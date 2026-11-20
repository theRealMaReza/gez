extends Node

# Central non-musical audio manager (Phase 16).
# Buses: Master -> UI, Effects, Ambience.
# Strictly zero music or tonal instruments.

const SETTINGS_PATH := "user://audio_settings.cfg"
const MAX_UI_PLAYERS := 3
const MAX_EFFECT_PLAYERS := 5

const SOUND_PATHS := {
	"ui_parchment": [
		"res://assets/audio/ui_parchment_01.ogg",
		"res://assets/audio/ui_parchment_02.ogg",
		"res://assets/audio/ui_parchment_open.ogg",
	],
	"ui_wood": [
		"res://assets/audio/ui_wood_01.ogg",
		"res://assets/audio/ui_wood_02.ogg",
		"res://assets/audio/ui_wood_tick.ogg",
	],
	"coin_clink": [
		"res://assets/audio/coin_clink_01.ogg",
		"res://assets/audio/coin_clink_02.ogg",
	],
	"march_boots": [
		"res://assets/audio/march_boots_01.ogg",
		"res://assets/audio/march_boots_02.ogg",
		"res://assets/audio/march_boots_03.ogg",
	],
	"hoofbeats": [
		"res://assets/audio/hoofbeats_01.ogg",
		"res://assets/audio/hoofbeats_02.ogg",
	],
	"building_finished": [
		"res://assets/audio/build_hammer_01.ogg",
		"res://assets/audio/build_hammer_02.ogg",
		"res://assets/audio/build_wood_01.ogg",
	],
	"siege_started": [
		"res://assets/audio/siege_thud_01.ogg",
	],
	"siege_cannon": [
		"res://assets/audio/cannon_fire_01.ogg",
		"res://assets/audio/siege_thud_01.ogg",
	],
	"battle_started": [
		"res://assets/audio/battle_sword_clash_01.ogg",
		"res://assets/audio/battle_sword_clash_02.ogg",
	],
	"battle_sword": [
		"res://assets/audio/battle_sword_01.ogg",
		"res://assets/audio/battle_sword_02.ogg",
		"res://assets/audio/battle_sword_clash_01.ogg",
		"res://assets/audio/battle_sword_clash_02.ogg",
	],
	"battle_musket": [
		"res://assets/audio/musket_shot_01.ogg",
		"res://assets/audio/musket_shot_02.ogg",
	],
	"ambience_sea": [
		"res://assets/audio/ambience_sea.ogg",
	],
	"ambience_wind": [
		"res://assets/audio/ambience_wind.ogg",
	],
	"ambience_city": [
		"res://assets/audio/ambience_city.ogg",
	],
}

const CUE_COOLDOWN_SEC := {
	"ui_parchment": 0.05,
	"ui_wood": 0.05,
	"coin_clink": 0.30,
	"march_boots": 0.25,
	"hoofbeats": 0.28,
	"building_finished": 0.45,
	"siege_started": 0.50,
	"siege_cannon": 0.35,
	"battle_started": 0.55,
	"battle_sword": 0.22,
	"battle_musket": 0.22,
}

var master_muted: bool = false
var ui_volume: float = 0.85
var effects_volume: float = 0.80
var ambience_volume: float = 0.55

var _game_paused: bool = true
var _streams: Dictionary = {} # cue -> Array[AudioStream]
var _ui_pool: Array[AudioStreamPlayer] = []
var _fx_pool: Array[AudioStreamPlayer] = []
var _ambience_players: Dictionary = {} # key ("sea","wind","city") -> AudioStreamPlayer
var _ambience_targets: Dictionary = {"sea": 0.0, "wind": 0.45, "city": 0.0}
var _ambience_current: Dictionary = {"sea": 0.0, "wind": 0.0, "city": 0.0}
var _ambience_dirty: bool = false
var _last_cue_msec: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1453
	_ensure_buses()
	_load_settings()
	_apply_bus_settings()
	_preload_streams()
	_build_pools()
	_build_ambience_players()
	_wire_existing_buttons(get_tree().root)
	get_tree().node_added.connect(_on_node_added)

func _ensure_buses() -> void:
	for bus_name in ["UI", "Effects", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		master_muted = bool(cfg.get_value("audio", "master_muted", false))
		ui_volume = clampf(float(cfg.get_value("audio", "ui_volume", 0.85)), 0.0, 1.0)
		effects_volume = clampf(float(cfg.get_value("audio", "effects_volume", 0.80)), 0.0, 1.0)
		ambience_volume = clampf(float(cfg.get_value("audio", "ambience_volume", 0.55)), 0.0, 1.0)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_muted", master_muted)
	cfg.set_value("audio", "ui_volume", ui_volume)
	cfg.set_value("audio", "effects_volume", effects_volume)
	cfg.set_value("audio", "ambience_volume", ambience_volume)
	cfg.save(SETTINGS_PATH)

func _apply_bus_settings() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, master_muted)
	_set_bus_linear("UI", ui_volume)
	_set_bus_linear("Effects", effects_volume)
	_set_bus_linear("Ambience", ambience_volume)

func _set_bus_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, v)))

func set_master_muted(muted: bool) -> void:
	master_muted = muted
	_apply_bus_settings()
	_save_settings()

func set_ui_volume(val: float) -> void:
	ui_volume = clampf(val, 0.0, 1.0)
	_apply_bus_settings()
	_save_settings()

func set_effects_volume(val: float) -> void:
	effects_volume = clampf(val, 0.0, 1.0)
	_apply_bus_settings()
	_save_settings()

func set_ambience_volume(val: float) -> void:
	ambience_volume = clampf(val, 0.0, 1.0)
	_apply_bus_settings()
	_save_settings()

func _preload_streams() -> void:
	for cue in SOUND_PATHS.keys():
		var arr: Array[AudioStream] = []
		for path in SOUND_PATHS[cue]:
			if ResourceLoader.exists(path):
				var res := load(path)
				if res is AudioStream:
					arr.append(res as AudioStream)
		_streams[cue] = arr

func _build_pools() -> void:
	for _i in range(MAX_UI_PLAYERS):
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_ui_pool.append(p)
	for _i in range(MAX_EFFECT_PLAYERS):
		var p := AudioStreamPlayer.new()
		p.bus = "Effects"
		add_child(p)
		_fx_pool.append(p)

func _build_ambience_players() -> void:
	for key in ["sea", "wind", "city"]:
		var cue: String = "ambience_" + str(key)
		var p := AudioStreamPlayer.new()
		p.bus = "Ambience"
		p.volume_db = -80.0
		var list: Array = _streams.get(cue, [])
		if not list.is_empty():
			var stream: AudioStream = list[0]
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			p.stream = stream
		add_child(p)
		_ambience_players[key] = p

# MARK: - Playback API

func set_game_paused(paused: bool) -> void:
	if _game_paused != paused:
		_game_paused = paused
		_ambience_dirty = true

func update_ambience_weights(sea_weight: float, wind_weight: float, city_weight: float) -> void:
	_ambience_targets["sea"] = clampf(sea_weight, 0.0, 1.0)
	_ambience_targets["wind"] = clampf(wind_weight, 0.0, 1.0)
	_ambience_targets["city"] = clampf(city_weight, 0.0, 1.0)
	_ambience_dirty = true

func _process(delta: float) -> void:
	if not _ambience_dirty:
		return
	var any_moving := false
	for key in ["sea", "wind", "city"]:
		var target: float = 0.0 if _game_paused else float(_ambience_targets.get(key, 0.0))
		var cur: float = float(_ambience_current.get(key, 0.0))
		var next_val := move_toward(cur, target, delta * 2.2)
		if not is_equal_approx(next_val, target):
			any_moving = true
		_ambience_current[key] = next_val
		var p: AudioStreamPlayer = _ambience_players.get(key, null)
		if p != null and p.stream != null:
			if next_val <= 0.005:
				p.volume_db = -80.0
				if p.playing:
					p.stop()
			else:
				p.volume_db = linear_to_db(next_val * 0.65)
				if not p.playing and not DisplayServer.get_name().to_lower().contains("headless"):
					p.play()
	_ambience_dirty = any_moving

func play_ui(cue: String = "ui_wood") -> void:
	_play_from_pool(cue, _ui_pool, -4.0, 0.04)

func play_effect(cue: String, volume_db: float = -2.0) -> void:
	# Stay quiet while the game is paused except for UI clicks.
	if _game_paused:
		return
	_play_from_pool(cue, _fx_pool, volume_db, 0.07)

func play_events(cues: Array) -> void:
	if _game_paused:
		return
	for c in cues:
		play_effect(str(c))

func _play_from_pool(cue: String, pool: Array[AudioStreamPlayer], base_db: float, pitch_jitter: float) -> void:
	var list: Array = _streams.get(cue, [])
	if list.is_empty():
		return
	var now := Time.get_ticks_msec()
	var cooldown_ms := int(float(CUE_COOLDOWN_SEC.get(cue, 0.15)) * 1000.0)
	var last_ms := int(_last_cue_msec.get(cue, -999999))
	if now - last_ms < cooldown_ms:
		return

	var chosen: AudioStreamPlayer = null
	for p in pool:
		if not p.playing:
			chosen = p
			break
	if chosen == null:
		# Limit concurrent voices: do not pile up sounds.
		return

	_last_cue_msec[cue] = now
	var idx := _rng.randi_range(0, list.size() - 1)
	chosen.stream = list[idx]
	chosen.volume_db = base_db
	chosen.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	if not DisplayServer.get_name().to_lower().contains("headless"):
		chosen.play()

# MARK: - Automatic UI click wiring

func _wire_existing_buttons(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)
	for child in node.get_children():
		_wire_existing_buttons(child)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)

func _wire_button(btn: BaseButton) -> void:
	if btn.has_meta("_gez_audio_wired"):
		return
	btn.set_meta("_gez_audio_wired", true)
	btn.pressed.connect(_on_any_button_pressed.bind(btn))

func _on_any_button_pressed(btn: BaseButton) -> void:
	if not is_instance_valid(btn):
		return
	var t := ""
	if btn is Button:
		t = (btn as Button).text.to_lower()
	if t == "x" or t.contains("close") or t.contains("overview") or t.contains("economy") or t.contains("people") or t.contains("recent events") or t.contains("court") or t.contains("religion") or t.contains("tech"):
		play_ui("ui_parchment")
	else:
		play_ui("ui_wood")
