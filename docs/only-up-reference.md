# 《Only Up!》原作點樣設計一個落腳位

參考對象係 2023 年 5 月 24 日發售嘅 Windows 單人遊戲，Steam App ID `2381590`。主角 Jackie 由貧民區向上爬，靈感來自《傑克與豌豆》。爬得愈高，一次失足就可能要重行愈長一段。原作已下架，商店介紹同開發者公告仍然可查。[原作 Steam 商店頁](https://store.steampowered.com/app/2381590/Only_Up/) · [開發者公告](https://steamcommunity.com/app/2381590/announcements/)

## 起跳、抓邊同鏡頭

| 玩法 | 查到嘅原作行為 |
| --- | --- |
| 起跑同精準跳 | 玩家可以改變移動速度，亦可以主動放慢時間，喺關鍵一步調整時機。一名 PC 玩家記錄自己用 Steam Input 將行路、衝刺、跳躍同轉鏡分開操作。當中 A 鍵跳、右搖桿轉鏡係該玩家自訂配置。 [商店玩法說明](https://store.steampowered.com/app/2381590/Only_Up/) · [玩家手掣設定原帖](https://steamcommunity.com/app/2381590/discussions/0/3803902423384408716/) |
| 跌落時救返 | 6 月 14 日更新寫明，下墜期間嘅操控提高 30%。抓住物件嘅距離曾加 50%，按玩家回應調整為比原先多 20%。開發者亦改過管道段，減少一道要連跳兩次先爬到嘅障礙。呢幾項分別影響空中修正、抓邊同路線難度。 [開發者更新公告存檔](https://gameupdatenotifier.com/g/only-up/v/update-game-rebalancing) |
| 睇清方向 | 開發者 6 月加入滑鼠靈敏度設定，之後提供 `1` 切到置中第三身、`2` 回復偏側、按住 `C` 暫用第一身。置中鏡方便玩家將直行方向同畫面對齊。 [6 月官方公告](https://steamcommunity.com/app/2381590/announcements/) · [鏡頭更新公告存檔](https://gameupdatenotifier.com/g/only-up/v/update-game-rebalancing) |
| 跌返低處 | 商店列明原作無存檔點。7 月 4 日，開發者另外加咗一部可選升降機，沿途可直達地圖中段，俾玩家追回進度或縮短一次遊玩時間。 [商店玩法說明](https://store.steampowered.com/app/2381590/Only_Up/) · [7 月官方公告](https://steamcommunity.com/app/2381590/announcements/) |

6 月 14 日嗰篇嘅現存全文來自第三方保存嘅開發者原文。公告提供嘅百分比係版本間相對改動。商店同公告都無公開起跳初速、重力、空中橫移加速度、抓邊距離或者腳底碰撞體尺寸。無法由呢啲資料推算「半隻腳仲企到」嘅精確門檻。[更新公告存檔](https://gameupdatenotifier.com/g/only-up/v/update-game-rebalancing) · [官方公告列表](https://steamcommunity.com/app/2381590/announcements/)

## 同一條攀登路線點樣變化

以下按時間抽查咗開發者 6 月 2 日推薦嘅玩家「为颜绎而生」速通影片。時間按播放器，點入可以直接睇相應位置。呢次遊玩早於上面嘅 6 月中平衡更新。[官方推薦原文](https://steamcommunity.com/app/2381590/announcements/) · [玩家原片](https://www.bilibili.com/video/BV1vk4y1W7Yi/)

| 畫面時間 | 可見嘅落腳面 | 對路線設計嘅啟示 |
| --- | --- | --- |
| [00:55](https://www.bilibili.com/video/BV1vk4y1W7Yi/?t=55) | 建築上方有成排交錯嘅鏽色圓喉，角色沿其中一條行 | 管面有長度可用嚟助跑，但兩側窄，要先對準管軸。 |
| [02:45](https://www.bilibili.com/video/BV1vk4y1W7Yi/?t=165)、[03:40](https://www.bilibili.com/video/BV1vk4y1W7Yi/?t=220) | 高架路軌有間隔分明嘅枕木，再接近橫放嘅車廂 | 同一段可以先讀空隙，再搵較闊身嘅目標。 |
| [09:36](https://www.bilibili.com/video/BV1vk4y1W7Yi/?t=576)、[11:36](https://www.bilibili.com/video/BV1vk4y1W7Yi/?t=696) | 大樓旁邊有條紅色窄斜面，較後可見角色企喺氣球旁嘅圓形頂面 | 斜面要沿住坡度行，圓面就要判斷邊個位置夠闊俾角色落腳。 |
| [18:17](https://www.bilibili.com/video/BV1vk4y1W7Yi/?t=1097)、[19:32](https://www.bilibili.com/video/BV1vk4y1W7Yi/?t=1172) | 雲層上有一條粗糙圓木狀物件，稍後角色沿船嘅木甲板前進 | 窄而有弧度嘅位置同較闊嘅甲板交替，可以放慢對位，再重新助跑。 |
| [26:22](https://www.bilibili.com/video/BV1vk4y1W7Yi/?t=1582)、[31:42](https://www.bilibili.com/video/BV1vk4y1W7Yi/?t=1902) | 雲海上出現浮空啤牌，終段畫面見到太空站 | 熟悉物件隨高度轉換尺度同場景，玩家可以憑景物認出自己爬到邊。 |

## OnlyJump 手機版採用嘅取捨

- **起跳保留助跑速度。** 點一下即跳，行跳同跑跳靠水平距離區分。空中保留少量修正，鬆開搖桿後按地面摩擦收步。起跳高度、落地時間同跑跳距離要喺本作實測決定。
- **模型外形直接參與玩法。** 圓管中線、斜面、窄樑、圓蓋同較闊休息位各有自己嘅承托面。鞋底仍搭住邊時可以企穩，再踏出就跌。要用同一件物件分別試中心、邊緣同外側先判斷到。
- **鏡頭畀手機玩家揀。** 左拇指落喺移動區就生成浮動搖桿，鬆手立即歸中。右手可轉鏡，亦可開關自動跟隨前進方向。起跳時穩住視線，等玩家睇得清落點。浮動搖桿、跟隨開關同空中穩鏡係本作對應雙拇指操作嘅設計選擇。
