# 図鑑の影：絵が必要なもの（needsArt）

オーナー決定（2026-10-02）: 影はできるだけ Apple の SF Symbols を使う。合う記号が無いものはここに並べ、
後で AI でシルエット画を作る。それまでは灰色の角丸の仮の影を出す。

- 作った絵は Assets.xcassets に `dexsil-<id>` の名前で入れると、その項目の影に自動で使われる
  （白黒のシルエット。アプリ側で影の色 #C5CFDC に塗る。透明背景の PNG または PDF、正方形）。
- 一覧の元は `ios/CatchWords/Models/DexCatalog.swift`（項目を変えたらこの表も直す）。
- No. は基本の 100 個だけ（001–100）。それ以外は捕まえた順に 101 から番号が付くので、ここでは「—」。

合計 **219** 個（全 379 項目のうち）。

## 1. 🧋 飲み物（15）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| 001 | `bubbletea` | 珍珠奶茶 | bubble tea | タピオカミルクティー |
| 003 | `tea` | 茶 | tea | お茶 |
| 004 | `juice` | 果汁 | juice | ジュース |
| — | `soymilk` | 豆漿 | soy milk | 豆乳 |
| — | `milk` | 牛奶 | milk | 牛乳 |
| — | `blacktea` | 紅茶 | black tea | 紅茶 |
| — | `greentea` | 綠茶 | green tea | 緑茶 |
| — | `milktea` | 奶茶 | milk tea | ミルクティー |
| — | `cola` | 可樂 | cola | コーラ |
| — | `soda` | 汽水 | soda | 炭酸飲料 |
| — | `sportsdrink` | 運動飲料 | sports drink | スポーツドリンク |
| — | `beer` | 啤酒 | beer | ビール |
| — | `wintermelontea` | 冬瓜茶 | winter melon tea | 冬瓜茶 |
| — | `yogurtdrink` | 優酪乳 | drinkable yogurt | 飲むヨーグルト |
| — | `hotcocoa` | 熱可可 | hot chocolate | ココア |

## 2. 🍜 料理・屋台（19）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| 006 | `rice` | 飯 | rice | ご飯 |
| 007 | `noodles` | 麵 | noodles | 麺 |
| 008 | `bento` | 便當 | bento | 弁当 |
| 009 | `dumplings` | 水餃 | dumplings | 水餃子 |
| 010 | `bun` | 包子 | steamed bun | 肉まん |
| — | `egg` | 蛋 | egg | 卵 |
| — | `braisedporkrice` | 滷肉飯 | braised pork rice | 魯肉飯 |
| — | `friedrice` | 炒飯 | fried rice | チャーハン |
| — | `soup` | 湯 | soup | スープ |
| — | `beefnoodles` | 牛肉麵 | beef noodle soup | 牛肉麺 |
| — | `danbing` | 蛋餅 | egg crepe | ダンビン |
| — | `sandwich` | 三明治 | sandwich | サンドイッチ |
| — | `tofu` | 豆腐 | tofu | 豆腐 |
| — | `porridge` | 粥 | congee | お粥 |
| — | `friedchicken` | 炸雞 | fried chicken | フライドチキン |
| — | `stinkytofu` | 臭豆腐 | stinky tofu | 臭豆腐 |
| — | `hotpot` | 火鍋 | hot pot | 火鍋 |
| — | `scallionpancake` | 蔥油餅 | scallion pancake | ねぎ餅 |
| — | `hamburger` | 漢堡 | hamburger | ハンバーガー |

## 3. 🍎 果物・野菜（18）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| 011 | `apple` | 蘋果 | apple | りんご |
| 012 | `banana` | 香蕉 | banana | バナナ |
| 013 | `mango` | 芒果 | mango | マンゴー |
| 014 | `tomato` | 番茄 | tomato | トマト |
| 015 | `cabbage` | 高麗菜 | cabbage | キャベツ |
| — | `orange` | 橘子 | orange | みかん |
| — | `watermelon` | 西瓜 | watermelon | スイカ |
| — | `guava` | 芭樂 | guava | グァバ |
| — | `grapes` | 葡萄 | grapes | ぶどう |
| — | `pineapple` | 鳳梨 | pineapple | パイナップル |
| — | `papaya` | 木瓜 | papaya | パパイヤ |
| — | `onion` | 洋蔥 | onion | 玉ねぎ |
| — | `sweetpotato` | 地瓜 | sweet potato | さつまいも |
| — | `corn` | 玉米 | corn | とうもろこし |
| — | `strawberry` | 草莓 | strawberry | いちご |
| — | `lemon` | 檸檬 | lemon | レモン |
| — | `cucumber` | 小黃瓜 | cucumber | きゅうり |
| — | `potato` | 馬鈴薯 | potato | じゃがいも |

## 4. 🍰 お菓子・パン（17）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| 016 | `bread` | 麵包 | bread | パン |
| 018 | `cookie` | 餅乾 | cookie | クッキー |
| 019 | `icecream` | 冰淇淋 | ice cream | アイスクリーム |
| 020 | `pineapplecake` | 鳳梨酥 | pineapple cake | パイナップルケーキ |
| — | `candy` | 糖果 | candy | 飴 |
| — | `chocolate` | 巧克力 | chocolate | チョコレート |
| — | `toast` | 吐司 | toast | 食パン |
| — | `shavedice` | 剉冰 | shaved ice | かき氷 |
| — | `chips` | 洋芋片 | potato chips | ポテトチップス |
| — | `pudding` | 布丁 | pudding | プリン |
| — | `douhua` | 豆花 | tofu pudding | 豆花 |
| — | `donut` | 甜甜圈 | donut | ドーナツ |
| — | `eggtart` | 蛋塔 | egg tart | エッグタルト |
| — | `mochi` | 麻糬 | mochi | もち |
| — | `taroballs` | 芋圓 | taro balls | タロイモ団子 |
| — | `waffle` | 鬆餅 | waffle | ワッフル |
| — | `jelly` | 果凍 | jelly | ゼリー |

## 5. 🥢 食器・台所（18）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| 022 | `bowl` | 碗 | bowl | お椀 |
| 023 | `chopsticks` | 筷子 | chopsticks | 箸 |
| 024 | `plate` | 盤子 | plate | 皿 |
| 025 | `spoon` | 湯匙 | spoon | スプーン |
| — | `fork` | 叉子 | fork | フォーク |
| — | `knife` | 刀子 | knife | ナイフ |
| — | `straw` | 吸管 | straw | ストロー |
| — | `papercup` | 紙杯 | paper cup | 紙コップ |
| — | `pot` | 鍋子 | pot | 鍋 |
| — | `glass` | 玻璃杯 | glass | グラス |
| — | `kettle` | 水壺 | kettle | やかん |
| — | `cuttingboard` | 砧板 | cutting board | まな板 |
| — | `bentobox` | 便當盒 | bento box | 弁当箱 |
| — | `thermos` | 保溫瓶 | thermos | 水筒 |
| — | `wok` | 炒鍋 | wok | 中華鍋 |
| — | `teapot` | 茶壺 | teapot | 急須 |
| — | `sponge` | 菜瓜布 | scrub sponge | スポンジ |
| — | `dishsoap` | 洗碗精 | dish soap | 食器用洗剤 |

## 6. 🛋️ 家具・インテリア（4）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| — | `desk` | 書桌 | desk | 机 |
| — | `mirror` | 鏡子 | mirror | 鏡 |
| — | `pillow` | 枕頭 | pillow | 枕 |
| — | `blanket` | 被子 | blanket | 布団 |

## 7. 🔌 家電（7）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| — | `ricecooker` | 電鍋 | rice cooker | 炊飯器 |
| — | `hairdryer` | 吹風機 | hair dryer | ドライヤー |
| — | `waterdispenser` | 飲水機 | water dispenser | ウォーターサーバー |
| — | `vacuum` | 吸塵器 | vacuum cleaner | 掃除機 |
| — | `hotwaterpot` | 熱水瓶 | electric water pot | 電気ポット |
| — | `iron` | 熨斗 | iron | アイロン |
| — | `toaster` | 烤麵包機 | toaster | トースター |

## 8. 📱 スマホ・パソコン（3）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| — | `powerbank` | 行動電源 | power bank | モバイルバッテリー |
| — | `phonecase` | 手機殼 | phone case | スマホケース |
| — | `usbdrive` | 隨身碟 | USB flash drive | USBメモリ |

## 9. ✏️ 文房具・本（9）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| 043 | `notebook` | 筆記本 | notebook | ノート |
| — | `pencil` | 鉛筆 | pencil | 鉛筆 |
| — | `comic` | 漫畫 | comic | 漫画 |
| — | `tape` | 膠帶 | tape | テープ |
| — | `pencilcase` | 鉛筆盒 | pencil case | 筆箱 |
| — | `marker` | 麥克筆 | marker | マーカー |
| — | `glue` | 膠水 | glue | のり |
| — | `stapler` | 釘書機 | stapler | ホッチキス |
| — | `dictionary` | 字典 | dictionary | 辞書 |

## 10. 🪥 洗面・日用品（11）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| 046 | `toothbrush` | 牙刷 | toothbrush | 歯ブラシ |
| 047 | `towel` | 毛巾 | towel | タオル |
| 048 | `tissue` | 衛生紙 | tissue | ティッシュ |
| — | `toothpaste` | 牙膏 | toothpaste | 歯磨き粉 |
| — | `coin` | 硬幣 | coin | 硬貨 |
| — | `soap` | 肥皂 | soap | 石けん |
| — | `shampoo` | 洗髮精 | shampoo | シャンプー |
| — | `trashbag` | 垃圾袋 | trash bag | ゴミ袋 |
| — | `transitcard` | 悠遊卡 | transit card | 交通系ICカード |
| — | `receipt` | 發票 | receipt | レシート |
| — | `wetwipes` | 濕紙巾 | wet wipes | ウェットティッシュ |

## 11. 👕 服（17）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| 052 | `pants` | 褲子 | pants | ズボン |
| 054 | `skirt` | 裙子 | skirt | スカート |
| 055 | `socks` | 襪子 | socks | 靴下 |
| — | `tshirt` | T恤 | T-shirt | Tシャツ |
| — | `shirt` | 襯衫 | shirt | シャツ |
| — | `shorts` | 短褲 | shorts | 短パン |
| — | `jeans` | 牛仔褲 | jeans | ジーンズ |
| — | `dress` | 洋裝 | dress | ワンピース |
| — | `raincoat` | 雨衣 | raincoat | レインコート |
| — | `sweater` | 毛衣 | sweater | セーター |
| — | `hoodie` | 帽T | hoodie | パーカー |
| — | `uniform` | 制服 | uniform | 制服 |
| — | `pajamas` | 睡衣 | pajamas | パジャマ |
| — | `tanktop` | 背心 | tank top | タンクトップ |
| — | `underwear` | 內衣 | underwear | 下着 |
| — | `scarf` | 圍巾 | scarf | マフラー |
| — | `necktie` | 領帶 | necktie | ネクタイ |

## 12. 👟 靴・バッグ・小物（8）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| — | `mask` | 口罩 | face mask | マスク |
| — | `slippers` | 拖鞋 | slippers | スリッパ |
| — | `belt` | 皮帶 | belt | ベルト |
| — | `hairtie` | 髮圈 | hair tie | ヘアゴム |
| — | `earrings` | 耳環 | earrings | イヤリング |
| — | `necklace` | 項鍊 | necklace | ネックレス |
| — | `ring` | 戒指 | ring | 指輪 |
| — | `gloves` | 手套 | gloves | 手袋 |

## 13. 🛵 乗り物（6）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| — | `truck` | 卡車 | truck | トラック |
| — | `hsr` | 高鐵 | high-speed rail | 新幹線 |
| — | `garbagetruck` | 垃圾車 | garbage truck | ゴミ収集車 |
| — | `ambulance` | 救護車 | ambulance | 救急車 |
| — | `policecar` | 警車 | police car | パトカー |
| — | `firetruck` | 消防車 | fire truck | 消防車 |

## 14. 🏪 建物・お店（10）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| 067 | `temple` | 廟 | temple | お寺 |
| 068 | `school` | 學校 | school | 学校 |
| 070 | `nightmarket` | 夜市 | night market | 夜市 |
| — | `breakfastshop` | 早餐店 | breakfast shop | 朝ごはん屋 |
| — | `park` | 公園 | park | 公園 |
| — | `station` | 車站 | station | 駅 |
| — | `pharmacy` | 藥局 | pharmacy | 薬局 |
| — | `cafe` | 咖啡廳 | café | カフェ |
| — | `postoffice` | 郵局 | post office | 郵便局 |
| — | `library` | 圖書館 | library | 図書館 |

## 15. 🚦 道・街の物（12）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| 071 | `trafficlight` | 紅綠燈 | traffic light | 信号 |
| 074 | `streetlight` | 路燈 | streetlight | 街灯 |
| 075 | `crosswalk` | 斑馬線 | crosswalk | 横断歩道 |
| — | `busstop` | 公車站 | bus stop | バス停 |
| — | `bench` | 長椅 | bench | ベンチ |
| — | `mailbox` | 郵筒 | mailbox | ポスト |
| — | `bridge` | 橋 | bridge | 橋 |
| — | `vendingmachine` | 販賣機 | vending machine | 自動販売機 |
| — | `utilitypole` | 電線桿 | utility pole | 電柱 |
| — | `sidewalk` | 人行道 | sidewalk | 歩道 |
| — | `firehydrant` | 消防栓 | fire hydrant | 消火栓 |
| — | `atm` | 提款機 | ATM | ATM |

## 16. 🐾 動物（10）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| — | `pigeon` | 鴿子 | pigeon | ハト |
| — | `sparrow` | 麻雀 | sparrow | スズメ |
| — | `mosquito` | 蚊子 | mosquito | 蚊 |
| — | `cockroach` | 蟑螂 | cockroach | ゴキブリ |
| — | `butterfly` | 蝴蝶 | butterfly | チョウ |
| — | `chicken` | 雞 | chicken | ニワトリ |
| — | `duck` | 鴨子 | duck | アヒル |
| — | `squirrel` | 松鼠 | squirrel | リス |
| — | `frog` | 青蛙 | frog | カエル |
| — | `hamster` | 倉鼠 | hamster | ハムスター |

## 17. 🌿 植物・花（14）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| 083 | `grass` | 草 | grass | 草 |
| 085 | `pottedplant` | 盆栽 | potted plant | 鉢植え |
| — | `banyan` | 榕樹 | banyan tree | ガジュマル |
| — | `palmtree` | 椰子樹 | palm tree | ヤシの木 |
| — | `cactus` | 仙人掌 | cactus | サボテン |
| — | `rose` | 玫瑰 | rose | バラ |
| — | `bamboo` | 竹子 | bamboo | 竹 |
| — | `sunflower` | 向日葵 | sunflower | ひまわり |
| — | `moss` | 青苔 | moss | 苔 |
| — | `mushroom` | 香菇 | mushroom | キノコ |
| — | `cherryblossom` | 櫻花 | cherry blossom | 桜 |
| — | `orchid` | 蘭花 | orchid | ラン |
| — | `lotus` | 蓮花 | lotus | ハス |
| — | `seed` | 種子 | seed | 種 |

## 18. ⛅ 空・自然（5）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| — | `river` | 河 | river | 川 |
| — | `stone` | 石頭 | stone | 石 |
| — | `lake` | 湖 | lake | 湖 |
| — | `puddle` | 水坑 | puddle | 水たまり |
| — | `sand` | 沙子 | sand | 砂 |

## 19. ⚽ スポーツ・遊び（6）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| — | `badminton` | 羽毛球 | badminton | バドミントン |
| — | `tabletennis` | 桌球 | table tennis | 卓球 |
| — | `clawmachine` | 夾娃娃機 | claw machine | クレーンゲーム |
| — | `cards` | 撲克牌 | playing cards | トランプ |
| — | `doll` | 娃娃 | doll | 人形 |
| — | `kite` | 風箏 | kite | 凧 |

## 20. 🖐️ 人・体（10）

| No. | id | 台湾華語 | English | 日本語 |
|---|---|---|---|---|
| — | `hair` | 頭髮 | hair | 髪 |
| — | `foot` | 腳 | foot | 足 |
| — | `head` | 頭 | head | 頭 |
| — | `mother` | 媽媽 | mother | お母さん |
| — | `father` | 爸爸 | father | お父さん |
| — | `baby` | 嬰兒 | baby | 赤ちゃん |
| — | `student` | 學生 | student | 学生 |
| — | `teacher` | 老師 | teacher | 先生 |
| — | `grandmother` | 阿嬤 | grandmother | おばあちゃん |
| — | `shopowner` | 老闆 | shop owner | 店主 |
