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
        let adding = "Tap + in Collection and photograph a label, or import photos. Empty bags you keep count too."
        let growerHint = "Set the grower when you add or edit a bag. Taima often reads it from the label or the back of the bag."
        return [
            m("bags.1", "First bag", "Add your first bag.", adding, "bag.fill", bags.count, 1),
            m("bags.10", "Collector", "Have 10 bags in your collection.", adding, "square.stack.3d.up.fill", bags.count, 10),
            m("bags.25", "Archivist", "Have 25 bags in your collection.", adding, "books.vertical.fill", bags.count, 25),
            m("bags.50", "Curator", "Have 50 bags in your collection.", adding, "building.columns.fill", bags.count, 50),
            m("strains.5", "Explorer", "Collect 5 different strains.", "Bags with the same strain name count once, so try something new.", "leaf.fill", strains, 5),
            m("strains.15", "Strain hunter", "Collect 15 different strains.", "Bags with the same strain name count once. The strain library has ideas, and you can keep a want-to-try list.", "binoculars.fill", strains, 15),
            m("growers.3", "Grower tour", "Get bags from 3 of the designated growers.", growerHint, "building.2.fill", knownGrowers, 3),
            m("growers.10", "All ten", "Get a bag from every designated grower.", growerHint, "star.circle.fill", knownGrowers, GrowerDirectory.designated.count),
            m("forms.all", "Full menu", "Collect a bag, prerolls, a jar and hash.", "Set Product when you add or edit an item.", "square.grid.2x2.fill", forms, ProductForm.allCases.count),
            m("types.3", "Indica, sativa, hybrid", "Have an indica, a sativa and a hybrid.", "Set the type when you edit a bag. Taima fills it in when the strain library knows it.", "circle.hexagongrid.fill", types, 3),
            m("rated.10", "Connoisseur", "Give 10 bags a score.", "Open a bag, tap Edit and set its score out of 10 under Yours.", "star.leadinghalf.filled", rated, 10),
            m("described.5", "Tasting notes", "Add effects or flavours to 5 bags.", "Open a bag, tap Edit and pick tags under Effects, Downsides or Taste and smell.", "text.bubble.fill", described, 5),
            m("sessions.10", "Journal keeper", "Log 10 sessions with a method or a mood.", "Use Log a session on a bag or in Stash, and choose how you used it or how you felt. Quick amounts don't count.", "book.closed.fill", sessions, 10),
            m("photos.flower", "Close-up", "Add a photo of the flower itself.", "Open a bag, tap Edit, then Add or change photos and pick one under Photo of the flower.", "camera.macro", bags.filter { !($0.extraPhotoNames ?? []).isEmpty }.count, 1)
        ]
    }
}
