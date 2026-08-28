import 'dart:math';

import 'package:flutter/material.dart';

import '../models/ad_definition.dart';
import '../models/ad_sound_profile.dart';
import '../models/ad_visual_assets.dart';
import 'ad_mini_game.dart';

class AdExperienceHost extends StatelessWidget {
  const AdExperienceHost({
    super.key,
    required this.ad,
    required this.onInteraction,
    this.onSoundEvent,
  });

  final AdDefinition ad;
  final VoidCallback onInteraction;
  final ValueChanged<AdSoundEvent>? onSoundEvent;

  @override
  Widget build(BuildContext context) {
    if (ad.experienceFormat == AdExperienceFormat.playable) {
      return AdMiniGame(
        ad: ad,
        onInteraction: onInteraction,
        onSoundEvent: onSoundEvent,
      );
    }
    return _EditorialExperience(
      ad: ad,
      onInteraction: onInteraction,
      onSoundEvent: onSoundEvent,
    );
  }
}

class _EditorialExperience extends StatefulWidget {
  const _EditorialExperience({
    required this.ad,
    required this.onInteraction,
    this.onSoundEvent,
  });

  final AdDefinition ad;
  final VoidCallback onInteraction;
  final ValueChanged<AdSoundEvent>? onSoundEvent;

  @override
  State<_EditorialExperience> createState() => _EditorialExperienceState();
}

class _EditorialExperienceState extends State<_EditorialExperience> {
  int _step = 0;
  int _score = 0;
  int _wrongChoices = 0;
  bool _started = false;

  AdDefinition get ad => widget.ad;
  Map<String, String> get data => ad.experienceData;
  bool get _complete => _step >= 3;

  void _advance({int score = 0}) {
    if (!_started) {
      _started = true;
      widget.onInteraction();
    }
    widget.onSoundEvent?.call(
      _step >= 2 ? AdSoundEvent.success : AdSoundEvent.interaction,
    );
    setState(() {
      _score += score;
      _step = min(3, _step + 1);
    });
  }

  void _wrong() {
    if (!_started) {
      _started = true;
      widget.onInteraction();
    }
    widget.onSoundEvent?.call(AdSoundEvent.failure);
    setState(() => _wrongChoices++);
  }

  void _reset() => setState(() {
    _step = 0;
    _score = 0;
    _wrongChoices = 0;
    _started = false;
  });

  @override
  Widget build(BuildContext context) {
    final assets = AdVisualAssets.forAd(ad);
    return Column(
      children: [
        Text(
          ad.semantic.action,
          key: const Key('experience-instruction'),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        if (ad.experienceFormat != AdExperienceFormat.playable) ...[
          const SizedBox(height: 4),
          Text(
            ad.name,
            key: const Key('experience-ad-title'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ad.accentColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${ad.semantic.subject}  •  ${ad.semantic.action}  •  ${ad.semantic.object}',
            key: const Key('experience-semantic-context'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
        if (ad.experienceFormat != AdExperienceFormat.playable &&
            ad.fixedValues.isNotEmpty) ...[
          const SizedBox(height: 5),
          SizedBox(
            height: 26,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ad.fixedValues.length,
              separatorBuilder: (_, _) => const SizedBox(width: 5),
              itemBuilder: (context, index) {
                final entry = ad.fixedValues.entries.elementAt(index);
                return Container(
                  key: Key('fixed-${ad.id}-${entry.value}'),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: ad.accentColor, width: 2),
                  ),
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: AdGameStage(
            ad: ad,
            backgroundAsset: assets.backgroundAsset,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x55000000), Color(0xCC000000)],
                      ),
                    ),
                  ),
                ),
                if (assets.foregroundAsset != null &&
                    ad.experienceFormat != AdExperienceFormat.productDemo)
                  Positioned(
                    right: 8,
                    bottom: 4,
                    width: 112,
                    height: 112,
                    child: IgnorePointer(
                      child: Image.asset(
                        assets.foregroundAsset!,
                        fit: BoxFit.contain,
                        cacheWidth: 240,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: _complete ? _result() : _content(assets),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(AdVisualAssets assets) => switch (ad.experienceFormat) {
    AdExperienceFormat.productDemo => _productDemo(assets),
    AdExperienceFormat.factCheck => _evidence(),
    AdExperienceFormat.personalityQuiz => _quiz(),
    AdExperienceFormat.storyReel => _story(),
    AdExperienceFormat.newsBulletin => _news(),
    AdExperienceFormat.systemScan => _scan(),
    AdExperienceFormat.webTrap => _webTrap(),
    AdExperienceFormat.playable => const SizedBox.shrink(),
  };

  Widget _productDemo(AdVisualAssets assets) {
    final spec = _ProductDemoSpec.forAd(ad);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow(ad.number >= 66 && ad.number <= 75 ? 'MAKEOVER' : 'LIVE DEMO'),
        const SizedBox(height: 4),
        Text(
          spec.scene,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: _productStage(spec, assets.foregroundAsset)),
        const SizedBox(height: 5),
        Row(
          children: List.generate(3, (index) {
            final done = index < _step;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 5),
                child: FilledButton(
                  key: Key('experience-step-$index'),
                  onPressed: index == _step ? _advance : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: done ? Colors.green : ad.accentColor,
                    foregroundColor: _contrast(ad.accentColor),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(done ? Icons.check : spec.icon, size: 18),
                      const SizedBox(height: 2),
                      Text(
                        spec.steps[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _productStage(_ProductDemoSpec spec, String? productAsset) {
    final isKnife = ad.number == 16;
    return Semantics(
      button: true,
      label: spec.action,
      child: GestureDetector(
        key: const Key('experience-product-object'),
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        onHorizontalDragEnd: isKnife ? (_) => _advance() : null,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xB3000000),
            border: Border.all(color: ad.accentColor, width: 2),
          ),
          child: isKnife
              ? _knifeDemo(productAsset)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Icon(spec.icon, color: Colors.white70, size: 42),
                      ),
                    ),
                    if (productAsset != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedScale(
                          scale: 1 + _step * .08,
                          duration: const Duration(milliseconds: 180),
                          child: Image.asset(
                            productAsset,
                            width: 108,
                            height: 108,
                            fit: BoxFit.contain,
                            cacheWidth: 240,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Text(
                          '${spec.action}  ${_step + 1}/3',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _knifeDemo(String? knifeAsset) => Stack(
    fit: StackFit.expand,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Image.asset(
          _step >= 2
              ? 'assets/images/generated/game/sashimi_plate.png'
              : 'assets/images/generated/game/whole_fish.png',
          key: Key(_step >= 2 ? 'sashimi-result' : 'whole-fish'),
          width: 126,
          fit: BoxFit.contain,
          cacheWidth: 260,
        ),
      ),
      if (knifeAsset != null && _step < 2)
        AnimatedAlign(
          alignment: Alignment(-.05 + _step * .38, -.45 + _step * .35),
          duration: const Duration(milliseconds: 180),
          child: Transform.rotate(
            angle: -.45,
            child: Image.asset(
              knifeAsset,
              width: 94,
              fit: BoxFit.contain,
              cacheWidth: 200,
            ),
          ),
        ),
      Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Text(
            _step >= 2 ? '刺身が完成' : '包丁を横へ滑らせる ${_step + 1}/3',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _evidence() {
    final evidence = [
      '${ad.semantic.subject}と「${ad.semantic.object}」の存在を確認',
      '${ad.semantic.setting}で「${ad.semantic.action}」を再現',
      '広告の説明を照合：${ad.description}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('AD FACT CHECK'),
        const SizedBox(height: 5),
        Text(
          data['claim']!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        ...List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(top: 5),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('experience-step-$index'),
                onPressed: index == _step ? _advance : null,
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  backgroundColor: index < _step
                      ? const Color(0xDD1B5E20)
                      : const Color(0xDDFFFFFF),
                  foregroundColor: index < _step ? Colors.white : Colors.black,
                ),
                icon: Icon(
                  index < _step ? Icons.verified : Icons.description,
                  size: 18,
                ),
                label: Text(
                  evidence[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quiz() {
    final questions = [
      '「${ad.semantic.object}」を見た最初の反応は？',
      '${ad.semantic.setting}で「${ad.semantic.action}」ならどうする？',
      '${ad.semantic.subject}へ一番近い距離感は？',
    ];
    final answers = switch (_step) {
      0 => const ['まず観察する', 'すぐ触ってみる', '広告だと疑う'],
      1 => const ['手順を確認する', '直感で進める', '結果を比較する'],
      _ => const ['慎重に見守る', '一緒に参加する', '記録して分析する'],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow('AI DIAGNOSIS  ${_step + 1}/3'),
        const SizedBox(height: 8),
        Text(
          questions[_step],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        ...List.generate(
          3,
          (index) => SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: Key('experience-choice-$index'),
              onPressed: () => _advance(score: index),
              style: FilledButton.styleFrom(
                backgroundColor: index == 0
                    ? const Color(0xFF1565C0)
                    : index == 1
                    ? const Color(0xFFE65100)
                    : const Color(0xFF6A1B9A),
              ),
              child: Text(answers[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _story() {
    final scenes = [
      '0:00  ${ad.semantic.setting}に${ad.semantic.subject}が現れる',
      '0:03  ${ad.semantic.object}で「${ad.semantic.action}」',
      '0:06  ${ad.description}',
    ];
    return InkWell(
      key: const Key('experience-story-next'),
      onTap: _advance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: index == 0 ? 0 : 4),
                  height: 4,
                  color: index <= _step ? Colors.white : Colors.white30,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _Eyebrow('SPONSORED STORY'),
          const Spacer(),
          Text(
            scenes[_step],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
          const Spacer(),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, color: Colors.white),
              SizedBox(width: 5),
              Text('タップで次のカット', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _news() {
    final updates = [
      ad.name,
      '${ad.semantic.setting}から中継。${ad.semantic.subject}が${ad.semantic.object}を確認。',
      '現場では「${ad.semantic.action}」。${ad.description}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: const Color(0xFFD50000),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '速報 No.${ad.number.toString().padLeft(3, '0')}  ${ad.semantic.object}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Spacer(),
        Text(
          updates[_step],
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          key: Key('experience-step-$_step'),
          onPressed: _advance,
          icon: const Icon(Icons.campaign),
          label: Text(_step == 2 ? '最終確認' : '続報を開く'),
        ),
      ],
    );
  }

  Widget _scan() {
    final scans = [
      '対象：${ad.semantic.object}',
      '操作：${ad.semantic.action}',
      '発生場所：${ad.semantic.setting}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('SECURITY CHECK'),
        const SizedBox(height: 8),
        ...List.generate(
          3,
          (index) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              index < _step
                  ? Icons.check_circle
                  : index == _step
                  ? Icons.radar
                  : Icons.radio_button_unchecked,
              color: index < _step ? Colors.greenAccent : Colors.white,
            ),
            title: Text(
              scans[index],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          key: Key('experience-step-$_step'),
          onPressed: _advance,
          icon: const Icon(Icons.manage_search),
          label: Text('検査 ${_step + 1}/3'),
        ),
      ],
    );
  }

  Widget _webTrap() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Eyebrow('WWW / SPONSORED'),
      const SizedBox(height: 5),
      Text(
        ad.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      if (_wrongChoices > 0)
        Text(
          'そのボタンは広告でした ×$_wrongChoices',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w900,
          ),
        ),
      const Spacer(),
      FilledButton(
        key: const Key('experience-bait-1'),
        onPressed: _wrong,
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
        child: Text('今すぐ${ad.semantic.action}'),
      ),
      FilledButton(
        key: const Key('experience-bait-2'),
        onPressed: _wrong,
        style: FilledButton.styleFrom(backgroundColor: Colors.green),
        child: Text('${ad.semantic.object}を無料で開く'),
      ),
      OutlinedButton(
        key: Key('experience-step-$_step'),
        onPressed: _advance,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        child: Text('仕組みを確認して進む ${_step + 1}/3'),
      ),
    ],
  );

  Widget _result() {
    final text = ad.experienceFormat == AdExperienceFormat.personalityQuiz
        ? '診断結果：${['慎重', '直感', '観察'][(_score / 3).round().clamp(0, 2)]}型。${ad.semantic.subject}は${ad.semantic.object}を前に「${ad.semantic.action}」選択をしました。'
        : data['verdict'] ?? ad.resultText;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (ad.number == 16)
          Image.asset(
            'assets/images/generated/game/sashimi_plate.png',
            key: const Key('sashimi-result'),
            width: 118,
            height: 82,
            fit: BoxFit.contain,
            cacheWidth: 240,
          ),
        Icon(_resultIcon, color: Colors.amberAccent, size: 44),
        const SizedBox(height: 8),
        Text(
          text,
          key: const Key('experience-success'),
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('experience-reset'),
          onPressed: _reset,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          icon: const Icon(Icons.replay),
          label: const Text('もう一度'),
        ),
      ],
    );
  }

  IconData get _resultIcon => switch (ad.experienceFormat) {
    AdExperienceFormat.productDemo => Icons.inventory_2,
    AdExperienceFormat.factCheck => Icons.fact_check,
    AdExperienceFormat.personalityQuiz => Icons.psychology,
    AdExperienceFormat.storyReel => Icons.movie,
    AdExperienceFormat.newsBulletin => Icons.newspaper,
    AdExperienceFormat.systemScan => Icons.health_and_safety,
    AdExperienceFormat.webTrap => Icons.travel_explore,
    AdExperienceFormat.playable => Icons.sports_esports,
  };
}

class _ProductDemoSpec {
  const _ProductDemoSpec({
    required this.scene,
    required this.action,
    required this.steps,
    required this.icon,
  });

  factory _ProductDemoSpec.forAd(AdDefinition ad) => switch (ad.number) {
    11 => const _ProductDemoSpec(
      scene: '空のコップへ本当に水を注ぐ',
      action: '水量を増やす',
      steps: ['一口分', '半分', '満水'],
      icon: Icons.water_drop,
    ),
    12 => const _ProductDemoSpec(
      scene: '椅子へ荷重をかけて座り心地を検証',
      action: '座って荷重する',
      steps: ['浅く座る', '深く座る', '立ち上がる'],
      icon: Icons.chair,
    ),
    13 => const _ProductDemoSpec(
      scene: '開かない傘のロックを雨の中で検証',
      action: '傘を開こうとする',
      steps: ['留め具', '持ち手', '力ずく'],
      icon: Icons.umbrella,
    ),
    14 => const _ProductDemoSpec(
      scene: '財布へ硬貨・紙幣・カードを収納',
      action: '財布へ入れる',
      steps: ['硬貨', '紙幣', 'カード'],
      icon: Icons.account_balance_wallet,
    ),
    15 => const _ProductDemoSpec(
      scene: '枕へ頭を預けて入眠までを計測',
      action: '眠りを深くする',
      steps: ['横になる', '目を閉じる', '熟睡'],
      icon: Icons.bedtime,
    ),
    16 => const _ProductDemoSpec(
      scene: '包丁で一尾の魚を刺身にする実演',
      action: '魚を切る',
      steps: ['一太刀', '切り分け', '盛り付け'],
      icon: Icons.restaurant,
    ),
    17 => const _ProductDemoSpec(
      scene: '常温の食品を冷蔵庫で冷却',
      action: '温度を下げる',
      steps: ['収納', '冷却', '冷え冷え'],
      icon: Icons.ac_unit,
    ),
    18 => const _ProductDemoSpec(
      scene: '靴を履いて三段階の歩行試験',
      action: '歩いて試す',
      steps: ['一歩', '十歩', '完走'],
      icon: Icons.directions_walk,
    ),
    19 => const _ProductDemoSpec(
      scene: 'カバンへ荷物を詰めて持ち運ぶ',
      action: '荷物を運ぶ',
      steps: ['小物', '書類', '満載'],
      icon: Icons.luggage,
    ),
    20 => const _ProductDemoSpec(
      scene: '水2026を開封して三口飲む',
      action: '水を飲む',
      steps: ['一口', '二口', '飲み切る'],
      icon: Icons.local_drink,
    ),
    66 => const _ProductDemoSpec(
      scene: '泥だらけの靴を磨いて本来の色へ',
      action: '靴を磨く',
      steps: ['泥を落す', '泡で洗う', '磨き上げ'],
      icon: Icons.cleaning_services,
    ),
    67 => const _ProductDemoSpec(
      scene: '壁のない部屋へ必要な家具を配置',
      action: '部屋を整える',
      steps: ['壁を作る', '家具を置く', '照明を点灯'],
      icon: Icons.weekend,
    ),
    68 => const _ProductDemoSpec(
      scene: '汚れた部屋を掃除して豪邸化',
      action: '部屋を掃除する',
      steps: ['ゴミ回収', '床を磨く', '豪邸完成'],
      icon: Icons.house,
    ),
    69 => const _ProductDemoSpec(
      scene: '15秒の仕事選びで資産を増やす',
      action: '収入源を選ぶ',
      steps: ['働く', '貯める', '億万長者'],
      icon: Icons.trending_up,
    ),
    70 => const _ProductDemoSpec(
      scene: '所持金3円から買い物を積み上げる',
      action: '3円を運用する',
      steps: ['節約', '商売', '資産形成'],
      icon: Icons.savings,
    ),
    71 => const _ProductDemoSpec(
      scene: '三つの選択肢から人生逆転ルートへ',
      action: '人生を選ぶ',
      steps: ['休む', '学ぶ', '逆転する'],
      icon: Icons.alt_route,
    ),
    72 => const _ProductDemoSpec(
      scene: '衣装を順に重ねて王族へ着せ替え',
      action: '服を着替える',
      steps: ['正装', 'マント', '王冠'],
      icon: Icons.checkroom,
    ),
    73 => const _ProductDemoSpec(
      scene: 'ボロ家を補修して宮殿へ改築',
      action: '家を建て替える',
      steps: ['壁を補修', '塔を増築', '宮殿完成'],
      icon: Icons.castle,
    ),
    74 => const _ProductDemoSpec(
      scene: 'スポンジ一本で汚れを9999除去',
      action: '汚れをこする',
      steps: ['100除去', '1000除去', '9999除去'],
      icon: Icons.auto_fix_high,
    ),
    75 => const _ProductDemoSpec(
      scene: '同じ人物を段階的に身だしなみ改善',
      action: '本人を整える',
      steps: ['洗顔', '髪型', '服装'],
      icon: Icons.face_retouching_natural,
    ),
    143 => const _ProductDemoSpec(
      scene: '価格を入力して0.01％割引を実演',
      action: '割引額を計算する',
      steps: ['価格入力', '0.01％引', '差額確認'],
      icon: Icons.percent,
    ),
    _ => _ProductDemoSpec(
      scene: ad.name,
      action: '実演する',
      steps: const ['確認1', '確認2', '確認3'],
      icon: Icons.touch_app,
    ),
  };

  final String scene;
  final String action;
  final List<String> steps;
  final IconData icon;
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      color: Colors.white70,
      fontSize: 11,
      fontWeight: FontWeight.w900,
    ),
  );
}

Color _contrast(Color color) =>
    color.computeLuminance() > .45 ? Colors.black : Colors.white;
