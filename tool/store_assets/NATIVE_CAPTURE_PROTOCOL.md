# Native capture session protocol

This is a separate debug-only simulator entry point. The native channel must
attest a simulator; release and physical-device execution are refused. Normal
production widgets, game clocks, physics, randomness and purchase initialization
are used. Captures use the documented local-progress fixture, with audio and
external advertisements disabled. No StoreKit price, transaction, entitlement,
score, win, power-up, or artwork is fabricated.

One process serves exactly one locale/device. The production thumbnail cache is
keyed by game number, so restarting between languages is mandatory. Version 1
single-scene requests remain supported for simple transport proofs.

The host atomically replaces the fixed app-owned
`Documents/HitasuraCapture/request.json` (maximum 4096 bytes). Version 2 has exactly
these keys: `schema_version: 2`, `session_id`, `request_id`, `locale`, `scene`,
`action`, and `created_at`. Both identifiers are lowercase version-4 UUIDs.
`created_at` is UTC, at most five minutes old and at most 30 seconds ahead.

- Initial action is `show`. Subsequent actions are `show`, `record_start`, or `stop`
- The session ID and locale remain fixed; each action has a fresh request ID
- Repeated unchanged file bytes are ignored. Reusing an earlier request ID,
  changing session/locale, recording an unprepared scene, or recording it twice
  fails closed
- Scenes are `home`, `collection`, `pin`, `runner`, `rush`, optional `settings`,
  `liquid` (G003) and `fruit` (G008). Legacy `preview` is only an unreviewed runner
  source mode and is not the new two-game App Preview
- The app session exits its command loop after eight minutes. The host imposes
  the stricter overall work deadline, checkpoints completed files, and terminates
  the simulator process after `stopped` or failure

State updates are atomically written to `state.json` and appended to
`state.json.events.jsonl`. All v2 states contain session/request identity,
`launch_id` equal to session ID, requested scene, locale, action, timestamp, native
simulator attestation, debug/iOS status and capture target. Errors are sticky.

## Native screenshots

`show` navigates the real application. `ready` is emitted after an actual frame,
with `active_scene` and the applied locale. Settings shows the ordinary simulator
purchase state; it must not be described as a verified StoreKit offer or receipt.

## Native gameplay segments

For liquid/fruit, `ready` additionally requires the real GameView session to be in
`play` and reports `game_no`, `game_time`, `time_left` and `phase`. The game keeps
running normally while the host starts simctl recording. No pause or clock reset
is introduced. The host must receive an actual recorder-start acknowledgment
before writing `record_start`. A game with less than 10.5 seconds remaining is
rejected so slow recorder setup cannot silently yield a short clip.

`gameplay_started` includes `started_at`, `game_time`, `duration_seconds: 10`,
`game_no`, `phase`, `active_scene`, `input_method` and `random_seed`. The last two
are `flutter_gesture_binding_pointer_events` and `shipping_time_seed_unmodified`.

Inputs use Flutter's ordinary pointer-event hit testing and the shipping GameView
Listener. Virtual coordinates map through the actual letterboxed render box into
global logical coordinates. They are scripted gestures, not an OS touch recording.
Liquid sort performs real tube selections/pour attempts; fruit merge performs two
slow aim-and-drop gestures. Results, including invalid moves, remain real. The
capture does not force a winning seed or inspect private game state to solve it.

`gameplay_complete` requires ten real seconds entirely in play, at least eight
seconds of game-clock progression, and contains:

- `started_at`, `completed_at`, `elapsed_seconds`
- `game_time_start`, `game_time_end`, `phase`, `game_no`, `active_scene`
- `score_observed`, `input_method`, `random_seed`
- `input_events`, each with `kind`, `pointer`, `virtual_xy`, `global_logical_xy`,
  `scheduled_seconds`, `actual_elapsed_seconds`, and observed `game_time`

An early result or stalled game fails the segment. The host preserves recorder
startup/acknowledgment and app event timestamps, raw recording and input journal.
These do not claim frame-exact synchronization; trim boundaries require recorded
timing reconciliation and pixel review before encoding ten seconds from each game.

The final preview is a plain cut between the two genuine native segments. Existing
`assets/audio/bgm/cute.mp3`, used by both games, may be added as a documented
postproduction music bed. It is not live-captured audio. Geometry, encoding and
human review gates are enforced by the separate encoder; technical success alone
does not imply App Store acceptance.
