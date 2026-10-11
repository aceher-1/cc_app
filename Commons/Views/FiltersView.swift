import SwiftUI

struct FiltersView: View {
    @EnvironmentObject private var store: MenuStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Your choices are saved on this iPhone.", systemImage: "checkmark.circle")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    ForEach(Allergen.allCases) { allergen in
                        Toggle("Exclude \(allergen.title.lowercased())", isOn: allergenBinding(allergen))
                    }
                } header: { Text("Allergens to exclude") } footer: {
                    Text("Items with missing or unrecognized allergen data are hidden while allergen exclusions are active. Source labels do not establish freedom from cross-contact.")
                }
                Section {
                    ForEach(Diet.allCases) { diet in Toggle(diet.title, isOn: dietBinding(diet)) }
                } header: { Text("Diet labels to require") } footer: {
                    Text("Dishes must carry every selected Sodexo diet label.")
                }
                Section {
                    Toggle("Halal: potentially suitable", isOn: $store.preferences.halalPotentiallySuitable)
                        .accessibilityIdentifier("filter.halal")
                    Text(HalalAssessment.explanation).font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Halal ingredient screen") }
                Section {
                    Button("Clear dietary preferences", role: .destructive) { store.preferences = .init() }
                }
            }
            .tint(CommonsTheme.red)
            .navigationTitle("Dietary preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("filters.done") } }
        }
    }
    private func allergenBinding(_ allergen: Allergen) -> Binding<Bool> {
        Binding(get: { store.preferences.excludedAllergens.contains(allergen) }, set: { enabled in
            if enabled { store.preferences.excludedAllergens.insert(allergen) }
            else { store.preferences.excludedAllergens.remove(allergen) }
        })
    }
    private func dietBinding(_ diet: Diet) -> Binding<Bool> {
        Binding(get: { store.preferences.requiredDiets.contains(diet) }, set: { enabled in
            if enabled { store.preferences.requiredDiets.insert(diet) }
            else { store.preferences.requiredDiets.remove(diet) }
        })
    }
}
