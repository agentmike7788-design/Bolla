class_name StrangerCaseView
extends Node
## Phase 9 W-Welt (docs/PHASE9_DESIGN.md §2.5.2 K4, W1-Anschlüsse 7 „Brenneisens Kindmesh case bei K4 per Code
## ausblenden"): Brenneisen's figures carry the brown case (child mesh case at the bone tool) only while it is his – it
## stands forgotten in the Holderkrug, the gravekeeper carries it, or Fenner keeps it (Stranger.case_holder() inn / player /
## fenner): then the tool attachment of every stranger figure (graveyard and village) is hidden, so the mesh the Npc
## shows by its clips stays invisible. Display only; refreshed on the stranger's events, loading and the world's start.

const STRANGER_GROUP := &"stranger"
const NPC_GROUP := &"npc"
const NPC_ID := &"stranger"
## The case is away from him with these holders (Stranger.CASE_HOLDERS without &"stranger").
const AWAY: Array[StringName] = [&"inn", &"player", &"fenner"]
const ATTACHMENT := "tool"


func _ready() -> void:
	EventBus.stranger_event.connect(_on_event.unbind(2))
	EventBus.game_loaded.connect(_on_event.unbind(1))
	EventBus.world_ready.connect(_on_event.unbind(1))
	refresh.call_deferred()


## The case is not with Brenneisen now.
func case_away() -> bool:
	var stranger := get_tree().get_first_node_in_group(STRANGER_GROUP) if is_inside_tree() else null
	if stranger == null or not stranger.has_method(&"case_holder"):
		return false
	return StringName(str(stranger.call(&"case_holder"))) in AWAY


func refresh() -> void:
	if not is_inside_tree():
		return
	var away := case_away()
	for node: Node in get_tree().get_nodes_in_group(NPC_GROUP):
		if node.get(&"npc_id") != NPC_ID:
			continue
		var model := node.get_node_or_null(^"Model")
		var tool := model.find_child(ATTACHMENT, true, false) as Node3D if model != null else null
		if tool != null:
			tool.visible = not away


func _on_event() -> void:
	refresh()
