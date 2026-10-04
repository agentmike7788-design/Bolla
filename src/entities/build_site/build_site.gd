class_name BuildSite
extends Node3D
## Entities/site_<id> in the workyard (docs/PHASE5_DESIGN.md §2.1, §3.4, §4.1): visible (with
## collision and a prompt) from workshop_open while its station is not built. [E] opens the
## build-site panel (&"build_site", context {station (id), station_data, site, inventory,
## player}); request_build runs the build as a timed action (build_minutes, not cancellable) →
## Workshop.build (items + coins taken at the end, atomically). Afterwards the station
## (Workbench with requires_built) replaces the site.

const PANEL := &"build_site"
const PROMPT := "[E] Bauplatz: %s"
const WORKSHOP_GROUP := &"workshop"
const ANIM := &"interact"
const LABEL_BUILD := "%s bauen"
const TEXT_BUILT := "%s steht."
const TEXT_FAILED := "Bauen fehlgeschlagen."
const TEXT_BUSY := "Gerade nicht möglich."

@export var station_id: StringName
## Phase 7 (W-Welt, the pult in the crypt): hidden until this GameState flag is set (village_open);
## &"" = no flag (bit-identical for the workyard sites).
@export var requires_flag: StringName = &""

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

## Player of the last interaction (the panel builds for them).
var _player: Player


func _ready() -> void:
	EventBus.station_built.connect(_on_station_built)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.time_tick.connect(_on_time_tick)
	refresh()


## workshop_open ∧ the station not built (∧ requires_flag, Phase 7).
func is_active() -> bool:
	if requires_flag != &"" and not GameState.flag_on(requires_flag):
		return false
	var shop := workshop()
	return shop != null and shop.is_open() and not shop.is_built(station_id)


## Visible, with collision and interactable only while active.
func refresh() -> void:
	var on := is_active()
	if visible == on and (process_mode == Node.PROCESS_MODE_DISABLED) == (not on):
		return
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func can_interact(player: Player) -> bool:
	return player != null and is_active() and not player.is_busy() and not is_instance_valid(player.carried)


func get_interaction_prompt(player: Player) -> String:
	if not is_active():
		return ""
	if player != null and is_instance_valid(player.carried):
		return Player.TEXT_HANDS_FULL
	var data := station_data()
	return PROMPT % (data.display_name if data != null and data.display_name != "" else String(station_id))


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	_player = player
	EventBus.ui_panel_requested.emit(PANEL, {"station": station_id, "station_data": station_data(), "site": self,
			"inventory": player.inventory, "player": player})


## "" or why the station cannot be built now (Workshop.build_block_reason).
func block_reason(inv: Inventory) -> String:
	var shop := workshop()
	if shop == null:
		return TEXT_BUSY
	return shop.build_block_reason(station_id, inv)


## Panel: TimedAction build_minutes (not cancellable) → Workshop.build.
func request_build() -> void:
	var player := _player if is_instance_valid(_player) else _first_player()
	var data := station_data()
	if player == null or data == null or player.is_busy() or is_instance_valid(player.carried) or not is_active():
		_warn(TEXT_BUSY)
		return
	var reason := block_reason(player.inventory)
	if reason != "":
		_warn(reason)
		return
	player.start_timed_action(LABEL_BUILD % data.display_name, data.build_minutes, _finish_build.bind(player.inventory), false,
			ToolAnimConfig.clip_for(&"build_site", ANIM))


func _finish_build(inv: Inventory) -> void:
	var shop := workshop()
	if shop == null or not shop.build(station_id, inv):
		_warn(TEXT_FAILED)
		return
	var data := station_data()
	EventBus.notification_requested.emit(TEXT_BUILT % (data.display_name if data != null else String(station_id)), &"reward")
	refresh()


## Systems/Workshop (group workshop) or null.
func workshop() -> Workshop:
	return get_tree().get_first_node_in_group(WORKSHOP_GROUP) as Workshop if is_inside_tree() else null


## StationData of station_id (Database) or null.
func station_data() -> StationData:
	return Database.station(station_id) as StationData


func _on_station_built(id: StringName) -> void:
	if id == station_id:
		refresh()


func _on_game_loaded(_slot: int) -> void:
	refresh()


func _on_time_tick(_day: int, _minute: int) -> void:
	refresh()


func _first_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player if is_inside_tree() else null


func _warn(text: String) -> void:
	EventBus.notification_requested.emit(text, &"warning")


# --- Phase 6 (docs/PHASE6_DESIGN.md §2.5, §3.4) -------------------------------------------------

## Shed ≥ 2: fetch the missing `needs` {item_id: amount} from the shed into the player's inventory
## (TimedAction fetch_minutes, 0 → at once), then shed_supply_moved(&"fetch") – ShedSupply.run_fetch.
func request_fetch(needs: Dictionary) -> void:
	ShedSupply.run_fetch(get_tree() if is_inside_tree() else null, _acting_player(), needs)


## Shed 3: store the player's RESOURCE / MATERIAL surplus (ShedSupply.store_surplus), at once.
func request_store() -> void:
	ShedSupply.run_store(get_tree() if is_inside_tree() else null, _acting_player())


func _acting_player() -> Player:
	return _player if is_instance_valid(_player) else _first_player()
