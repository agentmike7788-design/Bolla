class_name CollectionSetData
extends Resource
## A set of the specimen collection (docs/PHASE7_DESIGN.md §2.7, §3.4): data/anatomy/sets/<id>.tres.
## Rewarded once when all its organs' compartments are filled at the same time.

@export var id: StringName
@export var title: String
@export var organs: Array[StringName] = []
## At least one of the pieces must be a display specimen (set_complete).
@export var needs_display: bool = false
## Quast pays once („Die Universität zahlt für die Aufstellung.").
@export var reward_coins: int = 0
## + Ansehen bei der Universität.
@export var standing: int = 1
## Flag set on completion (set_complete: university_letter).
@export var sets_flag: StringName = &""
