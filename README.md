# Commerce Tracker（經商追蹤）

**開發中，尚未收錄於插件管理器。** 本 repo 公開提供開發與測試，完成後再發布供一般玩家使用的版本。

本插件以 Folio105 為基礎重寫，保留其介面概念、部分資料及圖示。維護者已取得原作者授權；來源與授權紀錄見 [COPYRIGHT.md](COPYRIGHT.md)。

## 目前功能

- 選擇大陸、起始區域與交貨區域，查詢特產路線比率。
- 使用遊戲 API 取得配方材料，依拍賣查價估算成本與利潤。
- 依最高新鮮度計算售價，收藏常用路線。
- 設定透過遊戲插件存檔 API 保存，支援中文與英文介面。

功能仍在驗證中，價格資料及計算結果不應視為已完成校準。

## 測試操作

將本 repo 放在 `Addon/commercetracker/`，或建立指向本開發目錄的 Junction，於遊戲中啟用。不要與 Folio105 同時啟用，以免同時送出路線查詢。

點畫面小圖示開關主視窗，拖曳可移動。依序選擇大陸、起始區域、交貨區域；路線查詢有五秒冷卻。「查價」依序查詢材料拍賣單價，再按一次停止。「收藏」可加入、套用及刪除路線。

遊戲內中文使用簡體；本文件與開發說明使用繁體。

## 資料與程式

售價計算使用基礎售價、路線比率、經商熟練度與新鮮度倍率。基礎價格位於 `data/prices.lua`，地區及倍率位於 `data/zones.lua`；這些資料仍需實機核對。

| 路徑 | 用途 |
|---|---|
| `toc.g`、`main.lua` | 載入順序與初始化 |
| `trade.lua`、`auction.lua` | 路線、售價與拍賣查價 |
| `data/` | 地區、特產與價格資料 |
| `windows/` | 主視窗、收藏及開關按鈕 |
| `settings.lua`、`locale.lua` | 設定及遊戲文字 |
| `manifest.json` | 版本、介紹、更新紀錄與封裝白名單 |

設定 key 保持 `commercetracker_settings`。

## 開發與發布

使用者未明確要求升版或發布時，保留目前版本；一般修改、測試、提交或推送不自動升版。

這是獨立 Git repo，可保留在管理器的 `addons/commercetracker/` 開發。提交與推送在本目錄執行。

```powershell
python -m pip install -r scripts/test-requirements.txt
./scripts/test.ps1
python scripts/build-release.py
```

目前自動檢查為 Lua 5.1 語法及封裝內容驗證，尚無涵蓋經商行為的回歸測試。遊戲行為需另行實測。

push main／PR 會執行 CI 並保留封裝產物；使用者明確要求正式發布且完成測試後，更新 manifest 版本與 changelog，再推送單一 `v<版本>` tag。workflow 會核對版本並發布 ZIP、manifest、說明及圖示。建立 repo 或通過 CI 不代表已正式發布，也不會自動加入管理器清單。
