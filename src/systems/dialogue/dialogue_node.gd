class_name DialogueNode
extends Resource
## One dialogue line with answers. If conditions fail the node is skipped to fallback_next.

@export var id: StringName
@export_multiline var text: String = ""
@export var choices: Array[DialogueChoice] = []
@export var conditions: Array[String] = []
@export var fallback_next: StringName = &""
## Executed when the node is entered.
@export var actions: Array[String] = []
