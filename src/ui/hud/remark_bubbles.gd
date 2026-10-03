class_name RemarkBubbles
extends Node
## Speech bubbles of the villagers' remarks (docs/PHASE7_DESIGN.md §2.4, §7): on EventBus.villager_remarked
## (Relationships.remark, once a day and person) a Label3D above the person's head like the ghosts'
## bubbles, for 4 s, one at a time (a new remark replaces the old one). The village Npc of that npc_id is
## preferred. Purely visual – the bubble is a child of the Npc and is removed again; nothing is saved.
## Created by UIRoot.

const NPC_GROUP := &"npc"
const BUBBLE_NAME := &"RemarkBubble"
const HEIGHT := 2.25
const REGION_VILLAGE := &"village"

## The bubble shown now (null = none) and its speaker.
var bubble: Label3D
var speaker: Node3D
var text: String = ""
var _left: float = 0.0


func _init() -> void:
	name = "RemarkBubbles"


func _ready() -> void:
	EventBus.villager_remarked.connect(show_remark)


func _exit_tree() -> void:
	if EventBus.villager_remarked.is_connected(show_remark):
		EventBus.villager_remarked.disconnect(show_remark)
	clear()


## A bubble over `npc_id` with `line` (no-op without its Npc in the tree).
func show_remark(npc_id: StringName, line: String) -> void:
	clear()
	text = line
	var npc := find_npc(npc_id)
	if npc == null or line == "":
		return
	speaker = npc
	bubble = Label3D.new()
	bubble.name = BUBBLE_NAME
	bubble.text = line
	bubble.position = Vector3(0.0, HEIGHT, 0.0)
	bubble.pixel_size = 0.004
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.modulate = Color(0.95, 0.91, 0.82, 1.0)
	bubble.outline_modulate = Color(0.12, 0.09, 0.07, 0.9)
	bubble.font_size = 30
	bubble.outline_size = 10
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.width = 520.0
	bubble.render_priority = 2
	bubble.outline_render_priority = 1
	npc.add_child(bubble)
	_left = Phase7Texts.REMARK_SECONDS


func clear() -> void:
	if is_instance_valid(bubble):
		bubble.queue_free()
	bubble = null
	speaker = null
	_left = 0.0


func is_showing() -> bool:
	return is_instance_valid(bubble)


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		clear()


## The Npc with `npc_id` – the village one first.
func find_npc(npc_id: StringName) -> Node3D:
	if not is_inside_tree():
		return null
	var other: Node3D = null
	for node: Node in get_tree().get_nodes_in_group(NPC_GROUP):
		if not node is Node3D or StringName(str(node.get(&"npc_id"))) != npc_id:
			continue
		if StringName(str(node.get(&"region_id"))) == REGION_VILLAGE:
			return node as Node3D
		if other == null:
			other = node as Node3D
	return other
