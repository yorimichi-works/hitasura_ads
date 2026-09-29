// Developer playtest launcher: pick any of the 151 games and play it directly
// (no progress is saved).
//
//   flutter run -d chrome -t lib/playtest_main.dart
import 'package:flutter/material.dart';

import 'app.dart';
import 'arcade/engine/audio.dart';
import 'arcade/engine/game_view.dart';
import 'arcade/registry.dart';
import 'arcade/spec.dart';
import 'l10n/l10n.dart';
import 'ui/kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  L10n.code = L10n.detect();
  applyLanguage();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: _Picker()));
}

class _Picker extends StatefulWidget {
  const _Picker();

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  double _speed = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.night,
      appBar: AppBar(
        title: const Text('AD DEMO 151 — playtest'),
        actions: [
          DropdownButton<String>(
            value: L10n.code,
            items: [for (final l in languages) DropdownMenuItem(value: l.code, child: Text(l.name))],
            onChanged: (v) => setState(() {
              L10n.code = v!;
              applyLanguage();
            }),
          ),
          const SizedBox(width: 8),
          Text('speed ${_speed.toStringAsFixed(1)}'),
          Slider(value: _speed, min: 1, max: 1.9, onChanged: (v) => setState(() => _speed = v)),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 6,
        padding: const EdgeInsets.all(8),
        children: [
          for (final g in allGames)
            InkWell(
              onTap: () => _play(g),
              child: Card(
                color: K.category(g.cat),
                child: Center(
                  child: Text('${g.no}\n${L10n.game(g.no).title}',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 11)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _play(GameSpec g) {
    ArcadeAudio.instance.bgm(g.bgm);
    final t = L10n.game(g.no);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) {
      late GameSession s;
      s = GameSession(
        game: g.create(),
        duration: g.duration,
        verb: t.verb,
        hook: t.hook,
        speed: _speed,
        onFinished: (_) => Navigator.of(context).pop(),
      );
      return Scaffold(backgroundColor: Colors.black, body: SafeArea(child: GameView(session: s)));
    }));
  }
}
