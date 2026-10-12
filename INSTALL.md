# Install Commons on your iPhone

## Before you start

Commons works on an **iPhone running iOS 17 or later**, including iPhone 15 on iOS 26.2. Check your version in **Settings > General > About**.

You will need:

- A Windows PC or Mac with an internet connection.
- Your iPhone and a USB cable that can transfer data.
- Your Apple Account: the email and password you use for the App Store.
- A free [GitHub account](https://github.com/signup) to download the app.

**Commons is not available in the App Store yet.** You install it using a free computer app called Sideloadly. With a free Apple Account, the installation needs to be renewed every **seven days**. This guide explains how. Commons itself has no login.

## Install Commons on your iPhone

### 1. Download Commons onto your computer

1. Sign in to GitHub, then open the [Commons download page](https://github.com/aceher-1/cc_app/actions/workflows/device-build.yml).
2. Click the most recent entry with a **green check mark**.
3. Scroll to **Artifacts**. This is GitHub's name for the download area. Click **commons-iphone-ipa**.
4. Open the downloaded ZIP file. On Windows, right-click it and choose **Extract All**. On a Mac, double-click it.
5. Find **Commons-unsigned.ipa** in the extracted folder. Keep it handy for step 3.

If you cannot find the download, check that you are signed in and viewing the entry's **Summary** page. Downloads expire after 30 days; if none are available, [ask for a fresh download](https://github.com/aceher-1/cc_app/issues).

### 2. Install Sideloadly on your computer

1. Open [sideloadly.io](https://sideloadly.io/) and choose the download for Windows or Mac.
2. Install Sideloadly and follow its setup instructions.
3. **On Windows:** use the iTunes and iCloud download links on that page. Sideloadly requires those versions rather than the Microsoft Store versions; follow its instructions if you need to replace an existing installation.

### 3. Put Commons on your phone

1. Connect your iPhone to your computer with the USB cable and unlock it.
2. If the phone asks **Trust This Computer?**, tap **Trust** and enter your phone passcode.
3. Open Sideloadly. Choose your **iPhone** from its device list.
4. Drag **Commons-unsigned.ipa** into Sideloadly's app-file box.
5. Enter your **Apple Account email**, leave the other options at their defaults, and click **Start**.
6. Enter your Apple Account password and verification code in Sideloadly's prompts if asked. Wait until installation finishes.

### 4. Allow Commons to open

1. On your iPhone, go to **Settings > General > VPN & Device Management**.
2. Under **Developer App**, tap the Apple Account you used, then **Trust** it. Follow any verification or restart prompts.
3. Go to **Settings > Privacy & Security > Developer Mode** and turn it on. This lets your phone open apps installed this way.
4. Allow the restart. After the phone restarts, unlock it, confirm **Turn On**, and enter your passcode if asked.
5. Open **Commons** from your Home Screen while connected to the internet.

If Developer Mode is missing, finish the Sideloadly installation, try opening Commons, and check Settings again.

For installer help, see [Sideloadly's instructions](https://sideloadly.io/faq.html). GitHub also explains [where to find downloads](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts).

## Keep the app working

With a free Apple Account, Commons needs its installation renewed every **seven days**. Otherwise, it may stop opening. This is an [Apple limit](https://developer.apple.com/help/account/basics/about-your-developer-account/).

Connect your phone to your computer and enable **automatic refresh** in Sideloadly. Leave Sideloadly running with the phone connected so it can renew the app. You can also set up renewal over Wi-Fi using the [Sideloadly setup guide](https://sideloadly.io/faq.html).

If the app has already stopped opening, repeat step 3 with the same Apple Account and the same Sideloadly options. Install over the existing copy. **Do not delete Commons first**: deleting it removes your saved choices.

Daily menu updates happen separately. You do not need to reinstall Commons to get the next day's menu.

## Get a newer version of Commons

Download the newest app file from the same download page, then repeat step 3. Use the same Apple Account and installer options to keep your saved dietary and section choices.

## Having trouble?

| What you see | What to try |
| --- | --- |
| Sideloadly cannot find your phone | Unlock it, check the cable, and accept the Trust prompt. On Windows, check that iTunes sees it; on Mac, check Finder. |
| An untrusted-developer or Developer Mode message | Follow step 4 above. |
| Commons stopped opening after about a week | Renew the installation using Sideloadly. |
| No menu, or an older menu | Check your internet connection and tap **MSOE** with the refresh arrow. If it is still unavailable, open the original menu link inside Commons. |
| No dishes match | Check the selected date, meal, search, and dietary filters. |

Still stuck? [Ask for help](https://github.com/aceher-1/cc_app/issues) and include the exact error message, your iOS version, and whether you use Windows or Mac.


For the app controls, visit https://github.com/aceher-1/cc_app#using-commons
