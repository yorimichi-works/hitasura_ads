import '../engine/engine.dart';

/// No.083 Brick Buster — placeholder until the real game lands.
class G083 extends MiniGame {
  double _t = 0;

  @override
  void update(double dt) => _t += dt;

  @override
  void onDown(Offset p) => host.win();

  @override
  void render(Canvas c) {
    D.gradientBg(c, [Pal.purple, Pal.night]);
    D.title(c, 'No.083', const Offset(180, 280), size: 48, scale: 1 + .05 * sin(_t * 6));
    D.text(c, 'COMING SOON', const Offset(180, 350), size: 20);
  }
}
