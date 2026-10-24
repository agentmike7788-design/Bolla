class_name NoticeBoard
extends Node3D
## Cemetery notice board at the gate (docs/PHASE3_DESIGN.md §4.1, W-Welt): model
## ph_prop_notice_board ("Model", in the scene) and a Label3D ("Label", added in _ready) on its
## marker label_board, showing the cemetery rating (CemeteryScore, group cemetery_score) and the
## village reputation (Reputation, group reputation). Refreshes on cemetery_quality_changed,
## reputation_changed, world_ready, game_loaded and new_game_started.
## Not saved.
## G8 Runde 6 „Bitten vom Hügel" (docs/PHASE8_DESIGN.md, G8 Runde 6 §5): from HillRequestsConfig.start_day the board
## is interactive – „[E] Bitten am Tor lesen" opens the docked panel &"hill_requests" (HillRequestsPanel) – and the
## requests Osric pinned show as paper slips (ph_notice_slip, a painted box like ph_door_note) beside the label.
## STUB (W-Welt) → implemented in W2; this marker line stays for test_phase3_scaffold.
## Phase 9 „Größere Bitten" (docs/PHASE9_DESIGN.md §2.3.4, P2): below the slips hangs a large folded sheet with a seal
## thread (ph_notice_sheet + ph_notice_seal, code meshes like the slips) while a large request is pinned at the gate;
## the panel context carries the large ids and their cards ({large, large_cards, place gate}) – the panel shows the sheet
## as its first card (W-UI).

const MARKER := "label_board"
const TITLE := "Friedhof Hollerbrück"
const TEXT := "%s\n„%s“\nRuf: %s"
## Label look (painted ink on wood, like the signpost).
const FONT_SIZE := 44
const PIXEL_SIZE := 0.0021
const INK := Color("#2a1f18")
## Lift off the board surface against z-fighting (m).
const SURFACE_OFFSET := 0.012

## G8 Runde 6: the request panel and the slips.
const PANEL := &"hill_requests"
const HILL_GROUP := &"hill_requests"
const PAINTED_MATERIAL := "res://assets/materials/mat_painted.tres"
const SLIP_SIZE := Vector3(0.19, 0.24, 0.008)
## Lighter than the paper printed on the board's texture, so a pinned request stands out.
const SLIP_COLOR := Color("#efe3c2")
## The word on a slip (ink like the label).
const SLIP_WORD := "Bitte"
const SLIP_FONT_SIZE := 30
const PIN_COLOR := Color("#5a2a1c")
const PIN_SIZE := Vector3(0.018, 0.018, 0.01)
## Slip places (relative to the label marker: x, y, tilt in degrees) – pinned to the lower edge of the board, below the text.
const SLIP_SPOTS: Array[Vector3] = [Vector3(-0.24, -0.37, -5.0), Vector3(0.26, -0.36, 4.0)]
## Phase 9: the large sheet between the slips, a little lower (x, y, tilt in degrees relative to the label marker).
const SHEET_SPOT := Vector3(0.01, -0.42, 2.0)
const SHEET_SIZE := Vector3(0.24, 0.32, 0.01)
const SHEET_COLOR := Color("#e6d6ae")
## The fold across the sheet and the red seal thread with its wax dot.
const FOLD_COLOR := Color("#c9b88e")
const SEAL_COLOR := Color("#7a2a1e")
const SHEET_WORD := "Große Bitte"
## A9-6: the word's size and height on the sheet (its centre; the pin sits at the top edge, the fold at y 0.02).
const SHEET_FONT_SIZE := 22
const SHEET_WORD_Y := 0.06
const PLACE := &"gate"

var label: Label3D
## The slip meshes (shown: one per request on the board).
var slips: Array[Node3D] = []
## Phase 9: the large sheet (shown while a large request hangs at the gate).
var sheet: Node3D


func _ready() -> void:
	label = get_node_or_null(^"Label") as Label3D
	if label == null:
		label = _make_label()
	EventBus.cemetery_quality_changed.connect(_on_changed.unbind(2))
	EventBus.reputation_changed.connect(_on_changed.unbind(4))
	EventBus.world_ready.connect(_on_changed.unbind(1))
	EventBus.game_loaded.connect(_on_changed.unbind(1))
	# Reputation sets the start value on new_game_started without reputation_changed (its
	# Systems node connected first, so the value is already set here).
	EventBus.new_game_started.connect(refresh)
	EventBus.hill_request_changed.connect(_on_changed.unbind(2))
	EventBus.day_started.connect(_on_changed.unbind(1))
	_make_slips()
	_make_sheet()
	refresh()


# --- G8 Runde 6: interaction ----------------------------------------------------------------------

func can_interact(_player: Player) -> bool:
	return _hill() != null and TimeManager.day >= _start_day()


func get_interaction_prompt(_player: Player) -> String:
	return HillTexts.PROMPT if can_interact(_player) else ""


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	EventBus.ui_panel_requested.emit(PANEL, panel_context(player))


## {player, inventory} for HillRequestsPanel (it reads HillRequests itself); Phase 9: + {place gate, large (ids at the
## gate), large_cards (HillRequests.large_card of each)}.
func panel_context(player: Player) -> Dictionary:
	var ctx := {"player": player, "place": PLACE, "large": large_ids(), "large_cards": large_cards()}
	if player != null and is_instance_valid(player):
		ctx["inventory"] = player.inventory
	return ctx


## Slips shown now (one per request on the board).
func slip_count() -> int:
	var n := 0
	for s: Node3D in slips:
		if s.visible:
			n += 1
	return n


## Phase 9: the large requests pinned at the gate.
func large_ids() -> Array[StringName]:
	var hill := _hill()
	if hill == null or not hill.has_method(&"large_board"):
		return [] as Array[StringName]
	return hill.call(&"large_board", PLACE)


## Phase 9: the cards of the large requests at the gate (title, giver, text, parts with ticks, deadline, reward, reason).
func large_cards() -> Array:
	var out: Array = []
	var hill := _hill()
	if hill != null and hill.has_method(&"large_card"):
		for id: StringName in large_ids():
			out.append(hill.call(&"large_card", id))
	return out


func sheet_visible() -> bool:
	return sheet != null and sheet.visible


## Rewrites the label from the current rating and reputation.
func refresh() -> void:
	if label != null:
		label.text = board_text(_rating(), _reputation_tier())
	var hill := _hill()
	var shown: int = hill.call(&"board").size() if hill != null and hill.has_method(&"board") else 0
	for i: int in slips.size():
		slips[i].visible = i < shown
	if sheet != null:
		sheet.visible = not large_ids().is_empty()


## "Friedhof Hollerbrück\n„Gepflegt“\nRuf: Geachtet"
static func board_text(rating: StringName, reputation_tier: StringName) -> String:
	return TEXT % [TITLE, CemeteryRating.label(rating), ReputationRules.label(reputation_tier)]


func _make_label() -> Label3D:
	var l := Label3D.new()
	l.name = "Label"
	l.font_size = FONT_SIZE
	l.pixel_size = PIXEL_SIZE
	l.modulate = INK
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.line_spacing = -4.0
	var marker := find_child(MARKER, true, false) as Node3D
	var at := Transform3D.IDENTITY
	if marker != null:
		at = _relative(marker)
	else:
		push_warning("[NoticeBoard] model has no %s marker" % MARKER)
		at.origin = Vector3(0, 1.25, 0.05)
	l.transform = at * Transform3D(Basis.IDENTITY, Vector3(0, 0, SURFACE_OFFSET))
	add_child(l)
	return l


func _make_slips() -> void:
	if not slips.is_empty():
		return
	var marker := find_child(MARKER, true, false) as Node3D
	var at := _relative(marker) if marker != null else Transform3D(Basis.IDENTITY, Vector3(0, 1.25, 0.05))
	var base := load(PAINTED_MATERIAL) as ShaderMaterial
	for i: int in SLIP_SPOTS.size():
		var spot := SLIP_SPOTS[i]
		var slip := Node3D.new()
		slip.name = "Slip%d" % (i + 1)
		slip.transform = at * Transform3D(Basis(Vector3.BACK, deg_to_rad(spot.z)), Vector3(spot.x, spot.y, SURFACE_OFFSET))
		slip.add_child(_box("Sheet", "ph_notice_slip", SLIP_SIZE, SLIP_COLOR, base, Vector3.ZERO))
		slip.add_child(_box("Pin", "ph_notice_pin", PIN_SIZE, PIN_COLOR, base, Vector3(0, SLIP_SIZE.y * 0.5 - 0.025, SLIP_SIZE.z)))
		var word := Label3D.new()
		word.name = "Word"
		word.text = SLIP_WORD
		word.font_size = SLIP_FONT_SIZE
		word.pixel_size = PIXEL_SIZE
		word.modulate = INK
		word.outline_size = 0
		word.shaded = true
		word.double_sided = false
		word.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		word.position = Vector3(0, 0.01, SLIP_SIZE.z * 0.5 + 0.002)
		slip.add_child(word)
		slip.visible = false
		add_child(slip)
		slips.append(slip)


func _make_sheet() -> void:
	if sheet != null:
		return
	var marker := find_child(MARKER, true, false) as Node3D
	var at := _relative(marker) if marker != null else Transform3D(Basis.IDENTITY, Vector3(0, 1.25, 0.05))
	var base := load(PAINTED_MATERIAL) as ShaderMaterial
	sheet = Node3D.new()
	sheet.name = "LargeSheet"
	sheet.transform = at * Transform3D(Basis(Vector3.BACK, deg_to_rad(SHEET_SPOT.z)), Vector3(SHEET_SPOT.x, SHEET_SPOT.y, SURFACE_OFFSET * 1.5))
	sheet.add_child(_box("Sheet", "ph_notice_sheet", SHEET_SIZE, SHEET_COLOR, base, Vector3.ZERO))
	sheet.add_child(_box("Fold", "ph_notice_sheet_fold", Vector3(SHEET_SIZE.x, 0.006, 0.002), FOLD_COLOR, base,
			Vector3(0, 0.02, SHEET_SIZE.z * 0.5 + 0.001)))
	sheet.add_child(_box("Thread", "ph_notice_seal_thread", Vector3(0.006, SHEET_SIZE.y * 0.55, 0.003), SEAL_COLOR, base,
			Vector3(SHEET_SIZE.x * 0.3, -SHEET_SIZE.y * 0.2, SHEET_SIZE.z * 0.5 + 0.002)))
	sheet.add_child(_box("Seal", "ph_notice_seal", Vector3(0.03, 0.03, 0.008), SEAL_COLOR, base,
			Vector3(SHEET_SIZE.x * 0.3, -SHEET_SIZE.y * 0.42, SHEET_SIZE.z * 0.5 + 0.004)))
	sheet.add_child(_box("Pin", "ph_notice_pin", PIN_SIZE, PIN_COLOR, base, Vector3(0, SHEET_SIZE.y * 0.5 - 0.025, SHEET_SIZE.z)))
	# W3 QA-Fix A9-6 (qa_g9.md: the word hung wider than the sheet over its pin): two lines in a smaller hand, on the
	# sheet between the pin and the fold.
	var word := Label3D.new()
	word.name = "Word"
	word.text = SHEET_WORD.replace(" ", "\n")
	word.font_size = SHEET_FONT_SIZE
	word.pixel_size = PIXEL_SIZE
	word.line_spacing = -4.0
	word.modulate = INK
	word.outline_size = 0
	word.shaded = true
	word.double_sided = false
	word.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	word.position = Vector3(0, SHEET_WORD_Y, SHEET_SIZE.z * 0.5 + 0.002)
	sheet.add_child(word)
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


func _hill() -> Node:
	return _first(HILL_GROUP)


func _start_day() -> int:
	var cfg := Database.config(&"hill_requests_config") as HillRequestsConfig
	return cfg.start_day if cfg != null else HillRequestsConfig.new().start_day


func _relative(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _rating() -> StringName:
	var score := _first(&"cemetery_score")
	if score != null and score.has_method(&"rating"):
		return score.call(&"rating")
	var graveyard := _first(&"graveyard")
	if graveyard != null and graveyard.has_method(&"rating"):
		return graveyard.call(&"rating")
	return CemeteryRating.NEGLECTED


func _reputation_tier() -> StringName:
	var rep := _first(&"reputation")
	if rep != null and rep.has_method(&"tier"):
		return rep.call(&"tier")
	return ReputationRules.tier(GameState.get_stat(&"reputation"), null)


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _on_changed() -> void:
	refresh()
