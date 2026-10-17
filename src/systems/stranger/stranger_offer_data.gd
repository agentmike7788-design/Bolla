class_name StrangerOfferData
extends Resource
## One thing Brenneisen wants to buy (docs/PHASE9_DESIGN.md §2.5.2 K2, §3.4): data/stranger/offers/<id>.tres –
## soil from a fresh grave, the register extract, specimens. Never a corpse.

@export var id: StringName
@export var label: String
@export var item: StringName
@export var price: int
@export var conditions: PackedStringArray = []
## Consequences (piety, talk, flags) – DialogueActions syntax.
@export var actions: PackedStringArray = []
## Line in the panel („Lenz wird es erfahren." – without a number).
@export var note: String
