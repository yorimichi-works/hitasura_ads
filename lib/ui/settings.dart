import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../arcade/engine/audio.dart';
import '../arcade/engine/sfx.dart';
import '../arcade/registry.dart';
import '../l10n/l10n.dart';
import '../services/release_links.dart';
import '../services/rewarded_ad_service.dart';
import '../state/app_controller.dart';
import 'kit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.rewardedAdService,
  });
  final AppController controller;
  final RewardedAdService? rewardedAdService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.controller.user?.nickname ?? '',
  );

  AppController get c => widget.controller;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NightBackground(
        hue: 180,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AnimatedBuilder(
                animation: c,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 30),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            K.tap(Sfx.back);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        InkText(L10n.ui('settings'), size: 26, color: K.yellow),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _section(
                      L10n.ui('stats'),
                      Column(
                        children: [
                          _stat(
                            L10n.ui('discovered'),
                            '${c.discoveredCount} / ${allGames.length}',
                          ),
                          _stat(
                            L10n.ui('total_plays'),
                            '${c.arcade.totalPlays}',
                          ),
                          _stat(L10n.ui('wins'), '${c.arcade.wins}'),
                          _stat(
                            L10n.ui('stars_total'),
                            '${c.arcade.totalStars}',
                          ),
                          _stat(
                            '${L10n.ui('rush')} ${L10n.ui('rush_best')}',
                            '${c.arcade.rushBest}',
                          ),
                          _stat(L10n.ui('level'), '${c.level}'),
                        ],
                      ),
                    ),
                    _section(
                      L10n.ui('nickname'),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _name,
                              maxLength: 16,
                              style: K.t(16, color: K.ink),
                              decoration: InputDecoration(
                                hintText: L10n.ui('nickname_hint'),
                                counterText: '',
                              ),
                              onSubmitted: c.setNickname,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              K.tap(Sfx.correct);
                              c.setNickname(_name.text);
                              FocusScope.of(context).unfocus();
                            },
                            icon: const Icon(
                              Icons.check_circle_rounded,
                              color: K.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _section(
                      L10n.ui('sound'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: c.soundEffectsEnabled,
                        title: Text(
                          c.soundEffectsEnabled
                              ? L10n.ui('on')
                              : L10n.ui('off'),
                          style: K.t(16, color: K.ink),
                        ),
                        onChanged: (v) {
                          c.setSoundEffectsEnabled(v);
                          ArcadeAudio.instance.muted = !v;
                          if (v) K.tap(Sfx.ding);
                        },
                      ),
                    ),
                    _section(
                      L10n.ui('notifications'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: c.notificationsEnabled,
                        title: Text(
                          L10n.ui('notifications_desc'),
                          style: K.t(14, color: K.ink),
                        ),
                        onChanged: c.setNotificationsEnabled,
                      ),
                    ),
                    _section(
                      L10n.ui('premium_title'),
                      AnimatedBuilder(
                        animation: c.purchases,
                        builder: (context, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              L10n.ui('premium_desc'),
                              style: K.t(14, color: K.ink),
                            ),
                            const SizedBox(height: 8),
                            if (c.premiumNoAds)
                              Text(
                                L10n.ui('premium_active'),
                                style: K.t(
                                  16,
                                  color: K.ink,
                                  weight: FontWeight.w900,
                                ),
                              )
                            else
                              ElevatedButton(
                                onPressed:
                                    c.purchases.product == null ||
                                        c.purchases.busy
                                    ? null
                                    : c.purchases.buy,
                                child: Text(
                                  '${L10n.ui('premium_buy')} ${c.purchases.product?.price ?? ''}',
                                ),
                              ),
                            if (!c.premiumNoAds && c.purchases.product == null)
                              Text(
                                L10n.ui('premium_unavailable'),
                                style: K.t(12, color: K.ink),
                              ),
                            TextButton(
                              onPressed:
                                  c.purchases.available && !c.purchases.busy
                                  ? c.purchases.restore
                                  : null,
                              child: Text(L10n.ui('restore_purchases')),
                            ),
                            if (c.purchases.error != null)
                              Text(
                                c.purchases.error!,
                                style: K.t(12, color: K.red),
                              ),
                          ],
                        ),
                      ),
                    ),
                    _section(
                      L10n.ui('privacy_and_support'),
                      AnimatedBuilder(
                        animation: widget.rewardedAdService ?? c,
                        builder: (context, _) {
                          final ads = widget.rewardedAdService;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    _openLink(ReleaseLinks.privacyPolicy),
                                icon: const Icon(Icons.privacy_tip_outlined),
                                label: Text(L10n.ui('privacy_policy')),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _openLink(ReleaseLinks.support),
                                icon: const Icon(Icons.help_outline),
                                label: Text(L10n.ui('support')),
                              ),
                              if (ads?.privacyOptionsRequired ?? false)
                                TextButton.icon(
                                  onPressed: ads!.privacyBusy
                                      ? null
                                      : ads.showPrivacyOptions,
                                  icon: const Icon(Icons.tune),
                                  label: Text(L10n.ui('ad_privacy_options')),
                                ),
                              if (ads?.privacyHasError ?? false)
                                Text(
                                  L10n.ui('ad_privacy_failed'),
                                  style: K.t(12, color: K.red),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    _section(
                      L10n.ui('language'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final lang in languages)
                            GestureDetector(
                              onTap: () {
                                K.tap();
                                c.setLanguage(lang.code);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: L10n.code == lang.code
                                      ? K.yellow
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: K.ink, width: 2),
                                ),
                                child: Text(
                                  lang.name,
                                  style: K.t(14, color: K.ink),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (c.adminToolsEnabled)
                      _section(
                        'Admin',
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: c.unlockAll,
                          title: Text(
                            'Unlock all (view only)',
                            style: K.t(14, color: K.ink),
                          ),
                          onChanged: c.setUnlockAll,
                        ),
                      ),
                    _section(
                      L10n.ui('credits'),
                      Text(
                        'ひたすら広告 / Nothing But Ads — AD DEMO 151\n'
                        'Games, art, music & sound: procedurally made for this app.\n'
                        'Font: Kosugi Maru (Apache License 2.0).\n'
                        'In-game ads, products and prizes are fictional parodies.\n'
                        'Optional sponsor videos are real third-party ads.',
                        style: K.t(
                          12,
                          color: K.ink.withValues(alpha: .7),
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String value) async {
    final uri = ReleaseLinks.parse(value);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Leave the user in Settings and offer a readable error below.
      }
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L10n.ui('link_unavailable'))));
    }
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Sticker(
      padding: const EdgeInsets.all(14),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: K.t(
                13,
                color: K.ink.withValues(alpha: .55),
                weight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    ),
  );

  Widget _stat(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: K.t(14, color: K.ink)),
        ),
        Text(
          value,
          style: K.t(15, color: K.ink, weight: FontWeight.w900),
        ),
      ],
    ),
  );
}
