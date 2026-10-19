# Publish MSOE Dining from Windows

**Version 1.2 widget update:** first follow [WIDGETS.md](WIDGETS.md) to enable the shared App Group and add `APPLE_WIDGET_PROFILE_BASE64`. The main app's profile must also be regenerated with the group enabled. The existing certificate and API key can be reused. Version 1.1 under review is unaffected.

The app now uses **com.aceher.msoedining**, with **MSOE Dining** as its Home Screen name. The [Upload to TestFlight](https://github.com/aceher-1/cc_app/actions/workflows/testflight.yml) action builds an App Store archive, signs it, and uploads it to Apple. It does not submit the app for public review or release it automatically.

Apple credentials are not included in the repository. The first signed upload needs the one-time setup below. Enter private values directly in GitHub's encrypted Actions secrets, not in a source file, issue, or chat.

## 1. Confirm your Apple listing

In [App Store Connect](https://appstoreconnect.apple.com/), open your app's App Information page and confirm **com.aceher.msoedining**. Your developer membership and agreements must be active. Find your 10-character **Team ID** under [Apple Developer membership details](https://developer.apple.com/account).

The current app version is **1.1**. Use version 1.1 on the Distribution page when selecting this build for review. TestFlight will show the uploaded version independently of the store version you are editing.

## 2. Create your signing certificate on Windows

You need **PowerShell 7.2 or newer** (the `pwsh` command), not the older Windows PowerShell 5 app. If `pwsh` is not recognized, install PowerShell using [Microsoft's Windows instructions](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows), then open a new terminal. Open PowerShell in your local `cc_app` folder.

Create a signing request and an encrypted private key in a folder outside the repository:

```powershell
pwsh -File tools/apple_signing_windows.ps1 -Mode request -OutputDirectory "$env:USERPROFILE\CommonsSigning"
```

Choose and save the password when prompted. Keep the private key and this password; you will need them to package the certificate. The helper refuses to overwrite an existing key.

In [Apple Developer → Certificates](https://developer.apple.com/account/resources/certificates/list):

1. Click **+** and choose **Apple Distribution**.
2. Upload `distribution.certSigningRequest` from your `CommonsSigning` folder.
3. Download Apple's certificate, usually named `distribution.cer`, into that same folder.
4. Run:

```powershell
pwsh -File tools/apple_signing_windows.ps1 -Mode export -OutputDirectory "$env:USERPROFILE\CommonsSigning" -CertificatePath "$env:USERPROFILE\CommonsSigning\distribution.cer"
```

Enter the private-key password, then choose a password for the resulting **distribution.p12**. That P12 includes the certificate and its matching private key. A `.cer` file by itself is insufficient for signing. Back up the encrypted signing files and passwords securely; you can reuse this certificate rather than creating one on every build.

## 3. Download an App Store distribution profile

In [Apple Developer → Profiles](https://developer.apple.com/account/resources/profiles/list):

1. Click **+**, then choose **App Store Connect** under Distribution.
2. Select **com.aceher.msoedining**.
3. Select the Apple Distribution certificate you just created.
4. Name the profile **MSOE Dining App Store**, generate it, and download it into `CommonsSigning`.

Use an App Store Connect profile, not Development or Ad Hoc. The workflow checks its app identifier, team, expiry, and matching signing identity.

## 4. Create an Apple upload key

In App Store Connect, open **Users and Access → Integrations → App Store Connect API → Team Keys**. Request API access if Apple prompts you to do so. Generate a team key with **App Manager** access. Download its `.p8` file once and save it securely outside the repository.

Record its **Key ID** and the page's **Issuer ID**. This API key authorizes uploads; it is separate from the distribution certificate used to sign the app. Your Apple Account password is not needed by the workflow.

## 5. Add the secrets to GitHub

Open [this repository's Actions secrets](https://github.com/aceher-1/cc_app/settings/secrets/actions), select **New repository secret**, and add each name exactly as listed:

| Secret name | What to enter |
| --- | --- |
| `APPLE_TEAM_ID` | Your 10-character developer Team ID |
| `APPLE_DISTRIBUTION_P12_BASE64` | Base64 text of `distribution.p12` |
| `APPLE_DISTRIBUTION_P12_PASSWORD` | The P12 password you chose |
| `APPLE_PROFILE_BASE64` | Base64 text of the downloaded App Store `.mobileprovision` file |
| `ASC_KEY_ID` | The upload key's Key ID |
| `ASC_ISSUER_ID` | Its Issuer ID |
| `ASC_PRIVATE_KEY` | The entire `.p8` file, including its BEGIN/END lines and real line breaks |

To copy a file's Base64 text without printing it in the terminal, run this in PowerShell, adjusting the path as needed:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\CommonsSigning\distribution.p12")) | Set-Clipboard
```

Paste into the matching GitHub secret. Repeat for the `.mobileprovision` file. For the `.p8` key use the file's actual text, not Base64:

```powershell
Get-Content -Raw "$env:USERPROFILE\CommonsSigning\AuthKey_YOURKEYID.p8" | Set-Clipboard
```

The workflow installs signing credentials in a temporary keychain and removes them afterward. Private keys and profile files are excluded from source control. Release artifacts contain the IPA and build logs, never the P12 or `.p8` private key.

## 6. Run the upload

1. Open [Upload to TestFlight](https://github.com/aceher-1/cc_app/actions/workflows/testflight.yml).
2. Click **Run workflow**, select **codex/initial-app**, and leave destination set to **testflight**.
3. Start the run and wait for its green checkmark.
4. Open your app in App Store Connect → **TestFlight**. Allow Apple time to process the build; upload success does not mean processing or review has finished.
5. Add yourself as an internal tester, install Apple's TestFlight app on your iPhone, and test the release.

The workflow assigns a build number such as `2001.1`; subsequent runs and reruns get distinct numbers. The version stays 1.1 until changed in the project generator. If you have already uploaded a higher build number outside this workflow, adjust its numeric base before your next upload.

Other destination choices:

- **signed-download:** signs and exports the IPA into the `commons-app-store-release` artifact without uploading. Needs the four signing secrets but no upload API key.
- **archive-check:** verifies the archive, app identifier, device architecture, encryption declaration, and SDK without Apple credentials. Its output is unsigned and cannot be submitted to Apple.

The older **Build iPhone IPA** workflow remains an unsigned sideloading download. Use **Upload to TestFlight** for the App Store path.

## 7. Finish the listing and request review

Complete the description, screenshots, support and public privacy-policy URLs, age rating, privacy answers, content rights, pricing, and availability. The app uses Apple's HTTPS networking and declares no non-exempt encryption; review export-compliance answers against your actual distribution plans. Verify permission to use provider content and branding. Explain that the project is independent and its halal screen means potentially suitable, not certified.

Test live menu loading, offline access, saved filters, hidden-food dropdowns, and meal navigation on your iPhone. After Apple processes the upload, select version 1.1's build under Distribution, click **Add for Review**, and submit. Choose automatic or manual release after approval. Keep the shared menu publisher active and monitor failures.

Changing from the old sideloaded bundle identifier creates a separate app on the phone; its existing local preferences will not automatically transfer to this new app identity.

References: [Apple uploads](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [distribution profiles](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/), [GitHub signing](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications), [Apple encryption declaration](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption).
