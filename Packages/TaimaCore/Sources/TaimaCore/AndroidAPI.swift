import Foundation

/// Versioned, stateless coarse boundary. Android owns documents and platform I/O;
/// all mutations and derived values are evaluated here. No global game session.
public enum AndroidAPI {
    @TaskLocal public static var resourceDirectory: String?
    static func resourceURL(_ name: String, extension ext: String) -> URL? {
        if let resourceDirectory { return URL(fileURLWithPath: resourceDirectory).appendingPathComponent(name + "." + ext) }
        return Bundle.module.url(forResource: name, withExtension: ext)
    }
    enum Failure: String, Error { case invalidRequest, invalidRecord, unsupportedOperation, unsafePhoto }
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]; return e
    }
    static func decode<T: Decodable>(_ type: T.Type, _ value: Any) throws -> T {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try d.decode(type, from: JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]))
    }
    static func json<T: Encodable>(_ value: T) throws -> Any { try JSONSerialization.jsonObject(with: encoder().encode(value), options: [.fragmentsAllowed]) }
    static func optional<T>(_ value: T?) -> Any { value.map { $0 as Any } ?? NSNull() }
    public static func call(_ data: Data) -> Data {
        do {
            guard let r = try JSONSerialization.jsonObject(with: data) as? [String: Any], r["version"] as? Int == 1 else { throw Failure.invalidRequest }
            let result = try $resourceDirectory.withValue(r["resourceDirectory"] as? String) {
                try PartyContent.$requestedLanguage.withValue(r["language"] as? String) { try run(r) }
            }
            return try JSONSerialization.data(withJSONObject: ["version": 1, "ok": true, "result": result], options: [.sortedKeys, .fragmentsAllowed])
        } catch {
            let code = (error as? Failure)?.rawValue ?? (error is BackupArchive.ArchiveError ? "invalidBackup" : "invalidRequest")
            return Data("{\"version\":1,\"ok\":false,\"error\":{\"code\":\"\(code)\"}}".utf8)
        }
    }
    static func validate(_ b: Bag) throws {
        guard !b.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              [b.grams, b.remainingGrams, b.priceEuros].compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 >= 0 }),
              b.remainingGrams.map({ $0 <= (b.grams ?? $0) }) ?? true,
              [b.thc, b.cbd].compactMap({ $0 }).allSatisfy({ (0...100).contains($0.percent) }),
              b.rating10.map({ (0...10).contains($0) }) ?? true,
              b.unitCount.map({ $0 > 0 }) ?? true,
              b.usage.allSatisfy({ $0.grams.isFinite && $0.grams >= 0 })
        else { throw Failure.invalidRecord }
    }
    static func run(_ r: [String: Any]) throws -> Any {
        func string(_ k: String) -> String { r[k] as? String ?? "" }
        func number(_ k: String, _ fallback: Double = 0) -> Double { (r[k] as? NSNumber)?.doubleValue ?? fallback }
        func bags() throws -> [Bag] { try decode([Bag].self, r["bags"] ?? []) }
        func bag() throws -> Bag { try decode(Bag.self, r["bag"] ?? [:]) }
        func date(_ k: String) -> Date? { ISO8601DateFormatter().date(from: string(k)) }
        var calendar = Calendar.taima
        calendar.timeZone = TimeZone(identifier: string("timeZone")) ?? .current
        let now = date("now") ?? .now
        switch string("op") {
        case "bag.new": return try json(Bag(stock: .full))
        case "number.parse": return optional(DecimalInput.parse(string("text"), locale: Locale(identifier: string("locale"))))
        case "bag.edit":
            var b = try bag()
            let fields = r["fields"] as? [String: String] ?? [:]
            func amount(_ key: String) throws -> Double? {
                guard let text = fields[key], !text.isEmpty else { return nil }
                guard let value = DecimalInput.parse(text, locale: Locale(identifier: string("locale"))) else { throw Failure.invalidRecord }
                return value
            }
            func day(_ key: String) throws -> Date? {
                guard let text = fields[key], !text.isEmpty else { return nil }
                let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = calendar; f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
                guard let date = f.date(from: text), f.string(from: date) == text else { throw Failure.invalidRecord }; return date
            }
            b.name = fields["name"] ?? b.name; b.producer = fields["producer"]; b.notes = fields["notes"] ?? b.notes
            b.form = ProductForm(rawValue: fields["productForm"] ?? "") ?? b.form; b.stock = StockState(rawValue: fields["stockState"] ?? "") ?? b.stock
            b.grams = try amount("grams"); b.priceEuros = try amount("priceEuros"); b.score = try amount("score")
            if b.stock == .full { b.remainingGrams = b.grams } else if b.stock == .empty { b.remainingGrams = 0 } else { b.remainingGrams = try amount("remainingGrams") ?? b.grams }
            for key in ["thc", "cbd"] {
                let value = try amount(key)
                var potency = key == "thc" ? b.thc : b.cbd
                if value != potency?.percent { potency = value.map { Potency(percent: $0) } }
                if key == "thc" { b.thc = potency } else { b.cbd = potency }
            }
            b.unitCount = try amount("unitCount").map { value in guard value.rounded() == value, value <= 10000 else { throw Failure.invalidRecord }; return Int(value) }
            b.strainType = StrainType(rawValue: fields["strainType"] ?? "")
            b.shop = fields["shop"]; b.shopCity = fields["shopCity"]; b.productID = fields["productID"]; b.sku = fields["sku"]; b.ean = fields["ean"]
            b.harvestedOn = try day("harvestedOn"); b.packedOn = try day("packedOn"); b.bestBeforeOn = try day("bestBeforeOn")
            b.effects = fields["effects"]?.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            b.sideEffects = fields["sideEffects"]?.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            b.flavors = fields["flavors"]?.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            b.wouldBuyAgain = fields["wouldBuyAgain"].flatMap { $0.isEmpty ? nil : $0 == "true" }
            b.updatedAt = now; try validate(b); return try json(b)
        case "bag.save":
            var b = try bag(); b.name = b.name.trimmingCharacters(in: .whitespacesAndNewlines); try validate(b); b.updatedAt = now
            return try json(b)
        case "bag.view":
            let b = try bag()
            return ["remaining": b.remaining, "unitGrams": optional(b.gramsPerUnit), "unitsLeft": optional(b.unitsLeft), "score": optional(b.rating10), "photoNames": b.storedPhotoNames, "mainPhoto": optional(b.mainPhoto)]
        case "bag.open", "bag.use", "bag.undo", "bag.repeat", "bag.session", "bag.note", "bag.deleteNote":
            var b = try bag()
            switch string("op") {
            case "bag.open": b.open()
            case "bag.undo": guard let id = UUID(uuidString: string("id")) else { throw Failure.invalidRequest }; b.undoUse(id)
            case "bag.repeat":
                guard let last = UsageEntry.toRepeat(for: b, in: try bags()) else { throw Failure.invalidRequest }
                b.use(last.grams, at: now, details: last.repeated(at: now))
            case "bag.session": b.updateUse(try decode(UsageEntry.self, r["entry"] ?? [:]))
            case "bag.note": b.noteLog.append(TimedNote(date: now, text: string("text"), photoName: r["photoName"] as? String))
            case "bag.deleteNote": b.noteLog.removeAll { $0.id.uuidString == string("id") }
            default:
                let amount = number("amount")
                guard amount.isFinite, amount > 0, amount <= b.remaining else { throw Failure.invalidRecord }
                let entry = UsageEntry(date: now, grams: amount, method: ConsumptionMethod(rawValue: string("method")), moodBefore: r["moodBefore"] as? Int, moodAfter: r["moodAfter"] as? Int, note: r["note"] as? String, withTobacco: r["withTobacco"] as? Bool)
                b.use(amount, at: now, details: entry)
            }
            b.updatedAt = now; return try json(b)
        case "dashboard":
            let bs = try bags(), stats = CollectionStats(bags: bs, calendar: calendar), inv = InventorySummary(bags: bs, now: now, calendar: calendar)
            let spending = SpendingSummary(bags: bs, calendar: calendar), sessions = SessionInsights(bags: bs, calendar: calendar)
            let year = YearReview(bags: bs, year: Int(number("year", Double(calendar.component(.year, from: now)))), calendar: calendar)
            let experience = ExperienceInsights(bags: bs)
            let history = UsageMonth(bags: bs, month: date("month") ?? now, now: now, calendar: calendar)
            return [
                "count": stats.bagCount, "grams": stats.totalGrams, "strains": stats.strainCount, "growers": stats.producerCount,
                "averageTHC": optional(stats.averageTHC), "averageHashTHC": optional(stats.averageHashTHC), "averageScore": optional(stats.averageRating), "pricePerGram": optional(stats.averagePricePerGram),
                "stash": inv.stashGrams, "usedToday": inv.usedToday, "usedWeek": inv.usedThisWeek, "used30Days": inv.usedLast30Days, "daysSupply": optional(inv.daysOfSupply), "freeDays": inv.useFreeDaysThisWeek,
                "spent": spending.total, "sessions": sessions.sessionCount,
                "months": stats.months.map { ["date": ISO8601DateFormatter().string(from: $0.start), "count": $0.count, "grams": $0.grams] as [String: Any] },
                "shops": spending.shops.map { ["name": $0.name, "city": optional($0.city), "visits": $0.visits, "euros": $0.euros, "perGram": optional($0.pricePerGram)] },
                "history": history.days.map { ["date": ISO8601DateFormatter().string(from: $0.date), "grams": $0.grams, "sessions": $0.sessions, "tracked": $0.isTracked] as [String: Any] },
                "milestones": Milestone.evaluate(bs).map { ["id": $0.id, "title": $0.title, "detail": $0.detail, "hint": $0.hint, "current": $0.current, "target": $0.target] as [String: Any] },
                "year": ["year": year.year, "count": year.bagCount, "grams": year.grams, "strains": year.strainCount, "growers": year.growerCount, "favourite": optional(year.favourite?.name), "topGrower": optional(year.topGrower)] as [String: Any],
                "useFirst": bs.filter { $0.stock != .empty }.useFirstOrder.map { $0.id.uuidString },
                "formCounts": ProductForm.allCases.map { form in ["form": form.rawValue, "count": bs.filter { $0.form == form }.count] as [String: Any] },
                "byHour": sessions.byHour, "byWeekday": sessions.byWeekday,
                "thcBins": stats.thcBins.map { ["lower": $0.lowerBound, "count": $0.count] },
                "producers": stats.producers.map { ["name": $0.label, "count": $0.count, "grams": $0.grams] as [String: Any] },
                "cureDays": optional(stats.averageCureDays), "ageDays": optional(stats.averageAgeAtCollectionDays),
                "methods": sessions.methods.map { ["name": $0.label, "count": $0.count, "grams": $0.grams] as [String: Any] },
                "tobaccoShare": optional(sessions.tobaccoShare),
                "moodByStrain": sessions.liftByStrain.map { ["name": $0.label, "change": $0.change, "count": $0.count] as [String: Any] },
                "moodByMethod": sessions.liftByMethod.map { ["name": $0.label, "change": $0.change, "count": $0.count] as [String: Any] },
                "positive": experience.positive.map { ["name": $0.name, "count": $0.count] as [String: Any] },
                "negative": experience.negative.map { ["name": $0.name, "count": $0.count] as [String: Any] },
                "flavors": experience.flavors.map { ["name": $0.name, "count": $0.count] as [String: Any] },
                "topStrains": experience.topStrains.map { ["name": $0.label, "score": $0.score, "count": $0.count] as [String: Any] },
                "memories": OnThisDay.memories(in: bs, now: now, calendar: calendar).map { ["name": $0.bag.name, "years": $0.yearsAgo] as [String: Any] }
            ] as [String: Any]
        case "catalog.verify":
            let folder = URL(fileURLWithPath: string("directory"))
            let manifest = try CatalogManifest.decode(Data(contentsOf: folder.appendingPathComponent("manifest.json")))
            guard manifest.isWellFormed, (manifest.minimumBuild ?? 0) <= Int(number("build")) else { throw Failure.invalidRequest }
            for file in manifest.files { guard manifest.verify(try Data(contentsOf: folder.appendingPathComponent(file.name)), for: file) else { throw Failure.invalidRequest } }
            let catalog = StrainCatalog(curated: try Data(contentsOf: folder.appendingPathComponent("strains-curated.json")), community: try Data(contentsOf: folder.appendingPathComponent("strains.json")))
            guard !catalog.strains.isEmpty else { throw Failure.invalidRequest }; return true
        case "catalog":
            let catalog = StrainCatalog(curated: Data(string("curated").utf8), community: Data(string("community").utf8))
            func info(_ s: StrainInfo) -> [String: Any] { ["id": s.id, "name": s.name, "aliases": s.aliases, "parents": s.parents, "reported": s.lineageReported, "breeder": optional(s.breeder), "sources": s.sourceIDs, "type": optional(s.trustedType?.rawValue), "effects": s.effects, "downsides": s.downsides, "flavors": s.flavors] }
            if let s = catalog.info(named: string("name")) { return ["strain": info(s), "children": catalog.children(of: s).map(info), "owned": try json(try bags().filter { catalog.match(productName: $0.name)?.info.id == s.id })] }
            return ["results": catalog.search(string("query"), limit: 100).map(info)]
        case "label":
            let lines = try decode([RecognizedLine].self, r["lines"] ?? [])
            let reading = LabelParser.parse(lines: lines, codes: try decode([DetectedCode].self, r["codes"] ?? []))
            var b = (try? bag()) ?? Bag(stock: .full)
            b.name = reading.name ?? b.name; b.producer = reading.producer ?? b.producer; b.thc = reading.thc ?? b.thc; b.cbd = reading.cbd ?? b.cbd; b.grams = reading.grams ?? b.grams
            b.productID = reading.productID ?? b.productID; b.sku = reading.sku ?? b.sku; b.ean = reading.ean ?? b.ean; b.leafletURL = reading.leafletURL ?? b.leafletURL
            b.productForm = reading.form ?? b.productForm; b.unitCount = reading.unitCount ?? b.unitCount; b.strainType = reading.strainType ?? b.strainType
            b.harvestedOn = reading.harvestedOn ?? b.harvestedOn; b.packedOn = reading.packedOn ?? b.packedOn; b.bestBeforeOn = reading.bestBeforeOn ?? b.bestBeforeOn; b.recognizedText = reading.text
            return ["bag": try json(b), "fields": reading.detectedFields.map(\.rawValue)]
        case "lookup":
            let result = CollectionLookup.find(payloads: r["payloads"] as? [String] ?? [], texts: r["texts"] as? [String] ?? [], in: try bags())
            switch result {
            case .sameBag(let b): return ["kind": "sameBag", "bags": try json([b])]
            case .sameProduct(let bs): return ["kind": "sameProduct", "bags": try json(bs)]
            case .sameStrain(_, let bs): return ["kind": "sameStrain", "bags": try json(bs)]
            case .new: return ["kind": "new", "bags": []]
            }
        case "tools":
            let grams = number("grams"), thc = number("thc"), per = number("perJoint", 0.25)
            let edible = StashMath.edible(grams: grams, thcPercent: thc, efficiency: number("efficiency", 0.7), portions: Int(number("portions", 10)))
            return ["joints": StashMath.joints(grams: grams, perJoint: per), "thc": StashMath.thcMilligrams(grams: per, thcPercent: thc), "totalMG": edible.totalMilligrams, "portionMG": edible.perPortionMilligrams]
        case "wellbeing":
            let answers = r["answers"] as? [Int] ?? []
            let score = SelfCheck.score(answers)
            let record = BreakRecord(start: date("start") ?? now, end: date("end"))
            let saving = record.savings(dailyGrams: number("dailyGrams"), pricePerGram: r["pricePerGram"] as? Double, now: now)
            return ["questions": SelfCheck.questions.map { ["text": $0.text, "answers": $0.answers.map(\.label)] }, "score": score, "summary": SelfCheck.summary(for: score), "days": record.days(now: now, calendar: calendar), "gramsSaved": saving.grams, "eurosSaved": optional(saving.euros)]
        case "party":
            var settings = PartySettings.decode(try r["settings"].map { try JSONSerialization.data(withJSONObject: $0) })
            var state = try r["state"].map { try decode(DeckState.self, $0) } ?? DeckState(seen: settings.seenCards)
            if string("action") == "players" { settings.players = (r["names"] as? [String] ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { name in settings.players.first { $0.name == name } ?? Player(name: name) } }
            if string("action") == "score", let id = UUID(uuidString: string("id")), let i = settings.players.firstIndex(where: { $0.id == id }) { settings.players[i].points += Int(number("points")); settings.players[i].sjaak += Int(number("sjaak")); settings.players[i].legendaries += Int(number("legendary")) }
            var output: [String: Any] = [:]
            if string("action") == "next" || string("action") == "roulette" {
                if let id = r["gameID"] as? String, let game = settings.cards.first(where: { $0.id == id }) { output["card"] = try json(PartyDeck.next(only: game, settings, state: &state)) }
                else if string("action") == "roulette" { let spin = PartyDeck.roulette(settings, bags: try bags(), state: &state); output["roulette"] = try json(spin); if let game = spin.game { output["card"] = try json(game) } }
                else { output["card"] = try json(PartyDeck.next(settings, bags: try bags(), state: &state)) }
                let legendary = (output["card"] as? [String: Any])?["kind"] as? String == "legendary"
                settings.spinsSinceLegendary = legendary ? 0 : settings.spinsSinceLegendary + 1
            }
            settings.seenCards = state.seen.sorted(); output["settings"] = try json(settings); output["state"] = try json(state)
            output["standings"] = try json(settings.players.sorted { $0.points > $1.points })
            output["games"] = settings.cards.map { ["id": $0.id, "title": $0.displayTitle, "enabled": $0.enabled, "legendary": $0.legendary] as [String: Any] }
            return output
        case "csv.export": return CSVExport.make(try bags())
        case "csv.import": return try json(CSVExport.parse(string("text")))
        case "backup.write":
            let manifest = try decode(BackupArchive.Manifest.self, r["manifest"] ?? [:])
            let photos = URL(fileURLWithPath: string("photoDirectory"), isDirectory: true)
            let names = Array(Set(manifest.bags.flatMap(\.storedPhotoNames)))
            guard names.allSatisfy(BackupArchive.isSafePhotoName) else { throw Failure.unsafePhoto }
            try BackupArchive.write(to: URL(fileURLWithPath: string("path")), manifest: manifest, photoNames: names, photo: { name in
                let url = photos.appendingPathComponent(name); guard FileManager.default.fileExists(atPath: url.path) else { throw Failure.unsafePhoto }; return try Data(contentsOf: url)
            }, passphrase: r["passphrase"] as? String)
            return true
        case "backup.read":
            let path = URL(fileURLWithPath: string("path")), folder = URL(fileURLWithPath: string("photoDirectory"), isDirectory: true)
            func photo(_ name: String, _ data: Data) throws { guard BackupArchive.isSafePhotoName(name) else { throw Failure.unsafePhoto }; try data.write(to: folder.appendingPathComponent(name), options: .atomic) }
            let manifest: BackupArchive.Manifest
            if BackupArchive.isArchive(path) { manifest = try BackupArchive.read(from: path, passphrase: r["passphrase"] as? String, photo: photo) }
            else { let old = try CollectionBackup.decode(Data(contentsOf: path)); for (name, bytes) in old.photos { try photo(name, bytes) }; manifest = .init(bags: old.bags, wishlist: old.wishlist ?? [], producerKeys: [:], exportedAt: old.exportedAt) }
            guard manifest.version == 2 else { throw Failure.invalidRequest }; return try json(manifest)
        default: throw Failure.unsupportedOperation
        }
    }
}
