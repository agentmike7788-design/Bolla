class_name OldGraveData
extends Resource
## One of the old graves old_01…08 in the Alter Hof (docs/PHASE6_DESIGN.md §2.3):
## data/ossuary/old_graves/<grave_id>.tres, Database.old_grave(grave_id) / old_graves().

@export var grave_id: String
@export var display_name: String
@export var born_year: int
@export var died_year: int
## Note when the bones are reinterred ("" for the graves still in their rest period).
@export var reinter_line: String = ""
## The same old stone (leans against the ossuary wall after the reinterment).
@export var stone_model: PackedScene
