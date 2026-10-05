class_name ApprenticeTaskData
extends Resource
## One task of the apprentice (docs/PHASE8_DESIGN.md §2.5.2, §3.4): data/apprentice/tasks/<id>.tres.
## Reusable by Phase 14 (ApprenticePlanner); no Phase-8 system knows Phase 14.

## rake | weed | water | candle.
@export var id: StringName
@export var label: String
## Minutes per place by level [Ungelernt (cannot), Angelernt, Geübt].
@export var minutes: PackedInt32Array = [0, 15, 10]
## Tool from his box (apprentice_rake, watering_can; &"" = hands) / item used up per place (grave_candle).
@export var tool_item: StringName = &""
@export var consumes: StringName = &""
## leaves | weeds | flowers | candle.
@export var spot_kind: StringName
## Not before this minute of day (candle 900).
@export var from_minute: int = 0
@export var animation: StringName
## neighbour_leaves | flowers_torn | flowers_trodden | candle_broken.
@export var mistake_kind: StringName
@export var mistake_text: String
## Sort order (Database.apprentice_tasks: rake, weed, water, candle) – W0 addition, §3.5.
@export var order: int = 0
