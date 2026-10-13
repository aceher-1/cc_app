import Foundation

struct DietaryPreferences: Codable, Equatable {
    var excludedAllergens: Set<Allergen> = []
    var requiredDiets: Set<Diet> = []
    var halalPotentiallySuitable = false
    var count: Int { excludedAllergens.count + requiredDiets.count + (halalPotentiallySuitable ? 1 : 0) }

    func exclusionReasons(for item: MenuItem) -> [String] {
        var reasons: [String] = []
        if !excludedAllergens.isEmpty {
            if !item.hasAllergenData || !item.unknownAllergens.isEmpty {
                reasons.append("Allergen information is missing or unrecognized.")
            }
            let listed = Allergen.allCases.filter { excludedAllergens.contains($0) && item.allergens.contains($0) }
            if !listed.isEmpty { reasons.append("Lists excluded allergens: \(listed.map(\.title).joined(separator: ", ")).") }
        }
        let missing = Diet.allCases.filter { requiredDiets.contains($0) && !item.diets.contains($0) }
        if !missing.isEmpty { reasons.append("Missing required labels: \(missing.map(\.title).joined(separator: ", ")).") }
        if halalPotentiallySuitable {
            let assessment = HalalAssessment.assess(item)
            if assessment.status != .potentiallySuitable { reasons.append("Halal screen: \(assessment.reason)") }
        }
        return reasons
    }

    func includes(_ item: MenuItem) -> Bool {
        if !excludedAllergens.isEmpty {
            guard item.hasAllergenData, item.unknownAllergens.isEmpty,
                  item.allergens.isDisjoint(with: excludedAllergens) else { return false }
        }
        guard requiredDiets.isSubset(of: item.diets) else { return false }
        return !halalPotentiallySuitable || HalalAssessment.assess(item).status == .potentiallySuitable
    }
}

struct PreferenceStorage {
    let defaults: UserDefaults
    private let key = "commons.dietaryPreferences.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> DietaryPreferences {
        guard let data = defaults.data(forKey: key),
              let result = try? JSONDecoder().decode(DietaryPreferences.self, from: data) else { return .init() }
        return result
    }
    func save(_ preferences: DietaryPreferences) {
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: key) }
    }
}
