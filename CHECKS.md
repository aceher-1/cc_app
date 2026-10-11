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
