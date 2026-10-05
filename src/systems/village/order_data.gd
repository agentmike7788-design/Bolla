class_name OrderData
extends Resource
## One order of a villager or the parish board (docs/PHASE7_DESIGN.md §2.5, §3.4): data/orders/<id>.tres.

## Phase 8 (docs/PHASE8_DESIGN.md §2.4, §3.4) appends meet (conditions {npc, place, window, times}) and task
## (conditions {action_id, place}).
const KINDS: Array[StringName] = [&"deliver", &"bury", &"stone", &"tend", &"donate", &"section", &"meet", &"task"]
const CATEGORY_FRIEND := &"friend"

@export var id: StringName
## npc_id of the giver; &"council" = the parish board („die Gemeinde").
@export var giver: StringName
## Who takes a delivery (&"" = the giver).
@export var recipient: StringName = &""
@export var kind: StringName
@export var title: String
@export_multiline var request_text: String
@export_multiline var thanks_text: String
## deliver / donate: items handed over.
@export var items: Dictionary[StringName, int] = {}
## donate: coins handed over.
@export var coins: int = 0
## grave_id | story_id | section_id | "next_delivery".
@export var target: String = ""
## dress, service, prepared, unharvested, section, stone_shape, ornament, gilded, inscription,
## mornings, min_clarity, organ (all optional).
@export var conditions: Dictionary = {}
## Game days from acceptance (0 = no limit); checked at 06:00.
@export var days_limit: int = 0
@export var requires_flag: StringName = &""
@export var requires_orders: Array[StringName] = []
## Relationship tier with the giver needed for the offer (&"" = any).
@export var requires_tier: StringName = &""
@export var reward_coins: int = 0
@export var reward_rel: int = 0
@export var reward_rep: int = 0
## Extra relationship changes on completion / on failure ({npc_id: delta}).
@export var extra_rel: Dictionary[StringName, int] = {}
@export var fail_rel: Dictionary[StringName, int] = {}
## true = an offer of the parish board (pool, cooldown_days).
@export var board: bool = false
@export var cooldown_days: int = 3
## Sort order (Database.orders).
@export var order: int = 0
## Flag set on acceptance (o_fenner_linden: linden_granted).
@export var accept_flag: StringName = &""
# Phase 8 (docs/PHASE8_DESIGN.md §2.4, §3.4): &"" = a Phase-7 order | &"friend" (friendship steps and
# return favours: their own limit OrdersConfig.max_active_friend).
@export var category: StringName = &""
