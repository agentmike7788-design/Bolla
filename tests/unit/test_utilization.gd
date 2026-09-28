extends TestCase
## P3 (docs/PHASE4_DESIGN.md §2.6, §3.4, §10): UtilizationRules – block reasons in order
## (unknown trader = invisible, taken, dressed, tool, minimum freshness „Das Haar ist zu
## brüchig.“, full inventory), sale value with the piety bonus, the consequences of one harvest
## (quality / reputation / piety / ghost mood) and the utilization config against its fixture.

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")


class FullInventory extends "res://tests/fixtures/fake_inventory.gd":
	func can_add(_id: StringName, _amount: int) -> bool:
		return false


var cfg: UtilizationConfig
var inv: Inventory


func before_each() -> void:
	cfg = Phase4Fixtures.utilization_config()
	inv = FakeInventory.new()
	inv.add_item(&"shears", 1)
	inv.add_item(&"pliers", 1)


func after_each() -> void:
	inv.free()


func test_hidden_until_the_trader_is_known() -> void:
	var r := Phase4Fixtures.corpse()
	assert_eq(UtilizationRules.block_reason(r, &"hair", inv, cfg, false), UtilizationRules.HIDDEN)
	assert_eq(UtilizationRules.block_reason(r, &"teeth", inv, cfg, false), "-")
	assert_eq(UtilizationRules.block_reason(r, &"hair", inv, cfg, true), "")
	assert_eq(UtilizationRules.block_reason(r, &"teeth", inv, cfg, true), "")
	assert_eq(UtilizationRules.block_reason(r, &"nails", inv, cfg, true), UtilizationRules.HIDDEN, "unknown kind")
	assert_eq(UtilizationRules.block_reason(null, &"hair", inv, cfg, true), UtilizationRules.HIDDEN)
	r.location = CorpseRecord.LOCATION_BURIED
	assert_eq(UtilizationRules.block_reason(r, &"hair", inv, cfg, true), UtilizationRules.HIDDEN, "buried")


func test_once_per_kind_and_only_before_dressing() -> void:
	var r := Phase4Fixtures.corpse()
	r.harvested.append(CorpseRecord.HARVEST_HAIR)
	assert_eq(UtilizationRules.block_reason(r, &"hair", inv, cfg, true), UtilizationRules.TEXT_DONE)
	assert_eq(UtilizationRules.block_reason(r, &"teeth", inv, cfg, true), "", "the other kind stays possible")
	r.dress = CorpseRecord.DRESS_SHROUD
	assert_eq(UtilizationRules.block_reason(r, &"teeth", inv, cfg, true), UtilizationRules.TEXT_DRESSED)
	var legacy := Phase4Fixtures.corpse()
	legacy.shrouded = true
	assert_eq(UtilizationRules.block_reason(legacy, &"teeth", inv, cfg, true), UtilizationRules.TEXT_DRESSED, "Phase-2 shrouded")


func test_tool_missing_is_dimmed() -> void:
	var r := Phase4Fixtures.corpse()
	var bare := FakeInventory.new()
	assert_eq(UtilizationRules.block_reason(r, &"hair", bare, cfg, true), "Werkzeug fehlt – Ilse Kranich hat es.")
	assert_eq(UtilizationRules.block_reason(r, &"teeth", bare, cfg, true), UtilizationRules.TEXT_NO_TOOL)
	assert_eq(UtilizationRules.block_reason(r, &"hair", null, cfg, true), UtilizationRules.TEXT_NO_TOOL)
	bare.add_item(&"pliers", 1)
	assert_eq(UtilizationRules.block_reason(r, &"teeth", bare, cfg, true), "")
	assert_eq(UtilizationRules.block_reason(r, &"hair", bare, cfg, true), UtilizationRules.TEXT_NO_TOOL, "shears still missing")
	bare.free()


func test_minimum_freshness_for_hair() -> void:
	var r := Phase4Fixtures.corpse([], &"fever", 0.3)
	assert_eq(UtilizationRules.block_reason(r, &"hair", inv, cfg, true), "", "exactly at 0.3")
	r.freshness = 0.2999
	assert_eq(UtilizationRules.block_reason(r, &"hair", inv, cfg, true), "Das Haar ist zu brüchig.")
	r.freshness = 0.0
	assert_eq(UtilizationRules.block_reason(r, &"teeth", inv, cfg, true), "", "teeth: no limit")
	var plain := cfg.duplicate(true) as UtilizationConfig
	var hair: Dictionary = plain.kinds[&"hair"].duplicate()
	hair.erase("low_freshness_text")
	plain.kinds[&"hair"] = hair
	assert_eq(UtilizationRules.block_reason(r, &"hair", inv, plain, true), UtilizationRules.TEXT_TOO_OLD, "no text → fallback")


func test_full_inventory_blocks() -> void:
	var full := FullInventory.new()
	full.items = {&"shears": 1, &"pliers": 1}
	var r := Phase4Fixtures.corpse()
	assert_eq(UtilizationRules.block_reason(r, &"hair", full, cfg, true), UtilizationRules.TEXT_NO_ROOM)
	full.free()


func test_order_of_reasons() -> void:
	# Dressed, without tools, too old: the first reason wins (taken → dressed → tool → freshness).
	var r := Phase4Fixtures.corpse([], &"fever", 0.1)
	var bare := FakeInventory.new()
	r.dress = CorpseRecord.DRESS_GOWN
	r.harvested.append(CorpseRecord.HARVEST_HAIR)
	assert_eq(UtilizationRules.block_reason(r, &"hair", bare, cfg, true), UtilizationRules.TEXT_DONE)
	r.harvested.clear()
	assert_eq(UtilizationRules.block_reason(r, &"hair", bare, cfg, true), UtilizationRules.TEXT_DRESSED)
	r.dress = CorpseRecord.DRESS_NONE
	assert_eq(UtilizationRules.block_reason(r, &"hair", bare, cfg, true), UtilizationRules.TEXT_NO_TOOL)
	assert_eq(UtilizationRules.block_reason(r, &"hair", inv, cfg, true), "Das Haar ist zu brüchig.")
	bare.free()


func test_sale_value() -> void:
	assert_eq(UtilizationRules.sale_value({&"hair_braid": 1}, 0, cfg), 4)
	assert_eq(UtilizationRules.sale_value({&"teeth_pouch": 1}, 0, cfg), 5)
	assert_eq(UtilizationRules.sale_value({&"hair_braid": 2, &"teeth_pouch": 1}, 0, cfg), 13)
	assert_eq(UtilizationRules.sale_value({&"hair_braid": 2, &"teeth_pouch": 1}, 1, cfg), 16, "+1 per item (Abgebrüht)")
	assert_eq(UtilizationRules.sale_value({&"linen": 3, &"hair_braid": 0, &"teeth_pouch": -2}, 1, cfg), 0, "not bought / ≤ 0")
	assert_eq(UtilizationRules.sale_value({"hair_braid": 1}, 0, cfg), 4, "String keys")
	assert_eq(UtilizationRules.sale_value({}, 1, cfg), 0)


func test_effects_of_one_harvest() -> void:
	var eco := Phase4Fixtures.economy_config()
	var rep := Phase4Fixtures.reputation_config()
	var pie := Phase4Fixtures.piety_config()
	var ghosts := GhostConfig.new()
	assert_eq(UtilizationRules.effects(&"hair", cfg, eco, rep, pie, ghosts),
			{"item": &"hair_braid", "price": 4, "quality": -1, "reputation": -3, "piety": -4, "mood": -5})
	assert_eq(UtilizationRules.effects(&"teeth", cfg, eco, rep, pie, ghosts),
			{"item": &"teeth_pouch", "price": 5, "quality": -2, "reputation": -5, "piety": -6, "mood": -5})
	assert_eq(UtilizationRules.effects(&"valuables", cfg, eco, rep, pie, ghosts),
			{"item": &"", "price": 0, "quality": -2, "reputation": -8, "piety": -6, "mood": 0})
	assert_eq(UtilizationRules.effects(&"nails", cfg, eco, rep, pie, ghosts), {})
	assert_eq(UtilizationRules.effects(&"hair").reputation, -3, "data configs")


func test_kinds_carry_the_contract_values() -> void:
	for c: UtilizationConfig in [cfg, Database.config(&"utilization_config") as UtilizationConfig]:
		var hair := c.kind(&"hair")
		var teeth := c.kind(&"teeth")
		for key: String in UtilizationConfig.KIND_KEYS:
			assert_true(hair.has(key) and teeth.has(key), key)
		assert_eq([hair.minutes, hair.tool, hair.item, hair.min_freshness], [10, &"shears", &"hair_braid", 0.3])
		assert_eq([teeth.minutes, teeth.tool, teeth.item, teeth.min_freshness], [15, &"pliers", &"teeth_pouch", 0.0])
		assert_eq(hair.low_freshness_text, "Das Haar ist zu brüchig.")
		assert_eq(c.sell_prices, {&"hair_braid": 4, &"teeth_pouch": 5})
		assert_eq(c.tool_items, [&"shears", &"pliers"] as Array[StringName])


func test_real_configs_match_the_fixtures() -> void:
	for name: StringName in [&"utilization_config", &"trader_config"]:
		var real := Database.config(name)
		# Phase 5 (P6, §2.6): the real trader config carries gold leaf → the Phase-5 fixture.
		var fixture := Phase5Fixtures.config(name) if name == &"trader_config" else Phase4Fixtures.config(name)
		for prop: Dictionary in real.get_property_list():
			if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				assert_eq(real.get(prop.name), fixture.get(prop.name), "%s.%s" % [name, prop.name])
