# Publishing from Windows

You do not need to own a Mac. GitHub's cloud Mac can build, sign, and upload the app; you can manage its store listing and submit it for review in your Windows browser.

## What is ready

- The app supports iOS 17 and newer, including iPhone 15.
- Both native test and device build workflows explicitly select Xcode 26.2 and the iOS 26.2 SDK. They stop if that environment is unavailable instead of silently using older tools.
- Menu updates already happen centrally, and saved preferences stay on the phone.
- The current device workflow produces an **unsigned sideloading IPA**. It does not upload to Apple.

## What still needs to be done

1. **Activate your Apple Developer membership.** Accept the required agreements in your Apple account.
2. **Register the app with Apple.** Choose a permanent, unique app identifier, replace `com.example.msoecommons` in the project and its generator, and create the matching app under App Store Connect → Apps → + → New App. Record your developer Team ID.
3. **Set up release signing.** Create an Apple Distribution certificate with its private key and an App Store distribution profile for this app. This can be done with Windows tools or the cloud Mac. Keep the private key backed up securely.
4. **Give GitHub upload access.** Create an App Store Connect API key. Store its private key and signing credentials in GitHub Actions secrets, never in source files or this public repository. Enter secrets directly in GitHub; do not paste them into chat.
5. **Add an upload workflow.** Configure a manual action that archives the app, exports a signed App Store IPA, and uploads it to App Store Connect. Include a unique build number for each upload. This workflow is not implemented yet; the existing unsigned download workflow remains available for sideloading.
6. **Prepare the store page.** Add the app name, description, screenshots, support URL, public privacy-policy URL, age rating, privacy answers, export-compliance answers, pricing, and availability. Explain that this is an independent project, and that the halal screen means potentially suitable rather than certified. Verify permission to use any provider content and branding before publication.
7. **Test the signed release with TestFlight.** Check live menu loading, offline behavior, saved preferences, section organization, meal swipes, and dietary explanations on your iPhone. Review any outstanding bugs and ensure the shared menu publisher is monitored and remains scheduled.
8. **Submit for review.** Select the processed build in App Store Connect, add it for review, and submit. Choose automatic release after approval or a manual release date. Apple approval is required even when uploading is automated.

After setup, the usual process will be: **GitHub → Actions → upload workflow → Run workflow**, test the build through TestFlight, then submit the new version from App Store Connect. That upload workflow will appear only after it has been added.

## Compatibility and verification

Updating the build tools does not change the app's minimum iOS version. No redesign or conversion to a different framework is required. Newer compiler errors, warnings, or differences in system controls may still need small fixes, so the cloud build and simulator tests must pass before treating this upgrade as verified.

The existing unsigned IPA must be rebuilt and signed for App Store distribution. Updating the SDK alone does not make it ready for publication.

References: [Apple upload requirements](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [GitHub signing on cloud Macs](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications), [submit to App Review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app).
