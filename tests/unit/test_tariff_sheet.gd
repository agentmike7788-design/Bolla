extends TestCase
## P1 (docs/PHASE10_DESIGN.md §2.4, §10.1): the Phase-10 tariff is in the data – every row of the Tarifblatt read from
## the loaded resources and compared with the contract; the sheet tools/economy/tariff_report.py generated into
## docs/reviews/phase10_wip/balance.md shows exactly these data values (same formatting, row by row), so the sheet cannot
## drift from the data. Rows another package brings (owner ≠ "") are only compared with the sheet; for them the contract
## value is checked once the owner's data are there (P2 treasury_config from W0 already is).

const SHEET := "res://docs/reviews/phase10_wip/balance.md"
const BEGIN := "<!-- tarifblatt:begin (tools/economy/tariff_report.py) -->"
const END := "<!-- tarifblatt:end -->"
## Small hill requests (§2.4.1 E8): minutes of work the request asks for (same table as tariff_report.py SMALL_MINUTES);
## ≤ 40 → 1 coin, longer → 2.
const SMALL_MINUTES := {
	&"hr_brandt_grave": 25, &"hr_esch_stone": 30, &"hr_esch_vase": 45, &"hr_fenner_clear": 40, &"hr_fenner_stone": 60,
	&"hr_kehr_gate": 30, &"hr_lenz_ghost": 30, &"hr_lenz_stone": 60, &"hr_liesel_paths": 30, &"hr_liesel_wash": 25,
	&"hr_mangold_bench": 55, &"hr_osric_laidout": 35, &"hr_osric_wood": 60, &"hr_ott_ghost": 30, &"hr_quast_exam": 0,
	&"hr_rosine_leaves": 40, &"hr_rosine_wood": 60, &"hr_sieber_cross": 75,
}
const SMALL_LIMIT := 40
## Rows whose data another package brings: id → owner (as the sheet's „Stand" names it).
const OWNED_ELSEWHERE := {"E1": "mit P2", "E1b": "mit P2", "E18": "P4", "A1": "P5", "A11": "P4"}


# --- the rows -------------------------------------------------------------------------------------------------------

## id → [contract value, data value now]
func _rows() -> Dictionary:
	var rep := Database.config(&"reputation_config") as ReputationConfig
	var tre := Database.config(&"treasury_config") as TreasuryConfig
	var vis := Database.config(&"visitor_config") as VisitorConfig
	var util := Database.config(&"utilization_config") as UtilizationConfig
	var anat := Database.config(&"anatomy_config") as AnatomyConfig
	var tables := Database.corpse_tables() as CorpseTables
	var village := Database.config(&"village_config")
	var trader := Database.config(&"trader_config") as TraderConfig
	var stranger := Database.config(&"stranger_config")
	var market := Database.config(&"market_config") as MarketConfig
	var tiers: Array = []
	for t: StringName in CemeteryRating.TIERS:
		tiers.append(tre.tier_pay.get(t, 0))
	var causes: Array = []
	for c: Dictionary in tables.causes:
		if float(c.get("weight", 0.0)) > 0.0:
			causes.append(int(c.base_payment))
	var cons: Dictionary = village.get(&"consecration_price_by_tier")
	var shop_buys: Array = []
	for s: ShopData in Database.shops():
		for item: StringName in s.buys:
			shop_buys.append(int((s.buys[item] as Dictionary).get("price", 0)))
	var small := _rewards("res://data/hill_requests", "hr_")
	return {
		"E1": ["0/0/0/0/0", fmt_list(rep.stipend)],
		"E1b": ["0", str(rep.stipend_purse_cap)],
		"E2": ["0/4/7/10/12", fmt_list(tiers)],
		"E2b": ["0,5/0,75/0,95/15", fmt_list(Array(tre.care_steps) + [tre.quality_cap])],
		"E2c": ["60/4/15", fmt_list([tre.need_threshold, tre.need_divisor, tre.need_cap])],
		"E2d": ["10/8", fmt_list([tre.hardship_floor, tre.hardship_cap])],
		"E3": ["2–4", fmt_range(causes)],
		"E4": ["0,5", fmt_num((Database.config(&"economy_config") as EconomyConfig).payment_per_quality)],
		"E5": ["-2/0/1/2/2", fmt_list(rep.pay_bonus)],
		"E6": ["3/5/6", fmt_list(Array((Database.config(&"chapel_config") as ChapelConfig).service_fee_by_level).slice(1))],
		"E7": ["4/2", fmt_list([Database.config(&"crypt_config").get(&"reinter_fee"), Database.config(&"ghost_config").get(&"gift_coins")])],
		"E7b": ["10/10/5/0", fmt_list([cons[&"stranger"], cons[&"acquainted"], cons[&"trusted"], cons[&"friend"]])],
		"E8": ["1–2: 1 bis 40 Min Arbeit, 2 länger", "%s (Ø %s)" % [fmt_range(small.values()), fmt_avg(small.values())]],
		"E9": ["2", fmt_range(_rewards("res://data/hill_requests/large", "hrl_").values())],
		"E9b": ["3–4", fmt_range(_rewards("res://data/hill_requests/large", "hrv_").values())],
		"E10": ["3–11", fmt_range(_rewards("res://data/orders", "o_").values().filter(func(v: int) -> bool: return v > 0)
				+ _rewards("res://data/orders", "ob_").values().filter(func(v: int) -> bool: return v > 0))],
		"E11": ["3", str(vis.tip_cap_day)],
		"E11b": ["1/2", fmt_list([vis.poor_box_coin, vis.poor_box_cap_day])],
		"E12": ["3/4", fmt_list([util.sell_prices[&"hair_braid"], util.sell_prices[&"teeth_pouch"]])],
		"E12b": ["1/1/0/0/0", fmt_list((Database.config(&"piety_config") as PietyConfig).buyer_bonus_by_tier)],
		"E13": ["4–7", "%d–%d" % [tables.valuables_coins_min, tables.valuables_coins_max]],
		"E14": ["10/11/8", fmt_list([anat.organs[&"eyes"].base_price, anat.organs[&"hand"].base_price, anat.organs[&"heart"].base_price])],
		"E14b": ["4", str(anat.lecture.fee)],
		"E15": ["40/15", fmt_list([stranger.get(&"kladde_price"), stranger.get(&"bribe_coins")])],
		"E17": ["1–8", fmt_range(shop_buys)],
		"E18": ["wooden_cross 4 · herbs 1 · herb_bundle 3 · grave_candle 1 · wax_wreath 6", _wares()],
		"A1": ["0", _license_price()],
		"A2": ["25/10/15/12", fmt_list([&"forge", &"loom", &"mason", &"pult"].map(func(s: StringName) -> int:
				return (Database.station(s) as StationData).build_coins))],
		"A2b": ["shed 10/15/20 · chapel 25/30/40 · crypt 0/35/35", " · ".join([&"shed", &"chapel", &"crypt"].map(_building_coins))],
		"A3": ["2", _shop_price(&"grocer", &"honey_cake")],
		"A3b": ["12", _shop_price(&"smith", &"mortsafe")],
		"A4": ["3", str(Database.config(&"apprentice_config").get(&"wage"))],
		"A5": ["5/5/1", fmt_list([village.get(&"round_price"), village.get(&"donation_step"), Database.config(&"letters_config").get(&"postage")])],
		"A6": ["2/1/6", fmt_list([trader.shop[&"linen"].price, trader.shop[&"juniper"].price, trader.shop[&"gold_leaf"].price])],
		"A7": ["8", str(tre.rent)],
		"A8": ["10/25", fmt_list([tre.tithe_percent, tre.tithe_cap])],
		"A9": ["10/20/15", fmt_list([tre.estimate_percent, tre.estimate_min_untracked, tre.estimate_cap])],
		"A10": ["1", str(market.stall_fee)],
		"A11": ["12/10", _agathe([&"rose_bush", &"brass_lantern"])],
	}


func test_the_p1_rows_of_the_tariff_are_in_the_data() -> void:
	var rows := _rows()
	for id: String in rows:
		if OWNED_ELSEWHERE.has(id) or id == "E8":
			continue
		assert_eq(rows[id][1], rows[id][0], "§2.4 %s" % id)


func test_small_requests_pay_by_work_minutes() -> void:
	var small := _rewards("res://data/hill_requests", "hr_")
	assert_eq(small.keys().size(), SMALL_MINUTES.size(), "every small request has its minutes")
	for id: StringName in SMALL_MINUTES:
		assert_eq(small.get(id, -1), 1 if int(SMALL_MINUTES[id]) <= SMALL_LIMIT else 2, "E8 %s (%d Min)" % [id, SMALL_MINUTES[id]])
	# E9: the large ones; the things given as reward stay (only reward_coins changed).
	assert_eq(_rewards("res://data/hill_requests/large", "hrv_"), {&"hrv_bridge_stones": 4, &"hrv_church_candles": 4,
			&"hrv_inn_cellar": 4, &"hrv_paul_day": 3})


func test_rows_brought_by_other_packages_wait_for_them() -> void:
	var rows := _rows()
	# The stipend stays until P2's Treasury pays the Friedhofsgeld (measured: without it the founder line stalls in
	# Phase 5, docs/reviews/phase10_wip/balance.md) – then it is 0 in the data and the class default.
	assert_true(rows.E1[1] in ["0/1/2/3/4", "0/0/0/0/0"], "E1 now %s" % rows.E1[1])
	for id: String in ["E18", "A11"]:
		assert_true(rows[id][1] == "–" or rows[id][1] == rows[id][0], "%s: P4's data are the contract (%s)" % [id, rows[id][1]])
	assert_true(rows.A1[1] in ["20", "0"], "A1: P5 turns the license into the Pachtbrief (%s)" % rows.A1[1])


func test_the_generated_sheet_shows_the_data() -> void:
	var text := FileAccess.get_file_as_string(SHEET)
	assert_true(text.contains(BEGIN) and text.contains(END), "balance.md carries the generated Tarifblatt")
	var block := text.substr(text.find(BEGIN), text.find(END) - text.find(BEGIN))
	var sheet := {}
	for line: String in block.split("\n"):
		if not line.begins_with("| ") or line.begins_with("| #"):
			continue
		var cols := line.trim_prefix("| ").trim_suffix(" |").split(" | ")
		if cols.size() == 7:
			sheet[cols[0]] = {"contract": cols[4], "data": cols[5], "stand": cols[6]}
	var rows := _rows()
	assert_eq(sheet.keys().size(), rows.keys().size(), "one row per tariff entry (python tools/economy/tariff_report.py --update=docs/reviews/phase10_wip/balance.md)")
	for id: String in rows:
		assert_true(sheet.has(id), "sheet row %s" % id)
		if not sheet.has(id):
			continue
		assert_eq(sheet[id].data, rows[id][1], "%s: the sheet shows the data – regenerate it after a data change" % id)
		assert_eq(sheet[id].contract, rows[id][0], "%s: contract column" % id)
		var ok: bool = rows[id][1] == rows[id][0] or (id == "E8")
		assert_eq(sheet[id].stand, "✓" if ok else OWNED_ELSEWHERE.get(id, "✗"), "%s: Stand" % id)


# --- helpers (formatting = tariff_report.py) -----------------------------------------------------------------------

static func fmt_num(v: Variant) -> String:
	if v is float:
		var s := "%.2f" % float(v)
		while s.ends_with("0"):
			s = s.trim_suffix("0")
		s = s.trim_suffix(".")
		return s.replace(".", ",")
	return str(v)


static func fmt_list(values: Variant) -> String:
	var parts := PackedStringArray()
	for v: Variant in values:
		parts.append(fmt_num(v))
	return "/".join(parts)


static func fmt_range(values: Array) -> String:
	if values.is_empty():
		return "–"
	var lo: Variant = values.min()
	var hi: Variant = values.max()
	return fmt_num(lo) if lo == hi else "%s–%s" % [fmt_num(lo), fmt_num(hi)]


static func fmt_avg(values: Array) -> String:
	if values.is_empty():
		return "–"
	var sum := 0
	for v: int in values:
		sum += v
	return ("%.2f" % (float(sum) / values.size())).replace(".", ",")


## id → reward_coins of the order resources `prefix`* in `dir`.
static func _rewards(dir: String, prefix: String) -> Dictionary:
	var out := {}
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for f: String in files:
		if f.begins_with(prefix) and f.ends_with(".tres"):
			var o := load(dir.path_join(f)) as OrderData
			out[o.id] = o.reward_coins
	return out


static func _license_price() -> String:
	var re := RegEx.create_from_string("take_item:coin:(\\d+):license")
	var m := re.search(FileAccess.get_file_as_string("res://data/dialogue/carter.tres"))
	return m.get_string(1) if m != null else "0"


static func _building_coins(id: StringName) -> String:
	var b := load("res://data/buildings/%s.tres" % id) as BuildingData
	var coins: Array = []
	for l: Resource in b.levels:
		coins.append(int(l.get(&"coins")))
	return "%s %s" % [id, fmt_list(coins)]


static func _shop_price(shop: StringName, item: StringName) -> String:
	var s := Database.shop(shop) as ShopData
	return str(int(s.sells[item].price)) if s != null and s.sells.has(item) else "–"


static func _wares() -> String:
	var parts := PackedStringArray()
	var files := Array(DirAccess.get_files_at("res://data/market/wares")) if DirAccess.dir_exists_absolute("res://data/market/wares") else []
	files.sort()
	for f: String in files:
		if f.ends_with(".tres"):
			var w := load("res://data/market/wares/" + f) as MarketWareData
			parts.append("%s %s" % [w.item, fmt_num(w.value)])
	return "–" if parts.is_empty() else " · ".join(parts)


static func _agathe(items: Array) -> String:
	if not ResourceLoader.exists("res://data/market/stalls/ms_agathe.tres"):
		return "–"
	var st := load("res://data/market/stalls/ms_agathe.tres") as MarketStallData
	var prices := {}
	for o: MarketOfferData in st.offers:
		prices[o.item] = o.price
	return fmt_list(items.map(func(i: StringName) -> Variant: return prices.get(i, "–")))
