import 'ad_definition.dart';

enum AdSoundEvent { interaction, success, failure }

class AdSoundProfile {
  const AdSoundProfile({
    required this.interaction,
    required this.success,
    required this.failure,
    required this.reason,
  });

  final String interaction;
  final String success;
  final String failure;
  final String reason;

  String assetFor(AdSoundEvent event) => switch (event) {
    AdSoundEvent.interaction => interaction,
    AdSoundEvent.success => success,
    AdSoundEvent.failure => failure,
  };

  factory AdSoundProfile.forAd(AdDefinition ad) {
    const soft = 'soundeffect_lab/decision3.mp3';
    const heavy = 'soundeffect_lab/decision11.mp3';
    const retro = 'soundeffect_lab/decision17.mp3';
    const cute = 'soundeffect_lab/decision22.mp3';
    const warning = 'soundeffect_lab/warning2.mp3';
    const success = 'soundeffect_lab/success1.mp3';
    const levelUp = 'soundeffect_lab/levelup1.mp3';
    const scratch = 'soundeffect_lab/dj-scratch1.mp3';
    const news = 'soundeffect_lab/news-title1.mp3';
    const correct = 'soundeffect_lab/correct2.mp3';
    const incorrect = 'soundeffect_lab/incorrect1.mp3';
    const shine = 'soundeffect_lab/shine3.mp3';
    const explosion = 'soundeffect_lab/bomb1.mp3';
    const silly = 'soundeffect_lab/stupid5.mp3';
    const dash = 'soundeffect_lab/machdash1.mp3';
    const eat = 'soundeffect_lab/suck1.mp3';
    const toggle = 'soundeffect_lab/switch1.mp3';
    const brake = 'soundeffect_lab/brake1.mp3';
    const data = 'soundeffect_lab/data-analysis1.mp3';
    const chest = 'soundeffect_lab/treasure-chest1.mp3';
    const item = 'soundeffect_lab/item-get1.mp3';
    const cash = 'soundeffect_lab/clearing1.mp3';
    const slash = 'soundeffect_lab/sword-slash2.mp3';
    const flame = 'soundeffect_lab/magic-flame1.mp3';
    const dog = 'soundeffect_lab/dog1.mp3';

    AdSoundProfile profile(
      String interaction,
      String successSound,
      String failureSound,
      String reason,
    ) => AdSoundProfile(
      interaction: interaction,
      success: successSound,
      failure: failureSound,
      reason: reason,
    );

    return switch (ad.number) {
      1 ||
      2 ||
      3 ||
      5 ||
      7 ||
      8 ||
      9 => profile(retro, success, silly, 'レトロWebのボタンと罠'),
      4 || 10 => profile(news, success, silly, '古いWebの中継・速報'),
      6 => profile(data, correct, incorrect, '割引表示の検証'),
      11 ||
      12 ||
      13 ||
      15 ||
      17 ||
      19 => profile(soft, success, silly, '通販商品の実演'),
      14 => profile(cash, success, silly, '財布への収納実演'),
      16 => profile(slash, success, incorrect, '包丁で魚を切る実演'),
      18 => profile(brake, success, silly, '靴の歩行試験'),
      20 => profile(eat, success, silly, '水の試飲'),
      >= 21 && <= 30 => profile(data, correct, incorrect, '広告主張の監査'),
      31 ||
      33 ||
      34 ||
      39 ||
      40 ||
      43 ||
      45 => profile(toggle, chest, incorrect, '王様救出のピンと宝'),
      32 || 36 || 37 => profile(toggle, chest, flame, '炎から王様を救出'),
      35 => profile(soft, success, incorrect, '水没した王様の救出線'),
      38 => profile(toggle, correct, incorrect, '救出率タイミング停止'),
      41 => profile(dash, item, incorrect, '王様の資産ゲート'),
      42 => profile(soft, chest, incorrect, '地下の宝を運ぶ'),
      44 => profile(cute, success, silly, '休日の王様を見つける'),
      >= 46 && <= 55 => profile(dash, levelUp, explosion, '倍率ランナーと数値バトル'),
      56 ||
      57 ||
      60 ||
      63 ||
      64 ||
      65 => profile(soft, success, incorrect, 'ドラッグ・線引きパズル'),
      58 => profile(toggle, success, incorrect, '水をコップへ導く'),
      59 => profile(dog, success, explosion, '犬を蜂から守る'),
      61 || 62 => profile(brake, success, incorrect, '赤い車を駐車場から動かす'),
      66 ||
      67 ||
      68 ||
      73 ||
      74 ||
      75 => profile(soft, shine, silly, '掃除・美容・改装の変身'),
      69 || 70 => profile(cash, item, silly, '所持金と資産を増やす'),
      71 || 72 => profile(cute, shine, incorrect, '人生・衣装の選択'),
      76 || 77 => profile(eat, levelUp, incorrect, '魚の捕食と進化'),
      78 ||
      79 ||
      80 ||
      81 ||
      82 ||
      83 ||
      85 => profile(cute, levelUp, silly, '素材・生物の合体進化'),
      84 => profile(toggle, levelUp, silly, '卵から社長を孵化'),
      86 ||
      87 ||
      88 ||
      90 ||
      91 => profile(toggle, item, incorrect, 'スロット・ルーレット停止'),
      89 => profile(toggle, cash, incorrect, '大量コイン抽選'),
      92 => profile(scratch, item, incorrect, 'スクラッチ面を削る'),
      93 ||
      94 ||
      95 ||
      97 ||
      98 ||
      99 ||
      100 => profile(chest, item, silly, '広告パックの開封'),
      96 => profile(chest, correct, incorrect, '価格を鑑定して開封'),
      >= 101 && <= 109 => profile(data, correct, incorrect, 'AI・性格診断の回答'),
      110 => profile(toggle, data, silly, 'AI搭載ボタン'),
      111 ||
      113 ||
      114 ||
      115 ||
      116 ||
      117 ||
      118 ||
      119 ||
      120 => profile(soft, success, silly, '縦動画・SNS広告の場面送り'),
      112 => profile(news, success, warning, 'CM後のニュース速報'),
      121 || 124 || 125 || 130 => profile(news, success, warning, '警告・セール速報'),
      122 ||
      126 ||
      127 ||
      128 ||
      129 => profile(data, success, warning, '端末スキャンと警告'),
      123 => profile(soft, item, silly, '増殖する在庫箱'),
      >= 131 && <= 140 => profile(retro, success, silly, '意味不明なWeb広告の探索'),
      141 => profile(retro, shine, incorrect, '伝説の閉じるボタン'),
      142 => profile(soft, levelUp, silly, '広告王の王冠を磨く'),
      143 => profile(cash, correct, silly, '0.01%割引を計算'),
      144 => profile(news, success, warning, '幻の在庫速報'),
      145 => profile(data, shine, incorrect, '未知レアカードを鑑定'),
      146 => profile(data, correct, incorrect, '広告博士の最終講義'),
      147 => profile(toggle, chest, flame, '最後の王様救出'),
      148 => profile(chest, item, incorrect, '究極広告パック開封'),
      149 => profile(news, success, warning, '151番直前の終幕映像'),
      150 => profile(data, correct, incorrect, '図鑑150件の完成監査'),
      151 => profile(heavy, levelUp, explosion, 'アドゴンの最終進化'),
      _ => throw RangeError.range(ad.number, 1, 151, 'ad.number'),
    };
  }
}
