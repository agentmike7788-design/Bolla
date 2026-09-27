class_name GameHud
extends Control
## Permanent HUD (docs §7): day + clock + sun/moon, objective line, delivery notice,
## resources (coins/wood/stone/linen + crafted items when > 0, crafted ones with a name
## caption so linen and shroud never look alike), cemetery quality,
## interaction prompt (dimmed when disabled) and the timed-action bar.
## Notifications and the reward card are separate overlay nodes (NotificationStack,
## RewardCard). Updates from EventBus + inventory.changed; refresh_all() pulls
## everything (UIRoot calls it on world_ready / game_loaded / new_game_started).
## The widgets are built by HudBuilder; this script wires the signals and updates them.

const BASE_ITEMS: Array[StringName] = [&"coin", &"wood", &"stone", &"linen"]
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const GRAVEYARD_GROUP := &"graveyard"
const FLAG_DELIVERY_SKIPPED := &"delivery_skipped"
const KEY_INTERACT := "E"
const KEY_PREFIX := "[E]"
const TEXT_DAY := "Tag %d"
## Same term as the day / slice summaries and the debug console.
const TEXT_QUALITY_CAPTION := "Friedhofsqualität"
const TEXT_QUALITY := "%d · %s"
const TEXT_NEXT_TIER := "%s ab %d"
## Same wording as CorpseManager's notification for the same skip.
const TEXT_NOTICE := "Heute keine Leiche: %s"
const TEXT_NOTICE_UNKNOWN := "Heute keine Leiche – die Bahre war belegt oder kein Grab frei."
const TEXT_ACTION_RUNNING := "%s …"

@export var margin: float = 28.0
@export var top_panel_width: float = 560.0
@export var icon_edge: float = 50.0
@export var action_bar_width: float = 440.0

var clock_label: Label
var day_label: Label
var day_icon: DayIcon
var objective_label: Label
var notice_label: Label
var quality_caption: Label
var quality_label: Label
var next_tier_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var prompt_key: PanelContainer
var action_panel: PanelContainer
var action_label: Label
var action_bar: ProgressBar

## item id -> {chip: Control, count: Label, caption: Label (crafted items only)}
var _chips: Dictionary[StringName, Dictionary] = {}
var _inventory: Inventory
var _prompt_text: String = ""
var _prompt_enabled: bool = false
var _action_running: bool = false
var _objective_dirty: bool = false
var _skipped_day: int = 0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudBuilder.build_clock_panel(self)
	_chips = HudBuilder.build_resource_panel(self)
	HudBuilder.build_bottom(self)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.day_started.connect(_on_day_started)
	EventBus.interaction_focus_changed.connect(set_prompt)
	EventBus.timed_action_started.connect(_on_action_started)
	EventBus.timed_action_progress.connect(_on_action_progress)
	EventBus.timed_action_finished.connect(_on_action_finished)
	EventBus.cemetery_quality_changed.connect(_on_quality_changed)
	EventBus.delivery_skipped.connect(_on_delivery_skipped)
	EventBus.ui_modal_changed.connect(_on_modal_changed)
	EventBus.corpse_arrived.connect(_mark_objective_dirty.unbind(1))
	EventBus.corpse_updated.connect(_mark_objective_dirty.unbind(1))
	EventBus.corpse_buried.connect(_mark_objective_dirty.unbind(2))
	EventBus.grave_state_changed.connect(_mark_objective_dirty.unbind(2))
	EventBus.slice_completed.connect(_mark_objective_dirty)
	refresh_all()


## Uses `player.inventory` (duck-typed; null unbinds).
func bind_player(player: Node) -> void:
	var inv: Inventory = player.get(&"inventory") as Inventory if is_instance_valid(player) else null
	if inv == _inventory:
		return
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)
	_inventory = inv
	if _inventory != null:
		_inventory.changed.connect(_on_inventory_changed)
	_refresh_resources()
	_mark_objective_dirty()


## Pulls every value from the autoloads and the world groups.
func refresh_all() -> void:
	_refresh_clock(TimeManager.day, TimeManager.minute_of_day)
	_refresh_resources()
	var graveyard := _group_node(GRAVEYARD_GROUP)
	if graveyard != null and graveyard.has_method(&"total_quality"):
		var total := int(graveyard.call(&"total_quality"))
		_on_quality_changed(total, CemeteryRating.rating(total, _economy()))
	else:
		_on_quality_changed(0, CemeteryRating.rating(0, _economy()))
	# The flag (day of the skip) is saved, the reason is not: keep a live reason if known.
	var skipped: Variant = GameState.get_flag(FLAG_DELIVERY_SKIPPED)
	if (skipped is int or skipped is float) and int(skipped) == TimeManager.day:
		if _skipped_day != TimeManager.day:
			_show_notice(TEXT_NOTICE_UNKNOWN, TimeManager.day)
	else:
		_hide_notice()
	_apply_modal_visibility()
	refresh_objective()


func refresh_objective() -> void:
	_objective_dirty = false
	objective_label.text = ObjectiveResolver.current(_records(), _graves(), _inventory,
			TimeManager.minute_of_day, GameState.flags)


## Interaction prompt ("" hides it). A leading "[E]" in the text is dropped (keycap shown).
func set_prompt(prompt: String, enabled: bool) -> void:
	_prompt_text = prompt.strip_edges().trim_prefix(KEY_PREFIX).strip_edges()
	_prompt_enabled = enabled
	prompt_label.text = _prompt_text
	prompt_key.visible = enabled
	prompt_label.theme_type_variation = &"PromptLabel" if enabled else &"HudDimLabel"
	_apply_modal_visibility()


# --- accessors (tests, debug) -------------------------------------------------------------

func clock_text() -> String:
	return clock_label.text


func day_text() -> String:
	return day_label.text


func objective_text() -> String:
	return objective_label.text


func notice_text() -> String:
	return notice_label.text if notice_label.visible else ""


func quality_text() -> String:
	return quality_label.text


func prompt_text() -> String:
	return _prompt_text if prompt_panel.visible else ""


func prompt_enabled() -> bool:
	return _prompt_enabled


## Count shown for an item ("" when its chip is hidden).
func resource_text(id: StringName) -> String:
	if not _chips.has(id):
		return ""
	var chip: Control = _chips[id].chip
	return (_chips[id].count as Label).text if chip.visible else ""


## Caption in front of the cemetery quality value.
func quality_caption_text() -> String:
	return quality_caption.text


## Name caption under a chip ("" when the chip is hidden or has none).
func resource_caption(id: StringName) -> String:
	if not _chips.has(id) or not (_chips[id].chip as Control).visible:
		return ""
	var caption: Label = _chips[id].get("caption")
	return caption.text if caption != null and caption.visible else ""


func action_visible() -> bool:
	return action_panel.visible


func action_ratio() -> float:
	return action_bar.value


# --- updates ------------------------------------------------------------------------------

func _refresh_clock(day: int, minute_of_day: int) -> void:
	day_label.text = TEXT_DAY % day
	clock_label.text = UIKit.clock(minute_of_day)
	day_icon.night = TimeManager.is_night()


func _refresh_resources() -> void:
	for id: StringName in _chips:
		var count := _inventory.count(id) if is_instance_valid(_inventory) else 0
		(_chips[id].count as Label).text = str(count)
		(_chips[id].chip as Control).visible = id in BASE_ITEMS or count > 0


func _show_notice(text: String, day: int) -> void:
	_skipped_day = day
	notice_label.text = text
	notice_label.visible = true


func _hide_notice() -> void:
	_skipped_day = 0
	notice_label.text = ""
	notice_label.visible = false


## Prompt and action bar belong to the world: hidden while a panel/dialogue is open.
func _apply_modal_visibility() -> void:
	var modal := UIState.is_modal()
	prompt_panel.visible = _prompt_text != "" and not modal
	action_panel.visible = _action_running and not modal


func _mark_objective_dirty() -> void:
	if _objective_dirty:
		return
	_objective_dirty = true
	refresh_objective.call_deferred()


func _on_time_tick(day: int, minute_of_day: int) -> void:
	_refresh_clock(day, minute_of_day)
	_mark_objective_dirty()


func _on_day_started(day: int) -> void:
	if _skipped_day != 0 and _skipped_day != day:
		_hide_notice()


func _on_inventory_changed() -> void:
	_refresh_resources()
	_mark_objective_dirty()


func _on_quality_changed(total: int, rating: StringName) -> void:
	quality_label.text = TEXT_QUALITY % [total, CemeteryRating.label(rating)]
	next_tier_label.text = _next_tier_text(total)
	next_tier_label.visible = next_tier_label.text != ""


func _next_tier_text(total: int) -> String:
	var thresholds := _economy().rating_thresholds
	for i: int in thresholds.size():
		if total < thresholds[i] and i + 1 < CemeteryRating.TIERS.size():
			return TEXT_NEXT_TIER % [CemeteryRating.label(CemeteryRating.TIERS[i + 1]), thresholds[i]]
	return ""


func _on_delivery_skipped(day: int, reason: String) -> void:
	_show_notice(TEXT_NOTICE % reason if reason != "" else TEXT_NOTICE_UNKNOWN, day)


func _on_action_started(label: String, _duration_sec: float) -> void:
	_action_running = true
	action_label.text = TEXT_ACTION_RUNNING % label
	action_bar.value = 0.0
	_apply_modal_visibility()


func _on_action_progress(ratio: float) -> void:
	action_bar.value = clampf(ratio, 0.0, 1.0)


func _on_action_finished(_completed: bool) -> void:
	_action_running = false
	_apply_modal_visibility()


func _on_modal_changed(_open: bool) -> void:
	_apply_modal_visibility()


func _records() -> Array[CorpseRecord]:
	var out: Array[CorpseRecord] = []
	var manager := _group_node(CORPSE_MANAGER_GROUP)
	if manager != null and manager.has_method(&"records"):
		out.assign(manager.call(&"records"))
	return out


func _graves() -> Array[GraveRecord]:
	var out: Array[GraveRecord] = []
	var graveyard := _group_node(GRAVEYARD_GROUP)
	if graveyard != null and graveyard.has_method(&"graves"):
		out.assign(graveyard.call(&"graves"))
	return out


func _group_node(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _economy() -> EconomyConfig:
	var cfg := Database.config(&"economy_config") as EconomyConfig
	return cfg if cfg != null else EconomyConfig.new()
