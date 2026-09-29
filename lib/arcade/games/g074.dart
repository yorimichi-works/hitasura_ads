import '../engine/engine.dart';

/// No.074 Pop the Wrap! — placeholder until the real game lands.
class G074 extends MiniGame {
  double _t = 0;

  @override
  void update(double dt) => _t += dt;

  @override
  void onDown(Offset p) => host.win();

  @override
  void render(Canvas c) {
    D.gradientBg(c, [Pal.purple, Pal.night]);
    D.title(c, 'No.074', const Offset(180, 280), size: 48, scale: 1 + .05 * sin(_t * 6));
    D.text(c, 'COMING SOON', const Offset(180, 350), size: 20);
  }
}
