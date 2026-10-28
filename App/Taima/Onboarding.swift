import SwiftUI

/// First launch: what Taima does, in four pages.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let symbol: String?
        let title: String
        let text: String
    }

    private let pages = [
        Page(id: 0, symbol: nil, title: "Welcome to Taima", text: "A private home for every bag you collect: what it was, how strong, who grew it and how much is left."),
        Page(id: 1, symbol: "text.viewfinder", title: "Scan the label", text: "Bags, preroll packs and jars. Photograph the front, and the back if you like. Taima reads the name, THC, weight, dates, codes and grower on this iPhone. Check the values and fix anything before saving."),
        Page(id: 2, symbol: "bag.fill", title: "Track your stash", text: "Mark bags as full, open or empty. Log what you use from the app, a widget or the Live Activity on your Lock Screen."),
        Page(id: 3, symbol: "lock.shield", title: "Yours alone", text: "No account, no cloud, no analytics. Export a backup from Settings now and then: deleting the app deletes its data.")
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.17, blue: 0.12), Color(red: 0.03, green: 0.09, blue: 0.07)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Theme.leafMid.opacity(0.16), .clear], center: .init(x: 0.5, y: 0.32), startRadius: 0, endRadius: 280)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                TabView(selection: $page) {
                    ForEach(pages) { item in
                        VStack(spacing: 24) {
                            Spacer()
                            if let symbol = item.symbol {
                                Image(systemName: symbol)
                                    .font(.system(size: 72, weight: .semibold))
                                    .foregroundStyle(Theme.leafLight)
                                    .symbolEffect(.bounce, value: page == item.id)
                                    .frame(height: 150)
                            } else {
                                Mascot(size: 170)
                            }
                            Text(item.title)
                                .font(.largeTitle.bold())
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                            Text(item.text)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if page < pages.count - 1 {
                        withAnimation(.spring) { page += 1 }
                    } else {
                        dismiss()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Next" : "Get started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentTransition(.opacity)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.leafDeep)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: page)
    }
}

/// What a build changed, shown once after an update, as in Saiko.
struct ReleaseHighlights: Identifiable {
    struct Item: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        var id: String { symbol + title }
    }

    let build: Int
    let items: [Item]
    var id: Int { build }

    static var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }

    static let all: [ReleaseHighlights] = [
        ReleaseHighlights(build: 9, items: [
            Item(symbol: "character.bubble", title: "Taima in Dutch", detail: "Set your iPhone to Dutch and Taima speaks it too, from the labels to the widgets."),
            Item(symbol: "arrow.clockwise", title: "Repeat last session", detail: "Log the same amount and method again in one tap, from Stash, a bag or the widget."),
            Item(symbol: "square.grid.2x2", title: "Log from the Home Screen", detail: "The bag-in-use widget comes in a medium size with all quick amounts."),
            Item(symbol: "calendar", title: "A calendar of your use", detail: "Stats shows each month at a glance: days with use, shaded by amount, and days without."),
            Item(symbol: "clock.arrow.circlepath", title: "On this day", detail: "See what you collected around this date in earlier years."),
            Item(symbol: "dice", title: "Roulette and games", detail: "Spin for a strain, a way to smoke and a game like Bim Bam Baap. Add players, keep score, chase rare legendary pulls and make every rule your own, in Tools."),
            Item(symbol: "link", title: "Strain sources", detail: "Every curated lineage now shows where it comes from. Growers and sources update with the strain library.")
        ]),
        ReleaseHighlights(build: 8, items: [
            Item(symbol: "crop", title: "Cleaner label photos", detail: "Taima straightens and crops the bag in your photo, evens out the light and reads both versions."),
            Item(symbol: "text.viewfinder", title: "Better label reading", detail: "More label layouts, dates and weights are understood, and every filled-in value can be checked."),
            Item(symbol: "wand.and.sparkles", title: "Improve older entries", detail: "Re-read the bags you already have and accept what the better reader adds. Nothing you typed is changed."),
            Item(symbol: "books.vertical", title: "A bigger strain library", detail: "Many more curated strains, aliases and crosses, and the library now updates itself."),
            Item(symbol: "note.text.badge.plus", title: "Timed notes", detail: "Write how a session is going, with an optional photo, from the bag, the Stash or the Live Activity."),
            Item(symbol: "brain", title: "Learns your fixes", detail: "When you correct a name Taima misread, it remembers on this iPhone. You can choose to share samples to help everyone."),
            Item(symbol: "arrow.down.app", title: "Updates and reminders", detail: "Add Taima's source to SideStore for automatic updates. Taima tells you about new versions and reminds you the day before a refresh is due."),
            Item(symbol: "rosette", title: "Clearer milestones", detail: "Tap a badge in Stats to see what earns it, where to do it and how far along you are."),
            Item(symbol: "calendar.badge.clock", title: "Countdown to 4/20", detail: "Tools now counts the days to 20 April, next to the daily 4:20."),
            Item(symbol: "arrow.uturn.backward", title: "Undo and polish", detail: "Take back a stock change, a removed session or a deleted note. Taima asks before discarding edits, and layout, contrast and wording are clearer throughout.")
        ]),
        ReleaseHighlights(build: 7, items: [
            Item(symbol: "arrow.triangle.2.circlepath.camera", title: "Rotate to scan", detail: "For prerolls and jars: turn the label slowly in front of the camera. Taima reads every side, combines what it sees and keeps the clearest frame as the photo. Find it in the + menu, or under photos in the editor.")
        ]),
        ReleaseHighlights(build: 6, items: [
            Item(symbol: "lock.shield", title: "Tighter privacy", detail: "The Face ID lock now covers everything, Siri needs an unlocked iPhone, and discreet mode keeps names off the Lock Screen, widgets and Spotlight."),
            Item(symbol: "externaldrive.badge.timemachine", title: "Encrypted and automatic backups", detail: "Backups are protected with a passphrase and handle big collections. Turn on daily backups to a folder you choose."),
            Item(symbol: "timer", title: "Edible wait timer", detail: "Log an edible and the Lock Screen shows how long ago you took it, so you wait before taking more."),
            Item(symbol: "heart.text.square", title: "Safer use and a self-check", detail: "Trimbos tips, Dutch help lines and an optional private check-in, all in Tools."),
            Item(symbol: "calendar", title: "Use-free days and break savings", detail: "See use-free days each week, and the grams and euros a break keeps in your pocket."),
            Item(symbol: "nosign", title: "Tobacco and patterns", detail: "Note tobacco per session; Stats shows mood by time of day and THC."),
            Item(symbol: "hand.thumbsup", title: "Would buy again", detail: "Mark bags you'd buy again; the shop scanner reminds you."),
            Item(symbol: "sparkles.rectangle.stack", title: "Year in review", detail: "Share your year in Taima as a card."),
            Item(symbol: "square.grid.2x2", title: "Calmer and faster", detail: "Settings on every tab, one search, clearer cards, better contrast and much faster Stats.")
        ]),
        ReleaseHighlights(build: 5, items: [
            Item(symbol: "trash", title: "Start over", detail: "Settings can delete all of Taima's data on this iPhone and start fresh. You can export a backup first, and you confirm by typing DELETE.")
        ]),
        ReleaseHighlights(build: 4, items: [
            Item(symbol: "camera", title: "Camera fixed", detail: "Taking a photo no longer closes the camera straight away, and a new label photo is read at once."),
            Item(symbol: "books.vertical", title: "Strain library", detail: "Search over 9,000 strains in the Search tab, with lineage, aliases, crosses and a family tree. Tap the heart to keep a want-to-try list."),
            Item(symbol: "star.leadinghalf.filled", title: "Scores, effects and flavours", detail: "Rate out of 10 in half stars and note effects, downsides and flavours. Stats turns them into insights."),
            Item(symbol: "square.and.pencil", title: "Sessions", detail: "Log how you used and how you felt before and after, and see when and how you use most."),
            Item(symbol: "barcode.viewfinder", title: "Do I have this?", detail: "Point the camera at a bag in the shop to see if you already have it, or how you rated it."),
            Item(symbol: "calendar", title: "Weekly limit and reminders", detail: "Set a weekly limit and get a reminder when your stash runs low."),
            Item(symbol: "eurosign", title: "Shops and spending", detail: "Note where you bought a bag and see spending and price per gram by shop."),
            Item(symbol: "faceid", title: "Privacy", detail: "Lock Taima with Face ID, or switch on discreet mode for a plain icon and no names on widgets."),
            Item(symbol: "square.and.arrow.up", title: "Share, compare and milestones", detail: "Share a review card, compare two bags and collect milestones. All ten growers and hash are in.")
        ]),
        ReleaseHighlights(build: 3, items: [
            Item(symbol: "photo.stack", title: "Your own photos", detail: "Replace any photo, add pictures of the flower itself and pick which one shows in your collection."),
            Item(symbol: "rectangle.bottomthird.inset.filled", title: "Bag in use, everywhere", detail: "The bag you're using sits above the tab bar with a quick log button. Settings moved to the gear in Collection, and Search has its own tab."),
            Item(symbol: "chart.bar.xaxis", title: "Cleaner stats", detail: "Bars no longer overlap their labels, sizes compare by grams, and growers get their own colours."),
            Item(symbol: "person.2", title: "Growers filled in", detail: "Bags saved earlier get their grower from the label text Taima already read.")
        ]),
        ReleaseHighlights(build: 2, items: [
            Item(symbol: "bag.fill", title: "Stash and inventory", detail: "Mark bags as full, open or empty, log what you use and see how long your stash lasts."),
            Item(symbol: "livephoto", title: "Live Activity", detail: "The bag in use sits on your Lock Screen and Dynamic Island, with buttons to log an amount."),
            Item(symbol: "square.grid.2x2", title: "Widgets and controls", detail: "Stash and bag-in-use widgets, a Control Center button to scan, and Siri shortcuts."),
            Item(symbol: "smoke.fill", title: "Prerolls and jars", detail: "Track preroll packs one at a time and keep jars next to your bags."),
            Item(symbol: "rectangle.on.rectangle", title: "Back of the bag", detail: "Add a photo of the back. Taima recognizes growers such as Aardachtig, FYTA, Holigram and Canadelaar (COG) and fills in what the front missed."),
            Item(symbol: "leaf", title: "Strains together", detail: "See every bag of the same strain combined, with its THC over time."),
            Item(symbol: "chart.bar.xaxis", title: "Livelier stats", detail: "Pick a time range and tap or drag the charts for details."),
            Item(symbol: "wrench.and.screwdriver", title: "Tools", detail: "Joint and edible calculators, a tolerance break counter, strain roulette and countdowns to 4:20 and 4/20."),
            Item(symbol: "face.smiling", title: "Meet the mascot", detail: "Taima has a new icon: a friendly little leaf.")
        ])
    ]

    /// Highlights newer than the last build the person saw.
    static func owed(seenThrough: Int) -> [ReleaseHighlights] {
        all.filter { $0.build > seenThrough && $0.build <= currentBuild }
    }
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    let releases: [ReleaseHighlights]
    @State private var contentHeight: CGFloat = 520

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    Mascot(size: 84)
                    Text("What's new in Taima")
                        .font(.title2.bold())
                        .fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)
                }
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Array(releases.flatMap(\.items).enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 16) {
                            TintedIconTile(systemImage: item.symbol, hue: Theme.leafMid)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.headline)
                                Text(item.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .appearLift(delay: 0.05 * Double(index))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 12)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) {
            Button {
                dismiss()
            } label: {
                Text("Continue").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
        }
        .presentationDetents([.height(min(contentHeight + 110, 760)), .large])
        .presentationDragIndicator(.visible)
    }
}
