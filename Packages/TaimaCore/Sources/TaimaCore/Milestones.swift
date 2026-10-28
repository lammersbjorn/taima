import Foundation

/// Small collection milestones. Counted from records; nothing about amounts
/// used is rewarded, so using more never earns a badge.
public struct Milestone: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    /// What earns it, as an instruction.
    public var detail: String
    /// Where in Taima to do it.
    public var hint: String
    public var symbol: String
    public var current: Int
    public var target: Int
    public var achieved: Bool { current >= target }
    public var progress: Double { min(1, Double(current) / Double(max(target, 1))) }
    public var remaining: Int { max(0, target - current) }

    public static func evaluate(_ bags: [Bag]) -> [Milestone] {
        let strains = Set(bags.map(\.strainKey).filter { !$0.isEmpty }).count
        let knownGrowers = Set(bags.compactMap { bag in
            bag.producer.flatMap { name in GrowerDirectory.designated.first { $0.name == name }?.name }
        }).count
        let forms = Set(bags.map(\.form)).count
        let types = Set(bags.compactMap(\.strainType)).count
        let rated = bags.filter { $0.rating10 != nil }.count
        let described = bags.filter { !($0.positiveEffects.isEmpty && $0.negativeEffects.isEmpty && $0.flavorTags.isEmpty) }.count
        let sessions = bags.flatMap(\.usage).filter { $0.method != nil || $0.moodAfter != nil }.count
        func m(_ id: String, _ title: String, _ detail: String, _ hint: String, _ symbol: String, _ current: Int, _ target: Int) -> Milestone {
            Milestone(id: id, title: title, detail: detail, hint: hint, symbol: symbol, current: current, target: target)
        }
        let adding = String(localized: "Tap + in Collection and photograph a label, or import photos. Bags, prerolls, jars and hash all count, also empty ones you keep.", bundle: .taimaLocalization)
        let growerHint = String(localized: "Set the grower when you add or edit an item. Taima often reads it from the label or the back of a bag.", bundle: .taimaLocalization)
        return [
            m("bags.1", String(localized: "First find", bundle: .taimaLocalization), String(localized: "Add your first item.", bundle: .taimaLocalization), adding, "bag.fill", bags.count, 1),
            m("bags.10", String(localized: "Collector", bundle: .taimaLocalization), String(localized: "Have 10 items in your collection.", bundle: .taimaLocalization), adding, "square.stack.3d.up.fill", bags.count, 10),
            m("bags.25", String(localized: "Archivist", bundle: .taimaLocalization), String(localized: "Have 25 items in your collection.", bundle: .taimaLocalization), adding, "books.vertical.fill", bags.count, 25),
            m("bags.50", String(localized: "Curator", bundle: .taimaLocalization), String(localized: "Have 50 items in your collection.", bundle: .taimaLocalization), adding, "building.columns.fill", bags.count, 50),
            m("strains.5", String(localized: "Explorer", bundle: .taimaLocalization), String(localized: "Collect 5 different strains.", bundle: .taimaLocalization), String(localized: "Bags with the same strain name count once, so try something new.", bundle: .taimaLocalization), "leaf.fill", strains, 5),
            m("strains.15", String(localized: "Strain hunter", bundle: .taimaLocalization), String(localized: "Collect 15 different strains.", bundle: .taimaLocalization), String(localized: "Bags with the same strain name count once. The strain library has ideas, and you can keep a want-to-try list.", bundle: .taimaLocalization), "binoculars.fill", strains, 15),
            m("growers.3", String(localized: "Grower tour", bundle: .taimaLocalization), String(localized: "Collect from 3 of the designated growers.", bundle: .taimaLocalization), growerHint, "building.2.fill", knownGrowers, 3),
            m("growers.10", String(localized: "All ten", bundle: .taimaLocalization), String(localized: "Collect from every designated grower.", bundle: .taimaLocalization), growerHint, "star.circle.fill", knownGrowers, GrowerDirectory.designated.count),
            m("forms.all", String(localized: "Full menu", bundle: .taimaLocalization), String(localized: "Collect a bag, prerolls, a jar and hash.", bundle: .taimaLocalization), String(localized: "Set Product when you add or edit an item.", bundle: .taimaLocalization), "square.grid.2x2.fill", forms, ProductForm.allCases.count),
            m("types.3", String(localized: "Indica, sativa, hybrid", bundle: .taimaLocalization), String(localized: "Have an indica, a sativa and a hybrid.", bundle: .taimaLocalization), String(localized: "Set the type when you edit a bag. Taima fills it in when the strain library knows it.", bundle: .taimaLocalization), "circle.hexagongrid.fill", types, 3),
            m("rated.10", String(localized: "Connoisseur", bundle: .taimaLocalization), String(localized: "Give 10 bags a score.", bundle: .taimaLocalization), String(localized: "Open a bag, tap Edit and set its score out of 10 under Yours.", bundle: .taimaLocalization), "star.leadinghalf.filled", rated, 10),
            m("described.5", String(localized: "Tasting notes", bundle: .taimaLocalization), String(localized: "Add effects or flavours to 5 bags.", bundle: .taimaLocalization), String(localized: "Open a bag, tap Edit and pick tags under Effects, Downsides or Taste and smell.", bundle: .taimaLocalization), "text.bubble.fill", described, 5),
            m("sessions.10", String(localized: "Journal keeper", bundle: .taimaLocalization), String(localized: "Log 10 sessions with a method or a mood.", bundle: .taimaLocalization), String(localized: "Use Log a session on a bag or in Stash, and choose how you used it or how you felt. Quick amounts don't count.", bundle: .taimaLocalization), "book.closed.fill", sessions, 10),
            m("photos.flower", String(localized: "Close-up", bundle: .taimaLocalization), String(localized: "Add a photo of the flower itself.", bundle: .taimaLocalization), String(localized: "Open a bag, tap Edit, then Add or change photos and pick one under Photo of the flower.", bundle: .taimaLocalization), "camera.macro", bags.filter { !($0.extraPhotoNames ?? []).isEmpty }.count, 1)
        ]
    }
}
