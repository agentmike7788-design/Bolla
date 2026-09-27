class_name UtilizationConfig
extends Resource
## Harvesting hair / teeth (docs/PHASE4_DESIGN.md §2.6): data/config/utilization_config.tres.

const KIND_KEYS: PackedStringArray = ["label", "verb", "minutes", "tool", "item", "min_freshness",
		"reputation_event", "piety_event", "done_text"]

## {hair: {label, verb, minutes, tool, item, min_freshness, reputation_event, piety_event,
##  done_text}, teeth: {…}} – min_freshness 0.0 = no limit; low_freshness_text optional.
@export var kinds: Dictionary[StringName, Dictionary] = {}
## What Ilse pays per item (before the piety bonus).
@export var sell_prices: Dictionary[StringName, int] = {&"hair_braid": 4, &"teeth_pouch": 5}
## Tools only Ilse hands out.
@export var tool_items: Array[StringName] = [&"shears", &"pliers"]


## The entry of `kind`, {} if unknown.
func kind(id: StringName) -> Dictionary:
	return kinds.get(id, {})
