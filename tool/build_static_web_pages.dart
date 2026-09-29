import 'dart:convert';
import 'dart:io';

const origin = 'https://hitasura.yorimichi-works.jp';

String escape(String value) => const HtmlEscape().convert(value);

String page({
  required String title,
  required String description,
  required String body,
}) =>
    '''<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>$title | ひたすら広告</title>
  <meta name="description" content="$description">
  <link rel="canonical" href="$origin/${_paths[title]}">
  <link rel="stylesheet" href="/static.css">
</head>
<body>
  <header><a class="brand" href="/">ひたすら広告</a><nav><a href="/about.html">このゲームについて</a><a href="/guide.html">遊び方</a><a href="/catalog.html">広告図鑑</a><a href="/privacy.html">プライバシー</a><a href="/contact.html">運営・お問い合わせ</a></nav></header>
  <main>$body</main>
  <footer><p>© 2026 yorimichi-works　画面内の「架空広告」はゲーム内コンテンツです。</p><p><a href="/">ゲームを起動する</a> · <a href="/privacy.html">プライバシーポリシー</a> · <a href="/contact.html">お問い合わせ</a></p></footer>
</body>
</html>''';

const _paths = {
  'このゲームについて': 'about.html',
  '遊び方': 'guide.html',
  '全151広告図鑑': 'catalog.html',
  'プライバシーポリシー': 'privacy.html',
  '運営・お問い合わせ': 'contact.html',
};

void main() {
  final ads = (jsonDecode(
    File('assets/data/ad_catalog.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  final cards = ads
      .map(
        (ad) =>
            '''<article class="ad-card"><p class="number">No.${(ad['number'] as int).toString().padLeft(3, '0')} · ${escape(ad['category'] as String)}</p><h2>${escape(ad['name'] as String)}</h2><p>${escape(ad['flavorText'] as String)}</p><p class="result">遊ぶ内容：${escape(ad['experienceData']['instruction'] as String)}</p></article>''',
      )
      .join('\n');

  File('web/static.css').writeAsStringSync(
    '''*{box-sizing:border-box}body{margin:0;background:#fff7e8;color:#271d1b;font:16px/1.8 system-ui,-apple-system,"Noto Sans JP",sans-serif}header,main,footer{max-width:1040px;margin:auto;padding:24px}.brand{display:inline-block;color:#271d1b;font-size:28px;font-weight:900;text-decoration:none}nav{display:flex;flex-wrap:wrap;gap:8px 20px;margin-top:12px}a{color:#9b260b}main{min-height:60vh}h1{font-size:clamp(30px,7vw,56px);line-height:1.25}h2{line-height:1.4}section,.ad-card{margin:24px 0;padding:24px;background:#fff;border:2px solid #271d1b;border-radius:14px;box-shadow:6px 6px 0 #ffd16b}.lead{font-size:19px}.notice{padding:16px;background:#fff0b6;border-left:6px solid #e4390b}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:18px}.ad-card{margin:0}.number{font-size:13px;font-weight:800;color:#785e58}.result{font-weight:700}footer{border-top:2px solid #271d1b;margin-top:40px;font-size:14px}dt{font-weight:800;margin-top:16px}button,.play{display:inline-block;padding:13px 20px;background:#ef3510;color:white;border-radius:999px;text-decoration:none;font-weight:800}@media(max-width:600px){header,main,footer{padding:18px}.grid{grid-template-columns:1fr}section,.ad-card{padding:18px}}''',
  );

  final pages = <String, String>{
    'about.html': page(
      title: 'このゲームについて',
      description: '151種類の架空広告を次々に遊ぶゲーム「ひたすら広告」の作品紹介。',
      body: '''<h1>広告を、ひたすら遊ぶ。</h1><p class="lead">「ひたすら広告」は、怪しい広告、妙に大げさな商品広告、どこかで見たゲーム広告を題材にした短編ゲーム集です。通常150本と、全発見後に現れる秘密の1本を収録しています。</p><p><a class="play" href="/">ゲームを起動する</a></p><section><h2>広告の内容そのものが遊び</h2><p>閉じるボタンを追いかける、0.01％の値引きを計算する、王様をピンから救う、回転する剣で書類を片づける。表示を眺めるだけではなく、広告の誇張や矛盾を操作に変えています。</p></section><section><h2>短く、すぐ始まる</h2><p>広告を開くと難易度選択や長い開始説明を挟まず、そのままゲームが始まります。一戦は短く、失敗理由を読んですぐ再挑戦できます。遊んだ広告は図鑑へ登録され、固有のフレーバーテキストを読めます。</p></section><section><h2>実在広告との区別</h2><p>ゲーム画面の「架空広告」は、本作品内で制作したパロディ表現です。実在の商品・広告主を宣伝するものではありません。Googleが配信するスポンサー広告は、ゲーム内コンテンツと区別できる表示で提供します。</p></section>''',
    ),
    'guide.html': page(
      title: '遊び方',
      description: 'ひたすら広告の遊び方、広告図鑑、再挑戦、スポンサー広告の説明。',
      body: '''<h1>遊び方</h1><section><h2>1. プロフィールを決める</h2><p>最初にニックネーム、年齢層、性別を選びます。これはゲーム内で出現する架空広告を変えるための設定です。実在広告のパーソナライズ情報としてGoogleへ渡しません。</p></section><section><h2>2. 広告を探す</h2><p>ホームのボタンから広告を抽選します。見つけた架空広告を開くと、短いゲームがすぐに始まります。画面の指示と動きを見て操作してください。</p></section><section><h2>3. 失敗から読み直す</h2><p>失敗すると、何が起きたかを表示します。「もう一度挑戦」から同じ広告をやり直せます。広告ごとに計算、反応、観察、配置、線引き、アクションなど操作が異なります。</p></section><section><h2>4. 図鑑を埋める</h2><p>終了した広告は図鑑へ登録されます。通常150本を見つけると、秘密の広告が解放されます。図鑑では各広告の物語とプレイ記録を確認できます。</p></section><section><h2>スポンサー広告について</h2><p>探索回数の回復など、任意の場面だけGoogleのスポンサー広告を利用できます。視聴しなくても通常のゲームは遊べます。スポンサー広告の視聴が完了しなかった場合、回復などの報酬は付与されません。</p></section>''',
    ),
    'catalog.html': page(
      title: '全151広告図鑑',
      description: 'ひたすら広告に収録された151種類の架空広告と、それぞれの物語・遊びの一覧。',
      body:
          '<h1>全151広告図鑑</h1><p class="lead">通常150本と秘密の1本。すべて本作品のために作った架空広告です。以下は作品内容を紹介する公開版の図鑑で、ゲーム内の発見状態には影響しません。</p><div class="grid">$cards</div>',
    ),
    'privacy.html': page(
      title: 'プライバシーポリシー',
      description: 'ひたすら広告Web版における保存データ、Google広告、Cookie、Firebase認証の取扱い。',
      body: '''<h1>プライバシーポリシー</h1><p>制定・最終更新：2026年9月10日</p><section><h2>取得・保存する情報</h2><p>本サービスは、ニックネーム、年齢層、性別、ゲーム内の興味設定、広告の発見状況、プレイ回数・時間、探索回数、音声設定を保存します。ログインしない場合は主にブラウザ内へ保存します。</p><p>Googleログインを利用した場合、Firebase AuthenticationからユーザーID、表示名、メールアドレス、プロフィール画像URLを取得し、ゲーム進行とともにGoogle FirebaseのFirestoreへ保存します。</p></section><section><h2>利用目的</h2><p>ゲーム進行の保存、同一アカウントでのデータ同期、架空広告のゲーム内抽選、機能提供、不具合対応のために利用します。ゲーム内プロフィールを、実在広告のパーソナライズ対象を決める情報として広告事業者へ送りません。</p></section><section><h2>Google広告とCookie等</h2><p>Web版ではGoogle AdSenseの広告サービスを利用する場合があります。Googleなどの第三者配信事業者は、広告配信のためCookie、Webビーコン、IPアドレスその他の識別子を使用し、利用者の本サービスや他サイトへのアクセス情報に基づく広告を表示することがあります。</p><p>Googleによるデータ利用は、<a href="https://policies.google.com/technologies/partner-sites?hl=ja">Googleがパートナーのサイトやアプリを使用する際の情報利用</a>をご確認ください。広告設定は<a href="https://adssettings.google.com/">Google広告設定</a>から管理できます。ブラウザ設定でCookieを無効にすると、一部機能や広告が正しく動かない場合があります。</p></section><section><h2>第三者サービス</h2><dl><dt>Google AdSense</dt><dd>スポンサー広告の表示、視聴完了の判定。</dd><dt>Google Firebase Authentication</dt><dd>任意のGoogleログイン。</dd><dt>Google Cloud Firestore</dt><dd>ログイン利用者のゲーム進行同期。</dd><dt>Firebase Hosting</dt><dd>Webサイトの配信。</dd></dl><p>各サービスで送信される情報は、各提供者のポリシーに従って取り扱われます。</p></section><section><h2>保存期間・削除</h2><p>ブラウザ内データは、ブラウザのサイトデータ削除で消去できます。Googleアカウントとの同期データの削除を希望する場合は、お問い合わせ先からご連絡ください。法令上の保存義務がある場合を除き、確認後に対応します。</p></section><section><h2>未成年者</h2><p>未成年の方は、必要に応じて保護者と一緒に本ポリシーを確認してください。本サービスを13歳未満の子ども向けとして広告配信する意図はありません。</p></section><section><h2>改定</h2><p>機能や利用サービスの変更に応じて本ポリシーを改定することがあります。重要な変更は本ページで告知します。</p></section>''',
    ),
    'contact.html': page(
      title: '運営・お問い合わせ',
      description: 'ひたすら広告の運営者情報、連絡先、権利表記。',
      body:
          '''<h1>運営・お問い合わせ</h1><section><h2>運営者</h2><p>yorimichi-works</p><p>作品名：ひたすら広告<br>公開URL：<a href="$origin/">$origin/</a></p></section><section><h2>お問い合わせ</h2><p>不具合、データ削除、権利に関するご連絡は、公開リポジトリのIssueから受け付けています。アカウントや個人情報を本文へ書かないでください。本人確認が必要な内容は、公開投稿後に安全な連絡方法をご案内します。</p><p><a class="play" href="https://github.com/yorimichi-works/hitasura_ads/issues">GitHub Issuesを開く</a></p></section><section><h2>権利と素材</h2><p>ゲーム内の架空広告、文章、独自画像・音声は本作品のために制作しています。一部の音源は、配布元の利用条件に従って使用しています。第三者の商標や作品を公式に扱うものではありません。</p></section>''',
    ),
  };
  for (final entry in pages.entries) {
    File('web/${entry.key}').writeAsStringSync(entry.value);
  }
  stdout.writeln(
    'Built ${pages.length} static pages and ${ads.length} catalog entries.',
  );
}
