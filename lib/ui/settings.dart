import 'dart:async';

import 'package:flutter/material.dart';

import '../arcade/engine/audio.dart';
import '../arcade/engine/sfx.dart';
import '../arcade/registry.dart';
import '../l10n/l10n.dart';
import '../services/google_auth_service.dart';
import '../state/app_controller.dart';
import 'kit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = GoogleAuthService();
  late final TextEditingController _name = TextEditingController(text: widget.controller.user?.nickname ?? '');

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_refresh);
    unawaited(_auth.initialize());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth.removeListener(_refresh);
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
                builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(12, 6, 12, 30), children: [
                  Row(children: [
                    IconButton(
                      onPressed: () {
                        K.tap(Sfx.back);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    InkText(L10n.ui('settings'), size: 26, color: K.yellow),
                  ]),
                  const SizedBox(height: 10),
                  _section(L10n.ui('stats'), Column(children: [
                    _stat(L10n.ui('discovered'), '${c.discoveredCount} / ${allGames.length}'),
                    _stat(L10n.ui('total_plays'), '${c.arcade.totalPlays}'),
                    _stat(L10n.ui('wins'), '${c.arcade.wins}'),
                    _stat(L10n.ui('stars_total'), '${c.arcade.totalStars}'),
                    _stat('${L10n.ui('rush')} ${L10n.ui('rush_best')}', '${c.arcade.rushBest}'),
                    _stat(L10n.ui('level'), '${c.level}'),
                  ])),
                  _section(L10n.ui('nickname'), Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _name,
                        maxLength: 16,
                        style: K.t(16, color: K.ink),
                        decoration: InputDecoration(hintText: L10n.ui('nickname_hint'), counterText: ''),
                        onSubmitted: c.setNickname,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        K.tap(Sfx.correct);
                        c.setNickname(_name.text);
                        FocusScope.of(context).unfocus();
                      },
                      icon: const Icon(Icons.check_circle_rounded, color: K.ink),
                    ),
                  ])),
                  _section(L10n.ui('sound'), SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: c.soundEffectsEnabled,
                    title: Text(c.soundEffectsEnabled ? L10n.ui('on') : L10n.ui('off'), style: K.t(16, color: K.ink)),
                    onChanged: (v) {
                      c.setSoundEffectsEnabled(v);
                      ArcadeAudio.instance.muted = !v;
                      if (v) K.tap(Sfx.ding);
                    },
                  )),
                  _section(L10n.ui('language'), Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final lang in languages)
                      GestureDetector(
                        onTap: () {
                          K.tap();
                          c.setLanguage(lang.code);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: L10n.code == lang.code ? K.yellow : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: K.ink, width: 2),
                          ),
                          child: Text(lang.name, style: K.t(14, color: K.ink)),
                        ),
                      ),
                  ])),
                  _section(L10n.ui('cloud'), _cloud()),
                  if (c.adminToolsEnabled)
                    _section('Admin', SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: c.unlockAll,
                      title: Text('Unlock all (view only)', style: K.t(14, color: K.ink)),
                      onChanged: c.setUnlockAll,
                    )),
                  _section(L10n.ui('credits'), Text(
                    'ひたすら広告 / Nothing But Ads — AD DEMO 151\n'
                    'Games, art, music & sound: procedurally made for this app.\n'
                    'Font: Kosugi Maru (Apache License 2.0).\n'
                    'All ads, products and prizes in this app are fictional parodies.',
                    style: K.t(12, color: K.ink.withValues(alpha: .7), weight: FontWeight.w600),
                  )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cloud() {
    if (!_auth.isConfigured || _auth.initFailed) {
      return Text('—', style: K.t(14, color: K.ink));
    }
    if (!_auth.isSignedIn) {
      return ChunkyButton(
        onTap: _auth.isBusy ? null : () => unawaited(_auth.signIn()),
        color: Colors.white,
        height: 48,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.login_rounded, color: K.ink),
          const SizedBox(width: 8),
          Text(L10n.ui('sign_in'), style: K.t(15, color: K.ink)),
        ]),
      );
    }
    final a = _auth.account!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(a.displayName ?? a.email, style: K.t(15, color: K.ink)),
      Text(a.email, style: K.t(12, color: K.ink.withValues(alpha: .6))),
      const SizedBox(height: 6),
      Text(c.cloudSyncError != null ? L10n.ui('sync_error') : (c.cloudSynced ? L10n.ui('synced') : '…'),
          style: K.t(13, color: c.cloudSyncError != null ? K.red : const Color(0xFF1E9E5A))),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: _auth.isBusy ? null : () => unawaited(_auth.signOut()),
        icon: const Icon(Icons.logout_rounded),
        label: Text(L10n.ui('sign_out')),
      ),
    ]);
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Sticker(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: K.t(13, color: K.ink.withValues(alpha: .55), weight: FontWeight.w900)),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      );

  Widget _stat(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: K.t(14, color: K.ink))),
          Text(value, style: K.t(15, color: K.ink, weight: FontWeight.w900)),
        ]),
      );
}
