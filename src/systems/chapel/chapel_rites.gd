class_name ChapelRites
extends Node
## Systems/Chapel (docs/PHASE6_DESIGN.md §2.4, §3.1, §3.4, §5.1), groups &"chapel_rites",
## &"saveable": funeral services on the catafalque and devotions for graves. The gravekeeper holds
## them as a lay rite; Phase 8's priest uses the same hold_service.
## Other systems are reached through their groups (buildings, corpse_manager, graveyard, reputation,
## piety, ghosts, player) and called directly – never from signal listeners.
## Saved: {devotions: {grave_id: chapel level it was held at}, services: n}. Mourners, candles and
## the bell are presentation only (ChapelAltar / MournerSet).

const GROUP := &"chapel_rites"
const SAVEABLE_GROUP := &"saveable"
const BUILDINGS_GROUP := &"buildings"
const MANAGER_GROUP := &"corpse_manager"
const GRAVEYARD_GROUP := &"graveyard"
const REPUTATION_GROUP := &"reputation"
const PIETY_GROUP := &"piety"
const GHOSTS_GROUP := &"ghosts"
const PLAYER_GROUP := &"player"
const BUILDING_ID := &"chapel"
const COIN_ITEM := &"coin"
const STAT_SERVICES := &"services_held"
const STAT_DEVOTIONS := &"devotions_held"
const PIETY_SERVICE := &"service"
const PIETY_DEVOTION := &"devotion"
const REASON_SERVICE := "Aussegnung"
const REASON_DEVOTION := "Andacht"
## Payment reason / notification of the family's fee (§2.4).
const TEXT_FEE := "Die Familie legt %d Münzen auf den Altar."
const TEXT_FEE_ONE := "Die Familie legt eine Münze auf den Altar."
const NOTIFY_KIND := &"info"

@export var save_id: String = "chapel"
@export var save_order: int = 37

## Rules; null = data/config/chapel_config.tres (resolved lazily).
var config: ChapelConfig

## grave_id -> chapel level the devotion was held at (the highest counts, never summed).
var _devotions: Dictionary[String, int] = {}
## Services held so far (chapter panel / journal).
var _services: int = 0
## Services held with mourners in the pews (chapel ≥ 2; chapter panel „davon mit Trauergästen", QA6-02).
var _mourned: int = 0


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(SAVEABLE_GROUP, true)


## = Buildings.level(&"chapel") (0 without a Buildings node).
func level() -> int:
	var buildings := _first(BUILDINGS_GROUP)
	if buildings == null or not buildings.has_method(&"level"):
		return 0
	return int(buildings.call(&"level", BUILDING_ID))


## "" or why no service for `corpse_id` can begin now (ChapelRules, minute of the clock).
func service_block_reason(corpse_id: String, inv: Inventory) -> String:
	var record := _live_record(corpse_id)
	return ChapelRules.service_block_reason(record, inv, TimeManager.minute_of_day, level(), _config())


## After the TimedAction (the time window was checked at its start): candle, fee (payment_received),
## reputation, piety (only an unharvested corpse), mark_service, stats.services_held, funeral_held.
## Returns the fee | -1 (nothing changed).
func hold_service(corpse_id: String, inv: Inventory) -> int:
	var record := _live_record(corpse_id)
	var lvl := level()
	var cfg := _config()
	var reason := ChapelRules.service_block_reason(record, inv, ChapelRules.ANY_MINUTE, lvl, cfg)
	if reason != "":
		push_warning("[ChapelRites] hold_service('%s'): %s" % [corpse_id, reason])
		return -1
	if not inv.remove_item(cfg.candle_item, cfg.candle_amount):
		return -1
	var fee := ChapelRules.fee(lvl, cfg)
	if fee > 0:
		inv.add_item(COIN_ITEM, fee)
		var text := fee_text(fee)
		EventBus.payment_received.emit(fee, text)
		EventBus.notification_requested.emit(text, NOTIFY_KIND)
	var rep := _first(REPUTATION_GROUP) as Reputation
	var points := ChapelRules.reputation(lvl, cfg)
	if rep != null and points != 0:
		rep.change(points, REASON_SERVICE)
	if record.harvested.is_empty():
		_piety_event(PIETY_SERVICE, REASON_SERVICE)
	var manager := _manager()
	if manager != null:
		manager.mark_service(corpse_id, TimeManager.day)
	_services += 1
	if ChapelRules.mourners(lvl, cfg) > 0:
		_mourned += 1
	GameState.add_stat(STAT_SERVICES, 1)
	EventBus.funeral_held.emit(corpse_id, lvl, fee)
	return fee


## "" or why no devotion for `grave_id` (ChapelRules with the level already held for it).
func devotion_block_reason(grave_id: String, inv: Inventory) -> String:
	return ChapelRules.devotion_block_reason(_grave(grave_id), devotion_level(grave_id), inv, level(), _config())


## Candle, _devotions[grave_id] = level, piety once per grave, devotion_held (the bonus the ghost
## now gets), stats.devotions_held. false = blocked, nothing changed.
func hold_devotion(grave_id: String, inv: Inventory) -> bool:
	var reason := devotion_block_reason(grave_id, inv)
	if reason != "":
		push_warning("[ChapelRites] hold_devotion('%s'): %s" % [grave_id, reason])
		return false
	var cfg := _config()
	if not inv.remove_item(cfg.candle_item, cfg.candle_amount):
		return false
	var first := not _devotions.has(grave_id)
	var lvl := level()
	_devotions[grave_id] = lvl
	if first:
		_piety_event(PIETY_DEVOTION, REASON_DEVOTION)
	GameState.add_stat(STAT_DEVOTIONS, 1)
	EventBus.devotion_held.emit(grave_id, devotion_bonus(grave_id))
	return true


## Chapel level the devotion for this grave was held at (0 = none).
func devotion_level(grave_id: String) -> int:
	return int(_devotions.get(grave_id, 0))


## The mood bonus the ghost of `grave_id` gets from its devotion (capped for robbed souls) – from
## GhostManager when present, else the uncapped devotion_mood_by_level value.
func devotion_bonus(grave_id: String) -> int:
	var ghosts := _first(GHOSTS_GROUP)
	if ghosts != null and ghosts.has_method(&"mood_info"):
		var info: Dictionary = ghosts.call(&"mood_info", grave_id)
		if info.has("devotion"):
			return int(info.devotion)
	return ChapelRules.at_level(_config().devotion_mood_by_level, devotion_level(grave_id))


## Every MARKED grave (Graveyard order): {grave_id, name, section, mood, held_level, block_reason}.
## mood = GhostManager.mood_of (&"" without ghosts); block_reason for the player's inventory.
func eligible_devotions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var graveyard := _graveyard()
	if graveyard == null:
		return out
	var ghosts := _first(GHOSTS_GROUP)
	var inv := _player_inventory()
	for grave: GraveRecord in graveyard.graves():
		if grave.state != GraveRecord.State.MARKED:
			continue
		var corpse := _record(grave.corpse_id)
		var mood: StringName = &""
		if ghosts != null and ghosts.has_method(&"mood_of"):
			mood = StringName(ghosts.call(&"mood_of", grave.id))
		out.append({
			"grave_id": grave.id,
			"name": corpse.display_name if corpse != null else "",
			"section": _section_name(graveyard.section_of(grave.id)),
			"mood": mood,
			"held_level": devotion_level(grave.id),
			"block_reason": devotion_block_reason(grave.id, inv),
		})
	return out


## Corpses with service_held whose grave is MARKED (chapter §1.5).
func services_buried() -> int:
	var manager := _manager()
	var graveyard := _graveyard()
	if manager == null or graveyard == null:
		return 0
	var n := 0
	for record: CorpseRecord in manager.records():
		if not record.service_held or record.grave_id == "":
			continue
		var grave := graveyard.get_grave(record.grave_id)
		if grave != null and grave.state == GraveRecord.State.MARKED and grave.corpse_id == record.id:
			n += 1
	return n


## Services held so far.
func services_held() -> int:
	return _services


## Services held with mourners (chapel level with mourners_by_level > 0).
func services_with_mourners() -> int:
	return _mourned


## Graves with a devotion (grave_id -> level), a copy.
func devotions() -> Dictionary[String, int]:
	return _devotions.duplicate()


## {devotions: {grave_id: level}, services: n, mourned: n} (§5.1; "mourned" QA6-02).
func save_state() -> Dictionary:
	var dev := {}
	for id: String in _devotions:
		dev[id] = _devotions[id]
	return {"devotions": dev, "services": _services, "mourned": _mourned}


## Tolerant: missing keys = nothing held; invalid entries are dropped with a warning; levels are
## clamped to 1…3.
func load_state(data: Dictionary) -> void:
	_devotions.clear()
	_services = 0
	_mourned = 0
	var raw: Variant = data.get("devotions", {})
	if raw is Dictionary:
		for key: Variant in raw:
			var v: Variant = raw[key]
			if (key is String or key is StringName) and (v is int or v is float) and roundi(float(v)) > 0:
				_devotions[String(key)] = clampi(roundi(float(v)), 1, 3)
			else:
				push_warning("[ChapelRites] invalid saved devotion %s: %s" % [str(key), str(v)])
	elif raw != null:
		push_warning("[ChapelRites] invalid saved devotions")
	var services: Variant = data.get("services", 0)
	if services is int or services is float:
		_services = maxi(0, roundi(float(services)))
	else:
		push_warning("[ChapelRites] invalid saved service count")
	var mourned: Variant = data.get("mourned", 0)
	if mourned is int or mourned is float:
		_mourned = clampi(roundi(float(mourned)), 0, _services)
	else:
		push_warning("[ChapelRites] invalid saved mourned count")


## The rules in use (ChapelConfig; data/config/chapel_config.tres unless set).
func get_config() -> ChapelConfig:
	return _config()


## "Die Familie legt 3 Münzen auf den Altar."
static func fee_text(fee: int) -> String:
	return TEXT_FEE_ONE if fee == 1 else TEXT_FEE % fee


# --- internals ---------------------------------------------------------------------------

func _piety_event(kind: StringName, reason: String) -> void:
	var piety := _first(PIETY_GROUP) as Piety
	if piety != null:
		piety.event(kind, reason)


func _live_record(corpse_id: String) -> CorpseRecord:
	var record := _record(corpse_id)
	var manager := _manager()
	if record != null and manager != null and record.location != CorpseRecord.LOCATION_BURIED:
		manager.refresh_decay(corpse_id)
	return record


func _record(corpse_id: String) -> CorpseRecord:
	var manager := _manager()
	return manager.get_record(corpse_id) if manager != null and corpse_id != "" else null


func _grave(grave_id: String) -> GraveRecord:
	var graveyard := _graveyard()
	return graveyard.get_grave(grave_id) if graveyard != null else null


func _section_name(section_id: StringName) -> String:
	if section_id == &"":
		return ""
	var data := Database.section(section_id) as SectionData
	return data.display_name if data != null and data.display_name != "" else String(section_id)


func _player_inventory() -> Inventory:
	var player := _first(PLAYER_GROUP) as Player
	return player.inventory if player != null else null


func _manager() -> CorpseManager:
	return _first(MANAGER_GROUP) as CorpseManager


func _graveyard() -> Graveyard:
	return _first(GRAVEYARD_GROUP) as Graveyard


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _config() -> ChapelConfig:
	if config == null:
		config = Database.config(&"chapel_config") as ChapelConfig
		if config == null:
			config = ChapelConfig.new()
	return config
