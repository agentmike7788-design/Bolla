class_name StoneConfig
extends Resource
## Stone design surcharges, inscription calendar and colours (docs/PHASE5_DESIGN.md §2.5, §8,
## §14.3): data/config/stone_config.tres.

@export var inscription_points: int = 1
@export var fitting_points: int = 1
@export var gilded_points: int = 1
@export var ink_item: StringName = &"ink"
@export var ink_amount: int = 1
@export var inscription_minutes: int = 20
@export var gold_item: StringName = &"gold_leaf"
@export var gilding_minutes: int = 10
## "[E] Gestalteten Stein setzen (20 Min)"
@export var set_minutes: int = 20
## Game day 1 = 3. Gilbhart 1834 (old German month names, real month lengths; §14.3).
@export var calendar: Dictionary = {"start_year": 1834, "start_month": 10, "start_day": 3,
		"month_names": ["Hartung", "Hornung", "Lenzing", "Ostermond", "Wonnemond", "Brachet", "Heuet", "Ernting", "Scheiding", "Gilbhart", "Nebelung", "Julmond"],
		"month_days": [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]}
@export var ink_color: Color = Color("2A1F18")
@export var gold_color: Color = Color("C9A24A")
