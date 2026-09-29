# AD DEMO 151 — Mini-game developer guide

You are building individual mini-games for **ひたすら広告 / AD DEMO 151**: a collection of
151 playable *ad-parody demos*. Each game should feel like the juiciest possible version of a
mobile game ad you'd actually want to play: instantly readable, funny, and full of dopamine
("ドパガキが喜ぶ演出" — screen shake, particles, combo text, coins, confetti, big numbers).

The overall design of every game is in `tool/arcade/lineup.json` (`concept` field). Follow it,
but you are the game designer: improve it when it makes the game more fun.

## Files & rules

* One game = one file: `lib/arcade/games/gNNN.dart` containing `class GNNN extends MiniGame`.
  (Registry already imports it; do NOT edit `lib/arcade/registry.dart`.)
* You may add private helper classes inside your file. Do NOT modify engine files
  (`lib/arcade/engine/*`) — if you think the engine needs something, implement it locally in
  your game file and mention it in your report.
* Import only `import '../engine/engine.dart';` (it re-exports dart:math basics, dart:ui
  types, painting helpers, and the whole engine). Add `dart:math as math` etc. only if needed.
* No image/asset files, no emoji (they may render as tofu). Draw everything with Canvas:
  vector shapes (`D.*` helpers), pixel sprites (`Sprite`, `PixelFont`) or 3D (`Scene3`).
* No Flutter widgets inside games. Everything is drawn in `render(Canvas c)`.
* Keep text inside the game minimal. Numbers and symbols are fine. Every word shown must go
  through `host.tr('key', 'English')` (key = lowercase snake_case, English = fallback). These
  get translated into 20 languages later, so keep them short (1–3 words). Reuse common keys
  when possible: `perfect, great, good, miss, combo, score, level, wave, boss, day, night,
  gold, wood, food, power, hp, attack, magic, defend, item, ready, go, time, lap, round, you,
  cpu, next, buy, upgrade, merge, build, sell, fever, jackpot, bonus, new, lucky, legendary,
  rare, epic, common, clear, strike, goal, out, safe, ko, tap, hold, swipe, drag, bingo, wow,
  nice, oops, danger, win, lose, verify, loading, close, install, free, sale, people, money`.
* Titles / verbs / hooks of each game are handled by the ad frame, not by you.

## The API (see `lib/arcade/engine/game.dart` for docs)

```dart
class G042 extends MiniGame {
  @override void init() {}                 // build level; host is ready (rng, fx...)
  @override void update(double dt) {}      // dt seconds; host.time = elapsed play time
  @override void render(Canvas c) {}       // draw in 360x640 virtual space
  @override void onDown(Offset p) {}       // pointer (virtual coords)
  @override void onMove(Offset p) {}
  @override void onUp(Offset p) {}
  @override void onKey(String key, bool down) {} // 'left','right','up','down','action' (desktop)
  @override void onTimeUp() => host.win(); // default is host.lose(); survival games win
}
```

Host services: `host.win(stars: 1..3)`, `host.lose()`, `host.time`, `host.duration`,
`host.timeLeft`, `host.speed` (difficulty multiplier, 1.0 normal, up to ~1.8 in RUSH mode —
scale enemy speed/spawn rates/reaction windows by it), `host.rng`, `host.fx`,
`host.sfx(Sfx.coin, volume:, rate:)`, `host.shake(px)`, `host.flash(color)`,
`host.hitStop(sec)`, `host.punch(amount)`, `host.addScore(n, at)`, `host.showScore = true`,
`host.setMusicVolume(v)`, `host.tr(key, english)`, `host.pointerDown`, `host.pointer`.
MiniGame helpers: `rand(a,b)`, `randInt(n)`, `pick(list)`, `chance(p)`.

* The timer bar and the "AD" chrome are drawn by the runtime at the top 36px — keep important
  gameplay below y≈40. The intro verb banner and CLEAR/FAIL stamps are also drawn for you.
* After win()/lose() your `update`/`render` keep running ~1.5 s (input stops) — use it for
  ending animations (hero cheers, building collapses...).
* The game MUST end: call win/lose, or let the timer expire (onTimeUp).
* A player who understands the game should win most of the time (~70–85%). Losing should be
  funny. Winning should feel AMAZING (stars: 3 for great play, 1 for barely).
* Show a tutorial hint in the first ~2 s when the control isn't obvious (`D.hand(c, pos, t)`
  draws a bobbing pointing hand; arrows via `D.arrow`).
* Controls must work with mouse and touch. Prefer tap / drag / swipe. Keyboard is a bonus.

## Drawing toolkit

* `D` (draw.dart): `text` (cached, outlined), `title` (big cartoon text), `rrect`, `circle`,
  `line`, `shadow`, `gradientBg`, `rays` (sunburst), `star`, `heart`, `coin`, `gem`, `button`,
  `bar`, `face` (10 expressions), `blob` (mascot), `person` (bean person w/ run anim), `cloud`,
  `tree`, `flame`, `bubble`, `arrow`, `hand`, `hsv`, `fill`, `stroke`. Palette: `Pal.*`.
* `Fx` via `host.fx`: `burst`, `confetti`, `coins`, `ring`, `smoke`, `sparkle`, `pop` (floating
  text). Use them generously.
* Pixel art (pixel.dart): `Sprite(rows, palette)` → `draw`/`drawCentered(scale:)`, supports
  `flipX` and `tint` (hit flash). `PixelFont.draw(c, 'SCORE 100', pos, scale, color)`.
  `Retro.scanlines`, `Retro.vignette`, `Retro.tiles`. Pixel games should commit to the look:
  limited palettes, integer scales (3–5), chunky 8-bit HUD, CRT scanlines.
* 3D (mini3d.dart): `Scene3` with `cam` (`pos`, `lookAt`, `focal`, `center`, `project`,
  `screenToGround`), `Mesh.box/sphere/cylinder/cone/pyramid/plane/grid/torus`, `Mesh.merge`,
  `Models.person/car/pine/roundTree/house`, `scene.add(mesh, pos:, rotX/Y/Z:, scale:, scale3:,
  tint:, flash:)`, `scene.addSprite(p, drawFn)` for billboards, `fogColor/fogNear/fogFar`,
  `light`, `ambient`. Build static meshes once (fields), not every frame, when they are big.
  Painter's-sort only: avoid huge polygons crossing each other; subdivide floors with
  `Mesh.grid`. Keep < ~2500 faces per frame.
* Math: `M.lerp, clamp01, approach (framerate-independent smoothing), easeOutBack,
  easeOutElastic, easeInOut, wave, distToSegment, big (1.2K/3.4M/5.6B)`.
* Sounds: `Sfx.*` constants (see sfx.dart; there are ~100). Use `rate:` to pitch combos up.
  Retro games should use the `p_*` 8-bit sounds.

## Quality bar (important!)

This app was frozen because it was boring. Each game must be **a polished little demo**:

1. **Readable in 1 second.** Big clear shapes, strong silhouettes, contrasting colors.
2. **Juice on every action.** Every tap/hit/score gets a sound + visual feedback (squash &
   stretch, particles, popups, shake). Escalate for combos.
3. **A real mechanic with a skill element**, not just "tap to win". But tuned so it's
   winnable within the duration given in lineup.json.
4. **Distinctive art direction** that matches the `style` field (vector / pixel / threeD /
   neon). Backgrounds should never be flat single colors — gradients, patterns, props,
   parallax, ambient animation.
5. **Humor.** Characters react (faces!), silly fail states, parody of real ad tropes.
6. **Performance:** 60fps on mid phones — avoid allocating big lists every frame, cap
   particles, cache Paths/meshes.

## Testing (required before you report)

```bash
cd /d/user/develop/hitasura_ads
../flutter/bin/dart analyze lib/arcade/games/g042.dart   # must be clean (no errors/warnings)
python tool/arcade/snap.py 42,43        # compiles ONLY the listed games
```

The test runs each game 3 times with a random "monkey" player, fails on exceptions or if the
game never ends, prints outcomes, and writes snapshots to `build/snaps/gNNN_{0,1,2,3,end}.png`.
**Look at the PNGs with the Read tool** and iterate on the art until it looks great.
(The monkey plays randomly, so it usually loses — that's fine. But do sanity-check that your
win path works, e.g. by reasoning through the code or temporarily testing.)

Note: several agents share this machine; flutter test may wait on a lock — be patient. Run
the test for all your games in ONE invocation when possible (e.g. `python tool/arcade/snap.py 41-50`).
