class_name BuildingLevelData
extends Resource
## One level (1…3) of a building (docs/PHASE6_DESIGN.md §2.1, §3.4) – part of BuildingData.levels.
## Built on top of the previous level; consumed atomically at the end of the build (items + coins).

@export var level: int = 1
@export var title: String = ""
## Material {item_id: amount} (coins separately).
@export var inputs: Dictionary[StringName, int] = {}
@export var coins: int = 0
## Build time in game minutes (TimedAction, not cancellable).
@export var minutes: int = 180
## What the coins pay for („Kalk und Mörtel aus Hollerbrück").
@export var coin_part_label: String = ""
## Panel description.
@export_multiline var text: String = ""
## "Neu:" list of the panel („2 Kühlnischen", „Beinhaus: 3 Plätze" …).
@export var adds: PackedStringArray = []
## Outdoor model of this level (null until P5 delivers it: the builder uses a grey box).
@export var model: PackedScene
