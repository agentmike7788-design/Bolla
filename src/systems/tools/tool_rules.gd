class_name ToolRules
extends RefCounted
## STUB (P3) – docs/PHASE5_DESIGN.md §2.3, §3.4: tool tiers from the tool belt (passive: the
## highest ItemData.tool_tier of a kind counts, no equipping). Until P3 delivers the belt, tier()
## is 0 and Inventory keeps its old behaviour. W1 (P3) fills the bodies.


## Highest ItemData.tool_tier of `kind` on the belt, else 0.
static func tier(_inv: Inventory, _kind: StringName) -> int:
	return 0


## "" | "Holzfälleraxt nötig – Esse" · "Meisterhacke nötig"
static func block_reason(_inv: Inventory, _kind: StringName, _min_tier: int, _cfg: ToolConfig) -> String:
	return ""


## "Alte Schaufel", "Eisenschaufel", …
static func tool_name(kind: StringName, tier_value: int, cfg: ToolConfig) -> String:
	if cfg != null and tier_value <= 0:
		return cfg.base_names.get(kind, "")
	return ""
