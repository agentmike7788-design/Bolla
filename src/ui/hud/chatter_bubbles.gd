class_name ChatterBubbles
extends Node
## Speech bubbles of the encounters (docs/PHASE8_DESIGN.md §2.1.2, §7.5): on EventBus.chatter_line (ChatterRunner,
## Jakob's own remarks) a Label3D above the speaker's head like the remarks of Phase 7, the speaker's name small
## below it. One encounter at a time: a line of another encounter clears the bubbles; within one encounter the
## other speaker's last line stays a moment longer (two bubbles, a conversation), dimmed. The Npc of the
## gravekeeper's region is preferred. Purely visual – nothing is saved. Created by UIRoot.

const NPC_GROUP := &"npc"
const PLAYER_GROUP := &"player"
const BUBBLE_NAME := &"ChatterBubble"
const HEIGHT := 2.25
## The earlier line of an encounter stays this many times the line time.
const LINGER := 2.0
const DIM := 0.72

## npc_id → {bubble: Label3D, left: float}
var bubbles: Dictionary[StringName, Dictionary] = {}
var chatter_id: StringName = &""
var last_text: String = ""
var last_npc: StringName = &""


func _init() -> void:
	name = "ChatterBubbles"


func _ready() -> void:
	EventBus.chatter_line.connect(show_line)


func _exit_tree() -> void:
	if EventBus.chatter_line.is_connected(show_line):
		EventBus.chatter_line.disconnect(show_line)
	clear()


## A bubble over `npc_id` with `text`; a line of another encounter clears the others first.
func show_line(id: StringName, npc_id: StringName, text: String) -> void:
	if id != chatter_id:
		clear()
		chatter_id = id
	last_text = text
	last_npc = npc_id
	for other: StringName in bubbles:
		var b: Label3D = bubbles[other].bubble
		if is_instance_valid(b):
			b.modulate.a = DIM
	_remove(npc_id)
	var npc := find_npc(npc_id)
	if npc == null or text == "":
		return
	var bubble := Label3D.new()
	bubble.name = BUBBLE_NAME
	bubble.text = text
	bubble.position = Vector3(0.0, HEIGHT, 0.0)
	_style(bubble, 30, 520.0)
	# The text grows upwards from the bubble's anchor, the name sits just below it.
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var tag := Label3D.new()
	tag.name = &"Name"
	tag.text = Phase8Texts.person_name(npc_id)
	tag.position = Vector3(0.0, -0.03, 0.0)
	_style(tag, 18, 400.0)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tag.modulate = Color(0.8, 0.76, 0.66, 1.0)
	bubble.add_child(tag)
	npc.add_child(bubble)
	bubbles[npc_id] = {"bubble": bubble, "left": Phase8Texts.CHATTER_SECONDS * LINGER}


func clear() -> void:
	for id: StringName in bubbles.keys():
		_remove(id)
	bubbles.clear()
	chatter_id = &""


func is_showing() -> bool:
	for id: StringName in bubbles:
		if is_instance_valid(bubbles[id].bubble):
			return true
	return false


func count() -> int:
	var n := 0
	for id: StringName in bubbles:
		if is_instance_valid(bubbles[id].bubble):
			n += 1
	return n


func _process(delta: float) -> void:
	if bubbles.is_empty():
		return
	for id: StringName in bubbles.keys():
		var e: Dictionary = bubbles[id]
		e.left = float(e.left) - delta
		if float(e.left) <= 0.0:
			_remove(id)
	if bubbles.is_empty():
		chatter_id = &""


func _remove(npc_id: StringName) -> void:
	if not bubbles.has(npc_id):
		return
	var b: Variant = bubbles[npc_id].bubble
	if is_instance_valid(b):
		(b as Node).queue_free()
	bubbles.erase(npc_id)


static func _style(l: Label3D, font_size: int, width: float) -> void:
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color(0.95, 0.91, 0.82, 1.0)
	l.outline_modulate = Color(0.12, 0.09, 0.07, 0.9)
	l.font_size = font_size
	l.outline_size = 10 if font_size >= 24 else 7
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = width
	l.render_priority = 2
	l.outline_render_priority = 1


## The Npc with `npc_id` – the one in the gravekeeper's region first.
func find_npc(npc_id: StringName) -> Node3D:
	if not is_inside_tree():
		return null
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	var region := StringName(str(player.get(&"region_id"))) if player != null else &""
	var other: Node3D = null
	for node: Node in get_tree().get_nodes_in_group(NPC_GROUP):
		if not node is Node3D or StringName(str(node.get(&"npc_id"))) != npc_id:
			continue
		if region != &"" and StringName(str(node.get(&"region_id"))) == region:
			return node as Node3D
		if other == null:
			other = node as Node3D
	return other
