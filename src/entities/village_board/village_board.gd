class_name VillageBoard
extends Node3D
## The parish board at the linden (docs/PHASE7_DESIGN.md §2.5, §3.4, §4.2): „[E] Gemeindetafel lesen"
## → panel &"orders" {board: true, orders (today's board offers), header (the gravekeeper's
## reputation), inventory, player}. Usable once the village is open; the offers themselves come from
## Orders (apply_morning, two per day).
## Phase 9 „Größere Bitten" (docs/PHASE9_DESIGN.md §2.3.4, P2): from village_open a large request may hang here too –
## a folded sheet with a seal thread at the right edge of the board (ph_notice_sheet, code meshes like the gate's
## slips) and, in the panel context, the card „Große Bitte" above the orders: {large, large_cards, hill_place village}
## (W-UI shows it; large_context gives the context of the panel &"hill_requests" with place village).

const PANEL := &"orders"
const PROMPT := "[E] Gemeindetafel lesen"
## Header line of the board (§2.4).
const HEADER := "Totengräber auf dem Hügel – Ruf: %s"
const TEXT_EMPTY := "Heute hängt nichts an der Tafel."
## Phase 9: the large sheet.
const HILL_PANEL := &"hill_requests"
const HILL_GROUP := &"hill_requests"
const PLACE := &"village"
const PAINTED_MATERIAL := "res://assets/materials/mat_painted.tres"
## On the board's face (ph_prop_v_board: board centre 1.35 m high, 1.16 m wide, face towards +z), at its right edge.
const SHEET_POS := Vector3(0.43, 1.33, 0.065)
const SHEET_TILT := 3.0
const SHEET_SIZE := Vector3(0.2, 0.27, 0.008)
const SHEET_COLOR := Color("#e6d6ae")
const FOLD_COLOR := Color("#c9b88e")
const SEAL_COLOR := Color("#7a2a1e")

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

## Phase 9: the large sheet (shown while a large request hangs at the board).
var sheet: Node3D


func _ready() -> void:
	_make_sheet()
	EventBus.hill_request_changed.connect(_on_hill_changed.unbind(2))
	EventBus.day_started.connect(_on_hill_changed.unbind(1))
	EventBus.game_loaded.connect(_on_hill_changed.unbind(1))
	EventBus.world_ready.connect(_on_hill_changed.unbind(1))
	refresh()


func can_interact(_player: Player) -> bool:
	return GameState.flag_on(&"village_open")


func get_interaction_prompt(_player: Player) -> String:
	return PROMPT if GameState.flag_on(&"village_open") else ""


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	EventBus.ui_panel_requested.emit(PANEL, panel_context(player))


## {board: true, orders, header, empty_text, inventory, player} + Phase 9 {large, large_cards, hill_place}.
func panel_context(player: Player) -> Dictionary:
	var orders := get_tree().get_first_node_in_group(&"orders") if is_inside_tree() else null
	var ids: Array[StringName] = []
	if orders != null and orders.has_method(&"board"):
		ids = orders.call(&"board")
	var ctx := {"board": true, "orders": ids, "header": header_text(), "empty_text": TEXT_EMPTY, "player": player,
			"large": large_ids(), "large_cards": large_cards(), "hill_place": PLACE}
	if player != null and is_instance_valid(player):
		ctx["inventory"] = player.inventory
	return ctx


## Phase 9: the context of the panel &"hill_requests" for the large request of the parish board.
func large_context(player: Player) -> Dictionary:
	var ctx := {"player": player, "place": PLACE, "large": large_ids(), "large_cards": large_cards()}
	if player != null and is_instance_valid(player):
		ctx["inventory"] = player.inventory
	return ctx


## Phase 9: the large requests pinned at the parish board.
func large_ids() -> Array[StringName]:
	var hill := _hill()
	if hill == null or not hill.has_method(&"large_board"):
		return [] as Array[StringName]
	return hill.call(&"large_board", PLACE)


func large_cards() -> Array:
	var out: Array = []
	var hill := _hill()
	if hill != null and hill.has_method(&"large_card"):
		for id: StringName in large_ids():
			out.append(hill.call(&"large_card", id))
	return out


func sheet_visible() -> bool:
	return sheet != null and sheet.visible


func refresh() -> void:
	if sheet != null:
		sheet.visible = not large_ids().is_empty()


## „Totengräber auf dem Hügel – Ruf: Geachtet".
static func header_text() -> String:
	return HEADER % GameState.reputation_label()


func _hill() -> Node:
	return get_tree().get_first_node_in_group(HILL_GROUP) if is_inside_tree() else null


func _on_hill_changed() -> void:
	refresh()


func _make_sheet() -> void:
	if sheet != null:
		return
	var base := load(PAINTED_MATERIAL) as ShaderMaterial
	sheet = Node3D.new()
	sheet.name = "LargeSheet"
	sheet.transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(SHEET_TILT)), SHEET_POS)
	sheet.add_child(_box("Sheet", "ph_notice_sheet", SHEET_SIZE, SHEET_COLOR, base, Vector3.ZERO))
	sheet.add_child(_box("Fold", "ph_notice_sheet_fold", Vector3(SHEET_SIZE.x, 0.005, 0.002), FOLD_COLOR, base,
			Vector3(0, 0.015, SHEET_SIZE.z * 0.5 + 0.001)))
	sheet.add_child(_box("Thread", "ph_notice_seal_thread", Vector3(0.005, SHEET_SIZE.y * 0.55, 0.003), SEAL_COLOR, base,
			Vector3(SHEET_SIZE.x * 0.3, -SHEET_SIZE.y * 0.2, SHEET_SIZE.z * 0.5 + 0.002)))
	sheet.add_child(_box("Seal", "ph_notice_seal", Vector3(0.026, 0.026, 0.008), SEAL_COLOR, base,
			Vector3(SHEET_SIZE.x * 0.3, -SHEET_SIZE.y * 0.42, SHEET_SIZE.z * 0.5 + 0.004)))
	sheet.visible = false
	add_child(sheet)


func _box(node_name: String, mesh_name: String, size: Vector3, color: Color, base: ShaderMaterial, offset: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.resource_name = mesh_name
	if base != null:
		var mat := base.duplicate() as ShaderMaterial
		mat.resource_name = "mat_" + mesh_name
		mat.set_shader_parameter(&"tint", color)
		mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = offset
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
