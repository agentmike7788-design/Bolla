class_name Phase10Fixtures
extends RefCounted
## Phase-10 test fixtures (W0, docs/PHASE10_DESIGN.md §12). W1 unit tests load these instead of data/ – they mirror
## the contract values and leading texts (§1–§2) at the time of W0 and do not follow later balancing / text edits of
## the real data files. Written by make_phase10_fixtures.gd (historical tool).
##
## *_config_fixture.tres: treasury, cash_book, market (= the W0 data/config files: class defaults + the §2.6 / §2.7
##   tables CashBookConfig.sources / purpose_labels, MarketConfig.groups / season_rules / rep_demand / piety_demand)
##   + the Phase-10 values of existing configs: reputation (+ 2 events), piety (+ 2), relationship (gains + 3),
##   npc_life (reactions + market_lage), visitor (poor_box_coin, poor_box_cap_day).
## market/stalls/ (ms_agathe, ms_kehr, ms_brandt with their offer pools), market/wares/ (the five A wares of the own
##   stand), items/ (rose_bush, brass_lantern), recipes/ (grave_candle_poured, wax_wreath_bound), decor/brass_lantern,
##   economy/wishlist.tres (a sample in the contract's form – P1 writes the real one).
## layout_p9.json / village_layout_p9.json: the approved Phase-9 layouts (f024103 = 6f0bd9c), byte-identical.
## ../saves_v8/: Phase-9 save files (format v8) – see make_v8_saves.gd.

const DIR := "res://tests/fixtures/phase10"
const CONFIG_NAMES: Array[StringName] = [&"treasury_config", &"cash_book_config", &"market_config"]
## Existing configs with Phase-10 values (W0: class default and data carry them too).
const EXTENDED_CONFIG_NAMES: Array[StringName] = [&"reputation_config", &"piety_config", &"relationship_config",
		&"npc_life_config", &"visitor_config"]
## Properties of the new configs whose .tres value is a contract table while §3.4 keeps the class default {} / [].
const DATA_TABLES := {&"cash_book_config": [&"sources", &"purpose_labels"],
		&"market_config": [&"groups", &"season_rules", &"rep_demand", &"piety_demand"]}
const STALL_IDS: Array[StringName] = [&"ms_agathe", &"ms_brandt", &"ms_kehr"]
const WARE_IDS: Array[StringName] = [&"grave_candle", &"herb_bundle", &"herbs", &"wax_wreath", &"wooden_cross"]
const ITEM_IDS: Array[StringName] = [&"rose_bush", &"brass_lantern"]
const RECIPE_IDS: Array[StringName] = [&"grave_candle_poured", &"wax_wreath_bound"]
const GROUP_IDS: Array[StringName] = [&"candles", &"grave_goods", &"herbs", &"textiles", &"wood_iron", &"pantry"]
## [class, save_id, save_order, group] of the Phase-10 system nodes (§3.1).
const SAVEABLES := [
	["Treasury", "treasury", 85, &"treasury"], ["CashBook", "cash_book", 86, &"cash_book"], ["Market", "market", 87, &"market"],
]
const SAVES_V8_DIR := "res://tests/fixtures/saves_v8"
const SAVES_V8: PackedStringArray = ["slot_p9_day75_kindly", "slot_p9_day75_trader", "slot_p9_day75_stay", "slot_p9_founder",
		"slot_p9_day38_village", "slot_p9_day29_new", "slot_p9_mid_h4"]
const LAYOUT_P9 := DIR + "/layout_p9.json"
const VILLAGE_LAYOUT_P9 := DIR + "/village_layout_p9.json"
## §1.4 arc A starts on day 75 (Tuesday, 16. Julmond 1834); its settlement is the Julmond's on day 91.
const OPEN_DAY := 75
const MONTH_JULMOND := "1834-12"
## The flags of every chapter up to Phase 9 (p10_open needs who_knows_when_complete).
const OPEN_FLAGS: Array[StringName] = [&"village_open", &"name_in_village_complete", &"p8_open", &"who_comes_up_complete",
		&"p9_open", &"who_knows_when_complete"]


# --- configs ------------------------------------------------------------------------------------

static func config(name: StringName) -> Resource:
	return load(DIR + "/%s_fixture.tres" % name)


static func treasury_config() -> TreasuryConfig:
	return config(&"treasury_config") as TreasuryConfig


static func cash_book_config() -> CashBookConfig:
	return config(&"cash_book_config") as CashBookConfig


static func market_config() -> MarketConfig:
	return config(&"market_config") as MarketConfig


static func reputation_config() -> ReputationConfig:
	return config(&"reputation_config") as ReputationConfig


static func piety_config() -> PietyConfig:
	return config(&"piety_config") as PietyConfig


static func relationship_config() -> RelationshipConfig:
	return config(&"relationship_config") as RelationshipConfig


static func npc_life_config() -> NpcLifeConfig:
	return config(&"npc_life_config") as NpcLifeConfig


static func visitor_config() -> VisitorConfig:
	return config(&"visitor_config") as VisitorConfig


# --- data ---------------------------------------------------------------------------------------

static func market_stall(id: StringName) -> MarketStallData:
	return load(DIR + "/market/stalls/%s.tres" % id) as MarketStallData


static func market_stalls() -> Array[MarketStallData]:
	var out: Array[MarketStallData] = []
	for id: StringName in STALL_IDS:
		out.append(market_stall(id))
	return out


static func market_ware(item_id: StringName) -> MarketWareData:
	return load(DIR + "/market/wares/%s.tres" % item_id) as MarketWareData


static func market_wares() -> Array[MarketWareData]:
	var out: Array[MarketWareData] = []
	for id: StringName in WARE_IDS:
		out.append(market_ware(id))
	return out


static func item(id: StringName) -> ItemData:
	return load(DIR + "/items/%s.tres" % id) as ItemData


static func recipe(id: StringName) -> RecipeData:
	return load(DIR + "/recipes/%s.tres" % id) as RecipeData


static func brass_lantern_decor() -> DecorData:
	return load(DIR + "/decor/brass_lantern.tres") as DecorData


static func wishlist() -> WishlistData:
	return load(DIR + "/economy/wishlist.tres") as WishlistData


static func layout_p9() -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_P9))
	return v if v is Dictionary else {}


static func village_layout_p9() -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(VILLAGE_LAYOUT_P9))
	return v if v is Dictionary else {}


# --- states -------------------------------------------------------------------------------------

## Phase 10 open on `day` (sets every chapter flag up to who_knows_when_complete, p10_open, p10_open_day); a Treasury
## with the book started on `day` (§5.1 book_start), in the tree if `tree`.
static func p10_open(tree: SceneTree = null, day: int = OPEN_DAY) -> Treasury:
	for f: StringName in OPEN_FLAGS:
		GameState.set_flag(f, true)
	var cfg := treasury_config()
	GameState.set_flag(cfg.open_flag, true)
	GameState.set_flag(cfg.open_day_flag, day)
	return _treasury({"book_start": day}, tree)


## A market Saturday: village_open + market_stall_granted, TimeManager on the next Saturday ≥ today at 08:00 (the bell);
## a Market with the place granted (§5.1 granted), in the tree if `tree`.
static func market_day(tree: SceneTree = null) -> Market:
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(market_config().stall_flag, true)
	var day := CalendarRules.next_weekday(maxi(TimeManager.day, 1), market_config().weekday)
	TimeManager.set_time(day, market_config().window.x)
	return _market({"granted": true}, tree)


## The own stand set up today with `goods` ({item: n}) and `tags` ({item: &"cheap" | &"fair" | &"dear"}; missing = fair),
## `ticks` sold so far (§5.1 stall). Market day as market_day().
static func stall_with(goods: Dictionary, tags: Dictionary = {}, ticks: int = 0, tree: SceneTree = null) -> Market:
	var m := market_day(null)
	var g := {}
	var t := {}
	for k: Variant in goods:
		g[str(k)] = int(goods[k])
		t[str(k)] = str(tags.get(k, &"fair"))
	m.load_state({"granted": true, "stall": {"day": TimeManager.day, "goods": g, "tags": t, "ticks": ticks}})
	if tree != null:
		tree.root.add_child(m)
	return m


## The day of the Sunday of `week` (CalendarRules.week_of: day 3 = week 0, day 10 = week 1).
static func schau_day(week: int) -> int:
	return week * 7 + 3


## The inspection of `week` evaluated and not yet paid out (§5.1 schau): tier, care 0.82 (+2), no disturbed grave,
## quality = tier_pay + 2, no need / hardship (Phase 10 open on OPEN_DAY).
static func schau_done(week: int, tier: StringName = &"venerable", tree: SceneTree = null) -> Treasury:
	p10_open(null)
	var cfg := treasury_config()
	var quality := mini(int(cfg.tier_pay.get(tier, 0)) + 2, cfg.quality_cap)
	return _treasury({"book_start": OPEN_DAY, "schau": {"week": week, "day": schau_day(week), "tier": String(tier),
			"care": 0.82, "disturbed": 0, "quality": quality, "need": 0, "hardship": 0, "paid": false}}, tree)


## The settlement of `month` (a "YYYY-MM" key) due since its 1st – the §5.1 example: rent 5, tithe 8, estimate 0 = 13.
static func settlement_due(month: String = MONTH_JULMOND, tree: SceneTree = null) -> Treasury:
	p10_open(null)
	return _treasury({"book_start": OPEN_DAY, "settlements": {month: _settlement(month, Treasury.STATE_DUE)}}, tree)


## The settlement of `month` deferred (not paid on the 7th).
static func deferred(month: String = MONTH_JULMOND, tree: SceneTree = null) -> Treasury:
	p10_open(null)
	return _treasury({"book_start": OPEN_DAY, "settlements": {month: _settlement(month, Treasury.STATE_DEFERRED)}}, tree)


## `n` coins in the poor box at the gate (§5.1 poor_box).
static func poor_box(n: int, tree: SceneTree = null) -> Treasury:
	return _treasury({"book_start": OPEN_DAY, "poor_box": n}, tree)


## A CashBook opened on `day` with one day page {in: {source: n}, out: {purpose: n}} and the same sums on its month page.
static func cash_day(day: int, incoming: Dictionary, outgoing: Dictionary, tree: SceneTree = null) -> CashBook:
	var page := {"in": _int_dict(incoming), "out": _int_dict(outgoing), "untracked": 0}
	var c := CashBook.new()
	c.config = cash_book_config()
	c.load_state({"open_day": day, "last_holdings": 0, "last_check": [day, 360], "days": {str(day): page.duplicate(true)},
			"months": {CalendarRules.month_key(day): page.duplicate(true)}})
	if tree != null:
		tree.root.add_child(c)
	return c


# --- v8 saves -------------------------------------------------------------------------------------

## res:// path of a v8 save fixture, e.g. save_v8_path("slot_p9_day75_kindly").
static func save_v8_path(name: String) -> String:
	return SAVES_V8_DIR.path_join(name + ".json")


## Copies a v8 fixture to <save_dir>/slot_<slot>.json (for SaveManager.load_game).
static func install_save_v8(name: String, save_dir: String, slot: int) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		return err
	var text := FileAccess.get_file_as_string(save_v8_path(name))
	if text == "":
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(SaveFileIO.slot_path(save_dir, slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


# --- helpers ------------------------------------------------------------------------------------

static func _treasury(state: Dictionary, tree: SceneTree) -> Treasury:
	var t := Treasury.new()
	t.config = treasury_config()
	t.load_state(state)
	if tree != null:
		tree.root.add_child(t)
	return t


static func _market(state: Dictionary, tree: SceneTree) -> Market:
	var m := Market.new()
	m.config = market_config()
	m.load_state(state)
	if tree != null:
		tree.root.add_child(m)
	return m


static func _settlement(month: String, state: StringName) -> Dictionary:
	return {"day": CalendarRules.first_day_of_month(month), "rent": 5, "tithe": 8, "estimate": 0, "deferred_in": 0, "total": 13,
			"state": String(state), "paid_day": 0, "via": ""}


static func _int_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d:
		out[str(k)] = int(d[k])
	return out
