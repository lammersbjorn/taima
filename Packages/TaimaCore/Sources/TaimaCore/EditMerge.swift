import Foundation

public extension Bag {
    /// Combines an edited copy with what was stored meanwhile. Use logged
    /// from the Live Activity while the editor was open wins over the
    /// editor's older copy, and stock follows the log unless the person
    /// changed it in the form.
    static func merge(edited: Bag, original: Bag, stored: Bag) -> Bag {
        var bag = edited
        // The editor never changes timed notes; ones added meanwhile stay.
        if edited.timedNotes == original.timedNotes { bag.timedNotes = stored.timedNotes }
        if edited.usageLog == original.usageLog {
            bag.usageLog = stored.usageLog
            if edited.stockState == original.stockState, edited.remainingGrams == original.remainingGrams {
                bag.stockState = stored.stockState
                bag.remainingGrams = stored.remainingGrams
            }
        }
        return bag
    }

    /// A fresh reading of the label replaces only label fields: everything
    /// the person added (inventory, photos, scores, tags, shop, notes) stays.
    func keepingPersonalFields(of previous: Bag) -> Bag {
        var bag = self
        bag.id = previous.id
        bag.createdAt = previous.createdAt
        bag.collectedOn = previous.collectedOn
        bag.notes = previous.notes
        bag.rating = previous.rating
        bag.score = previous.score
        bag.effects = previous.effects
        bag.sideEffects = previous.sideEffects
        bag.flavors = previous.flavors
        bag.priceEuros = previous.priceEuros
        bag.shop = previous.shop
        bag.shopCity = previous.shopCity
        bag.stockState = previous.stockState
        bag.remainingGrams = previous.remainingGrams
        bag.usageLog = previous.usageLog
        bag.timedNotes = previous.timedNotes
        bag.backPhotoName = previous.backPhotoName
        bag.backRecognizedText = previous.backRecognizedText
        bag.extraPhotoNames = previous.extraPhotoNames
        bag.coverPhotoName = previous.coverPhotoName
        bag.wouldBuyAgain = previous.wouldBuyAgain
        if productForm == nil || productForm == .bag { bag.productForm = previous.productForm }
        if unitCount == nil { bag.unitCount = previous.unitCount }
        return bag
    }
}
