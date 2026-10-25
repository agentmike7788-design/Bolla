class_name MarketConfig
extends Resource
## The weekly market on the Anger (docs/PHASE10_DESIGN.md §2.7, §3.4): data/config/market_config.tres (P4 owns the data).
## Saturday (weekday 5) from open_flag (village_open) on, 08:00–12:30; stands visible 06:30–13:30; the notice at the
## village board from Thursday 07:44; the own stand from stall_flag on (stall fee 1, 6 slots, ticks of 30 minutes).
## The market state of every ware group (scarce / normal / glut) is deterministic: hash([week, group]) with
## state_weights, then the rules in steps (season_rules, the mourning week, oversold, Hanne's day).

@export var open_flag: StringName = &"village_open"
@export var weekday: int = 5
## Market window 08:00–12:30; the own stand can be set up from 07:30.
@export var window: Vector2i = Vector2i(480, 750)
@export var setup_from: int = 450
## Stands (child meshes) visible 06:30–13:30; the market notice from Thursday 07:44.
@export var stalls_visible: Vector2i = Vector2i(390, 810)
@export var notice_weekday: int = 3
@export var notice_minute: int = 464
## §2.7.5 the own stand.
@export var stall_flag: StringName = &"market_stall_granted"
@export var stall_fee: int = 1
@export var stall_slots: int = 6
@export var tick_minutes: int = 30
@export var setup_minutes: int = 10
@export var takedown_minutes: int = 5
## Ware group → items (§2.7.3; §3.4 class default {}, the §2.7.3 table is in the .tres – W0).
@export var groups: Dictionary[StringName, PackedStringArray] = {}
## Market states: price and demand factors.
@export var states: Dictionary[StringName, Dictionary] = {&"scarce": {"price": 1.3, "demand": 1.5}, &"normal": {"price": 1.0, "demand": 1.0}, &"glut": {"price": 0.75, "demand": 0.6}}
## Base state weights scarce / normal / glut.
@export var state_weights: PackedFloat32Array = [0.25, 0.5, 0.25]
## Price tags of the own stand: cheap / fair / dear.
@export var tags: Dictionary[StringName, Dictionary] = {&"cheap": {"price": 0.8, "demand": 1.4}, &"fair": {"price": 1.0, "demand": 1.0}, &"dear": {"price": 1.25, "demand": 0.6}}
## {months: PackedInt32Array, group, step} (frost: Julmond, Hartung, Hornung → wood_iron +1; in the .tres – W0).
@export var season_rules: Array[Dictionary] = []
## Mourning week: ≥ 3 deliveries / deaths in the 7 days before → these groups +1.
@export var mourning_deaths: int = 3
@export var mourning_groups: Array[StringName] = [&"candles", &"grave_goods"]
## Oversold: ≥ 6 pieces of a group sold at the last market → that group −1; Hanne's day in the 6 days before → pantry −1.
@export var oversold_threshold: int = 6
@export var peddler_group: StringName = &"pantry"
## Demand factors by reputation tier / piety tier (§2.7.5; in the .tres – W0).
@export var rep_demand: Dictionary[StringName, float] = {}
@export var piety_demand: Dictionary[StringName, float] = {}
## Unsold goods that do not fit into the inventory at 12:30.
@export var leftover_chest: StringName = &"hut_chest"
