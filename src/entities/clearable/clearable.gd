class_name ClearableObstacle
extends Node3D
## Obstacle of a new section (docs/PHASE3_DESIGN.md §2.1, §3.4): bramble, rubble, stump, hedge,
## fence_gap. Group &"clearable"; Interactable priority 8. Prompt e.g.
## "[E] Brombeergestrüpp roden (30 Min) → +1 Holz"; clearing is a cancellable TimedAction with
## free hands that ends in ExpansionManager.clear. State only from ExpansionManager (not saved).
## Visuals: "Model" (ClearableData.model, or a builder-made child of that name) while standing;
## a fence_gap shows "Repaired" (ClearableData.repaired_model) once repaired. Optional child
## "Collision" (StaticBody3D) is switched off when cleared, "RepairedCollision" on.
## Phase 5 (docs/PHASE5_DESIGN.md §2.3): ClearableData.tool_kind / min_tier – the player's tier
## (Player.tool_tier) gates the obstacle (boulder: pickaxe 1, dimmed tool reason from ToolRules)
## and sets the minutes (ActionConfig.tool_minutes via ExpansionManager.clear_minutes).

const GROUP := &"clearable"
const EXPANSION_GROUP := &"expansion"
const MODEL_NAME := "Model"
const REPAIRED_NAME := "Repaired"
const PROMPT := "[E] %s %s (%d Min)"
const PROMPT_YIELD := " → %s"
const PROMPT_COST := " · %s"
const PROMPT_MISSING := "Fehlt: %s"
const PROMPT_NO_ROOM := "Kein Platz im Inventar"
const LABEL := "%s %s"
const TEXT_REWARD := "+%s"
const TEXT_FAILED := "Das geht hier gerade nicht."

@export var obstacle_id: String = ""
@export var section_id: StringName = &""
## ClearableData id (data/clearables/<kind>.tres).
@export var kind: StringName = &""
## Local XZ rect: build block + grass mask while not cleared.
@export var footprint: Rect2 = Rect2(-1, -1, 2, 2)

var cleared: bool = false

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _init() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	var data := _data()
	if data != null:
		if data.model != null and get_node_or_null(MODEL_NAME) == null:
			_add_model(data.model, MODEL_NAME)
		if data.repaired_model != null and get_node_or_null(REPAIRED_NAME) == null:
			_add_model(data.repaired_model, REPAIRED_NAME)
	_apply_visual()


## footprint in world XZ (axis-aligned bounds of the rotated local rect).
func world_rect() -> Rect2:
	var xform := global_transform if is_inside_tree() else transform
	var corners: Array[Vector2] = [footprint.position, Vector2(footprint.end.x, footprint.position.y),
			footprint.end, Vector2(footprint.position.x, footprint.end.y)]
	var out := Rect2()
	for i: int in corners.size():
		var p := xform * Vector3(corners[i].x, 0.0, corners[i].y)
		var flat := Vector2(p.x, p.z)
		out = Rect2(flat, Vector2.ZERO) if i == 0 else out.expand(flat)
	return out


## Model / collision; a fence_gap then shows repaired_model.
func apply_cleared(is_cleared: bool) -> void:
	cleared = is_cleared
	_apply_visual()


func can_interact(player: Player) -> bool:
	if cleared or player == null or player.is_busy() or _is_carrying(player):
		return false
	var manager := _manager()
	return manager != null and manager.can_clear(obstacle_id, player.inventory, tool_tier(player))


func get_interaction_prompt(player: Player) -> String:
	var manager := _manager()
	var data := _data()
	if cleared or manager == null or data == null:
		return ""
	var reason := manager.block_reason(section_id)
	if reason != "":
		return reason
	if player != null and _is_carrying(player):
		return Player.TEXT_HANDS_FULL
	var inv := player.inventory if player != null else null
	var tier := tool_tier(player)
	var tool_reason := manager.tool_block_reason(obstacle_id, inv, tier)
	if tool_reason != "":
		return tool_reason
	var missing := manager.missing_cost(obstacle_id, inv)
	if not missing.is_empty():
		return PROMPT_MISSING % _amounts(missing)
	if inv != null and not manager.yield_fits(obstacle_id, inv):
		return PROMPT_NO_ROOM
	var text := PROMPT % [data.display_name, data.verb, manager.clear_minutes(obstacle_id, inv, tier)]
	if not data.yield_items.is_empty():
		text += PROMPT_YIELD % _amounts(data.yield_items, "+")
	elif not data.cost.is_empty():
		text += PROMPT_COST % _amounts(data.cost)
	return text


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var data := _data()
	var tier := tool_tier(player)
	var minutes := _manager().clear_minutes(obstacle_id, player.inventory, tier)
	player.start_timed_action(LABEL % [data.display_name, data.verb], minutes,
			_finish.bind(player.inventory, tier), true, data.animation)


## Player.tool_tier of this obstacle's tool kind (0 without a tool kind / player).
func tool_tier(player: Player) -> int:
	var data := _data()
	if player == null or data == null or data.tool_kind == &"":
		return 0
	return player.tool_tier(data.tool_kind)


func _finish(inv: Inventory, tier: int = -1) -> void:
	var manager := _manager()
	var data := _data()
	if manager == null or data == null or not manager.clear(obstacle_id, inv, tier):
		EventBus.notification_requested.emit(TEXT_FAILED, &"warning")
		return
	if not data.yield_items.is_empty():
		EventBus.notification_requested.emit(TEXT_REWARD % _amounts(data.yield_items), &"reward")


func _apply_visual() -> void:
	var model := get_node_or_null(MODEL_NAME) as Node3D
	var repaired := get_node_or_null(REPAIRED_NAME) as Node3D
	if model != null:
		model.visible = not cleared
	if repaired != null:
		repaired.visible = cleared
	_set_body(get_node_or_null(^"Collision"), not cleared)
	_set_body(get_node_or_null(^"RepairedCollision"), cleared)
	if interactable != null:
		interactable.enabled = not cleared
		interactable.set_deferred(&"monitorable", not cleared)


static func _set_body(body: Node, active: bool) -> void:
	if body == null:
		return
	for shape: Node in body.get_children():
		if shape is CollisionShape3D:
			shape.set_deferred(&"disabled", not active)


func _add_model(scene: PackedScene, node_name: String) -> void:
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return
	inst.name = node_name
	add_child(inst)


## "2 Holz, 1 Eisenbeschlag" (prefix "+" → "+1 Holz").
static func _amounts(items: Dictionary, prefix: String = "") -> String:
	var parts: PackedStringArray = []
	for id: Variant in items:
		parts.append("%s%d %s" % [prefix, int(items[id]), _item_name(StringName(id))])
	return ", ".join(parts)


static func _item_name(id: StringName) -> String:
	var item := Database.item(id) as ItemData if Database.has_item(id) else null
	return item.display_name if item != null and item.display_name != "" else String(id)


func _data() -> ClearableData:
	var manager := _manager()
	if manager != null and manager.obstacle(obstacle_id) == self:
		return manager.data_of(obstacle_id)
	if manager != null and manager.clearable_data.has(kind):
		return manager.clearable_data[kind]
	return Database.clearable(kind) as ClearableData if kind != &"" else null


func _manager() -> ExpansionManager:
	return get_tree().get_first_node_in_group(EXPANSION_GROUP) as ExpansionManager if is_inside_tree() else null


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)
