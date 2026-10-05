class_name NpcLod
extends Node
## Systems/NpcLod (docs/PHASE7_DESIGN.md §3.1, §3.4, §9): governor_hz times per second it ranks the
## present Npc of the active region (Player.region_id) by distance to the camera focus: the nearest
## max_full within lod_full_distance → level 0, the rest up to lod_rest_distance → 1, beyond → 2. Npc
## of other regions and hidden ones rest (2; they evaluate once per game minute anyway). A present Npc
## of the active region closer than remark_distance to the gravekeeper is reported to
## Relationships.remark (once per person and day – Relationships has the last word). Not saved: the
## levels follow from the positions.
## Phase 8 (docs/PHASE8_DESIGN.md §3.4, §9, P1): on the graveyard at most max_visible_graveyard figures are
## drawn (max_visible_fest on the night of the lights), ranked by distance – the rest is culled (not drawn,
## level 2); max_full stays. Standing figures (idle / kneel / mourn) on the graveyard rest from
## stand_rest_distance (26 m) instead of lod_rest_distance (§9 is the graveyard budget; the village keeps
## Phase 7); on the night of the lights level 1 evaluates at fest_reduced_interval
## (3 Hz).

const GROUP := &"npc_lod"
const RELATIONSHIPS_GROUP := &"relationships"
const FESTIVALS_GROUP := &"festivals"
const FEST_LIGHTS := &"fest_lights"
const GRAVEYARD := &"graveyard"
## Animation prefixes of a standing figure (§3.4: idle / kneel / mourn).
const STANDING_PREFIXES: PackedStringArray = ["idle", "kneel", "mourn"]

## null = data/config/npc_config.tres (resolved lazily).
var config: NpcConfig
## Tests: the focus point instead of the camera rig's target / the player.
var focus_override: Variant = null
## Tests: the running festival instead of Festivals.running() (null = ask the system).
var fest_override: Variant = null

var _levels: Dictionary = {}  # Npc instance id -> level
var _elapsed: float = 0.0
var _visible: int = 0
## npc_id -> TimeManager.day of the last remark call.
var _remark_day: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.0 / maxf(_config().governor_hz, 0.01):
		return
	_elapsed = 0.0
	update_now()


func update_now() -> void:
	if not is_inside_tree():
		return
	var cfg := _config()
	var tree := get_tree()
	var region := RegionRoot.current(tree)
	var focus := _focus()
	var player := tree.get_first_node_in_group(&"player") as Node3D
	var ranked: Array = []  # [distance, npc]
	var levels := {}
	var lights := lights_night()
	var interval := cfg.fest_reduced_interval if lights else 0.0
	for node: Node in tree.get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc == null or not npc.is_inside_tree():
			continue
		if npc.npc_config == null:
			npc.npc_config = cfg
		npc.set_lod_interval(interval)
		if npc.region_id != region or not npc.is_present():
			levels[npc.get_instance_id()] = 2
			npc.set_lod(2)
			npc.set_culled(false)
			continue
		ranked.append([_flat_distance(npc.global_position, focus), npc])
		if player != null and _flat_distance(npc.global_position, player.global_position) < cfg.remark_distance:
			_remark(npc)
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var full := 0
	var cap := visible_cap(region)
	var shown := 0
	for pair: Array in ranked:
		var dist: float = pair[0]
		var npc: Npc = pair[1]
		var level := 2
		var culled := cap >= 0 and shown >= cap
		if not culled:
			shown += 1
			var rest := cfg.stand_rest_distance if region == GRAVEYARD and is_standing(npc) else cfg.lod_rest_distance
			if dist <= cfg.lod_full_distance and full < cfg.max_full:
				level = 0
				full += 1
			elif dist <= rest:
				level = 1
		levels[npc.get_instance_id()] = level
		npc.set_lod(level)
		npc.set_culled(culled)
	_levels = levels
	_visible = shown


## 0 full · 1 reduced · 2 resting (0 for an Npc the last update did not see).
func lod_of(npc: Npc) -> int:
	return int(_levels.get(npc.get_instance_id(), 0)) if npc != null else 0


## Drawn figures of the active region at the last update (Phase 8 cap).
func visible_count() -> int:
	return _visible


## Visible cap of `region_id`: graveyard max_visible_graveyard (max_visible_fest on the night of the
## lights); -1 = none (village, interiors: Phase 7 budget).
func visible_cap(region_id: StringName) -> int:
	if region_id != GRAVEYARD:
		return -1
	var cfg := _config()
	return cfg.max_visible_fest if lights_night() else cfg.max_visible_graveyard


## The night of the lights is running (Festivals.running() == fest_lights).
func lights_night() -> bool:
	if fest_override != null:
		return StringName(str(fest_override)) == FEST_LIGHTS
	var fest := get_tree().get_first_node_in_group(FESTIVALS_GROUP) if is_inside_tree() else null
	return fest != null and fest.has_method(&"running") and StringName(str(fest.call(&"running"))) == FEST_LIGHTS


## A standing figure (not walking, animation idle* / kneel* / mourn*).
static func is_standing(npc: Npc) -> bool:
	if npc == null or npc.is_walking():
		return false
	var anim := String(npc.current_animation())
	if anim == "":
		anim = String(npc.entry.animation) if npc.entry != null else "idle"
	for prefix: String in STANDING_PREFIXES:
		if anim.begins_with(prefix):
			return true
	return false


## Npc with level 0 at the last update.
func full_count() -> int:
	var n := 0
	for level: int in _levels.values():
		if level == 0:
			n += 1
	return n


func _remark(npc: Npc) -> void:
	if npc.npc_id == &"" or int(_remark_day.get(npc.npc_id, -1)) == TimeManager.day:
		return
	var relationships := get_tree().get_first_node_in_group(RELATIONSHIPS_GROUP)
	if relationships == null or not relationships.has_method(&"remark"):
		return
	_remark_day[npc.npc_id] = TimeManager.day
	relationships.call(&"remark", npc.npc_id)


## The camera focus: focus_override, else the CameraRig's target (the player), else the player.
func _focus() -> Vector3:
	if focus_override is Vector3:
		return focus_override
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var rig := cam.get_parent() as CameraRig if cam != null else null
	if rig != null and is_instance_valid(rig.target):
		return rig.target.global_position
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	return player.global_position if player != null else Vector3.ZERO


func _config() -> NpcConfig:
	if config == null:
		config = Database.config(&"npc_config") as NpcConfig
		if config == null:
			config = NpcConfig.new()
	return config


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
