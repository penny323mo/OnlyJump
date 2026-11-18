# OnlyJump · 失物天台

[手機或電腦直接試玩](https://penny323mo.github.io/OnlyJump/)

由士多天台出發，踩過梳化、波鞋、唱盤、玩具跑車、繫纜柱同吊臂鋼樑，經 18 跳登上 38 米高的失物招領枱。落差大時仍有機會踩返下層物件。最高落腳高度儲存在目前瀏覽器。

| 操作 | 手機 | 電腦 |
| --- | --- | --- |
| 移動 | 左搖桿 | WASD 或方向鍵 |
| 跳躍 | 輕撳跳躍 | 空白鍵 |
| 助跑 | 輕撳加速切換 | 按住 Shift |
| 環視 | 喺空白位置左右、上下掃動 | 拖曳滑鼠，或按 Q / E 旋轉 |
| 對準下一件物件 | 撳「對準目標」 | F |
| 暫停 | 右上角暫停掣 | P 或 Esc |

橙圈標示下一站。原地撳跳會垂直起跳，推住方向起跳會向前。靠近窄邊會減速，放開搖桿就收腳。腳掌部分伸出鋼樑時仍然可以企穩。

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

角色、城市及部分道具的作者、授權及改動記錄載於[模型鳴謝](web/credits.txt)。
