class_name Phase3Notices
extends Node
## Phase-3 notifications of the UI (docs/PHASE3_DESIGN.md §7), added by UIRoot:
## cemetery tier changes („Der Friedhof gilt jetzt als „Würdevoll“.“), reputation tier changes
## („In Hollerbrück bist du jetzt geschätzt.“), the daily stipend („Pflegegeld der Gemeinde:
## +2 Münzen“) and every ghost_spoke as a quiet info note. Section unlocks and ghost gifts
## already notify from their systems. Also remembers the sections unlocked since the last day
## summary (for its „Freigelegt“ row). Only emits notification_requested – no game state.
## After world_ready / game_loaded / new_game_started the known tiers are re-read silently, so
## loading never announces a change.

const NOTE_INFO := &"info"
const NOTE_REWARD := &"reward"
const NOTE_WARNING := &"warning"
const TEXT_STIPEND := "%s: +%d Münzen"
const TEXT_GHOST := "%s: „%s“"
const TEXT_GHOST_ANON := "Ein Geist: „%s“"

var _rating: StringName = &""
var _tier: StringName = &""
var _unlocked: Array[StringName] = []


func _ready() -> void:
	EventBus.cemetery_quality_changed.connect(_on_quality_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.payment_received.connect(_on_payment_received)
	EventBus.ghost_spoke.connect(_on_ghost_spoke)
	EventBus.section_unlocked.connect(_on_section_unlocked)
	EventBus.world_ready.connect(_resync.unbind(1))
	EventBus.game_loaded.connect(_resync.unbind(1))
	EventBus.new_game_started.connect(_resync)
	_resync()


func _exit_tree() -> void:
	for sig: Signal in [EventBus.cemetery_quality_changed, EventBus.reputation_changed, EventBus.payment_received,
			EventBus.ghost_spoke, EventBus.section_unlocked, EventBus.world_ready, EventBus.game_loaded,
			EventBus.new_game_started]:
		for c: Dictionary in sig.get_connections():
			if c.callable.get_object() == self:
				sig.disconnect(c.callable)


## Section ids unlocked since the last call (the day summary takes them).
func take_unlocked() -> Array[StringName]:
	var out := _unlocked.duplicate()
	_unlocked.clear()
	return out


func _resync() -> void:
	_rating = &""
	_tier = &""
	_unlocked.clear()
	if not is_inside_tree():
		return
	_read_current.call_deferred()


func _read_current() -> void:
	if not is_inside_tree():
		return
	_rating = CemeteryStatus.score(get_tree()).rating
	_tier = CemeteryStatus.reputation(get_tree()).tier


func _on_quality_changed(_total: int, rating: StringName) -> void:
	var text := Phase3Texts.rating_change_text(_rating, rating) if _rating != &"" else ""
	var up := CemeteryRating.TIERS.find(rating) > CemeteryRating.TIERS.find(_rating)
	_rating = rating
	if text != "":
		EventBus.notification_requested.emit(text, NOTE_REWARD if up else NOTE_WARNING)


func _on_reputation_changed(_value: int, tier: StringName, delta: int, _reason: String) -> void:
	var text := Phase3Texts.reputation_change_text(_tier, tier) if _tier != &"" else ""
	_tier = tier
	if text != "":
		EventBus.notification_requested.emit(text, NOTE_REWARD if delta > 0 else NOTE_WARNING)


func _on_payment_received(amount: int, reason: String) -> void:
	if reason == Reputation.REASON_STIPEND and amount > 0:
		EventBus.notification_requested.emit(TEXT_STIPEND % [reason, amount], NOTE_REWARD)


func _on_ghost_spoke(grave_id: String, _mood: StringName, text: String) -> void:
	if text == "":
		return
	var who := ghost_name(get_tree() if is_inside_tree() else null, grave_id)
	EventBus.notification_requested.emit(TEXT_GHOST % [who, text] if who != "" else TEXT_GHOST_ANON % text, NOTE_INFO)


func _on_section_unlocked(section_id: StringName) -> void:
	if not section_id in _unlocked:
		_unlocked.append(section_id)


## Display name of the person buried in `grave_id` ("" if unknown).
static func ghost_name(tree: SceneTree, grave_id: String) -> String:
	if tree == null:
		return ""
	var graveyard := tree.get_first_node_in_group(&"graveyard")
	var manager := tree.get_first_node_in_group(&"corpse_manager")
	if graveyard == null or manager == null or not graveyard.has_method(&"get_grave") or not manager.has_method(&"get_record"):
		return ""
	var grave := graveyard.call(&"get_grave", grave_id) as GraveRecord
	if grave == null or grave.corpse_id == "":
		return ""
	var record := manager.call(&"get_record", grave.corpse_id) as CorpseRecord
	return record.display_name if record != null else ""
