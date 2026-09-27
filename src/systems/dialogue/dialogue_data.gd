class_name DialogueData
extends Resource
## A dialogue (data/dialogue/<id>.tres).

@export var id: StringName
@export var speaker_name: String = ""
@export var start_node: StringName
@export var nodes: Array[DialogueNode] = []


func get_node_by_id(node_id: StringName) -> DialogueNode:
	for n: DialogueNode in nodes:
		if n.id == node_id:
			return n
	return null
