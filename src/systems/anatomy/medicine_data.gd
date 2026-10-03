class_name MedicineData
extends Resource
## A medicine from a specimen at the pult (docs/PHASE7_DESIGN.md §2.7, §3.4): data/anatomy/medicines/<id>.tres.

@export var id: StringName
## One of these organs as a specimen in a jar is consumed.
@export var organs: Array[StringName] = []
@export var min_clarity: float = 0.45
## Further ingredients.
@export var inputs: Dictionary[StringName, int] = {}
@export var minutes: int = 30
## Item id of the result and its amount.
@export var output: StringName
@export var amount: int = 1
