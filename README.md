# OnlyJump · 琥珀山徑

[進入遊戲](https://penny323mo.github.io/OnlyJump/)

用蓄力跳躍越過 12 段浮島山徑，登上 25 米高的山頂敲響銅鐘。角色可以落返下層平台，跌出山谷就會返到營地。最高落腳高度會儲存在目前瀏覽器。

| 操作 | 鍵盤 | 觸控 |
| --- | --- | --- |
| 移動、瞄準 | WASD 或方向鍵 | 左側搖桿 |
| 蓄力、跳躍 | 按住空白鍵，放手起跳 | 按住右側蓄力掣，放手起跳 |
| 暫停或繼續 | P 或 Esc | 右上角暫停掣 |

蓄力期間可改變方向，金色圓點顯示起跳軌跡，橙色圓環標示下一個落腳平台。起跳後只可微調。可從暫停畫面重新開始。

## 本機開發

使用標準版 Godot 4.7.2 開啟 `project.godot`，按 F5 執行專案。桌面版由 Enter 開始。

安裝相同版本的 Web export templates 後，可從專案根目錄匯出並試玩。

```sh
./scripts/export-web.sh
python3 -m http.server 8137 --bind 127.0.0.1 --directory build/web
```

開啟 <http://127.0.0.1:8137/>。若 Godot 未加入 PATH，可將 `GODOT_BIN` 設為 Godot 執行檔路徑。

## 部署與驗證

推送至 main 會觸發 GitHub Actions，下載指定版本的 Godot、核對 SHA-256、匯出單執行緒 WebGL 2 版本、以遊戲物理驗證整段路線，再發佈至 GitHub Pages。可在 Actions 手動重新部署。

```sh
godot --headless --import
godot --headless --fixed-fps 60 --script tests/route.gd
```

場景、角色和音效為此專案製作。標題字型 Barlow Condensed 依 [SIL Open Font License](web/fonts/OFL.txt) 使用。
