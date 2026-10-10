class_name ReactionRules
extends RefCounted
## The remark precedence of Phase 8 (docs/PHASE8_DESIGN.md §2.1.3, §3.4): event (NpcLife.valid_events –
## newest first, ≤ NpcLifeConfig.reactions days, only from p8_open; key event_<event>) > friend > piety >
## specimens > reputation (the Phase-7 order of Relationships.remark_keys below). A key counts only when the
## villager has lines for it (VillagerData.remarks) – who reacts is the data.

const PREFIX_EVENT := "event_"


## The VillagerData.remarks key to say (&"" = none).
static func remark_key(npc_id: StringName, life: NpcLife, rel: Relationships) -> StringName:
	var data: VillagerData = rel.villager(npc_id) if rel != null else Database.villager(npc_id) as VillagerData
	if data == null:
		return &""
	for key: StringName in keys(npc_id, life, rel):
		var pool: PackedStringArray = data.remarks.get(key, PackedStringArray())
		if not pool.is_empty():
			return key
	return &""


## Every candidate key in precedence order (event keys first, then Relationships.remark_keys).
static func keys(npc_id: StringName, life: NpcLife, rel: Relationships) -> Array[StringName]:
	var out: Array[StringName] = []
	if life != null:
		for ev: StringName in life.valid_events(npc_id):
			out.append(StringName(PREFIX_EVENT + String(ev)))
	if rel != null:
		out.append_array(rel.remark_keys(npc_id))
	return out
