# No.1-151 ミニゲーム化監査・対応表

この表は `assets/data/ad_catalog.json` と `AdMiniGameDefinition.forAd` から生成する実装上の正本です。

|No.|タイトル|元ネタ/現表示|ゲーム|操作|成功条件|失敗条件|画像|状態/リセット|
|---:|---|---|---|---|---|---|---|---|
|001|あなたは本日999,999人目！|古のWeb/retro; たぶん昨日も999,999人目。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|002|今すぐクリックしないでください！|古のWeb/retro; 押すなと言われると押したくなる。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|003|この矢印の先に未来がある|古のWeb/retro; 矢印が多すぎてどれか分からない。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|004|残り時間、永遠の10秒|古のWeb/warning; 0になると10へ戻る。; 既存:none; COMMON; 条件:通常抽選で出現|countdownStop（必要）|残り1秒で止める|表示が1のとき止める|1以外で止める|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|005|驚異の1円OFF！|古のWeb/sale; 企業努力の結晶。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_16.png|MiniGamePhase / 画面内リセット|
|006|世界が震えた0.5％OFF|古のWeb/sale; 震えているのは広告だけ。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_16.png|MiniGamePhase / 画面内リセット|
|007|閉じるボタンを探せ！|古のWeb/retro; ×は逃げる。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|008|ダウンロード率120％|古のWeb/retro; 何をダウンロードするのかは不明。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|009|NEW！たぶんNEW！|古のWeb/retro; いつからNEWなのか誰も知らない。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|010|工事中なのに営業中|古のWeb/retro; 永遠に完成しないWebサイト。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|011|水が入る！奇跡のコップ|怪しい通販/product; 驚くほど普通。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_07.png|MiniGamePhase / 画面内リセット|
|012|座れる椅子、ついに登場|怪しい通販/product; 家具業界騒然。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_07.png|MiniGamePhase / 画面内リセット|
|013|絶対に開かない傘|怪しい通販/product; 雨にも使用者にも負けない。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_07.png|MiniGamePhase / 画面内リセット|
|014|何も入らない財布|怪しい通販/product; 究極のミニマリズム。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_07.png|MiniGamePhase / 画面内リセット|
|015|寝るためだけの枕|怪しい通販/product; ほぼ枕。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_07.png|MiniGamePhase / 画面内リセット|
|016|切れる包丁・改|怪しい通販/product; 包丁として正しい。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_07.png|MiniGamePhase / 画面内リセット|
|017|冷たい冷蔵庫|怪しい通販/product; 専門家も驚いた。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_07.png|MiniGamePhase / 画面内リセット|
|018|歩ける靴 PREMIUM|怪しい通販/product; 左右セット！; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_07.png|MiniGamePhase / 画面内リセット|
|019|持てるカバン PRO MAX|怪しい通販/product; 取っ手搭載。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_07.png|MiniGamePhase / 画面内リセット|
|020|飲める水 2026|怪しい通販/product; 大型アップデート。; 既存:tap; COMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_07.png|MiniGamePhase / 画面内リセット|
|021|専門家100人中1人が推薦|ランキング/review; 選ばれし一人。; 既存:choice; COMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|022|堂々の第1位（1商品中）|ランキング/review; 圧倒的首位。; 既存:choice; COMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|023|★★★★★ 0件のレビュー|ランキング/review; 誰も評価していない高評価。; 既存:choice; COMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|024|満足度101％|ランキング/review; 残り1％はどこから来た。; 既存:choice; COMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|025|リピート率300％|ランキング/review; 一人が三回来た。; 既存:choice; COMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|026|利用者の99％が人間|ランキング/review; 残り1％が気になる。; 既存:choice; COMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|027|広告博士が認めた広告|ランキング/review; 広告博士とは。; 既存:choice; COMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|028|今年最も広告だった広告|ランキング/review; 広告賞受賞。; 既存:choice; COMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|029|比較したら勝ってました|ランキング/review; 比較対象は非公開。; 既存:choice; COMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|030|口コミで話題！（口コミ1件）|ランキング/review; その1件が強い。; 既存:choice; COMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|031|王様を助けろ！初級編|王様救出/rescue; 王様は今日も危険。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|032|王様、炎上する|王様救出/rescue; 物理的に。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|033|王様と三本のピン|王様救出/rescue; 抜く順番だけが人生。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|034|宝より王を選べ|王様救出/rescue; 宝を選びがち。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|035|王様、また溺れる|王様救出/rescue; 前回から学んでいない。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|036|溶岩 VS 王様|王様救出/rescue; カードではない。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|037|王様、また燃える|王様救出/rescue; 正解を選んだはずなのに。; 既存:pinPull; RARE; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|038|王様救出率2％|王様救出/rescue; 広告主も驚いた低さ。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|039|王様はそこじゃない|王様救出/rescue; ピンを抜く前に気づきたい。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|040|王様と謎の魚|王様救出/rescue; なぜ魚がいる。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|041|王様、大富豪になる|王様救出/rescue; 救出しただけなのに。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|042|王様、地下100階へ|王様救出/rescue; 助ける気ある？; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|043|王様と絶対抜くなピン|王様救出/rescue; 当然抜きたくなる。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|044|王様の休日|王様救出/rescue; それでもピンを抜かれる。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|045|王様FINALっぽい何か|王様救出/rescue; FINALではない。; 既存:pinPull; COMMON; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|assets/images/ad_parts/sheet1/sheet1_02.png|MiniGamePhase / 画面内リセット|
|046|＋10か×2か、それが問題だ|数字ゲート/gate; だいたい×2。; 既存:gate; COMMON; 条件:通常抽選で出現|numberGate（必要）|増えるゲートを選ぶ|大きい結果のゲートを通る|小さい結果のゲートを選ぶ|assets/images/ad_parts/sheet2/sheet2_01.png|MiniGamePhase / 画面内リセット|
|047|棒人間、増えすぎる|数字ゲート/gate; 端末は増やさない。; 既存:gate; COMMON; 条件:通常抽選で出現|numberGate（必要）|増えるゲートを選ぶ|大きい結果のゲートを通る|小さい結果のゲートを選ぶ|assets/images/ad_parts/sheet2/sheet2_01.png|MiniGamePhase / 画面内リセット|
|048|1人から999999人へ|数字ゲート/gate; 人口問題。; 既存:gate; COMMON; 条件:通常抽選で出現|numberGate（必要）|増えるゲートを選ぶ|大きい結果のゲートを通る|小さい結果のゲートを選ぶ|assets/images/ad_parts/sheet2/sheet2_01.png|MiniGamePhase / 画面内リセット|
|049|×100を選んだだけなのに|数字ゲート/gate; 社会が崩壊。; 既存:gate; COMMON; 条件:通常抽選で出現|numberGate（必要）|増えるゲートを選ぶ|大きい結果のゲートを通る|小さい結果のゲートを選ぶ|assets/images/ad_parts/sheet2/sheet2_01.png|MiniGamePhase / 画面内リセット|
|050|＋5の方が強かった|数字ゲート/gate; 数学への挑戦。; 既存:gate; COMMON; 条件:通常抽選で出現|numberGate（必要）|増えるゲートを選ぶ|大きい結果のゲートを通る|小さい結果のゲートを選ぶ|assets/images/ad_parts/sheet2/sheet2_01.png|MiniGamePhase / 画面内リセット|
|051|レベル1から宇宙王へ|数字ゲート/gate; 所要時間12秒。; 既存:gate; COMMON; 条件:通常抽選で出現|numberGate（必要）|増えるゲートを選ぶ|大きい結果のゲートを通る|小さい結果のゲートを選ぶ|assets/images/ad_parts/sheet2/sheet2_01.png|MiniGamePhase / 画面内リセット|
|052|LV.9999なのに弱い|数字ゲート/gate; 数字とは何だったのか。; 既存:gate; COMMON; 条件:通常抽選で出現|numberGate（必要）|増えるゲートを選ぶ|大きい結果のゲートを通る|小さい結果のゲートを選ぶ|assets/images/ad_parts/sheet2/sheet2_01.png|MiniGamePhase / 画面内リセット|
|053|敵が急に巨大化しました|数字ゲート/gate; 広告なので。; 既存:gate; COMMON; 条件:通常抽選で出現|numberGate（必要）|増えるゲートを選ぶ|大きい結果のゲートを通る|小さい結果のゲートを選ぶ|assets/images/ad_parts/sheet2/sheet2_01.png|MiniGamePhase / 画面内リセット|
|054|剣を拾ったら社長になった|数字ゲート/gate; キャリア形成。; 既存:gate; COMMON; 条件:通常抽選で出現|numberGate（必要）|増えるゲートを選ぶ|大きい結果のゲートを通る|小さい結果のゲートを選ぶ|assets/images/ad_parts/sheet2/sheet2_01.png|MiniGamePhase / 画面内リセット|
|055|棒人間帝国の終焉|数字ゲート/gate; 開始から20秒。; 既存:gate; COMMON; 条件:通常抽選で出現|numberGate（必要）|増えるゲートを選ぶ|大きい結果のゲートを通る|小さい結果のゲートを選ぶ|assets/images/ad_parts/sheet2/sheet2_01.png|MiniGamePhase / 画面内リセット|
|056|ネジを外すだけだったのに|パズル/puzzle; 板が増えた。; 既存:drag; UNCOMMON; 条件:通常抽選で出現|dragSort（必要）|アイテムを正しい場所へドラッグ|対象を正しい枠へ入れる|違う枠へドロップする|共通図形|MiniGamePhase / 画面内リセット|
|057|そのネジ、そこじゃない|パズル/puzzle; でも入る。; 既存:drag; UNCOMMON; 条件:通常抽選で出現|dragSort（必要）|アイテムを正しい場所へドラッグ|対象を正しい枠へ入れる|違う枠へドロップする|共通図形|MiniGamePhase / 画面内リセット|
|058|水をコップへ導け！|パズル/puzzle; 水の物理は休暇中。; 既存:drag; UNCOMMON; 条件:通常抽選で出現|drawPath（必要）|指で安全な線を描く|開始点からゴールまで線をつなぐ|線がゴールへ届かない|共通図形|MiniGamePhase / 画面内リセット|
|059|蜂から犬っぽい何かを守れ|パズル/puzzle; 犬かどうかも怪しい。; 既存:drag; UNCOMMON; 条件:通常抽選で出現|drawPath（必要）|指で安全な線を描く|開始点からゴールまで線をつなぐ|線がゴールへ届かない|共通図形|MiniGamePhase / 画面内リセット|
|060|線を引けば全部解決|パズル/puzzle; だいたい解決しない。; 既存:drag; UNCOMMON; 条件:通常抽選で出現|drawPath（必要）|指で安全な線を描く|開始点からゴールまで線をつなぐ|線がゴールへ届かない|共通図形|MiniGamePhase / 画面内リセット|
|061|駐車場から出たいだけ|パズル/puzzle; 車が多すぎる。; 既存:drag; UNCOMMON; 条件:通常抽選で出現|dragSort（必要）|アイテムを正しい場所へドラッグ|対象を正しい枠へ入れる|違う枠へドロップする|共通図形|MiniGamePhase / 画面内リセット|
|062|赤い車だけ特別扱い|パズル/puzzle; 主人公だから。; 既存:drag; UNCOMMON; 条件:通常抽選で出現|dragSort（必要）|アイテムを正しい場所へドラッグ|対象を正しい枠へ入れる|違う枠へドロップする|共通図形|MiniGamePhase / 画面内リセット|
|063|色を分けろ！何のために？|パズル/puzzle; 説明はない。; 既存:drag; UNCOMMON; 条件:通常抽選で出現|dragSort（必要）|アイテムを正しい場所へドラッグ|対象を正しい枠へ入れる|違う枠へドロップする|共通図形|MiniGamePhase / 画面内リセット|
|064|ボールを正しい穴へ|パズル/puzzle; 全部同じ穴に見える。; 既存:drag; UNCOMMON; 条件:通常抽選で出現|dragSort（必要）|アイテムを正しい場所へドラッグ|対象を正しい枠へ入れる|違う枠へドロップする|共通図形|MiniGamePhase / 画面内リセット|
|065|3秒で解けるIQ999パズル|パズル/puzzle; IQの定義が揺らぐ。; 既存:drag; UNCOMMON; 条件:通常抽選で出現|dragSort（必要）|アイテムを正しい場所へドラッグ|対象を正しい枠へ入れる|違う枠へドロップする|共通図形|MiniGamePhase / 画面内リセット|
|066|汚れすぎた靴|変身/makeover; 靴だったことに驚く。; 既存:choice; UNCOMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|067|この部屋をなんとかして！|変身/makeover; まず壁がない。; 既存:choice; UNCOMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|068|掃除したら豪邸になった|変身/makeover; 清掃の力。; 既存:choice; UNCOMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|069|貧乏から億万長者まで15秒|変身/makeover; 投資助言ではありません。; 既存:choice; UNCOMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|070|所持金3円から始めます|変身/makeover; 謎のリアリティ。; 既存:choice; UNCOMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|071|選ぶだけで人生逆転!?|変身/makeover; 寝るを選ぶと勝つ。; 既存:choice; UNCOMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|072|服を着替えたら王族になった|変身/makeover; 身分制度が軽い。; 既存:choice; UNCOMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|073|ボロ家から宮殿へ|変身/makeover; 建築確認は取っていない。; 既存:choice; UNCOMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|074|掃除力9999|変身/makeover; スポンジ一本。; 既存:choice; UNCOMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|075|AFTERが別人|変身/makeover; もはや比較不能。; 既存:choice; UNCOMMON; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|076|小魚から海の王へ|成長・マージ/merge; 食物連鎖が速い。; 既存:tap; UNCOMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|077|魚が魚を超えた日|成長・マージ/merge; 最後は宇宙船になる。; 既存:tap; UNCOMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|078|リンゴ＋リンゴ＝なぜかメロン|成長・マージ/merge; 進化。; 既存:tap; UNCOMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|079|メロン＋メロン＝冷蔵庫|成長・マージ/merge; マージの限界。; 既存:tap; UNCOMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|080|何でも合体させればいい|成長・マージ/merge; 思想。; 既存:tap; UNCOMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|081|LV.1スライムっぽくない何か|成長・マージ/merge; 法的にもスライムではない。; 既存:tap; UNCOMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|082|育てたら巨大になりすぎた|成長・マージ/merge; 画面外へ。; 既存:tap; UNCOMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|083|ペット育成 8秒目|成長・マージ/merge; もう成人。; 既存:tap; UNCOMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|084|卵から社長が生まれた|成長・マージ/merge; 生命の神秘。; 既存:tap; UNCOMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|085|進化先：広告|成長・マージ/merge; 最終形態。; 既存:tap; UNCOMMON; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|086|777っぽいもの|抽選/slot; 惜しいようで何も惜しくない。; 既存:spin; UNCOMMON; 条件:通常抽選で出現|timing（必要）|成功ゾーンで止める|針を緑の範囲で止める|緑の範囲外で止める|assets/images/ad_parts/sheet1/sheet1_18.png|MiniGamePhase / 画面内リセット|
|087|超激熱っぽい！|抽選/slot; 温度は常温。; 既存:spin; UNCOMMON; 条件:通常抽選で出現|timing（必要）|成功ゾーンで止める|針を緑の範囲で止める|緑の範囲外で止める|assets/images/ad_parts/sheet1/sheet1_18.png|MiniGamePhase / 画面内リセット|
|088|大当たり!? たぶん！|抽選/slot; 何も当たらない。; 既存:spin; UNCOMMON; 条件:通常抽選で出現|timing（必要）|成功ゾーンで止める|針を緑の範囲で止める|緑の範囲外で止める|assets/images/ad_parts/sheet1/sheet1_18.png|MiniGamePhase / 画面内リセット|
|089|コイン＋999999|抽選/slot; 使い道：なし。; 既存:spin; UNCOMMON; 条件:通常抽選で出現|timing（必要）|成功ゾーンで止める|針を緑の範囲で止める|緑の範囲外で止める|assets/images/ad_parts/sheet1/sheet1_18.png|MiniGamePhase / 画面内リセット|
|090|回せ！無料スロット風広告|抽選/slot; スロット“風”。; 既存:spin; UNCOMMON; 条件:通常抽選で出現|timing（必要）|成功ゾーンで止める|針を緑の範囲で止める|緑の範囲外で止める|assets/images/ad_parts/sheet1/sheet1_18.png|MiniGamePhase / 画面内リセット|
|091|全部当たりに見えるルーレット|抽選/roulette; ハズレも光っている。; 既存:spin; UNCOMMON; 条件:通常抽選で出現|timing（必要）|成功ゾーンで止める|針を緑の範囲で止める|緑の範囲外で止める|assets/images/ad_parts/sheet1/sheet1_18.png|MiniGamePhase / 画面内リセット|
|092|スクラッチしたら広告だった|抽選/scratch; 予想どおり。; 既存:scratch; UNCOMMON; 条件:通常抽選で出現|scratch（必要）|銀色の面をこする|表面を70%以上削る|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|093|超絶プレミアム広告パック|広告パック/pack; 1口0円。; 既存:packOpen; UNCOMMON; 条件:通常抽選で出現|packOpen（必要）|パックを上へスワイプ|十分な距離を上へスワイプする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_15.png|MiniGamePhase / 画面内リセット|
|094|SSR大量封入っぽいパック|広告パック/pack; Rが出る。; 既存:packOpen; UNCOMMON; 条件:通常抽選で出現|packOpen（必要）|パックを上へスワイプ|十分な距離を上へスワイプする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_15.png|MiniGamePhase / 画面内リセット|
|095|残り3口！（増えます）|広告パック/pack; 在庫概念への挑戦。; 既存:packOpen; UNCOMMON; 条件:通常抽選で出現|packOpen（必要）|パックを上へスワイプ|十分な距離を上へスワイプする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_15.png|MiniGamePhase / 画面内リセット|
|096|市場価格999999円相当!?|広告パック/pack; 何の市場かは不明。; 既存:packOpen; UNCOMMON; 条件:通常抽選で出現|packOpen（必要）|パックを上へスワイプ|十分な距離を上へスワイプする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_15.png|MiniGamePhase / 画面内リセット|
|097|幻の広告カード開封|広告パック/pack; カードも広告。; 既存:packOpen; UNCOMMON; 条件:通常抽選で出現|packOpen（必要）|パックを上へスワイプ|十分な距離を上へスワイプする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_15.png|MiniGamePhase / 画面内リセット|
|098|ラストワンじゃない賞|広告パック/pack; まだ42口ある。; 既存:packOpen; UNCOMMON; 条件:通常抽選で出現|packOpen（必要）|パックを上へスワイプ|十分な距離を上へスワイプする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_15.png|MiniGamePhase / 画面内リセット|
|099|UR『すごい水』|広告パック/pack; 絵柄が少し光る。; 既存:packOpen; UNCOMMON; 条件:通常抽選で出現|packOpen（必要）|パックを上へスワイプ|十分な距離を上へスワイプする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_15.png|MiniGamePhase / 画面内リセット|
|100|100番記念・何も当たらない祭|広告パック/pack; おめでとう。; 既存:packOpen; UNCOMMON; 条件:通常抽選で出現|packOpen（必要）|パックを上へスワイプ|十分な距離を上へスワイプする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_15.png|MiniGamePhase / 画面内リセット|
|101|AIがあなたの年齢を当てます|AI・診断/diagnosis; だいたい27歳。; 既存:choice; RARE; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|102|AIが考えたAI広告|AI・診断/diagnosis; AIの文字が多い。; 既存:choice; RARE; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|103|あなたの広告タイプ診断|AI・診断/diagnosis; 結果：広告。; 既存:choice; RARE; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|104|3秒で分かる性格診断|AI・診断/diagnosis; 広告を見るタイプ。; 既存:choice; RARE; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|105|IQ999の人だけ解けます|AI・診断/diagnosis; 1＋1。; 既存:choice; RARE; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|106|あなたの隠れた才能は？|AI・診断/diagnosis; 広告を見ること。; 既存:choice; RARE; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|107|AIが選ぶ今日の商品|AI・診断/diagnosis; 毎日コップ。; 既存:choice; RARE; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|108|未来の顔を予測しました|AI・診断/diagnosis; 謎の丸。; 既存:choice; RARE; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|109|あなたに最適な広告です|AI・診断/diagnosis; 根拠なし。; 既存:choice; RARE; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|110|AI搭載ボタン|AI・診断/diagnosis; 押せる。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|111|知らないと損！→知っても得しない|動画・SNS風/social; 最後まで広告。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|112|衝撃の事実はCMのあと|動画・SNS風/social; 今がCM。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|113|この動画を最後まで見てください|動画・SNS風/social; 4秒。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|114|コメント欄が全員絶賛|動画・SNS風/social; 全員架空。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|115|人生変わりました！（何が？）|動画・SNS風/social; 広告を見ました。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|116|たった3日でこうなった|動画・SNS風/social; 何がとは言わない。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|117|正直、教えたくありません|動画・SNS風/social; 広告なので教える。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|118|友達には秘密にしてください|動画・SNS風/social; ランキング公開中。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|119|今、若者の間で話題！|動画・SNS風/social; 若者とは誰か。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|120|1000万再生っぽい動画|動画・SNS風/social; 再生数表示だけ。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|121|警告：広告が不足しています|警告/warning; 重大。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|122|あなたの広告は古くなっています|警告/warning; 更新してください。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|123|残り1個！から増える在庫|警告/warning; 自己増殖。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|124|今だけ！毎日開催|警告/warning; 今とは。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|125|本日最終日・第438日目|警告/warning; 終わらない。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|126|あと5秒で終了します|警告/warning; 終了しない。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|127|99％で止まるアップデート|警告/warning; 永遠の99％。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|128|容量が足りません（広告の）|警告/warning; ストレージは正常。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|129|この広告を見逃すと損!?|警告/warning; 何を失うのか不明。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|130|緊急でも何でもない速報|警告/warning; 広告です。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|131|広告を広告する広告|意味不明/meta; メタ。; 既存:none; RARE; 条件:通常抽選で出現|reveal（必要）|隠された広告を探してタップ|移動する対象を見つける|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|132|詳しく見る→詳細はありません|意味不明/meta; 正直。; 既存:tap; RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|133|何の商品でしょう？|意味不明/meta; 答え：不明。; 既存:none; RARE; 条件:通常抽選で出現|reveal（必要）|隠された広告を探してタップ|移動する対象を見つける|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|134|とにかく光る広告|意味不明/meta; 内容より輝度。; 既存:none; RARE; 条件:通常抽選で出現|reveal（必要）|隠された広告を探してタップ|移動する対象を見つける|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|135|とにかく揺れる広告|意味不明/meta; 端末は揺れない。; 既存:none; RARE; 条件:通常抽選で出現|reveal（必要）|隠された広告を探してタップ|移動する対象を見つける|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|136|広告です！！！！！！|意味不明/meta; 説明終了。; 既存:none; RARE; 条件:通常抽選で出現|reveal（必要）|隠された広告を探してタップ|移動する対象を見つける|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|137|この広告には意味があります|意味不明/meta; まだ見つかっていない。; 既存:none; RARE; 条件:通常抽選で出現|reveal（必要）|隠された広告を探してタップ|移動する対象を見つける|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|138|広告を見るための広告|意味不明/meta; 目的達成。; 既存:none; RARE; 条件:通常抽選で出現|reveal（必要）|隠された広告を探してタップ|移動する対象を見つける|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|139|何も売らないセール|意味不明/meta; 全品対象。; 既存:none; RARE; 条件:通常抽選で出現|reveal（必要）|隠された広告を探してタップ|移動する対象を見つける|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|140|クリックする場所がありません|意味不明/meta; 安心設計。; 既存:none; RARE; 条件:通常抽選で出現|reveal（必要）|隠された広告を探してタップ|移動する対象を見つける|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|141|伝説の閉じるボタン|高レア/legendary; 見つけたら閉じたくない。; 既存:tap; SUPER RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|142|広告王の王冠|高レア/legendary; 広告を見続けた者の証。; 既存:tap; SUPER RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|143|0.01％OFF祭|高レア/sale; 割引額を計算してはいけない。; 既存:tap; SUPER RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_16.png|MiniGamePhase / 画面内リセット|
|144|幻の残り1個|高レア/warning; 誰も買えない。; 既存:tap; SUPER RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_19.png|MiniGamePhase / 画面内リセット|
|145|SSRより上っぽい何か|高レア/legendary; 名前はまだない。; 既存:tap; SUPER RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|146|広告博士・最終講義|高レア/diagnosis; 結論：広告だった。; 既存:choice; SUPER RARE; 条件:通常抽選で出現|choice（必要）|正しい選択肢を選ぶ|正解を選ぶ|不正解を選ぶ|共通図形|MiniGamePhase / 画面内リセット|
|147|王様、ついに助かる|高レア/rescue; 長かった。; 既存:pinPull; SUPER RARE; 条件:通常抽選で出現|pinPull（必要）|安全な順番でピンを抜く|宝を王様へ届ける|危険なピンを先に抜く|共通図形|MiniGamePhase / 画面内リセット|
|148|究極の広告パック|高レア/pack; 中身：広告。; 既存:packOpen; SUPER RARE; 条件:通常抽選で出現|packOpen（必要）|パックを上へスワイプ|十分な距離を上へスワイプする|操作を完了できない|assets/images/ad_parts/sheet2/sheet2_15.png|MiniGamePhase / 画面内リセット|
|149|最後から2番目っぽい広告|高レア/meta; 実際そう。; 既存:none; SUPER RARE; 条件:通常抽選で出現|reveal（必要）|隠された広告を探してタップ|移動する対象を見つける|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|150|広告図鑑、ほぼ完成！|高レア/legendary; あと一つ。; 既存:tap; SUPER RARE; 条件:通常抽選で出現|tapChallenge（必要）|光る対象を3回タップ|3回タップする|操作を完了できない|共通図形|MiniGamePhase / 画面内リセット|
|151|幻の広告 ― アドゴン|SECRET/secret; 151種類を見つけた者だけが出会える、幻の広告。; 既存:none; SECRET; 条件:AD_001〜AD_150をすべて発見|finale（必要）|王冠を3回タップして完成させる|3つの紋章を点灯する|操作を完了できない|assets/images/ad_parts/sheet1/sheet1_04.png|MiniGamePhase / 画面内リセット|

## 共通実装

- Widget: `AdMiniGame`
- 状態: `notStarted / playing / success / failure`
- リセット: 成功・失敗バナーの再試行ボタン
- 状態は表示中の広告1件だけ生成し、終了時にTimer/AnimationControllerを破棄
- No.151の解放規則とAdMobリワード処理は変更しない
