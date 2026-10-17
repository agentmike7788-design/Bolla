class_name LightEntryData
extends Resource
## One entry of the back of Lorenz' ledger (docs/PHASE9_DESIGN.md §2.2.1, §3.4) – a sub-resource of
## LightListData: a date, an initial, the ink; the dead under it and the witness of the light.

const INK_OLD := &"old"
const INK_FRESH := &"fresh"

@export var id: StringName
## „D." · „Q." · „W." · „H." · „O." · „S."
@export var initial: String
## &"old" | &"fresh"
@export var ink: StringName = &"fresh"
## StoryCorpseData id of the dead under the date (&"" = nobody yet – e_open).
@export var story_id: StringName = &""
## A fixed date text (e_dorn: „2. Julmond 1833"); "" = computed by LightRules.
@export var fixed_text: String = ""
## The open entry (S. – p9_open_day − 12).
@export var open: bool = false
## Villager (npc_id) who saw the light, and the clue of the witness.
@export var witness_npc: StringName
@export var witness_clue: StringName
