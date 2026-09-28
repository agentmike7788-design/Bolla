class_name InscriptionData
extends Resource
## One inscription template (docs/PHASE5_DESIGN.md §2.5): data/stone/inscriptions/<id>.tres.
## Placeholders {name} {born} {died} {age}; the text is fixed when the stone is carved.

@export var id: StringName
@export var order: int = 0
@export var title: String = ""
@export var lines: PackedStringArray = []
## "Passende Inschrift": cause ids, age range (-1 = no bound) or story ids that fit.
@export var fits_causes: Array[StringName] = []
@export var fits_min_age: int = -1
@export var fits_max_age: int = -1
@export var fits_story: Array[StringName] = []
