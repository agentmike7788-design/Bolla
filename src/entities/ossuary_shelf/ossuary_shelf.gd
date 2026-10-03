class_name OssuaryShelf
extends Node3D
## The ossuary niche inside the crypt (docs/PHASE6_DESIGN.md §2.3, §3.4, §4.8):
## „[E] Gebeine beisetzen (20 Min) – 1 Kiste wartet" → Ossuary.reinter (TimedAction, not
## cancellable). Shows one bone box and the old gravestone (leaning, 0.9 ×) per reinterred grave
## at the markers box_1…6 / stone_1…6 of the shelf model, and from crypt level 3 the name board
## (Label3D at the marker "names"). The shelf model is P5's ph_int_ossuary_shelf (instanced here
## as "Model" when present); without it the boxes and stones stand in a plain row.
## refresh() is visual only; it runs on bones_reinterred, building_upgraded, game_loaded and when
## the crypt room is entered – the listeners never change game state.

const PROMPT_REINTER := "[E] Gebeine beisetzen (%d Min)"
const SUFFIX_ONE := " – 1 Kiste wartet"
const SUFFIX_MANY := " – %d Kisten warten"
const PROMPT_NO_BOX := "Die belegte Gebeinkiste ist nicht im Gepäck."
const PROMPT_INFO := "Beinhaus – %d von %d Plätzen belegt"
const LABEL_REINTER := "Gebeine beisetzen"
const ANIM := &"interact"
const OSSUARY_GROUP := &"ossuary"
const BUILDINGS_GROUP := &"buildings"
const CRYPT := &"crypt"
const MODEL_PATH := "res://assets/models/interior/ph_int_ossuary_shelf.glb"
const BOX_PATH := "res://assets/models/interior/ph_int_bone_box.glb"
const MARKER_BOX := "box_%d"
const MARKER_STONE := "stone_%d"
const MARKER_NAMES := "names"
const SLOTS := 6
## Old stones lean against the wall at 0.9 × (§4.8), tilted back a little.
const STONE_SCALE := 0.9
const STONE_TILT_DEG := -10.0
## Fallback layout without the shelf model (shelf-local): a row along X.
const ROW_START := Vector3(-1.0, 0.9, 0.0)
const ROW_STEP := Vector3(0.4, 0.0, 0.0)
const STONE_ROW_OFFSET := Vector3(0.0, -0.9, 0.45)
const NAMES_OFFSET := Vector3(0.0, 1.7, 0.05)
const NAME_BOARD_EM := 0.045
const NAME_BOARD_WIDTH := 1.1

## Crypt level of the name board (§2.1: level 3 „Namenstafel").
@export var name_board_level: int = 3

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

var _boxes: Node3D
var _stones: Node3D
var _names: Node3D


## Group ossuary_shelf: Buildings.apply_levels refreshes it right after an upgrade / a load (QA6-06).
func _init() -> void:
	add_to_group(&"ossuary_shelf", true)


func _ready() -> void:
	if get_node_or_null(^"Model") == null and ResourceLoader.exists(MODEL_PATH):
		var model := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
		model.name = "Model"
		add_child(model)
	EventBus.bones_reinterred.connect(_on_changed.unbind(2))
	EventBus.building_upgraded.connect(_on_changed.unbind(2))
	EventBus.game_loaded.connect(_on_changed.unbind(1))
	EventBus.interior_room_changed.connect(_on_changed.unbind(1))
	refresh()


## Boxes, old stones, name board.
func refresh() -> void:
	var ossuary := _ossuary()
	var done := ossuary.reinterred() if ossuary != null else PackedStringArray()
	_boxes = _fresh_group(_boxes, "Boxes")
	_stones = _fresh_group(_stones, "OldStones")
	_names = _fresh_group(_names, "NameBoard")
	var box_scene := load(BOX_PATH) as PackedScene if ResourceLoader.exists(BOX_PATH) else null
	for i: int in mini(done.size(), SLOTS):
		var box := _instance(box_scene, "Box%d" % (i + 1))
		box.transform = _marker_xform(MARKER_BOX % (i + 1), ROW_START + ROW_STEP * i)
		_boxes.add_child(box)
		var data := ossuary.data_of(done[i])
		var stone := _instance(data.stone_model if data != null else null, "Stone%d" % (i + 1))
		stone.set_meta(&"grave_id", done[i])
		var at := _marker_xform(MARKER_STONE % (i + 1), ROW_START + STONE_ROW_OFFSET + ROW_STEP * i)
		stone.transform = at * Transform3D(Basis.from_euler(Vector3(deg_to_rad(STONE_TILT_DEG), 0, 0)).scaled(Vector3.ONE * STONE_SCALE),
				Vector3.ZERO)
		_stones.add_child(stone)
	_names.visible = _crypt_level() >= name_board_level and not done.is_empty()
	if _names.visible:
		_names.transform = _marker_xform(MARKER_NAMES, NAMES_OFFSET)
		var lines: PackedStringArray = []
		for id: String in done:
			var data := ossuary.data_of(id)
			lines.append(OssuaryRules.label(data) if data != null else id)
		var y := 0.0
		for line: String in lines:
			var label := StoneVisual.make_label(line, NAME_BOARD_EM, NAME_BOARD_WIDTH, false)
			label.position = Vector3(0, y, 0)
			_names.add_child(label)
			y -= NAME_BOARD_EM * 1.4


## Grave ids shown as old stones (tests / debug).
func shown_stones() -> PackedStringArray:
	var out := PackedStringArray()
	if _stones != null:
		for c: Node in _stones.get_children():
			out.append(str(c.get_meta(&"grave_id", "")))
	return out


func shown_boxes() -> int:
	return _boxes.get_child_count() if _boxes != null else 0


func name_board_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if _names != null and _names.visible:
		for c: Node in _names.get_children():
			if c is Label3D:
				out.append((c as Label3D).text)
	return out


func can_interact(player: Player) -> bool:
	var ossuary := _ossuary()
	if ossuary == null or player == null or player.is_busy() or is_instance_valid(player.carried):
		return false
	return not ossuary.pending().is_empty() and player.inventory != null \
			and player.inventory.has(ossuary.rules().full_item)


func get_interaction_prompt(player: Player) -> String:
	var ossuary := _ossuary()
	if ossuary == null:
		return ""
	var waiting := ossuary.pending().size()
	if waiting == 0:
		return PROMPT_INFO % [ossuary.used(), ossuary.capacity()]
	if player != null and is_instance_valid(player.carried):
		return Player.TEXT_HANDS_FULL
	if player == null or player.inventory == null or not player.inventory.has(ossuary.rules().full_item):
		return PROMPT_NO_BOX
	return PROMPT_REINTER % ossuary.rules().reinter_minutes + (SUFFIX_ONE if waiting == 1 else SUFFIX_MANY % waiting)


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	player.start_timed_action(LABEL_REINTER, _ossuary().rules().reinter_minutes, _finish.bind(player.inventory), false, ANIM)


func _finish(inv: Inventory) -> void:
	var ossuary := _ossuary()
	if ossuary != null:
		ossuary.reinter(inv)
	refresh()


func _on_changed() -> void:
	if is_inside_tree():
		refresh.call_deferred()


func _fresh_group(old: Node3D, group_name: String) -> Node3D:
	if old != null and is_instance_valid(old):
		remove_child(old)
		old.queue_free()
	var node := Node3D.new()
	node.name = group_name
	add_child(node)
	return node


func _instance(scene: PackedScene, node_name: String) -> Node3D:
	var node := scene.instantiate() as Node3D if scene != null else null
	if node == null:
		node = Node3D.new()
	node.name = node_name
	return node


## Shelf-local transform of a marker of the shelf model (`fallback` position without one).
func _marker_xform(marker: String, fallback: Vector3) -> Transform3D:
	var model := get_node_or_null(^"Model")
	var node := model.find_child(marker, true, false) as Node3D if model != null else null
	if node == null:
		return Transform3D(Basis.IDENTITY, fallback)
	return global_transform.affine_inverse() * node.global_transform if is_inside_tree() else node.transform


func _crypt_level() -> int:
	var buildings := get_tree().get_first_node_in_group(BUILDINGS_GROUP) if is_inside_tree() else null
	return int(buildings.call(&"level", CRYPT)) if buildings != null and buildings.has_method(&"level") else 0


func _ossuary() -> Ossuary:
	return get_tree().get_first_node_in_group(OSSUARY_GROUP) as Ossuary if is_inside_tree() else null
