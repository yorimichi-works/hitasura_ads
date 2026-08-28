import 'dart:math';

import 'package:flutter/material.dart';

import '../models/ad_definition.dart';
import '../models/ad_visual_assets.dart';
import 'ad_mini_game.dart';

class AdExperienceHost extends StatelessWidget {
  const AdExperienceHost({
    super.key,
    required this.ad,
    required this.onInteraction,
  });

  final AdDefinition ad;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    if (ad.experienceFormat == AdExperienceFormat.playable) {
      return AdMiniGame(ad: ad, onInteraction: onInteraction);
    }
    return _EditorialExperience(ad: ad, onInteraction: onInteraction);
  }
}

class _EditorialExperience extends StatefulWidget {
  const _EditorialExperience({required this.ad, required this.onInteraction});

  final AdDefinition ad;
  final VoidCallback onInteraction;

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
          data['instruction'] ?? '広告を操作しよう',
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
                  child: _complete ? _result() : _content(),
                ),
                if (assets.foregroundAsset != null &&
                    ad.experienceFormat == AdExperienceFormat.productDemo &&
                    !_complete)
                  Positioned(
                    right: 8,
                    top: 46,
                    width: 112,
                    height: 112,
                    child: Semantics(
                      button: true,
                      label: ad.name,
                      child: GestureDetector(
                        key: const Key('experience-product-object'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _advance,
                        child: AnimatedScale(
                          scale: 1 + _step * .04,
                          duration: const Duration(milliseconds: 180),
                          child: Image.asset(
                            assets.foregroundAsset!,
                            fit: BoxFit.contain,
                            cacheWidth: 240,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _content() => switch (ad.experienceFormat) {
    AdExperienceFormat.productDemo => _sequence(
      eyebrow: ad.number >= 66 && ad.number <= 75 ? 'MAKEOVER' : 'LIVE DEMO',
      headline: ad.name,
      labels: [data['step1']!, data['step2']!, data['step3']!],
      icons: const [Icons.touch_app, Icons.compare_arrows, Icons.sell],
    ),
    AdExperienceFormat.factCheck => _evidence(),
    AdExperienceFormat.personalityQuiz => _quiz(),
    AdExperienceFormat.storyReel => _story(),
    AdExperienceFormat.newsBulletin => _news(),
    AdExperienceFormat.systemScan => _scan(),
    AdExperienceFormat.webTrap => _webTrap(),
    AdExperienceFormat.playable => const SizedBox.shrink(),
  };

  Widget _sequence({
    required String eyebrow,
    required String headline,
    required List<String> labels,
    required List<IconData> icons,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Eyebrow(eyebrow),
      const SizedBox(height: 5),
      Text(
        headline,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      const Spacer(),
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
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(done ? Icons.check : icons[index], size: 20),
                    const SizedBox(height: 3),
                    Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
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

  Widget _evidence() {
    final evidence = [
      data['evidence1']!,
      data['evidence2']!,
      data['evidence3']!,
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
    final question = data['question${_step + 1}']!;
    const answers = ['じっくり考える', '直感で選ぶ', '広告を観察する'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow('AI DIAGNOSIS  ${_step + 1}/3'),
        const SizedBox(height: 8),
        Text(
          question,
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
    final scene = data['scene${_step + 1}']!;
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
            scene,
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
    final updates = [data['lead']!, data['update1']!, data['update2']!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: const Color(0xFFD50000),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            data['ticker']!,
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
    final scans = [data['scan1']!, data['scan2']!, data['scan3']!];
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
        child: Text(data['bait1']!),
      ),
      FilledButton(
        key: const Key('experience-bait-2'),
        onPressed: _wrong,
        style: FilledButton.styleFrom(backgroundColor: Colors.green),
        child: Text(data['bait2']!),
      ),
      OutlinedButton(
        key: Key('experience-step-$_step'),
        onPressed: _advance,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        child: Text('${data['safe']} ${_step + 1}/3'),
      ),
    ],
  );

  Widget _result() {
    final text = ad.experienceFormat == AdExperienceFormat.personalityQuiz
        ? data['result${['A', 'B', 'C'][(_score / 3).round().clamp(0, 2)]}']!
        : data['verdict'] ?? ad.resultText;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
