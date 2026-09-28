class_name Ossuary
extends Node
## Systems/Ossuary (docs/PHASE6_DESIGN.md §2.3, §3.1, §3.4, §5.1), groups &"ossuary", &"saveable":
## lifted (waiting) and reinterred old graves in lifting order, the sealed passage / grille of the
## crypt and its clue. Callers change it directly: GravePlot → lift (after the TimedAction) →
## Graveyard.lift_old; OssuaryShelf → reinter; Buildings.apply_levels → on_crypt_level;
## SealedPassage → look_at_passage. Listeners (shelf, passage visuals) only read.
## Save (§5.1): {"lifted": [ids in lifting order], "reinterred": [ids], "passage": "sealed"}.

const GROUP := &"ossuary"
const PASSAGE_HIDDEN := &"hidden"
const PASSAGE_SEALED := &"sealed"
const PASSAGE_GRILLE := &"grille"
const PASSAGES: Array[StringName] = [PASSAGE_HIDDEN, PASSAGE_SEALED, PASSAGE_GRILLE]

const GRAVEYARD_GROUP := &"graveyard"
const BUILDINGS_GROUP := &"buildings"
const JOURNAL_GROUP := &"journal"
const REPUTATION_GROUP := &"reputation"
const PIETY_GROUP := &"piety"
const CRYPT := &"crypt"
const COIN_ITEM := &"coin"
const STAT_LIFTED := &"bones_lifted"
const STAT_REINTERRED := &"bones_reinterred"
## Reputation / piety event (ReputationConfig.event_points, PietyConfig.events).
const EVENT_REINTERRED := &"reinterred"
## Set once the passage was looked at and its clue given (§5.1 flags).
const FLAG_PASSAGE_SEEN := &"c_crypt_draft_seen"
const NOTE_KIND := &"info"
const REASON_FEE := "Umbettung von %s"
const REASON_EVENT := "%s umgebettet"
## §2.3: what the player sees at the walled-up door (level 2) and through the grille (level 3).
const TEXT_PASSAGE_SEALED := "Hinter dem Beinhaus eine zugemauerte Tür, jünger als das Gewölbe. Durch die Fugen zieht es kalt. Der Zug kommt von Nordosten, von unter dem Hof her, Richtung Birkenhang."
const TEXT_PASSAGE_GRILLE := "Stufen, die weiter hinabführen, als die Laterne reicht. Ganz unten ein Schimmer, bläulich, der nicht flackert wie Feuer."

@export var save_id: String = "ossuary"
@export var save_order: int = 36

## Rules; null = data/config/crypt_config.tres (resolved lazily).
var config: CryptConfig
## Old grave data; empty = Database.old_graves() (tests assign fixtures).
var old_grave_data: Array[OldGraveData] = []
## Calendar of the game year; null = data/config/stone_config.tres.
var stone_config: StoneConfig

## Lifted old graves in lifting order (incl. the reinterred ones).
var _lifted: PackedStringArray = []
## Reinterred old graves (a prefix of _lifted – reinterment is FIFO).
var _reinterred: PackedStringArray = []
var _passage: StringName = PASSAGE_HIDDEN


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## Ossuary places of the current crypt level.
func capacity() -> int:
	return OssuaryRules.capacity(_crypt_level(), _cfg())


## Lifted (waiting) + reinterred.
func used() -> int:
	return _lifted.size()


func lift_block_reason(grave_id: String, inv: Inventory) -> String:
	var graveyard := _graveyard()
	var grave := graveyard.get_grave(grave_id) if graveyard != null else null
	return OssuaryRules.lift_block_reason(grave, data_of(grave_id), _crypt_level(), used(), inv, year(), _cfg(), is_open())


## After the TimedAction: bone_box → bone_box_full, Graveyard.lift_old, bones_lifted, stats.bones_lifted.
func lift(grave_id: String, inv: Inventory) -> bool:
	if lift_block_reason(grave_id, inv) != "":
		return false
	var cfg := _cfg()
	var graveyard := _graveyard()
	if not inv.remove_item(cfg.box_item, 1):
		return false
	if inv.add_item(cfg.full_item, 1) > 0:
		inv.add_item(cfg.box_item, 1)
		EventBus.notification_requested.emit(OssuaryRules.TEXT_NO_ROOM, &"warning")
		return false
	if not graveyard.lift_old(grave_id):
		inv.remove_item(cfg.full_item, 1)
		inv.add_item(cfg.box_item, 1)
		return false
	_lifted.append(grave_id)
	GameState.add_stat(STAT_LIFTED, 1)
	EventBus.bones_lifted.emit(grave_id)
	return true


## Lifted, not yet reinterred (lifting order).
func pending() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in _lifted:
		if not _reinterred.has(id):
			out.append(id)
	return out


func reinterred() -> PackedStringArray:
	return _reinterred.duplicate()


## FIFO; takes a bone_box_full; fee (payment_received), reputation, piety, the line;
## bones_reinterred; Buildings.check_goal; grave_id | "".
func reinter(inv: Inventory) -> String:
	var waiting := pending()
	var cfg := _cfg()
	if waiting.is_empty() or inv == null or not inv.remove_item(cfg.full_item, 1):
		return ""
	var grave_id := waiting[0]
	_reinterred.append(grave_id)
	var data := data_of(grave_id)
	var who := data.display_name if data != null and data.display_name != "" else grave_id
	if cfg.reinter_fee > 0:
		inv.add_item(COIN_ITEM, cfg.reinter_fee)
		EventBus.payment_received.emit(cfg.reinter_fee, REASON_FEE % who)
	var rep := _first(REPUTATION_GROUP)
	if rep != null and rep.has_method(&"event"):
		rep.call(&"event", EVENT_REINTERRED, REASON_EVENT % who)
	var piety := _first(PIETY_GROUP)
	if piety != null and piety.has_method(&"event"):
		piety.call(&"event", EVENT_REINTERRED, REASON_EVENT % who)
	if data != null and data.reinter_line != "":
		EventBus.notification_requested.emit(data.reinter_line, NOTE_KIND)
	GameState.add_stat(STAT_REINTERRED, 1)
	EventBus.bones_reinterred.emit(grave_id, _reinterred.size())
	var buildings := _first(BUILDINGS_GROUP)
	if buildings != null and buildings.has_method(&"check_goal"):
		buildings.call(&"check_goal")
	return grave_id


## Unlocks the passage / grille (state only, no note). Never goes back.
func on_crypt_level(level: int) -> void:
	var cfg := _cfg()
	var state := PASSAGE_HIDDEN
	if level >= cfg.grille_level:
		state = PASSAGE_GRILLE
	elif level >= cfg.passage_level:
		state = PASSAGE_SEALED
	if PASSAGES.find(state) > PASSAGES.find(_passage):
		_passage = state


## &"hidden" | &"sealed" | &"grille".
func passage_state() -> StringName:
	return _passage


## The clue c_crypt_draft once (Journal.add_clue), texts §2.3. At the grille the clue still comes
## once when the walled-up door was never looked at (crypt 3 built straight after 2).
func look_at_passage() -> void:
	if _passage == PASSAGE_HIDDEN:
		return
	EventBus.notification_requested.emit(TEXT_PASSAGE_GRILLE if _passage == PASSAGE_GRILLE else TEXT_PASSAGE_SEALED,
			NOTE_KIND)
	if GameState.has_flag(FLAG_PASSAGE_SEEN):
		return
	var journal := _first(JOURNAL_GROUP)
	if journal != null and journal.has_method(&"add_clue"):
		journal.call(&"add_clue", _cfg().passage_clue)
	GameState.set_flag(FLAG_PASSAGE_SEEN, true)


func save_state() -> Dictionary:
	return {"lifted": Array(_lifted), "reinterred": Array(_reinterred), "passage": String(_passage)}


## Tolerant: bad / duplicate / unknown ids are dropped (warning), reinterred ⊆ lifted and FIFO
## (a prefix of lifted), an unknown passage state → hidden.
func load_state(data: Dictionary) -> void:
	_lifted = PackedStringArray()
	_reinterred = PackedStringArray()
	_passage = PASSAGE_HIDDEN
	var lifted: Variant = data.get("lifted", [])
	if lifted is Array or lifted is PackedStringArray:
		for raw: Variant in lifted:
			var id := str(raw) if raw is String or raw is StringName else ""
			if id == "" or _lifted.has(id):
				push_warning("[Ossuary] saved lifted entry '%s' skipped" % str(raw))
				continue
			if not _known_ids().is_empty() and not _known_ids().has(id):
				push_warning("[Ossuary] saved lifted grave '%s' is no old grave – skipped" % id)
				continue
			_lifted.append(id)
	var done: Variant = data.get("reinterred", [])
	if done is Array or done is PackedStringArray:
		var wanted := {}
		for raw: Variant in done:
			wanted[str(raw)] = true
		for id: String in _lifted:
			if not wanted.has(id):
				break
			_reinterred.append(id)
			wanted.erase(id)
		if not wanted.is_empty():
			push_warning("[Ossuary] reinterred graves out of lifting order skipped: %s" % str(wanted.keys()))
	var passage := StringName(str(data.get("passage", PASSAGE_HIDDEN)))
	_passage = passage if PASSAGES.has(passage) else PASSAGE_HIDDEN


## Flag buildings_open (BuildingsConfig.open_flag).
func is_open() -> bool:
	var buildings := _first(BUILDINGS_GROUP)
	var cfg: BuildingsConfig = buildings.get(&"config") as BuildingsConfig if buildings != null else null
	if cfg == null:
		cfg = Database.config(&"buildings_config") as BuildingsConfig
	return GameState.has_flag(cfg.open_flag if cfg != null else &"buildings_open")


## The game year of today (StoneCalendar, §2.3 rest period).
func year() -> int:
	return StoneCalendar.year_of(TimeManager.day, _stone_config())


## OldGraveData of `grave_id` (null for other graves).
func data_of(grave_id: String) -> OldGraveData:
	for data: OldGraveData in _old_graves():
		if data.grave_id == grave_id:
			return data
	return null


## The CryptConfig in use (config, else data/config/crypt_config.tres).
func rules() -> CryptConfig:
	return _cfg()


## Minutes of lifting for `inv`'s shovel (60 / 50 / 35).
func lift_minutes(inv: Inventory, actions: ActionConfig = null) -> int:
	var a := actions
	if a == null:
		a = Database.config(&"action_config") as ActionConfig
	return OssuaryRules.lift_minutes(_cfg(), a, inv)


# --- lookups ------------------------------------------------------------------------------

func _crypt_level() -> int:
	var buildings := _first(BUILDINGS_GROUP)
	return int(buildings.call(&"level", CRYPT)) if buildings != null and buildings.has_method(&"level") else 0


func _old_graves() -> Array[OldGraveData]:
	if old_grave_data.is_empty():
		for res: Resource in Database.old_graves():
			if res is OldGraveData:
				old_grave_data.append(res as OldGraveData)
	return old_grave_data


func _known_ids() -> Dictionary:
	var out := {}
	for data: OldGraveData in _old_graves():
		out[data.grave_id] = true
	return out


func _graveyard() -> Graveyard:
	return _first(GRAVEYARD_GROUP) as Graveyard


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _cfg() -> CryptConfig:
	if config == null:
		config = Database.config(&"crypt_config") as CryptConfig
		if config == null:
			config = CryptConfig.new()
	return config


func _stone_config() -> StoneConfig:
	if stone_config == null:
		stone_config = Database.config(&"stone_config") as StoneConfig
		if stone_config == null:
			stone_config = StoneConfig.new()
	return stone_config
