class_name OrnamentData
extends Resource
## One relief ornament (docs/PHASE5_DESIGN.md §2.5): data/stone/ornaments/<id>.tres.
## Placed at the marker ornament of the shape model.

@export var id: StringName
@export var order: int = 0
@export var display_name: String = ""
@export var tooltip: String = ""
@export var points: int = 1
@export var minutes: int = 25
@export var model: PackedScene
