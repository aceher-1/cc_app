# Widgets in version 1.2

This update is developed on `codex/widgets-1.2`. It does not replace or submit a new build over version 1.1 currently under Apple review. Upload version 1.2 to TestFlight after the signing setup below, test it on an iPhone, then create a new App Store version when ready.

## What users get

- Small (2×2): a few current food options and a countdown to the next scheduled meal. Between services it previews the upcoming meal instead.
- Medium (4×2): current and next meal previews, plus the same countdown. Tap either meal to open its full menu.
- Weekends: Brunch for the day, with “Hours unavailable” and no guessed countdown.
- Both sizes apply the app's saved dietary filters and section order. No matching foods produces an explicit empty state. Collapsed app sections do not exclude food from the widget.

Open the updated app once to share your existing preferences. On the iPhone Home Screen, touch and hold an empty area, choose Edit → Add Widget, search for MSOE Dining, select a size, and add it. Newer iOS versions may label these controls slightly differently.

Settings stay local. The app copies dietary and layout settings to its shared App Group container; it does not upload them. The widget downloads only shared JSON menus and meal hours from GitHub Pages. There are no accounts, push servers, or analytics. Local widget menu caches are pruned after 30 days, like the app's cache.

## Meal hours

`public/meal-hours.json` is published by the existing menu workflow. Weekday times follow the posted Savory entrée service on the [source dining page](https://msoedining.sodexomyway.com/en-us/locations/the-dining-commons): Breakfast 7–10 a.m., Lunch 11 a.m.–2 p.m., Dinner 4–8:30 p.m., all in America/Chicago. Individual stations may differ. The widget labels its countdown “Scheduled”; it does not claim live kitchen status.

The file's `verifiedOn` and `validThrough` limit how long these regular hours can be used. Recheck the source before extending the expiry. After expiry or when hours cannot be loaded, the widget shows “Hours unavailable.” Weekend hours are deliberately omitted. A date override replaces regular hours, for example:

```json
"overrides": {
  "2026-11-26": [],
  "2026-11-27": [{"meal":"Lunch","start":"11:00","end":"13:00"}]
}
```

An empty array means confirmed closed. These example holidays are illustrative, not verified closures. Before public release, check breaks and special hours and populate any known overrides. Widget timelines handle meal boundaries and midnight; iOS decides when network refreshes run, so immediate changes are not guaranteed. A built-in timer renders the countdown without repeated downloads. Cached source data is marked when outdated.

## One-time Apple setup for this update

Do this on the Apple Developer website; no Mac is required:

1. Under Certificates, Identifiers & Profiles → Identifiers, register an **App Group** named `group.com.aceher.msoedining`.
2. Edit the existing App ID `com.aceher.msoedining`. Enable App Groups and assign that group. Keep the same bundle ID so installed users receive an update.
3. Register an explicit App ID `com.aceher.msoedining.widgets`, enable App Groups, and assign the same group. This is an embedded extension, not a separate App Store app listing.
4. Regenerate the main app's **App Store Connect distribution profile** with App Groups enabled, using the existing distribution certificate. Download it and replace the repository secret `APPLE_PROFILE_BASE64` with its Base64 content.
5. Create an **App Store Connect distribution profile** for the widget App ID, using that same certificate. Download it and add its Base64 content as the new repository secret `APPLE_WIDGET_PROFILE_BASE64`.
6. Keep the existing P12, password, team ID, and App Store Connect API secrets. No new certificate or API key is required.
7. After checks pass, merge this update into `codex/initial-app` so its daily menu publisher includes `meal-hours.json`. GitHub Pages allows deployment only from that default branch; feature branches build menu data but do not publish it. Wait for the menu publication to succeed.
8. Run **Upload to TestFlight** from the updated default branch. Start with **signed-download** if you want to inspect the signed release before uploading. The workflow validates both profiles, the shared group, and the certificate, then signs and embeds the extension.

The app and widget both use version 1.2 and the same CI build number. Secrets never belong in source control. Old profiles without App Groups will deliberately fail validation with instructions instead of producing a broken widget.

## Checks

Core tests cover meal boundaries, gaps, tomorrow transitions, weekend behavior, expired hours, closure overrides, daylight saving time, dietary filtering, section order, stale menus, shared storage, and deep-link contents. The cloud iOS checks compile the embedded widget as part of the app and run the existing app tests.

Before release, also verify both sizes on a real iPhone: launch the app once, change filters, tap each medium-widget meal, check weekend Brunch, and check a meal transition. Simulator compilation and model tests cannot prove iOS will refresh a Home Screen widget at an exact time.
