class_name GraveCare
extends Node
## Systems/GraveCare (docs/PHASE8_DESIGN.md §2.3, §3.1, §3.3, §3.4, §4.9, §5.1), groups &"grave_care",
## &"saveable", save_id grave_care / 72: grave flowers (planted / watered / wax wreath), the visitors'
## bouquets, grave candles (15:00–07:00, the pool of 6 omni lights near the camera focus), mortsafes, the
## disturbed grave, the watering cans of the player and the apprentice. Separate from decor and quality
## (changes neither). care_bonus ≤ care_cap (+ disturbed_mood) for GhostMood.
## Everything is derived from the clock (flowers wilt, candles go out at 07:00): a load never refreshes
## anything. grave_care_changed(grave_id, kind, active) for flowers / bouquet / candle / mortsafe / disturbed
## when a state appears or ends (also when it ends by the clock). Callers run the timed action first
## (GravePlot, RainBarrel, Apprentice) – these methods apply the effect at once.

const GROUP := &"grave_care"
const FLOWERS_FRESH := &"fresh"
const FLOWERS_WILTED := &"wilted"
const FLOWERS_WREATH := &"wreath"
const OWNER_PLAYER := &"player"
const OWNER_APPRENTICE := &"apprentice"
const KIND_FLOWERS := &"flowers"
const KIND_BOUQUET := &"bouquet"
const KIND_CANDLE := &"candle"
const KIND_MORTSAFE := &"mortsafe"
const KIND_DISTURBED := &"disturbed"
const GRAVEYARD_GROUP := &"graveyard"
const CLEANLINESS_GROUP := &"cleanliness"
const PLOT_GROUP := &"grave_plot"
const PLAYER_GROUP := &"player"
const DIRT_PREFIX := "dirt_"
## GameState flag (int day) of the night of the lights (FestivalData fest_lights.day_flag, P4).
const LIGHTS_DAY_FLAG := &"fest_lights_day"
const STAT_FLOWERS := &"flowers_planted"
const STAT_CANDLES := &"candles_lit"
const STAT_MORTSAFES := &"mortsafes_set"
const STAT_DISTURBED := &"graves_disturbed"
const STAT_CLOSED := &"graves_closed"
## The care spot of a disturbed grave (§2.3 "Pflegestelle Stufe 3").
const DISTURBED_LEVEL := 3
## §4.9: pool of omni lights for the burning candles nearest the camera focus (2 Hz), no shadows.
const LIGHT_POOL_SIZE := 6
const LIGHT_COLOR := Color("#F2A93B")
const LIGHT_ENERGY := 0.5
const LIGHT_RANGE := 2.2
const LIGHT_INTERVAL := 0.5
## Candle glass next to the marker at the head end, plot-local (GravePlotVisuals uses the same spot).
const CANDLE_OFFSET := Vector3(0.38, 0.0, -0.72)
const LIGHT_HEIGHT := 0.3

const TEXT_NOT_HERE := "Hier kann nichts gepflanzt werden."
const TEXT_HAS_FLOWERS := "Hier blühen schon Blumen."
const TEXT_DISTURBED := "Erst das Grab wieder schließen."
const TEXT_NO_SEEDLINGS := "Du hast keine Grabblumen."
const TEXT_NO_FLOWERS := "Hier sind keine Blumen zu gießen."
const TEXT_CAN_EMPTY := "Die Gießkanne ist leer."
const TEXT_NO_CAN := "Du hast keine Gießkanne."
const TEXT_TOO_EARLY := "Erst am Nachmittag."
const TEXT_CANDLE_BURNS := "Die Kerze brennt schon."
const TEXT_NO_CANDLE := "Du hast keine Grabkerze."
const TEXT_HAS_MORTSAFE := "Das Gitter liegt schon."
const TEXT_NO_MORTSAFE := "Du hast kein Grabgitter."
const TEXT_MORTSAFE_DAYS := "Die Erde muss sich noch setzen (noch %d Tage)."
const TEXT_NOT_DISTURBED := "Das Grab ist nicht aufgewühlt."

@export var save_id: String = "grave_care"
@export var save_order: int = 72

## Rules; null = data/config/grave_care_config.tres (resolved lazily).
var config: GraveCareConfig

## grave → {planted, watered, wreath} (total minutes).
var _flowers: Dictionary = {}
## grave → total minute the visitor laid the bouquet.
var _bouquets: Dictionary = {}
## grave → total minute the candle was lit (burns until the next 07:00).
var _candles: Dictionary = {}
## grave → the latest night a candle burned on it (GraveCareRules.night_of).
var _lit_nights: Dictionary = {}
## grave → total minute the mortsafe was set.
var _mortsafes: Dictionary = {}
var _disturbed: PackedStringArray = []
## owner (player / apprentice) → fillings left in the can.
var _can_fill: Dictionary = {}
## The total minute of the next clock-driven change (flowers gone, candle out, bouquet gone).
var _next_change: int = -1
var _lights: Array[OmniLight3D] = []
var _light_left: float = 0.0
var _plots: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.time_skipped.connect(_on_time_skipped)
	EventBus.world_ready.connect(_on_world_ready)


# --- flowers -------------------------------------------------------------------------------------

## &"" | &"fresh" | &"wilted" | &"wreath".
func flowers_state(grave_id: String) -> StringName:
	var f: Variant = _flowers.get(grave_id)
	if not f is Dictionary:
		return &""
	return GraveCareRules.flowers_state(f as Dictionary, TimeManager.total_minutes(), _cfg())


## Minutes until the flowers of `grave_id` wilt (0 = wilted / none / a wreath) – the grave tooltip.
func fresh_minutes_left(grave_id: String) -> int:
	var f: Variant = _flowers.get(grave_id)
	if not f is Dictionary or flowers_state(grave_id) != FLOWERS_FRESH:
		return 0
	return maxi(0, GraveCareRules.last_watered(f as Dictionary) + _cfg().flower_fresh_minutes - TimeManager.total_minutes())


## "" or why no grave flowers can be planted here (FILLED / MARKED, no flowers yet, not disturbed, a
## seedling in `inv`).
func plant_block_reason(grave_id: String, inv: Inventory) -> String:
	var base := _place_block_reason(grave_id)
	if base != "":
		return base
	if inv == null or not inv.has(_cfg().flower_item):
		return TEXT_NO_SEEDLINGS
	return ""


## 1 flower_seedlings → fresh grave flowers (planting counts as watering); stats.flowers_planted.
func plant(grave_id: String, inv: Inventory) -> bool:
	if plant_block_reason(grave_id, inv) != "":
		return false
	if not inv.remove_item(_cfg().flower_item, 1):
		return false
	var now := TimeManager.total_minutes()
	_flowers[grave_id] = {"planted": now, "watered": now, "wreath": false}
	GameState.add_stat(STAT_FLOWERS, 1)
	_changed(grave_id, KIND_FLOWERS, true)
	return true


## "" or why no wax wreath can be laid here (like plant_block_reason, a wax_wreath in `inv`).
func wreath_block_reason(grave_id: String, inv: Inventory) -> String:
	var base := _place_block_reason(grave_id)
	if base != "":
		return base
	if inv == null or not inv.has(_cfg().wreath_item):
		return TEXT_NO_SEEDLINGS
	return ""


## §2.6.2: 1 wax_wreath → counts as flowers for wishes, never wilts, ghost +0.
func lay_wreath(grave_id: String, inv: Inventory) -> bool:
	if wreath_block_reason(grave_id, inv) != "":
		return false
	if not inv.remove_item(_cfg().wreath_item, 1):
		return false
	var now := TimeManager.total_minutes()
	_flowers[grave_id] = {"planted": now, "watered": now, "wreath": true}
	_changed(grave_id, KIND_FLOWERS, true)
	return true


## "" or why `owner` cannot water `grave_id` (grave flowers that are still there, a filling left).
func water_block_reason(grave_id: String, owner: StringName = OWNER_PLAYER) -> String:
	var state := flowers_state(grave_id)
	if state == &"" or state == FLOWERS_WREATH:
		return TEXT_NO_FLOWERS
	if can_fill(owner) <= 0:
		return TEXT_CAN_EMPTY
	return ""


## One filling of the can (player's or the apprentice's) → the flowers fresh again.
func water(grave_id: String, by_apprentice := false) -> bool:
	var owner := OWNER_APPRENTICE if by_apprentice else OWNER_PLAYER
	if water_block_reason(grave_id, owner) != "":
		return false
	_can_fill[String(owner)] = can_fill(owner) - 1
	var entry: Dictionary = _flowers[grave_id]
	var was_wilted := flowers_state(grave_id) == FLOWERS_WILTED
	entry["watered"] = TimeManager.total_minutes()
	_flowers[grave_id] = entry
	_schedule_next()
	if was_wilted:
		_changed(grave_id, KIND_FLOWERS, true)
	return true


## §2.5.2 the apprentice treads into the bed: the flowers wilted at once (they wither on as usual).
func wilt_now(grave_id: String) -> void:
	var f: Variant = _flowers.get(grave_id)
	if not f is Dictionary or bool((f as Dictionary).get("wreath", false)):
		return
	var entry: Dictionary = f
	entry["watered"] = mini(GraveCareRules.last_watered(entry), TimeManager.total_minutes() - _cfg().flower_fresh_minutes)
	_flowers[grave_id] = entry
	_schedule_next()
	_changed(grave_id, KIND_FLOWERS, true)


## §2.5.2 weeding pulls the grave flowers out with the weeds.
func remove_flowers(grave_id: String) -> void:
	if _flowers.erase(grave_id):
		_changed(grave_id, KIND_FLOWERS, false)


func can_fill(owner: StringName = &"player") -> int:
	return maxi(0, int(_can_fill.get(String(owner), 0)))


## The rain barrel (2 minutes): the can full again.
func refill(owner: StringName = &"player") -> void:
	_can_fill[String(owner)] = _cfg().can_fills


## The visitor's bouquet (2 days; no stacking with grave flowers – a new one replaces the old).
func place_bouquet(grave_id: String) -> void:
	if grave_id == "":
		return
	_bouquets[grave_id] = TimeManager.total_minutes()
	_schedule_next()
	_changed(grave_id, KIND_BOUQUET, true)


func bouquet_fresh(grave_id: String) -> bool:
	return _bouquets.has(grave_id) and GraveCareRules.bouquet_fresh(int(_bouquets[grave_id]), TimeManager.total_minutes(), _cfg())


# --- candles -------------------------------------------------------------------------------------

func candle_lit(grave_id: String) -> bool:
	return candle_lit_at(grave_id, TimeManager.total_minutes())


## A candle burned on `grave_id` at total minute `total` (the robber decides at 00:00 and comes at 01:30 – also
## after a time skip).
func candle_lit_at(grave_id: String, total: int) -> bool:
	return _candles.has(grave_id) and GraveCareRules.candle_burning(int(_candles[grave_id]), total, _cfg())


## "" or why no candle can be lit (FILLED / MARKED, from 15:00, not burning yet, a grave_candle in `inv`).
func light_block_reason(grave_id: String, inv: Inventory) -> String:
	if not _tended(grave_id):
		return TEXT_NOT_HERE
	if candle_lit(grave_id):
		return TEXT_CANDLE_BURNS
	if not GraveCareRules.may_light_at(TimeManager.minute_of_day, _cfg()):
		return TEXT_TOO_EARLY
	if inv == null or not inv.has(_cfg().candle_item):
		return TEXT_NO_CANDLE
	return ""


## Apprentice passes his box. 1 grave_candle → burns until 07:00; stats.candles_lit.
func light(grave_id: String, inv: Inventory) -> bool:
	if light_block_reason(grave_id, inv) != "":
		return false
	if not inv.remove_item(_cfg().candle_item, 1):
		return false
	light_free(grave_id)
	return true


## A candle without taking one (debug, Lenz's candles already in hand, the apprentice's broken candle that
## still burns). false = no grave or burning already.
func light_free(grave_id: String) -> bool:
	if not _tended(grave_id) or candle_lit(grave_id):
		return false
	var now := TimeManager.total_minutes()
	_candles[grave_id] = now
	_lit_nights[grave_id] = GraveCareRules.night_of(now)
	GameState.add_stat(STAT_CANDLES, 1)
	_schedule_next()
	_changed(grave_id, KIND_CANDLE, true)
	_light_left = 0.0
	return true


## A candle burned on this grave last night (or burns tonight) – the visitor's bonus, by_candle.
func lit_last_night(grave_id: String) -> bool:
	return last_lit_night(grave_id) >= GraveCareRules.night_of(TimeManager.total_minutes() - 720)


## The latest night a candle burned on `grave_id` (−1 = never) – the candle wish (§2.2.5).
func last_lit_night(grave_id: String) -> int:
	return int(_lit_nights.get(grave_id, -1))


## Graves with a burning candle now (Festivals.lights_count, the light pool, the robber).
func lit_graves() -> PackedStringArray:
	var out := PackedStringArray()
	for id: Variant in _candles:
		if candle_lit(String(id)):
			out.append(String(id))
	return out


# --- mortsafe ------------------------------------------------------------------------------------

func has_mortsafe(grave_id: String) -> bool:
	return _mortsafes.has(grave_id)


## "" or why the mortsafe cannot go on (`on`) / come off.
func mortsafe_block_reason(grave_id: String, on: bool, inv: Inventory) -> String:
	if on:
		if not _occupied(grave_id):
			return TEXT_NOT_HERE
		if has_mortsafe(grave_id):
			return TEXT_HAS_MORTSAFE
		if inv == null or not inv.has(_cfg().mortsafe_item):
			return TEXT_NO_MORTSAFE
		return ""
	if not has_mortsafe(grave_id):
		return TEXT_NO_MORTSAFE
	var set_at := int(_mortsafes[grave_id])
	if not GraveCareRules.mortsafe_removable(set_at, TimeManager.total_minutes(), _cfg()):
		return TEXT_MORTSAFE_DAYS % GraveCareRules.mortsafe_days_left(set_at, TimeManager.total_minutes(), _cfg())
	return ""


## on: 1 mortsafe from `inv` onto the grave (stats.mortsafes_set); off (after mortsafe_min_days): back into
## `inv` (reusable).
func set_mortsafe(grave_id: String, on: bool, inv: Inventory) -> bool:
	if mortsafe_block_reason(grave_id, on, inv) != "":
		return false
	if on:
		if not inv.remove_item(_cfg().mortsafe_item, 1):
			return false
		_mortsafes[grave_id] = TimeManager.total_minutes()
		GameState.add_stat(STAT_MORTSAFES, 1)
	else:
		if inv == null or not inv.can_add(_cfg().mortsafe_item, 1):
			return false
		inv.add_item(_cfg().mortsafe_item, 1)
		_mortsafes.erase(grave_id)
	_changed(grave_id, KIND_MORTSAFE, on)
	return true


## Days the mortsafe has lain on `grave_id` (−1 = none) – the grave tooltip.
func mortsafe_days(grave_id: String) -> int:
	if not has_mortsafe(grave_id):
		return -1
	return floori(float(TimeManager.total_minutes() - int(_mortsafes[grave_id])) / 1440.0)


# --- disturbed -----------------------------------------------------------------------------------

func is_disturbed(grave_id: String) -> bool:
	var grave := _grave(grave_id)
	if grave != null:
		return grave.disturbed
	return _disturbed.has(grave_id)


## NightRobber at 05:00: GraveRecord.disturbed, care spot level 3, the flowers trodden; the dead stays in the
## grave (§2.3). stats.graves_disturbed.
func set_disturbed(grave_id: String) -> void:
	if not _occupied(grave_id) or is_disturbed(grave_id):
		return
	var grave := _grave(grave_id)
	if grave != null:
		grave.disturbed = true
	if not _disturbed.has(grave_id):
		_disturbed.append(grave_id)
	var clean := _first(CLEANLINESS_GROUP)
	if clean != null and clean.has_method(&"set_level"):
		clean.call(&"set_level", DIRT_PREFIX + grave_id, DISTURBED_LEVEL)
	remove_flowers(grave_id)
	if _bouquets.erase(grave_id):
		_changed(grave_id, KIND_BOUQUET, false)
	GameState.add_stat(STAT_DISTURBED, 1)
	_changed(grave_id, KIND_DISTURBED, true)


## „Grab wieder schließen" (30 minutes, shovel) – the earth back; stats.graves_closed.
func close_disturbed(grave_id: String) -> bool:
	if not is_disturbed(grave_id):
		return false
	var grave := _grave(grave_id)
	if grave != null:
		grave.disturbed = false
	var i := _disturbed.find(grave_id)
	if i >= 0:
		_disturbed.remove_at(i)
	GameState.add_stat(STAT_CLOSED, 1)
	_changed(grave_id, KIND_DISTURBED, false)
	return true


## ≤ care_cap (+ disturbed_mood); GhostMood reads it.
func care_bonus(grave_id: String) -> int:
	var now := TimeManager.total_minutes()
	var lights_day: Variant = GameState.get_flag(LIGHTS_DAY_FLAG, -1)
	var lights_night := (lights_day is int or lights_day is float) and int(lights_day) == GraveCareRules.night_of(now)
	return GraveCareRules.care_bonus(flowers_state(grave_id), bouquet_fresh(grave_id), candle_lit(grave_id), lights_night,
			is_disturbed(grave_id), _cfg())


## {flowers, bouquets, candles, lit_nights, mortsafes, disturbed, can_fill, light_pool} (§5.1). Gone states
## are dropped.
func save_state() -> Dictionary:
	_prune(TimeManager.total_minutes(), false)
	var disturbed: Array = []
	for id: String in _disturbed:
		disturbed.append(id)
	return {"flowers": _flowers.duplicate(true), "bouquets": _bouquets.duplicate(), "candles": _candles.duplicate(),
			"lit_nights": _lit_nights.duplicate(), "mortsafes": _mortsafes.duplicate(), "disturbed": disturbed,
			"can_fill": _can_fill.duplicate(), "light_pool": []}


## Tolerant: damaged entries are dropped. A disturbed grave saved by the Graveyard (GraveRecord.disturbed)
## counts as well.
func load_state(data: Dictionary) -> void:
	_flowers.clear()
	var f: Variant = data.get("flowers", {})
	if f is Dictionary:
		for key: Variant in f:
			var e: Variant = (f as Dictionary)[key]
			if e is Dictionary:
				var entry: Dictionary = e
				var planted := GraveCareRules._int(entry.get("planted", 0))
				_flowers[str(key)] = {"planted": planted, "watered": GraveCareRules._int(entry.get("watered", planted)),
						"wreath": typeof(entry.get("wreath")) == TYPE_BOOL and bool(entry.get("wreath"))}
	_bouquets = _int_map(data.get("bouquets", {}))
	_candles = _int_map(data.get("candles", {}))
	_lit_nights = _int_map(data.get("lit_nights", {}))
	_mortsafes = _int_map(data.get("mortsafes", {}))
	_disturbed = PackedStringArray()
	var d: Variant = data.get("disturbed", [])
	if d is Array or d is PackedStringArray:
		for id: Variant in d:
			if (id is String or id is StringName) and not _disturbed.has(String(id)):
				_disturbed.append(String(id))
	_can_fill = {}
	var fill: Variant = data.get("can_fill", {})
	if fill is Dictionary:
		for key: Variant in fill:
			var v: Variant = (fill as Dictionary)[key]
			if v is int or v is float:
				_can_fill[str(key)] = clampi(int(v), 0, _cfg().can_fills)
	for id: String in _disturbed:
		var grave := _grave(id)
		if grave != null and grave.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED]:
			grave.disturbed = true
	# W1-Anschluss 8 / W3 (QA8-12, §10 fuzzer): disturbed only on an occupied grave, no mortsafe on an EMPTY one – a
	# half-applied or edited save loses them (the Graveyard is loaded before, save_order 10 < 72).
	var graveyard := _first(GRAVEYARD_GROUP) as Graveyard
	if graveyard != null:
		for grave: GraveRecord in graveyard.graves():
			if grave.disturbed and not _occupied(grave.id):
				grave.disturbed = false
		var kept := PackedStringArray()
		for id: String in _disturbed:
			if _occupied(id):
				kept.append(id)
		_disturbed = kept
		for id: String in _mortsafes.keys():
			if not _occupied(id):
				_mortsafes.erase(id)
	_plots.clear()
	_next_change = -1
	_schedule_next()
	_light_left = 0.0


## The rules in use (data/config/grave_care_config.tres unless a test set `config`).
func get_config() -> GraveCareConfig:
	return _cfg()


# --- clock ---------------------------------------------------------------------------------------

func _on_time_tick(_day: int, _minute: int) -> void:
	var now := TimeManager.total_minutes()
	if _next_change >= 0 and now >= _next_change:
		_prune(now, true)


func _on_time_skipped(_from_total: int, to_total: int) -> void:
	_prune(to_total, true)


func _on_world_ready(_world: Node) -> void:
	_plots.clear()
	_light_left = 0.0


## Drops what is gone by the clock (flowers withered, candles out, bouquets gone); `notify` = signals.
func _prune(now: int, notify: bool) -> void:
	var cfg := _cfg()
	for id: Variant in _flowers.keys():
		if GraveCareRules.flowers_gone(_flowers[id] as Dictionary, now, cfg):
			_flowers.erase(id)
			if notify:
				_changed(String(id), KIND_FLOWERS, false)
	for id: Variant in _candles.keys():
		if not GraveCareRules.candle_burning(int(_candles[id]), now, cfg) and now >= int(_candles[id]):
			_candles.erase(id)
			if notify:
				_changed(String(id), KIND_CANDLE, false)
	for id: Variant in _bouquets.keys():
		if not GraveCareRules.bouquet_fresh(int(_bouquets[id]), now, cfg) and now >= int(_bouquets[id]):
			_bouquets.erase(id)
			if notify:
				_changed(String(id), KIND_BOUQUET, false)
	_schedule_next()


func _schedule_next() -> void:
	var cfg := _cfg()
	var best := -1
	for id: Variant in _flowers:
		var entry: Dictionary = _flowers[id]
		if bool(entry.get("wreath", false)):
			continue
		var t := GraveCareRules.last_watered(entry) + cfg.flower_wilt_minutes
		best = t if best < 0 else mini(best, t)
	for id: Variant in _candles:
		var t := GraveCareRules.candle_out_total(int(_candles[id]), cfg)
		best = t if best < 0 else mini(best, t)
	for id: Variant in _bouquets:
		var t := int(_bouquets[id]) + cfg.bouquet_minutes
		best = t if best < 0 else mini(best, t)
	_next_change = best


func _changed(grave_id: String, kind: StringName, active: bool) -> void:
	EventBus.grave_care_changed.emit(grave_id, kind, active)


# --- light pool (§4.9) ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_light_left -= delta
	if _light_left > 0.0:
		return
	_light_left = LIGHT_INTERVAL
	update_light_pool()


## Gives the pool's omni lights to the burning candles nearest the camera focus (helper, 2 Hz).
func update_light_pool() -> void:
	if not is_inside_tree():
		return
	var lit := lit_graves()
	if lit.is_empty() and _lights.is_empty():
		return
	var focus := _focus()
	var ranked: Array = []
	for id: String in lit:
		var plot := _plot(id)
		if plot != null:
			var p := plot.to_global(CANDLE_OFFSET)
			ranked.append([Vector2(p.x - focus.x, p.z - focus.z).length_squared(), id, p])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	if _lights.is_empty() and not ranked.is_empty():
		for i: int in LIGHT_POOL_SIZE:
			var light := OmniLight3D.new()
			light.name = "CandleLight%d" % i
			light.light_color = LIGHT_COLOR
			light.light_energy = LIGHT_ENERGY
			light.omni_range = LIGHT_RANGE
			light.shadow_enabled = false
			light.visible = false
			add_child(light)
			_lights.append(light)
	for i: int in _lights.size():
		var light := _lights[i]
		if i < ranked.size():
			light.global_position = (ranked[i][2] as Vector3) + Vector3(0.0, LIGHT_HEIGHT, 0.0)
			light.visible = true
		else:
			light.visible = false


## Visible pool lights (tests, perf probe).
func active_lights() -> int:
	var n := 0
	for light: OmniLight3D in _lights:
		if light.visible:
			n += 1
	return n


func _focus() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	var player := _first(PLAYER_GROUP) as Node3D
	if player != null and player.is_inside_tree():
		return player.global_position
	if cam != null:
		return cam.global_position
	return Vector3.ZERO


# --- lookups -------------------------------------------------------------------------------------

func _place_block_reason(grave_id: String) -> String:
	if not _tended(grave_id):
		return TEXT_NOT_HERE
	if is_disturbed(grave_id):
		return TEXT_DISTURBED
	if flowers_state(grave_id) != &"":
		return TEXT_HAS_FLOWERS
	return ""


## The grave holds a dead (FILLED / MARKED). Without a Graveyard in the tree (unit tests of other
## packages) every grave counts.
func _occupied(grave_id: String) -> bool:
	if grave_id == "":
		return false
	var graveyard := _first(GRAVEYARD_GROUP) as Graveyard
	if graveyard == null:
		return true
	var grave := graveyard.get_grave(grave_id)
	return grave != null and grave.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED]


## Flowers and candles also go on the rest-period graves (OLD: old_01…08 – Theres' mother, Esch's master).
func _tended(grave_id: String) -> bool:
	if _occupied(grave_id):
		return true
	var grave := _grave(grave_id)
	return grave != null and grave.state == GraveRecord.State.OLD


func _grave(grave_id: String) -> GraveRecord:
	var graveyard := _first(GRAVEYARD_GROUP) as Graveyard
	return graveyard.get_grave(grave_id) if graveyard != null else null


func _plot(grave_id: String) -> Node3D:
	var cached: Variant = _plots.get(grave_id)
	if cached is Node3D and is_instance_valid(cached):
		return cached
	_plots.clear()
	for node: Node in get_tree().get_nodes_in_group(PLOT_GROUP):
		var id: Variant = node.get("grave_id")
		if node is Node3D and (id is String or id is StringName):
			_plots[String(id)] = node
	return _plots.get(grave_id) as Node3D


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


static func _int_map(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for key: Variant in raw:
			var v: Variant = (raw as Dictionary)[key]
			if (key is String or key is StringName) and (v is int or v is float):
				out[String(key)] = roundi(float(v))
	return out


func _cfg() -> GraveCareConfig:
	if config == null:
		config = Database.config(&"grave_care_config") as GraveCareConfig
	if config == null:
		config = GraveCareConfig.new()
	return config
