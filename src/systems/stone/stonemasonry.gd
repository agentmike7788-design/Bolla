class_name Stonemasonry
extends Node
## Systems/Stonemasonry (docs/PHASE5_DESIGN.md §2.5, §3.1, §3.4, §5.1), groups &"stonemasonry",
## &"saveable": carving designed stones for one grave each at the mason's bench, the rack of
## finished stones (WorkshopConfig.ready_slots) and setting them at the grave
## (Graveyard.set_designed_stone). A finished stone is no inventory item: it waits in the rack
## with its text fixed at carving time. Also remembers which ghosts already spoke their by_design
## line (GhostManager, once per grave).
## Saved: {next_id, ready: [{id, grave_id, design}], heard_design: [grave_id]}.

const GROUP := &"stonemasonry"
const GRAVEYARD_GROUP := &"graveyard"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const STAT_CRAFTED := &"crafted"
const STATE_READY := &"ready"
const STATE_SET := &"set"
const STATE_DISCARDED := &"discarded"
const ID_FORMAT := "stone_%04d"

const TEXT_NO_GRAVE := "Hier liegt noch niemand."
const TEXT_NO_SHAPE := "Wähle eine Form."
const TEXT_GOLD_NEEDS_INSCRIPTION := "Vergolden geht nur mit Inschrift."
const TEXT_BETTER := "Der jetzige Stein ist schon besser."
const TEXT_ONE_PER_GRAVE := "Für dieses Grab liegt schon ein Stein bereit."
const TEXT_RACK_FULL := "Die Ablage ist voll – setz erst einen Stein."
const TEXT_MISSING := "Es fehlt: %s"
const NAME_UNKNOWN := "Unbekannt"

@export var save_id: String = "stonemasonry"
@export var save_order: int = 35

## null = Database (data/config/{stone,workshop,economy}_config.tres) – tests inject fixtures.
var config: StoneConfig
var workshop_config: WorkshopConfig
var economy: EconomyConfig
## Inventory whose material preview() compares (null = the player's).
var inventory: Inventory

var _next_id: int = 1
## [{id: String, grave_id: String, design: Dictionary}] in carving order.
var _ready: Array[Dictionary] = []
## Graves whose ghost already spoke its by_design line.
var _heard_design: Dictionary[String, bool] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## [{grave_id, name, section, marker, quality, ready: bool}] – FILLED / MARKED graves with a
## known corpse, in plot order.
func eligible_graves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var graveyard := _graveyard()
	if graveyard == null:
		return out
	for grave: GraveRecord in graveyard.graves():
		if not _holds_corpse(grave):
			continue
		var corpse := _corpse(grave.corpse_id)
		if corpse == null:
			continue
		out.append({"grave_id": grave.id, "name": corpse.display_name if corpse.display_name != "" else NAME_UNKNOWN,
				"section": graveyard.section_of(grave.id), "marker": grave.marker_id, "quality": _quality_now(grave, corpse),
				"ready": not ready_for(grave.id).is_empty()})
	return out


## {quality_before, quality_after, lines, text, fits, minutes, inputs, missing, block_reason}
## ({} for an unknown grave). `missing` / `block_reason` against `inventory` (or the player's).
func preview(grave_id: String, design: StoneDesign) -> Dictionary:
	var grave := _grave(grave_id)
	var corpse := _corpse(grave.corpse_id) if grave != null else null
	if grave == null or corpse == null or design == null:
		return {}
	var d := _with_text(design, corpse)
	var stored := d.to_dict()
	var eco := _economy()
	var ins := Database.inscription(d.inscription) as InscriptionData if d.inscription != &"" else null
	var inv := inventory if inventory != null else _player_inventory()
	var needed := StoneDesignRules.inputs(d, _config())
	return {
		"quality_before": _quality_now(grave, corpse),
		"quality_after": GraveQuality.compute(corpse, d.shape, eco, stored) if not d.is_empty() else _quality_now(grave, corpse),
		"lines": GraveQuality.breakdown(corpse, d.shape, eco, stored) if not d.is_empty() else [],
		"text": d.text,
		"fits": StoneDesignRules.fits(ins, corpse),
		"minutes": StoneDesignRules.minutes(d, _config()),
		"inputs": needed,
		"missing": _missing(needed, inv),
		"block_reason": order_block_reason(grave_id, design, inv),
	}


## "" = can be carved. Order: grave · shape · gilding · better than now · one per grave · rack ·
## material ("Es fehlt: 2 Stein, 1 Holundertinte").
func order_block_reason(grave_id: String, design: StoneDesign, inv: Inventory) -> String:
	var grave := _grave(grave_id)
	var corpse := _corpse(grave.corpse_id) if grave != null and _holds_corpse(grave) else null
	if corpse == null:
		return TEXT_NO_GRAVE
	if design == null or design.is_empty() or Database.stone_shape(design.shape) == null \
			or not _economy().marker_quality.has(design.shape):
		return TEXT_NO_SHAPE
	if design.gilded and design.inscription == &"":
		return TEXT_GOLD_NEEDS_INSCRIPTION
	if not _is_better(grave, corpse, design):
		return TEXT_BETTER
	if not ready_for(grave_id).is_empty():
		return TEXT_ONE_PER_GRAVE
	if _ready.size() >= _workshop_config().ready_slots:
		return TEXT_RACK_FULL
	var missing := _missing(StoneDesignRules.inputs(design, _config()), inv)
	if not missing.is_empty():
		return TEXT_MISSING % _missing_text(missing)
	return ""


## After the timed action; takes the material atomically (all or nothing), fixes the text
## (StoneDesignRules.render_text). order_id | ""; stone_order_changed(&"ready"); stats.crafted.
func carve(grave_id: String, design: StoneDesign, inv: Inventory) -> String:
	if inv == null or order_block_reason(grave_id, design, inv) != "":
		return ""
	var needed := StoneDesignRules.inputs(design, _config())
	for id: Variant in needed:
		if not inv.remove_item(StringName(str(id)), int(needed[id])):
			push_error("[Stonemasonry] carve: material vanished while taking it ('%s')" % id)
			return ""
	var grave := _grave(grave_id)
	var d := _with_text(design, _corpse(grave.corpse_id))
	var order_id := ID_FORMAT % _next_id
	_next_id += 1
	_ready.append({"id": order_id, "grave_id": grave_id, "design": d.to_dict()})
	GameState.add_stat(STAT_CRAFTED, 1)
	EventBus.stone_order_changed.emit(order_id, grave_id, STATE_READY)
	return order_id


## [{id, grave_id, design (dict), name, shape, fits_still: bool}] – fits_still false = "passt nicht
## mehr" (the grave meanwhile has an equal or better marker; discard only by hand).
func ready_stones() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for order: Dictionary in _ready:
		out.append(_describe(order))
	return out


func ready_for(grave_id: String) -> Dictionary:
	for order: Dictionary in _ready:
		if order.grave_id == grave_id:
			return _describe(order)
	return {}


## Throws the stone away (material lost); stone_order_changed(&"discarded").
func discard(order_id: String) -> bool:
	for i: int in _ready.size():
		if _ready[i].id == order_id:
			var grave_id: String = _ready[i].grave_id
			_ready.remove_at(i)
			EventBus.stone_order_changed.emit(order_id, grave_id, STATE_DISCARDED)
			return true
	return false


## From GravePlot after StoneConfig.set_minutes → Graveyard.set_designed_stone (payment into
## `inv` for a FILLED grave); the stone leaves the rack; stone_order_changed(&"set"). A new stone
## lets the ghost speak its by_design line again. Quality difference (0 = refused / nothing set).
func set_stone(grave_id: String, inv: Inventory) -> int:
	var order := ready_for(grave_id)
	var graveyard := _graveyard()
	if order.is_empty() or graveyard == null:
		return 0
	var design := StoneDesign.from_dict(order.design)
	var diff := graveyard.set_designed_stone(grave_id, design, inv)
	var grave := graveyard.get_grave(grave_id)
	if grave == null or grave.design != design.to_dict():
		return 0
	for i: int in _ready.size():
		if _ready[i].id == order.id:
			_ready.remove_at(i)
			break
	_heard_design.erase(grave_id)
	EventBus.stone_order_changed.emit(String(order.id), grave_id, STATE_SET)
	return diff


# --- ghosts (GhostManager, §2.5 by_design) ------------------------------------------------

## The grave has a designed stone whose by_design line was not spoken yet.
func design_line_pending(grave_id: String) -> bool:
	var grave := _grave(grave_id)
	return grave != null and not grave.design.is_empty() and not _heard_design.has(grave_id)


func mark_design_heard(grave_id: String) -> void:
	_heard_design[grave_id] = true


func save_state() -> Dictionary:
	var ready: Array = []
	for order: Dictionary in _ready:
		ready.append({"id": order.id, "grave_id": order.grave_id, "design": (order.design as Dictionary).duplicate(true)})
	var heard: Array = []
	for id: String in _heard_design:
		heard.append(id)
	heard.sort()
	return {"next_id": _next_id, "ready": ready, "heard_design": heard}


## Tolerant: bad entries are skipped; next_id never below the highest saved order number + 1.
func load_state(data: Dictionary) -> void:
	_ready.clear()
	_heard_design.clear()
	_next_id = 1
	if data == null:
		return
	var raw_next: Variant = data.get("next_id", 1)
	if raw_next is int or raw_next is float:
		_next_id = maxi(1, roundi(float(raw_next)))
	var list: Variant = data.get("ready", [])
	if list is Array:
		for entry: Variant in list:
			if not entry is Dictionary:
				continue
			var e: Dictionary = entry
			var id := str(e.get("id", ""))
			var grave_id := str(e.get("grave_id", ""))
			var raw_design: Variant = e.get("design", {})
			var design := StoneDesign.from_dict(raw_design if raw_design is Dictionary else {})
			if id == "" or grave_id == "" or design.is_empty() or not ready_for(grave_id).is_empty():
				push_warning("[Stonemasonry] invalid ready stone skipped: %s" % str(entry))
				continue
			_ready.append({"id": id, "grave_id": grave_id, "design": design.to_dict()})
			if id.begins_with("stone_") and id.trim_prefix("stone_").is_valid_int():
				_next_id = maxi(_next_id, id.trim_prefix("stone_").to_int() + 1)
	var heard: Variant = data.get("heard_design", [])
	if heard is Array:
		for id: Variant in heard:
			if id is String or id is StringName:
				_heard_design[String(id)] = true


# --- helpers --------------------------------------------------------------------------------

func _describe(order: Dictionary) -> Dictionary:
	var design := StoneDesign.from_dict(order.design)
	var grave := _grave(order.grave_id)
	var corpse := _corpse(grave.corpse_id) if grave != null else null
	var fits_still := grave != null and corpse != null and _holds_corpse(grave) and _is_better(grave, corpse, design)
	var name := corpse.display_name if corpse != null and corpse.display_name != "" else NAME_UNKNOWN
	return {"id": order.id, "grave_id": order.grave_id, "design": (order.design as Dictionary).duplicate(true),
			"name": name, "shape": design.shape, "fits_still": fits_still}


## A copy of `design` with the text of `corpse` fixed (empty without inscription).
func _with_text(design: StoneDesign, corpse: CorpseRecord) -> StoneDesign:
	var d := StoneDesign.new()
	d.shape = design.shape
	d.inscription = design.inscription
	d.ornament = design.ornament
	d.gilded = design.gilded and design.inscription != &""
	var ins := Database.inscription(design.inscription) as InscriptionData if design.inscription != &"" else null
	d.text = StoneDesignRules.render_text(ins, corpse, _config()) if ins != null else PackedStringArray()
	return d


func _is_better(grave: GraveRecord, corpse: CorpseRecord, design: StoneDesign) -> bool:
	return StoneDesignRules.marker_points(design, corpse, _economy(), _config()) \
			> StoneDesignRules.current_marker_points(grave, corpse, _economy(), _config())


## Quality shown for the grave now (FILLED: what it would be without a marker).
func _quality_now(grave: GraveRecord, corpse: CorpseRecord) -> int:
	if grave.state == GraveRecord.State.MARKED:
		return grave.quality
	return GraveQuality.compute(corpse, &"", _economy())


func _holds_corpse(grave: GraveRecord) -> bool:
	return (grave.state == GraveRecord.State.FILLED or grave.state == GraveRecord.State.MARKED) and grave.corpse_id != ""


## {item_id: missing amount}; without inventory everything is missing.
func _missing(needed: Dictionary, inv: Inventory) -> Dictionary:
	var out := {}
	for id: Variant in needed:
		var have := inv.count(StringName(str(id))) if inv != null else 0
		if have < int(needed[id]):
			out[id] = int(needed[id]) - have
	return out


func _missing_text(missing: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: Variant in missing:
		var name := String(id)
		var item_id := StringName(str(id))
		if Database.has_item(item_id):
			var item := Database.item(item_id) as ItemData
			if item != null and item.display_name != "":
				name = item.display_name
		parts.append("%d %s" % [int(missing[id]), name])
	return ", ".join(parts)


func _grave(grave_id: String) -> GraveRecord:
	var graveyard := _graveyard()
	return graveyard.get_grave(grave_id) if graveyard != null else null


func _corpse(corpse_id: String) -> CorpseRecord:
	if not is_inside_tree() or corpse_id == "":
		return null
	var manager := get_tree().get_first_node_in_group(CORPSE_MANAGER_GROUP) as CorpseManager
	return manager.get_record(corpse_id) if manager != null else null


func _graveyard() -> Graveyard:
	return get_tree().get_first_node_in_group(GRAVEYARD_GROUP) as Graveyard if is_inside_tree() else null


func _player_inventory() -> Inventory:
	if not is_inside_tree():
		return null
	var player := get_tree().get_first_node_in_group(&"player")
	return player.get(&"inventory") as Inventory if player != null else null


func _config() -> StoneConfig:
	if config == null:
		config = Database.config(&"stone_config") as StoneConfig
		if config == null:
			config = StoneConfig.new()
	return config


func _workshop_config() -> WorkshopConfig:
	if workshop_config == null:
		workshop_config = Database.config(&"workshop_config") as WorkshopConfig
		if workshop_config == null:
			workshop_config = WorkshopConfig.new()
	return workshop_config


## The Graveyard's EconomyConfig when it has one (tests inject fixtures), else the data file.
func _economy() -> EconomyConfig:
	if economy != null:
		return economy
	var graveyard := _graveyard()
	if graveyard != null and graveyard.economy != null:
		return graveyard.economy
	return EconomyConfig.resolve()
