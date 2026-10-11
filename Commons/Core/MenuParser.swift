import Foundation

enum MenuParseError: LocalizedError {
    case changedFormat
    var errorDescription: String? { "The dining website returned an unfamiliar menu format. Open the source menu or try again later." }
}

enum MenuParser {
    static func parse(_ data: Data, dateKey: String, fetchedAt: Date) throws -> DayMenu {
        guard let meals = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw MenuParseError.changedFormat
        }
        let parsed: [MenuMeal] = try meals.enumerated().map { mealIndex, meal in
            guard let name = nonempty(meal["name"]), let groups = meal["groups"] as? [[String: Any]] else {
                throw MenuParseError.changedFormat
            }
            let mealID = "\(dateKey)/\(mealIndex)"
            let stations: [MenuStation] = try groups.enumerated().map { groupIndex, group in
                guard let groupName = nonempty(group["name"]), let items = group["items"] as? [[String: Any]] else {
                    throw MenuParseError.changedFormat
                }
                let stationID = "\(mealID)/\(groupIndex)"
                return MenuStation(id: stationID, name: groupName, items: try items.enumerated().map { itemIndex, item in
                    guard let itemName = nonempty(item["formalName"]) ?? nonempty(item["name"]) else {
                        throw MenuParseError.changedFormat
                    }
                    let sourceAllergens = item["allergens"] as? [[String: Any]]
                    var allergens = Set<Allergen>()
                    var unknown: [String] = []
                    for entry in sourceAllergens ?? [] {
                        if let mapped = Allergen.fromSource(nonempty(entry["allergen"]) ?? "")
                            ?? Allergen.fromSource(nonempty(entry["name"]) ?? "") {
                            allergens.insert(mapped)
                        } else {
                            unknown.append(nonempty(entry["name"]) ?? nonempty(entry["allergen"]) ?? "Unspecified allergen")
                        }
                    }
                    var diets = Set<Diet>()
                    for (key, diet) in [("isMindful", Diet.mindful), ("isPlantBased", .plantBased),
                                        ("isVegan", .vegan), ("isVegetarian", .vegetarian)] {
                        if boolean(item[key]) { diets.insert(diet) }
                    }
                    // Sodexo often sends menuItemId=0 for every item. Contextual IDs avoid collisions.
                    return MenuItem(id: "\(stationID)/\(itemIndex)", name: itemName,
                                    description: nonempty(item["description"]) ?? "",
                                    ingredients: nonempty(item["ingredients"]), allergens: allergens,
                                    unknownAllergens: unknown, hasAllergenData: sourceAllergens != nil,
                                    diets: diets, calories: nonempty(item["calories"]),
                                    portion: nonempty(item["portionSize"]) ?? nonempty(item["portion"]),
                                    protein: nonempty(item["protein"]), carbohydrates: nonempty(item["carbohydrates"]),
                                    fat: nonempty(item["fat"]))
                })
            }
            return MenuMeal(id: mealID, name: name, stations: stations)
        }
        return DayMenu(dateKey: dateKey, fetchedAt: fetchedAt, meals: parsed)
    }
    private static func nonempty(_ value: Any?) -> String? {
        let text: String
        if let value = value as? String { text = value }
        else if let value = value as? NSNumber { text = value.stringValue }
        else { return nil }
        let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
    private static func boolean(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? String { return value.lowercased() == "true" }
        return false
    }
}
