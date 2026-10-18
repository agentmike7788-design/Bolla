class_name CartRider
extends Node3D
## Phase 9 W-Welt (docs/PHASE9_DESIGN.md §2.2.7 ending A, §4.5 „Mit Osric: Johann sitzt auf der Ladefläche (Pose sit_cart,
## Kindmesh bundle), Osric fährt um 10:00 den Kutschweg hinunter", W1-Anschlüsse 7): Johann on the bed of Osric's cart.
## While Johann's graveyard figure (Entities/npc_kin_sieber_v_g) is in a sit_cart entry of his plan (at the bier from
## 09:40, down the coach road with Osric 10:00–10:40) and Osric's cart is out, a figure of Johann sits on the cart bed
## and plays sit_cart: its root rides on the cart (the seat 0.45 m above the root, P7), the bundle beside him
## (bundle_down). Johann's own figure (it follows the same path on the ground) is hidden for that time – his
## Interactable stays (he can still be spoken to at the bier). Display only, no state; checked once per game minute,
## placed every frame only while he rides.

const SIT_CART := &"sit_cart"
## glTF extras of the figure's child meshes (shown only in the clips they name – like Npc._apply_props).
const META_EXTRAS := &"extras"
const KEY_SHOW := "show_with"

## Johann's graveyard Npc and Osric's (graveyard) Npc, relative to this node.
@export var rider_path: NodePath = ^"../npc_kin_sieber_v_g"
@export var carter_path: NodePath = ^"../npc_carter"
## Johann's figure (the same model as his Npc).
@export var model: PackedScene
## The root of the sitting figure in the frame of Osric's Cart node (P7: sit_cart seat 0.45 m above the root).
## W3 („Restbedarf“ 8): in the middle of the end board away from Osric (top 0.83 m, Cart -Z), his back to the bed, the
## legs hanging out over the board, looking down the road away from the cart – the root 0.45 m below the board top,
## 4 cm outside it (the seated hips slide back onto the board). Before (W2): the root at the right rear corner 0.6 m
## out, on the height of the floor boards – he sat beside the cart in the air (p9_10).
@export var seat: Transform3D = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.38, -1.07))

var _figure: Node3D
var _anim: AnimationPlayer
var _riding: bool = false
var _minute: int = -1


func _ready() -> void:
	EventBus.time_skipped.connect(_on_time_skipped.unbind(2))
	EventBus.game_loaded.connect(_on_loaded.unbind(1))


func _process(_delta: float) -> void:
	var minute := TimeManager.total_minutes()
	if minute != _minute:
		_minute = minute
		_set_riding(should_ride())
	if _riding:
		_place()


## Johann is in a sit_cart entry and Osric's cart is out (both on the graveyard).
func should_ride() -> bool:
	var rider := get_node_or_null(rider_path) as Npc
	var carter := get_node_or_null(carter_path) as Npc
	if rider == null or carter == null or rider.entry == null or rider.entry.animation != SIT_CART:
		return false
	if not rider.shows_region(rider.entry) or not rider.entry.visible or not rider.flag_allows() or rider.hidden_by_flag():
		return false
	return carter.is_present() and carter.cart.visible


## Johann's figure on the cart bed now (tests, shots).
func is_riding() -> bool:
	return _riding


func figure() -> Node3D:
	return _figure


func _set_riding(on: bool) -> void:
	var rider := get_node_or_null(rider_path) as Npc
	var own := rider.get_node_or_null(^"Model") as Node3D if rider != null else null
	if own != null:
		own.visible = not on
	if on and _figure == null:
		_make_figure()
	if _figure != null:
		_figure.visible = on
	if on and _anim != null and _anim.has_animation(SIT_CART):
		_anim.play(SIT_CART)
	elif not on and _anim != null:
		_anim.pause()
	_riding = on
	if on:
		_place()


func _place() -> void:
	var carter := get_node_or_null(carter_path) as Npc
	if carter == null or _figure == null:
		return
	_figure.global_transform = carter.cart.global_transform * seat


func _make_figure() -> void:
	if model == null:
		return
	_figure = model.instantiate() as Node3D
	_figure.name = "Johann"
	add_child(_figure)
	var found := _figure.find_children("*", "AnimationPlayer", true, false)
	_anim = found[0] as AnimationPlayer if not found.is_empty() else null
	# Only the child meshes of the sitting clip (hat on the head, the bundle beside him on the bed).
	for n: Node in _figure.find_children("*", "MeshInstance3D", true, false):
		var extras: Variant = n.get_meta(META_EXTRAS, {})
		if extras is Dictionary and (extras as Dictionary).has(KEY_SHOW):
			var names := String((extras as Dictionary)[KEY_SHOW]).split(",", false)
			(n as Node3D).visible = String(SIT_CART) in names


func _on_time_skipped() -> void:
	_minute = -1


func _on_loaded() -> void:
	_minute = -1
