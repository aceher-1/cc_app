import Foundation

struct HalalAssessment: Equatable {
    enum Status: String { case potentiallySuitable, needsConfirmation, excluded }
    let status: Status
    let reason: String
    var title: String {
        switch status {
        case .potentiallySuitable: return "Potentially suitable"
        case .needsConfirmation: return "Needs confirmation"
        case .excluded: return "Excluded by ingredient screen"
        }
    }

    static let explanation = "This ingredient screen is not halal certification. It shows provider-labeled vegetarian, vegan, or plant-based dishes with ingredients and no detected pork, alcohol, or other flagged ingredients. Meat and seafood need confirmation. Enzymes, flavorings, ingredient sources, and preparation may still need checking with dining staff."

    static func assess(_ item: MenuItem) -> HalalAssessment {
        guard let ingredients = item.ingredients, !ingredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .init(status: .needsConfirmation, reason: "Ingredients are missing from the source menu.")
        }
        var text = "\(item.name) \(item.description) \(ingredients)".lowercased()
        // Vinegar names do not by themselves establish beverage alcohol content.
        text = text.replacingOccurrences(of: #"\b(?:(?:red|white|rice)\s+)?(?:wine|sherry|champagne)\s+vinegar\b"#,
                                        with: "vinegar", options: .regularExpression)
        let exclusions: [(String, String)] = [
            (#"\b(?:pork|ham|bacon|lard|prosciutto|pancetta|salami|pepperoni|chorizo|gelatin|gelatine|blood)\b"#, "A pork, gelatin, or other flagged animal ingredient was detected."),
            (#"\b(?:alcohol|ethanol|wine|beer|ale|lager|bourbon|whisk(?:e)?y|vodka|rum|brandy|cognac|liqueur|liquor|sake|mirin|sherry|marsala|tequila|champagne)\b"#, "An alcohol-related ingredient was detected."),
            (#"\banimal\s+rennet\b"#, "Animal rennet was detected; its source is not verified.")
        ]
        for (pattern, reason) in exclusions where text.range(of: pattern, options: .regularExpression) != nil {
            return .init(status: .excluded, reason: reason)
        }
        let landMeat = #"\b(?:beef|chicken|turkey|lamb|mutton|veal|duck|goose|venison|bison|meat|sausage|tallow|suet|collagen)\b"#
        // False positives (for example plant-based sausages) stay conservative and explainable.
        if text.range(of: landMeat, options: .regularExpression) != nil {
            return .init(status: .needsConfirmation, reason: "Meat or an animal-derived ingredient is mentioned. The source does not verify halal sourcing.")
        }
        let seafood = #"\b(?:fish|salmon|tuna|cod|tilapia|haddock|anchov(?:y|ies)|shrimp|prawn|crab|lobster|clam|mussel|oyster|scallop|squid|octopus|seafood)\b"#
        if !item.allergens.isDisjoint(with: [.fish, .shellfish]) || text.range(of: seafood, options: .regularExpression) != nil {
            return .init(status: .needsConfirmation, reason: "Seafood is mentioned; confirm ingredients and suitability with dining staff.")
        }
        guard !item.diets.isDisjoint(with: [.vegan, .vegetarian, .plantBased]) else {
            return .init(status: .needsConfirmation, reason: "The provider has not labeled this item vegetarian, vegan, or plant based.")
        }
        return .init(status: .potentiallySuitable, reason: "Provider-labeled plant-based or vegetarian option; no flagged ingredient was detected. Ingredient sources and preparation are unverified.")
    }
}
