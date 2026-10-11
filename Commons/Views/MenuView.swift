import SwiftUI
import Combine

struct MenuView: View {
    @EnvironmentObject private var store: MenuStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showFilters = false
    private let minuteTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    dateStrip
                    mealPicker
                    menuContent
                    footer
                }.padding(.bottom, 30)
            }
            .background(CommonsTheme.canvas)
            .navigationTitle("Commons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("MSOE").font(.caption.bold()).foregroundStyle(CommonsTheme.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            if store.preferences.count > 0 { Text("\(store.preferences.count)").font(.caption.bold()) }
                        }
                    }.accessibilityLabel("Dietary filters, \(store.preferences.count) selected")
                        .accessibilityIdentifier("filters.open")
                }
            }
            .searchable(text: $store.searchText, prompt: "Search dishes or stations")
            .refreshable { await store.load(force: true) }
            .sheet(isPresented: $showFilters) { FiltersView().environmentObject(store) }
            .task(id: store.selectedDateKey) { await store.load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.foreground() } }
            }
            .onReceive(minuteTick) { _ in
                if scenePhase == .active { Task { await store.foreground() } }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ON THE MENU").font(.caption.weight(.heavy)).tracking(2).foregroundStyle(.white.opacity(0.7))
            Text("Find your next\ngood meal.").font(.system(.largeTitle, design: .rounded).bold()).foregroundStyle(.white)
            Text("Robert Spitzer Dining Commons").font(.subheadline).foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(DiningDay.label(store.selectedDate, format: "EEEE, MMMM d"))
            }.font(.subheadline.weight(.semibold)).foregroundStyle(.white).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            ZStack(alignment: .trailing) {
                CommonsTheme.black
                Circle().fill(CommonsTheme.red).frame(width: 200, height: 200).offset(x: 115, y: 50)
            }.clipShape(RoundedRectangle(cornerRadius: 24))
        }.padding(.horizontal, 20)
    }

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.dates, id: \.self) { date in
                        let key = DiningDay.key(for: date)
                        let selected = key == store.selectedDateKey
                        Button {
                            store.selectedDateKey = key
                            store.selectedMealName = ""
                        } label: {
                            VStack(spacing: 6) {
                                Text(key == DiningDay.key(for: Date()) ? "TODAY" : DiningDay.label(date, format: "EEE").uppercased())
                                    .font(.caption2.weight(.bold))
                                Text(DiningDay.label(date, format: "d")).font(.title3.bold())
                                Text(DiningDay.label(date, format: "MMM")).font(.caption2)
                            }
                            .frame(minWidth: 56, minHeight: 78).padding(.horizontal, 5)
                            .foregroundStyle(selected ? Color.white : Color.primary)
                            .background(selected ? CommonsTheme.red : CommonsTheme.card, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain).id(key)
                        .accessibilityLabel(DiningDay.label(date, format: "EEEE, MMMM d"))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }.padding(.horizontal, 20)
            }
            .onAppear { proxy.scrollTo(store.selectedDateKey, anchor: .center) }
            .onChange(of: store.selectedDateKey) { _, key in withAnimation { proxy.scrollTo(key, anchor: .center) } }
        }
    }

    @ViewBuilder private var mealPicker: some View {
        if let menu = store.currentMenu, !menu.meals.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(menu.meals) { meal in
                        let selected = store.currentMeal?.id == meal.id
                        Button { store.selectedMealName = meal.name } label: {
                            Text(meal.name).font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .background(selected ? CommonsTheme.black : CommonsTheme.card, in: Capsule())
                        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }.padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder private var menuContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let message = store.message {
                VStack(alignment: .leading, spacing: 10) {
                    Label(message, systemImage: "wifi.exclamationmark").font(.subheadline)
                    Button("Retry refresh") { Task { await store.load(force: true) } }.font(.subheadline.bold())
                        .disabled(store.isLoading)
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(CommonsTheme.card, in: RoundedRectangle(cornerRadius: 16))
            }
            if store.isLoading {
                HStack { ProgressView(); Text(store.currentMenu == nil ? "Loading the menu…" : "Refreshing today’s cache…") }
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if let menu = store.currentMenu {
                if menu.itemCount == 0 {
                    EmptyMenuView(symbol: "calendar.badge.clock", title: "No menu posted yet", detail: "Sodexo has not listed dishes for this date. Check another day or refresh later.")
                } else if store.visibleCount == 0 {
                    EmptyMenuView(symbol: "line.3.horizontal.decrease.circle", title: "No matching dishes", detail: "Try another meal, change your filters, or clear your search.")
                    if !store.searchText.isEmpty { Button("Clear search") { store.searchText = "" } }
                    Button("Edit dietary filters") { showFilters = true }
                } else {
                    HStack {
                        Text("\(store.visibleCount) dishes").font(.headline)
                        Spacer()
                        if store.preferences.count > 0 {
                            Button("Filters on") { showFilters = true }.font(.caption.weight(.semibold))
                        }
                    }
                    if store.preferences.halalPotentiallySuitable {
                        Label("Potentially suitable • not halal certified", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(store.visibleStations) { station in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Rectangle().fill(CommonsTheme.red).frame(width: 4, height: 18)
                                Text(station.name).font(.title3.bold())
                                Spacer()
                                Text("\(station.items.count)").font(.caption.bold()).foregroundStyle(.secondary)
                            }.padding(16)
                            ForEach(station.items) { item in
                                Divider().padding(.horizontal, 16)
                                NavigationLink { ItemDetailView(item: item, station: station.name, meal: store.currentMeal?.name ?? "") } label: {
                                    MenuItemRow(item: item, showHalal: store.preferences.halalPotentiallySuitable)
                                }.buttonStyle(.plain)
                            }
                        }.background(CommonsTheme.card, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
            } else if !store.isLoading {
                EmptyMenuView(symbol: "fork.knife", title: "Menu unavailable", detail: "Connect to load this date. Previously loaded dates remain available offline.")
            }
        }.padding(.horizontal, 20)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let menu = store.currentMenu {
                Label("Updated \(DiningDay.label(menu.fetchedAt, format: "MMM d, h:mm a")) · Milwaukee time", systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
                if !DiningDay.isSourceFresh(menu, now: Date()) {
                    Text("Saved menu from an earlier day. It may have changed.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Diet and allergen labels come from Sodexo. Shared equipment and ingredient changes can affect suitability; confirm with dining staff.")
                .font(.caption).foregroundStyle(.secondary)
            Link(destination: SharedMenuService.sourceURL) { Label("View Sodexo’s original menu", systemImage: "arrow.up.right.square") }
                .font(.subheadline.weight(.medium))
        }.padding(.horizontal, 24)
    }
}

private struct MenuItemRow: View {
    let item: MenuItem
    let showHalal: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                if !item.description.isEmpty && item.description != item.name {
                    Text(item.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { badges }
                    VStack(alignment: .leading, spacing: 6) { badges }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 10) {
                if let calories = item.calories {
                    Text("\(calories) cal").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
    @ViewBuilder private var badges: some View {
        if item.diets.contains(.vegan) { DietBadge(title: "Vegan") }
        else if item.diets.contains(.vegetarian) { DietBadge(title: "Vegetarian") }
        else if item.diets.contains(.plantBased) { DietBadge(title: "Plant Based") }
        if item.diets.contains(.mindful) { DietBadge(title: "Mindful") }
        if showHalal { DietBadge(title: "Potentially suitable") }
    }
}

#Preview { MenuView().environmentObject(MenuStore()) }
