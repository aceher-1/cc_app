import Foundation

enum PlanNutrient: String, CaseIterable {
    case calories = "Calories", protein = "Protein", carbs = "Carbs", fat = "Fat"

    var unit: String { self == .calories ? "kcal" : "g" }

    func amount(in item: MenuItem) -> Double? {
        let raw: String?
        switch self {
        case .calories: raw = item.calories
        case .protein: raw = item.protein
        case .carbs: raw = item.carbohydrates
        case .fat: raw = item.fat
        }
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return nil }
        let suffixes = self == .calories ? ["kcal", "calories", "cal"] : ["grams", "gram", "g"]
        if let suffix = suffixes.first(where: { text.hasSuffix($0) }) {
            text = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
        }
        guard let amount = Double(text), amount.isFinite, amount >= 0 else { return nil }
        return amount
    }
}

enum PlanGoal: String, CaseIterable, Identifiable {
    case all = "All dishes", protein = "Higher protein", carbs = "Lower carb"
    var id: Self { self }
    var nutrient: PlanNutrient? {
        switch self {
        case .all: return nil
        case .protein: return .protein
        case .carbs: return .carbs
        }
    }
}

struct PlannedDish: Codable, Identifiable {
    let id: UUID
    let meal: String
    let station: String
    let item: MenuItem
    var servings: Int
}

struct MealPlan: Codable {
    var dishes: [PlannedDish] = []

    mutating func add(_ item: MenuItem, meal: String, station: String) {
        if let index = dishes.firstIndex(where: { $0.meal == meal && $0.station == station && $0.item == item }) {
            dishes[index].servings = min(99, dishes[index].servings + 1)
        } else {
            dishes.append(.init(id: UUID(), meal: meal, station: station, item: item, servings: 1))
        }
    }

    mutating func adjust(_ id: UUID, by delta: Int) {
        guard let index = dishes.firstIndex(where: { $0.id == id }) else { return }
        let count = dishes[index].servings + delta
        if count <= 0 { dishes.remove(at: index) }
        else { dishes[index].servings = min(99, count) }
    }

    static func total(_ nutrient: PlanNutrient, in dishes: [PlannedDish]) -> (known: Double?, missing: Int) {
        var known: Double?
        var missing = 0
        for dish in dishes {
            if let amount = nutrient.amount(in: dish.item) { known = (known ?? 0) + amount * Double(dish.servings) }
            else { missing += dish.servings }
        }
        return (known, missing)
    }

    static func ranked(_ items: [MenuItem], goal: PlanGoal) -> [MenuItem] {
        guard let nutrient = goal.nutrient else { return items }
        return items.enumerated().compactMap { index, item -> (Int, MenuItem, Double)? in
            nutrient.amount(in: item).map { (index, item, $0) }
        }.sorted { left, right in
            if left.2 == right.2 { return left.0 < right.0 }
            return goal == .protein ? left.2 > right.2 : left.2 < right.2
        }.map { $0.1 }
    }
}
