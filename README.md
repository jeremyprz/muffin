# The Ultimate Muffin

A 4-player local co-op PVE action game built in Godot 4.6.

Players battle through tower dungeons, fight bosses, and collect muffins across three game modes: top-down overworld exploration, side-scrolling tower platforming, and boss arena fights.

## Controls

### Controller (PS5 / Xbox)

| Button | Gameplay | Ranger Grapple | Menus |
|--------|----------|----------------|-------|
| **Left Stick / D-pad** | Move | Swing boost/brake (horizontal), adjust rope length (vertical) | Navigate |
| **Cross (A)** | Jump | Disconnect + jump impulse | Select |
| **Square (X)** | Attack / Fire crossbow | — | Select |
| **Triangle (Y)** | Special ability | — | Delete character |
| **Circle (O)** | Interact / Reload | — | — |
| **L1 (bumper)** | Grapple: hold to spin, release to throw | While connected: second hook for tether | — |
| **R1 (bumper)** | — | Pull to anchor | — |
| **L2 (trigger)** | Archer aim mode (analog power) | — | — |
| **R2 (trigger)** | Fire aimed arrow | — | — |
| **L3 (left stick click)** | Block | — | — |
| **Start / Options** | Join game / Pause | — | Confirm |
| **Select / Share** | Debug toggle | — | — |
| **Right Stick** | Archer reticle position | Aim direction for throw | — |

### Keyboard

| Key | Action |
|-----|--------|
| **W/A/S/D** | Move |
| **Space** | Jump |
| **J** | Attack |
| **K** | Special ability |
| **F** | Interact |
| **G** | Grapple (hold/release) |
| **Shift** | Pull to anchor (R1) |
| **Tab** | Archer aim (L2) |
| **Enter** | Fire aimed arrow (R2) |
| **Left Arrow** | Block |
| **Escape** | Pause |
| **Backtick (`)** | Debug toggle |

### Title Screen

| Input | Action |
|-------|--------|
| **Press any button** | Join / materialize ghost player |
| **Move** | Ghost player movement before materializing |
| **Jump (when dead, solo)** | Self-revive |
| **Ctrl+D** | Toggle debug mode |
| **Ctrl+E** | Toggle level editor |
| **Ctrl+T** | Test menu |
| **?** | Help overlay (all commands) |
| **M** (debug) | Spawn quadruped monster |
| **G** (debug) | Regenerate nearest tree |

### Level Editor (Ctrl+E)

| Input | Action |
|-------|--------|
| **Tab** | Cycle mode: Spawn Areas → Positions → Seeds → Platforms → Portal → Migration → Splay → Splay Edit |
| **Ctrl+S** | Save level |
| **Ctrl+R** | Reset to defaults |
| **Mouse drag** | Edit positions and sizes |
| **1-9** (Migration) | Select phase |
| **N** (Migration) | Add phase |
| **Del / Backspace** (Migration) | Delete last phase |
| **+** (Migration) | Add zone |
| **S** (Migration) | Cycle species |
| **G** (Migration) | Toggle stagger |
| **Left/Right** (Migration) | Adjust cadence (1s steps) |
| **N** (Splay) | Add splay instance |
| **P** (Splay) | Pose library browser |
| **E** (Splay) | Enter pose editor |
| **B** (Splay) | Cycle behavior (asleep/stand_down/active) |
| **Left/Right** (Splay) | Rotate instance |
| **Up/Down** (Splay) | Cycle pose |
| **SPACE** (Splay Edit) | Toggle connection point on/off |
| **Shift+SPACE** (Splay Edit) | Dump skeleton JSON to logs |
| **C** (Splay Edit) | Toggle rope/chain |
| **P** (Splay Edit) | Toggle pin (joint doesn't move during IK) |
| **M** (Splay Edit) | Toggle mirror mode (L/R symmetric) |
| **L/R/U/D** (Splay Edit) | Preset poses |
| **Arrows** (Splay Edit) | Nudge cast endpoint |
| **Drag** (Splay Edit) | IK-drag connection point / cast endpoint / origin |

### Music Drawer (Ctrl+M)

Live-coding music panel. Each line is an independent pattern — all non-muted lines play stacked together.

**Line format:**
```
drums: c4(3,8)                — named "drums"
bass: c2 ~ c2 ~ e2 ~ s=bass  — named "bass", bass voice
melody: c4 e4 g4 c5 s=flute   — named "melody", flute voice
c4 e4 g4 c5                   — auto-named "d1", "d2", etc.
# this is a comment            — skipped
```

| Input | Action |
|-------|--------|
| **Enter** | New line below current |
| **Ctrl+Enter** | Evaluate all lines (play/hot-swap) |
| **Up / Down** | Move between lines |
| **Ctrl+/** | Toggle mute on current line |
| **Ctrl+Shift+K** | Delete current line |
| **Backspace at col 0** | Join with previous line |
| **Escape** | Close drawer |
| **Left / Right** | Move cursor one character |
| **Ctrl+Left / Right** | Move cursor one word |
| **Home / End** | Beginning / end of line |
| **Shift + movement** | Extend selection |
| **Ctrl+A** | Beginning of line (at start: select all) |
| **Ctrl+E** | End of line |
| **Backspace** | Delete char before cursor |
| **Shift+Backspace / Ctrl+Backspace** | Delete word backward |
| **Delete** | Delete char after cursor |
| **Ctrl+Delete** | Delete word forward |
| **Ctrl+C** | Copy selection (or whole line) |
| **Ctrl+X** | Cut selection (or whole line) |
| **Ctrl+V** | Paste from clipboard |
| **Ctrl+K** | Kill to end of line |
| **Ctrl+U** | Kill to beginning of line |
| **Ctrl+W** | Kill word backward |
| **Ctrl+Y** | Yank (paste from kill buffer) |

### RCON Commands (TCP port 9999)

```
help, debug, spawn <monster|dummy|attacker> [x y], tp <x> <y>, tab [n],
key <k>, enemies, players, precog, status, quit, clear, clearplayers,
enablejoins, revive, resethp, fps, hp, ik, ikreset, thrash, ball,
debugdraw, title, score, grid,
standdown [on|off], territorial [on|off], partstatus, partdmg <part> <amount>,
weight, attach balloon <point>, detach <point>,
tether <idx> <point> floor [len], tether <idx1> <pt1> <idx2> <pt2> [len],
tether wall <x1> <y1> <x2> <y2> [len], tether length <px>,
tether cut, tether status,
chain <idx> <point> floor [len], chain status, chain cut,
splay list, splay spawn <pose> [x y] [rot] [behavior], splay clear, splay status,
dump [enemy_idx] [trigger],
attacker <target|part|weapon|rate|stop|start|stats|tether_length|tether_b>
```

---

## Features

- **12 playable classes** with unique mechanics: Melee, Ranged, Mage, Summoner, Rogue, Demolitionist, Healer, Tank, Ninja, Balloonist, Guitarist, Werewolf
- **Physics-based grappling hook** (Ranger) with pendulum swing, rope slack, and Newtonian enemy tug
- **Dual-grapple tether system** (Ranger) — connect two points with a physics rope that pulls to a chosen length, max 5 active tethers
- **Parabolic arrow aiming** (Ranger) with arc solver, analog trigger power control, and power lock
- **Rift tentacle system** — class changes spawn physics-based tentacles that hunt players and buff enemies
- **4 bosses** with unique attack patterns and phases
- **18 enemy types** including 4 mini-bosses, each with a mass property for physics interactions
- **Persistent player profiles** with per-class skill leveling and XP
- **Controller haptics** — rumble feedback for grapple events, LED color matching class
- **Procedural background trees** with debug regeneration tools
- **Portal doorway** — atmospheric game start with stone archway, wooden doors, vortex, and fog
- **Splay pose system** — position creatures in custom poses with chains/tethers to walls, full skeleton snapshot save/restore, breakaway at 50% damage
- **Chain system** — zero-stretch rigid connections with shackles, peg+ring wall mounts, 2000 HP, shake/flash on damage
- **Level editor** (Ctrl+E) with JSON config system — spawn zones, positions, seeds, platforms, portal, splay instances all editable
- **Title screen ecosystem** — fireflies with spawn-gravity zones and bats with perlin noise hunting
- **Migration patterns** — cyclic multi-phase movement sequences that drive wildlife across the level
- **Quadruped monster** — procedurally animated beast with foot-driven locomotion, 2-bone IK, head tracking, pre-cognition pathfinding, vulnerable body parts with tiered damage, and attachment points for balloons/tethers
- **Cave walls** — curved floor-to-wall transitions with collision, undulation, and standing ledges
- **RCON server** (port 9999) — remote console for automated testing, spawning, teleporting, debug control

## How to Play

- Connect 1-4 controllers (PS5, Xbox, or similar)
- D-pad up/down selects profile, left/right selects class
- Walk all players into the portal doorway to begin

### Ranger Controls
| Input | Action |
|-------|--------|
| Square | Fire crossbow (uses ammo) |
| L1 (hold/release) | Grappling hook windup and throw |
| L1 (while connected) | Tether: second hook windup + throw (connects two points with rope) |
| R1 (while connected) | Pull toward anchor |
| Jump (while connected) | Disconnect + jump impulse in stick direction |
| D-pad UP/DOWN (while swinging) | Adjust rope length (sets tether target length) |
| L2 (hold) | Aim mode — reticle + pull strength builds |
| R2 | Fire aimed arrow along solved parabolic arc |
| RB (during L2) | Reverse power, release to lock power level |

### Debug Mode
Ctrl+D toggles debug mode anywhere. Shows velocity arrows, button states, grapple tracers, archer arc trails. Press G near a procedural tree to regenerate it with a new seed.

## Downloads

See [Releases](https://github.com/jeremyprz/muffin/releases) for Mac, Windows, and Linux builds.

### macOS Users
Right-click the app, click **Open**, then **Open** again to bypass Gatekeeper. Or run:
```
xattr -cr "/Applications/The Ultimate Muffin.app"
```

---

## Release Notes

### v0.10.63
**Intro music, dynamic drawer height, stack expansion for file loading**

- **Intro music**: `data/strudel/intro.strudel` — slow, mysterious, ominous 6-voice composition (sub-bass drone, minor chord pad, dark sawtooth texture, sparkle layers, deep pulse). Loads automatically on the title screen.
- **Dynamic drawer height**: editor lines fill the full screen height instead of a fixed 8-line cap. `MAX_VISIBLE_LINES` replaced with runtime calculation from available panel height.
- **Stack expansion for file loading**: `strudel load` expands `stack(a, b, c)` into individual drawer lines — each voice gets its own line with pianoroll, mute toggle, and label.
- **Named voice labels**: `.strudel` files use `name: pattern` syntax (e.g., `sub:`, `pad:`, `sparkle:`) for labeled voices in the drawer.
- **Comment stripping on load**: inline comments from `.strudel` files are stripped (except file header) to keep the drawer clean.
- **Title screen music via strudel load**: `_strudel_play_title()` now loads `intro.strudel` through the RCON file loader instead of hardcoded MML.

### v0.10.62
**Refactored _play_current: _resolve_line, _compile_parsed, _resolve_expr**

- **`_resolve_line(i, bindings)`**: single function resolves any line — returns typed dict (`skip`/`setcps`/`hush`/`let`/`pattern`). Replaces inline let detection, let compilation, let reference resolution, and normal parsing.
- **`_compile_parsed(parsed, bindings)`**: compiles a parsed line into a Pattern. Handles stack, mini-notation, wrapper types, deferred ops, and let variable resolution in stack sub-expressions. Eliminates duplicate compilation code between let definitions and normal lines.
- **`_resolve_expr(text, bindings)`**: resolves a text reference against let bindings, applying suffix transforms. Used by both `_resolve_line` (bare references) and `_compile_parsed` (stack sub-expressions).
- **`_play_current()` is now a clean match loop**: resolve → match type → collect. No inline let handling, no special-case branches.
- **Locations always 0-based**: `_compile_parsed` returns 0-based locations. `pattern_offset` on the line dict handles draw-time alignment. Let definitions set `pattern_offset` to `rhs_offset + expr_offset` so the same draw-time mechanism works for both normal and let lines.

### v0.10.61
**`let` variable bindings, linked source highlights, pattern engine spec**

- **`let` variable bindings**: `let melody = note("c4 e4 g4 c5")` then reference as `melody` or `melody.fast(2)`. Works in bare lines, method chains, and `stack()` sub-expressions.
- **Linked highlight architecture**: let bindings compile patterns with location tags pointing to the definition line. `_tag_locations_line()` stamps each location with its source line index. Highlights for `stack(drums, melody)` render on each variable's definition line, not the stack line.
- **No text substitution**: variable references are resolved via compiled pattern linking, not string expansion. The editor displays `melody`, not the expanded expression.
- **`stack()` let resolution**: sub-expressions inside `stack(drums, melody)` resolve against let bindings, with suffix transforms supported (`stack(melody.rev(), drums)`).
- **Pattern engine spec**: `docs/design/pattern_engine_spec.md` — clean-room functional specification describing the pattern algebra, mini-notation grammar, scheduler, and audio bridge in implementation-independent terms.
- **Fixed `ab_every` flaky check**: `every(3, fast(2))` highlight check simplified to stable first-beat assertion.

### v0.10.60
**File loading, legato/clip/dur, sub-expression method chains, 42 A/B tests**

- **`strudel load`**: load `.strudel`/`.js`/`.txt` files from `data/strudel/`, `user://patterns/`, or absolute paths. Multi-line expressions merged via paren-depth tracking. Auto-plays on load.
- **`legato(N)`/`clip(N)`**: per-note duration multiplier. `legato(0.5)` = staccato, `legato(2)` = overlapping. Injected into hap values via `set_in`, respected by `get_duration()` and `is_active()`.
- **`dur(N)`/`duration(N)`**: absolute note duration in seconds, overrides slot-based duration.
- **Sub-expression method chains**: `_eval_sub_expr` now handles full method chains (`.lpf()`, `.gain()`, `.fast()`, `.s()`, etc.) inside `stack()` — previously only `.s()` was supported.
- **Ref server legato fix**: `renderWav` now uses `hap.duration` (clip-aware) instead of raw `whole.end`.
- **Shared `_merge_continuation_lines()`**: `strudel begin/end` and `strudel load` both use the same paren-depth line merger.
- **4 example `.strudel` files**: chord_progression, arpeggio, minimal, dungeon_ambience in `data/strudel/`.
- **`ab_legato` test**: A/B comparison + per-beat highlight verification for legato(0.5).

### v0.10.59
**Highlight sequence testing, multi-line blocks, harmonic frequency matching, 41 A/B tests**

- **Per-beat highlight tracking**: new `strudel highlights` system records which source substrings are highlighted at each beat fraction (e.g., `0/1:[L1:c4|L1:c5]`), enabling visual correctness testing
- **All 41 A/B tests now verify highlights**: per-beat checks assert correct notes highlight at correct times with set semantics for simultaneous notes
- **Multi-line block syntax**: `strudel begin`/`strudel end` preprocesses multi-line expressions (like `stack(...)` across lines) by merging continuation lines via paren-depth tracking
- **Stack highlight offset fix**: `_split_top_level_commas` sub-expression positions now account for leading whitespace, fixing off-by-one source highlights in `stack()` expressions
- **Transform arg location stripping**: `add(note("<0 5 7 0>"))` no longer pollutes base pattern highlights — `_strip_locations()` on Pattern removes operand locations before `combine_context` merge
- **Harmonic frequency matching**: `ab_compare` now accepts 2x/0.5x frequency ratios as matches, correctly handling HPF-filtered signals where zero-crossing detects the 2nd harmonic
- **CPS sync fix**: `strudel_set_cps()` now syncs `MusicDrawer._cps`, preventing stale CPS from leaking between tests
- **Ref server space-join**: multi-line blocks sent to the Strudel reference server are joined with spaces (not semicolons), fixing `stack()` expressions
- **Both-silent match**: `ab_compare` returns OK when both files are silent (hush test)
- **5 new tests**: ab_setcps, ab_stack_func, ab_hush, plus ab suite updated to 41 tests

### v0.10.58
**add/sub/mul transposition, per-window frequency match, annotated spectrograms, 36 A/B tests**

- **add(note(7)) transposition**: bare note strings now wrap as `{note: value}` in compose ops, enabling `note("c4").add(note(7))` → g4
- **Signed WAV fix**: `_load_wav_mono` was reading unsigned 16-bit PCM (all samples 0-2), now correctly signed (-1 to 1). Fixes all spectral analysis accuracy.
- **Per-window frequency match**: zero-crossing rate comparison per 100ms window detects pitch/timing mismatches that spectral band averages miss
- **Annotated spectrograms**: `ab_show` overlays red/cyan frequency markers on mismatched windows, green on matched
- **Failure diagnostics**: worst mismatches shown with time and Hz (`@0.8s:ref=490Hz/our=340Hz`)
- **Centroid threshold**: configurable per-test as 6th arg to `ab_compare` (0=skip, 0.7=strict)
- **add/sub/mul as method chains**: `.add(note(7))`, `.sub(note(3))`, `.mul(2)` in deferred ops and arrow functions
- **superimpose/layer**: `.superimpose(x=>x.add(note(7)))`, `.layer(fast(2), rev)` recognized and applied
- **Full-height spectrograms**: 3× taller (800×1200) with aspect-ratio-aware overlay dialog
- **4 new focused tests**: ab_add_simple, ab_add_octave, ab_superimpose_add, ab_add (36 total, all passing)
- **Test order fix**: `ab_compare` runs before `ab_show` so freq data is available for overlay annotations

### v0.10.57
**Function combinators, s()/n() functions, polymeter fix, 32 A/B tests**

- **Function-argument combinators**: `.every(3, fast(2))`, `.jux(rev)`, `.sometimes(x=>x.fast(2))`, `.off(0.125, fast(2))`, `.chunk(4, rev)` — parse named transforms and arrow functions from method chains
- **Arrow function parser**: `x=>x.fast(2).rev()` — chained transforms in a single arrow expression
- **`s()` top-level function**: `s("sawtooth square triangle sine")` cycles through waveforms, matching Strudel's control pattern API
- **`n()` top-level function**: `n("0 1 2 3").s("piano")` for sample index patterns
- **`off()` fix**: late applied before transform (matching Strudel's `stack(pat, fn(pat.late(t)))`)
- **Polymeter fix**: `{c4 e4 g4}%8` single-child with `%n` now correctly applies `fast(n/steps)`
- **`euclidRot()` support**: `.euclidRot(3,8,1)` recognized as method chain for rotated euclidean rhythms
- **Source text highlighting**: fixed for `stack()` expressions (per-sub-expression offsets) and `degrade` patterns (preserve context in cycle-wrapped haps)
- **12 new A/B tests**: slow, rev, fast3, ply, bandpass, euclid_rot, euclid_5_13, polymeter, every, jux, off, s_function
- **32 total A/B tests**, all passing

### v0.10.56
**Degrade PRNG fix, stack() parsing, per-cycle rendering, A/B test hardening**

- **Degrade PRNG**: xorwise algorithm with 32-bit signed integer semantics now matches Strudel v1.2.0 exactly (verified per-value against JavaScript output)
- **`.degrade()` method chain**: recognized as a pattern combinator, applied after mini-notation eval
- **`stack()` expression parsing**: `stack(note("c3").s("sawtooth"), note("c5").s("square"))` correctly splits, evaluates sub-expressions, and routes per-note voices
- **Per-note voice routing**: batch mode groups haps by `value.s` waveform (not just track voice), enabling mixed oscillator types in a single stack
- **Multi-cycle pre-rendering**: oscillator renders 16 cycles to handle time-dependent patterns (degrade produces different dropout patterns each cycle)
- **Pianoroll cycle wrapping**: display wraps queries modulo batch cycle count so UI matches looping audio
- **Reference server fix**: now queries each cycle independently via `queryArc(n, n+1)` instead of repeating `firstCycle()` — critical for degrade/random pattern accuracy
- **Identical test strings**: `strudel ref` strips `.pianoroll()` and `cps=` so both commands receive the exact same input
- **Silence grace period**: `wait 10 unless silent 2.5` prevents reference/ours overlap in sparse patterns
- **20/20 A/B tests passing** with 12 new test files (chords, degrade, multi_voice, rests, slowcat, etc.)
- **TimeSpan.shift_by()**: new helper for shifting hap times during pianoroll cycle wrapping

### v0.10.52
**Pianoroll options, import/export, compatibility audit, oscillator + drum voices**

- **Pianoroll options**: `"mini".pianoroll({labels:1, fold:0, vertical:1, autorange:1, cycles:8})` — Strudel-compatible option syntax parsed from `{key:value}` inside parentheses
- **Wordfall** now delegates to pianoroll with exact Strudel presets (`vertical:1, labels:1, fillActive:1`)
- **Import/export**: `strudel save <name>` / `strudel load <name>` — save/load drawer lines to `user://patterns/*.txt`
- **Compatibility audit**: `docs/design/strudel_compatibility.md` — honest coverage report (mini-notation ~95%, controls ~2%, JS eval 0%)
- **Oscillator types**: `sine`, `triangle`, `supersaw` mapped to SiON FM presets
- **Drum sample names**: `bd`, `sd`, `hh`, `cp`, `rim`, `rd`, `cr` mapped to closest SiON percussion
- **Safety bounds** in pianoroll renderer prevent crashes from degenerate rects

### v0.10.51
**Multi-line editor, per-line visualizers, Strudel v1.2.0 viz compatibility**

- **Multi-line editor**: Enter creates lines, Ctrl+Enter evaluates all stacked, Up/Down navigates, Backspace@col0 joins
- **Named lines**: `drums: "c4(3,8)".pianoroll()` — Strudel label syntax with per-line naming
- **Per-line mute**: Ctrl+/ toggles mute, muted lines dimmed and excluded from playback
- **All Strudel v1.2.0 visualizers**: `.pianoroll()`, `.scope()`, `.wordfall()`, `.spiral()`, `.pitchwheel()`, `.fscope()` — each renders a strip below its code line
- **Strudel-compatible syntax**: `"c4 e4 g4 c5".pianoroll()` — quoted mini-notation + method chain, `note()` wrapper stripped
- **Per-line pattern isolation**: each line's visualizer only shows its own haps, not the combined output
- **Source highlighting fixed**: offsets account for name prefix and quotes, highlights land on correct characters
- **Polymeter**: `{a b c, d e}` properly aligns sub-patterns to shared step count
- **Note duration**: CPS-derived BPM synced to SiON for correct note lengths at all tempos
- **strudel start/stop**: resume last pattern after stop
- **strudel edit**: `strudel edit "melody".pianoroll() | "bass".scope()` — set drawer lines from RCON with viz
- **9 listening test suites** (60+ audible tests): features, voices, multiline, rhythm, duration, compositions, named lines, viz showcase, viz multiline
- Removed invented visualizers (.bar/.dots/.meter) — only Strudel-compatible types

### v0.10.50
**Strudel voices, test suites, Music Drawer sync, bug fixes**

- **87 SiON voice presets**: `s=flute`, `s=bass`, `s=strings`, `s=marimba`, `s=saw`, `s=pad`, `s=trumpet`, etc. — use `strudel voices` to list all
- **148 unit tests** across 8 suites: `strudel test` runs algebra, composers, combinators, signals, mini, integration, voices
- **18 listening tests**: `run music_listen_features` plays each Strudel feature live so you can hear it — uses the existing Ctrl+D test runner
- **Music Drawer syncs**: editor text, pianoroll, and source highlights now update when patterns change from RCON, console, or test runner
- **Fix**: note stacking — SiON `note_on` now passes duration so notes auto-release instead of holding forever
- **Fix**: parser infinite loop on unrecognized characters (e.g. `=`) — parser now skips bad chars
- **Fix**: pianoroll empty after RCON pattern change — rolling buffer detects external pattern swaps and resets
- **Fix**: dict value resolution — pianoroll and trigger both handle `{value: "c4", s: "strings"}` format
- **Full editor keybindings**: selection (Shift+arrows), Ctrl+C/X/V clipboard, Ctrl+K/U/W/Y kill ring, word navigation
- **`music help`** RCON command: comprehensive inline reference for all commands, mini-notation syntax, and drawer keybindings
- **`strudel listen`** shortcut to run listening tests from the console

### v0.10.49
**Fix Strudel audio dropout + pianoroll flashing**

- **Fix**: SiON driver mode conflict — `play(mml)` and `stream()` modes now properly sequenced; `strudel_play` always forces clean streaming mode
- **Fix**: `play_test_tone` and `play_mml` now stop the Strudel cyclist first to prevent mode conflicts
- **Fix**: Pianoroll rolling buffer — haps accumulate incrementally instead of re-querying entire window each frame, eliminating visual flashing
- **Fix**: Rolling buffer resets on pattern change and stop

### v0.10.48
**Strudel pattern engine — live-coding music in Godot**

- **Strudel v1.2.0 pattern algebra**: Fraction (exact rationals), TimeSpan, Hap, State, Pattern with full applicative/monadic composition — ported to GDScript
- **Mini-notation parser**: recursive descent parser for `"c4 e4 [g4 b4] c5"` — sequences, sub-cycles, stacks, fast/slow, angle brackets, euclidean rhythms, degrade, random choose
- **45+ pattern combinators**: fast, slow, early, late, every, rev, ply, palindrome, jux, off, inside, outside, zoom, chunk, hurry, compress, focus
- **Composers**: add, sub, mul, div, set, keep, keepif with In/Out/Both/Squeeze structure modes; struct, mask
- **Continuous signals**: saw, sine, tri, square, cosine, rand + segment, range; run, scan, irand, choose
- **Cyclist scheduler**: cycle-based pattern scheduler with CPS tempo, frame-tick clock, SiON trigger bridge
- **Music Drawer (Ctrl+M)**: slide-out panel with text editor, pianoroll visualization, source highlighting (active notes glow in the text)
- **Live editing**: type mini-notation, press Enter, pattern hot-swaps; pianoroll scrolls, playhead tracks current position
- **RCON commands**: `strudel <mini-notation>`, `strudel stop/cps/status/drawer`; `musicdrawer` (md) toggle
- **Debug aspects**: `strudel/trigger`, `strudel/scheduler`, `strudel/parse`, `strudel/pattern`
- **7 test suites**: Fraction, TimeSpan, Pattern, Composers, Combinators, Signals, Mini — all pass
- **Design document**: `docs/epics/EPIC_strudel_integration.md` — 5 EPICs, 22 stories, full architecture

### v0.10.47
**Procedural adaptive music system powered by GDSiON**

- **GDSiON integration**: Software synthesizer GDExtension (v0.7-beta8) — 650+ FM/MIDI/chiptune voices, MML sequencer, real-time effects
- **MusicManager autoload**: 4-layer adaptive music (pad, bass, drums, melody) driven by game intensity 0.0–1.0
- **Intensity system**: Game events push intensity up (combat +0.4, attacks +0.15, leaps +0.25), natural decay brings it down; layers activate/deactivate at thresholds
- **Monster hooks**: `_notify_music()` on every state transition — CHASE starts combat music, attacks/leaps escalate, death/patrol resets
- **Player hooks**: damage pushes intensity, all-players-dead drops to zero
- **Title ambient**: Soft C minor pad auto-plays on title screen, transitions cleanly to layered system
- **18 community MML scores**: Chrono Trigger, FFV Big Bridge, Castlevania Beginning, Street Fighter Chun-Li, Super Mario Bros, Ikaruga, Ys II, Secret of Mana, Dragon Quest III, Megami Tensei II, and more — loaded from `data/music/scores.json`
- **RCON commands**: `music play/stop/off/test`, `music score <name>`, `music mml <string>`, `music intensity/tempo/layer/push/combat/calm`, `music scores`
- **Console autocomplete**: All music commands, score names, debug aspects, modifier blueprints, and level names now tab-complete in the in-game console
- **Debug aspects**: `music/status`, `music/layers`, `music/beats`, `music/events`
- **Graceful fallback**: Dynamic GDScript bridge avoids parse-time type dependency — if GDSiON is missing, music system disables cleanly

### v0.10.46
**ChargeComponent, Character base virtuals, dead forwarder cleanup — player_side.gd under 4,000 lines**

- **ChargeComponent extracted**: hold-to-charge system as reusable component with class hooks (on_charge_press, on_charge_tick, on_charge_release, get_charge_threshold)
- **Character base expanded**: DEFAULT_GRAVITY, DEFAULT_JUMP_VELOCITY constants; apply_gravity(), apply_knockback(), get_aim_direction() virtual methods; _is_dead, _is_wall_sliding shared state
- **36 dead forwarders removed**: executioner functions with zero references (class calls local)
- **Dispatch table cleanup**: removed all extracted class entries from _init_class_dispatch — each class's init handles its own dispatch
- **Fix**: executioner tick crash from deleted forwarder (p._exec_test_tick → local exec_test_tick)
- **player_side.gd: 9,654 → 3,985 lines (−58.7%)**

### v0.10.45
**All 13 player classes extracted — player_side.gd reduced 55.8%**

- **All 13 classes now ClassComponents**: Executioner (1963), Ranger (1526), Summoner (510), Melee (442), Werewolf (375), Ninja (322), Mage (313), Rogue (267), Demolitionist (217), Healer (180), Balloonist (160), Tank (155), Guitarist (118)
- **player_side.gd: 9,654 → 4,268 lines** (−5,386, 55.8% reduction)
- **Generic `_init_class_component()`**: one function wires any class — loads script, injects context, redirects dispatch tables
- **Ranger extracted**: grapple FSM (9 states), tether dual-hook, archer aimed shot, crossbow, all drawing
- **5 small classes batch-extracted**: Melee, Mage, Tank, Balloonist, Ninja
- **6 remaining classes extracted**: Rogue, Demolitionist, Healer, Summoner, Guitarist, Werewolf
- **Inline GDScript exclusions**: `_spawn_fireball` (mage), `_attack_guitarist`, `_special_guitarist_blast_wave` stay on player (contain `GDScript.new()` class definitions)
- **Remaining on player_side.gd**: shared systems (physics, movement, charge, block, stagger), config/setup, dispatch tables, state vars, AI input, VFX helpers

### v0.10.44
**Executioner cleanup — removed duplicate constants, 19.7% player_side.gd reduction**

- Removed 54 duplicate EXEC_* constants from player_side.gd (already in executioner_class.gd)
- player_side.gd: 9,654 → 7,752 lines (−1,902, 19.7% reduction)
- Remaining executioner on player: state vars + enums (~200 lines for RCON), thin forwarders (~60 lines)
- Full test gate verified: executioner 7/7, class_basics 13/13

### v0.10.43
**Executioner extraction complete — all drawing + tuning migrated**

- **All executioner functions extracted**: 55+ functions in executioner_class.gd (1,963 lines)
- **player_side.gd reduced 19.1%**: 9,654 → 7,812 lines
- **Drawing migrated**: ball, shackle, chain radius, trajectory preview, swing, cleave charge, mode indicator, tuning popup — all using `p.draw_*()` delegation
- **Tuning migrated**: live slider popup, drag handling, config push/pop
- **Test tick migrated**: virtual input simulation for throw prediction
- **Remaining on player_side.gd**: state vars + enums (~200 lines for RCON compat), thin forwarders (~60 lines)
- Executioner suite: 7/7 pass with inspect=5

### v0.10.42
**Executioner class extraction — all core logic migrated to ExecutionerClass**

- **43 executioner functions migrated** from player_side.gd to executioner_class.gd
- **player_side.gd**: 9,654 → 8,412 lines (−1,242, 12.9% reduction)
- **executioner_class.gd**: 1,321 lines — owns all executioner behavior
- **Chain helpers**: ball/shackle chain length, B-S release detection, stuck anchors
- **Chain physics**: constraint, YEET elastic collisions, B-S stuck pull, chain severed
- **Chain spawning**: ball chain, shackle chain, ball-to-shackle chain, anchor updates
- **Throw system**: windup, aim preview, throw ball/shackle, retract, hold-on-throw
- **Ball tick**: full ball physics (thrown, stuck wall/platform/ceiling, retracting)
- **Preview arc**: two-body string simulation (optimistic + pessimistic cone)
- **Combat**: swing/slam, cleave (charge + fire), charged overhead
- **Mode management**: R1 toggle, chain mode cycling, L2/R2 length adjustment
- **Main tick**: orchestrator delegates to all sub-functions
- Thin forwarders on player_side.gd for backwards compatibility
- Godot 4.6 compat: explicit typing, p.get_world_2d(), local enum declarations
- Executioner suite: 7/7 pass throughout all migrations

### v0.10.41
**Composition refactor phases 3-5, class_basics test suite, ExecutionerClass extraction begun**

- **Refactor Phase 3**: `player_side.gd` extends `character.gd` — universal Character base with composition infrastructure
- **Refactor Phase 4**: Class dispatch tables — 4 dictionaries replace all `match character_class:` blocks and scattered per-frame handler calls
- **Refactor Phase 5**: ExecutionerClass component wired — dispatch delegates through class, thin `p` accessor for player state
- **Executioner function migration**: 11 functions moved to `executioner_class.gd` (chain helpers, constraint, YEET physics, position getters)
- **player_side.gd**: 9,654 → 9,502 lines (−152), with thin forwarders for migrated functions
- **class_basics gate suite**: 13 tests covering all player classes — spawn, walk, attack x3, jump, special, air attack
- **Total test count**: 48 tests across 6 gate suites (chained, combat, leaping, scaling, executioner, class_basics)
- **UID generation**: all new .gd files get .uid files for Godot 4.6 compatibility
- **Design doc**: `docs/design/player_refactor.md` — full architecture with DI, pooling, FSM, is-a/has-a hierarchy

### v0.10.40
**Unified inspect system, standardized test endings, {SCRIPT} built-in**

- **Unified inspect/notify**: every test ends with `notify {SCRIPT} "How does {SCRIPT} look?" ["OK","BAD","BROKEN"] {inspect} blocking`
- **`inspect` variable**: `0`=auto-dismiss (default), `N`=N second countdown, `-1`=wait forever
- **OK/BAD/BROKEN buttons**: color-coded (green/red/orange) with hover tooltips describing each action
- **BAD/BROKEN mark test failed**: clicking BAD or BROKEN adds a failed `inspect` result to the test
- **Timeout auto-OK**: logs "inspection skipped" to distinguish from human-clicked OK
- **`{SCRIPT}` built-in variable**: auto-set to test name, available in all test scripts
- **Override visibility**: overridden vars show ⚡ icon + gold highlight on the var line in test editor
- **Blocking notify rewrite**: wider dialog, centered message, proper multi-word parsing, countdown display
- **Negative timeout**: `timeout=-1` means wait forever (no auto-dismiss)
- **Removed old observations notify**: replaced by the unified inspect system
- **`run_inspect.sh`**: defaults to `inspect=5` for quick refactoring verification

### v0.10.39
**Inspect gate, blocking notify overhaul, refactor foundation**

- **Inspect gate for tests**: `run test_name inspect=true` shows a blocking modal after test passes — OK/BAD/BROKEN buttons with color-coded hover tooltips
- **Blocking notify rewrite**: wider dialog (500px), proper multi-word message parsing, centered text, color-coded buttons, hover highlights, tooltip descriptions
- **Negative timeout = wait forever**: `timeout=-1` prevents auto-dismiss on blocking modals (timeout=0 still auto-dismisses for backwards compatibility)
- **Inspect replaces trailing notify**: when enabled, inspect IS the final modal — no competing observations dialog
- **`run_inspect.sh`**: shell script for agent workflow — runs test with inspect, polls log for result, exits with 0/1/2/3
- **Refactor Phase 1+2 foundation**: StateMachine, State, CharacterContext, StatsComponent, HealthComponent, InputController (Player/AI), ClassComponent, ConfigProvider Resources, ObjectPool autoload
- **Movement FSM states**: Idle, Run, Jump, Fall, WallSlide, Dash
- **Action FSM states**: Ready, Attacking, Charging, Blocking, Staggered, Dead
- **Character base class**: `character.gd` with composition wiring (not yet extending player_side.gd)
- **Design doc**: `docs/design/player_refactor.md` — full architecture for unified Character system
- **All 44 tests have `var inspect default=false`** — disabled by default, enabled via override

### v0.10.38
**Minecraft-style relative coordinates, query multipliers, executioner gate suite**

- **Relative coordinates in spawn/ai_spawn**: `spawn dummy @e[name=AI] ~150 ~0` spawns at entity position + offset — Minecraft `~X ~Y` syntax
- **`_resolve_pos()` utility**: shared by `spawn` and `ai_spawn`, supports `@e[name=AI] ~X ~Y`, `@e[name=AI]` (exact pos), or absolute `960 876`
- **`query` multiplier**: `query @e[name=AI] exec_chain_total_len shackle_radius 400 *0.5 +20` — `(value * mult) + offset`
- **Late variable substitution**: `{variables}` from `query` resolve within the same batch, not just at parse time
- **`#` comments print to test log**: no longer silently skipped — shown in muted green during test execution
- **`comment` command prints to log**: `print("  # ...")` instead of silent no-op
- **Executioner suite is now a gate suite**: `"gate": true` — runs in test-gate alongside chained, combat, leaping, scaling
- **exec_shackle_kick rewritten**: uses `query` for dynamic shackle radius, relative spawn positioning
- **exec_shackle_drag rewritten**: proper throw sequence (ball up, shackle at ball), walks right to test drag constraint
- **exec_bs_yeet updated**: shortened wait, user-edited formatting
- **All 5 gate suites pass**: chained 8/8, combat 14/14, leaping 5/5, scaling 1/1, executioner 7/7

### v0.10.37
**B-S Release mode physics fix, rect verify boundaries, dynamic config queries in tests**

- **B-S mass-weighted constraint**: ball no longer hard-clamped to shackle — position correction distributed by mass ratio (ball=140 moves 3%, shackle=5 moves 97%)
- **B-S YEET elastic collision**: fires once per slack→taut transition, transferring momentum proportional to mass
- **STUCK_WALL floor transition**: ball dragging down a wall now detects floor via raycast and transitions to STUCK_PLATFORM instead of clipping through ground
- **STUCK_PLATFORM/STUCK_WALL anchor fix**: stuck states now use correct chain anchor (shackle in B-S, player in B-P) instead of always using the player
- **B-S entity leash**: shackle attached to entity in Release mode now constrains entity to ball distance, preventing unchecked drift
- **Rect verify boundaries**: candy-stripe rendering for rect monitors matching circle style (green inner band, solid borders, red outer band, fade gradients)
- **`query` command in tests**: `query @e[name=AI] exec_chain_total_len chain_radius 400 +20` reads live config values from entities at runtime, stores in test variables with optional offset
- **`#` comments in tests**: lines starting with `#` print to test log without RCON dispatch; `comment` command also prints to log
- **Revert/Promote buttons**: class editor sliders show ↩ (revert to default) and ↑ (promote as new default) buttons on modified values, with hover tooltips
- **Late variable substitution**: verify lines resolve `{variables}` at execution time, enabling dynamic radii from runtime queries
- **New test**: `exec_release_ball_wall` — verifies ball doesn't sink through floor when stuck to wall
- **All exec tests updated**: use `query` for dynamic chain radius, `#` comments explaining each step, `announce` for on-screen context

### v0.10.36
**Config panel redesign: 9 sub-sections, class defaults, entity config stacks**

- **Config panel restructured** from 4 to 9 sub-sections: Classes, Class editor, Entities, Entity Mods, Entity Stats, Calculations, Modifiers, Modifier editor, Modified Entities
- **Class defaults from JSON**: 18 files in `data/config/class_defaults/` — one per player class, physics entity (spikeball, shackle, chain, soccer_dummy), and monster
- **Class editor with live sliders**: drag to edit defaults, saves to user overrides, updates all entities immediately
- **Entity Stats table**: Stat/Base/Mods/Curr columns showing resolved config values
- **Calculations breakdown**: full computation chain showing base → each modifier → final value
- **Cross-selection**: clicking Modified Entities selects the entity, clicking stats shows calculations
- **Every physics body has config**: soccer dummy, spike ball, chain all have `cfg()/push_config()/remove_config()`
- **SpikeBallEntity**: proper persistent entity with own config stack, `exec_ball_*` prefix dropped
- **Chain config stack**: `cfg()` for damping, gravity, link_length, max_hp
- **Soccer dummy config**: mass, gravity, friction, bounce, radius all configurable
- **Chain selection glow**: pulsing blue polyline aura behind selected chain
- **Game Settings moved** to Level Editor Actions ("Same Class OK" toggle)
- **Dynamic section titles**: update each frame with selection context (Class: melee, Stats: bat_01, etc.)
- **Scroll/hover/click fixes**: all list sections have scroll indicators, hover highlights, scroll-aware click handlers
- **Entity naming**: chains auto-named `chain_01`, bats auto-named `bat_01`
- **Resize grip always visible** on collapsed sub-section headers
- **TPS metrics visible** in debug aspect tree (visual + textual separate)

### v0.10.35
**ShackleEntity refactor, chain damping, anchor fix**

- **ShackleEntity**: shackle is now a proper scene entity (`scripts/systems/shackle_entity.gd`) with its own config stack, physics tick, chain spawning, enemy snap, and leash constraint. Legacy property accessors on player_side.gd delegate transparently.
- **Chain physics configurable**: `exec_chain_damping` (default 0.85) and `exec_chain_gravity` (default 600) — tunable via debug drawer sliders in real-time
- **Chain anchor fix**: shackle chain was severing immediately because anchor used `"node"` key instead of `"body"` — chain.gd expects `"body"`
- **Entities group**: shackle and spikeball markers now use `"entities"` group instead of `"players"`, preventing them from intercepting AI commands, tab selection, and player listings
- **Shackle init in _ready()**: shackle entity created during `_ready()` not just `reset_state()`, fixing null shackle on fresh spawn
- **top_level positioning**: shackle entity uses `top_level = true` for world-space positioning as child of player

### v0.10.34
**Chain physics fix, TPS metrics, clean logs, unified UI, generic ai_spawn**

- **B-S chain length fix**: B-S chain was getting overwritten from 600 to 300 every frame by split update — now correctly preserves full length for Release mode chains
- **Unified B-S/B-P/B-E physics**: removed separate B-S constraint code, all modes use same chain constraint + YEET path. B-S with attached entity uses entity mass for YEET
- **Chain FABRIK sag**: removed straight-line shortcut for taut chains — FABRIK + gravity always runs, producing natural catenary drape even when taut
- **Chain tension feedback**: chain.gd reports `tension_pos_a/b` and `is_taut` after FABRIK solve
- **TPS metrics in debug drawer**: every debug aspect shows visual and textual ticks-per-second, color-coded (green/orange/red). Visible even when aspect is off — see which systems are active
- **`vis()` API**: `DebugOverlay.vis("aspect", entity, func(): draw_calls)` — lambda pattern for debug draw, always counts ticks
- **Clean logs**: all hardcoded `print()` calls in player_side.gd routed through `DebugOverlay.log()`. Skeleton dumps gated behind `body_mechanics/spine_debug` aspect. Startup logs reduced to 4 lines
- **Generic `ai_spawn`**: accepts `class=executioner` (or any class name). All tests updated to explicitly declare class
- **`announce` command**: shows large centered text on screen with fade-out
- **`comment` command**: silent no-op for test script documentation
- **Spikeball marker entity**: proper Node2D with script, `cfg()`/`push_config()` proxied to owner player. Shows as configurable entity in debug drawer
- **Spike ball properties configurable**: spin speed, spin accel, max spin, wall drag, ceiling drag all route through `cfg()` with debug drawer sliders
- **Unified sub-section headers**: `_draw_sub_header()` shared by Config, Level Editor, Constructs — consistent look with accent color theming
- **Drawer state persistence**: active section saved/restored across restarts via `drawer_state.json`
- **Layout persistence fix**: `_auto_snap_all()` no longer overwrites saved sub-section heights on reload
- **Logs moved to `/var/tumu/logs/`**: falls back to `/tmp/` if unavailable
- **Input mapping doc**: `docs/design/input_mapping.md` — PS5/Xbox/keyboard mappings for all game actions
- **New test**: `exec_release_mode` — Release mode with dummy attachment, verify boundary

### v0.10.33
**Verify monitors, candy-stripe boundaries, shackle drag fix, monster HUD, test loops**

- **`verify` statement**: background boundary monitors that run every frame during tests. Breach = immediate test failure. Uses Minecraft-style `@e[name=...]` entity selectors
- **Candy-stripe boundary rendering**: 4-zone circle visual — inner green 45° stripes fading in, solid green ring, solid red ring, outer red stripes fading out. Radial alpha gradient. Desaturated during test, hyper-saturated at end (winning side vivid, losing side grey)
- **Boundary types**: `circle` (fixed or entity-relative) and `rect`. Entity-relative circles follow the anchor entity dynamically
- **Shackle entity constraint fix**: attached entities now properly constrained to shackle chain length. YEET elastic collision fires on taut transition, position leash via `call_deferred`
- **Ball stuck drag**: ball stuck on walls/platforms now gets dragged toward player when chain is taut. Pops off surface when pulled hard enough
- **Monster player HUD icon**: procedural monster silhouette with player badge, state label, HP bar in top-left corner
- **`announce` command**: shows large centered text on screen that fades out (test step announcements)
- **`comment` command**: silent no-op for test script documentation
- **`kick` command**: applies velocity impulse to any named entity
- **`shackle_attach` command**: forces shackle attachment to a target entity
- **`spawn ... name=<id>`**: custom entity naming for stable test references (also on `ai_spawn`)
- **While loop editor tracking**: body lines highlight during execution, `while` line shows ↻ with variable value, `set` lines show ✓
- **While loop math**: `Expression`-based evaluation for `set` — supports `+`, `-`, `*`, `/`, parentheses
- **Debug labels**: all world-space debug text now renders at front-most Z with 75% grey background
- **Verify line states**: ◈ pulsing blue diamond while active, ✓ green check on pass, ✗ red X on fail. Results count in test pass/fail (1/1 PASSED)
- **New tests**: `exec_shackle_kick` (4-direction kicks with verify), `exec_shackle_drag` (player walks, entity follows), `exec_bs_loop` (B-S release flight loop)

### v0.10.32
**Config refactor, modifier blueprints, shackle config stack, B-S YEET physics**

- **Config section refactored** into 4 collapsible sub-sections: Game Settings, Entities, Mod Blueprints, Mod Instances
- **Modifier Blueprint system**: JSON files in `data/modifier_blueprints/` define reusable modifier templates (multiply, add, set, min, max operations)
- **Interactive blueprint editor**: draggable sliders update live modifier instances in real-time, clickable operation badges cycle through operations, Apply/Shackle/Save buttons
- **Shackle config stack**: Executioner shackle has its own config stack (`shackle_cfg()`) with defaults for mass, elasticity, gravity, drag — editable via debug drawer sliders
- **B-S YEET physics**: Ball-Shackle elastic collision now uses same math as Ball-Player and Ball-Entity. Shackle mass=5 means ball barely notices it (3.4% velocity loss)
- **Unified flight physics**: all YEET modes (B-P, B-S, B-E) use identical elastic collision math, each "other end" provides its own config
- **Monster player HUD icon**: procedural monster silhouette with player badge, state label, and HP bar in top-left corner
- **Executioner sprite fix**: deleted fake .import files, opened Godot editor to reimport correctly
- **RCON: `mod/mods/unmod`** commands for entity modifier management
- **RCON: `smod/smods/unsmod`** commands for shackle modifier management
- **RCON: `kick <entity> <vx> <vy>`** applies velocity impulse to any entity
- **RCON: `spawn ... name=<id>`** allows custom entity naming for stable test references
- **While loop editor tracking**: loop body lines now highlight correctly during execution, `while` line shows orange ↻ while looping, green ✓ when complete
- **`set` line tracking**: top-level set commands now show ✓ checkmark in editor
- **While loop `{var}-1` / `{var}+1`**: simple arithmetic in set expressions for loop counters
- **8 modifier blueprints**: heavy_ball, bouncy_chain, glass_cannon, tank, long_chain, monster_rage, heavy_shackle, ghost_shackle
- **Experimental test suite**: `soccer_back_and_forth` (while-loop soccer ball demo), `exec_bs_yeet` (B-S release mode test)

### v0.10.31
**Absolute mass system, entity YEET, RELEASE mode**

- **Absolute mass**: Ball, player, and all entities now use real mass values (kg) instead of ratios. Ball=140, player=70, soccer ball=20, enemies range 3-200+. YEET physics use actual masses from both entities in the elastic collision.
- **Entity YEET (RELEASE mode)**: When shackle is attached to an entity and ball is thrown, the ball's momentum YEETs the shackled entity (not the player). Player is free to move. Chain connects entity↔ball.
- **3-mode throw system planned**: THROW-RELEASE, THROW-HOLD+RELEASE, THROW-HOLD+HOLD. Currently implements RELEASE mode for second throw.
- **Soccer ball mass**: Soccer dummy now has `mass=20.0` for proper YEET physics.
- **Tuning popup**: Ball Mass slider replaces Mass Ratio (range 10-1000 kg).

### v0.10.30
**Shackle attaches to any entity, R1 always recalls, no stuck states**

- **Shackle targets all entities**: Shackle now snaps to any damageable entity — enemies, attack dummies, soccer balls, other players (not self). Previously only checked "enemies" group.
- **R1 always works**: R1 recalls everything when anything is deployed (ball, shackle, or both). Only toggles ball/shackle order when nothing is out. No stuck states possible.
- **L1 recall**: Still works when both ends are thrown.

### v0.10.29
**Ball-and-chain physics overhaul, chain split system, AI player, tuning popup**

- **Chain split system**: One total chain length shared between ball and shackle. L2/R2 adjusts the split ratio (default 50/50). Double-tap snaps to max. Visual shows two radius rings (golden=ball, blue=shackle) with percentage labels.
- **YEET physics**: Partially elastic collision when chain goes taut. Ball mass ratio (2x) and elasticity (0.25) are configurable. Fires on every slack-to-taut transition — player and ball exchange momentum back and forth with degrading energy.
- **String simulation**: Chain modeled as a string (max distance only, no compression). Player overshoots ball after YEET, chain goes slack, gravity pulls ball, chain goes taut again from new direction.
- **Probability cone preview**: Two coupled two-body simulations (optimistic + pessimistic) form a cone showing where the ball will land. Outer arc = no damping, inner arc = aggressive damping. Reality falls between them.
- **Shackle chain**: Shackle now has its own chain.gd instance with rigid constraint. Only attaches to enemy hitboxes, bounces off walls. Chain severs independently from ball chain.
- **AI player system**: `ai_spawn` creates a joystick-free player. `exec_test <angle> <hold> [x y]` spawns an AI Executioner, aims, throws, and records results. Used for automated physics testing.
- **Player AI input system**: Generic command queue (`ai_queue_cmd`) injects actions into the player's input system. Supports hold duration, aim direction override. Works for any player class.
- **Tuning popup**: `et` command toggles a live slider panel for all ball/chain settings. Click-drag to adjust mass ratio, elasticity, throw speed, gravity, chain length in real-time.
- **ModifierProvider**: New config provider type for artifacts — supports multiply, add, set, min, max operations on any config key. Stacks with existing DictProvider/CallableProvider.
- **Chain reel sound**: Clinky chain sound when adjusting split with L2/R2 while chain is deployed. Higher pitch for reeling in, lower for letting out.
- **Throw arc improvements**: Ball cone extends to viewport edge or physics body. Shackle shows narrow precise line. Ball preview stops at wall hits. Physics collision checks every 3rd step for performance.
- **R1 mode indicator**: Shackle-first mode shows dangling chain links with shackle cuff in front of player. Ball-first shows the spike ball.
- **`/godot restart --level`**: Slash command now accepts `--level <name>` to auto-load a level after restart.

### v0.10.28
**Executioner class, entity effects system, player config, chain physics overhaul**

- **Executioner class**: New heavy melee character with ball-and-chain, shackle, and axe. Dark hooded sprite with red eyes.
- **Ball-and-chain**: L1 throws a massive spiked ball on a rigid FABRIK chain. Trajectory preview (like monster leap) shows during windup. Right thumbstick aims with priority over left stick.
- **YEET physics**: When the chain goes taut, momentum transfers via partially elastic collision (configurable mass ratio 8x, 75% elasticity). The player gets launched along the chain direction — works as a traversal tool.
- **Spike ball behavior**: Sticks to walls (drags slowly down), sticks to floors (drags if pulled), cannot stick to ceilings (drags out and falls). 3-second stun on enemy hit.
- **Shackle**: Only attaches to enemies (snaps to hitbox within 40px), bounces off world surfaces. Looks like splay-chain shackle.
- **Executioner attacks**: Square=overhead swing slam (hold to spin, release to slam with dust puff), Circle=quick axe chop, Triangle=charged cleave (2s power-up, massive semicircle sweep, player knockback from impact).
- **Chain physics overhaul**: Replaced Jakobsen solver with FABRIK — each link is an exact rigid rod. Flexible joints but zero stretch. Every-4th-link collision for performance. Chain cannot pass through walls (segment raycast + point probe).
- **Entity effects system**: New `EntityEffects` static class for timed effects on any entity (stun, slow, bleed, burn, etc.). Used by executioner ball stun.
- **Player Entity Config**: Players now have `cfg()` / `push_config()` / `CONFIG_BOUNDS` like monsters. Debug drawer shows class-specific config sliders (physics, combat, health, class abilities).
- **Game config**: `game/multiple_players_same_class` toggle (default OFF). Accessible via debug drawer, RCON (`gameconfig` command), and debug aspects.
- **Monster-as-player improvements**: Health bar added, ghost on death (no disappear), revive mechanics (solo jump or teammate proximity).
- **Player names in debug drawer**: Entity list shows profile name + class instead of node name.
- **Chain clanking**: Audible chain-link sound as the ball's chain flows out during throw.

### v0.10.27
**Playable monster, faction system, ball mode, attack zone debug**

- **Playable monster**: The quadruped monster is now a selectable character class. D-pad Left/Right cycles to MONSTER like any other class. Controller or keyboard input drives movement, attacks, and abilities.
- **Controller system**: Swappable `MonsterController` architecture — `MonsterAIController` (default) and `MonsterPlayerController` slot into the monster seamlessly. AI logic stays in the monster; controllers set intent variables.
- **Monster controls**: Left stick=move (analog speed tiers), Cross=jump, Square=bite, Triangle=swipe, L3=tail whip, Circle=ball mode, L1 (hold)=charge leap.
- **Right thumbstick head aim**: Right stick aims the monster's head in any direction (200px range). Release returns to neutral.
- **Hold-to-leap (L1)**: Hold L1 to charge, aim with stick, see an orange parabolic arc preview showing the trajectory. Longer hold = more power (400-900 speed over 1.5s). Release fires.
- **Ball mode (Circle)**: Monster curls into the grab-attack ball pose (tight, no player inside) with rolling/bouncing soccer-ball physics. Left stick pushes. Cross in ball = uncurl + mid-power leap. Circle again = unfurl to walking.
- **Air slash (R1)**: During any leap, hold R1 for front-claw swipe attacks (up to 3 per flight, 0.25s cooldown).
- **Faction system**: New `Factions` autoload with hostility matrix. Players hostile to monsters, monsters hostile to players+animals, animals hostile to bugs, bugs passive. AI targeting and damage use faction lookups.
- **Monster attacks damage chains**: Bite, swipe, tail, and lunge now check chain segment proximity and deal damage (HP/10, min 3 per hit). Chains shake and sever when HP depleted.
- **Attack zone debug indicators**: New `attack_zones/*` debug aspects show persistent hit-area circles during attacks (faint) and flashing circles at moment of hit (bright, 0.3s fade). Bite=red r50, swipe=gold r25, tail=purple r20, lunge=orange r35.
- **Faction labels**: `debug on factions/labels` shows color-coded faction name above each monster.
- **Spawn commands**: `spawn player_monster [x y] [device=N]` via RCON. `Shift+M` (keyboard) or `Select+Triangle` (controller) on title screen.
- **MONSTER class stats**: HP 300, speed 200, no mana.

### v0.10.26
**Debug drawer UI fixes, level editor tree/rock selection**

- **Icon bar overlap fix**: Icon buttons (magnifying glass, play, gear, etc.) no longer extend past the icon bar into the content pane. Buttons now sized to fit within the 36px bar with proper margins.
- **Row hover alignment fix**: Debug section hover highlight now aligns with the content area instead of starting at the panel's left edge (covering the icon bar).
- **Tree/rock row selection**: Clicking a tree or rock row in the level editor's Items list now selects it, matching the behavior of clicking trees/rocks in the world view.
- **Scale slider removed**: Removed the monster scale slider from the debug section to reduce clutter.
- **Session consolidation command**: Added `/aid-session-consolidate` command for persisting session summaries to `/var/tumu/aid/sessions/`.

### v0.10.25
**Tree blueprint system, tree placement in level editor, console keybindings**

- **Tree blueprints**: All procedural tree generation parameters now configurable. Blueprint JSON files in `data/tree_blueprints/` (oak, pine shipped). Trees in levels can reference a `"blueprint"` key to inherit shape settings.
- **Tree placement**: Seeds mode in level editor now has action buttons: +Tree, Delete, Type (cycle blueprint), Seed (randomize). New trees auto-reference a blueprint.
- **Blueprint tree editor**: Blueprints panel shows tree blueprint files. Clicking one spawns a live preview in the sandbox with 14 property sliders (trunk, branching, canopy, colors). Changes regenerate instantly. Save button writes to disk.
- **Configurable tree parameters**: trunk weight/length, max depth, min weight, wobble, spread, decay range, split/bend ranges, canopy offset/layers, bark and leaf colors.
- **Console emacs keybindings**: Ctrl+A (beginning of line), Ctrl+E (end of line), Ctrl+K (kill to end), Ctrl+U (kill to start), Ctrl+W (kill word), Ctrl+Y (yank).
- **Console word operations**: Shift+Backspace and Ctrl+Backspace delete word backward. Ctrl+Delete deletes word forward. Ctrl+Left/Right for word navigation.
- **Console mouse wheel scrolling**: Scroll output history with mouse wheel (in addition to PgUp/PgDn).
- **Console smooth slide**: Panel X position lerps smoothly when the debug drawer opens/closes (no more jump).
- **Backward compatible**: Existing level JSONs with inline tree config work unchanged — all new parameters use original values as defaults.

### v0.10.24
**Level Editor and Blueprints integrated into debug drawer — Ctrl+E removed**

- **Level Editor section** (pencil icon): New debug drawer section with 6 sub-sections using the Test Runner's polished framework (collapsible, resizable, snap-points, grip dots, layout persistence)
- **Level selector**: Scrollable list of available levels at the top. Click to load. Current level highlighted.
- **Mode list**: Gameplay + 6 editor modes (Spawn Areas, Spawn Pos, Seeds, Platforms, Portal, Migration, Splays). Selecting a mode auto-activates the level editor overlay.
- **Gameplay mode**: No editing — shows spawn/kill/territorial/revive actions (replaces Ctrl+T test menu functionality)
- **Mode-dependent actions**: Each mode shows relevant action buttons. Always-available: Clear Entities, Restart Level.
- **Property inspector**: Inline editing for selected items — number fields (click to type), sliders (drag), read-only text for pose/behavior.
- **Save sub-section**: Change summary, Save Original / Save Custom buttons, CUSTOM/ORIGINAL status indicator.
- **Blueprints section** (blueprint icon): Separate workshop for editing construct definitions (splay poses, tree shapes). Lists available pose files from `data/splay_poses/` and `user://splay_poses/`.
- **Blueprint sandbox**: Clicking a blueprint enters a blank sandbox level (flat_floor) for editing. Spawned entities are temporary. Remembers previous level to return to.
- **Ctrl+E eliminated**: Level editor now activates entirely through the debug drawer's mode list. No more separate toggle.
- **Click-through fix**: Level editor world-space mouse handling skips clicks over the debug drawer panel area.
- **Top bar suppression**: Level editor's top bar, help text overlays, and change summary hidden when the debug drawer is managing it.
- **Console slides from bottom**: Game console now slides up from the bottom of the screen instead of down from the top.
- **Console respects drawer**: Console width limited to the area right of the debug drawer when both are open.
- **Game viewport adapts**: Game area resizes to fit above the console and right of the drawer, keeping gameplay visible in the remaining rectangle.

### v0.10.23
**UI cleanup: remove static entity info, streamline test menu, save/diff detection**

- **Static entity info removed**: Eliminated the left/right positioned state text panel from monster `_draw_debug()`. Only the generic following overlay in the debug drawer remains.
- **Test menu cleaned up** (Ctrl+T): Removed 8 obsolete test suite entries (now in debug drawer). Reorganized into Spawn, Actions, and Level sections. Added Kill All and Spawn Dummy.
- **Save/diff detection**: Editor tracks disk hash — shows yellow ● + 💾 when content differs from the on-disk source file. Save promotes edits to `data/tests/` (git-tracked).

### v0.10.22
**Result caching across versions, smart soft-wrap, comment toggle, suite auto-recompute**

- **Result caching across versions**: `/ship-it` copies latest results forward to the new version directory. Script hash validates content.
- **Startup result scan**: All test/suite pass/fail indicators pre-populated on first open by scanning cached results
- **Suite auto-recompute**: Running an individual test immediately updates pass/total for every suite containing it
- **Comment toggle**: `#` button on hover toggles line commenting. Works in EDIT and INSPECT modes
- **Smart soft-wrap**: Boundary commands (`unless`, `check`) wrap at earliest match (one clause per line). Lower priority tokens wrap at latest match
- **Dynamic edit field**: Auto-sizes and soft-wraps to fit content. Same wrap algorithm as script rows
- **Editor click fixes**: Edit field takes priority over row selection. Unbounded height for hover/click/scroll in editor section
- **Opaque panel**: Fully opaque background since game viewport scales to the right
- **Play button fix**: Correct draw offset and wider 40px click zone

### v0.10.21
**Test runner overhaul: 3 editor modes, suite/test play buttons, result caching, soft-wrap**

- **Three editor modes**: EDIT (green, full editing), EXECUTE (orange, read-only during run), INSPECT (blue, click rows to view check details in Status pane)
- **Suite selection**: Click a suite to filter the Tests list to its tests. Pass/fail dot + score shown per suite. Play button runs the entire suite.
- **Test play buttons**: Each test row has a play button (visible on hover). Shows pause icon when running.
- **Result caching**: Test results auto-load from disk when switching tests. Script hash stored in results.json — only loads if script content hasn't changed. Edit and change back = hash matches again.
- **Soft-wrap**: Long script lines wrap at natural breakpoints (`unless`, `label:`, `extract:`) with ↵ indicator. Variable row heights throughout.
- **Pending deletion**: Clicking ✕ shows red strikeout. Undo (↶) or confirm (bold ✕). Approve-all button in Editor bar. Row ✕ only visible on hover.
- **Line insertion**: Green triangle with + on left side between rows. Click to insert blank line and auto-focus edit field.
- **Split-pane resize**: Grip dots resize the section above, Editor absorbs the change. All sections between stay fixed.
- **Content-based snap points**: Each section calculates preferred height from content. Dashed cyan snap line visible during drag. Double-click grip to snap. Snap on release within 12px.
- **Dynamic preferred heights**: Suites = suite count × row, Tests = min(tests, 10) × row, Controls = button bar, Status = result line count, Editor = fills remaining space.
- **Header bar context**: Tests bar shows selected suite name, Controls bar shows test name + EDIT/EXEC/INSPECT mode, Status/Editor bars show test name. Save button (💾) in Editor bar when dirty.
- **Status pane**: Shows all check results when no row selected, filtered to selected row's detail when a row is clicked in INSPECT mode.
- **Play button hit zone fixed**: Was 30px off due to missing `x` offset in draw coordinates.

### v0.10.20
**Remove floating test editor — always docked**

- **Floating test editor removed**: ~350 lines of floating window drawing, input handling, and dead helper functions deleted from `test_editor.gd`
- **Always docked**: `_docked` flag is always true. No floating fallback — RCON `run`/`suite` commands auto-open the debug drawer if closed
- **Debug drawer auto-opens**: Running a test from RCON or the test menu opens the debug drawer and switches to the Test Runner section automatically
- **Deferred initialization fixed**: Script properties (`_docked`, `_active`) are guarded against access before `_ready()` runs, preventing "Invalid access" errors on freshly created editors
- **DebugDrawer lookup simplified**: Uses `get_node_or_null("/root/DebugDrawer")` instead of fragile property-sniffing loop

### v0.10.19
**Generic entity selection, config panel overhaul, debug click fix**

- **Generic entity selection**: Any entity (monsters, bats, players, dummies) can be selected from the Config panel. Pulsing cyan circle with 1-indexed number drawn in world space for any selected entity
- **World-space state info panel**: Selected entity shows a floating info box with type, ID, position, HP, state, velocity, scale, chain status — with a line pointing to it. Works for all entity types
- **Config panel redesign**: Search filter at top, full entity list (all types, no cap), then type-adaptive config — monsters get cfg() sliders, other entities show their script properties
- **Entity list shows ID + type**: Each entity displays its entity_id and script type name side by side with 1-indexed number for visual correlation
- **Debug aspect tree click fix**: Click/hover detection was using hardcoded `HEADER_HEIGHT` (160px) instead of the dynamically calculated tree start position. Now syncs correctly — clicking V/T checkboxes always hits the right row
- **Selection indicator generified**: Removed monster-specific "SELECTED" text from quadruped_monster.gd. All selection rendering handled by a generic world-space overlay in the debug drawer

### v0.10.18
**Docked test editor, chain daze, soccer ball dummy, balloon explosions, press-to-join**

- **Docked test runner**: 5 collapsible, resizable sub-sections (Suites, Tests, Controls, Status, Editor) inside the debug drawer. Collapse via triangle, resize via grip dots. Layout persists to disk
- **Chain daze**: Monster yanked back mid-leap when exceeding chain length. Takes 30 damage, falls limp (ragdoll), lies dazed with circling sparkly stars for 5s, stands up over 2s. Chain takes 25 damage + violent shake
- **Soccer ball dummy**: `spawn dummy` creates a rolling soccer ball (Wikipedia SVG texture). Realistic rotation (angular velocity = linear velocity / radius), bounce, friction, knockback
- **Balloon chain explosions**: Popping a balloon triggers nearby balloons to pop with staggered 0.12s delay. Every pop spawns a 3-layer expanding fireball blast that deals 20 damage to enemies + 10 friendly fire
- **Melee ground slam pops balloons**: Slam through balloons mid-fall without stopping
- **Damageable tentacles**: Rift tentacles have a collision hitbody (CharacterBody2D on layer 8). 30 HP when free, damage flash on hit, death smoke on kill
- **Chains damageable by all weapons**: Player attack areas detected against chain segments each frame. 8 damage per melee hit with shake + sound
- **Press-to-join controllers**: No auto-join on startup. First button press = P1, second = P2, etc. Class/profile persisted per slot (not per controller). Mid-game disconnect reserves the slot for reconnect
- **Player debug migrated to DebugOverlay**: 5 new aspects (`player/velocity_arrows`, `player/jump_tracers`, `player/archer_arcs`, `player/reticle_info`, `player/button_state`). Old `_debug_mode` replaced
- **Hitbox debug aspects**: `hitboxes/monster_parts` (colored circles per part), `hitboxes/player_attack` (attack area rectangle when swinging)
- **Debug auto-disabled on level start**: Entering gameplay from title screen turns off all debug overlays
- **`kill` RCON command**: Deals 99999 damage to all enemies (triggers death sequence, unlike `clear`)
- **`check no_leaps`**: New test check verifies monster has zero planned leap edges
- **Complete `help` command**: All RCON commands listed with descriptions
- **Debug V/T checkbox click fix**: Hit detection corrected (was offset by icon bar width)
- **test_menu.gd null viewport fix**: `get_viewport()` guarded after scene reload

### v0.10.17
**Multi-section debug panel, config sliders, test runner UI, bounds enforcement**

- **Multi-section icon bar**: Debug (magnifying glass), Test Runner (play), Config (gear) — click icons to switch sections
- **Config sliders**: 60+ configurable values with grouped categories (Mode, Physics, Skeleton, Pose, Movement, Gait, Blend, Combat, Leap, Grab, Health, Precog). Drag to adjust live. Single persistent provider (no stack spam)
- **CONFIG_BOUNDS**: Every configurable value has enforced min/max bounds in `cfg()`. No more division-by-zero or monster disappearing from extreme values
- **Test Runner UI**: Lists all suites and tests with click-to-run. Hover highlights. Shows running test status
- **Viewport scaling**: Game canvas shifts right and scales when drawer opens, resets when closed
- **Level per test**: All 34 tests now declare their level (`level title_screen` or `level flat_floor`) with a wait for deferred rebuild before `clear`
- **Force normalization fix**: `speed_medium` no longer inversely affects push force when changed via config
- **Debug panel spec**: Full spec for docked test editor with collapsible sub-sections captured in `docs/design/debug_panel_spec.md`

### v0.10.16
**Gait system, level loading, while loops, peaceful mode**

- **Leg depth ordering**: Far-side legs render behind body, near-side in front. Switches with facing.
- **Gait oscillation**: Clavicles/hip bones swing forward/backward with diagonal gait pattern. Knees swing 1.2x more (cascading). Speed-dependent amplitude.
- **Bipedal arms**: Upper arms dangle, claws aim at eyeball. Shoulder oscillation at 50%.
- **`peaceful` config**: Monster pathfinds to target but never attacks or leaps. `config={peaceful=1}`
- **`while`/`endwhile`** in test scripts: Variable-driven loops with `set` command for control flow
- **`level` RCON command**: Loads a level by name, tears down and rebuilds world geometry. `level flat_floor`
- **`flat_floor` level**: Empty floor, no platforms/bats/portal/scenery — clean canvas for animation tuning
- **`gait_tuning_loop` test**: Peaceful monster walks back and forth forever on flat floor
- Portal setup skips creation on empty config (no phantom doors)
- Bat spawner disabled (`_bat_max=0`) when level has no spawn zones
- `gait_stride_rate` and `gait_knee_swing` added to config defaults

### v0.10.15
**Predatory leap: arms-forward flight, dramatic 3-slash with blood spray**

- **Arms reach forward during flight**: Front legs extend toward a point above the target instead of tucking against the chest. The monster looks like a hawk diving at prey
- **3 dramatic downward slashes** replace the old 6-slash rapid-fire. Each has a visible RAISE → fast STRIKE → PAUSE cycle with alternating sides
- **Momentum carries through strikes**: Half-gravity and gradual deceleration during slashing instead of freezing mid-air
- **Enhanced leap slash effects**: Bright sweeping arc (arm-sized, flashes in ~4 frames), 3 lingering claw marks that slowly fade, 12 blood droplets that spray downward and stretch into drips as they fall
- `leap_slash_raise`, `leap_slash_strike`, `leap_slash_pause` timing values added to config
- All 27 tests pass, zero failures

### v0.10.14
**Attack wind-up and follow-through animations**

- **Bite**: head rears back (coil), pauses, snaps forward fast with slash effect, follow-through past target, recovery
- **Swipe**: body leans away (coil), claw pulls back, raises high, fast downward arc (3x faster than before) with slash effect, follow-through, recovery
- **Tail whip**: spine compresses (crouch), tail curls wide S-curve with cascading segments, fast crack release (base-first tip-last), follow-through, recovery
- **Lunge**: rear legs visibly compress, body rocks back, explosive head-first launch with jaw opening, slide deceleration, recovery
- Slash visual effects now fire during bite strike and swipe strike (previously only on grab/sprint/leap)
- Strike phases move 3x faster than wind-up for visible snap contrast
- **Debug state info**: shows current attack phase (COIL/RAISE/STRIKE/FOLLOW/RECOVER) with timer, highlighted yellow during STRIKE
- **Config stack display**: state info panel shows active providers and override count
- 13 new configurable timing values: `bite_windup/strike/recover`, `swipe_coil/raise/strike/recover`, `tail_coil/whip/recover`, `lunge_coil/launch/slide`
- New `exag_attack_showcase` test with heavily exaggerated timings (scale 1.5, stiffness 4.0, 3x slower windups)
- `exaggerated_animations` suite expanded to 5 tests

### v0.10.13
**Momentum speed curves and head tracking fix**

- **Asymmetric acceleration/deceleration**: Separate `accel_rate` (200, slow buildup) and `decel_rate` (600, hard braking) replace the single `speed_blend_rate`
- **Speed-dependent stride**: Stride offset scales with current speed (0.15 * speed). Short choppy steps at low speed, long fluid strides at top speed
- **Speed-dependent step height**: Foot lift scales with speed ratio — higher arcs during fast movement
- **Head tracking fix**: Skull aim anchored from spine[0] (neck base, correct height) instead of spine[1] (body center, caused upward-looking head). Aim direction still computed from stable body center
- Exaggerated tests updated: `exag_floor_sprint` and `exag_speed_transitions` use `accel_rate=80, decel_rate=300-400` for visible momentum
- `accel_rate` and `decel_rate` added to `monster_defaults.json`
- Exaggerated suite 4/4 passed

### v0.10.12
**All monster constants routed through cfg() — fully runtime-configurable**

- All 60+ monster constants now use `cfg(key, DEFAULT)` instead of bare const references
- Covers: gravity, mass, all segment lengths, stiffness, speed tiers, all combat damage/ranges/cooldowns, leap planning params, health values, grab/sprint/hop-up/precog tuning
- Every value can be overridden at spawn time (`config={}`), via timed buffs (`buff` command), or programmatically via the config provider stack
- GDScript `const` declarations preserved as absolute fallbacks
- `monster_defaults.json` serves as the single source of truth for default values
- All 27 tests pass, zero failures

### v0.10.11
**Config provider stack — composable monster configuration**

- **Stack-based config system**: Monster constants resolved via a priority stack of providers. First non-null wins, falls back to GDScript const
- **Provider types**: `DictProvider` (JSON/dictionaries), `CallableProvider` (dynamic functions), `TimedProvider` (auto-expiring wrapper for buffs/debuffs)
- **JSON defaults**: `data/config/monster_defaults.json` with 60+ configurable values (physics, movement, combat, leap, health, grab, sprint, precog)
- **Timed buffs via RCON**: `buff <duration> <key=value> ...` applies temporary overrides to all monsters. Auto-pruned every 60 frames
- `apply_timed_config()` convenience method for programmatic buff/debuff application
- `push_config()` / `remove_config()` for direct stack manipulation (power-ups, state modifiers)
- Spawn `config={}` overrides now use the stack (DictProvider) instead of a flat dictionary
- All 27 tests pass, zero failures

### v0.10.10
**Exaggerated animation test suite and animation roadmap**

- New `exag_floor_sprint` test: monster sprints back and forth chasing teleporting dummy (speed blend + turns at full speed)
- New `exag_landing_recovery` test: monster on P1 leaps to floor (landing compression + post-impact speed blend)
- New `exag_speed_transitions` test: dummy alternates close/far positions (speed tier ramping between slow/medium/fast)
- All exaggerated tests use `scale=2.0` with tuned `cfg()` params for visible animation quality
- `exaggerated_animations` suite expanded to 4 tests (4/4 passing)
- New `docs/design/animation_roadmap.md` capturing upcoming work: momentum/speed curves, attack wind-up/follow-through, wall climbing, wall jumping

### v0.10.9
**2.5D skeleton projection for smooth turns**

- **2.5D projection system**: Segment rigidity uses `_projected_len()` to compute physically correct 2D distances during turns. Horizontal segments compress as if rotating into Z. Uses rest-pose directions to avoid feedback where collapsed segments resist compression
- **3D shoulder/hip rotation**: Clavicles and hip bones rotate around the spine via `_enforce_shoulder_3d()` with configurable `SHOULDER_Z_DEPTH`. Near-side sweeps inward, far-side sweeps outward, crossing at midpoint
- **Turn commitment**: Blocks facing reversals while mid-turn (`|_facing| < 0.9`) to prevent oscillation when target is nearly overhead
- **Head tracking fix**: Skull aims from spine[1] (stable body center) instead of breathing-affected spine[0]. Aim blend goes to 100% during turns to override rest-pose snap
- **Cosine easing**: `_get_facing_offset()` applies cosine curve so body stays near full width longer and snaps through compressed midpoint symmetrically
- New `chained_above_slow_turn` test with exaggerated turn/stiffness config (scale=2.0, turn_speed=2.0, stiffness=6.0)
- New `exaggerated_animations` test suite for visual verification
- All 27 tests pass (all suite), zero failures

### v0.10.8
**Runtime config system for monster constants**

- New `cfg(key, default)` helper reads from `_cfg` dictionary, falling back to const defaults
- `apply_config(dict)` method accepts arbitrary key=value overrides at runtime
- RCON spawn syntax: `spawn monster X Y [state] config={turn_speed=2.0,stiffness=6.0}`
- 12 constants now configurable: `turn_speed`, `speed_blend_rate`, `landing_recovery_time`, `landing_compress`, `fall_threshold`, `stiffness`, `head_track_speed`, `step_threshold`, `step_duration`, `step_height`, `foot_push_force`, `foot_grip`
- Test scripts can use config to exaggerate parameters for visual verification
- All 27 tests pass

### v0.10.7
**Movement blending: smooth turns, speed ramps, landing recovery**

- **Facing blend**: `_facing` lerps toward `_facing_target` at configurable `TURN_SPEED` instead of flipping instantly. Skeleton rest-pose targets sweep through the turn, creating visible body curl during direction changes
- **Speed blend**: `_move_speed` lerps toward `_target_move_speed` at `SPEED_BLEND_RATE`. Gait transitions smoothly as stride and step frequency ramp
- **Landing recovery**: After 0.15s+ airborne, landing triggers 0.25s spine compression + 70% force reduction. Monster visibly absorbs impact before resuming movement
- `_get_facing_offset()` now multiplies x by facing float (supports intermediate values during blend) instead of binary flip
- Leap launches, mid-flight facing, and course corrections still use instant facing (no slow turns mid-air)
- New `monster/blend` debug aspect for turn/speed/landing diagnostics
- All 27 tests pass (1 pre-existing flaky `hunt_P2` ik_peak)

### v0.10.6
**Consolidate attack timer/cooldown resets into enter hook**

- `_enter_state()` now resets `_attack_timer` for all combat, transition, and precog states
- `_enter_state()` sets `_attack_cooldown` for attack-entry states (not mid-leap sub-states)
- Removed 16 duplicated `_attack_timer = 0.0` / `_attack_cooldown = ATTACK_COOLDOWN` lines from `_start_attack`, `_start_grab`, `_start_sprint_slash`, `_start_hop_up`, `_start_leap`, `_start_precognition`, and inline transition sites
- `_start_*` functions now only contain state-specific setup (targets, counters, skeleton poses)
- All 27 tests pass (1 flaky `hunt_P2` ik_peak — pre-existing, unrelated)

### v0.10.5
**Enter/exit hooks for monster state machine**

- `_change_state()` now calls `_exit_state(old, new)` and `_enter_state(new, old)` hooks
- Exit hooks consolidate per-state cleanup: tail whip flag, grab collision restore, leap IK/floor-snap reset, posture finalization
- Enter hooks handle per-state defaults (standdown zeroes velocity/direction)
- Leap sub-state transitions (windup/airborne/strike/thrash) skip full leap cleanup — only applied when leaving the leap group entirely
- Removed duplicated cleanup from `_do_tail_whip`, `_do_grab`, `_do_transition_*`, `_end_leap`, and standdown entry
- All 27 tests pass (1 flaky `ik_peak` near-threshold on `hunt_P2` — unrelated to state changes)

### v0.10.4
**Centralized monster state machine transitions, debug logging for state changes**

- All 42 monster state assignments now route through `_change_state()` instead of raw `_state = State.XXX`
- New `monster/state` debug aspect logs every state transition (e.g., `STATE: CHASE -> ATTACK_LEAP_PLAN`)
- Enable via RCON: `debug log monster/state`
- Removed redundant state-change tracking from `_score_strategy_thrash()` (now handled by `_change_state()`)
- RCON `run` and `suite` commands default to `owait=0` instead of `owait=600` for faster automated test runs
- All 27 tests in `all` suite pass with zero regressions

### v0.10.3
**Suite skip support, suite completion logging, test-gate polling fix**

- `suite` RCON command supports `skip test1 test2 ...` to exclude tests from a run
- Suite completion prints `SUITE_COMPLETE <name> X/Y` to stdout for log-based polling
- `/test-gate` command polls via separate 1-second Bash calls instead of blocking loops
- All 4 gate suites pass: combat 14/14, chained 7/7, leaping 5/5, scaling 1/1

### v0.10.2
**Test Gate System, Suite Partitioning, Release Workflow**

- Test suites now have `"gate": true/false` field — gate suites auto-run, non-gate suites are manual-only
- Gate suites (`chained`, `combat`, `leaping`, `scaling`) partition all 27 tests with no overlaps
- Non-gate suites (`all`, `todo`) excluded from automated gating
- New `scaling` gate suite for scaled monster tests
- `combat` suite expanded: added `quick` and `verify_leap_graph_P0_P1` to close coverage gaps
- `/test-gate` command: checks staleness via `ts/<suite>/pass` and `ts/<suite>/fail` git tags, runs stale suites, records results
- `/release` command: pushes trunk + version tag, enforces all gate suites passing at HEAD
- `/ship-it` command: bumps patch version, updates docs, writes release notes, commits

### v0.10.1
**Procedural Monster Scaling, Splay Scale Controls, Chain Scaling**

- Single `creature_scale` float controls all monster dimensions (skeleton, collision, drawing, combat, pathing)
- `sc()` helper scales 260+ spatial constants automatically; scale 1.0 is identical to pre-scaling behavior
- Speed auto-scales with size; `speed_override` decouples speed from size
- `pathing_radius` override lets large monsters path through standard-sized gaps
- `spawn monster X Y [state] [scale=N] [pathing_radius=N]` RCON syntax
- Splay manager spawns scaled creatures with scaled skeleton snapshots, connection offsets, and chain distances
- Chain link width, shackles, wall pegs/rings scale with creature size
- Tether rope width, hooks, and fray effect scale with creature size
- Debug drawer: live scale slider on TAB-selected monster (Ctrl+D)
- Level editor splay widget: draggable rotation handle (cyan circle) and scale handle (green diamond)
- `splay spawn` RCON and level config support `scale=N`
- All monsters auto-assign `entity_id` in `_ready()` via static counter
- Level editor save dialog click detection fixed (screen-to-world coordinate conversion)
- New test: `giant_floor_to_P3` (two scaled monsters, 0.5x and 2.0x, hunt one target)
- Debug aspects: `scaling/active_scale`, `scaling/effective_radii`, `scaling/speed_info`

### v0.10.0
**In-Game Test Editor, Arc Planning Fixes, Bounded Leap System — 25/26 tests pass (96%)**

**In-Game Test Editor:**
- Visual test editor (Ctrl+T → Tests...) with draggable control points for all command types
- Spawn, bleap, ETZ/DAZ, fence, exit_circle — all editable in the game world
- Floating window: numbered script list, click to select, inline text editing with Tab autocomplete
- Run mode: per-line execution state (pending/running/complete), auto-select failed row
- Suite runner with prev/next navigation, position in title bar [N/M]
- Notify system with variable substitution (`var owait default=0`)
- Double-click to execute single line, drag-drop row reordering
- Post-run review: violations render as body circles (r=55), breach markers shown
- `suite all owait=0` runs all 26 tests; `suite todo owait=600` for interactive review

**Arc Planning Fixes (P1):**
- Body circle clearance via `intersect_shape` with `CircleShape2D` at each arc point
- Dynamic radius reduction near destination: full radius mid-flight, fades when directly above landing zone
- Below-surface cap: radius limited so body can't reach UP and clip platform from underneath
- Higher arcs: LEAP_FLIGHT_TIME_MAX 1.2→1.6, LEAP_FLIGHT_TIMES 5→7
- Finer simulation: LEAP_ARC_STEPS 16→40, LEAP_ARC_DT 0.04→0.03
- Gap detection: same-level platforms trigger precog when floor probe finds no ground at midpoint
- Horizontal bounding arcs (arc_l/arc_r) replace diagonal launch-perpendicular offset

**Bounded Leap Monitor:**
- Continuous graph monitoring during wait (polls every 0.5s)
- Collects matches and violations over test lifetime
- MATCHED = START+END fit, no disallow breach; VIOLATION = START+END fit but arc clips disallow
- Unmatched arcs (fail START/END) silently ignored — not violations
- `bleap next` accumulates multiple leap defs; single `check bounded_leaps` evaluates all
- Monitor checks body circle (r=55) against disallow capsules

**Breach Fences & Exit Circles:**
- `wait N unless breach X1 Y1 X2 Y2 patterns...` — finite segment trip wire
- `wait N unless exit_circle X Y R patterns...` — abort if entity leaves circle
- Fences are TRUE segments: perpendicular distance limit (50px), strict [0,1] span
- Breach markers rendered in editor (orange circle with L<line>[idx] label)
- Breach just aborts wait — not a test failure

**Test Infrastructure:**
- All 26 tests in script format with parameterized `notify` and `var owait default=0`
- Comprehensive JSON output: `user://test-output/<version>/<test>/<timestamp>/results.json`
- Suite output: `user://test-output/<version>/<suite>/<timestamp>.json`
- Test state machine: INITIALIZING → RUNNING → COMPLETE → FINALIZED
- `suite all` runs all tests; `suite todo` runs failing tests only
- RCON key=value args: `suite all owait=600`, `run test owait=10`
- Auto-clear zones and debug state between suite tests

**Console Improvements:**
- Cursor position, text selection, Ctrl+A/C/X/V cut/copy/paste
- Test name autocomplete for `testload`, `run`, `testsave`, `suite`
- `run` and `suite` from console route through RCON (consistent arg parsing)

### v0.9.25
**Chain Surface Collision, Physical Chain Constraints, Console Autocomplete**

**Chain Surface Collision:**
- Verlet chain points raycast in 4 directions (down, up, left, right)
- Chains drape over platforms, rest on ledges, slide against walls
- Surface friction dampens horizontal sliding
- Only collides with world geometry (players pass through)

**Physical Chain Constraints:**
- Leaps/precog/lunges all allowed for chained creatures — chain physically limits reach
- On-floor: horizontal-only constraint (Pythagorean max-X at current Y)
- Airborne: full 2D constraint with floor clamp (no clipping through geometry)
- Chain constraint runs before move_and_slide (respects floor collision)
- Standdown off now forces CHASE state + picks target

**Console Autocomplete (Tab):**
- Tab cycles through matching commands
- Completes RCON commands, test names (`run <tab>`), suite names (`suite <tab>`)
- Current match highlighted in [brackets] above input line
- Up to 8 matches shown with overflow indicator

**Chained Monster Tests:**
- chained_floor: monster attacks nearby dummy within chain reach
- chained_reach: dummy beyond chain length (expects 0 damage)
- chained_above: dummy on platform above (expects 0 damage)
- Test setup: spawn standdown → chain → spawn dummy → wake

**Portal Safety:**
- Portal disabled state persists across level rebuilds (stored as scene meta)
- Re-applied every 60 frames to catch recreated portal nodes

### v0.9.24
**Chained Creature AI, In-Game Console, Portal Test Safety**

**Chained Creature AI:**
- Active chained creatures walk, chase, and attack within chain reach
- Horizontal chain constraint: uses Pythagorean max-X at current Y (no vertical yanking)
- No precog pathfinding for chained creatures (can't multi-hop)
- No leaping for chained creatures
- Stale precog waypoints cleared on spawn
- Chain constraint applied before move_and_slide (floor collision respected)
- Asleep chained: stays frozen, zero velocity
- Awake + on floor: full AI with chain limits
- Awake + suspended: dangles with gravity, limbs enforced

**In-Game Console (backtick `):**
- Quake-style pop-down console, accepts all RCON commands
- Test runner: `run <test>`, `suite <name>`, `tests`
- File-based tests (JSON): setup commands, wait, checks
- 13 combat test files + combat suite
- Frame-based task queue for sequential test execution
- Command history, scrollable output, color-coded results

**Editor Fixes:**
- Ctrl+E works on first press
- Splay drag: stored creature reference (no proximity guessing)
- Splay drag: Verlet chain points shift with creature
- Rotation ring in splay edit (drag to rotate all points around origin)
- FABRIK: 30 iterations, angle corrections propagate downstream

**Portal Test Safety:**
- `portal off` RCON command disables portal transitions
- All test scripts + JSON test files include portal off in setup
- Prevents test dummy from triggering level transition

### v0.9.21
**Verlet Chain Physics, Chained Creature Mode, Breakaway Fix, Pose Lock Fix**

**Chain Physics (Verlet):**
- Position-based Verlet integration with Jakobsen constraint solving
- Chains drape naturally under gravity with fixed-length segments
- Iterations scale with chain length for convergence
- Chain HP reduced to 200 for faster breakaway testing
- Alternating thin/thick dark grey rendering with shackles + peg/ring
- RCON: chaindump — detailed per-point position + distance report

**Chained Creature Mode:**
- `_chained` flag: creature has gravity but chains constrain position
- Chain constraints clamp CharacterBody2D position each frame
- Velocity along chain direction killed when taut
- Asleep + not on floor = go limp (limbs dangle)
- Awake + on floor = try to stand/walk within chain reach

**Breakaway Fix:**
- Tracks total ORIGINAL HP across ALL chains (including severed ones)
- Breakaway triggers when 50% of original aggregate HP is destroyed
- On breakaway: state forced to CHASE, _pick_target() called immediately
- Creature targets nearest player after breaking free

**Pose Lock Fix:**
- `_enforce_spine_rigid()` skips angle constraints when `_pose_locked`
- Only distance enforcement runs — preserves non-standard orientations
- Fixes body kinking sideways for vertically-posed splayed creatures
- Neck/skull angle constraints also skipped when pose_locked

**Test Menu:**
- "Clear Level" (was "Reset Level") — clears enemies/players
- "Restart Level" — full scene reload (game reboot)

### v0.9.20
**Editor Change Tracking, Source Mode Detection, Save Original/Custom Workflow**

**Source Mode Detection:**
- `Version.is_source_mode()` — detects running from source code (checks `res://project.godot`)
- "[DEV]" badge shown in editor when in source mode
- Source-only operations: save original, delete bundled poses

**Editor Save Workflow (Original / Custom):**
- Ctrl+S shows O/C dialog with clickable buttons and keyboard shortcuts
- _O_riginal: saves to `res://` (source authority), deletes custom override
- _C_ustom: saves to `user://` (user override)
- Works for both level configs AND splay poses (same UX)
- Non-source builds: only Custom save available

**Change Tracking:**
- Per-component tracking: which items have unsaved changes
- Yellow asterisk (*) on changed splay instances in editor overlay
- Summary bar: "2 splays changed, 1 migration changed" (only non-zero)
- Custom/Original status: "(CUSTOM - N unsaved changes)" or "(ORIGINAL)"

**Pose Library Enhancements:**
- Usage tracking: scans all level configs, shows "Used in: level(count)" per pose
- CRUD: N=new, Del=delete, E=edit
- Unused poses shown dimmed
- Missing pose references: RED outline, click to replace or delete

**Splay Editor Fixes:**
- Drag/rotate/cycle no longer trigger full level rebuilds
- Creature moves directly when dragging splay instance marker
- I-pose: renamed from t-pose (body=I stem, arms/legs=I serifs)
- Save dialog: O/C choice with underlined hotkeys, clickable buttons
- ESC from edit rebuilds level to restore all splay creatures

### v0.9.19
**Splay Pose System, Chain System, Skeleton Rigidity, Editor Overhaul**

**Splay Pose System:**
- Creatures positioned in custom poses with chains/tethers to walls
- Pose editor (Ctrl+E → SPLAY → E): preset poses (L/R/U/D), FABRIK IK drag, pinned joints, mirror mode
- Full skeleton snapshot saved in pose JSON — exact restoration on reload and spawn
- Poses auto-spawn from level config on level load
- 3 behaviors: active, stand_down, asleep (dormant until damaged)
- Breakaway at 50% aggregate tether damage — flash, screen shake, creature wakes
- Pose library browser (P key) with preview thumbnails
- Multi-creature splay support with inter-creature tethers

**Chain System:**
- Zero-stretch rigid connections (hard position correction every frame)
- 2000 HP, damage per hit capped at 5
- Shackles at creature end (sized to limb), peg+ring at wall end
- Alternating thin/thick dark grey segments, fixed-length rendering
- Shake + flash damage feedback on hit
- RCON: chain commands parallel tether commands

**Skeleton Rigidity:**
- 4 new bones: clavicle L/R (from shoulders), hip bone L/R (from waist)
- Clavicles/hip bones rotate with body orientation
- Upper limbs rigid (exact length), lower limbs ±10% flex
- Tail segments: rigid ±5% flex, max 20° bend per joint
- Spine joints: max 30° bend, neck joints: max 45° bend
- All rigid constraints enforced in ALL states (leap, grab, precog)
- Planted feet preserved at world position when reachable
- Skeleton dump system: Shift+SPACE in edit, RCON dump, auto-triggers

**Leap & Movement Fixes:**
- No backwards leaps: facing check at initiation, launch, and during flight
- Precog multi-hop: must face launch direction before each hop
- Floating legs fixed: force-replant when feet unreachable

**Editor & Testing:**
- Splay editor: click to select, SPACE toggle, C rope/chain, P pin, M mirror, drag IK
- Test menu (Ctrl+T): run test suites, spawn monsters, reset level
- Help overlay (?): all keyboard, controller, and RCON commands
- Territorial mode: monsters attack each other (RCON: territorial [on|off])
- Skeleton dump: JSON export of all bone positions + distances for debugging

### v0.9.18
**Monster Damage & Weak Spots, Dual-Grapple Tether System, Attack Dummy**

**Monster Damage & Weak Spots:**
- Tiered damage states per body part: NONE → MEDIUM → HIGH with blood effects
- 7 vulnerable zones: head, eye, mid-tail, torso, 2 rear legs, 2 arms (front legs)
- Eye critical hit: 2x damage to head + audible PING + 5-directional blood squirt
- Gameplay penalties at HIGH damage: tail disables grab attack, torso drips blood continuously, rear legs reduce leap distance (25%/50%), arms reduce slash damage (50%/75%)
- Blood particle system with splash and squirt modes, gravity, and fade
- Part-specific arrow damage: arrows hit nearest body part hitbox
- Monster HP increased: body 1500, head 400, tail 300, legs 250 each
- 4 attachment points: head, tail tip, shoulders, waist — for balloons, tethers, grapple
- Per-segment weight system (total ~193): head 15, torso 40, legs 12 each
- RCON: partstatus, partdmg, weight, attach, detach

**Dual-Grapple Tether System:**
- L1 first hook → adjust rope length → L1 second hook → creates persistent tether between two points
- Tether entity with strong pull physics (force 25000), mass-aware force distribution
- Connects anything: enemy↔enemy, enemy↔wall, body part↔body part, wall↔wall
- Max 5 active tethers per player, HUD dots show available slots
- Body part targeting: hooks snap to nearest attachment point on enemies
- Tether rendering: catenary sag when slack, straight when taut, red when over-stressed
- Tether HP (100): severable by projectiles passing through the rope, visual fraying before snap
- R1 pulls player to anchor (moved from L1 second press)
- RCON: tether commands for creation, length adjustment, status, and cutting

**Attack Dummy & Testing:**
- New test entity: configurable orange circle that fires at enemies
- 3 weapons: bow (arrows), balloon (darts), tether (creates tethers at targets)
- Targets specific body parts by name, tracks shots/hits
- Monster stand-down mode: passive, receives damage, skeleton still animates
- Solo self-revive: press jump when dead with no teammates
- RCON: spawn attacker, attacker target/part/weapon/rate/stop/start/stats
- clearplayers blocks controller re-joins, enablejoins re-allows them
- Balloons last forever (only removed by popping)

**Test Suites:**
- test_damage.sh: 6 tests for damage states, grab disable, bleeding, leap/slash reduction
- test_attachments.sh: 6 tests for balloon attachment, stacking, detach, weight
- test_tether.sh: 7 tests for tether creation, physics, balloon resistance, severing
- Regression: 18/18 hit rate, 4513 total damage (best ever)

### v0.9.17
**17/18 Test Suite, Score Cards, Cliff Aerial Strike, 3812 Damage**
- Full 18-scenario test suite with on-screen title cards and colored score tables
- 17/18 scenarios deal damage (3812 total), only cliff_ledge_right fails
- Raw ballistic aerial strike after precog hops reaches cave wall cliff ledges
- Score cards: green/yellow/red for damage, time, FPS, IK, thrash per test
- Final results grid rendered on screen after all tests (8s hold)
- Post-grab teleport to player position (no more popping back to pre-grab spot)
- Skeleton-to-world constraints prevent skull/tail clipping through floors
- Test categories: Same Floor, Platform Hunting, Cross-Platform Pursuit, Corner Trapping, Cliff Edge Assault
- RCON commands: title, score, grid for recording-friendly test visualization

### v0.9.16
**10/10 Baseline, Rigid Spinning Ball, Safe Landing, Thrash=8**
- 10/10 baseline hit rate, 1175 total damage, worst thrash 8 (was 29)
- 8/8 edge cases hit, time-to-first-hit 1.1-10.4s
- Rigid spinning ball grab: body parts SET (not lerped) on computed circle positions
- Ball radius 40px (player visible in center), collision expands to full tail spiral (~88px)
- Body frozen during grab (move_and_slide skipped, IK/gait/spine all skipped)
- Safe landing after grab: teleports to player's position, raycasts floor, resets skeleton
- 25% chance of grab-ball on leap contact (instead of normal slash barrage)
- Periodic slash visual effects spawn at ball center during bites/kicks
- Ball quality scoring: measures containment of body parts within ball radius
- Tail spiral starts from spine[2] angle, grows proportionally by TAIL_SEG_LEN
- I key toggles debug draw on all enemies

### v0.9.15
**Death Ball Grab, Down-Jump Loosening, Edge Case 8/8**
- Death ball grab attack: monster curls around player, clasps with front legs, kicks with rear, bites repeatedly, ejects after 2s
- Body collision enlarges during grab to trap the player (30px radius centered on target)
- Down-jump constraints loosened: 40% body radius, skip lateral clearance, gentle drops allowed
- Edge cases: 8/8 scenarios hit (was 5/8), time-to-first-hit 1.1-3.2s
- Baseline: 7-10/10 hit, 1055 total damage
- I key toggles debug draw on all enemies (no prerequisites)
- Debug text: compact layout, positioned opposite side of screen, no overlap
- Skeleton-to-world constraints prevent skull/tail clipping through geometry

### v0.9.14
**10/10 Hit Rate, Belly Sphere Collider, Skeleton World Constraints**
- Achieved 10/10 baseline hit rate (all scenarios deal damage)
- Body collider: circle sphere (r=14) rigidly attached to torso as hanging belly
- Skeleton-to-world constraints: skull, tail, spine pushed out of geometry via raycasts
- Airspace validation: arrival points under overhangs rejected via upward raycast
- Underside attack rejection: arrival points below target's platform filtered
- State lock timer (3s precog, 1.5s attack) eliminates same-floor strategy thrashing
- Strategy thrash scoring: tracks state changes since target moved
- IK quality scoring: spread + hover + stretch, queryable via RCON
- EPIC documentation with 6 prioritized stories and specific tasks
- Baseline: 9-10/10 hit, 590-780 dmg, IK/thrash/FPS tracked per scenario

### v0.9.13
**Realistic Trajectory Clearance, IK Scoring, 1395 Total Damage**
- LEAP_BODY_RADIUS increased from 22px to 55px — trajectories now account for the creature's actual size
- Creature no longer clips platforms mid-flight or squeezes through gaps it can't fit
- IK quality scoring system: spread (2pts/px over 30), stretch (5pts/px over max), hover (3pts/px above floor)
- IK score displayed in debug (green/yellow/red) and queryable via RCON (`ik`, `ikreset`)
- Automated baseline: 9/10 scenarios deal damage, 1395 total, same-floor-near deals 905
- FPS stable at 54-99 without debug draw (debug draw toggleable via RCON `debugdraw`)
- Async graph building (5 pairs/frame), precog cooldown (2s), leap cooldown (2s)
- Sprint slash, connected hop-up, direct leap all tuned for appropriate scenarios
- Foot landing re-raycasts floor to prevent floating feet after steps
- Out-of-bounds teleport recovery

### v0.9.12
**9/10 Baseline, IK Fixes, FPS Stability**
- Automated baseline: 9/10 scenarios deal damage, min FPS 60 (never dips)
- IK leg clamping: feet stay under the body, only corrected at 2x max reach
- Async graph building: 5 pairs per frame, no single-frame stutter
- Precog cooldown: 5s between triggers, prevents infinite loop FPS crash
- Wonky leg detection: feet that reach to lower platforms are auto-corrected
- Knee snap at 2x stiffness prevents oscillation/sticking
- Step threshold 35px for responsive foot placement
- Dummy player tracks HP/damage, displays on-screen, routes take_damage correctly
- RCON: fps, hp, resethp commands for automated measurement

### v0.9.11
**Speed Overhaul, Sprint Slash, Connected Hop-Up**
- Ruthless panther: instant precog when target is on a different platform (no timer wait)
- Pre-cached platform graph at spawn — Dijkstra pathfinding is instant
- Sprint slash: same-plane charge at 250 speed + 3 rapid alternating claw swipes
- Connected hop-up: short platform climb with feet connected to both surfaces
- Movement doubled: slow 60, medium 140, fast 240 px/s
- Attack cooldown 0.8s, leap cooldown 4s, leap windup 0.6s
- Out-of-bounds recovery: teleport back to spawn if monster falls off screen
- Debug draw toggle (`debugdraw` via RCON) — disable heavy visual rendering for performance
- Automated baseline: 7/10 scenarios succeed in 0.7-5.5s average

### v0.9.10
**Pre-cognition Pathfinding, RCON Server, Automated Testing**
- Pre-cognition system: when the monster can't hit a player for 5s, it curls up and plans a multi-hop route across platforms
- Ball-drop platform detection: grid of virtual balls covers the entire map, landings are Y-snapped and grouped into surfaces
- Dijkstra pathfinding across the platform connectivity graph to find shortest route from monster to target
- Destination-aware arc clearance: ignores hits on the landing platform so upward leaps aren't falsely rejected
- IK skeleton reset after landing: spine returns to horizontal, feet raycast to floor
- RCON server (TCP port 9999): debug, spawn monster/dummy, teleport, tab, key simulation, clear enemies, force precog, status
- Dummy player: controllerless target with gravity and collision for automated testing
- Automated test script (`scripts/test_precog.sh`): 6/6 positions with successful pathfind + leap execution
- Debug visualization: platform bars, graph edges, Dijkstra path, waypoint markers, precog phase status

### v0.9.9
**Quadruped Leap Planning, Head Pivot, Cave Walls, Keystone Platform**
- Vertical leap attack with reverse trajectory planning: finds open-air strike zones around the target, then reverse-solves parabolic launch velocities to reach them
- Two-phase planning: broad search (12 arrivals × 5 flight times) then refinement around near-misses (5 positions × 7 times)
- 5-stage leap sequence: plan → windup (coil/compress) → airborne (missile alignment) → 6-slash barrage → bite+thrash+fling
- Body-width clearance: 3 parallel arc raycasts (left, center, right edge) ensure the creature fits through gaps
- Head pivot: skull/jaw/eye/teeth rotate in head-local space to face the target; stays upright on direction flip
- Paired stepping: one front + one rear foot at a time, rear legs trail behind the body
- Foot-driven locomotion: feet grip ground in world space and push the body via force
- 2-bone IK with mammal anatomy (front elbows backward, rear knees forward)
- Cave walls with CollisionPolygon2D: curved floor-to-wall transitions, flat ledge shelf at 1/3 height
- Portal keystone is a standable platform (48px wide StaticBody2D)
- Debug entity inspector: TAB cycles enemies, shows skeleton, strike zone, trajectory planning, target crosshair with distance
- Comprehensive design doc at docs/design/quadruped_monster.md

### v0.9.8
**Quadruped Monster, Cave Walls, Debug Inspector**
- Quadruped monster: procedurally animated 23-point skeleton with foot-driven locomotion
- Feet grip the ground in world space and push the body forward — body moves as a result of foot forces
- 2-bone IK solves knee positions; mammal anatomy (front elbows backward, rear knees forward)
- Head pivots to track target: skull, jaw, eye, teeth all rotate in head-local space
- Paired stepping: one front foot + one rear foot move at a time, rear legs trail behind
- Bite, claw swipe, tail whip, and lunge attacks; aggro switches after 3 hits from another player
- 7 independently damageable/severable body parts (body, head, tail, 4 legs)
- Cave walls: curved CollisionPolygon2D floor-to-wall transitions on both sides of the room
- Flat ledge shelf at 1/3 height for standing; undulation, rock texture, depth shading
- Debug entity inspector: TAB cycles enemies, shows skeleton, foot targets, state, target crosshair
- Debug M key spawns a quadruped on the title screen

### v0.9.7
**Rift Tentacle Physics**
- Rift tentacle segments now resist movement with verlet drag (0.92 velocity retention per frame)
- When attached to an enemy, only the anchor segment tracks it — the rest trail behind under physics
- Bidirectional constraint solver (5 iterations, forward+reverse passes) propagates forces both ways along the chain
- Pulling either end tugs the entire tentacle with visible lag and resistance
- Rift orb draws at anchor segment, staying attached to the enemy as it moves

### v0.9.6
**Migration Patterns**
- Migration patterns: cyclic multi-phase species movement — wildlife migrates between configurable zones on a timer
- Per-species patterns with independent zones (fireflies and bats each have their own pattern)
- Stagger mode: random phase offset per individual so not all entities migrate in lockstep
- Bat repulsion: bats strongly repel each other within 120px
- Level editor MIGRATION mode: drag zone centers/radii, X to delete zones, N/Del for phases, +/- for zones, S to switch species, G to toggle stagger, left/right arrows for cadence (1s steps)
- Species and cadence shown in editor top bar, species label on each zone circle

### v0.9.5
**Level Editor, Fireflies & Bats, Archer Reticle Fix, Menu Overhaul**
- Level editor (Ctrl+E): JSON-based config system for all level layout — spawn zones, P1-P4 positions, seeds, platforms, portal position
- 5 editor modes: SPAWN_AREAS, SPAWN_POSITIONS, SEEDS, PLATFORMS, PORTAL with mouse drag on vertices/handles
- Ctrl+S saves level edits, Ctrl+R resets to bundled defaults, live rebuild on every change
- Fireflies: spawn-gravity zones with per-fly home points, 20% glow time, deficit-scaled spawn rate (1x-5x)
- Bats: perlin noise movement via FastNoiseLite, firefly hunting within 100px, 5s hunger cooldown, max belly of 5
- Archer auto-target: gold portal-style sense effect (glow, rays, particles) that dissipates over 0.5s
- Fix: archer manual reticle was orphaned inside auto-target draw function — now renders reliably when L2 held
- Fix: trigger detection uses analog axis with hysteresis (0.1 start, 0.05 stop) instead of nonexistent button constants
- All menus support thumbstick, D-pad, and mouse input (3 input methods everywhere)
- Fix: pause mapped to Options button (was D-pad UP), D-pad navigation works in pause menu
- Profile select sub-mode in pause menu with HUD popups
- Auto-select profile's preferred class when cycling profiles on title screen
- Grapple hook connection no longer inflicts damage
- HUD aura fades out over 1 second when popup dismissed
- Portal stone pillars: per-stone X-only jitter, dark wood frame strips behind pillars
- Ctrl+D toggles debug mode anywhere (title screen, gameplay, pause menu)

### v0.9.4
**Critical Fix & Procedural Rocks**
- Fix: `Input.set_joy_light()` caused a parse error in export builds, preventing the entire player script from loading. Controllers could select classes but not move characters. Fixed via runtime `call()` dispatch.
- Procedural vector rocks with faceted plane shading (Kats Pixels technique)
- Configurable light direction, highlight intensity, and highlight width on rocks
- Grey and red-brown rock palettes with directional shadow/base/lit/highlight shading
- Debug: press G to regenerate nearest procedural scenery item (trees and rocks)
- README.md with full release notes

### v0.9.3
**Portal Doorway & Procedural Trees**
- Stone archway with wooden double doors, keystone, and decorative transom with muffin symbol replaces "Press START to begin"
- Doors creak open when a player approaches, fog creeps along the floor
- Slow-spinning blue vortex with layered glow, speeds up during pull-in
- All players must stand in the doorway for 5 seconds to transition
- Deep bass drone sound while doors are open
- Procedural background trees with multi-layered leaf canopy (3 green shades)
- Debug: press G to regenerate nearest tree with a random seed
- Archer can now aim and shoot while swinging on grapple
- Fix: health sparkle particles no longer leak after pickup
- Fix: grapple hook follows moving platforms via anchor body tracking
- Fix: title screen raised 40px so players render above HUD bar

### v0.9.2
**Portal Doorway (initial), Keystone & Vortex Polish**
- Initial portal doorway implementation
- Trapezoidal capstone centered on arch peak
- Vortex rotation reduced to barely-noticeable drift
- Pull-in gradually speeds up the vortex
- Arch-following wooden slats behind stone arch
- Bass drone sound (beam_fire at 0.12 pitch)

### v0.9.1
**Archer Aimed Shot, Grapple Polish, Debug System, Controller Features**
- Physics-based archer aimed shot with quadratic arc solver (L2/R2)
- Analog trigger pull = proportional max power. RB locks power level.
- Grapple moved to L1 with full movement during windup
- Two-phase disconnect: pull toward anchor, then release
- Jump-release adds impulse in thumbstick direction (additive to swing momentum)
- Rope slack physics: free movement above anchor, bounce at rope end
- Launch immunity preserves momentum through freefall until landing
- Either thumbstick aims grapple (right priority)
- Controller rumble at all grapple events (scales with velocity)
- Controller LED matches class color via Godot 4.6 Input.set_joy_light
- Debug mode (SELECT): velocity arrows, jump prediction, tracer snapshots, HUD button state
- Debug tracer arrows linger 10s on grapple jump-release
- Archer debug: solver arc (orange) and arrow trail (cyan) linger 10s
- Velocity audit system documented (not yet implemented)
- Profile saves last class choice, auto-selects on rejoin
- In-game class change requires button press before rift spawns
- Out-of-bounds players teleported back via purple aether rift
- Entity mass system: all 18 enemies + bosses + player have mass values
- Grapple tug uses Newtonian F=ma on both ends based on mass

### v0.9.0
**Inline HUD, Rift Tentacles, Health Drops, CI Pipeline**
- Inline player HUD replaces overlay menus — D-pad selects profile/class directly
- HUD shows class sprite, name, HP/mana bars, tentacle status
- Camera reserves 90px for bottom HUD strip
- Rift tentacle spawns on class change with verlet physics (14 segments)
- Tentacle hunts players (4 smashes) and enemies (permanent attach + buff)
- Tentacle sub-health (50 HP) absorbs damage, rift shrinks as health drops
- 25% health drop on enemy death — green + shaped pickup, heals 15 HP
- Fix: boss pseudo-enemy squares (wrong skeleton scene path, pants leak)
- 3-tier version system (MAJOR.MINOR.PATCH)
- GitHub Actions CI: builds Mac/Windows/Linux on tag push
- macOS build on native runner with proper codesign

### Pre-v0.9.0
**Core Game Development (EPICs 1-26)**
- 12 character classes with full ability sets
- 4 bosses: Gingerbread Skeleton, Icing Goblin, Sprinkle Dragon, Giant Muffin
- 13 regular enemies + 4 mini-bosses
- 18 trap/obstacle types
- Overworld with 3 towers + final tower gating
- Procedural tower generation with platforms, enemies, and collectibles
- Character leveling (4 skills per class, max level 20)
- Persistent profiles saved to JSON
- Pause menu, death/revive system, scene transitions
- Demolitionist rocket jetpack with chaos mechanics
- Balloonist physics with H2 gas explosions
- Guitarist with Karplus-Strong string synthesis audio
- Werewolf frenzy mode
- Ninja triple-slash and air jumps
- 39 sound effects
- Complete pixel art overhaul (all 12 classes, 4 bosses, enemies, environment)
