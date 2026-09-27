class_name DialogueChoice
extends Resource
## One answer option. Conditions/actions use the string mini-language in docs/VERTICAL_SLICE_DESIGN.md §3.4.

@export var text: String = ""
## Next node id; &"" ends the dialogue.
@export var next: StringName = &""
@export var conditions: Array[String] = []
@export var actions: Array[String] = []
