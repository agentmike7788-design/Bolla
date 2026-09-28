class_name GatherNodeData
extends Resource
## One kind of regrowing gather node (docs/PHASE5_DESIGN.md §2.2, §3.4): data/gather/<kind>.tres.
## The state (charges, last_taken_day, last_refresh_day) lives in GatherManager.

@export var id: StringName
@export var display_name: String = ""
## Prompt verb: "Erle fällen" → "[E] Erle fällen (50 Min)".
@export var verb: String = ""
@export var item_id: StringName
@export var yield_amount: int = 1
@export var charges_max: int = 1
## A node with charges < charges_max is full again at day_started when
## day − last_taken_day ≥ regrow_days.
@export var regrow_days: int = 1
## Base minutes (tier factor via ActionConfig.tool_minutes when tool_kind is set).
@export var minutes: int = 10
## &"" = no tool needed.
@export var tool_kind: StringName = &""
@export var min_tier: int = 0
## Extra yield with tool tier 2.
@export var tier2_bonus: int = 0
@export var animation: StringName = &"interact"
@export var requires_flag: StringName = &"workshop_open"
@export var model_full: PackedScene
@export var model_empty: PackedScene
@export var model_regrow: PackedScene
## alder: [2, 5] → stump < 2 days, sapling < 5 days, tree from day 5.
@export var regrow_stage_days: PackedInt32Array = []
