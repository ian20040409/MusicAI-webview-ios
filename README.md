# MusicAI Client iOS

MusicAI Client is an iOS application built in Swift that provides a web-based interface for the MusicAI platform. The app offers a simple and intuitive user experience to access MusicAI chat and related features directly from your iPhone.

## Features

- **Modern iOS Interface:** Clean and minimalistic UI for seamless navigation (see screenshot above).
- **Webview Integration:** Easily access MusicAI's chat functionality.
- **App Linking:** Quickly open related apps or resources from within MusicAI.
- **100% Swift:** All code is written entirely in Swift for the best performance and compatibility with iOS.
- **Liquid Glass:** Built following the latest iOS 26 design principles.
- **Client User-Agent:** This identifier is required by the backend to allow access to protected routes.
- **Remote Configuration:** Fetches the home URL from a remote endpoint, allowing for dynamic updates without requiring an app redeployment. The app automatically navigates to the new home URL and now fires a local notification as soon as a new address is detected.

## Download

You can download the latest pre-built version of the app directly from the **[Releases](https://github.com/ian20040409/MusicAI-Client-iOS/releases)** page.

## Getting Started
> [!NOTE]
> Build IPA using GitHub Actions
> 1. Fork this repository using the fork button on the top right
> 2. On your forked repository, go to **Repository Settings** > **Actions**, enable **Read and Write** permissions.
1. **Clone the repository:**
   ```sh
   git clone https://github.com/ian20040409/MusicAI-Client-ios.git
   ```
2. **Open the project in Xcode.**
3. **Build and run on your device or simulator.**

## Build and Release with GitHub Actions

> **Note**
>
> If this is your first time, please complete the following steps before you start:
> 1. Fork this repository using the **Fork** button in the top-right corner.
> 2. In your forked repository go to **Settings → Actions**, and set **Workflow permissions** to **Read and write** (required for creating Releases).

### How to build the MusicAI app using GitHub Actions (unsigned .ipa + Release)

1. Sync your fork. If your branch is out-of-date, click **Update branch** to bring it up to date.
2. Open the **Actions** tab in your forked repository and select the `Build iOS 26 Unsigned IPA (MusicAI) and Release` workflow.
3. Click the **Run workflow** button on the right and provide the required inputs:
   - `tag`: Tag to use for the release (e.g., `v1.0.0`).
   - `draft`: Create the release as a draft? (`true` or `false`, default: `true`).
4. Click **Run workflow** to start. The workflow will run on a macOS runner and perform the following:
   - Build an unsigned `.xcarchive`, package the `.app` into an unsigned `.ipa`, and upload both as artifacts.
   - If triggered by a tag push, or when running via `workflow_dispatch` with a `tag` value, the workflow will create a GitHub Release and upload `MusicAI-unsigned.ipa` as the release asset.
5. After the run completes, download the `.ipa` from the **Releases** page of your forked repository. If Releases are not visible, append `/releases` to your repo URL.

### Troubleshooting & Notes

- If you want to attach the entire `xcarchive` to the Release, zip the archive in the build job (`zip -r musicai-xcarchive.zip build/MusicAI.xcarchive`) and upload the single `.zip` file. Uploading the raw archive folder may cause the release action to attempt to upload internal files (Info.plist, Assets.car, etc.), which can fail with 404.
- Creating a signed IPA requires adding signing certificates (P12) and passwords to repository secrets and adding a signing step to the workflow; this workflow does not perform automatic signing.
- If the workflow cannot find artifacts or upload fails, inspect the `Upload artifact` step output in the build job and the `List files to upload` output in the release job to debug the problem.


## Screenshots
<p align="left">
  <img src="https://i.meee.com.tw/SgoE3Ql.png" alt="MusicAI Screenshot 1" height="590"/>
  <img src="https://i.meee.com.tw/En8vskJ.png" alt="MusicAI Screenshot 2" height="590"/>
</p>

## License

This project is licensed under the MIT License.

---

*Made with Swift*
