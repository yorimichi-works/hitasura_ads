import 'package:flutter/material.dart';

import '../arcade/engine/sfx.dart';
import '../l10n/l10n.dart';
import '../state/app_controller.dart';
import 'kit.dart';

/// Language pick + nickname. Kept to one screen: players want to play.
class FirstLaunchScreen extends StatefulWidget {
  const FirstLaunchScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<FirstLaunchScreen> createState() => _FirstLaunchScreenState();
}

class _FirstLaunchScreenState extends State<FirstLaunchScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
                      children: [
                        Pulse(
                          child: Transform.rotate(
                            angle: -.05,
                            child: InkText(
                              L10n.ui('app_title'),
                              size: 48,
                              color: K.yellow,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Pill(
                            L10n.ui('app_sub'),
                            color: K.pink,
                            textColor: Colors.white,
                            size: 14,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Sticker(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                L10n.ui('welcome'),
                                style: K.t(
                                  20,
                                  color: K.ink,
                                  weight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                L10n.ui('welcome_body'),
                                style: K.t(
                                  14,
                                  color: K.ink.withValues(alpha: .75),
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                L10n.ui('language'),
                                style: K.t(
                                  12,
                                  color: K.ink.withValues(alpha: .55),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final lang in languages)
                                    GestureDetector(
                                      onTap: () {
                                        K.tap();
                                        setState(() => L10n.code = lang.code);
                                        c.setLanguage(lang.code);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: L10n.code == lang.code
                                              ? K.yellow
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: K.ink,
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          lang.name,
                                          style: K.t(13, color: K.ink),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                L10n.ui('nickname'),
                                style: K.t(
                                  12,
                                  color: K.ink.withValues(alpha: .55),
                                ),
                              ),
                              TextField(
                                controller: _name,
                                maxLength: 16,
                                style: K.t(18, color: K.ink),
                                decoration: InputDecoration(
                                  hintText: L10n.ui('nickname_hint'),
                                  counterText: '',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                    child: ChunkyButton(
                      onTap: () => c.register(_name.text),
                      color: K.pink,
                      height: 68,
                      sound: Sfx.go,
                      child: InkText(L10n.ui('start'), size: 28, shadow: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
