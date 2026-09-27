class_name CorpseManager
extends Node
## Owns all CorpseRecords and their nodes (WorldRoot/Systems/CorpseManager).
## Groups corpse_manager + saveable. Delivers the daily corpse (docs §2.5) on time_tick /
## time_skipped – a corpse delivered inside a skip arrived at the delivery minute – and applies
## decay on hour_changed / time_skipped as a function of the minutes since arrival.
## _ready only wires signals and data – corpses appear via delivery, spawn_corpse or load_state.

const GROUP := &"corpse_manager"
const SAVEABLE_GROUP := &"saveable"
const PLAYER_GROUP := &"player"
const DROPOFF_GROUP := &"dropoff"
const GRAVEYARD_GROUP := &"graveyard"
const DEFAULT_CORPSE_SCENE := "res://src/entities/corpse/corpse.tscn"
const ID_FORMAT := "corpse_%04d"
const SHROUD_ITEM := &"shroud"
const COIN_ITEM := &"coin"
const FLAG_SLICE_COMPLETE := &"slice_complete"
const FLAG_DELIVERY_SKIPPED := &"delivery_skipped"
const STAT_MISSED := &"missed_deliveries"
const STAT_VALUABLES_TAKEN := &"valuables_taken"
const STAT_REPUTATION := &"reputation"
## Locations a corpse can be spawned at or put down to.
const PLACE_LOCATIONS: Array[StringName] = [CorpseRecord.LOCATION_DROPOFF, CorpseRecord.LOCATION_TABLE, CorpseRecord.LOCATION_GROUND]
const MINUTES_PER_HOUR := 60
const MINUTES_PER_DAY := 1440
## Freshness at arrival (CorpseGenerator sets it); decay is measured from arrival_total_minutes.
const START_FRESHNESS := 1.0
## Freshness is kept on a grid of 1 / FRESHNESS_RESOLUTION: exact threshold times land exactly
## on the threshold, and the 14-digit floats of JSON.from_native save it bit-exactly.
const FRESHNESS_RESOLUTION := 1000000.0

const REASON_OCCUPIED := "Die Bahre ist noch belegt."
const REASON_NO_PLOT := "Es gibt keine freie Grabstelle."
const REASON_NO_DROPOFF := "Es gibt keine Bahre für die Lieferung."
const NOTE_SKIPPED := "Heute keine Leiche: %s"

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

## id -> record, in spawn order.
var _records: Dictionary[String, CorpseRecord] = {}
## id -> corpse node (only for corpses that are not buried).
var _nodes: Dictionary[String, Node3D] = {}
var _next_serial: int = 1
## Last day a delivery was attempted (0 = never) and the corpse it brought ("" = skipped).
var _last_delivery_day: int = 0
var _last_delivery_id: String = ""
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


## Docs §2.5: once per day; needs a free dropoff and more free plots than unburied corpses,
## never after slice_complete. Repeated calls for the same day return that day's corpse.
## Returns null when skipped.
func try_daily_delivery(day: int) -> CorpseRecord:
	return _deliver(day, TimeManager.total_minutes())


## try_daily_delivery checked at world time `now_total` (the time of the triggering signal).
## The corpse arrived at the day's delivery minute – also when the check runs later, inside a
## skip (rest, timed action) – but never after now, and has decayed since then.
## Without any EMPTY/DUG plot the cemetery is full for good (graves are never emptied again):
## the carter brings nothing more, which is no missed delivery.
func _deliver(day: int, now_total: int) -> CorpseRecord:
	if day <= _last_delivery_day:
		return get_record(_last_delivery_id) if day == _last_delivery_day else null
	_last_delivery_day = day
	_last_delivery_id = ""
	if GameState.has_flag(FLAG_SLICE_COMPLETE):
		return null
	var t := _tables()
	if t == null:
		push_warning("[CorpseManager] delivery on day %d without corpse tables" % day)
		return null
	if _cemetery_full():
		return null
	var dropoff := _first_in_group(DROPOFF_GROUP)
	var reason := ""
	if dropoff == null or not dropoff.has_method("is_free"):
		push_warning("[CorpseManager] no dropoff node in group '%s'" % DROPOFF_GROUP)
		reason = REASON_NO_DROPOFF
	elif not bool(dropoff.call("is_free")):
		reason = REASON_OCCUPIED
	elif _free_plot_count() <= unburied_count():
		reason = REASON_NO_PLOT
	if reason != "":
		_skip_delivery(day, reason)
		return null
	var at: Transform3D = dropoff.call("slot_transform") if dropoff.has_method("slot_transform") else Transform3D.IDENTITY
	var record := CorpseGenerator.generate(CorpseGenerator.seed_for(day, _take_spawn_index(day)), t, day)
	var arrival := mini(now_total, (day - 1) * MINUTES_PER_DAY + t.delivery_minute)
	record = _spawn(record, at, CorpseRecord.LOCATION_DROPOFF, arrival, now_total)
	if record != null:
		_last_delivery_id = record.id
	return record


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
	_store_transform(record, at)
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
	_place(node, target, xform)
	record.location = location
	_store_transform(record, xform)
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
	var corpses: Array = []
	for record: CorpseRecord in _records.values():
		corpses.append(record.to_dict())
	var counts := {}
	for day: int in _spawn_counts:
		counts[day] = _spawn_counts[day]
	return {
		"corpses": corpses,
		"next_serial": _next_serial,
		"last_delivery_day": _last_delivery_day,
		"last_delivery_id": _last_delivery_id,
		"spawn_counts": counts,
	}


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
	var corpses: Variant = data.get("corpses", [])
	if corpses is Array:
		for entry: Variant in corpses:
			if not entry is Dictionary:
				continue
			var record := CorpseRecord.from_dict(entry as Dictionary)
			if record.id == "" or _records.has(record.id):
				push_warning("[CorpseManager] saved corpse without unique id skipped")
				continue
			_records[record.id] = record
	_next_serial = maxi(1, _int(data.get("next_serial"), 1))
	_last_delivery_day = maxi(0, _int(data.get("last_delivery_day"), 0))
	var last_id: Variant = data.get("last_delivery_id", "")
	_last_delivery_id = String(last_id) if last_id is String or last_id is StringName else ""
	var counts: Variant = data.get("spawn_counts", {})
	if counts is Dictionary:
		for key: Variant in counts:
			var day := _int(key, -1)
			var count := _int((counts as Dictionary)[key], 0)
			if day >= 0 and count > 0:
				_spawn_counts[day] = count
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
	var day := _div(now_total, MINUTES_PER_DAY) + 1
	if not is_inside_tree() or day <= _last_delivery_day:
		return
	var t := _tables()
	if t != null and now_total % MINUTES_PER_DAY >= t.delivery_minute:
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


## Docs §2.5: freshness = START_FRESHNESS - base_decay_per_hour * decay_mult * hours since
## arrival (min 0), in one expression from the total-minute difference – no float error adds
## up over the hourly steps – snapped to the FRESHNESS_RESOLUTION grid. Nothing before
## last_decay_total (burial stops decay: buried corpses are not decayed any more).
func _decay_record(record: CorpseRecord, now_total: int) -> bool:
	if now_total <= record.last_decay_total:
		return false
	var minutes := maxi(0, now_total - record.arrival_total_minutes)
	var value := maxf(0.0, START_FRESHNESS - _decay_per_hour(record) * minutes / float(MINUTES_PER_HOUR))
	record.freshness = roundf(value * FRESHNESS_RESOLUTION) / FRESHNESS_RESOLUTION
	record.last_decay_total = now_total
	return true


func _decay_per_hour(record: CorpseRecord) -> float:
	var t := _tables()
	if t == null:
		return 0.0
	return t.base_decay_per_hour * float(t.get_cause(record.cause_id).get("decay_mult", 1.0))


# --- delivery helpers ---

func _skip_delivery(day: int, reason: String) -> void:
	GameState.add_stat(STAT_MISSED, 1)
	GameState.set_flag(FLAG_DELIVERY_SKIPPED, day)
	EventBus.delivery_skipped.emit(day, reason)
	EventBus.notification_requested.emit(NOTE_SKIPPED % reason, &"warning")


func _free_plot_count() -> int:
	var graveyard := _first_in_group(GRAVEYARD_GROUP)
	if graveyard == null or not graveyard.has_method("free_plot_count"):
		return 0
	return int(graveyard.call("free_plot_count"))


## A graveyard exists and has no EMPTY/DUG plot left – and never gets one back.
func _cemetery_full() -> bool:
	var graveyard := _first_in_group(GRAVEYARD_GROUP)
	return graveyard != null and graveyard.has_method("free_plot_count") and int(graveyard.call("free_plot_count")) <= 0


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
	var instance := corpse_scene.instantiate()
	var node := instance as Node3D
	if node == null:
		push_warning("[CorpseManager] corpse scene root is no Node3D")
		instance.free()
		return null
	node.name = record.id
	node.set("corpse_id", record.id)
	_place(node, parent if parent != null else _container(), _record_transform(record))
	_nodes[record.id] = node
	return node


## Moves `node` under `target` so that it ends up at the world transform `xform`.
func _place(node: Node3D, target: Node, xform: Transform3D) -> void:
	var local := xform
	var target_3d := target as Node3D
	if target_3d != null and target_3d.is_inside_tree():
		local = target_3d.global_transform.affine_inverse() * xform
	var current := node.get_parent()
	if current != null and current != target:
		current.remove_child(node)
	node.transform = local
	if node.get_parent() == null:
		target.add_child(node)


func _free_node(id: String) -> void:
	var node := _node(id)
	_nodes.erase(id)
	if node == null:
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()


func _container() -> Node:
	if not container_path.is_empty():
		var container := get_node_or_null(container_path)
		if container != null:
			return container
		push_warning("[CorpseManager] container '%s' not found – using the manager" % container_path)
	return self


func _first_in_group(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _tables() -> CorpseTables:
	if tables == null:
		tables = Database.corpse_tables() as CorpseTables
	return tables


func _economy() -> EconomyConfig:
	if economy == null:
		economy = EconomyConfig.resolve()
	return economy


static func _record_transform(record: CorpseRecord) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, record.rot_y), record.position)


static func _store_transform(record: CorpseRecord, xform: Transform3D) -> void:
	record.position = xform.origin
	record.rot_y = xform.basis.orthonormalized().get_euler().y


## int from int / float / numeric String (plain JSON values), else fallback.
static func _int(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float:
		return roundi(v)
	if v is String and (v as String).is_valid_float():
		return roundi((v as String).to_float())
	return fallback


@warning_ignore("integer_division")
static func _div(a: int, b: int) -> int:
	return a / b
