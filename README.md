# Commons

A SwiftUI iPhone app for the [MSOE Robert Spitzer Dining Commons menu](https://msoedining.sodexomyway.com/en-us/locations/the-dining-commons). Red/black styling, date and meal navigation, station cards, search, ingredients, nutrition, and locally saved dietary preferences.

## Shared daily menu service

```text
Sodexo menu widget
    ↓ one scheduled publisher, daily
GitHub Actions → validated JSON → GitHub Pages
                                    ↓
                         all iPhones → offline cache
```

The `Publish daily menus` workflow runs at **4:23 a.m. America/Chicago** and supports manual runs from GitHub's Actions tab. It discovers the public widget configuration once, retrieves yesterday through the next 14 days, validates every response, and publishes 16 date snapshots together. If a request or validation fails, deployment stops and the previous successful publication remains available.

The phones download an already-built JSON file; they do not access Sodexo for menu updates. No API key is included in the app or published snapshots. Source discovery uses only the website's public widget client key, in memory, on the publisher. Private authentication configuration is not extracted or used.

- Shared feed: `https://aceher-1.github.io/cc_app/api/YYYY-MM-DD.json`
- Publication metadata: [manifest.json](https://aceher-1.github.io/cc_app/manifest.json)
- One file contains every meal and station for that date. Searching, changing meals, and filtering use local data.
- Each iPhone downloads requested dates once per Chicago calendar day, persists them across restarts, and retains cached data offline. Pull-to-refresh checks the shared service again; it does not trigger an upstream scrape.
- The app displays the publisher's actual update timestamp, separately from the device's download time. If opened before the daily publication, it preserves the stale snapshot and retries at most hourly while active until today's snapshot appears. Failed requests retry at most once per five minutes; manual refresh bypasses the throttle.
- Midnight/foreground checks roll over the selected day. Previously requested dates remain available offline; caches older than 30 days are pruned. An unavailable date never substitutes another date's menu.
- Preferences stay on the iPhone; they are not sent to the service.

GitHub Pages is static hosting, so it needs no running database or application server. GitHub scheduled jobs can be delayed or dropped under load, and public-repository schedules are disabled after 60 days without repository activity. Check Actions periodically and re-enable the schedule if necessary. For unattended production reliability, the same publisher can run on a dedicated scheduler/object-storage service; change `SharedMenuService.defaultBaseURL` to the new host. See [GitHub schedule behavior](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule).

Sodexo's widget/feed is undocumented and can change. Source changes produce errors rather than invented dishes. Menu content and labels belong to the provider.

## Run on iPhone

See [INSTALL.md](INSTALL.md) for step-by-step **Windows-to-iPhone installation**, signing renewal, or direct installation from a Mac. The **Build iPhone IPA** manual workflow provides a release `arm64` device build; the unsigned IPA must be signed locally before an iPhone can run it. No Apple signing credentials are uploaded to GitHub.

1. On a Mac, use an Xcode version that supports the phone's iOS version (for iOS 26.2, Xcode 26.2 or a newer compatible stable version), and open **Commons.xcodeproj**.
2. Choose the **Commons** scheme and an installed iPhone simulator, then Run. Minimum iOS version: **17**.
3. For a physical iPhone, choose your Apple development team under Signing & Capabilities and replace `com.example.msoecommons` with your own bundle identifier, then select your iPhone and Run.

The Xcode project, shared scheme, and original geometric icon are included. No third-party iOS dependencies or XcodeGen setup is required. `python tools/generate_project.py` regenerates the project if source files are added.

## Test from Windows

Windows can run the publisher's deterministic tests and live source check with Python 3.9+:

```powershell
python -m unittest discover -s tools/tests -v
python tools/check_source.py 2026-10-11
python tools/refresh_menus.py --date 2026-10-11 --output _site
```

Omit `--date` to use the current Chicago day when Python has timezone data installed. Windows Python installations without timezone data can pass the date explicitly or install `tzdata`.

The pure Foundation core is separated into a Swift package. After installing [Swift for Windows and its platform dependencies](https://www.swift.org/install/windows/), run `swift test` to exercise the actual parser, dietary logic, preferences, and cache. Windows cannot run the native SwiftUI iPhone UI or Apple's iOS Simulator; [Simulator ships with Xcode](https://help.apple.com/xcode/mac/current/en.lproj/devfd9e28378.html).

The **iOS checks** GitHub workflow builds and tests the native app on a macOS iPhone simulator. It includes a UI test that changes the halal filter and verifies it survives relaunch. Open the workflow run from Windows and download **iphone-test-results** to view `iphone-preview.png`, the other PNG screenshots in `screenshots/`, and the build log. Screenshots use explicitly labeled synthetic test dishes; release builds use the live shared service. Full `.xcresult` bundles can be inspected with Xcode on a Mac. The **Export native test screenshots** workflow also converts an existing run's results into Windows-readable images when supplied its run ID.

On macOS:

```sh
swift test
xcodebuild test -project Commons.xcodeproj -scheme Commons \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

Use an installed simulator name if different. Tests cover malformed source data, duplicate source IDs, missing/unknown allergens, filter intersections, halal screening, persistence, disk corruption, daily rollover, offline retention, retry throttling, and shared-feed date/timestamp checks.

## Dietary logic

Filters save immediately and restore in the next session.

- All 12 Sodexo allergen exclusions: eggs, fish, gluten, milk, mustard, peanut, sesame, shellfish, soy, sulphites, tree nuts, wheat.
- All four Sodexo diet labels: Mindful, Plant Based, Vegan, Vegetarian. Every selected label must be present; allergen exclusions and diet requirements combine.
- Missing or unrecognized allergen data is hidden while allergen exclusions are active. “None listed” is not an allergen-free guarantee; shared equipment and substitutions need confirmation with dining staff.

**Halal: potentially suitable** is a conservative ingredient screen, not certification. It requires ingredients and a provider vegetarian/vegan/plant-based label. It checks whole words in names, descriptions, and ingredients for pork, gelatin, animal rennet, and alcohol. Unverified meat, seafood, missing ingredients, and unlabeled dishes need confirmation. Wine/sherry/champagne vinegar names alone are not treated as beverage alcohol; alcohol-containing extracts are flagged. Imitation meats can be conservatively hidden when their wording includes meat terms.

Dish details show the result and reason. Enzymes, flavorings, ingredient sources, slaughter, and preparation are unverified. No dish is displayed as “halal certified.” The rules are in `Commons/Core/HalalAssessment.swift`.

## Layout

`Commons/Core`: models, parser, screening, preferences, dates, disk cache. `Commons/Services`: shared JSON client. `MenuStore.swift`: daily refresh coordination. `Commons/Views`: SwiftUI screens. `CommonsTests` and `CommonsUITests`: native tests and synthetic fixtures. `tools/refresh_menus.py`: central publisher. `.github/workflows/menus.yml`: schedule and Pages deployment.

This is an independent student project. No university logo is bundled.
