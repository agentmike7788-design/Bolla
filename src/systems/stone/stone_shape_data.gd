class_name StoneShapeData
extends Resource
## One designed gravestone shape (docs/PHASE5_DESIGN.md §2.5): data/stone/shapes/<id>.tres.
## id = marker_id (EconomyConfig.marker_quality holds its points). No RecipeData, no item.

@export var id: StringName
@export var display_name: String = ""
@export var order: int = 0
## Material taken when the stone is carved.
@export var inputs: Dictionary[StringName, int] = {}
## Carving minutes of the bare shape (inscription / gilding / ornament add, StoneConfig).
@export var minutes: int = 50
## ph_prop_gravestone_<shape> with the markers inscription and ornament.
@export var model: PackedScene
@export var max_lines: int = 4
## Metres; Label3D width at the marker inscription.
@export var label_width: float = 0.5
