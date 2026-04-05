extends Node

## MusicManager — Procedural adaptive music powered by GDSiON.
##
## Layers MML sequences on top of a streaming SiON driver. Game events
## (combat start, boss phase, player damage, monster leaps) drive an
## intensity value that cross-fades between calm and intense pattern
## variants. Individual layers (drums, bass, melody, pad) can be
## enabled/disabled independently.
##
## All GDSiON types are accessed dynamically (Variant) so the script
## compiles even if the GDExtension is not loaded. The driver is created
## via ClassDB.instantiate() at runtime.
##
## RCON commands (registered in rcon.gd):
##   music                — show status
##   music play           — start music
##   music stop           — stop all music
##   music intensity <f>  — set intensity 0.0–1.0
##   music tempo <bpm>    — change BPM
##   music layer <name> [on|off] — toggle layer
##   music mute           — mute all layers
##   music unmute         — unmute all layers
##   music test           — play a quick test tone

# -- Signals -------------------------------------------------------------------

signal intensity_changed(value: float)
signal layer_changed(layer_name: String, active: bool)

# -- Constants -----------------------------------------------------------------

## How quickly intensity decays per second when no events push it up
const INTENSITY_DECAY_RATE := 0.02

# -- Audio Effects Bus ---------------------------------------------------------
# Post-processing effects applied via Godot AudioBus, matching Strudel controls.
# Reverb/delay are bus-level (same as Strudel's orbit-shared sends).
# Filter/distortion are bus-level approximations of Strudel's per-note chains.
const MUSIC_BUS_NAME := "Music"
const FX_IDX_LPF := 0       ## AudioEffectLowPassFilter
const FX_IDX_HPF := 1       ## AudioEffectHighPassFilter
const FX_IDX_DISTORT := 2   ## AudioEffectDistortion (also handles crush)
const FX_IDX_REVERB := 3    ## AudioEffectReverb
const FX_IDX_DELAY := 4     ## AudioEffectDelay
const FX_IDX_PAN := 5       ## AudioEffectPanner
const FX_SLOT_COUNT := 6
## Minimum intensity to activate bass layer
const BASS_THRESHOLD := 0.25
## Minimum intensity to activate drum layer
const DRUMS_THRESHOLD := 0.45
## Minimum intensity to activate melody layer
const MELODY_THRESHOLD := 0.65
## BPM range
const BPM_MIN := 70
const BPM_MAX := 160
const BPM_DEFAULT := 90

# -- State ---------------------------------------------------------------------

## SiONDriver instance (Variant to avoid parse-time type dependency)
var driver: Variant = null
## SiONVoicePresetUtil instance
var presets: Variant = null
## Whether GDSiON extension is available
var gdsion_available: bool = false
## Version string (set at init)
var _version_str: String = ""

var is_playing: bool = false
var is_muted: bool = false

## Current musical intensity: 0.0 = ambient, 1.0 = peak combat
var intensity: float = 0.0
## Target intensity (smoothed toward)
var _target_intensity: float = 0.0

var _bpm: int = BPM_DEFAULT

## Layer definitions: name → LayerState
var _layers: Dictionary = {}

## Voices (resolved from presets after driver init): name → SiONVoice
var _voices: Dictionary = {}

## Track ID allocation counter (GDSiON tracks)
var _next_track_id: int = 10

## Audio effects bus index (-1 = not set up yet)
var _music_bus_idx: int = -1
## Effect instances (stored for runtime parameter tweaking)
var _fx_lpf: Variant = null           ## AudioEffectLowPassFilter
var _fx_hpf: Variant = null           ## AudioEffectHighPassFilter
var _fx_distort: Variant = null       ## AudioEffectDistortion
var _fx_reverb: Variant = null        ## AudioEffectReverb
var _fx_delay: Variant = null         ## AudioEffectDelay
var _fx_pan: Variant = null           ## AudioEffectPanner
## Currently active effect controls (for status display)
var _active_controls: Dictionary = {}
## Audio recorder effect for capture/analysis
var _fx_recorder: Variant = null

## Future: Strudel signal modulation (sine.range, saw.range, etc.)
## Requires JS expression subset to parse .lpf(sine.range(200, 2000))
## Signals exist in strudel_signal.gd but aren't parseable from drawer text yet.

# -- Strudel Engine ------------------------------------------------------------

## The Strudel cyclist (pattern scheduler)
var _cyclist: StrudelCyclist = null
## The SiON trigger bridge
var _sion_trigger: StrudelSionTrigger = null
## Current strudel pattern being played
var _strudel_pattern: StrudelPattern = null
var _strudel_source_text: String = ""  ## Mini-notation text that produced the current pattern
## Elapsed time for the clock (seconds since start)
var _strudel_time: float = 0.0
## Whether strudel engine is active
var _strudel_playing: bool = false

# -- Layer State ---------------------------------------------------------------

class LayerState:
	var name: String = ""
	var enabled: bool = true        ## User toggle — can this layer play?
	var active: bool = false         ## Currently producing sound?
	var track_ids: Array[int] = []   ## SiON track IDs in use
	var threshold: float = 0.0      ## Intensity threshold to activate
	var variants: Array[String] = [] ## MML strings, indexed by intensity tier
	var current_variant: int = -1    ## Which variant is currently playing
	var voice_preset: String = ""    ## Voice preset key

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Defer driver creation to avoid issues during autoload init
	call_deferred("_init_driver")
	# Connect game events once the tree is ready
	get_tree().process_frame.connect(_try_connect_game_events, CONNECT_ONE_SHOT)


func _try_connect_game_events() -> void:
	_connect_game_events()


func _init_driver() -> void:
	# Check if SiONDriver class exists (GDSiON loaded successfully)
	if not ClassDB.class_exists(&"SiONDriver"):
		push_warning("MusicManager: GDSiON not available — music disabled")
		print("MUSIC: GDSiON extension not found. Music system disabled.")
		return

	gdsion_available = true

	# Create driver via dynamic GDScript to call static factory SiONDriver.create()
	# We use a runtime-compiled GDScript to avoid parse-time type references.
	var bridge: GDScript = GDScript.new()
	bridge.source_code = """extends RefCounted

func create_driver():
	return SiONDriver.create()

func get_ver():
	return SiONDriver.get_version()

func get_flavor():
	return SiONDriver.get_version_flavor()

func gen_presets():
	return SiONVoicePresetUtil.generate_voices()
"""
	var compile_err := bridge.reload()
	if compile_err != OK:
		push_warning("MusicManager: bridge script compile failed (err=%d)" % compile_err)
		print("MUSIC: Bridge compile failed — GDSiON types not resolving.")
		return

	var helper: Variant = bridge.new()
	driver = helper.create_driver()
	if not driver:
		push_warning("MusicManager: SiONDriver.create() returned null")
		print("MUSIC: SiONDriver.create() returned null.")
		return

	add_child(driver)

	var version: String = str(helper.get_ver())
	var flavor: String = str(helper.get_flavor())
	_version_str = "v%s-%s" % [version, flavor]
	print("MUSIC: SiON driver created (%s)" % _version_str)

	# Generate voice presets
	presets = helper.gen_presets()
	if not presets:
		push_warning("MusicManager: failed to generate voice presets")
		presets = null

	# Load score library
	_load_scores()

	# Set up voices for each layer type
	_setup_voices()

	# Define layers
	_setup_layers()

	# Connect beat callback for debug logging
	driver.call("set_beat_event_enabled", true)
	driver.connect("streaming_beat", _on_beat)
	driver.call("set_timer_interval", 4)  # fire every quarter note
	driver.connect("timer_interval", _on_timer)

	DebugOverlay.log("music/status", null, "MUSIC: driver initialized, %d layers defined", [_layers.size()])

	# Initialize the Strudel pattern engine
	_init_strudel()

	# Set up audio effects bus (post-processing for Strudel controls)
	_setup_audio_bus()

	# Auto-start Strudel pattern on the title screen
	if GameManager.current_state == GameManager.GameState.TITLE:
		_strudel_play_title()


func _setup_voices() -> void:
	if not presets:
		return

	var keys: PackedStringArray = presets.call("get_voice_preset_keys")
	var key_set: Dictionary = {}
	for k in keys:
		key_set[k] = true

	# Pad: warm atmospheric synth
	_voices["pad"] = presets.call("get_voice_preset", "midi.pad2")
	# Bass: synth bass
	_voices["bass"] = presets.call("get_voice_preset", "midi.bass7")
	# Lead/melody: saw lead
	_voices["lead"] = presets.call("get_voice_preset", "midi.lead2")
	# Chiptune square for alt melody
	if key_set.has("valsound.square1"):
		_voices["square"] = presets.call("get_voice_preset", "valsound.square1")
	else:
		_voices["square"] = presets.call("get_voice_preset", "midi.lead1")
	# Drumkit voices are handled differently (via note numbers)

	DebugOverlay.log("music/status", null, "MUSIC: %d voice presets available, %d voices configured" % [
		keys.size(), _voices.size()])


func _setup_layers() -> void:
	# -- PAD layer: always on, sets the harmonic foundation --
	var pad := LayerState.new()
	pad.name = "pad"
	pad.threshold = 0.0
	pad.voice_preset = "pad"
	pad.variants = [
		# Calm: slow whole notes, C minor ambiance
		"t%d %%6@0 o3 l1 v8 [c2.e-4g2.>c4< | c2.e-4b-2.g4]4" % BPM_DEFAULT,
		# Medium: add motion, arpeggiated
		"t%d %%6@0 o3 l4 v10 [ce-g>c< e-gb->e-< | gb->e-g< b->e-gc<]4" % BPM_DEFAULT,
		# Intense: faster movement, tension
		"t%d %%6@0 o3 l8 v12 [ce-ge-ce-g>c< e-gb-ge-gb->e-<]4" % BPM_DEFAULT,
	]
	_layers["pad"] = pad

	# -- BASS layer: kicks in at low-mid intensity --
	var bass := LayerState.new()
	bass.name = "bass"
	bass.threshold = BASS_THRESHOLD
	bass.voice_preset = "bass"
	bass.variants = [
		# Sparse: root notes on downbeats with rests
		"t%d %%6@0 o2 l4 v10 [c4.r8c4r4 | e-4.r8e-4r4 | g4.r8g4r4 | e-4.r8c4r4]2" % BPM_DEFAULT,
		# Driving: eighth-note pulse with chord changes
		"t%d %%6@0 o2 l8 v12 [cccccccc | e-e-e-e-e-e-e-e- | gggggggg | e-e-e-e-cccc]2" % BPM_DEFAULT,
		# Aggressive: syncopated with octave jumps
		"t%d %%6@0 o2 l16 v14 [ccrc>c<rccrc>c<rcc | e-e-r>e-<e-rccr>c<rcc]2" % BPM_DEFAULT,
	]
	_layers["bass"] = bass

	# -- DRUMS layer: mid intensity, rhythmic drive --
	# Uses voice type 1 (percussion). Note values map to different drum sounds.
	var drums := LayerState.new()
	drums.name = "drums"
	drums.threshold = DRUMS_THRESHOLD
	drums.voice_preset = ""  # Drums use a different mechanism
	drums.variants = [
		# Steady groove: kick-hat-snare-hat pattern
		"t%d %%6@1 l16 v12 [crcrdrcrcrcrdrcc | crcrdrcrcccrdrcc]4" % BPM_DEFAULT,
		# Aggressive: syncopated kicks with double-time hats
		"t%d %%6@1 l16 v14 [crccdrcccrccdcrc | ccrcdrcccrccdrcc]4" % BPM_DEFAULT,
	]
	_layers["drums"] = drums

	# -- MELODY layer: high intensity, gives the peak moments a theme --
	var melody := LayerState.new()
	melody.name = "melody"
	melody.threshold = MELODY_THRESHOLD
	melody.voice_preset = "lead"
	melody.variants = [
		# Simple motif in C minor
		"t%d %%6@0 o4 l8 v10 [ce-gge-c4. | e-gb->e-<b-g4.]4" % BPM_DEFAULT,
		# Intense: faster, wider range
		"t%d %%6@0 o4 l16 v12 [ce-ge->c<b-ge- ce-ge->e-c<b-g | e->ce-g b-ge-c< ge->ce-< gb-ge-]2" % BPM_DEFAULT,
	]
	_layers["melody"] = melody


var _fx_reconcile_timer: float = 0.0  ## Throttle reconciliation checks

func _process(delta: float) -> void:
	# Advance Strudel clock regardless of MML layer state
	if _strudel_playing and _cyclist != null:
		_strudel_time += delta
		_cyclist.process()

	# Process deferred note queue — fires notes at their correct wall-clock time
	if _sion_trigger:
		_sion_trigger.process()

	# Periodic reconciliation: verify bus effects match desired state.
	# Catches external changes, driver resets, or state that drifted.
	# Runs every 0.5s to avoid per-frame AudioServer overhead.
	if _music_bus_idx >= 0 and not _active_controls.is_empty():
		_fx_reconcile_timer += delta
		if _fx_reconcile_timer >= 0.5:
			_fx_reconcile_timer = 0.0
			_reconcile_effects()

	if not driver or not is_playing:
		return

	# Smooth intensity toward target
	if intensity != _target_intensity:
		var diff: float = _target_intensity - intensity
		var step: float = delta * 2.0  # 0.5 second smoothing
		if absf(diff) < step:
			intensity = _target_intensity
		else:
			intensity += signf(diff) * step
		intensity_changed.emit(intensity)

	# Natural decay of target intensity
	if _target_intensity > 0.0:
		_target_intensity = maxf(0.0, _target_intensity - INTENSITY_DECAY_RATE * delta)

	# Update layers based on intensity
	_update_layers()


# -- Layer Management ----------------------------------------------------------

func _update_layers() -> void:
	for layer_name in _layers:
		var layer: LayerState = _layers[layer_name]
		var should_be_active: bool = layer.enabled and not is_muted and intensity >= layer.threshold
		var target_variant: int = _get_variant_for_intensity(layer, intensity)

		if should_be_active and not layer.active:
			_activate_layer(layer, target_variant)
		elif not should_be_active and layer.active:
			_deactivate_layer(layer)
		elif should_be_active and layer.active and target_variant != layer.current_variant:
			# Switch variant: stop current, start new
			_deactivate_layer(layer)
			_activate_layer(layer, target_variant)


func _get_variant_for_intensity(layer: LayerState, intens: float) -> int:
	if layer.variants.is_empty():
		return -1
	# Map intensity above threshold to variant index
	var range_above: float = intens - layer.threshold
	var range_total: float = 1.0 - layer.threshold
	if range_total <= 0.0:
		return 0
	var frac: float = clampf(range_above / range_total, 0.0, 0.999)
	return mini(int(frac * layer.variants.size()), layer.variants.size() - 1)


func _activate_layer(layer: LayerState, variant_idx: int) -> void:
	if variant_idx < 0 or variant_idx >= layer.variants.size():
		return
	if not driver:
		return

	var mml: String = layer.variants[variant_idx]
	# Update tempo in MML string
	mml = _update_mml_tempo(mml, _bpm)

	var data: Variant = driver.call("compile", mml)
	if not data:
		push_warning("MusicManager: failed to compile MML for layer '%s'" % layer.name)
		return

	var track_id: int = _next_track_id
	_next_track_id += 1

	# Get voice for this layer (may be null for drumkits)
	var voice: Variant = _voices.get(layer.voice_preset)

	driver.call("sequence_on", data, voice, 0, 0, 0, track_id)

	layer.track_ids.append(track_id)
	layer.active = true
	layer.current_variant = variant_idx

	DebugOverlay.log("music/layers", null, "MUSIC: layer '%s' ON (variant=%d, track=%d)" % [
		layer.name, variant_idx, track_id])
	layer_changed.emit(layer.name, true)


func _deactivate_layer(layer: LayerState) -> void:
	for tid in layer.track_ids:
		driver.call("sequence_off", tid, 0, 0, true)
	layer.track_ids.clear()
	layer.active = false
	layer.current_variant = -1

	DebugOverlay.log("music/layers", null, "MUSIC: layer '%s' OFF" % layer.name)
	layer_changed.emit(layer.name, false)


func _update_mml_tempo(mml: String, bpm: int) -> String:
	## Replace the tempo command in an MML string.
	var regex := RegEx.new()
	regex.compile("t\\d+")
	return regex.sub(mml, "t%d" % bpm)


# -- Public API ----------------------------------------------------------------

func play() -> void:
	if not driver:
		print("MUSIC: Cannot play — driver not initialized")
		return
	if is_playing:
		return

	# Stop title music if it was playing
	stop_title_music()

	driver.call("set_bpm", _bpm)
	driver.call("stream", false)
	is_playing = true

	# Start pad layer immediately (threshold = 0)
	_update_layers()

	DebugOverlay.log("music/status", null, "MUSIC: playback started (bpm=%d)", [_bpm])
	print("MUSIC: playback started at %d BPM" % _bpm)


func stop() -> void:
	if not driver:
		return
	# Deactivate all layers
	for layer_name in _layers:
		var layer: LayerState = _layers[layer_name]
		if layer.active:
			_deactivate_layer(layer)
	driver.call("stop")
	is_playing = false
	intensity = 0.0
	_target_intensity = 0.0
	DebugOverlay.log("music/status", null, "MUSIC: playback stopped")
	print("MUSIC: playback stopped")


func set_intensity(value: float) -> void:
	_target_intensity = clampf(value, 0.0, 1.0)
	DebugOverlay.log("music/events", null, "MUSIC: intensity → %.2f", [_target_intensity])


func push_intensity(amount: float) -> void:
	## Add to current target intensity (clamped). Used by game events.
	_target_intensity = clampf(_target_intensity + amount, 0.0, 1.0)
	DebugOverlay.log("music/events", null, "MUSIC: intensity push +%.2f → %.2f", [
		amount, _target_intensity])


func set_tempo(bpm: int) -> void:
	_bpm = clampi(bpm, BPM_MIN, BPM_MAX)
	if driver and is_playing:
		driver.call("set_bpm", _bpm)
		# Restart active layers with new tempo
		_restart_active_layers()
	DebugOverlay.log("music/status", null, "MUSIC: tempo → %d BPM", [_bpm])


func set_layer_enabled(layer_name: String, enabled: bool) -> void:
	if not _layers.has(layer_name):
		return
	var layer: LayerState = _layers[layer_name]
	layer.enabled = enabled
	if not enabled and layer.active:
		_deactivate_layer(layer)


func mute() -> void:
	is_muted = true
	for layer_name in _layers:
		var layer: LayerState = _layers[layer_name]
		if layer.active:
			_deactivate_layer(layer)


func unmute() -> void:
	is_muted = false
	_update_layers()


func _restart_active_layers() -> void:
	## Re-activate all currently active layers (e.g. after tempo change).
	var to_restart: Array[String] = []
	for layer_name in _layers:
		var layer: LayerState = _layers[layer_name]
		if layer.active:
			to_restart.append(layer_name)
	for layer_name in to_restart:
		var layer: LayerState = _layers[layer_name]
		var variant: int = layer.current_variant
		_deactivate_layer(layer)
		_activate_layer(layer, variant)


func play_test_tone() -> void:
	## Quick verification that GDSiON is working.
	if not driver:
		print("MUSIC: Cannot test — driver not initialized")
		return
	# Stop strudel first — play(mml) conflicts with stream mode
	strudel_stop()
	_sion_streaming = false
	driver.call("play", "t120 l8 [ccggaag4 ffeeddc4]")
	print("MUSIC: test tone playing")


func test_sequence_on() -> String:
	## Diagnostic: test sequence_on in streaming mode.
	if not driver:
		return "ERR: no driver"
	# Ensure streaming
	driver.call("stop")
	driver.call("stream", false)
	_sion_streaming = true
	driver.call("set_bpm", 120)
	# Compile
	var mml := "t120 l4 [o4 c e g >c<]8"
	var data: Variant = driver.call("compile", mml)
	if not data:
		return "ERR: compile returned null for '%s'" % mml
	# Try with a real voice (the layer system always passes one)
	var voice: Variant = _voices.get("pad")
	print("MUSIC: test_sequence_on — voice=%s, data=%s" % [str(voice).substr(0, 30), str(data).substr(0, 30)])
	driver.call("sequence_on", data, voice, 0, 0, 0, 50)
	print("MUSIC: test_sequence_on — track 50 started, mml='%s'" % mml)
	return "OK: sequence_on track=50 voice=pad, mml='%s' — listen for C-E-G-C5" % mml


## Play an arbitrary MML string directly on the driver.
## Stops any current playback (layered, strudel, title) first.
func play_mml(mml: String) -> void:
	if not driver:
		print("MUSIC: Cannot play MML — driver not initialized")
		return
	strudel_stop()
	_sion_streaming = false
	if is_playing:
		stop()
	stop_title_music()
	driver.call("play", mml)
	print("MUSIC: playing custom MML (%d chars)" % mml.length())


## Stop any direct MML playback.
func stop_direct() -> void:
	if not driver:
		return
	driver.call("stop")
	_title_playing = false
	print("MUSIC: direct playback stopped")


# -- Named Scores -------------------------------------------------------------
# Loaded from data/music/scores.json — complex multi-track MML arrangements
# from the SiON MML community library (mmltalks). Original authors credited
# in the JSON metadata. Scores can be played via RCON: music score <name>

const SCORES_PATH := "res://data/music/scores.json"

## Simple built-in scores (always available, no file dependency)
const BUILTIN_SCORES := {
	"test": "t120 l8 [ccggaag4 ffeeddc4 | [ggffeed4]2 ]2",
}

## Loaded scores: name → {title, source, author, mood, mml}
var _loaded_scores: Dictionary = {}
## Flat name→mml lookup (builtins + loaded)
var _all_scores: Dictionary = {}


func _load_scores() -> void:
	## Load score library from JSON.
	_all_scores = BUILTIN_SCORES.duplicate()

	if not FileAccess.file_exists(SCORES_PATH):
		print("MUSIC: no scores file at %s" % SCORES_PATH)
		return

	var file := FileAccess.open(SCORES_PATH, FileAccess.READ)
	if not file:
		push_warning("MusicManager: failed to open %s" % SCORES_PATH)
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("MusicManager: failed to parse %s" % SCORES_PATH)
		return

	_loaded_scores = json.data
	for key in _loaded_scores:
		var entry: Dictionary = _loaded_scores[key]
		_all_scores[key] = entry.get("mml", "")

	print("MUSIC: loaded %d scores from %s" % [_loaded_scores.size(), SCORES_PATH])


# -- Audio Effects Bus ---------------------------------------------------------

func _setup_audio_bus() -> void:
	## Create a dedicated Music AudioBus with post-processing effect slots.
	## All effects start disabled. Controls like lpf(), room(), delay() enable them.

	# Check if "Music" bus already exists (e.g. from project settings)
	var existing_idx: int = AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if existing_idx >= 0:
		_music_bus_idx = existing_idx
	else:
		_music_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_music_bus_idx)
		AudioServer.set_bus_name(_music_bus_idx, MUSIC_BUS_NAME)
	# Route Music bus to Master
	AudioServer.set_bus_send(_music_bus_idx, &"Master")

	# Route the SiON driver to the Music bus.
	# SiONDriver extends AudioStreamPlayer, so it should have a "bus" property.
	if driver:
		var has_bus: bool = "bus" in driver
		if has_bus:
			driver.set("bus", MUSIC_BUS_NAME)
			DebugOverlay.log("music/effects", null, "MUSIC_FX: SiON routed to '%s' bus", [MUSIC_BUS_NAME])
		else:
			# Fallback: add effects to Master bus instead
			_music_bus_idx = 0
			DebugOverlay.log("music/effects", null, "MUSIC_FX: SiON has no bus property — effects on Master")
			print("MUSIC_FX: Warning — SiON driver lacks bus property, using Master bus")

	# Clear any existing effects on our bus (idempotent setup)
	while AudioServer.get_bus_effect_count(_music_bus_idx) > 0:
		AudioServer.remove_bus_effect(_music_bus_idx, 0)

	# Slot 0: Low-pass filter
	_fx_lpf = AudioEffectLowPassFilter.new()
	_fx_lpf.cutoff_hz = 20500.0   # Wide open = no audible filtering
	_fx_lpf.resonance = 0.5
	AudioServer.add_bus_effect(_music_bus_idx, _fx_lpf)
	AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_LPF, false)

	# Slot 1: High-pass filter
	_fx_hpf = AudioEffectHighPassFilter.new()
	_fx_hpf.cutoff_hz = 10.0      # Near DC = no audible filtering
	_fx_hpf.resonance = 0.5
	AudioServer.add_bus_effect(_music_bus_idx, _fx_hpf)
	AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_HPF, false)

	# Slot 2: Distortion (also handles crush via lofi mode)
	_fx_distort = AudioEffectDistortion.new()
	_fx_distort.mode = AudioEffectDistortion.MODE_CLIP
	_fx_distort.drive = 0.0
	_fx_distort.pre_gain = 0.0
	_fx_distort.post_gain = 0.0
	_fx_distort.keep_hf_hz = 16000.0
	AudioServer.add_bus_effect(_music_bus_idx, _fx_distort)
	AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_DISTORT, false)

	# Slot 3: Reverb
	_fx_reverb = AudioEffectReverb.new()
	_fx_reverb.room_size = 0.8
	_fx_reverb.damping = 0.5
	_fx_reverb.wet = 0.5
	_fx_reverb.dry = 1.0
	_fx_reverb.spread = 1.0
	_fx_reverb.hipass = 0.0
	AudioServer.add_bus_effect(_music_bus_idx, _fx_reverb)
	AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_REVERB, false)

	# Slot 4: Delay
	_fx_delay = AudioEffectDelay.new()
	_fx_delay.dry = 1.0
	_fx_delay.set("tap1/active", true)
	_fx_delay.set("tap1/delay_ms", 250.0)
	_fx_delay.set("tap1/level_db", -6.0)
	_fx_delay.set("tap1/pan", 0.2)
	_fx_delay.set("tap2/active", true)
	_fx_delay.set("tap2/delay_ms", 500.0)
	_fx_delay.set("tap2/level_db", -12.0)
	_fx_delay.set("tap2/pan", -0.2)
	_fx_delay.set("feedback/active", true)
	_fx_delay.set("feedback/delay_ms", 375.0)
	_fx_delay.set("feedback/level_db", -18.0)
	AudioServer.add_bus_effect(_music_bus_idx, _fx_delay)
	AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_DELAY, false)

	# Slot 5: Pan
	_fx_pan = AudioEffectPanner.new()
	_fx_pan.pan = 0.0
	AudioServer.add_bus_effect(_music_bus_idx, _fx_pan)
	AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_PAN, false)

	# Slot 6: Recorder (for audio capture/analysis)
	_fx_recorder = AudioEffectRecord.new()
	AudioServer.add_bus_effect(_music_bus_idx, _fx_recorder)
	AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_SLOT_COUNT, true)

	print("MUSIC_FX: Audio effects bus '%s' set up (%d slots + recorder)" % [
		AudioServer.get_bus_name(_music_bus_idx), FX_SLOT_COUNT])
	DebugOverlay.log("music/effects", null, "MUSIC_FX: bus '%s' ready (idx=%d)", [
		AudioServer.get_bus_name(_music_bus_idx), _music_bus_idx])


func set_music_effects(controls: Dictionary) -> void:
	## Apply Strudel-compatible audio controls to the Music bus effects.
	## Supported keys: lpf, hpf, lpq, hpq, room, roomsize, delay, delaytime,
	## delayfeedback, distort, crush, pan, shape.
	## Call with empty dict or reset_music_effects() to disable all.
	if _music_bus_idx < 0:
		return

	_active_controls = controls.duplicate()

	# -- Low-pass filter --
	if controls.has("lpf"):
		var cutoff: float = clampf(float(controls["lpf"]), 20.0, 20500.0)
		_fx_lpf.cutoff_hz = cutoff
		if controls.has("lpq"):
			_fx_lpf.resonance = clampf(float(controls["lpq"]), 0.0, 4.0)
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_LPF, true)
		DebugOverlay.log("music/effects", null, "MUSIC_FX: lpf=%.0f q=%.2f", [cutoff, _fx_lpf.resonance])
	else:
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_LPF, false)

	# -- High-pass filter --
	if controls.has("hpf"):
		var cutoff: float = clampf(float(controls["hpf"]), 10.0, 20500.0)
		_fx_hpf.cutoff_hz = cutoff
		if controls.has("hpq"):
			_fx_hpf.resonance = clampf(float(controls["hpq"]), 0.0, 4.0)
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_HPF, true)
		DebugOverlay.log("music/effects", null, "MUSIC_FX: hpf=%.0f q=%.2f", [cutoff, _fx_hpf.resonance])
	else:
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_HPF, false)

	# -- Distortion / Crush --
	if controls.has("distort") or controls.has("crush") or controls.has("shape"):
		if controls.has("crush"):
			# Bit crush → lofi distortion mode
			_fx_distort.mode = AudioEffectDistortion.MODE_LOFI
			var crush: float = clampf(float(controls["crush"]), 1.0, 16.0)
			# Map crush 1-16 to drive 0-1 (lower crush = more distortion)
			_fx_distort.drive = clampf(1.0 - (crush - 1.0) / 15.0, 0.0, 1.0)
		elif controls.has("shape"):
			_fx_distort.mode = AudioEffectDistortion.MODE_WAVESHAPE
			_fx_distort.drive = clampf(float(controls["shape"]), 0.0, 1.0)
		else:
			_fx_distort.mode = AudioEffectDistortion.MODE_CLIP
			_fx_distort.drive = clampf(float(controls["distort"]), 0.0, 1.0)
		_fx_distort.pre_gain = 6.0 if _fx_distort.drive > 0.3 else 0.0
		_fx_distort.post_gain = -3.0 if _fx_distort.drive > 0.3 else 0.0
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_DISTORT, true)
		DebugOverlay.log("music/effects", null, "MUSIC_FX: distort mode=%d drive=%.2f", [
			_fx_distort.mode, _fx_distort.drive])
	else:
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_DISTORT, false)

	# -- Reverb --
	if controls.has("room"):
		var wet: float = clampf(float(controls["room"]), 0.0, 1.0)
		_fx_reverb.wet = wet
		_fx_reverb.dry = 1.0 - wet * 0.3  # Keep dry signal strong
		if controls.has("roomsize"):
			_fx_reverb.room_size = clampf(float(controls["roomsize"]), 0.0, 1.0)
		else:
			_fx_reverb.room_size = 0.8
		if controls.has("roomlp"):
			_fx_reverb.hipass = clampf(1.0 - float(controls["roomlp"]), 0.0, 1.0)
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_REVERB, true)
		DebugOverlay.log("music/effects", null, "MUSIC_FX: room=%.2f size=%.2f", [wet, _fx_reverb.room_size])
	else:
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_REVERB, false)

	# -- Delay --
	if controls.has("delay"):
		var wet: float = clampf(float(controls["delay"]), 0.0, 1.0)
		_fx_delay.dry = 1.0
		# Scale tap levels by wet amount
		_fx_delay.set("tap1/level_db", lerpf(-40.0, -3.0, wet))
		_fx_delay.set("tap2/level_db", lerpf(-40.0, -9.0, wet))
		if controls.has("delaytime"):
			var dt_ms: float = clampf(float(controls["delaytime"]) * 1000.0, 10.0, 2000.0)
			_fx_delay.set("tap1/delay_ms", dt_ms)
			_fx_delay.set("tap2/delay_ms", dt_ms * 2.0)
			_fx_delay.set("feedback/delay_ms", dt_ms * 1.5)
		if controls.has("delayfeedback"):
			var fb: float = clampf(float(controls["delayfeedback"]), 0.0, 0.95)
			_fx_delay.set("feedback/level_db", lerpf(-40.0, -3.0, fb))
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_DELAY, true)
		DebugOverlay.log("music/effects", null, "MUSIC_FX: delay=%.2f", [wet])
	else:
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_DELAY, false)

	# -- Pan --
	if controls.has("pan"):
		var pan_val: float = clampf(float(controls["pan"]), -1.0, 1.0)
		_fx_pan.pan = pan_val
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_PAN, true)
		DebugOverlay.log("music/effects", null, "MUSIC_FX: pan=%.2f", [pan_val])
	else:
		AudioServer.set_bus_effect_enabled(_music_bus_idx, FX_IDX_PAN, false)


func reset_music_effects() -> void:
	## Disable all audio effects on the Music bus.
	if _music_bus_idx < 0:
		return
	for i in range(FX_SLOT_COUNT):
		AudioServer.set_bus_effect_enabled(_music_bus_idx, i, false)
	_active_controls.clear()
	# Also clear the trigger's last-known state so it re-applies on next hap
	if _sion_trigger:
		_sion_trigger._last_fx.clear()
	DebugOverlay.log("music/effects", null, "MUSIC_FX: all effects reset")


func _reconcile_effects() -> void:
	## Verify that the AudioBus effect state matches _active_controls.
	## If something drifted (external change, driver reset), re-apply.
	## Called periodically from _process(), NOT every frame.
	if _active_controls.is_empty():
		return

	var needs_fix: bool = false

	# Spot-check: is lpf enabled if we expect it?
	if _active_controls.has("lpf"):
		if not AudioServer.is_bus_effect_enabled(_music_bus_idx, FX_IDX_LPF):
			needs_fix = true
		elif absf(_fx_lpf.cutoff_hz - float(_active_controls["lpf"])) > 1.0:
			needs_fix = true

	if _active_controls.has("room"):
		if not AudioServer.is_bus_effect_enabled(_music_bus_idx, FX_IDX_REVERB):
			needs_fix = true

	if _active_controls.has("delay"):
		if not AudioServer.is_bus_effect_enabled(_music_bus_idx, FX_IDX_DELAY):
			needs_fix = true

	if needs_fix:
		DebugOverlay.log("music/effects", null, "MUSIC_FX: reconcile — drift detected, re-applying")
		set_music_effects(_active_controls)


func record_start() -> String:
	## Start recording audio from the music bus.
	if not _fx_recorder:
		return "ERR: recorder not initialized"
	if _fx_recorder.is_recording_active():
		return "ERR: already recording"
	_fx_recorder.set_recording_active(true)
	return "OK: recording started"


func record_stop(filename: String = "recording") -> String:
	## Stop recording and save to user:// as WAV.
	if not _fx_recorder:
		return "ERR: recorder not initialized"
	if not _fx_recorder.is_recording_active():
		return "ERR: not recording"
	_fx_recorder.set_recording_active(false)
	var recording: AudioStreamWAV = _fx_recorder.get_recording()
	if not recording:
		return "ERR: no recording data"
	var path: String = "user://%s.wav" % filename
	var err: int = recording.save_to_wav(path)
	if err != OK:
		return "ERR: save failed (err=%d)" % err
	var global_path: String = ProjectSettings.globalize_path(path)
	print("MUSIC: recording saved to %s (%s)" % [path, global_path])
	return "OK: saved to %s" % global_path


func get_effects_status() -> String:
	## Return a formatted string showing active effects.
	if _music_bus_idx < 0:
		return "Effects: not initialized"
	var lines: Array[String] = ["Effects (bus='%s' idx=%d):" % [
		AudioServer.get_bus_name(_music_bus_idx), _music_bus_idx]]
	var names := ["lpf", "hpf", "distort", "reverb", "delay", "pan"]
	for i in range(FX_SLOT_COUNT):
		var enabled: bool = AudioServer.is_bus_effect_enabled(_music_bus_idx, i)
		var state: String = "ON" if enabled else "off"
		var detail: String = ""
		if enabled:
			match i:
				FX_IDX_LPF: detail = " cutoff=%.0f q=%.2f" % [_fx_lpf.cutoff_hz, _fx_lpf.resonance]
				FX_IDX_HPF: detail = " cutoff=%.0f q=%.2f" % [_fx_hpf.cutoff_hz, _fx_hpf.resonance]
				FX_IDX_DISTORT: detail = " mode=%d drive=%.2f" % [_fx_distort.mode, _fx_distort.drive]
				FX_IDX_REVERB: detail = " wet=%.2f size=%.2f" % [_fx_reverb.wet, _fx_reverb.room_size]
				FX_IDX_DELAY: detail = " tap1=%.0fms" % [_fx_delay.get("tap1/delay_ms")]
				FX_IDX_PAN: detail = " pan=%.2f" % [_fx_pan.pan]
		lines.append("  %-8s: %s%s" % [names[i], state, detail])
	return "\n".join(lines)


# -- Strudel Engine ------------------------------------------------------------

func _init_strudel() -> void:
	## Initialize the Strudel pattern engine and connect to GDSiON.
	if not driver:
		return

	_sion_trigger = StrudelSionTrigger.new(driver, presets)
	_cyclist = StrudelCyclist.new(
		_sion_trigger.trigger,      # on_trigger callback (per-note mode)
		func() -> float: return _strudel_time,  # get_time
		Callable(),                 # on_toggle (unused)
		0.1,                        # latency
		0.05                        # interval
	)
	# Wire up batch mode callback
	_cyclist._on_batch_trigger = _sion_trigger.trigger_batch
	_cyclist.set_cps(0.5)  # Default: 120 BPM

	print("MUSIC: Strudel engine initialized")
	DebugOverlay.log("music/status", null, "MUSIC: Strudel engine initialized")


var _sion_streaming: bool = false  ## Track whether SiON is in streaming mode

func strudel_play(pattern: StrudelPattern, cps: float = -1.0, source_text: String = "") -> void:
	## Play a Strudel pattern. Hot-swaps if already playing.
	if not _cyclist or not driver:
		print("MUSIC: Cannot play pattern — Strudel engine not initialized")
		return

	# Stop non-strudel playback if active
	stop_title_music()
	if is_playing:
		stop()

	if cps > 0.0:
		_cyclist.set_cps(cps)

	# Hot-swap: stop cyclist and clean up old state FIRST, before starting new playback.
	if _strudel_playing:
		_cyclist.stop()
	if _sion_trigger:
		_sion_trigger.clear_pending()
		_sion_trigger._cycle_buffer_int = -1
	# Stop any current audio (batch play or streaming)
	driver.call("stop")
	_sion_streaming = false

	var is_batch: bool = _sion_trigger != null and _sion_trigger.batch_mode

	if is_batch:
		# Batch mode: compile full cycle eagerly and play via driver.play().
		# The MML embeds its own tempo (t<240*CPS>). Cyclist runs for UI sync only.
		_sion_trigger.start_batch_playback(pattern, _cyclist.cps)
	else:
		# Note mode: start streaming for per-note note_on dispatch.
		driver.call("stream", false)
		_sion_streaming = true
		var sion_bpm: float = _cyclist.cps * 120.0
		driver.call("set_bpm", int(maxf(sion_bpm, 30.0)))
	_strudel_time = 0.0
	_cyclist.set_pattern(pattern)
	_cyclist.start()
	_strudel_playing = true
	_strudel_pattern = pattern
	_strudel_source_text = source_text

	DebugOverlay.log("music/status", null, "MUSIC: Strudel playing (cps=%.2f)" % _cyclist.cps)
	print("MUSIC: Strudel pattern playing (cps=%.2f)" % _cyclist.cps)


func strudel_play_batch(tracks: Array, cps: float) -> void:
	## Play multiple tracks in batch mode — each track is compiled to its own MML.
	## tracks: Array of {pattern: StrudelPattern, voice: String, gain: float, name: String}
	if not _cyclist or not driver or not _sion_trigger:
		return

	stop_title_music()
	if is_playing:
		stop()
	_cyclist.set_cps(cps)

	# Stop old playback
	if _strudel_playing:
		_cyclist.stop()
	driver.call("stop")
	_sion_streaming = false

	# Collect signal controls from all tracks for per-note evaluation
	_sion_trigger._signal_controls.clear()
	for t in tracks:
		var sigs: Array = t.get("signals", [])
		_sion_trigger._signal_controls.append_array(sigs)

	# Compile each track's pattern to MML separately (clean, no set_in fragmentation)
	_sion_trigger.start_batch_from_tracks(tracks, _cyclist.cps)

	# Start cyclist for UI sync
	_strudel_time = 0.0
	# Use first track's pattern or stack all for UI
	var all_pats: Array = []
	for t in tracks:
		all_pats.append(t["pattern"])
	if all_pats.size() == 1:
		_strudel_pattern = all_pats[0]
	elif all_pats.size() > 1:
		_strudel_pattern = Strudel.stack(all_pats)
	_cyclist.set_pattern(_strudel_pattern)
	_cyclist.start()
	_strudel_playing = true

	DebugOverlay.log("music/status", null, "MUSIC: Strudel batch playing (%d tracks, cps=%.2f)" % [tracks.size(), cps])


var _strudel_last_pattern: StrudelPattern = null  ## Preserved for resume after stop
var _strudel_last_source: String = ""

func strudel_stop() -> void:
	## Stop the Strudel pattern engine and the SiON stream.
	## Preserves the last pattern so strudel_start() can resume it.
	if _strudel_pattern:
		_strudel_last_pattern = _strudel_pattern
		_strudel_last_source = _strudel_source_text
	if _cyclist and _strudel_playing:
		_cyclist.stop()
	_strudel_playing = false
	_strudel_pattern = null
	# Clear any deferred notes and stop batch sequences
	if _sion_trigger:
		_sion_trigger.clear_pending()
		_sion_trigger.stop_all_sequences()
	# Stop the driver — handles both streaming mode (note_on) and play mode (batch MML)
	if driver:
		driver.call("stop")
		_sion_streaming = false
	# Reset audio effects when stopping (effects belong to the pattern)
	reset_music_effects()


func strudel_start() -> void:
	## Resume the last stopped pattern, or do nothing if there's nothing to resume.
	if _strudel_last_pattern:
		strudel_play(_strudel_last_pattern, -1.0, _strudel_last_source)
	else:
		print("MUSIC: nothing to resume")


func _strudel_play_title() -> void:
	## Load the intro.strudel file for the title screen.
	## Uses the RCON strudel load command which handles file loading,
	## multi-line merging, stack expansion, and auto-play.
	var rcon: Node = get_node_or_null("/root/Rcon")
	if rcon:
		rcon._execute("strudel load intro")


func strudel_set_cps(cps: float) -> void:
	if _cyclist:
		_cyclist.set_cps(cps)
		# In batch mode, change the driver's BPM live — no recompile needed.
		# The MML has t<BPM> baked in but set_bpm() overrides it at runtime.
		if _sion_trigger and _sion_trigger.batch_mode and driver:
			var new_bpm: int = maxi(30, int(240.0 * cps))
			driver.call("set_bpm", new_bpm)
	# Keep drawer's CPS in sync so strudel begin/end blocks use the correct tempo
	if MusicDrawer:
		MusicDrawer._cps = cps


func play_score(score_name: String) -> String:
	## Play a named score. Returns OK or error message.
	if not _all_scores.has(score_name):
		# Try partial match
		for key in _all_scores:
			if key.begins_with(score_name) or score_name in key:
				score_name = key
				break
	if not _all_scores.has(score_name):
		return "ERR: unknown score '%s'. Try: music scores" % score_name
	play_mml(_all_scores[score_name])
	# Show metadata if available
	if _loaded_scores.has(score_name):
		var info: Dictionary = _loaded_scores[score_name]
		return "OK: playing '%s' — %s (%s) by %s" % [
			score_name, info.get("title", ""), info.get("source", ""), info.get("author", "")]
	return "OK: playing score '%s'" % score_name


func get_score_list() -> String:
	## Return a formatted list of available scores.
	var lines: Array[String] = ["Available scores (%d):" % _all_scores.size()]
	# Builtins first
	for name in BUILTIN_SCORES:
		lines.append("  %-25s  [builtin]" % name)
	# Loaded scores grouped by mood
	var by_mood: Dictionary = {}
	for name in _loaded_scores:
		var info: Dictionary = _loaded_scores[name]
		var mood: String = info.get("mood", "other")
		if not by_mood.has(mood):
			by_mood[mood] = []
		by_mood[mood].append(name)
	for mood in by_mood:
		lines.append("  -- %s --" % mood)
		for name in by_mood[mood]:
			var info: Dictionary = _loaded_scores[name]
			lines.append("  %-25s  %s (%s) — %s" % [
				name, info.get("title", ""), info.get("source", ""),
				info.get("author", "")])
	return "\n".join(lines)


# -- Beat/Timer Callbacks ------------------------------------------------------

func _on_beat(_event: Variant) -> void:
	DebugOverlay.log("music/beats", null, "MUSIC: beat (intensity=%.2f)", [intensity])


func _on_timer() -> void:
	DebugOverlay.log("music/beats", null, "MUSIC: tick")


# -- Game Event Hooks ----------------------------------------------------------
# Called by game systems to influence the music. These are connected in
# _connect_game_events() which runs after the scene tree is ready.

var _game_events_connected: bool = false

func _connect_game_events() -> void:
	if _game_events_connected:
		return
	_game_events_connected = true

	# Game state changes
	GameManager.state_changed.connect(_on_game_state_changed)

	# Player events
	PlayerManager.player_joined.connect(_on_player_joined)
	PlayerManager.all_players_dead.connect(_on_all_players_dead)

	DebugOverlay.log("music/events", null, "MUSIC: game event hooks connected")


func connect_monster(monster: Node) -> void:
	## Call this when a monster is spawned to hook its state changes.
	## The monster's _change_state() calls DebugOverlay.log which we can't
	## intercept, so instead we poll or the monster calls us directly.
	## For now, provide direct push methods that monster code can call.
	DebugOverlay.log("music/events", null, "MUSIC: monster connected: %s" % monster.name)


func connect_player_health(health_comp: Node) -> void:
	## Hook a HealthComponent's signals for music reactivity.
	if health_comp.has_signal("damage_taken"):
		health_comp.damage_taken.connect(_on_player_damaged)
	if health_comp.has_signal("died"):
		health_comp.died.connect(_on_player_died)


# -- Game Event Handlers -------------------------------------------------------

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.TITLE:
			# Play Strudel-based title pattern
			if is_playing:
				stop()
			stop_title_music()
			_strudel_play_title()
		GameManager.GameState.TOWER, GameManager.GameState.BOSS:
			if not is_playing:
				play()
			if new_state == GameManager.GameState.BOSS:
				set_intensity(0.6)
				set_tempo(120)
		GameManager.GameState.OVERWORLD:
			if not is_playing:
				play()
			set_intensity(0.1)
			set_tempo(85)


func _on_player_joined(_player_index: int) -> void:
	push_intensity(0.05)
	# Defer health hookup since the player node may not be fully initialized yet
	call_deferred("_hook_player_health")


func _hook_player_health() -> void:
	## Scan all players and connect their HealthComponent signals if available.
	for p in get_tree().get_nodes_in_group("players"):
		if p.get("_health_comp") and is_instance_valid(p._health_comp):
			connect_player_health(p._health_comp)


func _on_all_players_dead() -> void:
	# Dramatic drop
	set_intensity(0.0)
	set_tempo(70)
	DebugOverlay.log("music/events", null, "MUSIC: all players dead — intensity drop")


func _on_player_damaged(_amount: int, _source_index: int) -> void:
	push_intensity(0.1)


func _on_player_died() -> void:
	push_intensity(-0.15)


# -- Title Screen Music --------------------------------------------------------

## Ambient title music: a soft, looping pad with gentle melodic motion.
## Uses a single MML sequence played directly on the driver (no layer system).
var _title_playing: bool = false

func _enter_title_music() -> void:
	if not driver:
		return
	# Soft ambient loop in C minor — slow tempo, quiet volume, warm pad voice
	# The MML uses long note values with octave shifts for gentle movement.
	# %6@0 = FM voice type 6 preset 0 (pad-like), v6 = low volume
	var title_mml := (
		"t60 "  # Very slow tempo
		+ "%6@0 o3 l2 v6 "  # Warm pad, octave 3, half notes, quiet
		+ "["
		+ "c1 e-1 | "           # Cm root
		+ "g2. e-4 c2. r4 | "  # Gentle ascent
		+ "a-1 g1 | "          # Ab passing tone
		+ "e-2. c4 g2. r4"     # Descent back
		+ "]8"                  # Loop 8 times (~4 min at t60)
	)
	driver.call("play", title_mml)
	_title_playing = true
	DebugOverlay.log("music/status", null, "MUSIC: title ambient started")
	print("MUSIC: title ambient started")


func stop_title_music() -> void:
	if _title_playing and driver:
		driver.call("stop")
		_title_playing = false
		DebugOverlay.log("music/status", null, "MUSIC: title ambient stopped")


# -- Monster Event Push API (called from monster code or RCON) -----------------

func _ensure_playing() -> void:
	## Start the layered music system if it isn't running yet.
	## Called automatically when game events push intensity.
	## Does NOT start during title screen — title has its own ambient music.
	if not is_playing and driver and GameManager.current_state != GameManager.GameState.TITLE:
		stop_title_music()
		play()


func on_monster_attack_start() -> void:
	_ensure_playing()
	push_intensity(0.15)

func on_monster_leap_start() -> void:
	_ensure_playing()
	push_intensity(0.25)
	# Bump tempo slightly during leaps
	if _bpm < 130:
		set_tempo(_bpm + 5)

func on_monster_chase_start() -> void:
	_ensure_playing()
	push_intensity(0.1)

func on_monster_died() -> void:
	set_intensity(0.1)
	set_tempo(BPM_DEFAULT)

func on_combat_start() -> void:
	_ensure_playing()
	push_intensity(0.4)
	set_tempo(110)

func on_combat_end() -> void:
	set_intensity(0.1)
	set_tempo(BPM_DEFAULT)


# -- Status --------------------------------------------------------------------

func get_status_text() -> String:
	var lines: Array[String] = []
	lines.append("Music: %s" % ("PLAYING" if is_playing else "STOPPED"))
	if not driver:
		lines.append("  driver: NOT INITIALIZED (GDSiON %s)" % (
			"not found" if not gdsion_available else "init failed"))
		return "\n".join(lines)
	lines.append("  driver: %s" % _version_str)
	lines.append("  bpm: %d  intensity: %.2f (target: %.2f)  muted: %s" % [
		_bpm, intensity, _target_intensity, "yes" if is_muted else "no"])
	for layer_name in _layers:
		var layer: LayerState = _layers[layer_name]
		var state_str: String = "ON v%d" % layer.current_variant if layer.active else "off"
		var enabled_str: String = "" if layer.enabled else " [DISABLED]"
		lines.append("  %-8s: %-8s threshold=%.2f tracks=%s%s" % [
			layer.name, state_str, layer.threshold, str(layer.track_ids), enabled_str])
	# Show active audio effects
	if not _active_controls.is_empty():
		lines.append("  effects: %s" % str(_active_controls))
	return "\n".join(lines)
