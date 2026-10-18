class_name VisitSpot
extends Node3D
## Phase 9 W-Welt (docs/PHASE9_DESIGN.md §2.3.2 part kind visit, §4.6 D10/D11, W1-Anschlüsse 5): the place of a visit
## part of a large request – gate_outside on the graveyard („Licht am Kutschweg"), v_bridge_unload at the Holderbrücke
## („Steine für die Holderbrücke"), v_inn_cellar_help in the inn („Der Keller im Holderkrug"). Built at the waypoint of
## the same name (graveyard_build_phase9.gd, village_build_phase9.gd, interior_build.gd).
## While an accepted large request has its open visit part here: „[E] <prompt of the part>" → HillRequests.start_visit
## (the timed action and the part are HillRequests'); outside the part's window or while busy the prompt is shown dimmed
## with HillRequests' reason („Erst zwischen 21:30 und 23:00."). Without such a part the spot is not focusable.
## Display and one call – no state of its own.

const HILL_GROUP := &"hill_requests"
## Above the stations (5), below the graves (10) and the Npc (30) – the gate's visitors stay talkable.
const PRIORITY := 6
const REACH_RADIUS := 1.6
const REACH_HEIGHT := 2.0
const KIND_VISIT := &"visit"

## The waypoint id the visit part names in conditions.place.
@export var place_id: StringName = &""

var interactable: Interactable


func _ready() -> void:
	interactable = get_node_or_null(^"Interactable") as Interactable
	if interactable == null:
		interactable = Interactable.new()
		interactable.name = "Interactable"
		interactable.priority = PRIORITY
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var cyl := CylinderShape3D.new()
		cyl.radius = REACH_RADIUS
		cyl.height = REACH_HEIGHT
		shape.shape = cyl
		shape.position = Vector3(0.0, REACH_HEIGHT * 0.5, 0.0)
		interactable.add_child(shape)
		add_child(interactable)


func can_interact(player: Player) -> bool:
	var id := request_here()
	return id != &"" and _hill().visit_block_reason(id, player) == ""


## The prompt of the open visit part here, or its reason dimmed; "" (not focusable) when no running request needs
## this place now.
func get_interaction_prompt(player: Player) -> String:
	var id := request_here()
	if id == &"":
		return ""
	var hill := _hill()
	var why := hill.visit_block_reason(id, player)
	if why == HillRules.TEXT_VISIT_HERE:
		return ""
	return hill.visit_prompt(id) if why == "" else why


func interact(player: Player) -> void:
	var id := request_here()
	if id == &"":
		return
	var hill := _hill()
	var why := hill.visit_block_reason(id, player)
	if why != "":
		EventBus.notification_requested.emit(why, &"warning")
		return
	hill.start_visit(id)


## The accepted large request whose next open visit part names this place (&"" = none).
func request_here() -> StringName:
	var hill := _hill()
	if hill == null or place_id == &"":
		return &""
	for id: StringName in hill.large_active():
		var parts := HillRules.parts_of(hill.large_data(id))
		for index: int in hill.open_parts(id):
			var part: OrderData = parts[index] if index < parts.size() else null
			if part != null and part.kind == KIND_VISIT and StringName(str(part.conditions.get("place", ""))) == place_id:
				return id
	return &""


func _hill() -> HillRequests:
	return get_tree().get_first_node_in_group(HILL_GROUP) as HillRequests if is_inside_tree() else null
