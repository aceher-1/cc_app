import SwiftUI
import Combine

struct MenuView: View {
    @EnvironmentObject private var store: MenuStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showFilters = false
    @State private var showLayout = false
    @State private var expandedFilteredStations: Set<String> = []
    @State private var refreshConfirmation: String?
    @Namespace private var mealSelection
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
            .background {
                CommonsTheme.canvas.overlay(CommonsTheme.red.opacity(mealBackdropOpacity))
            }
            .animation(mealAnimation, value: store.currentMeal?.id)
            .sensoryFeedback(.selection, trigger: store.selectedMealName)
            .navigationTitle("Commons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Task { await refreshMenu() } } label: {
                        HStack(spacing: 6) {
                            Text("MSOE").font(.caption.bold())
                            if store.isLoading { ProgressView().controlSize(.mini) }
                            else { Image(systemName: "arrow.clockwise").font(.caption.bold()) }
                        }.frame(minHeight: 44)
                    }
                    .foregroundStyle(CommonsTheme.red)
                    .disabled(store.isLoading)
                    .accessibilityLabel("Refresh menu")
                    .accessibilityValue(store.isLoading ? "Refreshing" : "Ready")
                    .accessibilityHint("Check the latest published menu for the selected date.")
                    .accessibilityIdentifier("menu.refresh")
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
            .refreshable { await refreshMenu() }
            .sheet(isPresented: $showFilters) { FiltersView().environmentObject(store) }
            .sheet(isPresented: $showLayout) { SectionLayoutView().environmentObject(store) }
            .task(id: store.selectedDateKey) { await store.load() }
            .onChange(of: store.selectedDateKey) { _, _ in refreshConfirmation = nil }
            .onChange(of: store.selectedDateKey) { _, _ in expandedFilteredStations.removeAll() }
            .onChange(of: store.currentMeal?.id) { _, _ in expandedFilteredStations.removeAll() }
            .onChange(of: store.preferences) { _, _ in expandedFilteredStations.removeAll() }
            .onChange(of: store.searchText) { _, _ in expandedFilteredStations.removeAll() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.foreground() } }
            }
            .onReceive(minuteTick) { _ in
                if scenePhase == .active { Task { await store.foreground() } }
            }
        }
    }

    private var mealAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.2) }
    private var mealBackdropOpacity: Double { 0.02 + Double(min(store.currentMealIndex ?? 0, 3)) * 0.025 }

    @MainActor private func refreshMenu() async {
        guard !store.isLoading else { return }
        let key = store.selectedDateKey
        refreshConfirmation = nil
        await store.load(force: true)
        if !Task.isCancelled, store.selectedDateKey == key, store.currentMenu != nil, store.message == nil {
            refreshConfirmation = "Latest published menu checked."
        }
    }

    private func selectAdjacentMeal(_ direction: Int) {
        withAnimation(mealAnimation) { _ = store.selectAdjacentMeal(direction) }
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
            VStack(alignment: .leading, spacing: 10) {
                ScrollViewReader { proxy in
                    mealTabs(menu)
                        .onChange(of: store.currentMeal?.id) { _, id in
                            if let id { withAnimation(mealAnimation) { proxy.scrollTo(id, anchor: .center) } }
                        }
                        .onAppear {
                            if let id = store.currentMeal?.id { proxy.scrollTo(id, anchor: .center) }
                        }
                }
                if menu.meals.count > 1 {
                    Label("Swipe the menu to change meals", systemImage: "arrow.left.and.right")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24)
                }
            }
        }
    }

    private func mealTabs(_ menu: DayMenu) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(menu.meals) { meal in mealButton(meal) }
            }.padding(.horizontal, 20)
        }
    }

    private func mealButton(_ meal: MenuMeal) -> some View {
        let selected = store.currentMeal?.id == meal.id
        return Button {
            withAnimation(mealAnimation) { _ = store.selectMeal(named: meal.name) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
                Text(meal.name)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16).frame(minHeight: 46)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background {
                if selected {
                    Capsule().fill(CommonsTheme.red)
                        .matchedGeometryEffect(id: "selectedMeal", in: mealSelection)
                } else { Capsule().fill(CommonsTheme.card) }
            }
            .overlay { Capsule().strokeBorder(selected ? CommonsTheme.red : Color.secondary.opacity(0.15)) }
        }
        .buttonStyle(MealButtonStyle())
        .id(meal.id)
        .accessibilityLabel(meal.name)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("meal.\(meal.name)")
    }

    @ViewBuilder private var menuContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let meal = store.currentMeal {
                HStack {
                    Text(meal.name).font(.title2.bold()).accessibilityIdentifier("meal.current")
                    Spacer()
                    Button { showLayout = true } label: {
                        Label("Organize", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline.weight(.semibold))
                    }
                    .disabled(store.sectionNames.isEmpty)
                    .accessibilityLabel("Organize sections")
                    .accessibilityIdentifier("layout.open")
                }
            }
            if let confirmation = refreshConfirmation {
                Label(confirmation, systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("refresh.confirmation")
            }
            if let message = store.message {
                VStack(alignment: .leading, spacing: 10) {
                    Label(message, systemImage: "wifi.exclamationmark").font(.subheadline)
                    Button("Retry refresh") { Task { await refreshMenu() } }.font(.subheadline.bold())
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
                } else if store.searchedStations.isEmpty {
                    EmptyMenuView(symbol: "line.3.horizontal.decrease.circle", title: "No matching dishes", detail: "Try another meal, change your filters, or clear your search.")
                    if !store.searchText.isEmpty { Button("Clear search") { store.searchText = "" } }
                    Button("Edit dietary filters") { showFilters = true }
                } else {
                    HStack {
                        Text("\(store.visibleCount) \(store.visibleCount == 1 ? "matching dish" : "matching dishes")").font(.headline)
                        Spacer()
                        if store.preferences.count > 0 {
                            Button("Filters on") { showFilters = true }.font(.caption.weight(.semibold))
                        }
                    }
                    if store.preferences.halalPotentiallySuitable {
                        Label("Potentially suitable • not halal certified", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(store.searchedStations) { station in stationCard(station) }
                        .id(store.currentMeal?.id)
                        .transition(.opacity)
                }
            } else if !store.isLoading {
                EmptyMenuView(symbol: "fork.knife", title: "Menu unavailable", detail: "Connect to load this date. Previously loaded dates remain available offline.")
            }
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menu.content")
        .accessibilityAction(named: Text("Next meal")) { selectAdjacentMeal(1) }
        .accessibilityAction(named: Text("Previous meal")) { selectAdjacentMeal(-1) }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 65, abs(horizontal) > abs(vertical) * 1.4 else { return }
                selectAdjacentMeal(horizontal < 0 ? 1 : -1)
            }
        )
    }

    private func stationCard(_ station: MenuStation) -> some View {
        let collapsed = store.layout.isCollapsed(station.name)
        let matching = station.items.filter { store.preferences.includes($0) }
        let excluded = station.items.filter { !store.preferences.includes($0) }
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(mealAnimation) { store.layout.setCollapsed(!collapsed, for: station.name) }
            } label: {
                HStack(spacing: 10) {
                    Rectangle().fill(CommonsTheme.red).frame(width: 4, height: 18)
                    Text(station.name).font(.title3.bold()).foregroundStyle(.primary)
                    Spacer()
                    Text("\(matching.count)").font(.caption.bold()).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
                        .rotationEffect(.degrees(collapsed ? 0 : 90))
                }.padding(16).frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(station.name)
            .accessibilityValue(collapsed ? "Collapsed" : "Expanded")
            .accessibilityHint(collapsed ? "Show dishes in this section." : "Hide dishes in this section.")
            .accessibilityIdentifier("section.toggle.\(station.name)")
            if !collapsed {
                ForEach(matching) { item in dishLink(item, station: station, excluded: false) }
                if !excluded.isEmpty {
                    Divider().padding(.horizontal, 16)
                    DisclosureGroup(isExpanded: Binding(
                        get: { expandedFilteredStations.contains(station.id) },
                        set: { expanded in
                            if expanded { expandedFilteredStations.insert(station.id) }
                            else { expandedFilteredStations.remove(station.id) }
                        }
                    )) {
                        ForEach(excluded) { item in dishLink(item, station: station, excluded: true) }
                    } label: {
                        Text("\(excluded.count) \(excluded.count == 1 ? "dish hidden" : "dishes hidden") by dietary filters")
                            .font(.subheadline.weight(.medium))
                    }
                    .tint(CommonsTheme.red)
                    .padding(16)
                    .accessibilityIdentifier("filtered.\(station.name)")
                }
            }
        }.background(CommonsTheme.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private func dishLink(_ item: MenuItem, station: MenuStation, excluded: Bool) -> some View {
        let reasons = excluded ? store.preferences.exclusionReasons(for: item) : []
        return VStack(alignment: .leading, spacing: 0) {
            if !excluded { Divider().padding(.horizontal, 16) }
            NavigationLink {
                ItemDetailView(item: item, station: station.name, meal: store.currentMeal?.name ?? "", filterReasons: reasons)
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    MenuItemRow(item: item, showHalal: store.preferences.halalPotentiallySuitable && !excluded)
                    if excluded {
                        Label("Excluded by your dietary filters", systemImage: "exclamationmark.circle")
                            .font(.caption.bold()).foregroundStyle(CommonsTheme.red)
                            .padding(.horizontal, 16)
                        Text(reasons.joined(separator: " "))
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 16).padding(.bottom, 12)
                    }
                }
            }.buttonStyle(.plain)
        }
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

private struct MealButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
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
