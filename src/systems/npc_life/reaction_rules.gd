class_name ReactionRules
extends RefCounted
## STUB (P1) – the remark precedence of Phase 8 (docs/PHASE8_DESIGN.md §2.1.3, §3.4):
## event (NpcLife.reaction_for, ≤ 2 days) > friend > piety > reputation (Phase 7 below).
## W1 (P1) fills the bodies; the signatures are the contract.


## The VillagerData.remarks key to say (&"" = none).
static func remark_key(_npc_id: StringName, _life: NpcLife, _rel: Relationships) -> StringName:
	return &""
