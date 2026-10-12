import SwiftUI

struct SectionLayoutView: View {
    @EnvironmentObject private var store: MenuStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.sectionNames, id: \.self) { name in
                        Toggle(name, isOn: expandedBinding(name))
                            .accessibilityIdentifier("layout.expanded.\(name)")
                    }
                    .onMove { offsets, destination in store.moveSections(from: offsets, to: destination) }
                } header: { Text(store.currentMeal?.name ?? "Menu sections") } footer: {
                    Text("Drag the handles to reorder sections. Turn a section off to collapse its dishes. Your choices save on this iPhone and apply to matching section names across meals and dates.")
                }
                Section {
                    Button("Expand all sections") { setAllCollapsed(false) }
                    Button("Collapse all sections") { setAllCollapsed(true) }
                    Button("Reset section layout", role: .destructive) { store.layout = .init() }
                        .accessibilityIdentifier("layout.reset")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Organize sections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("layout.done")
                }
            }
        }
    }

    private func expandedBinding(_ name: String) -> Binding<Bool> {
        Binding(get: { !store.layout.isCollapsed(name) },
                set: { store.layout.setCollapsed(!$0, for: name) })
    }
    private func setAllCollapsed(_ collapsed: Bool) {
        var updated = store.layout
        for name in store.sectionNames { updated.setCollapsed(collapsed, for: name) }
        store.layout = updated
    }
}
