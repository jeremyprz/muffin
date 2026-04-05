extends Node

## Remote Console — TCP server for external tools to control the game.
## Listens on port 9999. Send text commands, one per line.
## Responds with results.

const PORT := 9999

var _server: TCPServer = null
var _clients: Array = []  # Array of StreamPeerTCP
var _title_layer: CanvasLayer = null
var _test_runner: Node = null
var _zone_manager: Node2D = null
var _leap_checker: Node2D = null
var _test_editor: Node = null

# Notify/prompt state (modal or editor-banner)
var _notify_layer: CanvasLayer = null
var _notify_name: String = ""
var _notify_message: String = ""
var _notify_buttons: Array = []
var _notify_timeout: float = 0.0
var _notify_timer: float = 0.0
var _notify_active: bool = false
var _notify_mode: String = ""  # "blocking" or "editor"
var _notify_dismissed_button: String = ""  # Set when dismissed, read by test runner
var _notify_hover_idx: int = -1           # Which button is hovered (-1 = none)
var _notify_mouse_pos: Vector2 = Vector2.ZERO

# Bounded-leap builder state (populated by `bleap` commands)
var _bleap_defs: Array = []              # Accumulated leap defs from previous `bleap next` calls
var _bleap_plat_a: Dictionary = {}       # {x, y, radius} — current def being built
var _bleap_plat_b: Dictionary = {}       # {x, y, radius}
var _bleap_plans: Array = []             # Array of plan dicts
var _bleap_current_plan: Dictionary = {} # Plan in progress (for multi-step plan building)
var _bleap_min_matched: int = 1

# Test script editor state
var _test_script: Array[String] = []     # Script as flat command list
var _test_script_name: String = ""       # Name of loaded test


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_server = TCPServer.new()
	var err := _server.listen(PORT)
	if err == OK:
		print("RCON: listening on port %d" % PORT)
	else:
		push_warning("RCON: failed to listen on port %d (err=%d)" % [PORT, err])


func _process(_delta: float) -> void:
	# Notify countdown timer. Negative timeout = wait forever (no auto-dismiss).
	if _notify_active and _notify_timeout >= 0:
		_notify_timer -= _delta
		if _notify_timer <= 0:
			_cmd_notify_dismiss(_notify_buttons[0] if not _notify_buttons.is_empty() else "OK")
		elif _notify_mode == "blocking" and _notify_layer and _notify_layer.get_child_count() > 0:
			_notify_layer.get_child(0).queue_redraw()

	# Re-apply portal state periodically (catches portals created after rebuild)
	if Engine.get_frames_drawn() % 60 == 0:
		_apply_portal_state()

	# Accept new connections
	if _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		_clients.append(peer)
		print("RCON: client connected")

	# Process each client
	var to_remove: Array[int] = []
	for i in range(_clients.size()):
		var peer: StreamPeerTCP = _clients[i]
		peer.poll()

		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			to_remove.append(i)
			continue

		var available: int = peer.get_available_bytes()
		if available > 0:
			var data: PackedByteArray = peer.get_data(available)[1]
			var text: String = data.get_string_from_utf8().strip_edges()
			for line in text.split("\n"):
				line = line.strip_edges()
				if line.is_empty():
					continue
				var response: String = _execute(line)
				peer.put_data((response + "\n").to_utf8_buffer())

	# Remove disconnected clients (reverse order)
	for i in range(to_remove.size() - 1, -1, -1):
		_clients.remove_at(to_remove[i])


func _execute(command: String) -> String:
	## Execute a command and return the response string.
	var parts: PackedStringArray = command.split(" ", false)
	if parts.is_empty():
		return "ERR: empty command"

	# Strudel multi-line block: accumulate lines between "strudel begin" and "strudel end"
	if _strudel_block_active:
		var trimmed: String = command.strip_edges()
		if trimmed == "strudel end":
			_strudel_block_active = false
			var raw_lines: Array[String] = _strudel_block.duplicate()
			_strudel_block.clear()
			# Merge multi-line expressions (shared with strudel load)
			var drawer_lines: Array[String] = _merge_continuation_lines(raw_lines)
			# Set drawer lines and play
			MusicDrawer._lines.clear()
			for bl in drawer_lines:
				MusicDrawer._lines.append(MusicDrawer._make_line(bl))
			MusicDrawer._current_line = 0
			MusicDrawer._editor_cursor = 0
			MusicDrawer.open()
			MusicDrawer._play_current()
			return "OK: strudel block (%d raw → %d merged lines), playing" % [raw_lines.size(), drawer_lines.size()]
		elif trimmed == "strudel ref end":
			_strudel_block_active = false
			var block_lines: Array[String] = _strudel_block.duplicate()
			_strudel_block.clear()
			# Send to ref server as a single multi-line expression
			var code: String = "\n".join(PackedStringArray(block_lines))
			return _cmd_strudel_ref_code(code)
		else:
			# Accumulate the line (skip empty and comments for cleanliness)
			if not trimmed.is_empty():
				_strudel_block.append(trimmed)
			return "OK: +line (%d)" % _strudel_block.size()

	var cmd: String = parts[0].to_lower()

	match cmd:
		"help":
			return """Commands:
  help                          — this list
  status                        — debug state, enemy/player counts
  debug [list|on|off|log|...]   — debug overlay aspects
  spawn <type> [x y] [name=id]         — spawn entity (name= sets entity_id)
  kick <entity> <vx> <vy>             — apply velocity impulse to entity
  shackle_attach <target>              — force shackle onto target entity
  kill                          — kill all enemies (damage to death)
  clear                         — remove all enemies (instant)
  clearplayers                  — remove all players
  enablejoins                   — allow new player joins
  revive                        — revive dead players
  tp <x> <y>                    — teleport selected enemy
  tab [n]                       — cycle/select enemy
  key <k>                       — simulate keypress
  eval <expr>                   — evaluate GDScript expression
  standdown [on|off]            — toggle monster standdown
  precog                        — force precognition
  hp                            — show player HP
  resethp                       — reset player HP to max
  fps                           — show FPS
  ik                            — show IK metrics
  ikreset                       — reset IK peak
  ball                          — drop ball simulation
  thrash                        — toggle thrash test
  dump [ik|skeleton]            — dump debug data to file
  splay ...                     — splay pose commands
  chain ...                     — chain commands
  tether ...                    — tether commands
  attach/detach                 — attachment system
  buff <key=val ...> <duration> — apply config overrides
  mod <blueprint> [entity]      — apply modifier blueprint
  mods                          — list active modifiers
  unmod <name> [entity]         — remove modifier by name
  smod <blueprint>              — apply modifier to shackle config
  smods                         — list shackle modifiers
  unsmod <name>                 — remove shackle modifier
  attacker ...                  — attacker dummy commands
  territorial                   — toggle territorial mode
  portal [on|off]               — toggle class-change portal
  level <name>                  — load level
  run <test> [key=val ...]      — run test
  suite <name> [key=val ...]    — run test suite
  tests                         — list available tests
  etz/daz <id> <x> <y> <r>     — add ETZ/DAZ zone
  zones / clearzones            — show/clear zones
  leaps / clearleaps            — show/clear leap graph
  bleap ...                     — bounded leap commands
  testload/testsave/testrun/... — test editor commands
  notify <name> <msg> ...       — show modal notification
  notify_dismiss <button>       — dismiss notification
  emit <signal>                 — emit a signal
  title                         — return to title screen
  score                         — show score panel
  grid                          — toggle grid overlay
  debugdraw                     — toggle enemy debug draw
  gameconfig <key> [value]      — get/set game config (gc shorthand)
  exec_tuning (et)              — toggle ball/chain tuning popup
  exec_set <key> <value>        — set executioner tuning value
  music [play|stop|off|score|scores|mml|intensity|tempo|layer|...] — music
  strudel <mini-notation>       — play Strudel pattern (or stop/cps/status/fx)
  musicdrawer (md)              — toggle music drawer (Ctrl+M)
  quit                          — quit game"""

		"debug":
			return _cmd_debug(parts)

		"level":
			# Load a level by name: level <name>
			# Tears down the current world and rebuilds from the new level config.
			# Also hides/shows baked scene nodes (platforms, etc.) based on the config.
			if parts.size() < 2:
				return "ERR: usage: level <name>"
			var level_name: String = parts[1]
			var data: Dictionary = LevelConfig.load_level(level_name)
			if data.is_empty():
				return "ERR: level '%s' not found" % level_name
			var scene: Node = get_tree().current_scene
			if scene and scene.has_method("_rebuild_from_config"):
				scene._rebuild_from_config(data)
				# Hide/show baked platform nodes based on whether the level has platforms
				var has_platforms: bool = not data.get("platforms", []).is_empty()
				var baked_plats: Array[String] = ["PlatLeft", "PlatRight", "PlatTopLeft", "PlatTopRight"]
				for pname in baked_plats:
					var plat: Node = scene.get_node_or_null(pname)
					if plat:
						plat.visible = has_platforms
						# Disable collision when hidden
						plat.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT if has_platforms else Node.PROCESS_MODE_DISABLED)
						for child in plat.get_children():
							if child is CollisionShape2D:
								child.set_deferred("disabled", not has_platforms)
				# Hide title UI when loading a non-title level
				var ui_node: Node = scene.get_node_or_null("UI")
				if ui_node:
					ui_node.visible = (level_name == "title_screen")
				return "OK: loaded level '%s'" % level_name
			return "ERR: current scene doesn't support level loading"

		"spawn":
			var what: String = parts[1] if parts.size() > 1 else "monster"
			# Resolve position: supports absolute (960 876) or relative (@e[name=AI] ~150 ~0)
			var pos_result: Array = _resolve_pos(parts, 2)
			var x: float = pos_result[0]
			var y: float = pos_result[1]
			var arg_start: int = pos_result[2]
			var state: String = ""
			var spawn_scale: float = 1.0
			var spawn_pathing_radius: float = -1.0
			var spawn_config: Dictionary = {}
			# Parse remaining args: positional state OR key=value pairs
			for pi in range(arg_start, parts.size()):
				var arg: String = parts[pi]
				if arg.begins_with("config={") and arg.ends_with("}"):
					var inner_cfg: String = arg.substr(8, arg.length() - 9)
					for pair in inner_cfg.split(","):
						var eq: int = pair.find("=")
						if eq > 0:
							spawn_config[pair.substr(0, eq).strip_edges()] = pair.substr(eq + 1).strip_edges()
				elif arg.contains("="):
					var kv: PackedStringArray = arg.split("=", true, 1)
					if kv[0] == "scale":
						spawn_scale = float(kv[1])
					elif kv[0] == "pathing_radius":
						spawn_pathing_radius = float(kv[1])
					else:
						spawn_config[kv[0]] = kv[1]
				elif state.is_empty():
					state = arg.to_lower()
			return _cmd_spawn(what, x, y, state, spawn_scale, spawn_pathing_radius, spawn_config)

		"tab":
			var count: int = int(parts[1]) if parts.size() > 1 else 1
			for _i in range(count):
				PlayerHUD._debug_cycle_enemy()
			var sel_name: String = "none"
			if is_instance_valid(PlayerHUD.debug_selected_enemy):
				sel_name = PlayerHUD.debug_selected_enemy.name
			return "OK: tab x%d → selected=%s" % [count, sel_name]

		"key":
			if parts.size() < 2:
				return "ERR: usage: key <keyname> (e.g. key m, key ctrl+d)"
			return _cmd_key(parts[1])

		"eval":
			var expr_text: String = command.substr(5).strip_edges()
			return _cmd_eval(expr_text)

		"status":
			return _cmd_status()

		"enemies":
			var enemies: Array = get_tree().get_nodes_in_group("enemies")
			var lines: Array[String] = ["enemies: %d" % enemies.size()]
			for e in enemies:
				lines.append("  %s at (%.0f,%.0f)" % [e.name, e.global_position.x, e.global_position.y])
			return "\n".join(lines)

		"players":
			var players: Array = get_tree().get_nodes_in_group("players")
			var lines: Array[String] = ["players: %d" % players.size()]
			for p in players:
				lines.append("  %s at (%.0f,%.0f)" % [p.name, p.global_position.x, p.global_position.y])
			# Show controller bindings
			lines.append("controllers:")
			for did in Input.get_connected_joypads():
				var guid: String = Input.get_joy_guid(did)
				var jname: String = Input.get_joy_name(did)
				var ctrl_name: String = ProfileManager._get_controller_name(did)
				var slot: int = ProfileManager.get_preferred_player_index(did)
				var joined_as: String = str(PlayerManager._joined_devices.get(did, "none"))
				lines.append("  dev=%d guid=%s name=%s ctrl=%s saved_slot=%d joined=%s" % [did, guid, jname, ctrl_name, slot, joined_as])
			lines.append("keyboard: slot=%d" % ProfileManager.get_preferred_player_index(-1))
			return "\n".join(lines)

		"tp":
			# Teleport player: tp <x> <y> or tp <player_index> <x> <y>
			if parts.size() < 3:
				return "ERR: usage: tp <x> <y> or tp <player_index> <x> <y>"
			return _cmd_teleport(parts)

		"clearplayers":
			var cleared_p: int = 0
			for p in get_tree().get_nodes_in_group("players"):
				# Reset state first to destroy chain nodes
				if p.has_method("reset_state"):
					p.reset_state()
				p.queue_free()
				cleared_p += 1
			# Also clean up any orphaned chains/tethers from executioner
			for chain in get_tree().get_nodes_in_group("chains"):
				chain.queue_free()
			# Block controller re-joins and clear device tracking
			PlayerManager.join_disabled = true
			PlayerManager._joined_devices.clear()
			return "OK: cleared %d players, joins disabled" % cleared_p

		"enablejoins":
			PlayerManager.join_disabled = false
			PlayerManager._joined_devices.clear()
			return "OK: joins enabled"

		"announce":
			# Show large announcement text on screen (fades after a few seconds)
			var ann_text: String = command.substr(command.find(" ") + 1).strip_edges() if command.find(" ") >= 0 else ""
			if not ann_text.is_empty():
				PlayerHUD.show_announcement(ann_text)
			return "OK: %s" % ann_text if not ann_text.is_empty() else "OK"

		"comment":
			# Inline documentation — prints to log but not on screen
			var comment_text: String = " ".join(parts.slice(1))
			if not comment_text.is_empty():
				print("  # %s" % comment_text)
			return "OK"

		"shackle_attach":
			# Force the Executioner's shackle onto a target entity
			# Usage: shackle_attach <entity_name>
			if parts.size() < 2:
				return "ERR: usage: shackle_attach <entity_name>"
			var sa_target_name: String = parts[1]
			var sa_target: Node2D = null
			for e in _get_all_entities():
				if e.name == sa_target_name or ("entity_id" in e and str(e.entity_id) == sa_target_name):
					sa_target = e
					break
			if not sa_target:
				return "ERR: entity '%s' not found" % sa_target_name
			# Find Executioner player
			var sa_exec: Node2D = null
			for p in get_tree().get_nodes_in_group("players"):
				if "_exec_shackle_state" in p:
					sa_exec = p
					break
			if not sa_exec:
				return "ERR: no Executioner player found"
			# Force shackle attachment
			sa_exec._exec_shackle_state = sa_exec.ExecEndState.ATTACHED_ENEMY
			sa_exec._exec_shackle_anchor_body = sa_target
			sa_exec._exec_shackle_anchor_offset = Vector2.ZERO
			sa_exec._exec_shackle_pos = sa_target.global_position
			# Create shackle chain if not present
			if not sa_exec._exec_shackle_chain_node or not is_instance_valid(sa_exec._exec_shackle_chain_node):
				var chain_script: GDScript = load("res://scripts/systems/chain.gd")
				var chain := Node2D.new()
				chain.set_script(chain_script)
				chain.link_count = 8
				chain.link_length = sa_exec._exec_shackle_chain_len() / 8.0
				chain.anchor_a = {"node": sa_exec, "offset": Vector2.ZERO, "is_wall": false}
				chain.anchor_b = {"pos": sa_target.global_position, "is_wall": false}
				get_tree().current_scene.add_child(chain)
				sa_exec._exec_shackle_chain_node = chain
			return "OK: shackle attached to '%s'" % sa_target_name

		"kick":
			# Apply velocity impulse to a named entity
			# Usage: kick <entity_name> <vx> <vy>
			if parts.size() < 4:
				return "ERR: usage: kick <entity_name> <vx> <vy>"
			var kick_name: String = parts[1]
			var kick_vx: float = float(parts[2])
			var kick_vy: float = float(parts[3])
			var kick_target: Node2D = null
			for e in _get_all_entities():
				if e.name == kick_name or ("entity_id" in e and str(e.entity_id) == kick_name):
					kick_target = e
					break
			if not kick_target:
				return "ERR: entity '%s' not found" % kick_name
			if kick_target.has_method("apply_knockback"):
				kick_target.apply_knockback(Vector2(kick_vx, kick_vy))
			elif "velocity" in kick_target:
				kick_target.velocity += Vector2(kick_vx, kick_vy)
			else:
				return "ERR: entity '%s' has no velocity or apply_knockback" % kick_name
			return "OK: kicked '%s' by (%.0f, %.0f)" % [kick_name, kick_vx, kick_vy]

		"kill":
			# Kill all monsters by dealing massive damage (triggers death sequence)
			var killed: int = 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.has_method("take_damage"):
					e.take_damage(99999, -1)
					killed += 1
				else:
					e.queue_free()
					killed += 1
			return "OK: killed %d enemies" % killed

		"clear":
			var cleared: int = 0
			for e in get_tree().get_nodes_in_group("enemies"):
				e.queue_free()
				cleared += 1
			# Disable bat/firefly spawning by removing their managers
			var scene: Node = get_tree().current_scene
			if scene:
				# Stop bat respawn timer
				if "_bat_spawn_timer" in scene:
					scene._bat_max = 0
				# Remove firefly manager
				if "_firefly_manager" in scene and is_instance_valid(scene._firefly_manager):
					scene._firefly_manager.queue_free()
					scene._firefly_manager = null
			return "OK: cleared %d enemies, disabled respawning" % cleared

		"precog":
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.has_method("_start_precognition"):
					e._start_precognition()
			return "OK: forced precognition"

		"hp":
			var players: Array = get_tree().get_nodes_in_group("players")
			for p in players:
				var hp: Variant = p.get("health")
				var dmg: Variant = p.get("damage_taken")
				if hp != null:
					return "hp=%s damage_taken=%s" % [str(hp), str(dmg)]
			return "ERR: no player with health"

		"resethp":
			var players: Array = get_tree().get_nodes_in_group("players")
			for p in players:
				if "health" in p:
					p.health = p.max_health
					p.damage_taken = 0
			return "OK: reset HP"

		"revive":
			var revived: int = 0
			# Revive real players (player_side.gd)
			for node in get_tree().get_nodes_in_group("players"):
				if "_is_dead" in node and node._is_dead and node.has_method("_revive"):
					node._revive()
					revived += 1
			# Also check dead players not in "players" group (they remove themselves on death)
			for node in get_tree().current_scene.get_children():
				if "_is_dead" in node and node._is_dead and node.has_method("_revive"):
					node._revive()
					revived += 1
			# Reset HP on all living players too
			for node in get_tree().get_nodes_in_group("players"):
				var p_data: Dictionary = {}
				if "player_index" in node:
					p_data = PlayerManager.get_player(node.player_index)
				if not p_data.is_empty():
					p_data["health"] = p_data.get("max_health", 100)
			return "OK: revived %d, reset all HP" % revived

		"fps":
			return "fps=%.0f" % Engine.get_frames_per_second()

		"ik":
			for e in get_tree().get_nodes_in_group("enemies"):
				if "_ik_score" in e:
					return "ik_now=%.0f ik_avg=%.0f ik_peak=%.0f" % [e._ik_score, e._ik_score_avg, e._ik_score_peak]
			return "ERR: no enemy with IK score"

		"ball":
			for e in get_tree().get_nodes_in_group("enemies"):
				if "_ball_score" in e:
					return "ball_now=%.0f ball_peak=%.0f" % [e._ball_score, e._ball_score_peak]
			return "ERR: no enemy with ball score"

		"thrash":
			for e in get_tree().get_nodes_in_group("enemies"):
				if "_strategy_changes" in e:
					return "thrash=%d plan_attempts=%d/%d" % [e._strategy_changes, e._plan_attempts, e.MAX_PLAN_ATTEMPTS]
			return "ERR: no enemy with thrash score"

		"ikreset":
			for e in get_tree().get_nodes_in_group("enemies"):
				if "_ik_score_peak" in e:
					e._ik_score_peak = 0.0
					e._ik_score_avg = 0.0
					e._ik_score_samples = 0
			return "OK: reset IK scores"

		"title":
			if parts.size() < 2:
				return "ERR: usage: title <text>"
			var title_text: String = command.substr(6).strip_edges()
			_show_title(title_text)
			return "OK: showing '%s'" % title_text

		"score":
			# Show score card: score <title>|<dmg>|<time>|<fps>|<ik>|<thrash>
			if parts.size() < 2:
				return "ERR: usage: score <title>|<dmg>|<time>|<fps>|<ik>|<thrash>"
			var score_text: String = command.substr(6).strip_edges()
			_show_score_card(score_text)
			return "OK: showing score"

		"grid":
			# Show final results grid: grid <line1>|<line2>|...
			if parts.size() < 2:
				return "ERR: usage: grid <line1>|<line2>|..."
			var grid_text: String = command.substr(5).strip_edges()
			_show_results_grid(grid_text)
			return "OK: showing grid"

		"debugdraw":
			for e in get_tree().get_nodes_in_group("enemies"):
				if "debug_draw_enabled" in e:
					e.debug_draw_enabled = not e.debug_draw_enabled
			return "OK: toggled debug draw"

		"test":
			# Automated test: teleport player to various spots, force precog each time
			if parts.size() < 2:
				return "ERR: usage: test precog"
			return _cmd_test(parts[1])

		"partstatus":
			return _cmd_partstatus()

		"partdmg":
			return _cmd_partdmg(parts)

		"weight":
			return _cmd_weight()

		"attach":
			return _cmd_attach(parts)

		"detach":
			return _cmd_detach(parts)

		"dump":
			# Dump skeleton JSON for selected or indexed enemy
			var idx: int = int(parts[1]) if parts.size() > 1 else 0
			var enemies: Array = get_tree().get_nodes_in_group("enemies")
			if idx >= enemies.size():
				return "ERR: enemy %d not found (have %d)" % [idx, enemies.size()]
			var trigger_name: String = parts[2] if parts.size() > 2 else "rcon"
			var data: Dictionary = PlayerHUD.dump_entity_skeleton(enemies[idx], trigger_name)
			if data.is_empty():
				return "ERR: dump failed"
			return JSON.stringify(data, "\t")

		"splay":
			return _cmd_splay(parts)

		"chaindump":
			return _cmd_chaindump()

		"mocap":
			return _cmd_mocap(parts)

		"skeleton":
			var sel: Node2D = PlayerHUD.debug_selected_enemy if is_instance_valid(PlayerHUD.debug_selected_enemy) else null
			if not sel or not "creature_scale" in sel:
				return "ERR: no quadruped selected (TAB to select)"
			var m: Node2D = sel
			var lines: Array[String] = ["skeleton: %s at (%.0f,%.0f) scale=%.1f facing=%.1f" % [
				m.entity_id, m.global_position.x, m.global_position.y, m.creature_scale, m._facing]]
			lines.append("  spine[0]=(%.0f,%.0f) [1]=(%.0f,%.0f) [2]=(%.0f,%.0f)" % [
				m._spine[0].x, m._spine[0].y, m._spine[1].x, m._spine[1].y, m._spine[2].x, m._spine[2].y])
			lines.append("  skull=(%.0f,%.0f) neck1=(%.0f,%.0f)" % [m._skull.x, m._skull.y, m._neck[1].x, m._neck[1].y])
			lines.append("  clav[0]=(%.0f,%.0f) clav[1]=(%.0f,%.0f)" % [
				m._clavicles[0].x, m._clavicles[0].y, m._clavicles[1].x, m._clavicles[1].y])
			for li in range(4):
				var label: String = ["FL","FR","RL","RR"][li]
				lines.append("  %s: hip=(%.0f,%.0f) knee=(%.0f,%.0f) foot=(%.0f,%.0f) planted=%s" % [
					label, m._legs[li][0].x, m._legs[li][0].y,
					m._legs[li][1].x, m._legs[li][1].y,
					m._legs[li][2].x, m._legs[li][2].y,
					str(m._foot_planted[li])])
			return "\n".join(lines)

		"chain":
			return _cmd_chain(parts)

		"tether":
			return _cmd_tether(parts)

		"territorial":
			var enemies: Array = get_tree().get_nodes_in_group("enemies")
			var count: int = 0
			var new_state: Variant = null
			if parts.size() > 1:
				match parts[1].to_lower():
					"on": new_state = true
					"off": new_state = false
			for e in enemies:
				if "territorial" in e:
					if new_state != null:
						e.territorial = new_state as bool
					else:
						e.territorial = not e.territorial
					count += 1
			if count == 0:
				return "ERR: no monsters with territorial support"
			var state_str: String = str(enemies[0].territorial) if "territorial" in enemies[0] else "?"
			return "OK: territorial=%s on %d monsters" % [state_str, count]

		"portal":
			# portal on|off — enable/disable portal transition (persists across rebuilds)
			var enable: bool = true
			if parts.size() > 1 and parts[1].to_lower() == "off":
				enable = false
			# Store as meta on the scene so it persists across rebuilds
			get_tree().current_scene.set_meta("portal_disabled", not enable)
			_apply_portal_state()
			return "OK: portal %s" % ("enabled" if enable else "disabled")

		"standdown":
			return _cmd_standdown(parts)

		"buff":
			# Apply a timed config override to all monsters
			# Usage: buff <duration> <key=value> [key=value ...]
			# Example: buff 5 speed_slow=200 bite_damage=50
			if parts.size() < 3:
				return "ERR: usage: buff <duration_seconds> <key=value> [key=value ...]"
			var buff_duration: float = float(parts[1])
			var buff_overrides: Dictionary = {}
			for pi in range(2, parts.size()):
				var eq: int = parts[pi].find("=")
				if eq > 0:
					buff_overrides[parts[pi].substr(0, eq).to_lower()] = parts[pi].substr(eq + 1)
			if buff_overrides.is_empty():
				return "ERR: no key=value pairs provided"
			var buff_count: int = 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.has_method("apply_timed_config"):
					e.apply_timed_config(buff_overrides, buff_duration, "buff_%.0fs" % buff_duration)
					buff_count += 1
			return "OK: applied %d overrides for %.0fs to %d monsters" % [buff_overrides.size(), buff_duration, buff_count]

		"mod":
			# Apply a modifier blueprint to an entity
			# Usage: mod <blueprint_name> [entity_name]
			# If no entity specified, applies to selected entity
			if parts.size() < 2:
				return "ERR: usage: mod <blueprint_name> [entity_name]"
			var bp_name: String = parts[1]
			# Load blueprint
			var bp_data: Dictionary = {}
			for base in ["user://modifier_blueprints/", "res://data/modifier_blueprints/"]:
				var bp_path: String = base + bp_name + ".json"
				if FileAccess.file_exists(bp_path):
					var bp_file := FileAccess.open(bp_path, FileAccess.READ)
					if bp_file:
						var bp_json := JSON.new()
						if bp_json.parse(bp_file.get_as_text()) == OK and bp_json.data is Dictionary:
							bp_data = bp_json.data
					break
			if bp_data.is_empty():
				return "ERR: blueprint '%s' not found" % bp_name
			# Find target entity
			var target: Node2D = null
			if parts.size() >= 3:
				var tname: String = parts[2]
				for e in _get_all_entities():
					if e.name == tname or ("entity_id" in e and str(e.entity_id) == tname):
						target = e
						break
				if not target:
					return "ERR: entity '%s' not found" % tname
			else:
				target = PlayerHUD.debug_selected_enemy if is_instance_valid(PlayerHUD.debug_selected_enemy) else null
				if not target:
					# Try first player
					var players = get_tree().get_nodes_in_group("players")
					if not players.is_empty():
						target = players[0]
			if not target:
				return "ERR: no entity selected/found"
			if not target.has_method("push_config"):
				return "ERR: entity '%s' doesn't support config stack" % target.name
			# Build modifiers
			var modifiers: Dictionary = {}
			for key in bp_data:
				if key.begins_with("_"):
					continue
				var val = bp_data[key]
				if val is Array and val.size() == 2:
					modifiers[key] = val
			if modifiers.is_empty():
				return "ERR: blueprint '%s' has no modifiers" % bp_name
			var MCP = load("res://scripts/systems/monster_config.gd")
			var provider = MCP.ModifierProvider.new(modifiers, bp_name)
			target.push_config(provider)
			return "OK: applied '%s' (%d mods) to %s" % [bp_name, modifiers.size(), target.name]

		"mods":
			# List all active modifier providers across entities
			var lines: Array[String] = []
			for e in _get_all_entities():
				if not e.has_method("cfg") or not "_config_stack" in e:
					continue
				for provider in e._config_stack:
					if provider.has_method("is_modifier") and provider.is_modifier():
						var pname: String = provider._name if "_name" in provider else str(provider)
						var eid: String = e.name
						if "entity_id" in e and not str(e.entity_id).is_empty():
							eid = str(e.entity_id)
						lines.append("  %s → %s (%d mods)" % [pname, eid, provider._modifiers.size()])
			if lines.is_empty():
				return "No active modifiers"
			return "Active modifiers:\n" + "\n".join(lines)

		"unmod":
			# Remove a modifier by name from an entity (or all entities)
			if parts.size() < 2:
				return "ERR: usage: unmod <modifier_name> [entity_name]"
			var mod_name: String = parts[1]
			var removed: int = 0
			for e in _get_all_entities():
				if parts.size() >= 3 and e.name != parts[2]:
					continue
				if not e.has_method("cfg") or not "_config_stack" in e:
					continue
				for provider in e._config_stack.duplicate():
					if provider.has_method("is_modifier") and provider.is_modifier():
						if "_name" in provider and provider._name == mod_name:
							e.remove_config(provider)
							removed += 1
			if removed == 0:
				return "ERR: no modifier named '%s' found" % mod_name
			return "OK: removed %d instance(s) of '%s'" % [removed, mod_name]

		"smod":
			# Apply a modifier blueprint to the shackle config stack
			# Usage: smod <blueprint_name>
			if parts.size() < 2:
				return "ERR: usage: smod <blueprint_name>"
			var sbp_name: String = parts[1]
			var sbp_data: Dictionary = {}
			for base in ["user://modifier_blueprints/", "res://data/modifier_blueprints/"]:
				var sbp_path: String = base + sbp_name + ".json"
				if FileAccess.file_exists(sbp_path):
					var sbp_file := FileAccess.open(sbp_path, FileAccess.READ)
					if sbp_file:
						var sbp_json := JSON.new()
						if sbp_json.parse(sbp_file.get_as_text()) == OK and sbp_json.data is Dictionary:
							sbp_data = sbp_json.data
					break
			if sbp_data.is_empty():
				return "ERR: blueprint '%s' not found" % sbp_name
			# Find executioner player
			var exec_player: Node2D = null
			for p in get_tree().get_nodes_in_group("players"):
				if "character_class" in p and p.character_class == PlayerManager.CharacterClass.EXECUTIONER:
					if p.has_method("push_shackle_config"):
						exec_player = p
						break
			if not exec_player:
				return "ERR: no Executioner player found"
			var s_modifiers: Dictionary = {}
			for key in sbp_data:
				if key.begins_with("_"):
					continue
				var val = sbp_data[key]
				if val is Array and val.size() == 2:
					s_modifiers[key] = val
			if s_modifiers.is_empty():
				return "ERR: blueprint '%s' has no modifiers" % sbp_name
			var MCP = load("res://scripts/systems/monster_config.gd")
			var s_provider = MCP.ModifierProvider.new(s_modifiers, sbp_name)
			exec_player.push_shackle_config(s_provider)
			return "OK: applied '%s' (%d mods) to shackle" % [sbp_name, s_modifiers.size()]

		"smods":
			# List shackle modifiers on all executioner players
			var s_lines: Array[String] = []
			for p in get_tree().get_nodes_in_group("players"):
				if not "_exec_shackle_config_stack" in p:
					continue
				for provider in p._exec_shackle_config_stack:
					if provider.has_method("is_modifier") and provider.is_modifier():
						s_lines.append("  %s (%d mods)" % [provider._name, provider._modifiers.size()])
			if s_lines.is_empty():
				return "No shackle modifiers"
			return "Shackle modifiers:\n" + "\n".join(s_lines)

		"unsmod":
			# Remove a shackle modifier by name
			if parts.size() < 2:
				return "ERR: usage: unsmod <modifier_name>"
			var us_name: String = parts[1]
			var us_removed: int = 0
			for p in get_tree().get_nodes_in_group("players"):
				if not "_exec_shackle_config_stack" in p or not p.has_method("remove_shackle_config"):
					continue
				for provider in p._exec_shackle_config_stack.duplicate():
					if provider.has_method("is_modifier") and provider.is_modifier():
						if "_name" in provider and provider._name == us_name:
							p.remove_shackle_config(provider)
							us_removed += 1
			if us_removed == 0:
				return "ERR: no shackle modifier named '%s' found" % us_name
			return "OK: removed %d instance(s) of '%s' from shackle" % [us_removed, us_name]

		"attacker":
			return _cmd_attacker(parts)

		"run":
			if parts.size() < 2:
				return "ERR: usage: run <test_name> [key=value ...]"
			var editor: Node = _ensure_test_editor()
			if editor:
				var override_vars: Dictionary = {"owait": "0"}
				for pi in range(2, parts.size()):
					var eq := parts[pi].find("=")
					if eq > 0:
						override_vars[parts[pi].substr(0, eq)] = parts[pi].substr(eq + 1)
				# If editor isn't ready yet (just created), defer the load+run
				if not "_active" in editor:
					call_deferred("_deferred_run_test", parts[1], override_vars)
				else:
					editor._test_override_vars = override_vars
					editor._load_test(parts[1])
					editor.call_deferred("_run_test")
				return "OK: running test '%s' in editor (%s)" % [parts[1], str(override_vars)]
			return "ERR: failed to open test editor"

		"suite":
			if parts.size() < 2:
				return "ERR: usage: suite <suite_name> [key=value ...] [skip test1 test2 ...]"
			var editor: Node = _ensure_test_editor()
			if editor:
				# Parse optional key=value args and skip list
				var override_vars: Dictionary = {"owait": "0"}  # Default for RCON
				var skip_tests: Array[String] = []
				var parsing_skip: bool = false
				for pi in range(2, parts.size()):
					if parts[pi] == "skip":
						parsing_skip = true
						continue
					if parsing_skip:
						skip_tests.append(parts[pi])
					else:
						var eq := parts[pi].find("=")
						if eq > 0:
							override_vars[parts[pi].substr(0, eq)] = parts[pi].substr(eq + 1)
				# If editor isn't ready yet (just created), defer the suite run
				if not "_active" in editor:
					call_deferred("_deferred_run_suite", parts[1], override_vars, skip_tests)
				else:
					editor._test_override_vars = override_vars
					editor.run_suite(parts[1], skip_tests)
				var skip_str: String = " skip=%s" % str(skip_tests) if not skip_tests.is_empty() else ""
				return "OK: running suite '%s' in editor (%s)%s" % [parts[1], str(override_vars), skip_str]
			return "ERR: failed to open test editor"

		"tests":
			return _cmd_list_tests()

		"etz":
			# etz <id> <x> <y> <radius> [entity_id]
			if parts.size() < 5:
				return "ERR: usage: etz <id> <x> <y> <radius> [entity_id]"
			var eid: String = parts[5] if parts.size() > 5 else ""
			_ensure_zone_manager()
			_zone_manager.add_etz(int(parts[1]), Vector2(float(parts[2]), float(parts[3])), float(parts[4]), eid)
			return "OK: added ETZ-%s at (%.0f,%.0f) r=%.0f" % [parts[1], float(parts[2]), float(parts[3]), float(parts[4])]

		"daz":
			# daz <id> <x> <y> <radius> [entity_id]
			if parts.size() < 5:
				return "ERR: usage: daz <id> <x> <y> <radius> [entity_id]"
			var eid: String = parts[5] if parts.size() > 5 else ""
			_ensure_zone_manager()
			_zone_manager.add_daz(int(parts[1]), Vector2(float(parts[2]), float(parts[3])), float(parts[4]), eid)
			return "OK: added DAZ-%s at (%.0f,%.0f) r=%.0f" % [parts[1], float(parts[2]), float(parts[3]), float(parts[4])]

		"zones":
			if _zone_manager and is_instance_valid(_zone_manager):
				return _zone_manager.get_status()
			return "zones: 0"

		"clearzones":
			if _zone_manager and is_instance_valid(_zone_manager):
				_zone_manager.clear_zones()
			else:
				_zone_manager = null  # Reset stale reference
			return "OK: zones cleared"

		"leaps":
			# Return a summary of all planned hop edges from every monster
			var _leap_lines: Array[String] = []
			for _le in get_tree().get_nodes_in_group("enemies"):
				if _le.has_method("get_leap_graph"):
					var _graph: Array = _le.get_leap_graph()
					_leap_lines.append("  %s: %d edges" % [_le.name, _graph.size()])
					for _edge in _graph:
						_leap_lines.append("    from=(%.0f,%.0f) arrival=(%.0f,%.0f) vel=(%.0f,%.0f)" % [
							_edge["from_pos"].x, _edge["from_pos"].y,
							_edge["arrival"].x, _edge["arrival"].y,
							_edge["launch_vel"].x, _edge["launch_vel"].y])
			if _leap_lines.is_empty():
				return "leaps: 0 (no monsters with leap graph)"
			return "leaps: " + str(get_tree().get_nodes_in_group("enemies").size()) + "\n" + "\n".join(_leap_lines)

		"clearleaps":
			if _leap_checker and is_instance_valid(_leap_checker):
				_leap_checker.clear_checks()
			else:
				_leap_checker = null
			return "OK: leap checks cleared"

		"bleap":
			return _cmd_bleap(parts, command)

		"testload":
			if parts.size() < 2:
				return "ERR: usage: testload <test_name>"
			return _cmd_testload(parts[1])

		"testshow":
			if _test_script.is_empty():
				return "ERR: no test loaded — use testload <name>"
			var ls: Array[String] = ["Test: %s (%d lines)" % [_test_script_name, _test_script.size()]]
			for i in range(_test_script.size()):
				ls.append("  %2d: %s" % [i + 1, _test_script[i]])
			return "\n".join(ls)

		"testedit":
			# testedit <n> <new command...>
			if parts.size() < 3:
				return "ERR: usage: testedit <line_number> <new command>"
			var ln: int = int(parts[1]) - 1
			if ln < 0 or ln >= _test_script.size():
				return "ERR: line %d out of range (1..%d)" % [ln + 1, _test_script.size()]
			# Rebuild rest of command after the line number
			var new_cmd: String = command.substr(command.find(parts[1]) + parts[1].length()).strip_edges()
			_test_script[ln] = new_cmd
			return "OK: line %d = \"%s\"" % [ln + 1, new_cmd]

		"testinsert":
			# testinsert <n> <command> — insert before line n
			if parts.size() < 3:
				return "ERR: usage: testinsert <line_number> <command>"
			var ln: int = int(parts[1]) - 1
			ln = clamp(ln, 0, _test_script.size())
			var new_cmd: String = command.substr(command.find(parts[1]) + parts[1].length()).strip_edges()
			_test_script.insert(ln, new_cmd)
			return "OK: inserted at line %d: \"%s\"" % [ln + 1, new_cmd]

		"testdelete":
			if parts.size() < 2:
				return "ERR: usage: testdelete <line_number>"
			var ln: int = int(parts[1]) - 1
			if ln < 0 or ln >= _test_script.size():
				return "ERR: line %d out of range" % [ln + 1]
			var removed: String = _test_script[ln]
			_test_script.remove_at(ln)
			return "OK: deleted line %d: \"%s\"" % [ln + 1, removed]

		"testrun":
			if _test_script.is_empty():
				return "ERR: no test loaded — use testload <name>"
			_ensure_test_runner()
			if _test_runner:
				_test_runner.run_test_script(_test_script, _test_script_name, null)
				return "OK: running script '%s' (%d lines)" % [_test_script_name, _test_script.size()]
			return "ERR: failed to create test runner"

		"testsave":
			var save_name: String = parts[1] if parts.size() > 1 else _test_script_name
			if save_name.is_empty():
				return "ERR: no name — use testsave <name>"
			return _cmd_testsave(save_name)

		"testnew":
			if parts.size() < 2:
				return "ERR: usage: testnew <name>"
			_test_script_name = parts[1]
			_test_script = ["# New test: " + parts[1], "clear", "portal off", "clearplayers", "clearzones"]
			return "OK: new test '%s' — use testshow, testedit, testrun, testsave" % parts[1]

		"notify":
			# notify <name> <message> <buttons_json> <timeout> [blocking|editor]
			# e.g.: notify observations DONE ["OK"] 600 editor
			# Message can be quoted: notify inspect "How does this look?" ["OK"] -1 blocking
			if parts.size() < 5:
				return "ERR: usage: notify <name> <message> <buttons_json> <timeout> [blocking|editor]"
			var notify_name: String = parts[1]
			# Extract message: everything between name and buttons array
			var btn_start: int = command.find("[")
			var btn_end: int = command.find("]", btn_start)
			var name_end: int = command.find(notify_name) + notify_name.length()
			var msg_raw: String = command.substr(name_end, btn_start - name_end).strip_edges()
			var notify_msg: String = msg_raw.replace("\"", "")
			var buttons_str: String = command.substr(btn_start, btn_end - btn_start + 1) if btn_start >= 0 else '["OK"]'
			var last_token: String = parts[parts.size() - 1].to_lower()
			var mode: String = "editor"  # Default: non-blocking editor banner
			var timeout_val: float = 0.0
			if last_token == "blocking" or last_token == "editor":
				mode = last_token
				timeout_val = float(parts[parts.size() - 2]) if parts.size() >= 6 else 600.0
			else:
				timeout_val = float(last_token)
			return _cmd_notify(notify_name, notify_msg, buttons_str, timeout_val, mode)

		"notify_dismiss":
			if parts.size() < 2:
				return "ERR: usage: notify_dismiss <button_label>"
			return _cmd_notify_dismiss(parts[1].replace("\"", ""))

		"emit":
			# emit <event_name> <value>
			if parts.size() < 3:
				return "ERR: usage: emit <event_name> <value>"
			return _cmd_emit(parts[1], parts[2])

		"quit":
			get_tree().quit()
			return "OK: quitting"

		"gameconfig", "gc":
			return _cmd_gameconfig(parts)

		"exec_tuning", "et":
			# Toggle the executioner tuning popup on the first player
			for p in get_tree().get_nodes_in_group("players"):
				if p.has_method("exec_tuning_toggle"):
					p.exec_tuning_toggle()
					return "OK: exec tuning %s" % ("ON" if p._exec_tuning_visible else "OFF")
			return "ERR: no executioner player found"

		"exec_set":
			# Set a tuning value: exec_set <key> <value>
			if parts.size() < 3:
				return "ERR: usage: exec_set <key> <value>"
			var key: String = parts[1]
			var val: float = float(parts[2])
			for p in get_tree().get_nodes_in_group("players"):
				if p.has_method("exec_tuning_set"):
					p.exec_tuning_set(key, val)
					return "OK: %s = %.2f" % [key, val]
			return "ERR: no executioner player found"

		"music", "m":
			return _cmd_music(parts, command)

		"strudel":
			return _cmd_strudel(parts, command)

		"ab_dismiss":
			if _ab_overlay:
				_ab_overlay.queue_free()
				_ab_overlay = null
				return "OK: dismissed"
			return "OK: no overlay"

		"ab_dir":
			# Set the output directory for A/B test files.
			# Usage: ab_dir <test_name>
			if parts.size() < 2:
				return "ab_dir: %s" % _ab_test_dir
			_ab_test_dir = parts[1]
			var full_path: String = OS.get_user_data_dir().path_join("ab").path_join(_ab_test_dir)
			DirAccess.make_dir_recursive_absolute(full_path)
			return "OK: ab_dir=%s (%s)" % [_ab_test_dir, full_path]

		"ab_compare":
			return _cmd_ab_compare(parts)

		"ab_show":
			return _cmd_ab_show(parts)

		"ab_play":
			# Play a WAV file from user://
			# Usage: ab_play <filename.wav>
			if parts.size() < 2:
				return "Usage: ab_play <filename.wav>"
			return _cmd_ab_play(parts[1])


		"musicdrawer", "md":
			# md / md open / md close
			if parts.size() > 1:
				match parts[1].to_lower():
					"open": MusicDrawer.open()
					"close": MusicDrawer.close()
					_: MusicDrawer.toggle()
			else:
				MusicDrawer.toggle()
			return "OK: music drawer %s" % ("open" if MusicDrawer.is_open() else "closed")

		"ai_spawn":
			# Spawn an AI-controlled player at a position.
			# ai_spawn [x y | @e[...] ~dx ~dy] [class=executioner] [name=id]
			# Supports absolute coords or relative to entity position.
			var ai_pos: Array = _resolve_pos(parts, 1, 960.0, 876.0)
			var spawn_x: float = ai_pos[0]
			var spawn_y: float = ai_pos[1]
			var ai_arg_start: int = ai_pos[2]
			var ai_name: String = ""
			var ai_class: String = "executioner"
			var ai_state: Dictionary = {}  # Generic key=value state to apply after spawn
			for pi in range(ai_arg_start, parts.size()):
				if parts[pi].begins_with("name="):
					ai_name = parts[pi].substr(5)
				elif parts[pi].begins_with("class="):
					ai_class = parts[pi].substr(6).to_lower()
				elif parts[pi].contains("="):
					var kv: PackedStringArray = parts[pi].split("=", true, 1)
					ai_state[kv[0]] = kv[1]
			var result: String = _cmd_ai_spawn(Vector2(spawn_x, spawn_y), ai_name, ai_class)
			if result.begins_with("OK") and not ai_state.is_empty():
				# Find the spawned player and apply state
				var spawned: Node2D = null
				for p in get_tree().get_nodes_in_group("players"):
					if p.has_method("ai_queue_cmd") and "_ai_active" in p and p._ai_active:
						spawned = p
				if spawned:
					result += _apply_entity_state(spawned, ai_state)
			return result

		"exec_test":
			# AI throw test: exec_test [angle_deg] [hold_secs] [x y]
			# Spawns AI player if needed, aims, holds L1, releases.
			var angle_deg: float = 45.0
			var hold_time: float = 1.5
			var test_pos := Vector2(960, 876)
			if parts.size() >= 2:
				angle_deg = float(parts[1])
			if parts.size() >= 3:
				hold_time = float(parts[2])
			if parts.size() >= 5:
				test_pos = Vector2(float(parts[3]), float(parts[4]))
			return _cmd_exec_test(angle_deg, hold_time, test_pos)

		"ai_cmd":
			# Queue an AI command: ai_cmd <action> <duration> [aim_x aim_y]
			# Special: ai_cmd reset 0 — resets player state
			if parts.size() < 3:
				return "ERR: usage: ai_cmd <action> <duration> [aim_x aim_y]"
			var action: String = parts[1]
			if action == "reset":
				for p in get_tree().get_nodes_in_group("players"):
					if p.has_method("reset_state"):
						p.reset_state()
						return "OK: player reset"
				return "ERR: no player"
			var duration: float = float(parts[2])
			var aim := Vector2.ZERO
			if parts.size() >= 5:
				aim = Vector2(float(parts[3]), float(parts[4]))
			var actions: Array = [action] if action != "none" else []
			for p in get_tree().get_nodes_in_group("players"):
				if p.has_method("ai_queue_cmd") and p._ai_active:
					p.ai_queue_cmd(actions, duration, aim)
					return "OK: queued %s for %.1fs" % [action, duration]
			return "ERR: no AI player"

		"ai_off":
			for p in get_tree().get_nodes_in_group("players"):
				if p.has_method("ai_set_active"):
					p.ai_set_active(false)
					p.ai_clear()
			return "OK: AI disabled"

		"reset", "player_reset":
			# Reset all players (or specific index) to default start state
			var count: int = 0
			for p in get_tree().get_nodes_in_group("players"):
				if p.has_method("reset_state"):
					p.reset_state()
					count += 1
			return "OK: reset %d players" % count

		"exec_mode":
			# Set executioner chain mode: exec_mode <release|hold_release|hold_hold>
			if parts.size() < 2:
				return "ERR: usage: exec_mode <release|hold_release|hold_hold>"
			for p in get_tree().get_nodes_in_group("players"):
				if "_exec_chain_mode" in p:
					var applied: String = _apply_entity_state(p, {"mode": parts[1]})
					if not applied.is_empty():
						return "OK:%s" % applied
					return "ERR: unknown mode '%s'. Use: release, hold_release, hold_hold" % parts[1]
			return "ERR: no executioner player found"

		"exec_get":
			# Read current tuning values: exec_get [key]
			for p in get_tree().get_nodes_in_group("players"):
				if not p.has_method("cfg"):
					continue
				if parts.size() >= 2:
					var key: String = parts[1]
					return "%s = %.2f" % [key, p.cfg(key, 0.0)]
				# Dump all tuning values
				var lines: PackedStringArray = PackedStringArray(["Executioner Tuning:"])
				if "EXEC_TUNING_KEYS" in p:
					for entry in p.EXEC_TUNING_KEYS:
						var k: String = entry[0]
						var def: float = entry[2]
						var cur: float = p.cfg(k, def)
						var changed: String = " *" if absf(cur - def) > 0.01 else ""
						lines.append("  %s = %.2f (default %.2f)%s" % [k, cur, def, changed])
				return "\n".join(lines)
			return "ERR: no player found"

		_:
			return "ERR: unknown command '%s'. Try 'help'" % cmd


func _cmd_gameconfig(parts: PackedStringArray) -> String:
	## Get/set game config values.
	## Usage: gameconfig <key> [value]
	##   gameconfig list                        — list all settings
	##   gameconfig multiple_players_same_class  — show current value
	##   gameconfig multiple_players_same_class true — set value
	var GAME_CONFIG_KEYS := {
		"multiple_players_same_class": {
			"get": func() -> Variant: return GameManager.multiple_players_same_class,
			"set": func(v: String) -> void: GameManager.multiple_players_same_class = v.to_lower() in ["true", "1", "on", "yes"],
			"type": "bool",
		},
	}

	if parts.size() < 2 or parts[1] == "list":
		var lines: PackedStringArray = PackedStringArray(["Game Config:"])
		for key in GAME_CONFIG_KEYS:
			var val: Variant = GAME_CONFIG_KEYS[key]["get"].call()
			lines.append("  %s = %s (%s)" % [key, str(val), GAME_CONFIG_KEYS[key]["type"]])
		return "\n".join(lines)

	var key: String = parts[1]
	if not GAME_CONFIG_KEYS.has(key):
		return "ERR: unknown game config key '%s'. Try 'gameconfig list'" % key

	if parts.size() < 3:
		# Get
		var val: Variant = GAME_CONFIG_KEYS[key]["get"].call()
		return "game/%s = %s" % [key, str(val)]

	# Set
	var value_str: String = parts[2]
	GAME_CONFIG_KEYS[key]["set"].call(value_str)
	var new_val: Variant = GAME_CONFIG_KEYS[key]["get"].call()
	return "OK: game/%s = %s" % [key, str(new_val)]


func _cmd_ab_compare(parts: PackedStringArray) -> String:
	## A/B spectral + timing comparison of two WAV files.
	## Usage: ab_compare <ref> <our> [hi] [shape] [onset_ms] [centroid]
	## All thresholds have sensible defaults. Set centroid=0 to skip centroid check.
	## Returns OK/FAIL with spectral, centroid, and timing analysis details.
	if parts.size() < 3:
		return "Usage: ab_compare <ref.wav> <our.wav> [hi=0.05] [shape=0.5] [onset_ms=500] [centroid=0.7]"

	var ref_path: String = _ab_path(parts[1])
	var our_path: String = _ab_path(parts[2])
	var max_hi_diff: float = float(parts[3]) if parts.size() > 3 else 0.05
	var max_shape_diff: float = float(parts[4]) if parts.size() > 4 else 0.5
	var max_onset_ms: float = float(parts[5]) if parts.size() > 5 else 500.0
	var min_centroid_r: float = float(parts[6]) if parts.size() > 6 else 0.7

	# Load WAV files
	var ref_data: PackedFloat32Array = _load_wav_mono(ref_path)
	var our_data: PackedFloat32Array = _load_wav_mono(our_path)

	if ref_data.is_empty():
		return "FAIL: can't load ref '%s'" % ref_path
	if our_data.is_empty():
		return "FAIL: can't load our '%s'" % our_path

	# Compute spectral energy in 3 bands per 100ms window
	var ref_bands: Array = _spectral_bands(ref_data, 44100)
	var our_bands: Array = _spectral_bands(our_data, 44100)

	if ref_bands.is_empty() and our_bands.is_empty():
		# Both files are silent — this is a valid match (e.g., hush test)
		return "OK: both silent — match"
	if ref_bands.is_empty():
		return "FAIL: no signal in ref (but ours has signal)"
	if our_bands.is_empty():
		return "FAIL: no signal in ours (but ref has signal)"

	# Compare: per-window spectral match + centroid correlation.
	# Catches time-varying filter differences (sweep direction, depth).
	var n: int = mini(ref_bands.size(), our_bands.size())
	var hi_diff_sum: float = 0.0
	var shape_diff_sum: float = 0.0
	var worst_window_diff: float = 0.0
	var ref_centroids: Array[float] = []
	var our_centroids: Array[float] = []

	for i in range(n):
		var r: Dictionary = ref_bands[i]
		var o: Dictionary = our_bands[i]

		hi_diff_sum += absf(float(r["hi"]) - float(o["hi"]))

		# Normalized spectral shape comparison
		var r_total: float = maxf(float(r["lo"]) + float(r["mid"]) + float(r["hi"]), 0.0001)
		var o_total: float = maxf(float(o["lo"]) + float(o["mid"]) + float(o["hi"]), 0.0001)
		var r_norm := Vector3(float(r["lo"]) / r_total, float(r["mid"]) / r_total, float(r["hi"]) / r_total)
		var o_norm := Vector3(float(o["lo"]) / o_total, float(o["mid"]) / o_total, float(o["hi"]) / o_total)
		var window_shape_diff: float = (r_norm - o_norm).length()
		shape_diff_sum += window_shape_diff
		worst_window_diff = maxf(worst_window_diff, window_shape_diff)

		ref_centroids.append(float(r["centroid"]))
		our_centroids.append(float(o["centroid"]))

	var avg_hi_diff: float = hi_diff_sum / n
	var avg_shape_diff: float = shape_diff_sum / n

	# Centroid correlation: do both sweeps move in the same direction?
	# Pearson correlation of centroid sequences. 1.0 = perfect match, 0 = no correlation.
	var centroid_corr: float = _pearson_correlation(ref_centroids, our_centroids)

	# Timing check: find first onset in each file, compare offset
	var ref_onset_ms: float = _find_first_onset_ms(ref_data, 44100)
	var our_onset_ms: float = _find_first_onset_ms(our_data, 44100)
	var onset_diff_ms: float = absf(our_onset_ms - ref_onset_ms)

	var spectral_ok: bool = avg_hi_diff <= max_hi_diff and avg_shape_diff <= max_shape_diff
	# Centroid correlation only matters if the reference has significant variation
	# (i.e., a filter sweep). For static sounds, centroid is ~constant and
	# correlation is meaningless. Check if ref centroid variance is > threshold.
	var ref_centroid_var: float = 0.0
	if not ref_centroids.is_empty():
		var c_mean: float = 0.0
		for c in ref_centroids:
			c_mean += c
		c_mean /= ref_centroids.size()
		for c in ref_centroids:
			ref_centroid_var += (c - c_mean) * (c - c_mean)
		ref_centroid_var = sqrt(ref_centroid_var / ref_centroids.size())

	# Centroid correlation only matters for dense, continuous patterns with
	# filter sweeps. For sparse patterns or static tones, centroid variance
	# comes from note-vs-silence transitions, not filter changes.
	# Check centroid density: what fraction of windows have non-negligible energy?
	# A sparse pattern (notes with gaps) has low density and centroid correlation
	# depends on exact timing alignment, making it unreliable.
	var paired_windows: int = mini(ref_centroids.size(), our_centroids.size())
	var ref_active_windows: int = 0
	for c in ref_centroids:
		if c > 10.0:  # > 10 Hz = has some meaningful energy
			ref_active_windows += 1
	var ref_density: float = float(ref_active_windows) / maxf(1.0, float(ref_centroids.size()))
	# Only check centroid when ref has high variance, enough windows, AND dense audio
	# (>60% of windows have energy = continuous sound, not sparse notes with gaps)
	# Centroid check: skip if threshold is 0, or if signal is too sparse/simple
	var centroid_matters: bool = min_centroid_r > 0.0 and ref_centroid_var > 200.0 and paired_windows >= 10 and ref_density > 0.6
	var centroid_ok: bool = true
	if centroid_matters:
		centroid_ok = centroid_corr >= min_centroid_r
	var timing_ok: bool = onset_diff_ms <= max_onset_ms

	# Per-window frequency match: compare dominant frequency in 100ms windows.
	# Uses zero-crossing rate as a cheap pitch proxy.
	# Catches pitch/timing differences that spectral averages miss.
	# Collects per-window data for diagnostic output and visual overlay.
	var win_samples: int = 4410  # 100ms at 44100Hz
	var hop_samples: int = 2205  # 50ms hop
	var compare_len: int = mini(ref_data.size(), our_data.size())
	var freq_match_count: int = 0
	var freq_total_count: int = 0
	var freq_windows: Array = []  # {time, ref_hz, our_hz, match} per window
	var pos: int = 0
	while pos + win_samples < compare_len:
		var ref_zc: int = 0
		var our_zc: int = 0
		var ref_ms: float = 0.0
		var our_ms: float = 0.0
		for j in range(1, win_samples):
			var ri: int = pos + j
			ref_ms += ref_data[ri] * ref_data[ri]
			our_ms += our_data[ri] * our_data[ri]
			if (ref_data[ri] > 0.0) != (ref_data[ri - 1] > 0.0):
				ref_zc += 1
			if (our_data[ri] > 0.0) != (our_data[ri - 1] > 0.0):
				our_zc += 1
		ref_ms /= float(win_samples)
		our_ms /= float(win_samples)
		var t: float = float(pos) / 44100.0
		if ref_ms > 0.001 and our_ms > 0.001:
			var ref_freq: float = float(ref_zc) * 44100.0 / (2.0 * float(win_samples))
			var our_freq: float = float(our_zc) * 44100.0 / (2.0 * float(win_samples))
			freq_total_count += 1
			# Match if frequencies are within 15%, OR if one is a harmonic
			# of the other (2x/0.5x ratio within 15%). Filters shift dominant
			# zero-crossing frequency to harmonics without changing the note.
			var ratio: float = our_freq / maxf(ref_freq, 1.0)
			var matched: bool = ref_freq > 10.0 and (
				absf(ratio - 1.0) < 0.15 or   # fundamental match
				absf(ratio - 2.0) < 0.15 or   # 2nd harmonic
				absf(ratio - 0.5) < 0.15)      # sub-harmonic
			if matched:
				freq_match_count += 1
			freq_windows.append({"time": t, "ref_hz": ref_freq, "our_hz": our_freq, "match": matched})
		pos += hop_samples
	var freq_match_pct: float = float(freq_match_count) / maxf(1.0, float(freq_total_count))
	# Require 60% of windows to have matching frequencies
	var freq_ok: bool = freq_total_count < 5 or freq_match_pct >= 0.6
	# Store window data for overlay generation
	_last_freq_windows = freq_windows

	# Centroid correlation gates when the reference has meaningful pitch variation
	# (dense audio with high centroid variance = multi-pitch content or filter sweeps).
	# For sparse single-pitch patterns, centroid is unreliable and skipped.
	var passed: bool = spectral_ok and timing_ok and centroid_ok and freq_ok
	var verdict: String = "OK" if passed else "FAIL"

	var reasons: Array[String] = []
	if not spectral_ok:
		reasons.append("spectral(hi=%.3f/%.3f shape=%.3f/%.3f)" % [
			avg_hi_diff, max_hi_diff, avg_shape_diff, max_shape_diff])
	if not centroid_ok:
		if centroid_matters:
			reasons.append("centroid(r=%.3f<%.1f var=%.0f den=%.2f)" % [centroid_corr, min_centroid_r, ref_centroid_var, ref_density])
		else:
			reasons.append("centroid_skip(var=%.0f den=%.2f)" % [ref_centroid_var, ref_density])
	if not timing_ok:
		reasons.append("timing(%.0fms>%.0fms)" % [onset_diff_ms, max_onset_ms])
	if not freq_ok:
		# Show worst mismatches to help diagnose the issue
		var worst: Array = []
		for fw in freq_windows:
			if not fw["match"]:
				worst.append(fw)
		worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return absf(a["ref_hz"] - a["our_hz"]) > absf(b["ref_hz"] - b["our_hz"]))
		var detail: String = ""
		for wi in range(mini(3, worst.size())):
			var w: Dictionary = worst[wi]
			detail += " @%.1fs:ref=%dHz/our=%dHz" % [w["time"], int(w["ref_hz"]), int(w["our_hz"])]
		reasons.append("freq(%.0f%% match, %d/%d windows%s)" % [freq_match_pct * 100, freq_match_count, freq_total_count, detail])

	return "%s: hi=%.4f shape=%.4f centroid_r=%.3f onset=%.0fms freq=%.0f%% %s" % [
		verdict, avg_hi_diff, avg_shape_diff, centroid_corr, onset_diff_ms, freq_match_pct * 100,
		("— " + ",".join(PackedStringArray(reasons))) if not passed else ""]


func _load_wav_mono(path: String) -> PackedFloat32Array:
	## Load a WAV file and return mono float samples.
	if not FileAccess.file_exists(path):
		print("AB: file not found: %s" % path)
		return PackedFloat32Array()
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return PackedFloat32Array()
	# Read WAV header
	var riff: String = file.get_buffer(4).get_string_from_ascii()
	if riff != "RIFF":
		return PackedFloat32Array()
	file.get_32()  # file size
	file.get_buffer(4)  # WAVE
	file.get_buffer(4)  # fmt
	var fmt_size: int = file.get_32()
	var audio_fmt: int = file.get_16()
	var channels: int = file.get_16()
	var sample_rate: int = file.get_32()
	file.get_32()  # byte rate
	file.get_16()  # block align
	var bits: int = file.get_16()
	# Skip extra fmt bytes
	if fmt_size > 16:
		file.get_buffer(fmt_size - 16)
	# Find data chunk
	while file.get_position() < file.get_length():
		var chunk_id: String = file.get_buffer(4).get_string_from_ascii()
		var chunk_size: int = file.get_32()
		if chunk_id == "data":
			var n_samples: int = chunk_size / (bits / 8)
			var n_frames: int = n_samples / channels
			var result := PackedFloat32Array()
			result.resize(n_frames)
			for i in range(n_frames):
				var sample: float = 0.0
				if bits == 16:
					var raw: int = file.get_16()
					if raw >= 32768:
						raw -= 65536  # Convert unsigned to signed
					sample = float(raw) / 32768.0
				elif bits == 32:
					sample = file.get_float()
				# Skip extra channels
				for _ch in range(channels - 1):
					if bits == 16:
						file.get_16()
					elif bits == 32:
						file.get_float()
				result[i] = sample
			return result
		else:
			file.get_buffer(chunk_size)
	return PackedFloat32Array()


func _spectral_bands(samples: PackedFloat32Array, rate: int) -> Array:
	## Compute spectral fingerprint per 100ms window.
	## Returns Array[Vector3] where x=lo, y=mid, z=hi energy.
	## Also computes spectral centroid for time-varying filter detection.
	var win: int = rate / 10  # 100ms
	var result: Array = []
	var i: int = 0
	while i + win <= samples.size():
		var peak: float = 0.0
		for j in range(i, i + win):
			peak = maxf(peak, absf(samples[j]))
		if peak < 0.003:
			i += win
			continue
		var lo: float = 0.0
		var mid: float = 0.0
		var hi: float = 0.0
		var centroid_num: float = 0.0  # Σ(freq * mag)
		var centroid_den: float = 0.0  # Σ(mag)
		for freq in range(50, 5000, 50):
			var cos_w: float = cos(TAU * freq / rate)
			var s1: float = 0.0
			var s2: float = 0.0
			var n_samp: int = mini(512, win)
			for j in range(n_samp):
				var s0: float = samples[i + j] + 2.0 * cos_w * s1 - s2
				s2 = s1
				s1 = s0
			var mag: float = sqrt(s1 * s1 + s2 * s2 - 2.0 * cos_w * s1 * s2) / n_samp
			centroid_num += freq * mag
			centroid_den += mag
			if freq < 500:
				lo += mag * mag
			elif freq < 2000:
				mid += mag * mag
			else:
				hi += mag * mag
		# Store centroid in x component of a second vector (we'll use a Dictionary instead)
		var centroid: float = centroid_num / maxf(centroid_den, 0.0001)
		result.append({"lo": sqrt(lo), "mid": sqrt(mid), "hi": sqrt(hi), "centroid": centroid})
		i += win
	return result


var _ab_player: AudioStreamPlayer = null
var _ab_test_dir: String = ""  ## Current A/B test output folder name

# Strudel multi-line block accumulator (strudel begin / strudel end)
var _strudel_block: Array[String] = []
var _strudel_block_active: bool = false
var _last_freq_windows: Array = []  ## Per-window freq data from last ab_compare

func _ab_path(filename: String) -> String:
	## Resolve a filename to the current A/B test directory.
	if _ab_test_dir.is_empty():
		return OS.get_user_data_dir().path_join(filename)
	return OS.get_user_data_dir().path_join("ab").path_join(_ab_test_dir).path_join(filename)

func _cmd_ab_play(filename: String) -> String:
	## Play a WAV file from the current A/B test directory.
	var path: String = _ab_path(filename)
	if not FileAccess.file_exists(path):
		return "ERR: file not found: %s" % path
	var wav := AudioStreamWAV.new()
	# Load raw WAV data
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return "ERR: can't open %s" % path
	# Parse WAV header
	file.get_buffer(4)  # RIFF
	file.get_32()       # file size
	file.get_buffer(4)  # WAVE
	file.get_buffer(4)  # fmt
	var fmt_size: int = file.get_32()
	var audio_fmt: int = file.get_16()
	var channels: int = file.get_16()
	var sample_rate: int = file.get_32()
	file.get_32()  # byte rate
	file.get_16()  # block align
	var bits: int = file.get_16()
	if fmt_size > 16:
		file.get_buffer(fmt_size - 16)
	# Find data chunk
	while file.get_position() < file.get_length():
		var chunk_id: String = file.get_buffer(4).get_string_from_ascii()
		var chunk_size: int = file.get_32()
		if chunk_id == "data":
			wav.data = file.get_buffer(chunk_size)
			break
		else:
			file.get_buffer(chunk_size)
	wav.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = channels > 1
	# Play it
	if _ab_player:
		_ab_player.stop()
		_ab_player.queue_free()
	_ab_player = AudioStreamPlayer.new()
	_ab_player.stream = wav
	_ab_player.finished.connect(func(): _ab_player.queue_free(); _ab_player = null)
	get_tree().root.add_child(_ab_player)
	_ab_player.play()
	return "OK: playing %s (%.1fs)" % [filename, float(wav.data.size()) / (sample_rate * channels * (bits / 8))]


func _cmd_ab_show(parts: PackedStringArray) -> String:
	## Generate spectral comparison PNG and display as overlay.
	## If ab_compare was run first, overlays freq match/mismatch markers.
	## Usage: ab_show <ref.wav> <our.wav>
	if parts.size() < 3:
		return "Usage: ab_show <ref.wav> <our.wav>"

	var ref_path: String = _ab_path(parts[1])
	var our_path: String = _ab_path(parts[2])
	var png_path: String = _ab_path("comparison.png")

	# Write freq window data from last ab_compare (if available)
	var freq_json_path: String = ""
	if not _last_freq_windows.is_empty():
		freq_json_path = _ab_path("freq_data.json")
		var json_str: String = JSON.stringify(_last_freq_windows)
		var f := FileAccess.open(freq_json_path, FileAccess.WRITE)
		if f:
			f.store_string(json_str)
			f.close()

	# Run Python spectral comparison script
	var py: String = "/var/tumu/venv/bin/python3"
	var script: String = "/var/tumu/strudel-ref/spectral_compare.py"
	var args: PackedStringArray = [script, ref_path, our_path, png_path]
	if not freq_json_path.is_empty():
		args.append(freq_json_path)
	var output: Array = []
	var exit_code: int = OS.execute(py, args, output, true)
	if exit_code != 0:
		return "ERR: spectral_compare.py failed (exit=%d) %s" % [exit_code, str(output)]

	# Load the PNG and display as overlay
	var img := Image.load_from_file(png_path)
	if img == null:
		return "ERR: can't load %s" % png_path

	var tex := ImageTexture.create_from_image(img)
	_show_ab_overlay(tex)
	return "OK: showing comparison (%dx%d)" % [img.get_width(), img.get_height()]


var _ab_overlay: CanvasLayer = null

func _show_ab_overlay(tex: ImageTexture) -> void:
	## Display a texture as a full-screen overlay. Click or Escape to dismiss.
	## Fills the screen vertically and scales width to match image aspect ratio.
	if _ab_overlay:
		_ab_overlay.queue_free()

	_ab_overlay = CanvasLayer.new()
	_ab_overlay.layer = 120  # Above everything

	# Compute panel size: fill screen height, scale width to image aspect ratio
	var img_w: float = tex.get_width()
	var img_h: float = tex.get_height()
	var aspect: float = img_w / maxf(img_h, 1.0)
	# Fill ~95% of screen height, compute width from aspect ratio
	var v_margin: float = 0.025
	var panel_h_frac: float = 1.0 - 2.0 * v_margin
	var panel_w_frac: float = minf(panel_h_frac * aspect, 0.95)  # Cap at 95% screen width
	var h_margin: float = (1.0 - panel_w_frac) / 2.0

	var panel := Panel.new()
	panel.anchor_left = h_margin
	panel.anchor_top = v_margin
	panel.anchor_right = 1.0 - h_margin
	panel.anchor_bottom = 1.0 - v_margin
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.92)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	_ab_overlay.add_child(panel)

	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = 16
	rect.offset_right = -16
	rect.offset_top = 12
	rect.offset_bottom = -28
	panel.add_child(rect)

	var label := Label.new()
	label.text = "Click to dismiss"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -24
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	panel.add_child(label)

	# Dismiss on input
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_ab_overlay.queue_free()
			_ab_overlay = null)

	get_tree().root.add_child(_ab_overlay)


func _pearson_correlation(a: Array[float], b: Array[float]) -> float:
	## Pearson correlation coefficient between two float arrays. Returns -1 to 1.
	var n: int = mini(a.size(), b.size())
	if n < 3:
		return 0.0
	var sum_a: float = 0.0
	var sum_b: float = 0.0
	for i in range(n):
		sum_a += a[i]
		sum_b += b[i]
	var mean_a: float = sum_a / n
	var mean_b: float = sum_b / n
	var cov: float = 0.0
	var var_a: float = 0.0
	var var_b: float = 0.0
	for i in range(n):
		var da: float = a[i] - mean_a
		var db: float = b[i] - mean_b
		cov += da * db
		var_a += da * da
		var_b += db * db
	var denom: float = sqrt(var_a * var_b)
	if denom < 0.0001:
		return 0.0
	return cov / denom


func _find_first_onset_ms(samples: PackedFloat32Array, rate: int, threshold: float = 0.01) -> float:
	## Find the time of the first sample above threshold.
	for i in range(samples.size()):
		if absf(samples[i]) > threshold:
			return float(i) / rate * 1000.0
	return -1.0


func _count_onsets(samples: PackedFloat32Array, rate: int, threshold: float = 0.02, min_gap_ms: float = 30.0) -> Array:
	## Detect note onsets: moments where the envelope crosses above threshold
	## after being below it for at least min_gap_ms. Returns array of onset times in seconds.
	var onsets: Array = []
	var min_gap_samples: int = int(rate * min_gap_ms / 1000.0)
	var last_onset: int = -min_gap_samples
	var was_below: bool = true
	for i in range(samples.size()):
		var above: bool = absf(samples[i]) > threshold
		if above and was_below and (i - last_onset) > min_gap_samples:
			onsets.append(float(i) / rate)
			last_onset = i
		was_below = not above
	return onsets


func _cmd_strudel_load_list() -> String:
	## List available .strudel/.js/.txt files from search paths.
	var found: Array[String] = []
	for dir_path in ["res://data/strudel/", "user://patterns/"]:
		var dir := DirAccess.open(dir_path)
		if not dir:
			continue
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".strudel") or fname.ends_with(".js") or fname.ends_with(".txt"):
				found.append("%s (%s)" % [fname.get_basename(), dir_path])
			fname = dir.get_next()
	if found.is_empty():
		return "No strudel files found. Place .strudel files in data/strudel/ or save with: strudel save <name>"
	return "Available: %s" % ", ".join(PackedStringArray(found))


func _cmd_strudel_load(path_or_name: String) -> String:
	## Load a Strudel file, preprocess it, put lines in the drawer, and play.
	## Resolves the path, reads raw lines, merges multi-line expressions,
	## and feeds the result to the music drawer.
	var resolved: String = _resolve_strudel_path(path_or_name)
	if resolved.is_empty():
		return "ERR: file not found: %s (searched res://data/strudel/, user://patterns/, and absolute)" % path_or_name
	var file := FileAccess.open(resolved, FileAccess.READ)
	if not file:
		return "ERR: cannot read %s" % resolved
	# Read all lines
	var raw_lines: Array[String] = []
	while not file.eof_reached():
		raw_lines.append(file.get_line())
	file.close()
	# Strip trailing empties from EOF
	while not raw_lines.is_empty() and raw_lines[-1].strip_edges().is_empty():
		raw_lines.pop_back()
	if raw_lines.is_empty():
		return "ERR: file is empty: %s" % resolved
	# Preprocess: merge multi-line expressions by tracking paren depth.
	# This is the same logic as strudel begin/end — a real .strudel file
	# can have stack(\n  ...,\n  ...\n) across multiple lines.
	var merged_lines: Array[String] = _merge_continuation_lines(raw_lines)
	# Expand stack(...) lines into individual voices for the drawer.
	# Each voice gets its own line with pianoroll, mute toggle, and highlights.
	var drawer_lines: Array[String] = _expand_stacks_for_drawer(merged_lines)
	# Load into drawer and play
	MusicDrawer._lines.clear()
	for bl in drawer_lines:
		MusicDrawer._lines.append(MusicDrawer._make_line(bl))
	if MusicDrawer._lines.is_empty():
		MusicDrawer._lines.append(MusicDrawer._make_line(""))
	MusicDrawer._current_line = 0
	MusicDrawer._editor_cursor = 0
	MusicDrawer.open()
	MusicDrawer._play_current()
	return "OK: loaded %s (%d raw → %d lines), playing" % [
		resolved.get_file(), raw_lines.size(), drawer_lines.size()]


func _resolve_strudel_path(path_or_name: String) -> String:
	## Resolve a strudel file path. Tries:
	## 1. Absolute path as-is
	## 2. res://data/strudel/<name> with .strudel/.js/.txt extensions
	## 3. user://patterns/<name> with .txt extension
	# Absolute or res:// path — try directly
	if path_or_name.begins_with("/") or path_or_name.begins_with("res://") or path_or_name.begins_with("user://"):
		if FileAccess.file_exists(path_or_name):
			return path_or_name
		# Try adding extensions
		for ext in [".strudel", ".js", ".txt"]:
			if FileAccess.file_exists(path_or_name + ext):
				return path_or_name + ext
		return ""
	# Short name — search directories
	var name: String = path_or_name
	for dir_path in ["res://data/strudel/", "user://patterns/"]:
		# Try with each extension
		for ext in ["", ".strudel", ".js", ".txt"]:
			var candidate: String = dir_path + name + ext
			if FileAccess.file_exists(candidate):
				return candidate
	return ""


func _expand_stacks_for_drawer(lines: Array[String]) -> Array[String]:
	## Expand stack(...) lines into individual sub-expressions for the drawer.
	## "stack(a, b, c)" becomes three lines: "a", "b", "c".
	## Standalone comments are dropped (they were between stack sub-expressions
	## in the file — noise in the drawer). The file comment at the top is kept
	## only if it's the very first line.
	var result: Array[String] = []
	for li in range(lines.size()):
		var stripped: String = lines[li].strip_edges()
		# Drop standalone comments (except the very first line as a file header)
		if stripped.begins_with("//") or stripped.begins_with("#"):
			if li == 0:
				result.append(stripped)
			continue
		if stripped.begins_with("stack(") and stripped.ends_with(")"):
			var inner: String = stripped.substr(6, stripped.length() - 7)
			var subs: Array = MusicDrawer._split_top_level_commas(inner)
			if subs.size() > 1:
				for sub in subs:
					var sub_text: String = sub["text"] if sub is Dictionary else str(sub)
					sub_text = sub_text.strip_edges()
					if not sub_text.is_empty():
						result.append(sub_text)
				continue
		result.append(stripped)
	return result


func _merge_continuation_lines(raw_lines: Array[String]) -> Array[String]:
	## Merge multi-line expressions by tracking paren depth.
	## Lines with unclosed parens are continuation lines joined with spaces.
	## Comments and blank lines are preserved as separate entries when at depth 0.
	var result: Array[String] = []
	var current: String = ""
	var depth: int = 0
	for rl in raw_lines:
		var cl: String = rl.strip_edges()
		if cl.is_empty() or cl.begins_with("//") or cl.begins_with("#"):
			if depth == 0 and not current.is_empty():
				result.append(current)
				current = ""
			if cl.begins_with("//") or cl.begins_with("#"):
				result.append(cl)
			continue
		if current.is_empty():
			current = cl
		else:
			current += " " + cl
		# Count parens (outside of quoted strings)
		var in_str: bool = false
		var str_char: String = ""
		for ci in range(cl.length()):
			var ch: String = cl[ci]
			if in_str:
				if ch == str_char:
					in_str = false
			elif ch == '"' or ch == "'":
				in_str = true
				str_char = ch
			elif ch == '(':
				depth += 1
			elif ch == ')':
				depth = maxi(0, depth - 1)
		if depth == 0:
			result.append(current)
			current = ""
	if not current.is_empty():
		result.append(current)
	return result


func _cmd_strudel_ref_code(code: String) -> String:
	## Send multi-line Strudel code to the ref server for rendering.
	## Strips display-only suffixes, joins lines with semicolons for JS eval.
	# Strip viz methods and our custom params from each line
	var clean_lines: Array[String] = []
	for line in code.split("\n"):
		var cl: String = line.strip_edges()
		if cl.is_empty() or cl.begins_with("//") or cl.begins_with("#"):
			continue
		# Strip viz methods
		for viz in [".pianoroll()", ".punchcard()", "._pianoroll()",
					".scope()", ".wordfall()", ".spiral()", ".pitchwheel()", ".fscope()"]:
			cl = cl.replace(viz, "")
		# Strip viz with options: .pianoroll({...})
		var viz_paren: int = cl.find(".pianoroll(")
		if viz_paren < 0:
			viz_paren = cl.find(".scope(")
		if viz_paren >= 0:
			var close: int = cl.find(")", viz_paren)
			if close >= 0:
				cl = cl.substr(0, viz_paren) + cl.substr(close + 1)
		# Strip cps= trailing param
		var cps_idx: int = cl.find("cps=")
		if cps_idx >= 0:
			var cps_end: int = cps_idx + 4
			while cps_end < cl.length() and cl[cps_end] != " " and cl[cps_end] != ";":
				cps_end += 1
			cl = (cl.substr(0, cps_idx) + cl.substr(cps_end)).strip_edges()
		cl = cl.strip_edges()
		if not cl.is_empty():
			clean_lines.append(cl)
	if clean_lines.is_empty():
		return "ERR: no code to send"
	# Join with spaces — preserves multi-line expressions (stack(...), etc.)
	# The ref server extracts setcps/setcpm before wrapping in `return`,
	# so the remaining code is a single expression that can be space-joined.
	var js_code: String = " ".join(PackedStringArray(clean_lines))
	var ref_result: String = _send_to_ref_server("render " + js_code)
	if ref_result.begins_with("OK:") and not _ab_test_dir.is_empty():
		var src: String = OS.get_user_data_dir().path_join("strudel_ref.wav")
		var dst: String = _ab_path("ref.wav")
		DirAccess.copy_absolute(src, dst)
		ref_result += " → %s" % dst
	return ref_result


func _send_to_ref_server(message: String) -> String:
	## Send a command to the Strudel reference server (Node.js on port 9998).
	## Returns the response string, or an error message.
	var peer := StreamPeerTCP.new()
	var err: int = peer.connect_to_host("127.0.0.1", 9998)
	if err != OK:
		return "ERR: can't connect to ref server (port 9998) — is it running?"
	# Wait for connection
	var timeout: float = 0.0
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and timeout < 2.0:
		peer.poll()
		OS.delay_msec(50)
		timeout += 0.05
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return "ERR: ref server connection timeout"
	peer.put_data((message + "\n").to_utf8_buffer())
	# Read response
	var response: String = ""
	timeout = 0.0
	while timeout < 5.0:
		peer.poll()
		if peer.get_available_bytes() > 0:
			var data: Array = peer.get_data(peer.get_available_bytes())
			if data[0] == OK:
				response += data[1].get_string_from_utf8()
				if "\n" in response:
					break
		OS.delay_msec(50)
		timeout += 0.05
	peer.disconnect_from_host()
	return response.strip_edges() if not response.is_empty() else "ERR: no response from ref server"


func _cmd_strudel(parts: PackedStringArray, command: String = "") -> String:
	## Strudel pattern engine — play mini-notation directly.
	## Usage:
	##   strudel <mini-notation>              — parse and play
	##   strudel stop                         — stop playback
	##   strudel cps <value>                  — set cycles per second
	##   strudel status                       — show scheduler state
	##   strudel hush                         — silence all
	##   strudel drawer                       — toggle music drawer
	if parts.size() < 2:
		# Show status
		var playing: String = "playing" if MusicManager._strudel_playing else "stopped"
		var cps_val: float = MusicManager._cyclist.cps if MusicManager._cyclist else 0.0
		var cycle: float = MusicManager._cyclist.now() if MusicManager._cyclist and MusicManager._strudel_playing else 0.0
		return "Strudel: %s  cps=%.2f  cycle=%.1f" % [playing, cps_val, cycle]

	var sub: String = parts[1].to_lower()
	match sub:
		"stop", "hush":
			MusicManager.strudel_stop()
			return "OK: strudel stopped"
		"begin":
			# Start accumulating multi-line Strudel block.
			# Lines are collected until "strudel end" which plays them,
			# or "strudel ref end" which sends them to the ref server.
			_strudel_block.clear()
			_strudel_block_active = true
			return "OK: strudel block started (send lines, then 'strudel end' or 'strudel ref end')"
		# "ref" is handled below in the second ref: case
		"start":
			MusicManager.strudel_start()
			return "OK: strudel %s" % ("resumed" if MusicManager._strudel_playing else "nothing to resume")
		"test":
			# Run strudel test suite: strudel test [suite_name]
			var test_node: Node = get_node_or_null("/root/StrudelTestRunner")
			if not test_node:
				var script: GDScript = load("res://scripts/music/core/strudel_test.gd")
				test_node = script.new()
				test_node.name = "StrudelTestRunner"
				get_tree().root.add_child(test_node)
			var suite_name: String = parts[2] if parts.size() > 2 else "all"
			return test_node.run(suite_name)
		"listen":
			# Shortcut: run the music listening test suite
			return _execute("run music_listen_features")
		"voices":
			if MusicManager._sion_trigger:
				var names: Array = MusicManager._sion_trigger._voices.keys()
				names.sort()
				var lines: Array[String] = ["Available voices (%d):" % names.size()]
				var row: String = " "
				for n in names:
					if row.length() + n.length() > 70:
						lines.append(row)
						row = " "
					row += " " + n
				if not row.strip_edges().is_empty():
					lines.append(row)
				lines.append("Usage: strudel c4 e4 g4 c5 sound=flute")
				return "\n".join(lines)
			return "ERR: trigger not initialized"
		"cps":
			if parts.size() < 3:
				return "cps: %.2f" % (MusicManager._cyclist.cps if MusicManager._cyclist else 0.0)
			MusicManager.strudel_set_cps(float(parts[2]))
			return "OK: cps → %.2f" % float(parts[2])
		"highlights":
			# Highlight beat tracking for visual tests.
			# strudel highlights on        — start tracking (clears previous)
			# strudel highlights off       — stop tracking
			# strudel highlights clear     — reset
			# strudel highlights           — show all beats
			# strudel highlights check <beat>:[<items>]
			#   e.g.: check 0/4:[L1:c4|L1:c5]  — at beat 0/4, both c4 and c5 highlighted
			var hl_sub: String = parts[2] if parts.size() > 2 else ""
			match hl_sub:
				"on":
					MusicDrawer._highlight_tracking = true
					MusicDrawer._highlight_beats.clear()
					MusicDrawer._highlight_seen.clear()
					return "OK: highlight tracking on"
				"off":
					MusicDrawer._highlight_tracking = false
					return "OK: highlight tracking off"
				"clear":
					MusicDrawer._highlight_beats.clear()
					MusicDrawer._highlight_seen.clear()
					return "OK: highlights cleared"
				"check":
					# strudel highlights check 0/4:[L1:c4|L1:c5]
					if parts.size() < 4:
						return "Usage: strudel highlights check <beat>:[<items>]"
					var check_arg: String = parts[3]
					var colon_pos: int = check_arg.find(":[")
					if colon_pos < 0:
						return "Usage: strudel highlights check <beat>:[L1:c4|L1:c5]"
					var beat_key: String = check_arg.substr(0, colon_pos)
					var items_str: String = check_arg.substr(colon_pos + 2)
					if items_str.ends_with("]"):
						items_str = items_str.substr(0, items_str.length() - 1)
					var expected_items: PackedStringArray = items_str.split("|")
					var actual_items: Array = MusicDrawer._highlight_beats.get(beat_key, [])
					var missing: Array[String] = []
					for want in expected_items:
						var w: String = want.strip_edges()
						if w not in actual_items:
							missing.append(w)
					if missing.is_empty():
						return "OK: beat %s has [%s] (%d items)" % [beat_key,
							"|".join(PackedStringArray(actual_items)), actual_items.size()]
					else:
						return "FAIL: beat %s missing [%s]. actual=[%s]" % [beat_key,
							"|".join(PackedStringArray(missing)),
							"|".join(PackedStringArray(actual_items)) if not actual_items.is_empty() else "empty"]
				_:
					# Show all beats sorted by fraction value
					if not MusicDrawer:
						return "ERR: MusicDrawer not available"
					var beats: Dictionary = MusicDrawer._highlight_beats
					var keys: Array = beats.keys()
					# Sort by numeric value of fraction
					keys.sort_custom(func(a: String, b: String) -> bool:
						var ap: PackedStringArray = a.split("/")
						var bp: PackedStringArray = b.split("/")
						var av: float = float(ap[0]) / maxf(float(ap[1]), 1.0) if ap.size() == 2 else float(a)
						var bv: float = float(bp[0]) / maxf(float(bp[1]), 1.0) if bp.size() == 2 else float(b)
						return av < bv)
					var lines: Array[String] = ["highlights (%d beats, tracking=%s):" % [
						keys.size(), "on" if MusicDrawer._highlight_tracking else "off"]]
					for k in keys:
						lines.append("  %s:[%s]" % [k, "|".join(PackedStringArray(beats[k]))])
					return "\n".join(lines)
		"status":
			var lines: Array[String] = ["Strudel Engine:"]
			lines.append("  playing: %s" % str(MusicManager._strudel_playing))
			if MusicManager._cyclist:
				lines.append("  cps: %.2f  (%.0f BPM)" % [MusicManager._cyclist.cps, MusicManager._cyclist.cps * 120.0])
				lines.append("  cycle: %.2f" % MusicManager._cyclist.now())
				lines.append("  started: %s" % str(MusicManager._cyclist.started))
			if MusicManager._strudel_pattern:
				var haps: Array = MusicManager._strudel_pattern.first_cycle()
				lines.append("  pattern: %d haps/cycle" % haps.size())
				for h in haps.slice(0, 8):
					lines.append("    %s" % h.show(true))
				if haps.size() > 8:
					lines.append("    ... +%d more" % (haps.size() - 8))
			# Effects status
			lines.append(MusicManager.get_effects_status())
			return "\n".join(lines)
		"effects", "fx":
			# Show or control audio effects
			if parts.size() < 3:
				return MusicManager.get_effects_status()
			if parts[2] == "off" or parts[2] == "reset":
				MusicManager.reset_music_effects()
				return "OK: all effects disabled"
			# Parse key=value pairs: strudel fx lpf=800 room=0.5
			var fx_controls: Dictionary = {}
			for i in range(2, parts.size()):
				var eq_idx: int = parts[i].find("=")
				if eq_idx > 0:
					var key: String = parts[i].substr(0, eq_idx)
					var val_str: String = parts[i].substr(eq_idx + 1)
					if val_str.is_valid_float():
						fx_controls[key] = float(val_str)
			if fx_controls.is_empty():
				return MusicManager.get_effects_status()
			MusicManager.set_music_effects(fx_controls)
			var fx_parts: Array[String] = []
			for k in fx_controls:
				fx_parts.append("%s=%.1f" % [k, fx_controls[k]])
			return "OK: effects set [%s]" % ", ".join(PackedStringArray(fx_parts))
		"ref":
			# Reference render: send pattern to Strudel Node.js server (port 9998)
			# Renders real Strudel output to WAV for A/B comparison.
			# Saves to current ab_dir as ref.wav.
			# Usage: strudel ref <strudel_code> OR strudel ref begin (multi-line)
			# Strips display-only suffixes (.pianoroll(), cps=) so tests can
			# pass the IDENTICAL string to both "strudel ref" and "strudel edit".
			if parts.size() > 2 and parts[2] == "begin":
				_strudel_block.clear()
				_strudel_block_active = true
				return "OK: strudel ref block started (send lines, then 'strudel ref end')"
			if parts.size() < 3:
				return "Usage: strudel ref <strudel_pattern_code>"
			var ref_code: String = command.substr(command.find("ref ") + 4).strip_edges()
			# Strip display-only suffixes the ref server doesn't understand
			for viz in [".pianoroll()", ".punchcard()", "._pianoroll()",
						".bar()", ".scope()", ".wordfall()"]:
				ref_code = ref_code.replace(viz, "")
			# Strip cps=<value> parameter
			var cps_idx: int = ref_code.find("cps=")
			if cps_idx >= 0:
				var cps_end: int = cps_idx + 4
				while cps_end < ref_code.length() and ref_code[cps_end] != " ":
					cps_end += 1
				ref_code = (ref_code.substr(0, cps_idx) + ref_code.substr(cps_end)).strip_edges()
			var ref_result: String = _send_to_ref_server("render " + ref_code)
			# Copy rendered file to ab test dir
			if ref_result.begins_with("OK:") and not _ab_test_dir.is_empty():
				var src: String = OS.get_user_data_dir().path_join("strudel_ref.wav")
				var dst: String = _ab_path("ref.wav")
				DirAccess.copy_absolute(src, dst)
				ref_result += " → %s" % dst
			return ref_result
		"ref_block":
			# Internal: called when strudel ref end finishes a block
			return "OK: ref_block (handled in _execute block accumulator)"

		"record":
			# Audio recording: strudel record start|stop [filename]
			if parts.size() < 3:
				return "Usage: strudel record start|stop [filename]"
			match parts[2]:
				"start":
					return MusicManager.record_start()
				"stop":
					var fname: String = parts[3] if parts.size() > 3 else "recording"
					var result: String = MusicManager.record_stop(fname)
					# Copy to ab test dir if set
					if result.begins_with("OK:") and not _ab_test_dir.is_empty():
						var src: String = OS.get_user_data_dir().path_join("%s.wav" % fname)
						var dst: String = _ab_path("%s.wav" % fname)
						DirAccess.copy_absolute(src, dst)
						result += " → %s" % dst
					return result
				_:
					return "Usage: strudel record start|stop [filename]"
		"test_seq":
			# Diagnostic: test sequence_on directly
			return MusicManager.test_sequence_on()
		"mode":
			# Scheduling mode: batch (MML sequence_on) or note (per-note note_on)
			if not MusicManager._sion_trigger or not MusicManager._cyclist:
				return "ERR: strudel engine not initialized"
			if parts.size() < 3:
				var mode: String = "batch" if MusicManager._cyclist.batch_mode else "note"
				return "Scheduling mode: %s" % mode
			match parts[2]:
				"batch":
					MusicManager._cyclist.batch_mode = true
					MusicManager._sion_trigger.batch_mode = true
					return "OK: batch mode (MML → sequence_on, sample-accurate)"
				"note":
					MusicManager._cyclist.batch_mode = false
					MusicManager._sion_trigger.batch_mode = false
					MusicManager._sion_trigger.stop_all_sequences()
					return "OK: note mode (per-note note_on, frame-accurate)"
				_:
					return "Usage: strudel mode batch|note"
		"timing":
			# Timing instrumentation: strudel timing on|off|report
			if not MusicManager._sion_trigger:
				return "ERR: trigger not initialized"
			if parts.size() < 3:
				return MusicManager._sion_trigger.timing_analyze()
			match parts[2]:
				"on", "start":
					MusicManager._sion_trigger.timing_start()
					return "OK: timing capture started"
				"off", "stop":
					return MusicManager._sion_trigger.timing_stop()
				"clear":
					MusicManager._sion_trigger._timing_records.clear()
					return "OK: timing records cleared"
				_:
					return "Usage: strudel timing on|off|report|clear"
		"drawer":
			MusicDrawer.toggle()
			return "OK: music drawer %s" % ("open" if MusicDrawer.is_open() else "closed")
		"save":
			# Save current drawer lines to a .txt file
			# strudel save <filename>
			if parts.size() < 3:
				return "ERR: usage: strudel save <filename>"
			var save_name: String = parts[2].strip_edges()
			if not save_name.ends_with(".txt"):
				save_name += ".txt"
			var save_path: String = "user://patterns/" + save_name
			DirAccess.make_dir_recursive_absolute("user://patterns/")
			var save_file := FileAccess.open(save_path, FileAccess.WRITE)
			if not save_file:
				return "ERR: cannot write to %s" % save_path
			for line_dict in MusicDrawer._lines:
				save_file.store_line(line_dict.get("text", ""))
			save_file.close()
			return "OK: saved %d lines to %s" % [MusicDrawer._lines.size(), save_path]
		"load":
			# Load a Strudel file into the drawer and play it.
			# strudel load <path_or_name>
			# Accepts: absolute paths, res:// paths, or short names (searched in
			# res://data/strudel/, user://patterns/, with .strudel/.js/.txt extensions).
			# Multi-line expressions (stack(...)) are merged via paren-depth tracking.
			if parts.size() < 3:
				return _cmd_strudel_load_list()
			var load_arg: String = command.substr(command.find("load") + 5).strip_edges()
			return _cmd_strudel_load(load_arg)
		"edit":
			# Set drawer lines directly and play. Lines separated by |
			# strudel edit drums: c4(3,8).pianoroll() | bass: c2 ~ e2 ~.bar() | melody: c4 e4 g4 c5
			if parts.size() < 3:
				return "ERR: usage: strudel edit <line1> | <line2> | ..."
			var edit_text: String = command.substr(command.find("edit") + 5).strip_edges()
			var edit_cps: float = -1.0
			var cps_match: int = edit_text.find("cps=")
			if cps_match >= 0:
				var cps_val: String = edit_text.substr(cps_match + 4).strip_edges()
				var sp: int = cps_val.find(" ")
				if sp >= 0:
					cps_val = cps_val.substr(0, sp)
				if cps_val.find("|") >= 0:
					cps_val = cps_val.substr(0, cps_val.find("|"))
				edit_cps = float(cps_val.strip_edges())
				edit_text = (edit_text.substr(0, cps_match) + edit_text.substr(cps_match + 4 + cps_val.length())).strip_edges()
			# Split into lines and set on the drawer
			var edit_lines: Array = edit_text.split("|")
			MusicDrawer._lines.clear()
			for el in edit_lines:
				MusicDrawer._lines.append(MusicDrawer._make_line(el.strip_edges()))
			MusicDrawer._current_line = 0
			MusicDrawer._editor_cursor = 0
			MusicDrawer.open()
			# Eval (plays all lines stacked)
			if edit_cps > 0:
				MusicDrawer._cps = edit_cps
			MusicDrawer._play_current()
			return "OK: drawer set with %d lines, playing" % edit_lines.size()
		_:
			# Everything else is mini-notation
			var mini_text: String = command.substr(command.find(" ") + 1).strip_edges()
			# Parse optional key=value parameters at the end
			var mini_cps: float = -1.0
			var mini_sound: String = ""
			var mini_controls: Dictionary = {}
			# Audio control key=value params (lpf=800, room=0.5, etc.)
			var control_params := ["lpf=", "hpf=", "lpq=", "hpq=",
				"room=", "roomsize=", "roomlp=",
				"delay=", "delaytime=", "delayfeedback=",
				"distort=", "crush=", "shape=", "pan="]
			# Extract cps=, sound=, and audio controls from the tail
			for param in ["cps=", "sound=", "s="] + control_params:
				var p_idx: int = mini_text.find(param)
				if p_idx >= 0:
					var p_val: String = mini_text.substr(p_idx + param.length()).strip_edges()
					# Value ends at next space or end of string
					var space_idx: int = p_val.find(" ")
					if space_idx >= 0:
						p_val = p_val.substr(0, space_idx)
					if param == "cps=":
						mini_cps = float(p_val)
					elif param == "sound=" or param == "s=":
						mini_sound = p_val
					else:
						# Audio control: strip trailing "="
						var key: String = param.substr(0, param.length() - 1)
						if p_val.is_valid_float():
							mini_controls[key] = float(p_val)
					mini_text = (mini_text.substr(0, p_idx) + mini_text.substr(p_idx + param.length() + p_val.length())).strip_edges()
			var pat: StrudelPattern = StrudelMini.mini(mini_text)
			var display_text: String = mini_text + (" s=%s" % mini_sound if not mini_sound.is_empty() else "")
			# Apply sound/voice if specified
			if not mini_sound.is_empty():
				pat = pat.set_in(Strudel.pure({"s": mini_sound}))
			# Inject audio controls into every hap so the trigger can
			# read them per-note and update bus effects in realtime.
			if not mini_controls.is_empty():
				pat = pat.set_in(Strudel.pure(mini_controls))
			MusicManager.strudel_play(pat, mini_cps, display_text)
			# Also apply bus effects immediately (don't wait for first trigger)
			if mini_controls.is_empty():
				MusicManager.reset_music_effects()
			else:
				MusicManager.set_music_effects(mini_controls)
			var hap_count: int = pat.first_cycle().size()
			var fx_str: String = ""
			if not mini_controls.is_empty():
				var fx_parts: Array[String] = []
				for k in mini_controls:
					fx_parts.append("%s=%.1f" % [k, mini_controls[k]])
				fx_str = " fx=[%s]" % ", ".join(PackedStringArray(fx_parts))
			return "OK: strudel '%s' (%d haps/cycle%s%s)" % [
				mini_text, hap_count,
				" sound=%s" % mini_sound if not mini_sound.is_empty() else "",
				fx_str]



func _cmd_music(parts: PackedStringArray, command: String = "") -> String:
	## Music system control.
	## Usage: music [subcmd] [args...]
	if parts.size() < 2:
		return MusicManager.get_status_text()

	var sub: String = parts[1].to_lower()
	match sub:
		"help":
			return """Music System Commands:
  music                    — show status
  music help               — this help text

  --- MML Playback ---
  music play               — start adaptive layer system
  music stop               — stop adaptive layers
  music off                — stop ALL music (layers + strudel + MML)
  music test               — play GDSiON test tone
  music score <name>       — play a named MML score
  music scores             — list all available scores
  music mml <string>       — play arbitrary MML notation

  --- Strudel Pattern Engine ---
  strudel <mini-notation>  — parse and play a pattern
  strudel stop             — stop strudel playback
  strudel cps <value>      — set cycles per second
  strudel status           — show scheduler state
  strudel drawer           — toggle music drawer
  strudel fx [key=val ...]  — show/set audio effects (lpf, room, delay, etc.)
  strudel fx off            — disable all audio effects
  strudel test [suite]     — run unit tests (all/algebra/mini/integration/voices)
  strudel listen           — run listening test (uses test runner: Ctrl+D)
  run music_listen_features — same thing via test runner directly
  suite music              — run music test suite

  --- Audio Controls (append to strudel command or use .method() in drawer) ---
  lpf=800           — low-pass filter cutoff Hz (bus-level)
  hpf=200           — high-pass filter cutoff Hz (bus-level)
  room=0.5          — reverb wet amount 0-1 (bus-level, same as Strudel)
  delay=0.5         — delay wet amount 0-1 (bus-level, same as Strudel)
  distort=0.3       — distortion drive 0-1 (bus-level)
  crush=8           — bit crush 1-16 (bus-level, lofi mode)
  pan=0.5           — stereo pan -1 to 1 (bus-level)
  Drawer syntax: "c4 e4".lpf(800).room(0.5).pianoroll()

  --- Mini-Notation Syntax ---
  c4 e4 g4         sequence (space-separated)
  [c4 e4]          sub-cycle (fits in one slot)
  [c4,e4,g4]       stack / chord (simultaneous)
  <c4 e4 g4>       slowcat (one per cycle)
  c4*2             fast (play twice as fast)
  c4/2             slow (stretch over 2 cycles)
  c4(3,8)          euclidean rhythm (3 pulses in 8 steps)
  c4?              degrade (randomly drop ~50%)
  c4?0.3           degrade with probability 0.3
  c4!3             replicate 3 times
  ~                silence / rest
  c4:2             tail (sets sample index)
  [c4|e4|g4]       random choose (one per cycle)

  --- Adaptive Layers ---
  music intensity <0-1>    — set music intensity
  music push <amount>      — add to intensity
  music tempo <bpm>        — set tempo (70-160)
  music layer [name] [on|off] — toggle layer (pad/bass/drums/melody)
  music mute / unmute      — mute/unmute all layers
  music combat             — simulate combat start
  music calm               — simulate combat end

  --- Music Drawer (Ctrl+M) ---
  musicdrawer              — toggle drawer (alias: md)

  Multi-line live-coding editor. Each line = independent pattern.
  All non-muted lines play stacked (simultaneous).

  Line format:
    drums: c4(3,8)              — named line (Strudel label syntax)
    bass: c2 ~ e2 ~ s=bass     — named + voice override
    c4 e4 g4 c5                 — auto-named d1, d2, ...
    # comment                   — skipped

  Enter: new line    Ctrl+Enter: evaluate all lines
  Up/Down: move between lines   Ctrl+/: toggle mute
  Ctrl+Shift+K: delete line     Backspace@col0: join lines
  Ctrl+A/E/K/U/W/Y: emacs      Ctrl+C/X/V: clipboard
  Shift+arrows: selection
  Pianoroll + source highlighting update live."""
		"play":
			MusicManager.play()
			return "OK: music playing"
		"stop":
			MusicManager.stop()
			return "OK: music stopped"
		"test":
			MusicManager.play_test_tone()
			return "OK: test tone"
		"intensity", "i":
			if parts.size() < 3:
				return "intensity: %.2f (target: %.2f)" % [MusicManager.intensity, MusicManager._target_intensity]
			var val: float = float(parts[2])
			MusicManager.set_intensity(val)
			return "OK: intensity → %.2f" % val
		"tempo", "bpm":
			if parts.size() < 3:
				return "tempo: %d BPM" % MusicManager._bpm
			var bpm: int = int(parts[2])
			MusicManager.set_tempo(bpm)
			return "OK: tempo → %d BPM" % bpm
		"layer":
			if parts.size() < 3:
				# List layers
				var lines: PackedStringArray = PackedStringArray(["Layers:"])
				for ln in MusicManager._layers:
					var l: MusicManager.LayerState = MusicManager._layers[ln]
					lines.append("  %s: %s (enabled=%s, active=%s, variant=%d)" % [
						l.name, "ON" if l.active else "off",
						"yes" if l.enabled else "no", "yes" if l.active else "no",
						l.current_variant])
				return "\n".join(lines)
			var layer_name: String = parts[2].to_lower()
			if parts.size() >= 4:
				var on_off: String = parts[3].to_lower()
				MusicManager.set_layer_enabled(layer_name, on_off in ["on", "true", "1", "yes"])
				return "OK: layer '%s' %s" % [layer_name, "enabled" if on_off in ["on", "true", "1", "yes"] else "disabled"]
			# Toggle
			if MusicManager._layers.has(layer_name):
				var layer: MusicManager.LayerState = MusicManager._layers[layer_name]
				MusicManager.set_layer_enabled(layer_name, not layer.enabled)
				return "OK: layer '%s' %s" % [layer_name, "enabled" if layer.enabled else "disabled"]
			return "ERR: unknown layer '%s'" % layer_name
		"mute":
			MusicManager.mute()
			return "OK: muted"
		"unmute":
			MusicManager.unmute()
			return "OK: unmuted"
		"push":
			if parts.size() < 3:
				return "ERR: usage: music push <amount>"
			var amount: float = float(parts[2])
			MusicManager.push_intensity(amount)
			return "OK: pushed +%.2f → %.2f" % [amount, MusicManager._target_intensity]
		"combat":
			MusicManager.on_combat_start()
			return "OK: combat start event fired"
		"calm":
			MusicManager.on_combat_end()
			return "OK: combat end event fired"
		"score":
			if parts.size() < 3:
				return MusicManager.get_score_list()
			return MusicManager.play_score(parts[2].to_lower())
		"scores":
			return MusicManager.get_score_list()
		"mml":
			# Play arbitrary MML: music mml <mml_string>
			# Everything after "mml" is the MML data (preserves spaces in MML)
			if parts.size() < 3:
				return "ERR: usage: music mml <mml_string>"
			var mml_idx: int = command.find("mml")
			var mml_text: String = command.substr(mml_idx + 3).strip_edges() if mml_idx >= 0 else " ".join(parts.slice(2))
			MusicManager.play_mml(mml_text)
			return "OK: playing MML (%d chars)" % mml_text.length()
		"off":
			# Stop everything (layered, title, direct, strudel)
			MusicManager.stop()
			MusicManager.stop_title_music()
			MusicManager.stop_direct()
			MusicManager.strudel_stop()
			return "OK: all music stopped"
		"pat", "pattern":
			# Play a Strudel pattern from note names
			# music pat c4 e4 g4 c5          — sequence of notes
			# music pat c4 e4 g4 c5 cps=0.5  — with CPS
			if parts.size() < 3:
				return "ERR: usage: music pat <note1> <note2> ... [cps=<value>]"
			var notes: Array = []
			var pat_cps: float = -1.0
			for i in range(2, parts.size()):
				if parts[i].begins_with("cps="):
					pat_cps = float(parts[i].substr(4))
				else:
					notes.append(Strudel.pure(parts[i]))
			if notes.is_empty():
				return "ERR: no notes specified"
			var pat: StrudelPattern = Strudel.sequence(notes)
			var note_names: Array = []
			for i in range(2, parts.size()):
				if not parts[i].begins_with("cps="):
					note_names.append(parts[i])
			MusicManager.strudel_play(pat, pat_cps, " ".join(PackedStringArray(note_names)))
			return "OK: playing pattern (%d notes, cps=%.2f)" % [notes.size(), MusicManager._cyclist.cps if MusicManager._cyclist else 0.0]
		"cps":
			if parts.size() < 3:
				return "cps: %.2f" % (MusicManager._cyclist.cps if MusicManager._cyclist else 0.0)
			MusicManager.strudel_set_cps(float(parts[2]))
			return "OK: cps → %.2f" % float(parts[2])
		"strudel", "s":
			# Play a mini-notation string via Strudel engine
			# music strudel c4 e4 [g4 g4] c5
			# Everything after "strudel" is the mini-notation
			if parts.size() < 3:
				return "ERR: usage: music strudel <mini-notation>"
			var mini_idx: int = command.find(sub) + sub.length()
			var mini_text: String = command.substr(mini_idx).strip_edges()
			# Parse optional cps= at the end
			var mini_cps: float = -1.0
			if mini_text.ends_with(")") or mini_text.find("cps=") >= 0:
				var cps_idx: int = mini_text.find("cps=")
				if cps_idx >= 0:
					mini_cps = float(mini_text.substr(cps_idx + 4).strip_edges())
					mini_text = mini_text.substr(0, cps_idx).strip_edges()
			var mini_pat: StrudelPattern = StrudelMini.mini(mini_text)
			MusicManager.strudel_play(mini_pat, mini_cps, mini_text)
			var hap_count: int = mini_pat.first_cycle().size()
			return "OK: strudel '%s' (%d haps/cycle, cps=%.2f)" % [
				mini_text, hap_count, MusicManager._cyclist.cps if MusicManager._cyclist else 0.0]
		_:
			return "ERR: unknown music command '%s'. Try: play, stop, off, test, score, scores, mml, pat, cps, intensity, tempo, layer, mute, unmute, push, combat, calm" % sub


func _cmd_teleport(parts: PackedStringArray) -> String:
	var players: Array = get_tree().get_nodes_in_group("players")
	var pi: int = 0
	var x: float
	var y: float

	if parts.size() >= 4:
		pi = int(parts[1])
		x = float(parts[2])
		y = float(parts[3])
	else:
		x = float(parts[1])
		y = float(parts[2])

	# Find by index or just grab the nth player in the group
	if pi < players.size():
		var p: Node = players[pi]
		if p is CharacterBody2D:
			p.global_position = Vector2(x, y)
			p.velocity = Vector2.ZERO
			return "OK: teleported %s to (%.0f, %.0f)" % [p.name, x, y]

	return "ERR: player %d not found (have %d)" % [pi, players.size()]


func _cmd_test(what: String) -> String:
	match what:
		"precog":
			# Automated precog test: cycles through positions
			# Results are printed to Godot log
			var positions := [
				Vector2(960, 520),   # Upper center (on P3/P4 level)
				Vector2(400, 740),   # On P1
				Vector2(1400, 740),  # On P2
				Vector2(200, 880),   # Floor left
				Vector2(1600, 880),  # Floor right
				Vector2(670, 520),   # On P3
				Vector2(1250, 520),  # On P4
			]
			# Teleport to first position, force precog
			# Subsequent positions handled by the game loop
			var players: Array = get_tree().get_nodes_in_group("players")
			if players.is_empty():
				return "ERR: no players"
			var p: Node = players[0]
			p.global_position = positions[0]
			p.velocity = Vector2.ZERO
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.has_method("_start_precognition"):
					e._start_precognition()
			return "OK: test precog started — P0 at (%.0f, %.0f)" % [positions[0].x, positions[0].y]
		_:
			return "ERR: unknown test '%s'" % what


func _resolve_pos(parts: PackedStringArray, start_idx: int, default_x: float = 960.0, default_y: float = 750.0) -> Array:
	## Resolve a position from command parts starting at start_idx.
	## Supports Minecraft-style relative coordinates:
	##   960 876              → absolute (960, 876)
	##   @e[name=AI] ~150 ~0  → entity pos + (150, 0)
	##   @e[name=AI] ~ ~      → entity pos exactly
	##   @e[name=AI]           → entity pos (no tilde args)
	## Returns [x: float, y: float, next_idx: int]
	if start_idx >= parts.size():
		return [default_x, default_y, start_idx]

	var token: String = parts[start_idx]

	# Check for entity selector: @e[...]
	if token.begins_with("@e["):
		var base_pos: Vector2 = _resolve_entity_pos(token)
		if base_pos == Vector2.INF:
			return [default_x, default_y, start_idx + 1]
		var next_idx: int = start_idx + 1
		var rx: float = base_pos.x
		var ry: float = base_pos.y
		# Check for ~X ~Y after the selector
		if next_idx < parts.size() and parts[next_idx].begins_with("~"):
			rx = base_pos.x + _parse_tilde(parts[next_idx])
			next_idx += 1
		if next_idx < parts.size() and parts[next_idx].begins_with("~"):
			ry = base_pos.y + _parse_tilde(parts[next_idx])
			next_idx += 1
		return [rx, ry, next_idx]

	# Check for absolute coordinates: two numbers
	if start_idx + 1 < parts.size() and token.is_valid_float() and parts[start_idx + 1].is_valid_float():
		return [float(token), float(parts[start_idx + 1]), start_idx + 2]

	# Single number or non-matching — return defaults
	return [default_x, default_y, start_idx]


func _resolve_entity_pos(token: String) -> Vector2:
	## Resolve an @e[key=value] selector to its world position.
	## Returns Vector2.INF if not found.
	if not token.begins_with("@e["):
		return Vector2.INF
	var bracket_end: int = token.find("]")
	if bracket_end < 0:
		return Vector2.INF
	var inner: String = token.substr(3, bracket_end - 3)
	var all_nodes: Array = get_tree().get_nodes_in_group("enemies") + \
		get_tree().get_nodes_in_group("players") + \
		get_tree().get_nodes_in_group("entities") + \
		get_tree().get_nodes_in_group("attack_dummies")
	for node in all_nodes:
		if not is_instance_valid(node) or not node is Node2D:
			continue
		for pair in inner.split(","):
			var eq: int = pair.find("=")
			if eq > 0:
				var key: String = pair.substr(0, eq)
				var val: String = pair.substr(eq + 1)
				match key:
					"name":
						if node.name == val or ("entity_id" in node and str(node.entity_id) == val):
							return node.global_position
	return Vector2.INF


func _parse_tilde(token: String) -> float:
	## Parse a tilde-prefixed coordinate: ~ → 0, ~50 → 50, ~-50 → -50
	if token == "~":
		return 0.0
	return float(token.substr(1))


func _cmd_spawn(what: String, x: float = 960.0, y: float = 750.0, state: String = "", spawn_scale: float = 1.0, spawn_pathing_radius: float = -1.0, spawn_config: Dictionary = {}) -> String:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return "ERR: no current scene"

	# Extract optional name= from config (used to name the entity)
	var custom_name: String = spawn_config.get("name", "")
	spawn_config.erase("name")

	var container: Node = scene_root.get_node_or_null("Players")
	if not container:
		container = scene_root

	match what:
		"monster":
			var script := load("res://scripts/enemies/quadruped_monster.gd")
			var monster := CharacterBody2D.new()
			monster.set_script(script)
			# Set scale and pathing radius BEFORE _ready() so _init_skeleton() uses them
			monster.creature_scale = spawn_scale
			monster.pathing_radius = spawn_pathing_radius
			monster.global_position = Vector2(x, y)
			var monster_count: int = get_tree().get_nodes_in_group("enemies").size()
			monster.entity_id = custom_name if not custom_name.is_empty() else "monster_%d" % monster_count
			container.add_child(monster)
			# Apply optional initial state
			if state == "standdown":
				monster._standdown = true
			# Apply runtime config overrides
			if not spawn_config.is_empty():
				monster.apply_config(spawn_config)
			var scale_str: String = " scale=%.1f" % spawn_scale if spawn_scale != 1.0 else ""
			var state_str: String = " (%s)" % state if not state.is_empty() else ""
			var config_str: String = " config=%s" % str(spawn_config) if not spawn_config.is_empty() else ""
			return "OK: spawned monster '%s' at (%.0f, %.0f)%s%s%s" % [monster.entity_id, x, y, state_str, scale_str, config_str]

		"dummy":
			# Soccer ball dummy — a rolling ball that monsters can target.
			var dummy_script: GDScript = load("res://scripts/testing/soccer_dummy.gd")
			var dummy := CharacterBody2D.new()
			dummy.set_script(dummy_script)
			var dummy_count: int = get_tree().get_nodes_in_group("players").size()
			var dummy_id: String = custom_name if not custom_name.is_empty() else "dummy_%d" % dummy_count
			dummy.name = dummy_id
			dummy.add_to_group("players")
			dummy.global_position = Vector2(x, y)
			dummy.player_index = 0
			dummy.collision_layer = 2  # Player layer
			dummy.collision_mask = 1   # World
			dummy.entity_id = dummy_id
			container.add_child(dummy)
			var dummy_result: String = "OK: spawned dummy '%s' at (%.0f, %.0f)" % [dummy.entity_id, x, y]
			if not spawn_config.is_empty():
				dummy_result += _apply_entity_state(dummy, spawn_config)
			return dummy_result

		"player_monster":
			# Spawn a player-controlled monster. device=-1 for keyboard, 0+ for controller.
			# Pass device=N via key=value args (parsed into spawn_config by caller)
			var pm_device: int = int(spawn_config.get("device", "-1"))
			var script := load("res://scripts/enemies/quadruped_monster.gd")
			var monster := CharacterBody2D.new()
			monster.set_script(script)
			monster.creature_scale = spawn_scale
			monster.pathing_radius = spawn_pathing_radius
			monster.global_position = Vector2(x, y)
			var monster_count: int = get_tree().get_nodes_in_group("enemies").size()
			monster.entity_id = custom_name if not custom_name.is_empty() else "player_monster_%d" % monster_count
			# Set up player controller BEFORE add_child (which calls _ready)
			var PlayerCtrlScript: GDScript = load("res://scripts/enemies/monster_player_controller.gd")
			var ctrl: RefCounted = PlayerCtrlScript.new()
			ctrl.device_id = pm_device
			ctrl.player_index = 0
			monster._controller = ctrl  # Pre-set so _ready() doesn't override with AI
			container.add_child(monster)
			if not spawn_config.is_empty():
				monster.apply_config(spawn_config)
			var scale_str: String = " scale=%.1f" % spawn_scale if spawn_scale != 1.0 else ""
			var device_str: String = "keyboard" if pm_device == -1 else "controller %d" % pm_device
			return "OK: spawned player_monster '%s' at (%.0f, %.0f)%s (%s)" % [monster.entity_id, x, y, scale_str, device_str]

		"attacker":
			var script := load("res://scripts/testing/attack_dummy.gd")
			var attacker := CharacterBody2D.new()
			attacker.set_script(script)
			attacker.name = "AttackDummy"
			attacker.global_position = Vector2(x, y)
			container.add_child(attacker)
			return "OK: spawned attacker at (%.0f, %.0f)" % [x, y]

		_:
			return "ERR: unknown spawn type '%s'. Try: monster, dummy, attacker, player_monster" % what


func _cmd_key(key_str: String) -> String:
	## Simulate a key press via InputEventKey.
	var event := InputEventKey.new()
	event.pressed = true

	if key_str.contains("+"):
		var mods: PackedStringArray = key_str.split("+")
		for i in range(mods.size() - 1):
			match mods[i].to_lower():
				"ctrl": event.ctrl_pressed = true
				"shift": event.shift_pressed = true
				"alt": event.alt_pressed = true
		key_str = mods[mods.size() - 1]

	var keycode: int = _key_name_to_code(key_str.to_lower())
	if keycode == 0:
		return "ERR: unknown key '%s'" % key_str

	event.keycode = keycode
	Input.parse_input_event(event)

	# Also send key up
	var up := InputEventKey.new()
	up.pressed = false
	up.keycode = keycode
	up.ctrl_pressed = event.ctrl_pressed
	up.shift_pressed = event.shift_pressed
	up.alt_pressed = event.alt_pressed
	Input.parse_input_event(up)

	return "OK: key %s" % key_str


func _key_name_to_code(name: String) -> int:
	match name:
		"a": return KEY_A
		"b": return KEY_B
		"c": return KEY_C
		"d": return KEY_D
		"e": return KEY_E
		"f": return KEY_F
		"g": return KEY_G
		"m": return KEY_M
		"n": return KEY_N
		"s": return KEY_S
		"r": return KEY_R
		"tab": return KEY_TAB
		"space": return KEY_SPACE
		"enter": return KEY_ENTER
		"escape": return KEY_ESCAPE
		"up": return KEY_UP
		"down": return KEY_DOWN
		"left": return KEY_LEFT
		"right": return KEY_RIGHT
		"delete": return KEY_DELETE
		"backspace": return KEY_BACKSPACE
		_: return 0


func _cmd_ai_spawn(pos: Vector2, custom_name: String = "", cls_name: String = "executioner") -> String:
	## Spawn an AI-controlled player of the given class. No joystick needed.
	var scene_path: String = "res://scenes/characters/player_side.tscn"
	if not ResourceLoader.exists(scene_path):
		return "ERR: player_side.tscn not found"

	# Register in PlayerManager with a fake device_id
	var fake_device: int = 9999
	var player_index: int = 0
	# Find next available slot
	for i in range(PlayerManager.MAX_PLAYERS):
		if not PlayerManager.players.has(i):
			player_index = i
			break

	# Resolve class name to enum
	var char_class: int = PlayerManager.CharacterClass.EXECUTIONER
	for cls in PlayerHUD.CLASS_NAMES:
		if PlayerHUD.CLASS_NAMES[cls].to_lower() == cls_name:
			char_class = cls
			break

	if not PlayerManager.CLASS_STATS.has(char_class):
		return "ERR: unknown class '%s'" % cls_name

	var stats: Dictionary = PlayerManager.CLASS_STATS[char_class]
	PlayerManager.players[player_index] = {
		"device_id": fake_device,
		"player_index": player_index,
		"character_class": char_class,
		"health": stats["max_health"],
		"max_health": stats["max_health"],
		"mana": stats["max_mana"],
		"max_mana": stats["max_mana"],
		"speed": stats["speed"],
		"mana_regen": stats["mana_regen"],
		"muffin_count": 0,
		"artifacts": [],
		"is_alive": true,
		"skill_xp": { "attack": 0, "special": 0, "charge": 0, "block": 0 },
		"total_kills": 0, "session_kills": 0, "session_damage_dealt": 0,
	}

	# Instantiate the player node
	var player_scene: PackedScene = load(scene_path)
	var player_node: CharacterBody2D = player_scene.instantiate()
	player_node.name = custom_name if not custom_name.is_empty() else "AIPlayer_%d" % player_index
	player_node.player_index = player_index
	player_node.device_id = fake_device
	player_node.character_class = char_class
	player_node.global_position = pos
	get_tree().current_scene.add_child(player_node)

	# Enable AI mode
	player_node.ai_set_active(true)
	player_node._facing_right = true

	var cls_display: String = PlayerHUD.CLASS_NAMES.get(char_class, cls_name)
	return "OK: AI %s spawned at (%.0f, %.0f) slot=%d" % [cls_display, pos.x, pos.y, player_index]


func _cmd_exec_test(angle_deg: float, hold_time: float, pos: Vector2 = Vector2(960, 876)) -> String:
	## Find or spawn an AI player, then run a throw test.
	var ai_player: CharacterBody2D = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.has_method("ai_queue_cmd") and p._ai_active:
			ai_player = p
			break

	if ai_player == null:
		var spawn_result: String = _cmd_ai_spawn(pos)
		if not spawn_result.begins_with("OK"):
			return spawn_result
		for p in get_tree().get_nodes_in_group("players"):
			if p.has_method("ai_queue_cmd") and p._ai_active:
				ai_player = p
				break

	if ai_player == null:
		return "ERR: could not create AI player"

	ai_player.global_position = pos
	ai_player.velocity = Vector2.ZERO
	ai_player._facing_right = true
	if ai_player._exec_ball_state != ai_player.ExecEndState.HELD:
		ai_player._exec_retract_all()
	ai_player._exec_ball_state = ai_player.ExecEndState.HELD
	ai_player._exec_shackle_state = ai_player.ExecEndState.HELD
	ai_player._exec_throw_step = 0

	# Set aim and queue commands
	var aim := Vector2(cos(deg_to_rad(angle_deg)), -sin(deg_to_rad(angle_deg)))
	ai_player.ai_clear()
	ai_player.ai_set_aim(aim)
	# Hold grapple (L1) for hold_time → windup + throw on release
	ai_player.ai_queue_cmd(["grapple"], hold_time, aim)
	# Then idle for 5 seconds to observe the result
	ai_player.ai_queue_cmd([], 5.0)

	return "OK: exec_test angle=%.0f hold=%.1fs aim=(%.2f,%.2f)" % [angle_deg, hold_time, aim.x, aim.y]


func _cmd_eval(expr_text: String) -> String:
	var expression := Expression.new()
	var err := expression.parse(expr_text)
	if err != OK:
		return "ERR: parse: %s" % expression.get_error_text()
	var result: Variant = expression.execute()
	if expression.has_execute_failed():
		return "ERR: exec: %s" % expression.get_error_text()
	return "OK: %s" % str(result)


func _cmd_status() -> String:
	var enemies: int = get_tree().get_nodes_in_group("enemies").size()
	var players: int = get_tree().get_nodes_in_group("players").size()
	var debug: bool = DebugOverlay.global_enabled
	var sel: String = "none"
	if is_instance_valid(PlayerHUD.debug_selected_enemy):
		sel = PlayerHUD.debug_selected_enemy.name
	return "status: debug=%s enemies=%d players=%d selected=%s" % [str(debug), enemies, players, sel]


func _color_for_value(value: int, good: int, warn: int) -> Color:
	## Green if <= good, yellow if <= warn, red otherwise
	if value <= good:
		return Color(0.2, 1.0, 0.3)
	elif value <= warn:
		return Color(1.0, 0.9, 0.2)
	else:
		return Color(1.0, 0.3, 0.2)


func _show_score_card(data: String) -> void:
	## Show score card below the title. Format: title|dmg|time|fps|ik|thrash
	var fields: PackedStringArray = data.split("|")
	if fields.size() < 6:
		return

	if not _title_layer:
		_title_layer = CanvasLayer.new()
		_title_layer.layer = 100
		add_child(_title_layer)

	var title: String = fields[0]
	var dmg: int = int(fields[1])
	var time_str: String = fields[2]
	var fps: int = int(fields[3])
	var ik: int = int(fields[4])
	var thrash: int = int(fields[5])

	# Title
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title_lbl.anchor_left = 0.5; title_lbl.anchor_right = 0.5
	title_lbl.anchor_top = 0.2; title_lbl.anchor_bottom = 0.2
	title_lbl.offset_left = -300; title_lbl.offset_right = 300
	_title_layer.add_child(title_lbl)

	# Score rows
	var rows := [
		["Damage", str(dmg), _color_for_value(1000 - dmg, 0, 500)],
		["Time to Hit", time_str, Color(0.2, 1.0, 0.3) if time_str != "NONE" else Color(1.0, 0.3, 0.2)],
		["Min FPS", str(fps), _color_for_value(60 - fps, 0, 20)],
		["IK Quality", str(ik), _color_for_value(ik, 100, 500)],
		["Thrash", str(thrash), _color_for_value(thrash, 5, 15)],
	]

	var container := VBoxContainer.new()
	container.anchor_left = 0.5; container.anchor_right = 0.5
	container.anchor_top = 0.32; container.anchor_bottom = 0.32
	container.offset_left = -200; container.offset_right = 200
	_title_layer.add_child(container)

	for row in rows:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 20)
		var name_lbl := Label.new()
		name_lbl.text = row[0]
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		name_lbl.custom_minimum_size.x = 140
		hbox.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.text = row[1]
		val_lbl.add_theme_font_size_override("font_size", 20)
		val_lbl.add_theme_color_override("font_color", row[2])
		hbox.add_child(val_lbl)
		container.add_child(hbox)

	# Fade out after 3 seconds
	var tween := title_lbl.create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(title_lbl, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(container, "modulate:a", 0.0, 1.0)
	tween.tween_callback(title_lbl.queue_free)
	tween.tween_callback(container.queue_free)


func _show_results_grid(data: String) -> void:
	## Show final results grid. Format: line1|line2|line3|...
	if not _title_layer:
		_title_layer = CanvasLayer.new()
		_title_layer.layer = 100
		add_child(_title_layer)

	var lines: PackedStringArray = data.split("|")

	var container := VBoxContainer.new()
	container.anchor_left = 0.5; container.anchor_right = 0.5
	container.anchor_top = 0.1; container.anchor_bottom = 0.1
	container.offset_left = -350; container.offset_right = 350
	_title_layer.add_child(container)

	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 16)
		if line.begins_with("===") or line.begins_with("TOTAL"):
			lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
			lbl.add_theme_font_size_override("font_size", 20)
		else:
			lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		container.add_child(lbl)

	# Stay visible until clicked or 30 seconds
	var tween := container.create_tween()
	tween.tween_interval(30.0)
	tween.tween_property(container, "modulate:a", 0.0, 2.0)
	tween.tween_callback(container.queue_free)
	# Click anywhere to dismiss early
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			container.queue_free()
	)
	container.mouse_filter = Control.MOUSE_FILTER_STOP


func _show_title(text: String) -> void:
	## Show a big title on screen: hold 1s, fade out 1s.
	if not _title_layer:
		_title_layer = CanvasLayer.new()
		_title_layer.layer = 100
		add_child(_title_layer)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.anchors_preset = Control.PRESET_CENTER
	lbl.anchor_left = 0.5
	lbl.anchor_right = 0.5
	lbl.anchor_top = 0.3
	lbl.anchor_bottom = 0.3
	lbl.offset_left = -400
	lbl.offset_right = 400
	lbl.offset_top = -30
	lbl.offset_bottom = 30
	_title_layer.add_child(lbl)

	var tween := lbl.create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.0)
	tween.tween_callback(lbl.queue_free)


func _cmd_partstatus() -> String:
	## Print all part health/damage states for the first quadruped monster.
	for e in get_tree().get_nodes_in_group("enemies"):
		if "_part_health" in e:
			var lines: Array[String] = ["partstatus:"]
			var ph: Dictionary = e._part_health
			for part_name in ph:
				var p: Dictionary = ph[part_name]
				var state_name: String = "NONE"
				match p.get("damage_state", 0):
					1: state_name = "MEDIUM"
					2: state_name = "HIGH"
				lines.append("  %s: %d/%d (%s)" % [part_name, p["current_hp"], p["max_hp"], state_name])
			if "_grab_disabled" in e:
				lines.append("  grab_disabled=%s" % str(e._grab_disabled))
			if "_torso_bleeding" in e:
				lines.append("  torso_bleeding=%s" % str(e._torso_bleeding))
			lines.append("  slash_mult=%.2f leap_mult=%.2f" % [e.get_slash_damage_multiplier(), e.get_leap_speed_multiplier()])
			return "\n".join(lines)
	return "ERR: no enemy with part health"


func _cmd_partdmg(parts: PackedStringArray) -> String:
	## Deal damage to a specific part: partdmg <part> <amount>
	if parts.size() < 3:
		return "ERR: usage: partdmg <part_name> <amount>"
	var part_name: String = parts[1]
	var amount: int = int(parts[2])
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_part_damage"):
			e.take_part_damage(part_name, amount)
			return "OK: dealt %d damage to %s" % [amount, part_name]
	return "ERR: no enemy with take_part_damage"


func _cmd_weight() -> String:
	## Print segment weights and attached forces.
	for e in get_tree().get_nodes_in_group("enemies"):
		if "SEGMENT_WEIGHTS" in e:
			var lines: Array[String] = ["weights (total=%.0f):" % e.get_total_weight()]
			for seg_name in e.SEGMENT_WEIGHTS:
				lines.append("  %s: %.0f" % [seg_name, e.SEGMENT_WEIGHTS[seg_name]])
			if "_attach_forces" in e and not e._attach_forces.is_empty():
				lines.append("forces:")
				for point_name in e._attach_forces:
					var f: Vector2 = e._attach_forces[point_name]
					lines.append("  %s: (%.1f, %.1f)" % [point_name, f.x, f.y])
			else:
				lines.append("forces: none")
			if "_attachments" in e:
				var total_items: int = 0
				for point_name in e._attachments:
					total_items += e._attachments[point_name].size()
				lines.append("attached_items: %d" % total_items)
			return "\n".join(lines)
	return "ERR: no enemy with weight data"


func _cmd_attach(parts: PackedStringArray) -> String:
	## Attach a test item: attach balloon <point>
	if parts.size() < 3:
		return "ERR: usage: attach balloon <point_name>"
	var item_type: String = parts[1].to_lower()
	var point_name: String = parts[2]

	if item_type != "balloon":
		return "ERR: only 'balloon' supported. Usage: attach balloon <point>"

	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("attach_item") and "_attachments" in e:
			if not e._attachments.has(point_name):
				return "ERR: unknown attachment point '%s'. Try: head, tail_tip, shoulders, waist" % point_name
			# Spawn a balloon dart and attach it
			var dart_script := load("res://scripts/characters/balloon_dart.gd")
			var dart := Node2D.new()
			dart.set_script(dart_script)
			var attach_pos: Vector2 = e.get_attach_world_position(point_name)
			dart.global_position = attach_pos
			dart.dart_direction = Vector2.UP
			dart.owner_index = -1
			var container: Node = get_tree().current_scene
			container.add_child(dart)
			# Force-attach: skip dart flight, go straight to inflating
			dart._dart_active = false
			dart._attached_to = e
			dart._balloon_inflating = true
			dart._balloon_timer = 0.0
			dart._dart_pos = attach_pos
			# Register with attachment system
			e.attach_item(point_name, dart)
			return "OK: attached balloon to %s" % point_name
	return "ERR: no enemy with attachment points"


func _cmd_detach(parts: PackedStringArray) -> String:
	## Detach all items from a point: detach <point>
	if parts.size() < 2:
		return "ERR: usage: detach <point_name>"
	var point_name: String = parts[1]

	for e in get_tree().get_nodes_in_group("enemies"):
		if "_attachments" in e and e._attachments.has(point_name):
			var items: Array = e._attachments[point_name]
			var count: int = items.size()
			for item in items:
				if is_instance_valid(item):
					item.queue_free()
			items.clear()
			return "OK: detached %d items from %s" % [count, point_name]
	return "ERR: no enemy with attachment point '%s'" % point_name


func _cmd_splay(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "ERR: usage: splay <list|spawn|clear|status>"

	var subcmd: String = parts[1].to_lower()
	# Find the SplayManager autoload or instance
	var mgr: Node = get_node_or_null("/root/SplayManager")
	if not mgr:
		# Try to find it as a child of current scene
		for child in get_tree().current_scene.get_children():
			if child.name == "SplayManager":
				mgr = child
				break
		if not mgr:
			# Create one on the fly
			var script: GDScript = load("res://scripts/systems/splay_manager.gd")
			mgr = Node.new()
			mgr.name = "SplayManager"
			mgr.set_script(script)
			get_tree().current_scene.add_child(mgr)

	match subcmd:
		"list":
			var names: Array[String] = mgr.get_all_pose_names()
			if names.is_empty():
				return "splay poses: (none)"
			return "splay poses: %s" % ", ".join(names)

		"spawn":
			# splay spawn <pose> [x y] [rotation] [behavior] [scale=N]
			if parts.size() < 3:
				return "ERR: usage: splay spawn <pose> [x y] [rotation] [behavior] [scale=N]"
			var pose_name: String = parts[2]
			var x: float = float(parts[3]) if parts.size() > 3 else 960.0
			var y: float = float(parts[4]) if parts.size() > 4 else 500.0
			var rot: float = float(parts[5]) if parts.size() > 5 else 0.0
			var behavior: String = parts[6] if parts.size() > 6 else "asleep"
			# Parse key=value args from remaining parts
			var splay_scale: float = -1.0
			for pi in range(3, parts.size()):
				if parts[pi].contains("="):
					var kv: PackedStringArray = parts[pi].split("=", true, 1)
					if kv[0] == "scale":
						splay_scale = float(kv[1])
			mgr.spawn_splay(pose_name, Vector2(x, y), rot, behavior, splay_scale)
			var scale_str: String = " scale=%.1f" % splay_scale if splay_scale > 0 else ""
			return "OK: spawning splay '%s' at (%.0f,%.0f) rot=%.0f behavior=%s%s" % [pose_name, x, y, rot, behavior, scale_str]

		"clear":
			var count: int = mgr.clear_all_splays()
			return "OK: cleared %d splay instances" % count

		"status":
			var lines: Array[String] = mgr.get_splay_status()
			return "\n".join(lines)

		_:
			return "ERR: unknown splay subcommand '%s'. Try: list, spawn, clear, status" % subcmd


func _cmd_mocap(parts: Array) -> String:
	## Mocap bridge commands: connect, disconnect, status
	var subcmd: String = parts[1] if parts.size() > 1 else "status"
	var client: Node = _get_or_create_mocap_client()
	match subcmd:
		"connect":
			var port: int = int(parts[2]) if parts.size() > 2 else 7777
			return client.connect_to_bridge(port)
		"disconnect":
			return client.disconnect_bridge()
		"calibrate":
			return client.start_calibration()
		"panel":
			return client.toggle_config_panel()
		"reset":
			client._reset_scene()
			return "OK: mocap scene reset"
		"raw":
			# Dump raw mocap 3D data for current frame
			var lm: Dictionary = client._last_frame.get("landmarks", {})
			if lm.is_empty():
				return "ERR: no mocap data"
			var lines: Array[String] = ["Raw mocap (x,y,z):"]
			for key in ["left_shoulder","right_shoulder","left_elbow","right_elbow","left_wrist","right_wrist","nose"]:
				if lm.has(key):
					var v: Array = lm[key]
					lines.append("  %s: (%.3f, %.3f, %.3f)" % [key, v[0], v[1], v[2]])
			# Also show relative elbow-shoulder
			if lm.has("right_shoulder") and lm.has("right_elbow"):
				var rs: Array = lm["right_shoulder"]
				var re: Array = lm["right_elbow"]
				lines.append("  R_elbow_rel: (%.3f, %.3f, %.3f)" % [re[0]-rs[0], re[1]-rs[1], re[2]-rs[2]])
			if lm.has("left_shoulder") and lm.has("left_elbow"):
				var ls: Array = lm["left_shoulder"]
				var le: Array = lm["left_elbow"]
				lines.append("  L_elbow_rel: (%.3f, %.3f, %.3f)" % [le[0]-ls[0], le[1]-ls[1], le[2]-ls[2]])
			return "\n".join(lines)
		"status":
			return client.get_status()
		"set":
			# mocap set <key> <value> — adjust config
			if parts.size() < 4:
				return "ERR: usage: mocap set <key> <value>. Keys: angle, smooth, xscale, yscale, depth, armscale"
			var key: String = parts[2]
			var val: float = float(parts[3])
			match key:
				"angle": client.cfg_stance_angle = val
				"smooth": client.cfg_smooth_weight = clampf(val, 0.01, 1.0)
				"xscale": client.cfg_x_scale = val
				"yscale": client.cfg_y_scale = val
				"depth": client.cfg_depth_blend = val
				"armscale": client.cfg_arm_scale = val
				_: return "ERR: unknown key '%s'" % key
			return "OK: mocap %s = %.2f" % [key, val]
		"get":
			return "angle=%.1f smooth=%.2f xscale=%.2f yscale=%.2f depth=%.2f armscale=%.2f" % [
				client.cfg_stance_angle, client.cfg_smooth_weight,
				client.cfg_x_scale, client.cfg_y_scale,
				client.cfg_depth_blend, client.cfg_arm_scale]
		_:
			return "ERR: unknown mocap subcommand '%s'. Try: connect, disconnect, calibrate, set, get, status" % subcmd


var _mocap_client: Node = null

func _get_or_create_mocap_client() -> Node:
	if _mocap_client and is_instance_valid(_mocap_client):
		return _mocap_client
	var script: GDScript = load("res://scripts/systems/mocap_client.gd")
	_mocap_client = Node.new()
	_mocap_client.set_script(script)
	_mocap_client.name = "MocapClient"
	add_child(_mocap_client)
	return _mocap_client


func _cmd_chaindump() -> String:
	## Dump detailed state of all chains: every point position and distances.
	var chains: Array = get_tree().get_nodes_in_group("chains")
	if chains.is_empty():
		return "chains: 0"
	var lines: Array[String] = ["chains: %d" % chains.size()]
	for ci in range(chains.size()):
		var c: Node2D = chains[ci]
		lines.append("=== Chain %d: %d pts, target_len=%.1f, link_len=%.1f, hp=%d/%d ===" % [
			ci, c._point_count, c.target_length, c._link_len, c.current_hp, c.CHAIN_MAX_HP])
		# Dump points with distances
		for i in range(c._points.size()):
			var pt: Vector2 = c._points[i]
			var dist_str: String = ""
			if i > 0:
				var dist: float = c._points[i - 1].distance_to(pt)
				var pct: float = (dist / c._link_len - 1.0) * 100
				if absf(pct) > 5:
					dist_str = " dist=%.1f (%.0f%%)" % [dist, pct]
				else:
					dist_str = " dist=%.1f" % dist
			var label: String = ""
			if i == 0:
				label = " [ANCHOR_A]"
			elif i == c._point_count - 1:
				label = " [ANCHOR_B]"
			lines.append("  pt[%d]: (%.1f,%.1f)%s%s" % [i, pt.x, pt.y, dist_str, label])
	return "\n".join(lines)


func _cmd_chain(parts: PackedStringArray) -> String:
	## Chain commands — same syntax as tether but creates chains instead.
	if parts.size() < 2:
		return "ERR: usage: chain <enemy idx point floor [len]|status|cut>"
	var subcmd: String = parts[1].to_lower()
	match subcmd:
		"status":
			var chains: Array = get_tree().get_nodes_in_group("chains")
			if chains.is_empty():
				return "chains: 0"
			var lines: Array[String] = ["chains: %d" % chains.size()]
			var ChainScript: GDScript = load("res://scripts/systems/chain.gd")
			for i in range(chains.size()):
				var c: Node2D = chains[i]
				var pa: Vector2 = c._get_anchor_world_pos(c.anchor_a)
				var pb: Vector2 = c._get_anchor_world_pos(c.anchor_b)
				lines.append("  [%d] len=%.0f/%.0f tension=%.2f hp=%d/%d" % [
					i, pa.distance_to(pb), c.target_length, c.get_tension(), c.current_hp, c.CHAIN_MAX_HP])
			return "\n".join(lines)
		"cut":
			var chains: Array = get_tree().get_nodes_in_group("chains")
			var count: int = chains.size()
			for c in chains:
				c.sever()
			return "OK: severed %d chains" % count
		_:
			# chain <idx> <point> floor [len]
			if parts.size() >= 4 and parts[3].to_lower() == "floor":
				var idx: int = int(parts[1])
				var point: String = parts[2]
				var length: float = 100.0
				if parts.size() > 4:
					length = float(parts[4])
				return _create_chain_enemy_floor(idx, point, length)
			# chain <idx> <point> wall <x> <y> [len]
			elif parts.size() >= 6 and parts[3].to_lower() == "wall":
				var idx: int = int(parts[1])
				var point: String = parts[2]
				var wall_x: float = float(parts[4])
				var wall_y: float = float(parts[5])
				var length: float = -1.0
				if parts.size() > 6:
					length = float(parts[6])
				return _create_chain_enemy_wall(idx, point, Vector2(wall_x, wall_y), length)
			elif parts.size() >= 5:
				var idx1: int = int(parts[1])
				var point1: String = parts[2]
				var idx2: int = int(parts[3])
				var point2: String = parts[4]
				var length: float = -1.0
				if parts.size() > 5:
					length = float(parts[5])
				return _create_chain_enemy_enemy(idx1, point1, idx2, point2, length)
	return "ERR: usage: chain <idx> <point> floor [len] | chain status | chain cut"


func _create_chain_enemy_floor(enemy_idx: int, point: String, length: float) -> String:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	if enemy_idx >= enemies.size():
		return "ERR: enemy %d not found" % enemy_idx
	var enemy: Node2D = enemies[enemy_idx]
	var ChainScript: GDScript = load("res://scripts/systems/chain.gd")
	var chain := Node2D.new()
	chain.set_script(ChainScript)
	var ap: String = ""
	if "_attach_points" in enemy and enemy._attach_points.has(point):
		ap = point
	var a: Dictionary = ChainScript.make_anchor_body(enemy, ap)
	var attach_pos: Vector2 = chain._get_anchor_world_pos(a) if chain.has_method("_get_anchor_world_pos") else enemy.global_position
	# For static methods we need the instance
	# Raycast to floor
	var floor_pos: Vector2 = Vector2(attach_pos.x, attach_pos.y + length + 200)
	var space := enemy.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(attach_pos, floor_pos, 1)
	var result: Dictionary = space.intersect_ray(query)
	if result:
		floor_pos = result["position"]
	var b: Dictionary = ChainScript.make_anchor_wall(floor_pos)
	var actual_length: float = length if length > 0 else attach_pos.distance_to(floor_pos)
	chain.setup(a, b, actual_length)
	get_tree().current_scene.add_child(chain)
	# Set _chained flag on the enemy so it respects chain constraints
	if "_chained" in enemy:
		enemy._chained = true
	return "OK: chained enemy %d (%s) to floor len=%.0f" % [enemy_idx, point, actual_length]


func _create_chain_enemy_wall(enemy_idx: int, point: String, wall_pos: Vector2, length: float) -> String:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	if enemy_idx >= enemies.size():
		return "ERR: enemy %d not found" % enemy_idx
	var enemy: Node2D = enemies[enemy_idx]
	var ChainScript: GDScript = load("res://scripts/systems/chain.gd")
	var chain := Node2D.new()
	chain.set_script(ChainScript)
	var ap: String = ""
	if "_attach_points" in enemy and enemy._attach_points.has(point):
		ap = point
	var a: Dictionary = ChainScript.make_anchor_body(enemy, ap)
	var b: Dictionary = ChainScript.make_anchor_wall(wall_pos)
	if length <= 0:
		var attach_pos: Vector2 = enemy.global_position
		if ap != "" and enemy.has_method("get_attach_world_position"):
			attach_pos = enemy.get_attach_world_position(ap)
		length = attach_pos.distance_to(wall_pos)
	chain.setup(a, b, length)
	get_tree().current_scene.add_child(chain)
	if "_chained" in enemy:
		enemy._chained = true
	return "OK: chained enemy %d (%s) to wall (%.0f,%.0f) len=%.0f" % [enemy_idx, point, wall_pos.x, wall_pos.y, length]


func _create_chain_enemy_enemy(idx1: int, point1: String, idx2: int, point2: String, length: float) -> String:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	if idx1 >= enemies.size():
		return "ERR: enemy %d not found" % idx1
	if idx2 >= enemies.size():
		return "ERR: enemy %d not found" % idx2
	var ChainScript: GDScript = load("res://scripts/systems/chain.gd")
	var chain := Node2D.new()
	chain.set_script(ChainScript)
	var ap1: String = ""
	if "_attach_points" in enemies[idx1] and enemies[idx1]._attach_points.has(point1):
		ap1 = point1
	var a: Dictionary = ChainScript.make_anchor_body(enemies[idx1], ap1)
	var ap2: String = ""
	if "_attach_points" in enemies[idx2] and enemies[idx2]._attach_points.has(point2):
		ap2 = point2
	var b: Dictionary = ChainScript.make_anchor_body(enemies[idx2], ap2)
	if length <= 0:
		length = enemies[idx1].global_position.distance_to(enemies[idx2].global_position)
	chain.setup(a, b, length)
	get_tree().current_scene.add_child(chain)
	if "_chained" in enemies[idx1]:
		enemies[idx1]._chained = true
	if "_chained" in enemies[idx2]:
		enemies[idx2]._chained = true
	return "OK: chained enemy %d (%s) to enemy %d (%s) len=%.0f" % [idx1, point1, idx2, point2, length]


func _cmd_tether(parts: PackedStringArray) -> String:
	## Tether commands: tether <subcommand> [args]
	if parts.size() < 2:
		return "ERR: usage: tether <enemy idx point floor|enemy idx1 point1 idx2 point2|wall x1 y1 x2 y2|length px|cut|status>"

	var subcmd: String = parts[1].to_lower()

	match subcmd:
		"status":
			var tethers: Array = get_tree().get_nodes_in_group("tethers")
			if tethers.is_empty():
				return "tethers: 0"
			var lines: Array[String] = ["tethers: %d" % tethers.size()]
			var TetherScript: GDScript = load("res://scripts/systems/tether.gd")
			for i in range(tethers.size()):
				var t: Node2D = tethers[i]
				var pa: Vector2 = TetherScript.get_anchor_world_pos(t.anchor_a)
				var pb: Vector2 = TetherScript.get_anchor_world_pos(t.anchor_b)
				var a_name: String = t.anchor_a.get("attach_point", "")
				if a_name == "":
					a_name = "wall" if t.anchor_a.get("is_wall", false) else "body"
				var b_name: String = t.anchor_b.get("attach_point", "")
				if b_name == "":
					b_name = "wall" if t.anchor_b.get("is_wall", false) else "body"
				var max_hp: int = t.CHAIN_MAX_HP if t.is_in_group("chains") else t.TETHER_MAX_HP
				lines.append("  [%d] A=%s(%.0f,%.0f) B=%s(%.0f,%.0f) len=%.0f/%.0f tension=%.2f hp=%d/%d" % [
					i, a_name, pa.x, pa.y, b_name, pb.x, pb.y,
					pa.distance_to(pb), t.target_length, t.get_tension(), t.current_hp, max_hp])
			return "\n".join(lines)

		"cut":
			var tethers: Array = get_tree().get_nodes_in_group("tethers")
			var count: int = tethers.size()
			for t in tethers:
				t.sever()
			return "OK: severed %d tethers" % count

		"length":
			if parts.size() < 3:
				return "ERR: usage: tether length <px>"
			var length: float = float(parts[2])
			var tethers: Array = get_tree().get_nodes_in_group("tethers")
			if tethers.is_empty():
				return "ERR: no active tethers"
			tethers[tethers.size() - 1].target_length = clampf(length, 30.0, 900.0)
			return "OK: set last tether length to %.0f" % length

		"wall":
			# tether wall <x1> <y1> <x2> <y2> [length]
			if parts.size() < 6:
				return "ERR: usage: tether wall <x1> <y1> <x2> <y2> [length]"
			var x1: float = float(parts[2])
			var y1: float = float(parts[3])
			var x2: float = float(parts[4])
			var y2: float = float(parts[5])
			var length: float = Vector2(x1, y1).distance_to(Vector2(x2, y2))
			if parts.size() > 6:
				length = float(parts[6])
			return _create_tether_wall_wall(Vector2(x1, y1), Vector2(x2, y2), length)

		_:
			# Try: tether <enemy_idx> <point> floor [length]
			# Or:  tether <enemy_idx1> <point1> <enemy_idx2> <point2> [length]
			if parts.size() >= 4 and parts[3].to_lower() == "floor":
				var idx: int = int(parts[1])
				var point: String = parts[2]
				var length: float = 100.0
				if parts.size() > 4:
					length = float(parts[4])
				return _create_tether_enemy_floor(idx, point, length)
			elif parts.size() >= 5:
				var idx1: int = int(parts[1])
				var point1: String = parts[2]
				var idx2: int = int(parts[3])
				var point2: String = parts[4]
				var length: float = -1.0  # Auto
				if parts.size() > 5:
					length = float(parts[5])
				return _create_tether_enemy_enemy(idx1, point1, idx2, point2, length)
			return "ERR: unrecognized tether command. Try: tether status, tether cut, tether <idx> <point> floor, tether <idx1> <point1> <idx2> <point2>"


func _create_tether_enemy_floor(enemy_idx: int, point: String, length: float) -> String:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	if enemy_idx >= enemies.size():
		return "ERR: enemy index %d not found" % enemy_idx
	var enemy: Node2D = enemies[enemy_idx]

	var TetherScript: GDScript = load("res://scripts/systems/tether.gd")
	var tether := Node2D.new()
	tether.set_script(TetherScript)

	var ap: String = ""
	if "_attach_points" in enemy and enemy._attach_points.has(point):
		ap = point
	var a: Dictionary = TetherScript.make_anchor_body(enemy, ap)

	# Floor position: directly below the attachment point
	var attach_pos: Vector2 = TetherScript.get_anchor_world_pos(a)
	var floor_pos: Vector2 = Vector2(attach_pos.x, attach_pos.y + length)
	# Raycast to find actual floor
	var space := enemy.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(attach_pos, attach_pos + Vector2(0, length + 200), 1)
	var result: Dictionary = space.intersect_ray(query)
	if result:
		floor_pos = result["position"]

	var b: Dictionary = TetherScript.make_anchor_wall(floor_pos)

	var actual_length: float = length
	if actual_length <= 0:
		actual_length = attach_pos.distance_to(floor_pos)

	tether.setup(a, b, actual_length)
	get_tree().current_scene.add_child(tether)
	return "OK: tethered enemy %d (%s) to floor at (%.0f,%.0f) len=%.0f" % [enemy_idx, point, floor_pos.x, floor_pos.y, actual_length]


func _create_tether_enemy_enemy(idx1: int, point1: String, idx2: int, point2: String, length: float) -> String:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	if idx1 >= enemies.size():
		return "ERR: enemy index %d not found" % idx1
	if idx2 >= enemies.size():
		return "ERR: enemy index %d not found" % idx2

	var TetherScript: GDScript = load("res://scripts/systems/tether.gd")
	var tether := Node2D.new()
	tether.set_script(TetherScript)

	var ap1: String = ""
	if "_attach_points" in enemies[idx1] and enemies[idx1]._attach_points.has(point1):
		ap1 = point1
	var a: Dictionary = TetherScript.make_anchor_body(enemies[idx1], ap1)

	var ap2: String = ""
	if "_attach_points" in enemies[idx2] and enemies[idx2]._attach_points.has(point2):
		ap2 = point2
	var b: Dictionary = TetherScript.make_anchor_body(enemies[idx2], ap2)

	if length <= 0:
		length = TetherScript.get_anchor_world_pos(a).distance_to(TetherScript.get_anchor_world_pos(b))

	tether.setup(a, b, length)
	get_tree().current_scene.add_child(tether)
	return "OK: tethered enemy %d (%s) to enemy %d (%s) len=%.0f" % [idx1, point1, idx2, point2, length]


func _create_tether_wall_wall(pos_a: Vector2, pos_b: Vector2, length: float) -> String:
	var TetherScript: GDScript = load("res://scripts/systems/tether.gd")
	var tether := Node2D.new()
	tether.set_script(TetherScript)

	var a: Dictionary = TetherScript.make_anchor_wall(pos_a)
	var b: Dictionary = TetherScript.make_anchor_wall(pos_b)

	tether.setup(a, b, length)
	get_tree().current_scene.add_child(tether)
	return "OK: tethered wall (%.0f,%.0f) to (%.0f,%.0f) len=%.0f" % [pos_a.x, pos_a.y, pos_b.x, pos_b.y, length]


func _apply_portal_state() -> void:
	## Apply the stored portal disabled state to all portal nodes.
	var scene := get_tree().current_scene
	if not scene:
		return
	var disabled: bool = scene.get_meta("portal_disabled", false)
	for node in scene.get_children():
		if "disabled" in node and ("_doors_open" in node or node.name.contains("ortal") or node.name.contains("oorway")):
			node.disabled = disabled


func _cmd_standdown(parts: PackedStringArray) -> String:
	## Toggle or set stand-down mode on all quadruped monsters.
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var count: int = 0
	var new_state: Variant = null  # null = toggle

	if parts.size() > 1:
		match parts[1].to_lower():
			"on": new_state = true
			"off": new_state = false

	for e in enemies:
		if "_standdown" in e:
			if new_state != null:
				e._standdown = new_state as bool
			else:
				e._standdown = not e._standdown
			# When waking up (standdown off), kick into CHASE state
			if not e._standdown and "_state" in e and e._state == 19:  # 19 = STANDDOWN
				e._state = 1  # CHASE
				if e.has_method("_pick_target"):
					e._pick_target()
			count += 1

	if count == 0:
		return "ERR: no monsters with standdown support"
	var state_str: String = ""
	if count > 0:
		state_str = str(enemies[0]._standdown) if "_standdown" in enemies[0] else "?"
	return "OK: standdown=%s on %d monsters" % [state_str, count]


func _cmd_attacker(parts: PackedStringArray) -> String:
	## Control attack dummies: attacker <subcommand> [args]
	var attackers: Array = get_tree().get_nodes_in_group("attack_dummies")
	if attackers.is_empty():
		return "ERR: no attack dummies spawned. Use: spawn attacker [x y]"

	if parts.size() < 2:
		return "ERR: usage: attacker <target|part|weapon|rate|stop|start|stats>"

	var subcmd: String = parts[1].to_lower()
	match subcmd:
		"target":
			# attacker target <enemy_index>
			var idx: int = int(parts[2]) if parts.size() > 2 else 0
			var enemies: Array = get_tree().get_nodes_in_group("enemies")
			if idx >= enemies.size():
				return "ERR: enemy index %d not found (have %d)" % [idx, enemies.size()]
			for a in attackers:
				a.set_target(enemies[idx])
			return "OK: targeting %s" % enemies[idx].name

		"part":
			# attacker part <part_name>
			var part_name: String = parts[2] if parts.size() > 2 else ""
			for a in attackers:
				a.set_target_part(part_name)
			return "OK: targeting part '%s'" % part_name

		"weapon":
			# attacker weapon <bow|balloon>
			if parts.size() < 3:
				return "ERR: usage: attacker weapon <bow|balloon>"
			var weapon: String = parts[2].to_lower()
			for a in attackers:
				a.set_weapon(weapon)
			return "OK: weapon=%s" % weapon

		"rate":
			# attacker rate <seconds>
			if parts.size() < 3:
				return "ERR: usage: attacker rate <seconds>"
			var rate: float = float(parts[2])
			for a in attackers:
				a.set_rate(rate)
			return "OK: attack rate=%.1fs" % rate

		"stop":
			for a in attackers:
				a._attacking = false
			return "OK: attackers stopped"

		"start":
			for a in attackers:
				a._attacking = true
			return "OK: attackers started"

		"stats":
			var lines: Array[String] = ["attack_dummies: %d" % attackers.size()]
			for a in attackers:
				var target_name: String = a._target.name if is_instance_valid(a._target) else "none"
				lines.append("  %s at (%.0f,%.0f) weapon=%s part=%s attacking=%s shots=%d hits=%d" % [
					a.name, a.global_position.x, a.global_position.y,
					a._weapon, a._target_part, str(a._attacking),
					a._shots_fired, a._hits_landed])
			return "\n".join(lines)

		"tether_length":
			if parts.size() < 3:
				return "ERR: usage: attacker tether_length <px>"
			var tlen: float = float(parts[2])
			for a in attackers:
				a.set_tether_length(tlen)
			return "OK: tether_length=%.0f" % tlen

		"tether_b":
			# attacker tether_b floor  OR  attacker tether_b enemy <idx> <part>
			if parts.size() < 3:
				return "ERR: usage: attacker tether_b floor | attacker tether_b enemy <idx> <part>"
			var btype: String = parts[2].to_lower()
			if btype == "floor":
				for a in attackers:
					a.set_tether_target_b("floor")
				return "OK: tether_b=floor"
			elif btype == "enemy" and parts.size() >= 5:
				var eidx: int = int(parts[3])
				var epart: String = parts[4]
				var enemies: Array = get_tree().get_nodes_in_group("enemies")
				if eidx >= enemies.size():
					return "ERR: enemy %d not found" % eidx
				for a in attackers:
					a.set_tether_target_b("enemy", enemies[eidx], epart)
				return "OK: tether_b=enemy %d %s" % [eidx, epart]
			return "ERR: usage: attacker tether_b floor | attacker tether_b enemy <idx> <part>"

		_:
			return "ERR: unknown attacker subcommand '%s'. Try: target, part, weapon, rate, stop, start, stats, tether_length, tether_b" % subcmd


func _cmd_debug(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		# No subcommand: toggle global on/off
		DebugOverlay.global_enabled = not DebugOverlay.global_enabled
		# Sync legacy PlayerHUD._debug_mode for backward compat during migration
		PlayerHUD._debug_mode = DebugOverlay.global_enabled
		return "OK: debug=%s" % ("on" if DebugOverlay.global_enabled else "off")

	var subcmd: String = parts[1].to_lower()

	match subcmd:
		"list":
			return DebugOverlay.get_status_text()

		"on":
			if parts.size() < 3:
				return "ERR: usage: debug on <aspect>[/<sub>]"
			var path: String = parts[2]
			_debug_set_human_visual(path, true)
			return "OK: %s visual=on" % path

		"off":
			if parts.size() < 3:
				return "ERR: usage: debug off <aspect>[/<sub>]"
			var path: String = parts[2]
			_debug_set_human_visual(path, false)
			return "OK: %s visual=off" % path

		"log":
			if parts.size() < 3:
				return "ERR: usage: debug log <aspect>[/<sub>]"
			_debug_set_human_textual(parts[2], DebugOverlay.TextMode.LOG)
			return "OK: %s textual=log" % parts[2]

		"console":
			if parts.size() < 3:
				return "ERR: usage: debug console <aspect>[/<sub>]"
			_debug_set_human_textual(parts[2], DebugOverlay.TextMode.CONSOLE)
			return "OK: %s textual=console" % parts[2]

		"both":
			if parts.size() < 3:
				return "ERR: usage: debug both <aspect>[/<sub>]"
			_debug_set_human_textual(parts[2], DebugOverlay.TextMode.BOTH)
			return "OK: %s textual=both" % parts[2]

		"nolog":
			if parts.size() < 3:
				return "ERR: usage: debug nolog <aspect>[/<sub>]"
			_debug_set_human_textual(parts[2], DebugOverlay.TextMode.NONE)
			return "OK: %s textual=none" % parts[2]

		"save":
			DebugOverlay.save_profile()
			return "OK: debug profile saved"

		"load":
			DebugOverlay.load_profile()
			return "OK: debug profile loaded"

		"filter":
			return _cmd_debug_filter(parts)

		"reset":
			DebugOverlay.remove_observer("human")
			return "OK: human observer state cleared"

		"profile":
			# Inline JSON profile: debug profile {"pathing/waypoints":"log"}
			if parts.size() < 3:
				return "ERR: usage: debug profile <json>"
			var json_str: String = " ".join(parts.slice(2))
			var json := JSON.new()
			if json.parse(json_str) != OK:
				return "ERR: invalid JSON: %s" % json.get_error_message()
			DebugOverlay.apply_profile("script:rcon", json.data)
			return "OK: applied debug profile (%d aspects)" % json.data.size()

		"clear_transient":
			DebugOverlay.clear_transient_observers()
			return "OK: transient observers cleared"

		_:
			return "ERR: unknown debug subcommand '%s'. Try: list, on, off, log, console, both, nolog, save, load, filter, reset, profile, clear_transient" % subcmd


## Set human visual for an aspect or all aspects in a group.
func _debug_set_human_visual(path: String, visual: bool) -> void:
	# Check if it's a group name (no "/" in path)
	if "/" not in path:
		# Try as group
		var aspects: Array[String] = DebugOverlay.get_aspects_in_group(path)
		if aspects.size() > 0:
			DebugOverlay.set_group_visual(path, visual)
			return
	# Single aspect
	var state: Array = DebugOverlay.get_observer_state(path, "human")
	DebugOverlay.set_observer(path, "human", visual, state[1])


## Set human textual for an aspect or all aspects in a group.
func _debug_set_human_textual(path: String, textual: int) -> void:
	if "/" not in path:
		var aspects: Array[String] = DebugOverlay.get_aspects_in_group(path)
		if aspects.size() > 0:
			DebugOverlay.set_group_textual(path, textual)
			return
	var state: Array = DebugOverlay.get_observer_state(path, "human")
	DebugOverlay.set_observer(path, "human", state[0], textual)


func _cmd_debug_filter(parts: PackedStringArray) -> String:
	# debug filter type <type> on|off
	# debug filter id <pattern>
	if parts.size() < 4:
		return "ERR: usage: debug filter type <type> on|off  |  debug filter id <pattern>"

	var filter_type: String = parts[2].to_lower()
	match filter_type:
		"type":
			var type_name: String = parts[3].to_lower()
			if parts.size() < 5:
				# Show current state
				var enabled: bool = DebugOverlay.entity_type_filter.get(type_name, true)
				return "filter type %s=%s" % [type_name, "on" if enabled else "off"]
			var on_off: String = parts[4].to_lower()
			DebugOverlay.entity_type_filter[type_name] = (on_off == "on")
			return "OK: filter type %s=%s" % [type_name, on_off]

		"id":
			var pattern: String = parts[3]
			DebugOverlay.entity_id_pattern = pattern
			return "OK: filter id=%s" % pattern

		_:
			return "ERR: unknown filter type '%s'. Try: type, id" % filter_type


func _deferred_run_test(test_name: String, override_vars: Dictionary) -> void:
	## Called deferred when the test editor was just created and isn't ready yet.
	if _test_editor and is_instance_valid(_test_editor) and "_active" in _test_editor:
		_test_editor._test_override_vars = override_vars
		_test_editor._load_test(test_name)
		_test_editor.call_deferred("_run_test")


func _deferred_run_suite(suite_name: String, override_vars: Dictionary, skip_tests: Array[String]) -> void:
	## Called deferred when the test editor was just created and isn't ready yet.
	if _test_editor and is_instance_valid(_test_editor) and "_active" in _test_editor:
		_test_editor._test_override_vars = override_vars
		_test_editor.run_suite(suite_name, skip_tests)


func _ensure_test_editor() -> Node:
	## Find or create the test editor. Always docked in the debug drawer.
	if _test_editor and is_instance_valid(_test_editor):
		# Guard: script properties may not exist yet if _ready hasn't run
		if not _test_editor.is_inside_tree():
			return _test_editor
		if "_active" in _test_editor and not _test_editor._active:
			_test_editor._active = true
			_test_editor.visible = true
		if "_docked" in _test_editor:
			_test_editor._docked = true
		var drawer: Node = _get_debug_drawer()
		if drawer:
			if not drawer.is_open():
				drawer.toggle()
			drawer._current_section = 1  # Section.TEST_RUNNER
		return _test_editor
	# Look for existing editor in the scene
	for node in get_tree().current_scene.get_children():
		if node.has_method("toggle") and node.has_method("_load_test") and node.has_method("_run_test"):
			_test_editor = node
			_test_editor._docked = true
			if not _test_editor._active:
				_test_editor._active = true
				_test_editor.visible = true
			var drawer: Node = _get_debug_drawer()
			if drawer:
				if not drawer.is_open():
					drawer.toggle()
				drawer._current_section = 1  # Section.TEST_RUNNER
			return _test_editor
	# Create one — always docked in the debug drawer.
	# Script properties aren't available until _ready, so defer activation.
	var script: GDScript = load("res://scripts/ui/test_editor.gd")
	var editor := CanvasLayer.new()
	editor.set_script(script)
	get_tree().current_scene.add_child(editor)
	_test_editor = editor
	# Open the debug drawer, switch to test runner
	var drawer: Node = _get_debug_drawer()
	if drawer:
		if not drawer.is_open():
			drawer.toggle()
		drawer._current_section = 1  # Section.TEST_RUNNER
	# Defer docked activation until _ready has run and script properties exist
	editor.call_deferred("_activate_docked")
	return editor


func _get_debug_drawer() -> Node:
	## Find the debug drawer autoload.
	return get_node_or_null("/root/DebugDrawer")


func _ensure_test_runner() -> void:
	if _test_runner and is_instance_valid(_test_runner):
		return
	var script: GDScript = load("res://scripts/systems/test_runner.gd")
	_test_runner = Node.new()
	_test_runner.name = "TestRunner"
	_test_runner.set_script(script)
	add_child(_test_runner)


func _ensure_zone_manager() -> void:
	if _zone_manager and is_instance_valid(_zone_manager):
		return
	var script: GDScript = load("res://scripts/systems/test_zones.gd")
	_zone_manager = Node2D.new()
	_zone_manager.name = "TestZones"
	_zone_manager.set_script(script)
	get_tree().current_scene.add_child(_zone_manager)


func _ensure_leap_checker() -> void:
	if _leap_checker and is_instance_valid(_leap_checker):
		return
	var script: GDScript = load("res://scripts/systems/test_bounded_leaps.gd")
	_leap_checker = Node2D.new()
	_leap_checker.name = "TestBoundedLeaps"
	_leap_checker.set_script(script)
	get_tree().current_scene.add_child(_leap_checker)


func _cmd_bleap(parts: PackedStringArray, full_cmd: String) -> String:
	## Bounded-leap builder. Configures leap check constraints step by step.
	## Sub-commands: reset, a, b, plan, start, end, disallow, min, show
	if parts.size() < 2:
		return "ERR: usage: bleap <reset|a|b|plan|start|end|disallow|min|show>"

	var sub: String = parts[1].to_lower()
	match sub:
		"reset":
			_bleap_defs = []
			_bleap_plat_a = {}
			_bleap_plat_b = {}
			_bleap_plans = []
			_bleap_current_plan = {}
			_bleap_min_matched = 1
			return "OK: bleap state reset"

		"a":
			if parts.size() < 5:
				return "ERR: usage: bleap a <x> <y> <radius>"
			_bleap_plat_a = {"x": float(parts[2]), "y": float(parts[3]), "radius": float(parts[4])}
			return "OK: platform_a = (%.0f,%.0f) r=%.0f" % [_bleap_plat_a["x"], _bleap_plat_a["y"], _bleap_plat_a["radius"]]

		"b":
			if parts.size() < 5:
				return "ERR: usage: bleap b <x> <y> <radius>"
			_bleap_plat_b = {"x": float(parts[2]), "y": float(parts[3]), "radius": float(parts[4])}
			return "OK: platform_b = (%.0f,%.0f) r=%.0f" % [_bleap_plat_b["x"], _bleap_plat_b["y"], _bleap_plat_b["radius"]]

		"plan":
			# bleap plan req|opt [start x y w h] [end x y r] [disallow r x1 y1 x2 y2] ...
			if parts.size() < 3:
				return "ERR: usage: bleap plan req|opt [start x y w h] [end x y r] [disallow r x1 y1 x2 y2]"
			var required: bool = parts[2].to_lower() == "req"
			var plan: Dictionary = {"required": required, "start": {}, "end": {}, "disallow": []}
			# Parse keyword args from remaining tokens
			var i: int = 3
			while i < parts.size():
				match parts[i].to_lower():
					"start":
						if i + 4 < parts.size():
							plan["start"] = {"x": float(parts[i+1]), "y": float(parts[i+2]),
								"w": float(parts[i+3]), "h": float(parts[i+4])}
							i += 5
						else: i += 1
					"end":
						if i + 3 < parts.size():
							plan["end"] = {"x": float(parts[i+1]), "y": float(parts[i+2]), "radius": float(parts[i+3])}
							i += 4
						else: i += 1
					"disallow":
						if i + 5 < parts.size():
							plan["disallow"].append({"radius": float(parts[i+1]),
								"x1": float(parts[i+2]), "y1": float(parts[i+3]),
								"x2": float(parts[i+4]), "y2": float(parts[i+5])})
							i += 6
						else: i += 1
					_: i += 1
			_bleap_plans.append(plan)
			var req_str: String = "REQUIRED" if required else "optional"
			return "OK: plan %d (%s) — start=%s end=%s disallow=%d" % [
				_bleap_plans.size(), req_str,
				str(plan["start"]), str(plan["end"]), plan["disallow"].size()]

		"start":
			# bleap start x y w h — set start for current plan being built
			if parts.size() < 6:
				return "ERR: usage: bleap start <x> <y> <w> <h>"
			_bleap_current_plan["start"] = {"x": float(parts[2]), "y": float(parts[3]),
				"w": float(parts[4]), "h": float(parts[5])}
			return "OK: current plan start = (%.0f,%.0f) %0.fx%.0f" % [float(parts[2]), float(parts[3]), float(parts[4]), float(parts[5])]

		"end":
			if parts.size() < 5:
				return "ERR: usage: bleap end <x> <y> <radius>"
			_bleap_current_plan["end"] = {"x": float(parts[2]), "y": float(parts[3]), "radius": float(parts[4])}
			return "OK: current plan end = (%.0f,%.0f) r=%.0f" % [float(parts[2]), float(parts[3]), float(parts[4])]

		"disallow":
			if parts.size() < 7:
				return "ERR: usage: bleap disallow <r> <x1> <y1> <x2> <y2>"
			if not _bleap_current_plan.has("disallow"):
				_bleap_current_plan["disallow"] = []
			_bleap_current_plan["disallow"].append({"radius": float(parts[2]),
				"x1": float(parts[3]), "y1": float(parts[4]),
				"x2": float(parts[5]), "y2": float(parts[6])})
			return "OK: disallow added (r=%.0f path=(%.0f,%.0f)→(%.0f,%.0f))" % [float(parts[2]), float(parts[3]), float(parts[4]), float(parts[5]), float(parts[6])]

		"commit":
			# Finalize current_plan and push to plans list
			if _bleap_current_plan.is_empty():
				return "ERR: no plan in progress (use bleap plan req|opt first)"
			_bleap_plans.append(_bleap_current_plan.duplicate(true))
			_bleap_current_plan = {}
			return "OK: plan %d committed" % _bleap_plans.size()

		"next":
			# Commit current def and start a new one (without clearing accumulated defs)
			if not _bleap_plat_a.is_empty() or not _bleap_plans.is_empty():
				_bleap_defs.append({"platform_a": _bleap_plat_a, "platform_b": _bleap_plat_b, "plans": _bleap_plans})
			_bleap_plat_a = {}
			_bleap_plat_b = {}
			_bleap_plans = []
			_bleap_current_plan = {}
			return "OK: def committed (%d total), ready for next" % _bleap_defs.size()

		"min":
			if parts.size() < 3:
				return "ERR: usage: bleap min <n>"
			_bleap_min_matched = int(parts[2])
			return "OK: min_matched = %d" % _bleap_min_matched

		"show":
			var ls: Array[String] = ["bleap state:"]
			ls.append("  platform_a: %s" % str(_bleap_plat_a))
			ls.append("  platform_b: %s" % str(_bleap_plat_b))
			ls.append("  min_matched: %d" % _bleap_min_matched)
			ls.append("  plans: %d" % _bleap_plans.size())
			for pi in range(_bleap_plans.size()):
				var p: Dictionary = _bleap_plans[pi]
				ls.append("    [%d] %s start=%s end=%s disallow=%d" % [
					pi + 1, "REQUIRED" if p.get("required", false) else "optional",
					str(p.get("start", {})), str(p.get("end", {})), p.get("disallow", []).size()])
			if not _bleap_current_plan.is_empty():
				ls.append("  (in-progress plan: %s)" % str(_bleap_current_plan))
			return "\n".join(ls)

		_:
			return "ERR: unknown bleap sub-command '%s'" % sub


func get_bleap_check_data() -> Dictionary:
	## Returns all accumulated bleap defs (from `bleap next`) plus the current one being built.
	var all_defs: Array = _bleap_defs.duplicate()
	# Include the current def if it has content
	if not _bleap_plat_a.is_empty() or not _bleap_plans.is_empty():
		all_defs.append({"platform_a": _bleap_plat_a, "platform_b": _bleap_plat_b, "plans": _bleap_plans})
	if all_defs.is_empty():
		return {}
	return {
		"leaps": all_defs,
		"min_matched": _bleap_min_matched,
	}


func _cmd_testload(test_name: String) -> String:
	## Load a test JSON and convert it to a flat script list for editing.
	var loaded_data: Dictionary = {}
	for dir_path in ["res://data/tests/", "user://data/tests/"]:
		var path: String = dir_path + test_name + ".json"
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var json := JSON.new()
				if json.parse(file.get_as_text()) == OK:
					loaded_data = json.data
				file.close()
			break
	if loaded_data.is_empty():
		return "ERR: test '%s' not found" % test_name

	_test_script_name = test_name
	_test_script = []

	# Use existing "script" field if present
	if loaded_data.has("script"):
		for line in loaded_data["script"]:
			_test_script.append(str(line))
		return "OK: loaded '%s' — %d lines (script format)" % [test_name, _test_script.size()]

	# Convert legacy {setup, wait, checks, debug} format to flat script
	var debug_profile: Dictionary = loaded_data.get("debug", {})
	for aspect in debug_profile:
		var mode: String = debug_profile[aspect]
		match mode:
			"on":        _test_script.append("debug on " + aspect)
			"log":       _test_script.append("debug log " + aspect)
			"both":      _test_script.append("debug both " + aspect)
			"on+log", _: _test_script.append("debug on " + aspect)

	for cmd in loaded_data.get("setup", []):
		_test_script.append(str(cmd))

	var wait_secs: float = loaded_data.get("wait", 10.0)
	_test_script.append("wait %.0f" % wait_secs)

	# Convert checks
	for ch in loaded_data.get("checks", []):
		var ch_cmd: String = ch.get("command", "")
		var ch_label: String = ch.get("label", ch_cmd)
		match ch_cmd:
			"zones":
				_test_script.append("check zones")
			"bounded_leaps":
				# Re-encode bounded_leaps as bleap commands
				var leap_defs: Array = ch.get("leaps", [])
				var ch_min: int = ch.get("min_matched", 1)
				_test_script.append("bleap reset")
				for ld in leap_defs:
					var pa: Dictionary = ld.get("platform_a", {})
					var pb: Dictionary = ld.get("platform_b", {})
					if not pa.is_empty():
						_test_script.append("bleap a %.0f %.0f %.0f" % [pa.get("x",0), pa.get("y",0), pa.get("radius",100)])
					if not pb.is_empty():
						_test_script.append("bleap b %.0f %.0f %.0f" % [pb.get("x",0), pb.get("y",0), pb.get("radius",100)])
					for plan in ld.get("plans", []):
						var req_str: String = "req" if plan.get("required", false) else "opt"
						var plan_line: String = "bleap plan " + req_str
						var ps: Dictionary = plan.get("start", {})
						if not ps.is_empty():
							plan_line += " start %.0f %.0f %.0f %.0f" % [ps.get("x",0), ps.get("y",0), ps.get("w",0), ps.get("h",0)]
						var pe: Dictionary = plan.get("end", {})
						if not pe.is_empty():
							plan_line += " end %.0f %.0f %.0f" % [pe.get("x",0), pe.get("y",0), pe.get("radius",0)]
						for dis in plan.get("disallow", []):
							plan_line += " disallow %.0f %.0f %.0f %.0f %.0f" % [
								dis.get("radius",20), dis.get("x1",0), dis.get("y1",0),
								dis.get("x2",0), dis.get("y2",0)]
						_test_script.append(plan_line)
				_test_script.append("bleap min %d" % ch_min)
				_test_script.append("check bounded_leaps " + ch_label)
			"fps", "hp", _:
				# Generic check: rebuild as "check <cmd> > <n>" etc.
				var threshold_str: String = ""
				if ch.has("expect_gt"):  threshold_str = "> %s" % str(ch["expect_gt"])
				elif ch.has("expect_lt"): threshold_str = "< %s" % str(ch["expect_lt"])
				elif ch.has("expect_eq"): threshold_str = "= %s" % str(ch["expect_eq"])
				var extract: String = ch.get("extract", "")
				var full_check: String = "check %s" % ch_cmd
				if extract:  full_check += " extract:" + extract
				if threshold_str: full_check += " " + threshold_str
				if ch_label != ch_cmd: full_check += " label:" + ch_label
				_test_script.append(full_check)

	return "OK: loaded '%s' — %d lines (converted from legacy JSON)" % [test_name, _test_script.size()]


func _cmd_testsave(save_name: String) -> String:
	## Save the current script back to JSON (using the script field).
	if _test_script.is_empty():
		return "ERR: no script to save"
	var data: Dictionary = {
		"name": save_name,
		"script": _test_script,
	}
	var path: String = "res://data/tests/" + save_name + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		# Try user:// fallback
		path = "user://data/tests/" + save_name + ".json"
		DirAccess.make_dir_recursive_absolute("user://data/tests/")
		file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return "ERR: could not write to '%s'" % path
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_test_script_name = save_name
	return "OK: saved '%s' (%d lines) → %s" % [save_name, _test_script.size(), path]


func _cmd_notify(notify_name: String, message: String, buttons_str: String, timeout: float, mode: String) -> String:
	## Show a notification. Modes:
	## - "blocking": modal dialog that captures all input
	## - "editor": non-blocking banner in the test editor (UI remains interactive)
	var json := JSON.new()
	var buttons: Array = ["OK"]
	if json.parse(buttons_str) == OK and json.data is Array:
		buttons = json.data

	_notify_name = notify_name
	_notify_message = message
	_notify_buttons = buttons
	_notify_timeout = timeout
	_notify_timer = timeout
	_notify_active = true
	_notify_mode = mode
	_notify_dismissed_button = ""

	# Always clean up any previous blocking layer
	if _notify_layer and is_instance_valid(_notify_layer):
		_notify_layer.queue_free()
		_notify_layer = null

	if mode == "blocking":
		_notify_layer = CanvasLayer.new()
		_notify_layer.layer = 115
		var panel := Control.new()
		panel.name = "NotifyPanel"
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.draw.connect(_draw_blocking_notify)
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_notify_handle_click(event.position)
			elif event is InputEventMouseMotion:
				_notify_mouse_pos = event.position
				_notify_update_hover()
				panel.queue_redraw()
		)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_notify_layer.add_child(panel)
		add_child(_notify_layer)
	elif mode == "editor":
		# Push notify state to the test editor — it renders the banner
		if _test_editor and is_instance_valid(_test_editor):
			_test_editor.set_meta("notify_name", notify_name)
			_test_editor.set_meta("notify_message", message)
			_test_editor.set_meta("notify_buttons", buttons)
			_test_editor.set_meta("notify_timeout", timeout)
			_test_editor.set_meta("notify_active", true)

	print("NOTIFY SHOW name=%s mode=%s buttons=%s timeout=%.0f" % [notify_name, mode, str(buttons), timeout])
	return "OK: notify '%s' shown (%s, %.0fs)" % [notify_name, mode, timeout]


func _cmd_notify_dismiss(button_label: String) -> String:
	## Dismiss the active notification.
	if not _notify_active:
		return "ERR: no notify active"
	_notify_dismissed_button = button_label
	_notify_active = false
	if _notify_mode == "blocking" and _notify_layer and is_instance_valid(_notify_layer):
		_notify_layer.queue_free()
		_notify_layer = null
	elif _notify_mode == "editor" and _test_editor and is_instance_valid(_test_editor):
		_test_editor.set_meta("notify_active", false)
	print("NOTIFY DISMISS button=%s" % button_label)
	return "OK: notify dismissed (button=%s)" % button_label


func _cmd_emit(event_name: String, value: String) -> String:
	## Emit a named event. Used by test scripts for state transitions.
	print("EMIT %s=%s" % [event_name, value])
	# Store the latest value for polling
	set_meta("emit_" + event_name, value)
	return "OK: emit %s=%s" % [event_name, value]


## Button colors for notify modal — each button gets a distinct color
const NOTIFY_BUTTON_COLORS := {
	"OK": Color(0.2, 0.8, 0.3),
	"BAD": Color(0.9, 0.3, 0.2),
	"BROKEN": Color(0.9, 0.6, 0.1),
	"RETRY": Color(0.3, 0.6, 1.0),
}

## Tooltips for each button — shown below the button on hover
const NOTIFY_BUTTON_TOOLTIPS := {
	"OK": "Test passed and looks correct",
	"BAD": "Test passed, but it should have failed",
	"BROKEN": "Test passed, but is invalid / broken",
	"RETRY": "Run this test again",
}

func _get_notify_rect() -> Rect2:
	## Compute the dialog rect based on content.
	var vp := get_viewport().get_visible_rect().size
	var pw: float = minf(500.0, vp.x * 0.6)
	var btn_count: int = maxi(_notify_buttons.size(), 1)
	var btn_row_w: float = btn_count * 110.0 + 20.0
	pw = maxf(pw, btn_row_w)
	var ph: float = 150.0
	var px: float = (vp.x - pw) / 2.0
	var py: float = (vp.y - ph) / 2.0
	return Rect2(px, py, pw, ph)

func _draw_blocking_notify() -> void:
	if not _notify_active or not _notify_layer:
		return
	var panel: Control = _notify_layer.get_child(0) if _notify_layer.get_child_count() > 0 else null
	if not panel:
		return
	var font: Font = ThemeDB.fallback_font
	var vp := get_viewport().get_visible_rect().size
	var r: Rect2 = _get_notify_rect()
	var px: float = r.position.x
	var py: float = r.position.y
	var pw: float = r.size.x
	var ph: float = r.size.y

	# Dim background
	panel.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.5))
	# Dialog box
	panel.draw_rect(Rect2(px, py, pw, ph), Color(0.08, 0.09, 0.08, 0.97))
	panel.draw_rect(Rect2(px, py, pw, ph), Color(0.4, 0.7, 0.4, 0.7), false, 2.0)
	# Name label (small, top-left) — skip for inspect modal
	if _notify_name != "inspect":
		panel.draw_string(font, Vector2(px + 12, py + 18), _notify_name,
			HORIZONTAL_ALIGNMENT_LEFT, pw - 24, 10, Color(0.45, 0.45, 0.45))
	# Message (large, centered)
	var display_msg: String = _notify_message if not _notify_message.is_empty() else _notify_name.to_upper()
	var msg_size: Vector2 = font.get_string_size(display_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var msg_x: float = px + (pw - msg_size.x) / 2.0
	panel.draw_string(font, Vector2(msg_x, py + 55), display_msg,
		HORIZONTAL_ALIGNMENT_LEFT, pw - 24, 18, Color(0.95, 0.95, 0.95))
	# Countdown (only if timeout > 0)
	if _notify_timeout > 0:
		var countdown: int = ceili(_notify_timer)
		panel.draw_string(font, Vector2(px + pw - 40, py + 18), "%ds" % countdown,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.8, 0.3))
	# Buttons — centered row, color-coded, with hover highlight + tooltip
	var btn_w: float = 100.0
	var btn_h: float = 30.0
	var btn_gap: float = 10.0
	var total_btn_w: float = _notify_buttons.size() * btn_w + (_notify_buttons.size() - 1) * btn_gap
	var btn_start_x: float = px + (pw - total_btn_w) / 2.0
	var btn_y: float = py + ph - btn_h - 15.0
	for i in range(_notify_buttons.size()):
		var bx: float = btn_start_x + i * (btn_w + btn_gap)
		var label: String = str(_notify_buttons[i])
		var col: Color = NOTIFY_BUTTON_COLORS.get(label, Color(0.5, 0.5, 0.5))
		var is_hovered: bool = (i == _notify_hover_idx)
		# Button background — brighter on hover
		var bg_alpha: float = 0.45 if is_hovered else 0.2
		var border_width: float = 2.5 if is_hovered else 1.5
		panel.draw_rect(Rect2(bx, btn_y, btn_w, btn_h), col * Color(1, 1, 1, bg_alpha))
		panel.draw_rect(Rect2(bx, btn_y, btn_w, btn_h), col * Color(1, 1, 1, 0.8 if is_hovered else 0.6), false, border_width)
		# Button label (centered)
		var lbl_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var lbl_x: float = bx + (btn_w - lbl_size.x) / 2.0
		var label_col: Color = Color(1, 1, 1) if is_hovered else col
		panel.draw_string(font, Vector2(lbl_x, btn_y + 21), label,
			HORIZONTAL_ALIGNMENT_LEFT, btn_w, 14, label_col)
	# Tooltip — render below the hovered button
	if _notify_hover_idx >= 0 and _notify_hover_idx < _notify_buttons.size():
		var hover_label: String = str(_notify_buttons[_notify_hover_idx])
		var tip_text: String = NOTIFY_BUTTON_TOOLTIPS.get(hover_label, "")
		if not tip_text.is_empty():
			var tip_col: Color = NOTIFY_BUTTON_COLORS.get(hover_label, Color(0.5, 0.5, 0.5))
			var tip_size: Vector2 = font.get_string_size(tip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			var tip_x: float = px + (pw - tip_size.x) / 2.0
			var tip_y: float = btn_y + btn_h + 8.0
			# Background
			panel.draw_rect(Rect2(tip_x - 4, tip_y - 10, tip_size.x + 8, 14),
				Color(0.05, 0.05, 0.05, 0.9))
			# Text
			panel.draw_string(font, Vector2(tip_x, tip_y), tip_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tip_col * Color(1, 1, 1, 0.9))


func _notify_update_hover() -> void:
	## Update which button is hovered based on mouse position.
	_notify_hover_idx = -1
	var r: Rect2 = _get_notify_rect()
	var px: float = r.position.x
	var py: float = r.position.y
	var pw: float = r.size.x
	var ph: float = r.size.y
	var btn_w: float = 100.0
	var btn_h: float = 30.0
	var btn_gap: float = 10.0
	var total_btn_w: float = _notify_buttons.size() * btn_w + (_notify_buttons.size() - 1) * btn_gap
	var btn_start_x: float = px + (pw - total_btn_w) / 2.0
	var btn_y: float = py + ph - btn_h - 15.0
	for i in range(_notify_buttons.size()):
		var bx: float = btn_start_x + i * (btn_w + btn_gap)
		if Rect2(bx, btn_y, btn_w, btn_h).has_point(_notify_mouse_pos):
			_notify_hover_idx = i
			return


func _notify_handle_click(pos: Vector2) -> void:
	var r: Rect2 = _get_notify_rect()
	var px: float = r.position.x
	var py: float = r.position.y
	var pw: float = r.size.x
	var ph: float = r.size.y
	var btn_w: float = 100.0
	var btn_h: float = 30.0
	var btn_gap: float = 10.0
	var total_btn_w: float = _notify_buttons.size() * btn_w + (_notify_buttons.size() - 1) * btn_gap
	var btn_start_x: float = px + (pw - total_btn_w) / 2.0
	var btn_y: float = py + ph - btn_h - 15.0
	for i in range(_notify_buttons.size()):
		var bx: float = btn_start_x + i * (btn_w + btn_gap)
		if Rect2(bx, btn_y, btn_w, btn_h).has_point(pos):
			_cmd_notify_dismiss(str(_notify_buttons[i]))
			return


func _cmd_list_tests() -> String:
	var lines: Array[String] = ["tests:"]
	for dir_path in ["res://data/tests/"]:
		var dir := DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var fname: String = dir.get_next()
			while fname != "":
				if fname.ends_with(".json") and not dir.current_is_dir():
					lines.append("  %s" % fname.get_basename())
				fname = dir.get_next()
	lines.append("suites:")
	for dir_path in ["res://data/tests/suites/"]:
		var dir := DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var fname: String = dir.get_next()
			while fname != "":
				if fname.ends_with(".json") and not dir.current_is_dir():
					lines.append("  %s" % fname.get_basename())
				fname = dir.get_next()
	return "\n".join(lines)


func _apply_entity_state(entity: Node2D, state: Dictionary) -> String:
	## Apply key=value state to an entity. Handles semantic keys (mode, facing)
	## and falls back to direct property assignment for anything else.
	var applied: Array[String] = []
	for key in state:
		var val: String = state[key]
		match key:
			"mode":
				# Chain mode for Executioner
				if "_exec_chain_mode" in entity:
					match val.to_lower():
						"release", "r":
							entity._exec_chain_mode = entity.ExecChainMode.RELEASE_RELEASE
						"hold_release", "hr":
							entity._exec_chain_mode = entity.ExecChainMode.HOLD_RELEASE
						"hold_hold", "hh":
							entity._exec_chain_mode = entity.ExecChainMode.HOLD_HOLD
					applied.append("mode=%s" % val)
			"facing":
				if "_facing_right" in entity:
					if val == "left":
						entity._facing_right = false
						if "_facing_target" in entity:
							entity._facing_target = -1.0
					elif val == "right":
						entity._facing_right = true
						if "_facing_target" in entity:
							entity._facing_target = 1.0
					applied.append("facing=%s" % val)
			"throw_mode":
				# Ball-first vs shackle-first
				if "_exec_throw_mode" in entity:
					match val.to_lower():
						"ball", "ball_first":
							entity._exec_throw_mode = entity.ExecThrowMode.BALL_FIRST
						"shackle", "shackle_first":
							entity._exec_throw_mode = entity.ExecThrowMode.SHACKLE_FIRST
					applied.append("throw_mode=%s" % val)
			"standdown":
				if "_standdown" in entity:
					entity._standdown = val.to_lower() in ["true", "1", "on", "yes"]
					applied.append("standdown=%s" % val)
			_:
				# Generic property set — try to set directly on the entity
				if key in entity:
					var prop_val = entity.get(key)
					if prop_val is float:
						entity.set(key, float(val))
					elif prop_val is int:
						entity.set(key, int(val))
					elif prop_val is bool:
						entity.set(key, val.to_lower() in ["true", "1", "on", "yes"])
					elif prop_val is String:
						entity.set(key, val)
					applied.append("%s=%s" % [key, val])
	if applied.is_empty():
		return ""
	return " [%s]" % ", ".join(applied)


func _get_all_entities() -> Array:
	## Returns a deduplicated list of all entities (enemies + players + dummies + entities).
	var all: Array = []
	all.append_array(get_tree().get_nodes_in_group("enemies"))
	all.append_array(get_tree().get_nodes_in_group("players"))
	all.append_array(get_tree().get_nodes_in_group("attack_dummies"))
	all.append_array(get_tree().get_nodes_in_group("entities"))
	var seen: Dictionary = {}
	var result: Array = []
	for e in all:
		if is_instance_valid(e) and not seen.has(e.get_instance_id()):
			seen[e.get_instance_id()] = true
			result.append(e)
	return result
