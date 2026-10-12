# Install Commons on your iPhone

Commons supports iPhone running iOS 17 or later, including iPhone 15 on iOS 26.2. It is currently a development app, with no App Store listing or TestFlight invitation.

## From Windows

GitHub builds the release app on a cloud Mac. You download the unsigned device IPA and sign/install it locally with your own Apple Account using Sideloadly. This does not require jailbreaking or a paid developer membership. Sideloadly documents support for iOS 26+, but installation and signing on your physical phone still need to be verified there.

1. Sign in to GitHub on your Windows PC. Open [Build iPhone IPA](https://github.com/aceher-1/cc_app/actions/workflows/device-build.yml).
2. Open the newest successful run. Under **Artifacts**, download **commons-iphone-ipa**. Extract the ZIP in File Explorer. The file you will install is **Commons-unsigned.ipa**, not the ZIP and not the simulator test artifact.
3. If no artifact is available, choose **Run workflow**, select **codex/initial-app**, and run it. Wait for the green check, then return to step 2. Artifacts are kept for 30 days.
4. Install the Windows version of [Sideloadly from sideloadly.io](https://sideloadly.io/). Follow its Windows prerequisites for the Apple website versions of iTunes and iCloud; the provider warns against their Microsoft Store versions. Use the links on that official page.
5. Connect the iPhone 15 to the PC with a USB-C data cable. Unlock it, tap **Trust** on **Trust This Computer?**, and enter your phone passcode. Check that iTunes recognizes the phone.
6. Open Sideloadly. Select your iPhone from its device list, drag **Commons-unsigned.ipa** into the app/IPA area, and enter your Apple Account email. Keep normal Apple Account signing and the default app options. If offered, enable automatic refresh.
7. Click **Start**. Enter your Apple Account password and verification code in Sideloadly's local prompts if requested. No Apple password or signing certificate needs to be added to this GitHub repository. Wait for installation to finish.
8. On the phone, open **Settings → General → VPN & Device Management**. Under **Developer App**, select the Apple Account used to install Commons and trust it. Follow any verification or restart prompts. If that entry is absent, finish installation first.
9. Enable **Settings → Privacy & Security → Developer Mode**. Allow the restart, unlock the phone, confirm **Turn On**, and enter your passcode if prompted. If Developer Mode is initially absent, attempt the developer-app installation first and recheck Settings. Apple documents that the setting appears after initiating development pairing/installation.
10. Open **Commons** on your Home Screen with an internet connection. It downloads the published daily menu; set your dietary filters once. They save on your phone.

Version 1.1 adds **Organize** beside the meal heading, collapsible station headers, clearer meal selection, left/right meal swipes, and the **MSOE ↻** refresh button. To update from an earlier build, download the newest IPA and repeat the installation with the same Apple Account and bundle identifier, overwriting the existing app to keep preferences.

With a free Apple Account, signing expires after **seven days**. Sideloadly's automatic refresh needs the PC running and the phone reachable over USB or configured Wi-Fi sync. For Wi-Fi: in iTunes, select the connected phone, open **Summary → Options**, enable **Sync with this iPhone over Wi-Fi**, and apply/sync. Keep both devices on the same network. Alternatively, repeat the installation before expiry using the same Apple Account and bundle identifier, overwriting the app. Do not delete Commons to refresh it: deletion removes its saved preferences/cache.

Signing refresh and menu refresh are separate. You do not rebuild or reinstall the app for each day's menu. The central publisher updates the shared feed once daily; Commons downloads that data when used.

If no device appears in Sideloadly, check cable/data support, unlock/trust the phone, and verify iTunes sees it. If an installation fails, retain the exact Sideloadly error. A successful IPA build proves device compilation and packaging; it cannot prove Apple Account provisioning or successful launch on your phone.

Sources: [Sideloadly setup and downloads](https://sideloadly.io/), [Sideloadly FAQ: signing, trust, refresh](https://sideloadly.io/faq.html), [Apple: Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device), [Apple: free Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account/).

## With access to a Mac

1. Install **Xcode 26.2 or a newer compatible stable Xcode**. Xcode 26.2 includes the iOS 26.2 SDK and requires macOS Sequoia 15.6 or later. See [Apple's Xcode 26.2 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-26_2-release-notes).
2. Download/clone [this repository](https://github.com/aceher-1/cc_app) and open **Commons.xcodeproj** in Xcode.
3. In **Xcode → Settings → Accounts**, add your Apple Account.
4. Select the blue **Commons** project in the navigator, then the **Commons** app target. In **Signing & Capabilities**, keep **Automatically manage signing** enabled and select your team (a free account appears as **Personal Team**). Change the bundle identifier to a unique value, for example `com.aceher.commons.personal`.
5. Connect/unlock the iPhone, trust the Mac, and select the physical iPhone as the destination beside the **Commons** scheme. Wait for pairing/device preparation to finish.
6. Enable Developer Mode as described above, including the restart and confirmation.
7. Choose **Product → Run** (Command-R). Xcode builds, signs, and installs Commons. Follow any trust prompts on the phone.
8. Open Commons. With a free Personal Team, repeat Run to renew provisioning every seven days; reinstall over the existing app to retain preferences.

For simple installation by friends or classmates, a future TestFlight release would require Apple Developer Program membership and a signed App Store Connect upload. TestFlight distribution is not configured in this repository yet.
