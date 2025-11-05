# MusicAI Webview iOS

MusicAI Webview iOS is an iOS application built in Swift that provides a web-based interface for the MusicAI platform. The app offers a simple and intuitive user experience to access MusicAI chat and related features directly from your iPhone.

## Features

- **Modern iOS Interface:** Clean and minimalistic UI for seamless navigation (see screenshot above).
- **Chat Integration:** Easily access MusicAI's chat functionality.
- **App Linking:** Quickly open related apps or resources from within MusicAI Webview.
- **100% Swift:** All code is written entirely in Swift for the best performance and compatibility with iOS.
- **Liquid Glass:** Built following the latest iOS 26 design principles.

## Getting Started
> [!NOTE]
> Build IPA using GitHub Actions
> 1. Fork this repository using the fork button on the top right
> 2. On your forked repository, go to **Repository Settings** > **Actions**, enable **Read and Write** permissions.
1. **Clone the repository:**
   ```sh
   git clone https://github.com/ian20040409/MusicAI-webview-ios.git
   ```
2. **Open the project in Xcode.**
3. **Build and run on your device or simulator.**

## 使用 GitHub Actions 建置並發佈 (Build with GitHub Actions)

> **注意**
> 
> 如果這是你第一次使用，請先完成下列步驟：
> 1. 使用右上角的 **Fork** 按鈕 fork 此專案至你的帳號。
> 2. 前往你 fork 後的 repository：**Settings → Actions**，將 **Workflow permissions** 設為 **Read and write**（允許寫入），否則無法建立 Release。

### 如何使用 GitHub Actions 建置 MusicAI（產生 unsigned .ipa 並建立 Release）

1. 在你的 fork 中按 **Sync fork**（若分支落後，點 **Update branch** 以同步）。
2. 進入 **Actions** 分頁，選擇 `Build iOS 26 Unsigned IPA (MusicAI) and Release` 工作流程（workflow）。
3. 點右側的 **Run workflow** 按鈕。你需要填入：
   - `tag`：要為 release 使用的 tag（例如 `v1.0.0`）。
   - `draft`：是否以草稿方式建立 Release（預設為 `true`）。
4. 點 **Run workflow** 開始。Actions 會在 macOS runner 上執行以下動作：
   - 編譯產生 unsigned `.xcarchive`，將 `.app` 打包為 unsigned `.ipa`，並把二者上傳為 artifact。
   - 若是以 tag 觸發（push tag），或以 `workflow_dispatch` 並提供 `tag`，流程會建立一個 GitHub Release 並將 `MusicAI-unsigned.ipa` 上傳為 Release asset。
5. 等待流程完成後，前往你的 fork 的 **Releases** 頁面下載 `.ipa`（若看不到 Releases，可在倉庫 URL 後加上 `/releases`，例如 `https://github.com/yourname/MusicAI-webview-ios/releases`）。

### 常見問題與注意事項

- 如果你希望上傳 `xcarchive` 作為下載項，建議在 build job 先將 `xcarchive` 壓縮為單一 `.zip` 檔，再上傳（避免將 archive 裡的多個內部檔案逐一當成 release asset 上傳，造成 404 錯誤）。
- 若想產生 signed（已簽名）的 IPA，需要在 repository secrets 中設定簽名憑證（P12）與密碼，並在 workflow 中加入簽名步驟（此流程未包含自動簽名）。
- 若 workflow 找不到產物或上傳失敗，可在 Actions 的 build job 中檢查 `Upload artifact` 步驟輸出，以及 release job 的 `List files to upload` 列表來排查問題。

*如果你要我幫你把 README 中的範例文字改為英文版本或加入範例截圖說明，我可以直接替你修改。*

## Screenshot
<p align="left">
  <img src="https://i.meee.com.tw/SgoE3Ql.png" alt="MusicAI Screenshot 1" height="590"/>
  <img src="https://i.meee.com.tw/En8vskJ.png" alt="MusicAI Screenshot 2" height="590"/>
</p>

## License

This project is licensed under the MIT License.

---

*Made with Swift*
