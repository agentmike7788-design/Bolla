class_name MarketWareData
extends Resource
## A ware the gravekeeper sells at his own stand (docs/PHASE10_DESIGN.md §2.7.5, §3.4): data/market/wares/<item>.tres
## (P4). Base value, demand per market (× state × tag × reputation × piety), the customers' lines (buyer → line).

@export var item: StringName
@export var group: StringName
@export var value: float = 1.0
@export var demand: int = 1
## Buyer (npc id) → line („Für den Feldrain. Und für später.").
@export var lines: Dictionary[StringName, String] = {}
