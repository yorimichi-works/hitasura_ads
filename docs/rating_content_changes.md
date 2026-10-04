# October 2026 score-game adjustments

This change keeps all 151 game IDs and the existing input loops. The original source is preserved on `archive/hitasura-pre-rating-nerf-20261004` at `eba58bfede79b50a940aed03eeda96e23ca6b8e6`. That branch contains the original versions of these seven games. There is no review-only flag or hidden original mode in the revised app.

| Game | Preserved interaction | Changed behavior/presentation |
| --- | --- | --- |
| 056 | Track the object under three shuffled cups | Blue target token and spectator guesses; success stars replace cash/bill/betting presentation |
| 102 | Hold/release a timing meter to roll two 3D dice totaling seven | Neutral tabletop without casino chips; target/timing labels and completion score |
| 110 | Start three moving strips; tap their stop buttons | Geometric target circles score 100 per accurate stop; no symbol payout table, 777 jackpot, or random rescue; three rounds |
| 111 | Scratch six areas to reveal three matching target symbols | Scratch-art board and 0–3 match progress replace lottery ticket and fictional money prize |
| 114 | Hold/release meter to stop a wheel | Fixed additive 20/50/100 points; misses add zero; three attempts; no initial bank, multiplier wager, bankruptcy, or car prize |
| 115 | Aim balls into a physics peg board | Ten balls, fixed score pockets, accuracy bonus; no bet-based payout or currency counter |
| 117 | Drop objects onto a moving pusher shelf | Colored discs, 32 attempts, points for objects crossing the edge; no currency or refunded attempts |

Flash, shake, confetti, sound cues, and the established motion/physics remain. Currency-shaped effects in these games become celebratory stars or colored discs. Titles and hooks reflect these actual mechanics in all 20 languages.

The app-wide earned-coin wallet and the 300-coin random game-unlock capsule are unchanged. These are separate from the seven in-game counters. The Loot Boxes declaration must be assessed independently; these changes do not justify removing it. The existing one-time ad-removal IAP is unchanged.

Validation includes the full Flutter suite, the existing all-151-game smoke test, targeted scene captures for the seven revised games, and a behavioral regression for the wheel: equal input timing gives equal score across random seeds; failed attempts never reduce earned score; three attempts end the round. Age-rating classification is reviewed against the actual revised source and rendered scenes before any declaration is changed. This document is not an assertion of Apple approval.
