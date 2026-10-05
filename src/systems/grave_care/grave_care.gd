class_name GraveCare
extends Node
## STUB (P2) – Systems/GraveCare (docs/PHASE8_DESIGN.md §2.3, §3.1, §3.3, §3.4, §4.9, §5.1), groups
## &"grave_care", &"saveable": grave flowers (planted / watered / wreath), the visitors' bouquets, grave
## candles (15:00–07:00, the pool of 6 omni lights), mortsafes, the disturbed grave, the watering cans of
## the player and the apprentice. Separate from decor and quality (changes neither). care_bonus ≤ 2 for
## GhostMood.
## W0: flowers_state / candle_lit / has_mortsafe / is_disturbed / can_fill answer from load_state (§5.1
## {"flowers": {grave: {planted, watered, wreath}}, "candles": {grave: lit_total}, "mortsafes", "disturbed",
## "can_fill"}; flowers fresh / wilted by the clock and GraveCareConfig); everything else is inert.
## W1 (P2) fills the bodies; the signatures are the contract.

const GROUP := &"grave_care"
const FLOWERS_FRESH := &"fresh"
const FLOWERS_WILTED := &"wilted"
const FLOWERS_WREATH := &"wreath"
const OWNER_PLAYER := &"player"
const OWNER_APPRENTICE := &"apprentice"

@export var save_id: String = "grave_care"
@export var save_order: int = 72

## Rules; null = data/config/grave_care_config.tres (resolved lazily).
var config: GraveCareConfig

## W0 stub store (P2 may rename it – the fixtures use load_state only).
var _flowers: Dictionary = {}
var _candles: Dictionary = {}
var _mortsafes: Dictionary = {}
var _disturbed: PackedStringArray = []
var _can_fill: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## &"" | &"fresh" | &"wilted" | &"wreath".
func flowers_state(grave_id: String) -> StringName:
	var f: Variant = _flowers.get(grave_id)
	if not f is Dictionary:
		return &""
	if bool((f as Dictionary).get("wreath", false)):
		return FLOWERS_WREATH
	var cfg := _cfg()
	var since := TimeManager.total_minutes() - int((f as Dictionary).get("watered", (f as Dictionary).get("planted", 0)))
	if since < cfg.flower_fresh_minutes:
		return FLOWERS_FRESH
	if since < cfg.flower_wilt_minutes:
		return FLOWERS_WILTED
	return &""


func plant_block_reason(_grave_id: String, _inv: Inventory) -> String:
	return "-"


func plant(_grave_id: String, _inv: Inventory) -> bool:
	return false


func water(_grave_id: String, _by_apprentice := false) -> bool:
	return false


func can_fill(owner: StringName = &"player") -> int:
	return int(_can_fill.get(String(owner), _can_fill.get(owner, 0)))


## The rain barrel (2 minutes): the can full again.
func refill(_owner: StringName = &"player") -> void:
	pass


## The visitor's bouquet (2 days; no stacking with grave flowers).
func place_bouquet(_grave_id: String) -> void:
	pass


func candle_lit(grave_id: String) -> bool:
	return _candles.has(grave_id)


## Apprentice passes his box.
func light(_grave_id: String, _inv: Inventory) -> bool:
	return false


func lit_last_night(_grave_id: String) -> bool:
	return false


func has_mortsafe(grave_id: String) -> bool:
	return _mortsafes.has(grave_id)


func set_mortsafe(_grave_id: String, _on: bool, _inv: Inventory) -> bool:
	return false


func is_disturbed(grave_id: String) -> bool:
	return _disturbed.has(grave_id)


## NightRobber at 05:00 (GraveRecord.disturbed, care spot level 3).
func set_disturbed(_grave_id: String) -> void:
	pass


func close_disturbed(_grave_id: String) -> bool:
	return false


## ≤ care_cap; GhostMood reads it.
func care_bonus(_grave_id: String) -> int:
	return 0


## {flowers, bouquets, candles, lit_nights, mortsafes, disturbed, can_fill, light_pool} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	var f: Variant = data.get("flowers", {})
	_flowers = (f as Dictionary).duplicate(true) if f is Dictionary else {}
	var c: Variant = data.get("candles", {})
	_candles = (c as Dictionary).duplicate(true) if c is Dictionary else {}
	var m: Variant = data.get("mortsafes", {})
	_mortsafes = (m as Dictionary).duplicate(true) if m is Dictionary else {}
	_disturbed = PackedStringArray()
	var d: Variant = data.get("disturbed", [])
	if d is Array or d is PackedStringArray:
		for id: Variant in d:
			_disturbed.append(str(id))
	var fill: Variant = data.get("can_fill", {})
	_can_fill = (fill as Dictionary).duplicate(true) if fill is Dictionary else {}


func _cfg() -> GraveCareConfig:
	if config == null:
		config = Database.config(&"grave_care_config") as GraveCareConfig
	if config == null:
		config = GraveCareConfig.new()
	return config
