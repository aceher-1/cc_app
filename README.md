# Commons

A native SwiftUI iPhone app for the [MSOE Robert Spitzer Dining Commons menu](https://msoedining.sodexomyway.com/en-us/locations/the-dining-commons). Red, black, and white styling; date and meal navigation; station cards; dish search; ingredients and nutrition details.

## Run on iPhone

1. On a Mac with Xcode 15 or later, open **Commons.xcodeproj**.
2. Select the **Commons** scheme and an iPhone simulator. Press Run. Minimum deployment target: **iOS 17**.
3. For a physical iPhone, choose your Apple development team under Signing & Capabilities and change `com.example.msoecommons` to your own bundle identifier. Select your connected iPhone and Run.

No third-party iOS dependencies, backend, account creation, API secret setup, or XcodeGen installation are required. The Xcode project and shared scheme are included. `python tools/generate_project.py` regenerates the project and original geometric app icon if source files are added.

## Menus and daily refresh

The app discovers the menu/location IDs from the source page and reads the same structured menu feed the site's JavaScript widget uses. The website's public client key is discovered at runtime from its Production configuration, never hardcoded in the repository. Private authentication configuration is neither extracted nor used. There is no HTML-browser scraping engine in the app.

- A request retrieves all meals and stations for one selected date. Switching meals, searching, and changing filters use local data.
- Menus are stored atomically under Application Support, keyed by menu date. A successful download is reused for the rest of the current **America/Chicago** calendar day, including across app restarts.
- A date first viewed after the daily boundary refreshes once. Dates can be browsed from yesterday through the next 14 days, matching the source widget's range; unpublished dates show an empty state.
- Refresh happens on first use, foregrounding, or a minute tick while the app is active. It also detects midnight while the app stays open. This app does **not** promise unattended background downloads at a fixed time; iOS controls background execution. The next foreground session obtains the daily update.
- Pull down to refresh manually, including for same-day corrections or menus posted after an earlier empty result. A manual refresh deliberately bypasses the daily cache.
- Offline or failed requests preserve the selected date's saved menu and show its timestamp and stale status. Failed automatic attempts are limited to one per five minutes, persisted across restarts. Other dates are never substituted for the requested date.
- Only requested dates are downloaded. Source configuration is discovered at most once per day in normal operation; a rotated public key permits one rediscovery. Menu caches older than 30 days are pruned.

The integration depends on Sodexo's public website schema and undocumented menu feed. A source change produces an error with a link to the original menu rather than invented dishes. Before wider distribution, confirm the provider's expectations for automated access.

## Dietary preferences

Filters save immediately in local UserDefaults and restore on the next session. No dietary preferences are sent to Sodexo or another service.

- The source's allergen exclusions: eggs, fish, gluten, milk, mustard, peanut, sesame, shellfish, soy, sulphites, tree nuts, wheat.
- The source's diet labels: Mindful, Plant Based, Vegan, Vegetarian. Every selected label must be present; exclusions and diet requirements combine.
- Missing/unrecognized allergen data is hidden when exclusions are active. An empty source allergen list means “none listed,” not an allergen-free guarantee. Shared equipment and substitutions still need confirmation with dining staff.

**Halal: potentially suitable** is a conservative ingredient screen, not certification or religious advice. It requires published ingredients and a provider vegetarian/vegan/plant-based label, checks item names, descriptions, and ingredients for whole-word pork/gelatin/animal-rennet/alcohol terms, and hides unverified meat and seafood. Missing data and unlabeled dishes need confirmation. Wine/sherry/champagne vinegar names alone are not treated as beverage alcohol. An alcohol-containing extract is flagged. Plant-based imitation meat can be conservatively hidden when its wording includes meat terms.

Each dish shows the screening result and reason. Enzymes, flavorings, ingredient sources, slaughter, and preparation are not verified. Users should confirm suitability with dining staff; no dish is displayed as “halal certified.” Rules live in `Commons/Core/HalalAssessment.swift` and can be adjusted as reliable provider information becomes available.

## Checks

On macOS:

```sh
swift test
xcodebuild test -project Commons.xcodeproj -scheme Commons \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

Choose an installed simulator name if different. Core tests cover the actual parser, duplicate upstream IDs, unknown/missing allergens, intersecting diets, halal exclusions and uncertainty, preference restoration, disk cache corruption, and Chicago midnight. App tests cover daily reuse across restarts, manual refresh, daily rollover, offline cache retention, and persisted retry throttling. GitHub Actions runs core tests and iPhone simulator tests on macOS.

Read-only live-source verification on Windows or macOS:

```sh
python tools/check_source.py 2026-10-11
```

The Python command validates discovery and the live feed shape; it does not compile Swift or test the iPhone UI. Live tests are deliberately separate from deterministic unit tests.

## Project layout

`Commons/Core` contains the data model, parser, screen, preferences, calendar, and disk cache. `Commons/Services` contains source discovery and network access. `MenuStore.swift` coordinates daily refresh and filtering. `Commons/Views` contains SwiftUI screens. `CommonsTests` contains synthetic fixtures and XCTest cases. `Package.swift` lets the core tests run without an iOS simulator.

This is an independent student project. Menu content and dietary labels belong to the dining provider. The icon is original; no university logo is bundled.
