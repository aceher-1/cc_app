import SwiftUI

struct ItemDetailView: View {
    let item: MenuItem
    let station: String
    let meal: String
    var filterReasons: [String] = []
    private var assessment: HalalAssessment { HalalAssessment.assess(item) }
    var body: some View {
        List {
            if !filterReasons.isEmpty {
                Section("Excluded by your dietary filters") {
                    ForEach(filterReasons, id: \.self) { Text($0) }
                }
            }
            Section {
                Text(item.name).font(.title2.bold())
                Text("\(station) · \(meal)").font(.subheadline).foregroundStyle(CommonsTheme.red)
                if !item.description.isEmpty && item.description != item.name { Text(item.description) }
                if let portion = item.portion { LabeledContent("Serving", value: portion) }
            }
            if !item.diets.isEmpty {
                Section("Sodexo diet labels") {
                    ForEach(Diet.allCases.filter { item.diets.contains($0) }) { diet in
                        Label(diet.title, systemImage: diet == .mindful ? "heart" : "leaf")
                    }
                }
            }
            Section("Halal ingredient screen") {
                Label(assessment.title, systemImage: assessment.status == .potentiallySuitable ? "leaf.circle" : "questionmark.circle")
                    .font(.headline)
                Text(assessment.reason)
                Text(HalalAssessment.explanation).font(.caption).foregroundStyle(.secondary)
            }
            Section("Listed allergens") {
                if !item.hasAllergenData { Text("Allergen information unavailable.") }
                else if item.allergens.isEmpty && item.unknownAllergens.isEmpty { Text("None listed by Sodexo.") }
                else {
                    ForEach(Allergen.allCases.filter { item.allergens.contains($0) }) { allergen in Text(allergen.title) }
                    ForEach(Array(item.unknownAllergens.enumerated()), id: \.offset) { _, name in Text(name) }
                }
                Text("Shared equipment may introduce allergens. Confirm ingredients and preparation with dining staff.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Ingredients from Sodexo") { Text(item.ingredients ?? "Ingredients not provided.").font(.subheadline).textSelection(.enabled) }
            Section("Nutrition per serving") {
                nutrition("Calories", value: item.calories)
                nutrition("Protein", value: item.protein)
                nutrition("Carbohydrates", value: item.carbohydrates)
                nutrition("Fat", value: item.fat)
            }
            Section { Link("View original dining menu", destination: SharedMenuService.sourceURL) }
        }
        .navigationTitle("Dish details").navigationBarTitleDisplayMode(.inline)
    }
    @ViewBuilder private func nutrition(_ label: String, value: String?) -> some View {
        if let value { LabeledContent(label, value: value) }
    }
}
