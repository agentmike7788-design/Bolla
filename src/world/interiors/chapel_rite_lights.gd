extends Node
## The chapel's rite lights (docs/PHASE6_DESIGN.md §4.8), child "RiteLights" of the chapel room:
## - the altar candles (lights with interior_role "rite" + the altar model's flame meshes flame_*)
##   burn only while a service or devotion runs (ChapelAltar.rite_active) and from chapel level 3
##   always (Ewiges Licht); their energy follows the room's candle values by daylight;
## - the eternal light at the candelabrum (role "eternal", level 3 furniture);
## - the coloured spot of the choir window (role "stain", level 3), by day only.
## InteriorLighting leaves these roles alone. Presentation only; runs while the room is active or
## a rite is on (a few property reads, 4 Hz).

const META_ROLE := &"interior_role"
const ALTAR_GROUP := &"chapel_altar"
const BUILDINGS_GROUP := &"buildings"
const FLAME_PREFIX := "flame_"
const INTERVAL := 0.25
## Energy of the eternal light and of the choir window's spot (§4.8).
const ETERNAL_ENERGY := 0.4
const STAIN_ENERGY := 0.9

var _room: InteriorRoom
var _altar: Node
var _rite: Array[Light3D] = []
var _eternal: Array[Light3D] = []
var _stain: Array[Light3D] = []
var _flames: Array[Node3D] = []
var _wait: float = 0.0


func _ready() -> void:
	_room = get_parent() as InteriorRoom
	if _room == null:
		set_process(false)
		return
	for node: Node in _room.find_children("*", "Light3D", true, false):
		match StringName(node.get_meta(META_ROLE, &"")):
			&"rite":
				_rite.append(node as Light3D)
			&"eternal":
				_eternal.append(node as Light3D)
			&"stain":
				_stain.append(node as Light3D)
	for node: Node in _room.find_children(FLAME_PREFIX + "*", "MeshInstance3D", true, false):
		_flames.append(node as Node3D)
	apply()


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = INTERVAL
	apply()


## True while a rite runs at the chapel altar.
func rite_active() -> bool:
	if _altar == null or not is_instance_valid(_altar):
		_altar = get_tree().get_first_node_in_group(ALTAR_GROUP) if is_inside_tree() else null
	return _altar != null and bool(_altar.get(&"rite_active"))


## Chapel level (0 without Buildings).
func level() -> int:
	var b := get_tree().get_first_node_in_group(BUILDINGS_GROUP) if is_inside_tree() else null
	return int(b.call(&"level", &"chapel")) if b != null and b.has_method(&"level") else 0


## Whether the altar candles burn now.
func candles_lit() -> bool:
	return rite_active() or level() >= 3


func apply() -> void:
	if _room == null:
		return
	var cfg := _room.room_config()
	var clock := get_node_or_null(^"/root/TimeManager")
	var minute := float(clock.call(&"get_minute_f")) if clock != null else 720.0
	var day := cfg.daylight(minute)
	var lit := candles_lit()
	var lvl := level()
	for light: Light3D in _rite:
		var e := lerpf(cfg.candle_night_energy, cfg.candle_day_energy, day) if lit else 0.0
		_put_energy(light, maxf(e, 0.12) if lit else 0.0)
	for flame: Node3D in _flames:
		flame.visible = lit
	for light: Light3D in _eternal:
		_put_energy(light, ETERNAL_ENERGY if lvl >= 3 else 0.0)
	for light: Light3D in _stain:
		_put_energy(light, STAIN_ENERGY * day if lvl >= 3 else 0.0)


static func _put_energy(light: Light3D, energy: float) -> void:
	light.set_meta(&"base_energy", energy)
	light.set_meta(&"scale", 1.0)
	light.light_energy = energy
	light.visible = energy > 0.01
