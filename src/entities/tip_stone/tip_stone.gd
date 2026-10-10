class_name TipStone
extends Node3D
## The coins a visitor left on the stone (docs/PHASE8_DESIGN.md §2.2.3, §3.1, §3.4): child of a GravePlot, not
## saved itself (the state is in Visitors.tips_on_stone); child mesh coins (ph_prop_tip_coins, else a small
## placeholder) at the marker height of the stone; „[E] Zwei Münzen auf dem Stein (%s)" → Visitors.take_tip(grave_id,
## inv). Ghosts and the robber take nothing. Shows / hides itself on grave_care_changed(…, &"tip", …).

const PROMPT_FORMAT := "[E] %s"
const VISITORS_GROUP := &"visitors"
const KIND_TIP := &"tip"
const COINS_NAME := "Coins"
const COINS_PATH := "res://assets/models/props/ph_prop_tip_coins.glb"
const COIN_COLOR := Color("#B08D57")
const PAPER_COLOR := Color("#E3DCCB")

## The grave of the parent GravePlot ("" = the parent's grave_id).
@export var grave_id: String = ""

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

var _coins: Node3D


func _ready() -> void:
	if grave_id == "":
		var id: Variant = get_parent().get("grave_id") if get_parent() != null else null
		grave_id = String(id) if id is String or id is StringName else ""
	EventBus.grave_care_changed.connect(_on_care_changed)
	EventBus.game_loaded.connect(_on_loaded)
	refresh()


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and not is_instance_valid(player.carried) and coins() > 0


func get_interaction_prompt(_player: Player) -> String:
	var n := coins()
	if n <= 0:
		return ""
	var visitors := _visitors()
	return PROMPT_FORMAT % Phase8Texts.coins_on_stone(n, visitors.tip_giver(grave_id) if visitors != null else "")


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var visitors := _visitors()
	if visitors != null:
		visitors.take_tip(grave_id, player.inventory)
	refresh()


## The coins lying on the stone (Visitors.tip_on_stone).
func coins() -> int:
	var visitors := _visitors()
	return visitors.tip_on_stone(grave_id).x if visitors != null else 0


## Shows / hides the coins from Visitors.tip_on_stone.
func refresh() -> void:
	var show := coins() > 0
	if show and _coins == null:
		_coins = _make_coins()
		_coins.name = COINS_NAME
		add_child(_coins)
	if _coins != null:
		_coins.visible = show
	if interactable != null:
		interactable.enabled = show
		interactable.set_deferred(&"monitorable", show)


func _make_coins() -> Node3D:
	if ResourceLoader.exists(COINS_PATH):
		return (load(COINS_PATH) as PackedScene).instantiate() as Node3D
	var root := Node3D.new()
	for i: int in 3:
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.022
		m.bottom_radius = 0.022
		m.height = 0.006
		m.radial_segments = 10
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COIN_COLOR
		mat.metallic = 0.6
		m.material = mat
		mi.mesh = m
		mi.position = Vector3(-0.05 + i * 0.045, 0.004 + i * 0.006, 0.0)
		root.add_child(mi)
	var paper := MeshInstance3D.new()
	var p := BoxMesh.new()
	p.size = Vector3(0.08, 0.004, 0.05)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = PAPER_COLOR
	p.material = pm
	paper.mesh = p
	paper.position = Vector3(0.09, 0.002, 0.02)
	root.add_child(paper)
	return root


func _on_care_changed(id: String, kind: StringName, _active: bool) -> void:
	if id == grave_id and kind == KIND_TIP:
		refresh()


func _on_loaded(_slot: int) -> void:
	refresh()


func _visitors() -> Visitors:
	return get_tree().get_first_node_in_group(VISITORS_GROUP) as Visitors if is_inside_tree() else null
