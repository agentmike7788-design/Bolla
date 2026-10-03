class_name TeachingData
extends Resource
## A teaching (Lehrsatz) of the anatomy (docs/PHASE7_DESIGN.md §2.6.5, §3.4): data/anatomy/teachings/<id>.tres.

@export var id: StringName
## The organ whose lecture / expertise teaches it.
@export var organ: StringName
@export var title: String
@export_multiline var text: String
