class_name CorpseManager
extends Node
## Owns all CorpseRecords and their nodes (WorldRoot/Systems/CorpseManager).
## Groups corpse_manager + saveable. Delivers the day's corpses (docs §2.5, Phase 3 §2.7: up
## to ReputationRules.deliveries_on per day, one free bier each) on time_tick / time_skipped –
## a corpse delivered inside a skip arrived at the delivery minute – and applies decay on
## hour_changed / time_skipped as a function of the minutes since arrival.
## _ready only wires signals and data – corpses appear via delivery, spawn_corpse or load_state.

const GROUP := &"corpse_manager"
const SAVEABLE_GROUP := &"saveable"
const PLAYER_GROUP := &"player"
const DROPOFF_GROUP := &"dropoff"
const GRAVEYARD_GROUP := &"graveyard"
const REPUTATION_GROUP := &"reputation"
const EVENT_MISSED_DELIVERY := &"missed_delivery"
const REASON_MISSED := "Lieferung verpasst"
const REASON_VALUABLES := "Wertsachen genommen"
const DEFAULT_CORPSE_SCENE := "res://src/entities/corpse/corpse.tscn"
const ID_FORMAT := "corpse_%04d"
const SHROUD_ITEM := &"shroud"
const COIN_ITEM := &"coin"
const FLAG_DELIVERY_SKIPPED := CorpseDeliveryRules.FLAG_DELIVERY_SKIPPED
const STAT_MISSED := CorpseDeliveryRules.STAT_MISSED
const STAT_VALUABLES_TAKEN := &"valuables_taken"
const STAT_REPUTATION := &"reputation"
## Locations a corpse can be spawned at or put down to.
const PLACE_LOCATIONS: Array[StringName] = [CorpseRecord.LOCATION_DROPOFF, CorpseRecord.LOCATION_TABLE, CorpseRecord.LOCATION_GROUND]
const MINUTES_PER_HOUR := CorpseDecay.MINUTES_PER_HOUR
const MINUTES_PER_DAY := CorpseDeliveryRules.MINUTES_PER_DAY
## Decay rules: CorpseDecay; delivery rules: CorpseDeliveryRules (constants kept here as API).
const START_FRESHNESS := CorpseDecay.START_FRESHNESS
const FRESHNESS_RESOLUTION := CorpseDecay.FRESHNESS_RESOLUTION

const REASON_OCCUPIED := CorpseDeliveryRules.REASON_OCCUPIED
const REASON_NO_PLOT := CorpseDeliveryRules.REASON_NO_PLOT
const REASON_NO_DROPOFF := CorpseDeliveryRules.REASON_NO_DROPOFF
const NOTE_SKIPPED := CorpseDeliveryRules.NOTE_SKIPPED

@export var save_id: String = "corpse_manager"
@export var save_order: int = 0
## Scene of one corpse; null = DEFAULT_CORPSE_SCENE (loaded on first spawn).
@export var corpse_scene: PackedScene
## Parent for corpses on the ground / at the dropoff; empty or missing = this node.
@export var container_path: NodePath

## Generation tables; null = Database.corpse_tables() (resolved in _ready or on first use).
var tables: CorpseTables
## Reputation cost of taken valuables and the freshness stages; null = EconomyConfig.resolve().
var economy: EconomyConfig
## Deliveries per tier; null = Database.config(&"reputation_config").
var reputation_config: ReputationConfig

## id -> record, in spawn order.
var _records: Dictionary[String, CorpseRecord] = {}
## id -> corpse node (only for corpses that are not buried).
var _nodes: Dictionary[String, Node3D] = {}
var _next_serial: int = 1
## Last day a delivery was attempted (0 = never) and the corpses it brought (empty = none).
var _last_delivery_day: int = 0
var _last_delivery_ids: Array[String] = []
## day -> number of corpses generated that day (spawn index of the next one).
var _spawn_counts: Dictionary[int, int] = {}
## The player carrying a corpse (from pick_up / post_load).
var _carrier_ref: WeakRef


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(SAVEABLE_GROUP, true)


func _ready() -> void:
	if _tables() == null:
		push_warning("[CorpseManager] no corpse tables at %s – no deliveries" % Database.CORPSE_TABLES)
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.time_skipped.connect(_on_time_skipped)
	EventBus.hour_changed.connect(_on_hour_changed)


func records() -> Array[CorpseRecord]:
	var out: Array[CorpseRecord] = []
	out.assign(_records.values())
	return out


func get_record(id: String) -> CorpseRecord:
	return _records.get(id) as CorpseRecord


func get_corpse_node(id: String) -> Corpse:
	return _node(id) as Corpse


## Docs §2.5 / Phase 3 §2.7: once per day; each corpse needs a free dropoff and more free plots
## than unburied corpses. Repeated calls for the same day return that day's first corpse.
## Returns null when nothing was delivered (or for a day before the last delivery day).
func try_daily_delivery(day: int) -> CorpseRecord:
	_deliver(day, TimeManager.total_minutes())
	if day != _last_delivery_day:
		return null
	var list := deliveries_of(day)
	return list[0] if not list.is_empty() else null


## The corpses delivered on `day` (up to deliveries_due(day)), in delivery order. Exact for the
## last delivery day; for earlier days the corpses generated for that day (seed of one of its
## spawn indices – a debug spawn of that day counts as well).
func deliveries_of(day: int) -> Array[CorpseRecord]:
	var out: Array[CorpseRecord] = []
	if day <= 0 or day > _last_delivery_day:
		return out
	if day == _last_delivery_day:
		for id: String in _last_delivery_ids:
			var record := get_record(id)
			if record != null:
				out.append(record)
		return out
	var seeds := {}
	for index: int in _spawn_counts.get(day, 0):
		seeds[CorpseGenerator.seed_for(day, index)] = true
	for record: CorpseRecord in _records.values():
		if seeds.has(record.seed):
			out.append(record)
	return out


## Corpses the carter brings on `day`: ReputationRules.deliveries_on(day, tier) with the tier of
## the node in group "reputation" (0 on even days while disreputable); 1 without that node.
func deliveries_due(day: int) -> int:
	var rep := _reputation()
	if rep == null:
		return 1
	return maxi(0, ReputationRules.deliveries_on(day, rep.tier(), _reputation_config()))


## try_daily_delivery checked at world time `now_total` (the time of the triggering signal).
## The corpses arrived at the day's delivery minute – also when the check runs later, inside a
## skip (rest, timed action) – but never after now, and have decayed since then.
## When every remaining EMPTY/DUG plot is already reserved by a corpse waiting for burial, the
## cemetery is full for good (graves are never emptied again; LOCKED plots never count): the
## carter brings nothing more, which is no missed delivery. No delivery due (disreputable on an
## even day) is quiet as well. Only a missing free bier is a missed delivery: once per day,
## missed_deliveries += the corpses left over, reputation event missed_delivery.
func _deliver(day: int, now_total: int) -> void:
	if day <= _last_delivery_day:
		return
	_last_delivery_day = day
	_last_delivery_ids.clear()
	var t := _tables()
	if t == null:
		push_warning("[CorpseManager] delivery on day %d without corpse tables" % day)
		return
	var due := deliveries_due(day)
	var graveyard := _first_in_group(GRAVEYARD_GROUP)
	var dropoffs: Array[Node] = []
	if is_inside_tree():
		dropoffs = get_tree().get_nodes_in_group(DROPOFF_GROUP)
	for i: int in due:
		if CorpseDeliveryRules.is_cemetery_full(graveyard, unburied_count()):
			return
		var free := CorpseDeliveryRules.free_dropoffs(dropoffs)
		var dropoff: Node = free[0] if not free.is_empty() else (dropoffs[0] if not dropoffs.is_empty() else null)
		var reason := CorpseDeliveryRules.blocked_reason(dropoff, graveyard, unburied_count(), DROPOFF_GROUP)
		if reason != "":
			CorpseDeliveryRules.report_skip(day, reason, due - i)
			var rep := _reputation()
			if reason == REASON_OCCUPIED and rep != null:
				rep.event(EVENT_MISSED_DELIVERY, REASON_MISSED)
			return
		var at := CorpseDeliveryRules.slot_transform(dropoff)
		var record := CorpseGenerator.generate(CorpseGenerator.seed_for(day, _take_spawn_index(day)), t, day)
		var arrival := CorpseDeliveryRules.arrival_total(day, now_total, t)
		record = _spawn(record, at, CorpseRecord.LOCATION_DROPOFF, arrival, now_total)
		if record != null:
			_last_delivery_ids.append(record.id)


## Adds a corpse at `at` (world transform). record null = generated for TimeManager.day
## with the next spawn index (debug). An empty record.id gets the next serial id.
func spawn_corpse(record: CorpseRecord = null, at: Transform3D = Transform3D.IDENTITY, location: StringName = &"dropoff") -> CorpseRecord:
	var now := TimeManager.total_minutes()
	return _spawn(record, at, location, now, now)


## spawn_corpse with the arrival at `arrival_total`, decayed up to `now_total`.
func _spawn(record: CorpseRecord, at: Transform3D, location: StringName, arrival_total: int, now_total: int) -> CorpseRecord:
	if not location in PLACE_LOCATIONS:
		push_warning("[CorpseManager] cannot spawn a corpse at location '%s'" % location)
		return null
	if record == null:
		var t := _tables()
		if t == null:
			push_warning("[CorpseManager] spawn_corpse without corpse tables")
			return null
		var day := TimeManager.day
		record = CorpseGenerator.generate(CorpseGenerator.seed_for(day, _take_spawn_index(day)), t, day)
	if record.id == "":
		record.id = _new_id()
	elif _records.has(record.id):
		push_warning("[CorpseManager] corpse '%s' exists already" % record.id)
		return null
	record.arrival_total_minutes = arrival_total
	record.last_decay_total = arrival_total
	_decay_record(record, now_total)
	record.location = location
	record.grave_id = ""
	CorpseNodePlacement.store_transform(record, at)
	_records[record.id] = record
	_create_node(record)
	EventBus.corpse_arrived.emit(record.id)
	return record


## Hands the corpse to the player (player.attach_carried does the reparenting).
func pick_up(id: String, player: Player) -> bool:
	var record := _live_record(id, "pick_up")
	if record == null or player == null:
		if player == null:
			push_warning("[CorpseManager] pick_up('%s') without player" % id)
		return false
	if record.location == CorpseRecord.LOCATION_CARRIED or _carried_record() != null:
		return false
	if is_instance_valid(player.get("carried")):
		return false
	var node := _node(id)
	if node == null:
		node = _create_node(record)
	if node == null:
		return false
	record.location = CorpseRecord.LOCATION_CARRIED
	_carrier_ref = weakref(player)
	player.attach_carried(node, id)
	EventBus.corpse_updated.emit(id)
	return true


## Puts the corpse at `xform` (world transform) under `parent` (e.g. a table slot) or the
## container. A carried corpse is detached from the player first.
func put_down(id: String, location: StringName, xform: Transform3D, parent: Node3D = null) -> bool:
	var record := _live_record(id, "put_down")
	if record == null:
		return false
	if not location in PLACE_LOCATIONS:
		push_warning("[CorpseManager] cannot put a corpse down at location '%s'" % location)
		return false
	if record.location == CorpseRecord.LOCATION_CARRIED:
		_release_from_carrier()
	var node := _node(id)
	var target: Node = parent if parent != null else _container()
	if node == null:
		node = _create_node(record, target)
	if node == null:
		return false
	CorpseNodePlacement.place(node, target, xform)
	record.location = location
	CorpseNodePlacement.store_transform(record, xform)
	EventBus.corpse_updated.emit(id)
	return true


func examine(id: String) -> void:
	var record := _live_record(id, "examine")
	if record == null or record.examined:
		return
	record.examined = true
	EventBus.corpse_updated.emit(id)


## Consumes one shroud. Refused while the valuables decision is open or when already shrouded.
func apply_shroud(id: String, inv: Inventory) -> bool:
	var record := _live_record(id, "apply_shroud")
	if record == null or record.shrouded or record.needs_valuables_decision():
		return false
	if inv == null or not inv.remove_item(SHROUD_ITEM, 1):
		return false
	record.shrouded = true
	EventBus.corpse_updated.emit(id)
	return true


## Final decision on examined valuables. take: coins into inv, stats valuables_taken and reputation.
func decide_valuables(id: String, take: bool, inv: Inventory) -> void:
	var record := _live_record(id, "decide_valuables")
	if record == null or not record.needs_valuables_decision():
		return
	if take:
		if inv == null:
			push_warning("[CorpseManager] decide_valuables('%s') without inventory" % id)
			return
		inv.add_item(COIN_ITEM, record.valuables_coins)
		GameState.add_stat(STAT_VALUABLES_TAKEN, 1)
		var rep := _reputation()
		if rep != null:
			rep.change(_economy().valuables_reputation, REASON_VALUABLES)
		else:
			GameState.add_stat(STAT_REPUTATION, _economy().valuables_reputation)
		record.valuables_decision = CorpseRecord.DECISION_TAKEN
	else:
		record.valuables_decision = CorpseRecord.DECISION_LEFT
	EventBus.corpse_updated.emit(id)


## Called by Graveyard.bury: final decay, location buried, open valuables count as left, node freed.
func mark_buried(id: String, grave_id: String) -> void:
	var record := _live_record(id, "mark_buried")
	if record == null:
		return
	_decay_record(record, TimeManager.total_minutes())
	if record.location == CorpseRecord.LOCATION_CARRIED:
		_release_from_carrier()
	record.location = CorpseRecord.LOCATION_BURIED
	record.grave_id = grave_id
	record.freshness_at_burial = record.freshness
	record.buried_day = TimeManager.day
	if record.needs_valuables_decision():
		record.valuables_decision = CorpseRecord.DECISION_LEFT
	_free_node(id)
	EventBus.corpse_updated.emit(id)


func unburied_count() -> int:
	var count := 0
	for record: CorpseRecord in _records.values():
		if record.location != CorpseRecord.LOCATION_BURIED:
			count += 1
	return count


func save_state() -> Dictionary:
	return CorpseSaveCodec.write(_records, _next_serial, _last_delivery_day, _last_delivery_ids, _spawn_counts)


## Replaces everything: old nodes are freed, nodes of all non-buried corpses are recreated
## at their saved position (a carried one under the container until post_load).
func load_state(data: Dictionary) -> void:
	if _carried_record() != null:
		_release_from_carrier()
	for id: String in _nodes.keys():
		_free_node(id)
	_records.clear()
	_nodes.clear()
	_spawn_counts.clear()
	CorpseSaveCodec.read_records(data, _records)
	_next_serial = maxi(1, CorpseSaveCodec.to_int(data.get("next_serial"), 1))
	_last_delivery_day = maxi(0, CorpseSaveCodec.to_int(data.get("last_delivery_day"), 0))
	_last_delivery_ids = CorpseSaveCodec.read_delivery_ids(data)
	CorpseSaveCodec.read_spawn_counts(data, _spawn_counts)
	for record: CorpseRecord in _records.values():
		if record.location != CorpseRecord.LOCATION_BURIED:
			_create_node(record)


## Re-attaches a carried corpse to the node in group "player"; without one it lies on the ground.
func post_load() -> void:
	var attached := false
	for record: CorpseRecord in _records.values():
		if record.location != CorpseRecord.LOCATION_CARRIED:
			continue
		var node := _node(record.id)
		if node == null:
			node = _create_node(record)
		var player := _first_in_group(PLAYER_GROUP)
		if not attached and node != null and player != null and player.has_method("attach_carried"):
			attached = true
			_carrier_ref = weakref(player)
			player.call("attach_carried", node, record.id)
		else:
			push_warning("[CorpseManager] carried corpse '%s' has no carrier – put on the ground" % record.id)
			record.location = CorpseRecord.LOCATION_GROUND
			EventBus.corpse_updated.emit(record.id)


# --- time ---

func _on_time_tick(day: int, minute_of_day: int) -> void:
	_check_delivery((day - 1) * MINUTES_PER_DAY + minute_of_day)


func _on_time_skipped(_from_total: int, to_total: int) -> void:
	_apply_decay(to_total)
	_check_delivery(to_total)


func _on_hour_changed(day: int, hour: int) -> void:
	_apply_decay((day - 1) * MINUTES_PER_DAY + hour * MINUTES_PER_HOUR)


func _check_delivery(now_total: int) -> void:
	var day := CorpseDeliveryRules.day_of(now_total)
	if not is_inside_tree() or day <= _last_delivery_day:
		return
	if CorpseDeliveryRules.is_due(now_total, _tables()):
		_deliver(day, now_total)


## Decays every unburied corpse up to `now_total`; corpse_updated only on a stage change
## (stages from the same EconomyConfig as the grave quality).
func _apply_decay(now_total: int) -> void:
	var cfg := _economy()
	for record: CorpseRecord in _records.values():
		if record.location == CorpseRecord.LOCATION_BURIED:
			continue
		var stage := CorpseRecord.stage_for(record.freshness, cfg)
		if _decay_record(record, now_total) and CorpseRecord.stage_for(record.freshness, cfg) != stage:
			EventBus.corpse_updated.emit(record.id)


## Freshness per CorpseDecay.freshness_at. Nothing before last_decay_total (burial stops
## decay: buried corpses are not decayed any more).
func _decay_record(record: CorpseRecord, now_total: int) -> bool:
	if now_total <= record.last_decay_total:
		return false
	record.freshness = CorpseDecay.freshness_at(record, now_total, CorpseDecay.decay_per_hour(record, _tables()))
	record.last_decay_total = now_total
	return true


# --- delivery bookkeeping ---

func _take_spawn_index(day: int) -> int:
	var index: int = _spawn_counts.get(day, 0)
	_spawn_counts[day] = index + 1
	return index


func _new_id() -> String:
	var id := ID_FORMAT % _next_serial
	while _records.has(id):
		_next_serial += 1
		id = ID_FORMAT % _next_serial
	_next_serial += 1
	return id


# --- records & nodes ---

## Record that exists and is not buried (warns otherwise).
func _live_record(id: String, action: String) -> CorpseRecord:
	var record := get_record(id)
	if record == null:
		push_warning("[CorpseManager] %s: unknown corpse '%s'" % [action, id])
		return null
	if record.location == CorpseRecord.LOCATION_BURIED:
		push_warning("[CorpseManager] %s: corpse '%s' is buried" % [action, id])
		return null
	return record


func _carried_record() -> CorpseRecord:
	for record: CorpseRecord in _records.values():
		if record.location == CorpseRecord.LOCATION_CARRIED:
			return record
	return null


func _release_from_carrier() -> void:
	var carrier: Node = _carrier_ref.get_ref() if _carrier_ref != null else null
	if carrier == null:
		carrier = _first_in_group(PLAYER_GROUP)
	if carrier != null and carrier.has_method("detach_carried"):
		carrier.call("detach_carried")
	_carrier_ref = null


func _node(id: String) -> Node3D:
	var node: Variant = _nodes.get(id)
	if not is_instance_valid(node):
		return null
	return node


## Instantiates the corpse scene for `record` under `parent` (default: the container).
func _create_node(record: CorpseRecord, parent: Node = null) -> Node3D:
	if corpse_scene == null:
		corpse_scene = load(DEFAULT_CORPSE_SCENE) as PackedScene
	if corpse_scene == null:
		push_warning("[CorpseManager] corpse scene missing – '%s' has no node" % record.id)
		return null
	var node := CorpseNodePlacement.instantiate(corpse_scene, record)
	if node == null:
		return null
	CorpseNodePlacement.place(node, parent if parent != null else _container(), CorpseNodePlacement.record_transform(record))
	_nodes[record.id] = node
	return node


func _free_node(id: String) -> void:
	var node := _node(id)
	_nodes.erase(id)
	if node != null:
		CorpseNodePlacement.free_node(node)


func _container() -> Node:
	if not container_path.is_empty():
		var container := get_node_or_null(container_path)
		if container != null:
			return container
		push_warning("[CorpseManager] container '%s' not found – using the manager" % container_path)
	return self


func _first_in_group(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _reputation() -> Reputation:
	return _first_in_group(REPUTATION_GROUP) as Reputation


func _reputation_config() -> ReputationConfig:
	if reputation_config == null:
		reputation_config = Database.config(&"reputation_config") as ReputationConfig
		if reputation_config == null:
			reputation_config = ReputationConfig.new()
	return reputation_config


func _tables() -> CorpseTables:
	if tables == null:
		tables = Database.corpse_tables() as CorpseTables
	return tables


func _economy() -> EconomyConfig:
	if economy == null:
		economy = EconomyConfig.resolve()
	return economy

