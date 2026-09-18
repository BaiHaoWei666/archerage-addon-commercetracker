# 語言與維護

- 遊戲內中文使用簡體；README、註解、管理器 metadata、更新紀錄及溝通使用繁體。識別字、路徑與必要原文保留原樣。
- 本目錄是獨立 Git repo；在本目錄提交與推送。保留既有使用者設定及資料相容性。

# 測試與發布

- 安裝 scripts/test-requirements.txt 的依賴後，執行 scripts/test.ps1；區分自動檢查與實機驗證。
- 完成程式與測試後才調高 manifest.json 的版本並新增 changelog；已發布版本不重用。
- 執行 python scripts/build-release.py，核對 dist 的 manifest、ZIP 內容與本機 version.txt 一致。
- 使用遊戲 Junction 時先確認指向本目錄，再從遊戲路徑讀回 version.txt；一般安裝資料夾由安裝流程更新。
- 封裝以 manifest 的 files 白名單為準，排除 Git、開發設定及測試資料。
- 一般提交格式為 type: 繁體中文摘要，或 type(scope): 繁體中文摘要；版本提交固定為 chore(commercetracker): bump version to <版本號>。
- 程式／文件與版本收尾分開提交。推送明列 main 或單一 v<版本號> tag，不使用 --tags。
- 目前仍在開發中，尚未收錄；只有使用者要求正式發布時才建立 release tag。
