# Verification

Verified October 11, 2026, using Windows locally and GitHub's macOS runner.

- Live source discovery and menu-schema check passed for `2026-10-11`: Breakfast (5 dishes), Brunch (29), Dinner (26), 60 dishes total across 15 stations.
- All 18 Swift files (app, tests, package manifest) passed a tree-sitter Swift syntax parse.
- Privacy manifest parsed as a plist; shared Xcode scheme parsed as XML; asset and fixture JSON parsed successfully.
- Every app and test Swift source is included in the generated Xcode project.
- The Xcode project passed OpenStep parsing, object-reference checks, and file-path validation.
- Python tooling passed bytecode compilation.

- Three publisher tests passed locally on Windows: complete date coverage, retention on upstream failure, and rejection of malformed schemas.
- The live publisher fetched and validated all 16 dates (yesterday through the next 14 days).
- The [publication workflow](https://github.com/aceher-1/cc_app/actions/runs/38171417113) passed and deployed to GitHub Pages. Public HTTP verification confirmed the manifest and today's 60-dish snapshot are accessible.
- The [final native workflow](https://github.com/aceher-1/cc_app/actions/runs/38172657136) passed on macOS for commit `9d43c5e`: Swift package tests, Xcode app build, iPhone unit tests, UI filtering and persistence through relaunch, and Windows-readable PNG export.
- The [separate screenshot-export workflow](https://github.com/aceher-1/cc_app/actions/runs/38172712519) also passed. The filtered menu screenshot was reviewed locally.
- The [physical-iPhone release build](https://github.com/aceher-1/cc_app/actions/runs/38173657607) passed for commit `1dababa` using Xcode 16.4 / iPhoneOS SDK 18.5. The `commons-iphone-ipa` artifact contains `Commons-unsigned.ipa`. Its SHA-256 checksum, ZIP layout, Info.plist (`iPhoneOS`, minimum iOS 17.0), and Mach-O `arm64` architecture were independently verified after download on Windows. It is unsigned and must be signed/provisioned locally; installation and launch on a physical iPhone have not yet been verified.

The earlier [iOS checks run #3](https://github.com/aceher-1/cc_app/actions/runs/38172039296) passed its app build and tests. It failed only in the post-test screenshot helper: `simctl launch` reported `Unable to lookup in current state: Shutdown` and exited 149. Xcode's test runner used a simulator clone while the helper targeted the original, shut-down simulator. Run #4 removed that helper and exports screenshots already captured by XCTest; its complete workflow passed.

The two final wording edits (singular “dish” and shared-service error wording) were syntax checked after the native workflow; they do not change app behavior. The documentation/wording commit skips duplicate CI. Windows itself has no Xcode or native iOS simulator; the native checks above ran on a cloud Mac. The screenshot fixtures are synthetic and explicitly named as samples; normal and release launches use the published live feed.

## Version 1.1 customization

Verified October 12, 2026.

- Local checks confirmed every app/test source is included in the regenerated project, all project object references resolve, the shared scheme and privacy manifest parse, assets are valid JSON, and version metadata is 1.1 (build 2).
- The three central-publisher tests still pass locally on Windows.
- The [final version 1.1 device build](https://github.com/aceher-1/cc_app/actions/runs/38291807453) passed for commit `b143ae1`. After downloading its `commons-iphone-ipa` artifact, independent checks verified the SHA-256 checksum, iPhoneOS platform, minimum iOS 17.0, ARM64 executable, version 1.1/build 2, and absence of the sample-oatmeal fixture string in the release executable. Binary inspection also confirmed the corrected UTF-8 footer labels and absence of the four garbled sequences. Local signing and physical-phone launch still require the user's device.
- The [final version 1.1 native checks](https://github.com/aceher-1/cc_app/actions/runs/38290305744) passed for commit `f3fc1a8`: 13 Swift package tests, 19 iPhone unit tests, and all four UI tests. UI automation performed an actual section-handle drag and verified order after relaunch; it also checked collapse persistence across refresh/relaunch, layout reset, dish navigation, meal buttons, left/right meal swipes and boundaries, vertical scrolling, refresh feedback, and saved halal preferences.
- The final PNG screenshots were downloaded and reviewed, including the reordered sections after relaunch. Visual review exposed four garbled punctuation literals introduced during a Windows file edit. Those literals were restored to valid UTF-8 after the native tests; all app sources passed a check for the garbled sequences. This final correction changes display text only.


## Xcode 26.2 build environment

Verified October 12, 2026 (America/Chicago), commit `4f5e62e`.

- Both native build workflows explicitly select Xcode 26.2 and check that the physical-device SDK is 26.2 before building. The screenshot recovery workflow also selects the matching Xcode version.
- The [iPhone release build](https://github.com/aceher-1/cc_app/actions/runs/38337090992) passed, including ARM64 and iOS platform checks and unsigned IPA packaging. The downloaded artifact checksum was independently verified, and its Info.plist records DTXcode 2620, iphoneos26.2, minimum iOS 17.0, version 1.1, build 2.
- The [native checks](https://github.com/aceher-1/cc_app/actions/runs/38337090522) passed, including Swift package tests, iPhone simulator app/unit/UI tests, and screenshot export.
- No app source changes or minimum-iOS increase were necessary. Signing, App Store upload, physical-device testing, and Apple review are still outstanding; see APP_STORE.md. The separate manual screenshot recovery workflow was configured but not rerun.


## Inspecting dietary exclusions

Verified October 13, 2026, commit `2964122`.

- The [device build](https://github.com/aceher-1/cc_app/actions/runs/38406706652) passed and provides a new unsigned IPA with per-station filtered-food dropdowns.
- The [native checks](https://github.com/aceher-1/cc_app/actions/runs/38406706522) passed. UI automation enabled the halal filter, verified the hidden count, opened and closed the dropdown, checked the excluded warning, and confirmed hidden dishes were closed again after relaunch while filters remained saved. Existing customization and navigation checks also passed.
- A new store test verifies that an entirely excluded station stays inspectable, search restricts hidden items without changing filters, exclusion reasons exist, and no extra fetch occurs.
- A test screenshot was downloaded; the dropdown label and matching-dish counts render correctly. Revealed content below the viewport was verified by UI assertions.
- The shared-menu publisher was manually refreshed successfully in [this run](https://github.com/aceher-1/cc_app/actions/runs/38406176773). The deployed manifest timestamp is 2026-10-13T13:35:28Z. Live source and published October 13 lunch both contained All Beef Hot Dog before refreshing; it was excluded by the enabled halal filter rather than missing from publication.


## App Store identity and release workflow

Verified October 15, 2026.

- The project and generator use `com.aceher.msoedining`; test identifiers use matching suffixes. The Home Screen name is MSOE Dining. The app retains minimum iOS 17 and version 1.1, and declares no non-exempt encryption for its system HTTPS networking.
- The [release archive check](https://github.com/aceher-1/cc_app/actions/runs/38801763233) passed for app-source commit `d8333e5`. Downloaded archive metadata confirms the registered identifier, build 2001.1, and iphoneos26.2 SDK. The archive also passed ARM64 and encryption-declaration assertions. Apple's installed uploader supports validation, upload, and API-key authentication.
- Six Python checks passed, including mismatched app/team, expired or non-store profiles, and missing matching private-key identity. All release workflow shell blocks passed Bash syntax checking. The Windows helper passed an encrypted-key/CSR/P12 round trip using a synthetic self-signed certificate, with temporary test material removed.
- Native [iOS 26.2 checks](https://github.com/aceher-1/cc_app/actions/runs/38804950191) passed 13 package tests, all 20 native unit tests, and three of four UI tests. The reordering UI test failed; recordings showed a drag ending outside the destination row. The test now uses an interior drop point and waits for the order to change. One focused attempt also timed out launching the cold simulator.
- The [final focused reordering check](https://github.com/aceher-1/cc_app/actions/runs/38807754568) passed for `3715ba0`, including reordering and persistence after relaunch. CI now selects the iOS SDK's matching simulator, explicitly boots it, disables parallel simulator clones, and supports focused manual checks. The full suite was not rerun after these test/environment-only corrections; the app source is unchanged from the successful release archive.
- No real Apple signing or upload credentials were available or committed. Signed export, Apple validation, TestFlight upload, physical-device testing, and public App Review remain pending the owner's credential setup. See APP_STORE.md for the seven encrypted GitHub Secrets and Windows-only setup steps. The existing unsigned sideloading workflow remains separate.
