extends RefCounted
## Driver of make_phase10_fixtures.gd (loaded after the autoloads exist). Writes the Phase-10 W1 fixtures
## (docs/PHASE10_DESIGN.md §12 W0) from the contract tables of §1–§2 and the three new data/config files:
##   godot --headless --path . -s res://tests/fixtures/phase10/make_phase10_fixtures.gd
## data/config/{treasury,cash_book,market}_config.tres = class defaults (§3.4), written explicitly; the contract tables
## that §3.4 leaves as {} / [] in the class (CashBookConfig.sources / purpose_labels from §2.6, MarketConfig.groups /
## season_rules / rep_demand / piety_demand from §2.7.3 / §2.7.5) are written into the .tres as well (like Phase 9's
## stranger questions). Historical tool of W0 (Lead) – the fixtures are the contract snapshot; W1 tests load them,
## owners never regenerate them for balancing (the data files under data/ belong to the owners).

const OUT := "res://tests/fixtures/phase10"

var _failed := false


func run() -> bool:
	_configs()
	_extended_configs()
	_stalls()
	_wares()
	_items()
	_recipes()
	_decor()
	_wishlist()
	return not _failed


# --- helpers ------------------------------------------------------------------------------------

## Every script variable written explicitly (ResourceSaver drops values equal to the class default – a fixture must
## not follow later changes of a class default). Resources with sub-resources (MarketStallData, WishlistData) and the
## DecorData (its model is an external scene) go through ResourceSaver.
func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if res is MarketStallData or res is WishlistData or res is DecorData:
		var err := ResourceSaver.save(res, path)
		if err != OK:
			printerr("save failed ", path, " ", error_string(err))
			_failed = true
		return
	var script := res.get_script() as Script
	var lines := PackedStringArray()
	lines.append('[gd_resource type="Resource" script_class="%s" load_steps=2 format=3]' % script.get_global_name())
	lines.append("")
	lines.append('[ext_resource type="Script" path="%s" id="1"]' % script.resource_path)
	lines.append("")
	lines.append("[resource]")
	lines.append('script = ExtResource("1")')
	for prop: Dictionary in res.get_property_list():
		var usage := int(prop.usage)
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			lines.append("%s = %s" % [prop.name, var_to_str(res.get(prop.name))])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("save failed ", path)
		_failed = true
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()


static func _sn(list: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for v: Variant in list:
		out.append(StringName(str(v)))
	return out


static func _ps(list: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for v: Variant in list:
		out.append(str(v))
	return out


# --- data/config + fixtures of the new configs ----------------------------------------------------

## §2.6 sources: {label, prefixes, receipt (tithe, §2.5.6), estimate (counts as „ohne Beleg" for the estimate –
## W0 addition, see the W0 notes)}. The prefixes are the reason texts of EventBus.payment_received in the G9 code
## (checked by test_phase10_scaffold) plus the new Phase-10 texts of §2.10.
const SOURCES := [
	["burial", "Bestattung", ["Bestattung von "], true, false],
	["service", "Aussegnung", ["Die Familie legt "], true, false],
	["reinter", "Umbettung", ["Umbettung von "], true, false],
	["parish", "Friedhofsgeld", ["Friedhofsgeld", "Pflegegeld der Gemeinde"], false, false],
	["need", "Bedarf der Gemeinde", ["Bedarfszulage der Gemeinde", "Notgroschen der Gemeinde"], false, false],
	["order", "Aufträge", ["Auftrag: "], true, false],
	["request", "Bitten", ["Bitte: ", "Bitte zur Hälfte: "], true, false],
	["errand", "Botenlohn", ["Botenlohn"], true, false],
	["tip", "Trinkgeld", ["Trinkgeld"], false, false],
	["donation_in", "Spenden", ["Spenden aus dem Opferstock"], false, false],
	["gift", "Geistergaben", ["Der Geist deutet "], false, false],
	["shop_sale", "Läden", ["Verkauf im Dorf", "Verkauf an Hanne"], true, false],
	["market_sale", "Markt", ["Verkauf am Marktstand"], true, false],
	["specimen", "Präparate", ["Präparat an Quast: "], false, true],
	["lecture", "Vorlesung", ["Honorar der Vorlesung"], false, true],
	["collection", "Sammlung", ["Die Universität zahlt für die Aufstellung: "], false, true],
	["night", "Ilse", [], false, true],
	["stranger", "Der Herr mit dem Koffer", ["Verkauf an den Herrn mit dem Koffer", "Auskunft für den Herrn mit dem Koffer",
			"Der Herr mit dem Koffer"], false, true],
	["other", "Sonstiges", [], false, false],
]
## GameState.COIN_REASONS → the cash book's purpose column (§2.6; W0 labels, P3 may polish).
const PURPOSE_LABELS := {"license": "Brief", "build": "Bau", "osric": "Osric", "ilse": "Ilse", "building": "Gebäude",
		"village": "Dorf", "donation": "Spenden", "round": "Runden", "consecration": "Weihe", "apprentice": "Jakob",
		"alms": "Almosen", "peddler": "Hanne", "post": "Post", "market": "Markt", "rent": "Pacht", "tax": "Abgaben",
		"stall": "Standgeld"}
## §2.7.3 ware groups (item ids of the G9 data + rose_bush / brass_lantern of P4).
const GROUPS := {
	"candles": ["grave_candle", "altar_candle", "beeswax"],
	"grave_goods": ["wooden_cross", "wax_wreath", "decor_grave_vase", "straw_bouquet", "rose_bush", "brass_lantern"],
	"herbs": ["herbs", "herb_bundle", "elderberries", "wound_salve"],
	"textiles": ["linen", "yarn", "flax", "burial_gown"],
	"wood_iron": ["wood", "charcoal", "iron_fittings", "steel_rod"],
	"pantry": ["honey_cake", "elder_wine", "spirits", "seeds", "flower_seedlings"],
}


func cash_book_config() -> CashBookConfig:
	var c := CashBookConfig.new()
	var sources: Dictionary[StringName, Dictionary] = {}
	for row: Array in SOURCES:
		sources[StringName(row[0])] = {"label": row[1], "prefixes": _ps(row[2]), "receipt": row[3], "estimate": row[4]}
	c.sources = sources
	var labels: Dictionary[StringName, String] = {}
	for k: String in PURPOSE_LABELS:
		labels[StringName(k)] = PURPOSE_LABELS[k]
	c.purpose_labels = labels
	return c


func market_config() -> MarketConfig:
	var c := MarketConfig.new()
	var groups: Dictionary[StringName, PackedStringArray] = {}
	for k: String in GROUPS:
		groups[StringName(k)] = _ps(GROUPS[k])
	c.groups = groups
	# §2.7.3 frost: Julmond, Hartung, Hornung → wood_iron +1.
	c.season_rules = [{"months": PackedInt32Array([12, 1, 2]), "group": &"wood_iron", "step": 1}] as Array[Dictionary]
	# §2.7.5 demand: „Verrufen" × 0.7, „Gerühmt" × 1.1; „Hartherzig" × 0.7 (grave_goods only – P4), „Andächtig" × 1.1.
	c.rep_demand = {&"disreputable": 0.7, &"renowned": 1.1} as Dictionary[StringName, float]
	c.piety_demand = {&"hardhearted": 0.7, &"devout": 1.1} as Dictionary[StringName, float]
	return c


func _configs() -> void:
	var pairs := {&"treasury_config": TreasuryConfig.new(), &"cash_book_config": cash_book_config(),
			&"market_config": market_config()}
	for name: StringName in pairs:
		_save(pairs[name], "res://data/config/%s.tres" % name)
		_save((pairs[name] as Resource).duplicate(true), OUT + "/%s_fixture.tres" % name)


## Phase-10 values of existing configs (W0: class default and data/config carry them too; the fixture is the W0
## snapshot): reputation (+ 2 events), piety (+ 2), relationship (gains + 3), npc_life (reactions + market_lage),
## visitor (poor_box_coin, poor_box_cap_day).
func _extended_configs() -> void:
	for name: StringName in [&"reputation_config", &"piety_config", &"relationship_config", &"npc_life_config",
			&"visitor_config"]:
		var res := (Database.config(name) as Resource).duplicate(true)
		_save(res, OUT + "/%s_fixture.tres" % name)


# --- market stands and wares (§2.7.4, §2.7.5) ------------------------------------------------------

func _offer(item: String, price: int, stock: int, flag: String = "", conditions: Array = []) -> MarketOfferData:
	var o := MarketOfferData.new()
	o.item = StringName(item)
	o.price = price
	o.stock = stock
	o.requires_flag = StringName(flag)
	o.conditions = _ps(conditions)
	return o


func _stall(id: String, npc: String, title: String, picks: int, buys: Array, offers: Array) -> MarketStallData:
	var s := MarketStallData.new()
	s.id = StringName(id)
	s.npc_id = StringName(npc)
	s.place = StringName(id)
	s.title = title
	s.picks = picks
	s.buys_groups = _sn(buys)
	var list: Array[MarketOfferData] = []
	for o: Variant in offers:
		list.append(o as MarketOfferData)
	s.offers = list
	return s


func _stalls() -> void:
	var agathe := _stall("ms_agathe", "marketwoman", "Agathe Wendel – Stadtware aus Ellbach", 5, ["candles", "grave_goods"], [
		_offer("rose_bush", 12, 2), _offer("brass_lantern", 10, 1), _offer("gold_leaf", 6, 2), _offer("steel_rod", 5, 2),
		_offer("iron_bar", 5, 2), _offer("prep_jar_small", 3, 3), _offer("spirits", 3, 3), _offer("ink", 2, 3),
		_offer("wax_wreath", 5, 2), _offer("mortsafe", 9, 1, "robber_known"), _offer("beeswax", 1, 6), _offer("linen", 3, 4)])
	var kehr := _stall("ms_kehr", "kin_kehr", "Hof Kehr – Wachs, Honig, Saat", 4, ["herbs"], [
		_offer("beeswax", 1, 8), _offer("honey_cake", 2, 4), _offer("seeds", 1, 6), _offer("flower_seedlings", 2, 4),
		_offer("juniper", 2, 4), _offer("elder_wine", 2, 2), _offer("grave_candle", 1, 6)])
	var brandt := _stall("ms_brandt", "kin_brandt", "Hof Brandt – Holz, Flachs, Garn", 4, ["grave_goods"], [
		_offer("wood", 1, 10), _offer("charcoal", 1, 6), _offer("flax", 1, 6), _offer("yarn", 1, 6), _offer("stone", 1, 6),
		_offer("iron_fittings", 3, 3)])
	for s: MarketStallData in [agathe, kehr, brandt]:
		_save(s, OUT + "/market/stalls/%s.tres" % s.id)


func _ware(item: String, group: String, value: float, demand: int, lines: Dictionary) -> MarketWareData:
	var w := MarketWareData.new()
	w.item = StringName(item)
	w.group = StringName(group)
	w.value = value
	w.demand = demand
	var l: Dictionary[StringName, String] = {}
	for k: String in lines:
		l[StringName(k)] = lines[k]
	w.lines = l
	return w


func _wares() -> void:
	for w: MarketWareData in [
		_ware("wooden_cross", "grave_goods", 4.0, 2, {"kin_brandt": "Für den Feldrain. Und für später. Man soll vorsorgen."}),
		_ware("herbs", "herbs", 1.0, 6, {"innkeeper": "Für den Krug. Gegen das, was die Leute nach dem dritten Bier haben."}),
		_ware("herb_bundle", "herbs", 3.0, 3, {}),
		_ware("grave_candle", "candles", 1.0, 8, {"kin_ott": "Drei. Eine für Vater. Zwei, damit er nicht allein brennt."}),
		_ware("wax_wreath", "grave_goods", 6.0, 2, {"kin_kehr": "Für Paul. Er hat Wachs nie gemocht, aber er sagt ja nichts mehr dagegen."}),
	]:
		_save(w, OUT + "/market/wares/%s.tres" % w.item)


# --- items, recipes, decor (§2.8, §2.7.4) -------------------------------------------------------------

func _item(id: String, name: String, description: String, category: ItemData.Category, stack: int) -> ItemData:
	var i := ItemData.new()
	i.id = StringName(id)
	i.display_name = name
	i.description = description
	i.category = category
	i.max_stack = stack
	return i


func _items() -> void:
	_save(_item("rose_bush", "Rosenstock", "Ein Rosenstock im Wurzelballen, winterhart, mit Hagebutten. Aufs Grab gesetzt blüht er jedes Jahr wieder – ohne Gießkanne.",
			ItemData.Category.MATERIAL, 4), OUT + "/items/rose_bush.tres")
	_save(_item("brass_lantern", "Messinglaterne", "Eine Laterne aus Messing, in Ellbach gegossen. Sie glänzt auch, wenn sie nicht brennt.",
			ItemData.Category.DECOR, 4), OUT + "/items/brass_lantern.tres")


func _recipe(id: String, name: String, inputs: Dictionary, output: String, amount: int, minutes: int) -> RecipeData:
	var r := RecipeData.new()
	r.id = StringName(id)
	r.display_name = name
	var inp: Dictionary[StringName, int] = {}
	for k: String in inputs:
		inp[StringName(k)] = int(inputs[k])
	r.inputs = inp
	r.output_id = StringName(output)
	r.output_amount = amount
	r.craft_minutes = minutes
	r.station = &"workbench"
	r.requires_flag = &"village_open"
	return r


func _recipes() -> void:
	_save(_recipe("grave_candle_poured", "Grabkerzen ziehen", {"beeswax": 1, "yarn": 1}, "grave_candle", 4, 20),
			OUT + "/recipes/grave_candle_poured.tres")
	_save(_recipe("wax_wreath_bound", "Wachskranz binden", {"beeswax": 2, "juniper": 1, "yarn": 1}, "wax_wreath", 1, 25),
			OUT + "/recipes/wax_wreath_bound.tres")


## §2.7.4: the brass lantern is a decor record like the grave lantern, Zier +1 (the model stays the lantern's until P6
## delivers ph_deco_lantern_brass).
func _decor() -> void:
	var d := (Database.decor(&"decor_lantern") as DecorData).duplicate() as DecorData
	d.id = &"brass_lantern"
	d.display_name = "Messinglaterne"
	d.zier += 1
	_save(d, OUT + "/decor/brass_lantern.tres")


# --- wish list (§2.3 Grundsatz 2) --------------------------------------------------------------------

func _entry(id: String, kind: String, ref: String, coins: int, flag: String, max_count: int = 1) -> WishlistEntryData:
	var e := WishlistEntryData.new()
	e.id = StringName(id)
	e.kind = StringName(kind)
	e.ref = StringName(ref)
	e.coins = coins
	e.available_flag = StringName(flag)
	e.max_count = max_count
	return e


## A W0 sample in the contract's form (P1 writes data/economy/wishlist.tres and decides the entries).
func _wishlist() -> void:
	var w := WishlistData.new()
	var entries: Array[WishlistEntryData] = [
		_entry("wl_forge", "station", "forge", 25, "workshop_open"),
		_entry("wl_loom", "station", "loom", 10, "workshop_open"),
		_entry("wl_mason", "station", "mason", 15, "workshop_open"),
		_entry("wl_pult", "station", "pult", 12, "village_open"),
		_entry("wl_gold", "per_grave", "gold_leaf", 6, "workshop_open", 60),
		_entry("wl_mortsafe", "per_grave", "mortsafe", 12, "p8_open", 60),
		_entry("wl_rose", "per_grave", "rose_bush", 12, "village_open", 60),
		_entry("wl_brass_lantern", "item", "brass_lantern", 10, "village_open", 6),
	]
	w.entries = entries
	_save(w, OUT + "/economy/wishlist.tres")
