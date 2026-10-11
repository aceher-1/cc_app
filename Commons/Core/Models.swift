import Foundation

enum Allergen: String, CaseIterable, Codable, Identifiable {
    case eggs, fish, gluten, milk, mustard, peanut, sesame, shellfish, soy, sulphites, treeNuts, wheat
    var id: String { rawValue }
    var title: String {
        switch self {
        case .treeNuts: return "Tree nuts"
        case .peanut: return "Peanut"
        default: return rawValue.capitalized
        }
    }
    static func fromSource(_ value: String) -> Allergen? {
        let key = value.lowercased().filter { $0.isLetter }
        switch key {
        case "egg", "eggs": return .eggs
        case "fish": return .fish
        case "gluten": return .gluten
        case "milk", "dairy": return .milk
        case "mustard": return .mustard
        case "peanut", "peanuts": return .peanut
        case "sesame", "sesameseeds": return .sesame
        case "shellfish": return .shellfish
        case "so", "soy", "soybean", "soybeans": return .soy
        case "sulphites", "sulfites": return .sulphites
        case "treenuts", "treenut": return .treeNuts
        case "wheat": return .wheat
        default: return nil
        }
    }
}

enum Diet: String, CaseIterable, Codable, Identifiable {
    case mindful, plantBased, vegan, vegetarian
    var id: String { rawValue }
    var title: String { self == .plantBased ? "Plant Based" : rawValue.capitalized }
}

struct MenuItem: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let ingredients: String?
    let allergens: Set<Allergen>
    let unknownAllergens: [String]
    let hasAllergenData: Bool
    let diets: Set<Diet>
    let calories: String?
    let portion: String?
    let protein: String?
    let carbohydrates: String?
    let fat: String?
}

struct MenuStation: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let items: [MenuItem]
}

struct MenuMeal: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let stations: [MenuStation]
    var itemCount: Int { stations.reduce(0) { $0 + $1.items.count } }
}

struct DayMenu: Codable, Equatable {
    let dateKey: String
    let fetchedAt: Date
    let meals: [MenuMeal]
    var itemCount: Int { meals.reduce(0) { $0 + $1.itemCount } }
}
