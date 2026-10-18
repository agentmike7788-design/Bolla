extends Node
## QA director, Phase-9 UI (docs/PHASE9_DESIGN.md §7, §11): started by ui_screenshots.gd with --phase9. Loads the v7
## reference save slot_p8_day63_kindly (Bogen A, 07:00 day 63 – the dead under Lorenz' list lie on the hill) into the
## real world and stages the Phase-9 states through the public APIs of the systems (their own save_state/load_state where
## a debug shortcut is needed). The Phase-9 system nodes the world does not have yet (W-Welt's builder adds them) are
## added at runtime from their own scripts; nothing is written to the world files.
## Shots (1280×720, <out>/ui_p9_<name><suffix>.jpg), the §11 number in brackets:
##   journal_list (03) · journal_plans (12) · letter_card (13) · journal_letters · large_gate (22) · large_half ·
##   large_village · register · hud_p9 · day_summary · chapter (26) · stranger (18) · map_friedhof
##   GODOT=… tools/godot_run.sh --resolution 1280x720 -s res://src/ui/tools/ui_screenshots.gd -- --phase9 --out=/abs/dir
##       [--shots=journal_list,stranger] [--suffix=_web]   (with --rendering-method gl_compatibility for the web shots)

const SAVE_DIR := "user://ui_shot_saves_p9"
const SLOT := 0
const SAVE := "slot_p8_day63_kindly"
const SETTLE_FRAMES := 30
const JPG_QUALITY := 0.9
const DAY := 63
const STRANGER_MINUTE := 880
const SYSTEMS: Dictionary[String, Script] = {
	"Quests": preload("res://src/systems/quests/quests.gd"),
	"WhoKnows": preload("res://src/systems/quests/who_knows/who_knows.gd"),
	"Letters": preload("res://src/systems/letters/letters.gd"),
	"Stranger": preload("res://src/systems/stranger/stranger.gd"),
}
const GROUPS: Dictionary[String, StringName] = {"Quests": &"quests", "WhoKnows": &"who_knows", "Letters": &"letters",
		"Stranger": &"stranger"}

var _out: String = ""
var _suffix: String = ""
var _only: PackedStringArray = []
var _world: WorldRoot
var _ui: UIRoot
var _player: Player
var _quests: Quests
var _who: WhoKnows
var _letters: Letters
var _stranger: Stranger
var _hill: HillRequests
var _journal: JournalManager
var _letter_uid: String = ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
		elif arg.begins_with("--suffix="):
			_suffix = arg.trim_prefix("--suffix=")
	if _out == "":
		push_error("[UiShotsP9] --out=<dir> missing")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	SaveManager.save_dir = SAVE_DIR
	if Phase9Fixtures.install_save_v7(SAVE, ProjectSettings.globalize_path(SAVE_DIR), SLOT) != OK:
		push_error("[UiShotsP9] cannot install %s" % SAVE)
		get_tree().quit(1)
		return
	var err: Error = await SaveManager.load_game(SLOT)
	if err != OK:
		push_error("[UiShotsP9] load failed: %s" % err)
		get_tree().quit(1)
		return
	await get_tree().process_frame
	TimeManager.running = false
	_world = get_tree().current_scene as WorldRoot
	_ui = _world.get_node(^"UI") as UIRoot
	_player = _world.get_player()
	_player.instant_actions = true
	_ensure_nodes()
	await get_tree().process_frame
	_stage()
	await get_tree().process_frame
	# In clock order (day 63 07:00 → day 65 14:40).
	await _shot("journal_list", _list_shot)
	await _shot("journal_plans", _plans_shot)
	await _shot("letter_card", _letter_shot)
	await _shot("journal_letters", _letters_page_shot)
	await _shot("large_gate", _large_gate_shot)
	await _shot("large_half", _large_half_shot)
	await _shot("large_village", _large_village_shot)
	await _shot("register", _register_shot)
	await _shot("hud_p9", _hud_shot)
	await _shot("day_summary", _day_summary_shot)
	await _shot("chapter", _chapter_shot)
	await _shot("stranger", _stranger_shot)
	await _shot("map_friedhof", _map_shot)
	SaveManager.delete_save(SLOT)
	SaveManager.save_dir = SaveManager.DEFAULT_SAVE_DIR
	get_tree().quit()


func _shot(shot_name: String, setup: Callable) -> void:
	if not _only.is_empty() and not shot_name in _only:
		return
	_ui.notifications.clear()
	await setup.call()
	_ui.hud.refresh_all()
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var path := _out.path_join("ui_p9_%s%s.jpg" % [shot_name, _suffix])
	get_viewport().get_texture().get_image().save_jpg(path, JPG_QUALITY)
	print("[UiShotsP9] ", path)
	_ui.close_all()
	UIState.clear()
	_ui.notifications.clear()
	_ui.reward_card.visible = false
	if _ui.dialogue_box.is_active():
		_ui.dialogue_box.abort()
	await get_tree().process_frame


## Missing Phase-9 nodes (a no-op once the builder adds them) – same classes and groups, opened from the loaded state.
func _ensure_nodes() -> void:
	var systems := _world.get_node(^"Systems")
	for node_name: String in SYSTEMS:
		if get_tree().get_first_node_in_group(GROUPS[node_name]) != null:
			continue
		var node := (SYSTEMS[node_name] as GDScript).new() as Node
		node.name = node_name
		systems.add_child(node)
		node.call(&"load_state", {})
	_quests = get_tree().get_first_node_in_group(&"quests") as Quests
	_who = get_tree().get_first_node_in_group(&"who_knows") as WhoKnows
	_letters = get_tree().get_first_node_in_group(&"letters") as Letters
	_stranger = get_tree().get_first_node_in_group(&"stranger") as Stranger
	_hill = get_tree().get_first_node_in_group(&"hill_requests") as HillRequests
	_journal = get_tree().get_first_node_in_group(&"journal") as JournalManager
	_quests.post_load()


# --- staging -------------------------------------------------------------------------------------

func _stage() -> void:
	_quests.open_now(DAY)
	GameState.set_flag(&"p9_intro", true)
	GameState.set_flag(&"q_light_day", DAY - 12)
	_who.load_state({"light_day": DAY - 12, "matched": ["e_dorn", "e_quendel", "e_wernstein", "e_hagedorn", "e_ott"],
			"witnessed": ["e_dorn", "e_quendel"]})
	_journal.add_clue(&"c_q_dates", "", true)
	_quests.load_state({"open_day": DAY, "open": ["q_who_knows", "q_letters"], "step": {"q_who_knows": "h3", "q_letters": "l2"},
			"done": {"q_who_knows": ["h1", "h2"], "q_letters": ["l1"]}, "notes": {"kladde_read": [""], "pocket_decided": ["lt_0002"],
			"date_grave": ["e_dorn", "e_quendel", "e_wernstein", "e_hagedorn", "e_ott"]}, "pinned": "q_who_knows"})
	_hill.pin_large(&"hrl_ferry_graves")
	_hill.accept(&"hrl_ferry_graves")
	_hill.set_part(&"hrl_ferry_graves", 0, true)
	_hill.pin_large(&"hrv_bridge_stones")
	_letter_uid = "lt_0001"
	_letters.load_state({"next_uid": 4, "records": {
		"lt_0001": {"id": "lp_l1_carter", "corpse": "", "state": "found", "day": DAY},
		"lt_0002": {"id": "lg_grocer", "corpse": "", "state": "delivered", "day": DAY - 1, "opened": true},
		"lt_0003": {"id": "lpo_quendel", "corpse": "", "state": "received", "day": DAY}}})
	for uid: String in ["lt_0001", "lt_0003"]:
		if not _player.inventory.has_uid(uid):
			_player.inventory.add_unique(&"letter", uid)
	_ui.hud.refresh_all()
	UIState.clear()
	_ui.close_all()


## p9_03: „Die Liste" – two inks, the names matched, two witnesses.
func _list_shot() -> void:
	_ui.open_journal(&"list")
	await get_tree().process_frame


## p9_12: „Vorhaben" with every group, the main chain chosen and pinned.
func _plans_shot() -> void:
	_ui.open_journal(&"plans")
	await get_tree().process_frame


## p9_13: a pocket letter with its choices and their places.
func _letter_shot() -> void:
	_ui.open_panel(&"letter", {"uid": _letter_uid, "inventory": _player.inventory, "player": _player})
	await get_tree().process_frame


func _letters_page_shot() -> void:
	_ui.open_journal(&"letters")
	await get_tree().process_frame


## p9_22: the large request at the gate (1 ✓, 2 ○) above the small slips.
func _large_gate_shot() -> void:
	_ui.open_panel(&"hill_requests", {"player": _player, "inventory": _player.inventory, "place": &"gate"})
	await get_tree().process_frame


## The stamp „halb": two of three parts done.
func _large_half_shot() -> void:
	_hill.set_part(&"hrl_ferry_graves", 1, true)
	_ui.open_panel(&"hill_requests", {"player": _player, "inventory": _player.inventory, "place": &"gate"})
	await get_tree().process_frame


## The parish board: „Große Bitte" above the orders.
func _large_village_shot() -> void:
	var board := _find(func(n: Node) -> bool: return n is VillageBoard) as VillageBoard
	if board != null:
		_ui.open_panel(&"orders", board.panel_context(_player))
	await get_tree().process_frame


## The grave register: the Brief column and „Licht: …" at the list's dead.
func _register_shot() -> void:
	var desk := _find(func(n: Node) -> bool: return n is Desk) as Desk
	if desk != null:
		_ui.open_panel(&"grave_register", desk.register_context())
	await get_tree().process_frame


## The HUD with the pinned large request and a note of Osric's post.
func _hud_shot() -> void:
	_quests.pin(&"hrl_ferry_graves")
	_ui.hud.refresh_objective()
	await get_tree().process_frame
	EventBus.notification_requested.emit(Letters.TEXT_POST % "Marthe Quendel", &"info")
	EventBus.notification_requested.emit("Die Gräber der Fähre: 2 von 3.", &"reward")


func _day_summary_shot() -> void:
	EventBus.letter_changed.emit("lt_0004", &"lp_l2_sister", &"found")
	EventBus.letter_changed.emit("lt_0002", &"lg_grocer", &"delivered")
	EventBus.letter_changed.emit("lt_0003", &"lpo_quendel", &"received")
	EventBus.hill_request_part.emit(&"hrl_ferry_graves", 1, true)
	EventBus.stranger_event.emit(&"asked", "frank")
	EventBus.stranger_event.emit(&"sold", "so_register")
	_ui.open_panel(&"day_summary", {"day": DAY, "burials_today": 1, "coins_today": 7})
	await get_tree().process_frame


## p9_26: the chapter panel „Wer weiß, wann?" (Ende B).
func _chapter_shot() -> void:
	var context := _quests.chapter_context()
	context["variant"] = &"who_knows_when"
	context["days_open"] = 10
	context["main_ending"] = &"stay"
	context["main_title"] = "Bei Grete"
	context["confided"] = &"confide_washer"
	context["closing_line"] = Phase9Texts.CHAPTER_FINAL_FALLBACK
	context["letters_delivered"] = 3
	context["letters_read_grave"] = 2
	context["letters_answered"] = 1
	context["letters_burned"] = 1
	context["letters_buried"] = 0
	context["errands_done"] = 2
	context["large_requests_done"] = 3
	context["large_requests_half"] = 1
	context["large_requests_failed"] = 0
	context["large_request_parts"] = 11
	context["stranger_talks"] = 2
	context["stranger_coins"] = 13
	context["stranger_end"] = &"fenner"
	context["stranger_seen"] = true
	context["insights"] = ["i_light_before"]
	_ui.open_panel(&"slice_summary", context)
	await get_tree().process_frame


## p9_18: Brenneisen at the gate (day 65, 14:40) with his offers.
func _stranger_shot() -> void:
	GameState.set_flag(&"anatomy_known", true)
	var day := DAY + _stranger.get_config().arrive_offset
	TimeManager.set_time(day, STRANGER_MINUTE)
	_stranger.apply_morning(day)
	_stranger.apply_minute(day, STRANGER_MINUTE)
	if not _player.inventory.has(&"register_extract"):
		_player.inventory.add_item(&"register_extract", 1)
	_ui.open_panel(&"stranger", {"player": _player, "inventory": _player.inventory})
	await get_tree().process_frame


## The graveyard map: Brenneisen outside the gate, the large sheet, the bookmark of the pinned request.
func _map_shot() -> void:
	_quests.pin(&"hrl_ferry_graves")
	_ui.open_map(&"graveyard")
	await get_tree().process_frame


func _find(pred: Callable) -> Node:
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if pred.call(node):
			return node
	return null
