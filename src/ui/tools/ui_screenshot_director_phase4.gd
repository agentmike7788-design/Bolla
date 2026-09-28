extends Node
## QA director, Phase-4 UI (docs/PHASE4_DESIGN.md §7, §11): started by ui_screenshots.gd with
## --phase4. Starts a new game in the real graveyard world and stages every state through the
## public APIs of the systems: the story corpse S1 (Marthe Quendel) on the morgue table,
## examined step by step through CorpseCare (the wounds late, so the cause detail is lost),
## washed and smoked with juniper, Ilse known and her shears in the pack; clues and an insight
## through JournalManager; Ilse's trade through NightTrade at 23:30; the chapter panel from
## Graveyard.chapter_context(&"six_pits"). Phase-4 system nodes the world does not have yet
## (CorpseCare, Piety, Journal, NightTrade – W-Welt adds them) are added under Systems first.
## Shots (1280×720, <out>/ui_<name>.jpg):
##   table_exam · table_prep · table_harvest · journal_clues · journal_insight · journal_self ·
##   trade_ilse · chapter_six_pits
##   GODOT=… tools/godot_run.sh --resolution 1280x720 -s res://src/ui/tools/ui_screenshots.gd -- --phase4 --out=/abs/dir [--shots=table_exam,trade_ilse]

const SAVE_DIR := "user://ui_shot_saves_p4"
const SETTLE_FRAMES := 30
const JPG_QUALITY := 0.9
const DAY := 6
const MORNING := 600
const NIGHT := 1410
const STORY := &"s1_quendel"
const SYSTEMS: Dictionary[String, Script] = {
	"CorpseCare": preload("res://src/systems/corpse/corpse_care.gd"),
	"Piety": preload("res://src/systems/piety/piety.gd"),
	"Journal": preload("res://src/systems/journal/journal_manager.gd"),
	"NightTrade": preload("res://src/systems/utilization/night_trade.gd"),
}
const GROUPS: Dictionary[String, StringName] = {
	"CorpseCare": &"corpse_care", "Piety": &"piety", "Journal": &"journal", "NightTrade": &"night_trade",
}

var _out: String = ""
var _only: PackedStringArray = []
var _world: WorldRoot
var _ui: UIRoot
var _player: Player
var _corpses: CorpseManager
var _graveyard: Graveyard
var _care: CorpseCare
var _journal: JournalManager
var _piety: Piety
var _trade: NightTrade
var _table: MorgueTable
var _record: CorpseRecord


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
	if _out == "":
		push_error("[UiShotsP4] --out=<dir> missing")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	SaveManager.save_dir = SAVE_DIR
	SaveManager.new_game()
	await EventBus.new_game_started
	await get_tree().process_frame
	TimeManager.running = false
	_world = get_tree().current_scene as WorldRoot
	_ui = _world.get_node(^"UI") as UIRoot
	_player = _world.get_player()
	_player.instant_actions = true
	_corpses = _world.corpse_manager
	_graveyard = _world.graveyard
	_ensure_systems()
	await get_tree().process_frame
	_stage()
	await get_tree().process_frame
	await _shot("table_exam", _table_shot.bind(CorpseExamTabs.TAB_EXAM))
	await _shot("table_prep", _table_shot.bind(CorpseExamTabs.TAB_PREP))
	await _shot("table_harvest", _table_shot.bind(CorpseExamTabs.TAB_HARVEST))
	await _shot("journal_clues", _journal_clues_shot)
	await _shot("journal_insight", _journal_insight_shot)
	await _shot("journal_self", _journal_self_shot)
	await _shot("trade_ilse", _trade_shot)
	await _shot("chapter_six_pits", _chapter_shot)
	for slot: int in [0, 1]:
		SaveManager.delete_save(slot)
	SaveManager.save_dir = SaveManager.DEFAULT_SAVE_DIR
	get_tree().quit()


func _shot(shot_name: String, setup: Callable) -> void:
	if not _only.is_empty() and not shot_name in _only:
		return
	await setup.call()
	_ui.hud.refresh_all()
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var path := _out.path_join("ui_%s.jpg" % shot_name)
	get_viewport().get_texture().get_image().save_jpg(path, JPG_QUALITY)
	print("[UiShotsP4] ", path)
	_ui.close_all()
	UIState.clear()
	_ui.notifications.clear()
	_ui.reward_card.visible = false
	await get_tree().process_frame


## Missing Phase-4 system nodes (until the W-Welt builder adds them) – same classes and groups.
func _ensure_systems() -> void:
	var systems := _world.get_node(^"Systems")
	for node_name: String in SYSTEMS:
		if get_tree().get_first_node_in_group(GROUPS[node_name]) != null:
			continue
		var node := (SYSTEMS[node_name] as GDScript).new() as Node
		node.name = node_name
		systems.add_child(node)
	_care = get_tree().get_first_node_in_group(&"corpse_care") as CorpseCare
	_journal = get_tree().get_first_node_in_group(&"journal") as JournalManager
	_piety = get_tree().get_first_node_in_group(&"piety") as Piety
	_trade = get_tree().get_first_node_in_group(&"night_trade") as NightTrade


# --- staging (real systems only) ----------------------------------------------------------

## Day 6, 10:00: Marthe Quendel (S1) on the table – wounds examined late (the cause detail is
## lost, the mark stays), then pockets (the page → c_page_1); washed and smoked with juniper;
## Ilse known, her shears in the pack, a burial gown but no comb.
func _stage() -> void:
	TimeManager.set_time(DAY, MORNING)
	_corpses.load_state({"last_delivery_day": DAY})
	_table = _world.get_node_by_layout_id("morgue_table") as MorgueTable
	var story := Database.story_corpse(STORY) as StoryCorpseData
	var rec := StoryDirector.make_record(story, 7)
	rec.arrival_total_minutes = TimeManager.total_minutes()
	_record = _corpses.spawn_corpse(rec, _table.slot_transform(), CorpseRecord.LOCATION_GROUND)
	_corpses.put_down(_record.id, CorpseRecord.LOCATION_TABLE, _table.slot_transform(), _table.slot_node())
	_set_freshness(0.5)
	_care.exam_step(_record.id, CorpseRecord.STEP_WOUNDS)
	_set_freshness(0.71)
	_care.exam_step(_record.id, CorpseRecord.STEP_POCKETS)
	var inv := _player.inventory
	for entry: Array in [[&"scrub_brush", 1], [&"juniper", 2], [&"burial_gown", 1], [&"coin", 14], [&"linen", 1]]:
		inv.add_item(entry[0], entry[1])
	_care.wash(_record.id, inv)
	_care.apply_balm(_record.id, inv)
	GameState.set_flag(&"trader_known", true)
	inv.add_item(&"shears", 1)
	_place_player(_table.global_position + _table.global_basis.z * 1.3)
	_ui.hud.refresh_all()
	UIState.clear()
	_ui.close_all()
	_ui.notifications.clear()


## Freshness by moving the arrival back (as the debug command "corpse fresh" does).
func _set_freshness(value: float) -> void:
	var rate := CorpseDecay.decay_per_hour(_record, Database.corpse_tables() as CorpseTables)
	var now := TimeManager.total_minutes()
	_record.arrival_total_minutes = now - roundi((1.0 - value) / rate * 60.0)
	_record.freshness = CorpseDecay.freshness_at(_record, now, rate)
	_record.last_decay_total = now
	_corpses.notify_changed(_record.id)


func _place_player(at: Vector3, facing: float = PI) -> void:
	at.y = _world.ground_height(Vector2(at.x, at.z))
	_player.global_transform = Transform3D(Basis(Vector3.UP, facing), at)
	_player.velocity = Vector3.ZERO
	_world.get_node(^"CameraRig").call(&"snap")


# --- shots ------------------------------------------------------------------------------------

func _table_shot(tab: StringName) -> void:
	_table.interact(_player)
	await get_tree().process_frame
	var panel := _ui.get_panel(&"corpse_exam") as CorpseExamPanel
	panel.tabs.select_tab(tab)
	if tab == CorpseExamTabs.TAB_HARVEST:
		panel.tabs.confirm_seconds = 60.0
		panel.tabs.press_harvest(&"hair")


func _journal_clues_shot() -> void:
	for id: StringName in [&"c_warning_letter", &"c_anchor_snake", &"c_trader_note"]:
		_journal.add_clue(id)
	_ui.notifications.clear()
	_ui.open_journal(&"clues")
	await get_tree().process_frame
	var panel := _ui.get_panel(&"journal") as JournalPanel
	for id: StringName in [&"c_warning_letter", &"c_mark", &"c_page_1"]:
		panel.toggle_clue(id)


func _journal_insight_shot() -> void:
	_ui.open_journal(&"clues")
	await get_tree().process_frame
	var panel := _ui.get_panel(&"journal") as JournalPanel
	panel.reveal_time = 0.0
	panel.toggle_clue(&"c_warning_letter")
	panel.toggle_clue(&"c_page_1")
	panel.link_selected()
	_ui.notifications.clear()


func _journal_self_shot() -> void:
	_piety.change(34 - _piety.value(), "Aufnahme")
	GameState.stats[&"prepared"] = 4
	GameState.stats[&"utilized"] = 1
	_ui.notifications.clear()
	_ui.open_journal(&"self")


## 23:30 at the west wall: Ilse greets a „callous“ gravekeeper (+1 per item).
func _trade_shot() -> void:
	TimeManager.set_time(TimeManager.day, NIGHT)
	_piety.change(-30 - _piety.value(), "Aufnahme")
	var inv := _player.inventory
	inv.add_item(&"hair_braid", 2)
	inv.add_item(&"teeth_pouch", 1)
	var spot: Vector3 = _world.get_waypoint(&"trader_spot")
	if spot != Vector3.ZERO:
		_place_player(spot + Vector3(1.4, 0.0, 0.0), -PI * 0.5)
	await get_tree().process_frame
	_ui.notifications.clear()
	_ui.open_panel(&"trader", {"speaker": null, "inventory": inv})
	await get_tree().process_frame
	var panel := _ui.get_panel(&"trader") as TraderPanel
	panel.buy(&"juniper")


func _chapter_shot() -> void:
	_piety.change(64 - _piety.value(), "Aufnahme")
	GameState.stats[&"burials"] = 18
	GameState.stats[&"prepared"] = 13
	GameState.stats[&"utilized"] = 1
	GameState.set_flag(&"insight_not_lorenz", true)
	var context := _graveyard.chapter_context(&"six_pits")
	_ui.notifications.clear()
	_ui.open_panel(&"slice_summary", context)
