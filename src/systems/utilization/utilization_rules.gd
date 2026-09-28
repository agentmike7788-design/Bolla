class_name UtilizationRules
extends RefCounted
## Pure harvesting / selling rules (docs/PHASE4_DESIGN.md §2.6, §3.4). Harvesting hair / teeth is
## only possible once Ilse is known (flag trader_known), before dressing, once per kind and
## corpse, with her tool and – for hair – above the minimum freshness. effects() gathers the
## consequences of one harvest (grave quality, reputation, piety, ghost mood) from the owning
## configs for the panel's consequence line; the systems apply them themselves.

## block_reason: button invisible (trader not known yet).
const HIDDEN := "-"
## Phase-2 valuables in effects() (not a UtilizationConfig kind).
const KIND_VALUABLES := &"valuables"
const TEXT_DONE := "Schon genommen."
const TEXT_DRESSED := "Nach dem Einkleiden nicht mehr zugänglich."
const TEXT_NO_TOOL := "Werkzeug fehlt – Ilse Kranich hat es."
const TEXT_TOO_OLD := "Das ist nicht mehr möglich."
const TEXT_NO_ROOM := "Kein Platz im Inventar."


## "" = possible; HIDDEN = no button (trader not known, unknown kind, no corpse / buried);
## otherwise the dimmed reason, in this order: already taken, dressed, tool missing, below the
## minimum freshness (low_freshness_text, "Das Haar ist zu brüchig."), no room for the item.
static func block_reason(record: CorpseRecord, kind: StringName, inv: Inventory, cfg: UtilizationConfig, known: bool) -> String:
	if not known or record == null or record.location == CorpseRecord.LOCATION_BURIED:
		return HIDDEN
	var entry := _cfg(cfg).kind(kind)
	if entry.is_empty():
		return HIDDEN
	if record.is_harvested(kind):
		return TEXT_DONE
	if record.is_dressed() or record.shrouded:
		return TEXT_DRESSED
	var tool := StringName(str(entry.get("tool", "")))
	if tool != &"" and (inv == null or not inv.has(tool)):
		return TEXT_NO_TOOL
	var min_fresh := float(entry.get("min_freshness", 0.0))
	if min_fresh > 0.0 and record.freshness < min_fresh:
		var text := str(entry.get("low_freshness_text", ""))
		return text if text != "" else TEXT_TOO_OLD
	var item := StringName(str(entry.get("item", "")))
	if item != &"" and inv != null and not inv.can_add(item, 1):
		return TEXT_NO_ROOM
	return ""


## Σ amount × (sell_prices[item] + bonus_per_item) over `items` {item_id: amount}; items Ilse
## does not buy and amounts ≤ 0 count 0.
static func sale_value(items: Dictionary, bonus_per_item: int, cfg: UtilizationConfig) -> int:
	var prices := _cfg(cfg).sell_prices
	var total := 0
	for id: Variant in items:
		var key := StringName(str(id))
		var amount := int(items[id])
		if amount <= 0 or not prices.has(key):
			continue
		total += amount * maxi(int(prices[key]) + bonus_per_item, 0)
	return total


## Consequences of one harvest of `kind` (hair / teeth / valuables) for the panel line:
## {item, price, quality, reputation, piety, mood} – quality from EconomyConfig.harvest_malus
## (valuables: valuables_taken_malus), reputation from ReputationConfig.event_points
## (valuables: EconomyConfig.valuables_reputation), piety from PietyConfig.events, mood from
## GhostConfig.robbed_mood (valuables: 0 – they act through the quality). {} for unknown kinds.
## null configs = the data/config files.
static func effects(kind: StringName, cfg: UtilizationConfig = null, economy: EconomyConfig = null,
		reputation: ReputationConfig = null, piety: PietyConfig = null, ghosts: GhostConfig = null) -> Dictionary:
	var eco := EconomyConfig.resolve(economy)
	var pie := PietyRules._cfg(piety)
	if kind == KIND_VALUABLES:
		return {"item": &"", "price": 0, "quality": eco.valuables_taken_malus, "reputation": eco.valuables_reputation,
				"piety": int(pie.events.get(&"valuables_taken", 0)), "mood": 0}
	var util := _cfg(cfg)
	var entry := util.kind(kind)
	if entry.is_empty():
		return {}
	var rep := reputation if reputation != null else ReputationRules._cfg(null)
	var ghost := ghosts if ghosts != null else _ghost_config()
	var item := StringName(str(entry.get("item", "")))
	return {
		"item": item,
		"price": int(util.sell_prices.get(item, 0)),
		"quality": int(eco.harvest_malus.get(kind, 0)),
		"reputation": int(rep.event_points.get(StringName(str(entry.get("reputation_event", ""))), 0)),
		"piety": int(pie.events.get(StringName(str(entry.get("piety_event", ""))), 0)),
		"mood": ghost.robbed_mood,
	}


static func _cfg(cfg: UtilizationConfig) -> UtilizationConfig:
	if cfg != null:
		return cfg
	var real := Database.config(&"utilization_config") as UtilizationConfig
	return real if real != null else UtilizationConfig.new()


static func _ghost_config() -> GhostConfig:
	var real := Database.config(&"ghost_config") as GhostConfig
	return real if real != null else GhostConfig.new()
