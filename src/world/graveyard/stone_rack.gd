extends Node3D
## The rack of finished stones at the mason's bench (docs/PHASE5_DESIGN.md §2.5, §8): every stone
## waiting in Stonemasonry.ready_stones() stands – with its shape, ornament and carved text
## (StoneVisual) – at the bench model's marker stone_slot_1…3, leaning back a little.
## Presentation only; rebuilt on stone_order_changed and after a load. Child of station_mason
## (hidden with it until the bench is built).

const MASONRY_GROUP := &"stonemasonry"
const SLOT_FORMAT := "stone_slot_%d"
const SLOTS := 3
## Lean against the rack (rad) and the turn of each stone: W3 (G5 QA) – the fronts face the
## gameplay camera (world +Z, south), turned a little towards the bench (TURN), whatever the
## bench's own rotation; before they showed their backs from the default view.
const LEAN := 0.12
const TURN := 0.35

## Order ids shown, in slot order (tests read it).
var shown: PackedStringArray = []


func _ready() -> void:
	EventBus.stone_order_changed.connect(_on_order_changed)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.new_game_started.connect(refresh)
	refresh()


func refresh() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	shown = PackedStringArray()
	var masonry := get_tree().get_first_node_in_group(MASONRY_GROUP) if is_inside_tree() else null
	if masonry == null:
		return
	var model := get_parent().get_node_or_null(^"Model") as Node3D
	var stones: Array = masonry.call(&"ready_stones")
	for i: int in mini(stones.size(), SLOTS):
		var marker := model.find_child(SLOT_FORMAT % (i + 1), true, false) as Node3D if model != null else null
		var stone := StoneVisual.build(StoneDesign.from_dict((stones[i] as Dictionary).design))
		if stone == null:
			continue
		stone.name = "Stone_%d" % (i + 1)
		var at := _relative(marker) if marker != null else Transform3D(Basis.IDENTITY, Vector3(0.4 + 0.3 * i, 0.06, 0.4 - 0.4 * i))
		var yaw := TURN - _parent_yaw()
		stone.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -LEAN), at.origin)
		for mesh: Node in stone.find_children("*", "GeometryInstance3D", true, false):
			(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(stone)
		shown.append(String((stones[i] as Dictionary).id))


## World yaw of the bench (the parent) – 0 outside the tree.
func _parent_yaw() -> float:
	var p := get_parent() as Node3D
	return p.global_rotation.y if p != null and p.is_inside_tree() else 0.0


func _relative(marker: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = marker
	while n != null and n != get_parent():
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return transform.affine_inverse() * xf


func _on_order_changed(_order_id: String, _grave_id: String, _state: StringName) -> void:
	refresh()


func _on_game_loaded(_slot: int) -> void:
	refresh()
