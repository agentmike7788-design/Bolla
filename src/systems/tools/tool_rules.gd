class_name ToolRules
extends RefCounted
## Tool tiers from the tool belt – docs/PHASE5_DESIGN.md §2.3, §3.4. Passive: the highest
## ItemData.tool_tier of a kind on the belt counts, there is no equipping. Tier 0 (old shovel,
## old hatchet) is always there and no item; the pickaxe has no tier 0 (block_reason says so).

const TEXT_NEEDED := "%s nötig"
const TEXT_NEEDED_FROM := "%s nötig – %s"


## Highest ItemData.tool_tier of `kind` on the belt, else 0. null inventory → 0.
static func tier(inv: Inventory, kind: StringName) -> int:
	if inv == null or kind == &"":
		return 0
	var best := 0
	for id: StringName in inv.tools():
		var item := _tool_item(id)
		if item != null and item.tool_kind == kind:
			best = maxi(best, item.tool_tier)
	return best


## "" when the belt holds `kind` at `min_tier` or better, else "Holzfälleraxt nötig – Esse" (with
## the source hint of the kind) or "Meisterhacke nötig" (tier 2: there is only one way – the forge).
## No kind or min_tier <= 0 → "" (tier 0 is always there).
static func block_reason(inv: Inventory, kind: StringName, min_tier: int, cfg: ToolConfig) -> String:
	if kind == &"" or min_tier <= 0 or tier(inv, kind) >= min_tier:
		return ""
	var name := tool_name(kind, min_tier, cfg)
	if name == "":
		name = cfg.labels.get(kind, String(kind)) if cfg != null else String(kind)
	if min_tier >= 2:
		return TEXT_NEEDED % name
	var hint: String = cfg.source_hint.get(kind, "") if cfg != null else ""
	return TEXT_NEEDED_FROM % [name, hint] if hint != "" else TEXT_NEEDED % name


## "Alte Schaufel", "Eisenschaufel", "Meisterhacke", … ("" if the tier has no tool, e.g. pickaxe 0).
## Tier > 0: display_name of the ItemData with this tool_kind and tool_tier (Database).
static func tool_name(kind: StringName, tier_value: int, cfg: ToolConfig) -> String:
	if tier_value <= 0:
		return cfg.base_names.get(kind, "") if cfg != null else ""
	for res: Resource in Database.items():
		var item := res as ItemData
		if item != null and item.category == ItemData.Category.TOOL and item.tool_kind == kind \
				and item.tool_tier == tier_value:
			return item.display_name
	return ""


## Minutes of `action` (ActionConfig.action_tools: dig/bury → shovel) for the player's belt.
## Actions without a tool, and tier 0 (factor 1.0), keep `base` unchanged.
static func action_minutes(actions: ActionConfig, action: StringName, base: int, inv: Inventory) -> int:
	if actions == null:
		return base
	var kind: StringName = actions.action_tools.get(action, &"")
	var t := tier(inv, kind) if kind != &"" else 0
	return actions.tool_minutes(base, t) if t > 0 else base


static func _tool_item(id: StringName) -> ItemData:
	if not Database.has_item(id):
		return null
	return Database.item(id) as ItemData
