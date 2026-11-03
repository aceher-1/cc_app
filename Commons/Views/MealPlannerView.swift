import SwiftUI

struct MealPlannerView: View {
    @EnvironmentObject private var store: MenuStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("commons.mealPlans.v1") private var saved = Data()
    @State private var goal: PlanGoal = .all
    @State private var browsingMeal: String?
    @State private var confirmClear = false
    let dateKey: String

    private var menu: DayMenu? { store.menus[dateKey] }
    private var plans: [String: MealPlan] {
        (try? JSONDecoder().decode([String: MealPlan].self, from: saved)) ?? [:]
    }
    private var plan: MealPlan { plans[dateKey] ?? MealPlan() }
    private var meals: [String] {
        var seen = Set<String>()
        return ((menu?.meals.map(\.name) ?? []) + plan.dishes.map(\.meal)).filter { seen.insert($0).inserted }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let date = DiningDay.date(for: dateKey) {
                        Text(DiningDay.label(date, format: "EEEE, MMMM d")).font(.headline)
                    }
                    Picker("Suggestions", selection: $goal) {
                        ForEach(PlanGoal.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Text("Suggestions follow your dietary filters and compare reported amounts per serving.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Day total") {
                    totals(plan.dishes)
                    Text("Estimates use Sodexo’s listed serving sizes. Missing values are excluded and marked; a partial total is not the full amount.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !plan.dishes.isEmpty {
                    Section { Button("Clear this day’s plan", role: .destructive) { confirmClear = true } }
                }
                if meals.isEmpty {
                    Section { Text(store.loadingDates.contains(dateKey) ? "Loading menu…" : "No menu available for this date.") }
                }
                ForEach(meals, id: \.self) { meal in
                    let dishes = plan.dishes.filter { $0.meal == meal }
                    Section(meal) {
                        totals(dishes)
                        ForEach(dishes) { dish in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(dish.item.name).font(.headline)
                                if let portion = dish.item.portion { Text("Per serving: \(portion)").font(.caption) }
                                if !store.preferences.includes(dish.item) {
                                    Text("Excluded by your current dietary filters").font(.caption).foregroundStyle(.secondary)
                                }
                                HStack {
                                    Button { update { $0.adjust(dish.id, by: -1) } } label: {
                                        Image(systemName: "minus.circle")
                                    }.accessibilityLabel("Remove one serving of \(dish.item.name)")
                                    Text("\(dish.servings) servings").monospacedDigit()
                                    Button { update { $0.adjust(dish.id, by: 1) } } label: {
                                        Image(systemName: "plus.circle")
                                    }.accessibilityLabel("Add one serving of \(dish.item.name)")
                                        .disabled(dish.servings >= 99 || !store.preferences.includes(dish.item))
                                }.buttonStyle(.borderless)
                            }
                        }
                        if menu?.meals.contains(where: { $0.name == meal }) == true {
                            Button("Browse \(meal) dishes") { browsingMeal = meal }
                        }
                    }
                }
            }
            .confirmationDialog("Clear this day’s plan?", isPresented: $confirmClear) {
                Button("Clear plan", role: .destructive) { update { $0.dishes.removeAll() } }
            }
            .navigationTitle("Meal planner")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .navigationDestination(isPresented: Binding(
                get: { browsingMeal != nil },
                set: { if !$0 { browsingMeal = nil } }
            )) {
                if let meal = browsingMeal { dishes(for: meal) }
            }
        }
    }

    private func dishes(for meal: String) -> some View {
        let stations = (menu?.meals ?? []).filter { $0.name == meal }.flatMap(\.stations)
        let items = stations.flatMap(\.items).filter(store.preferences.includes)
        let ranked = MealPlan.ranked(items, goal: goal)
        return List {
            if ranked.isEmpty {
                Text(items.isEmpty ? "No dishes match your dietary filters." : "No matching dishes have a reported value for this goal. Choose All dishes to browse them.")
            }
            if goal.nutrient != nil && ranked.count < items.count && !ranked.isEmpty {
                Text("Dishes missing the selected nutrient are available under All dishes.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(ranked) { item in
                let station = stations.first { $0.items.contains(where: { $0.id == item.id }) }?.name ?? ""
                let count = plan.dishes.first { $0.meal == meal && $0.station == station && $0.item == item }?.servings ?? 0
                Button {
                    update { $0.add(item, meal: meal, station: station) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).foregroundStyle(.primary)
                            Text(station).font(.caption).foregroundStyle(.secondary)
                            if let portion = item.portion { Text("Per serving: \(portion)").font(.caption).foregroundStyle(.secondary) }
                            if let nutrient = goal.nutrient, let amount = nutrient.amount(in: item) {
                                Text("\(amount.formatted(.number.precision(.fractionLength(0...2)))) \(nutrient.unit) \(nutrient.rawValue.lowercased())")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if count > 0 { Text("\(count) added").font(.caption).monospacedDigit() }
                        Image(systemName: "plus.circle.fill")
                    }
                }.disabled(count >= 99).accessibilityHint("Adds one serving to the plan")
            }
        }.navigationTitle(meal).navigationBarTitleDisplayMode(.inline)
    }

    private func totals(_ dishes: [PlannedDish]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(PlanNutrient.allCases, id: \.self) { nutrient in
                let total = MealPlan.total(nutrient, in: dishes)
                let amount = total.known.map {
                    "\($0.formatted(.number.precision(.fractionLength(0...2)))) \(nutrient.unit)"
                }
                LabeledContent(nutrient.rawValue,
                               value: dishes.isEmpty ? "—" : amount.map { total.missing > 0 ? "\($0) known" : $0 } ?? "Unavailable")
                if total.missing > 0 {
                    Text("\(total.missing) serving(s) missing \(nutrient.rawValue.lowercased())")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func update(_ change: (inout MealPlan) -> Void) {
        var updated = plans
        var day = updated[dateKey] ?? MealPlan()
        change(&day)
        updated[dateKey] = day.dishes.isEmpty ? nil : day
        if let cutoff = DiningDay.calendar.date(byAdding: .day, value: -30, to: Date()) {
            let key = DiningDay.key(for: cutoff)
            updated = updated.filter { $0.key >= key }
        }
        if let data = try? JSONEncoder().encode(updated) { saved = data }
    }
}
