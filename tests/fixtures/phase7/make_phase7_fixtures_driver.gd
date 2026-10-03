extends RefCounted
## Driver of make_phase7_fixtures.gd (loaded after the autoloads exist). Writes the Phase-7 W1 fixtures (docs/PHASE7_DESIGN.md §12 W0) from the contract tables of §2 and the
## five new data/config files (class defaults = contract values):
##   godot --headless --path . -s res://tests/fixtures/phase7/make_phase7_fixtures.gd
## Historical tool of W0 (Lead) – the fixtures are the contract snapshot; W1 tests load them, owners
## never regenerate them for balancing (the data files under data/ belong to the owners).

const OUT := "res://tests/fixtures/phase7"
const ITEMS_OUT := "res://tests/fixtures/items"

var _failed := false


func run() -> bool:
	_configs()
	_extended_configs()
	_regions()
	_villagers()
	_schedules()
	_shops()
	_orders()
	_findings()
	_teachings()
	_deductions()
	_medicines()
	_sets()
	_items()
	_recipes_and_station()
	_section()
	_story()
	_journal()
	_interiors()
	return not _failed


# --- helpers ------------------------------------------------------------------------------------

## Every script variable written explicitly (ResourceSaver drops values equal to the class default –
## a fixture must not follow later changes of a class default). Schedules (sub-resources) go through
## ResourceSaver.
func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if res is NpcSchedule:
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


static func _si(d: Dictionary) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for k: Variant in d:
		out[StringName(str(k))] = int(d[k])
	return out


static func _sn(list: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for v: Variant in list:
		out.append(StringName(str(v)))
	return out


static func _hm(text: String) -> int:
	var p := text.split(":")
	return int(p[0]) * 60 + int(p[1])


# --- data/config + fixtures of the new configs ----------------------------------------------------

func _configs() -> void:
	var pairs := {
		&"village_config": VillageConfig.new(), &"relationship_config": RelationshipConfig.new(),
		&"orders_config": OrdersConfig.new(), &"anatomy_config": AnatomyConfig.new(), &"npc_config": NpcConfig.new(),
	}
	for name: StringName in pairs:
		_save(pairs[name], "res://data/config/%s.tres" % name)
		_save((pairs[name] as Resource).duplicate(true), OUT + "/%s_fixture.tres" % name)


## Phase-7 values of existing configs (fixtures only; the data files belong to their owners).
func _extended_configs() -> void:
	var eco := (load("res://tests/fixtures/phase6/economy_config_fixture.tres") as EconomyConfig).duplicate(true) as EconomyConfig
	eco.harvest_malus = EconomyConfig.new().harvest_malus
	_save(eco, OUT + "/economy_config_fixture.tres")
	var rep := (load("res://tests/fixtures/phase6/reputation_config_fixture.tres") as ReputationConfig).duplicate(true) as ReputationConfig
	rep.event_points = ReputationConfig.new().event_points
	_save(rep, OUT + "/reputation_config_fixture.tres")
	var piety := (load("res://tests/fixtures/phase6/piety_config_fixture.tres") as PietyConfig).duplicate(true) as PietyConfig
	piety.events = PietyConfig.new().events
	_save(piety, OUT + "/piety_config_fixture.tres")
	var prep := (load("res://tests/fixtures/phase5/prep_config_fixture.tres") as PrepConfig).duplicate(true) as PrepConfig
	prep.balm_items = _sn([&"juniper", &"herb_bundle", &"corpse_balm"])
	_save(prep, OUT + "/prep_config_fixture.tres")
	var shed := (load("res://tests/fixtures/phase6/shed_config_fixture.tres") as ShedConfig).duplicate(true) as ShedConfig
	shed.excluded_items = _sn([&"bone_box_full", &"bone_box", &"altar_candle", &"specimen_jar", &"specimen_bundle",
			&"display_specimen", &"bone_specimen"])
	_save(shed, OUT + "/shed_config_fixture.tres")
	var tables := (load("res://data/corpses/corpse_tables.tres") as CorpseTables).duplicate(true) as CorpseTables
	tables.hidden_causes = {
		&"fever": [{"id": &"arsenic", "chance": 0.12}],
		&"drowned_millpond": [{"id": &"dead_before_water", "chance": 0.15}],
		&"old_age": [{"id": &"drink", "chance": 0.15}],
	}
	_save(tables, OUT + "/corpse_tables_fixture.tres")
	var lines := (load("res://tests/fixtures/phase6/ghost_lines_fixture.tres") as GhostLines).duplicate(true) as GhostLines
	lines.by_organ = PackedStringArray(["In mir ist eine Stelle, die nicht mehr warm wird.",
			"Mein Name steht auf einem Etikett. Wer liest ihn?",
			"Sie haben mich in der Stadt in ein Regal gestellt. Ich kann die Linde nicht sehen.",
			"Ich sehe die Linde nicht mehr. Ich weiß nur, dass sie da ist.",
			"Ich greife nach etwas und weiß nicht, womit."])
	lines.by_returned = PackedStringArray(["Es ist wieder da. Ich spüre es nicht, aber ich weiß es.",
			"Du hast zurückgebracht, was du genommen hast. Das tun nicht viele."])
	_save(lines, OUT + "/ghost_lines_fixture.tres")


func _regions() -> void:
	var g := RegionConfig.new()
	g.region_id = &"graveyard"
	g.display_name = "Friedhof"
	g.arrive_text = "Friedhof auf dem Hügel"
	g.origin = Vector3.ZERO
	g.camera_distance = 22.0
	g.camera_zoom_min = 12.0
	g.camera_zoom_max = 24.0
	# The graveyard's camera bounds stay those of the layout (camera_bounds); W-Welt copies them.
	g.bounds_min = Vector2(-22.0, -20.0)
	g.bounds_max = Vector2(22.0, 23.0)
	g.managed_paths = PackedStringArray(["Decor", "Lights", "Grass"])
	_save(g, OUT + "/regions/graveyard.tres")
	var v := RegionConfig.new()
	v.region_id = &"village"
	v.display_name = "Hollerbrück"
	v.arrive_text = "Hollerbrück · Anger"
	v.origin = Vector3(0, 0, 400)
	v.camera_distance = 22.0
	v.camera_zoom_min = 12.0
	v.camera_zoom_max = 24.0
	v.bounds_min = Vector2(-22.0, -8.0)
	v.bounds_max = Vector2(20.0, 8.0)
	v.managed_paths = PackedStringArray(["."])
	_save(v, OUT + "/regions/village.tres")


# --- villagers §2.1 ------------------------------------------------------------------------------

const VILLAGERS := [
	["innkeeper", "Rosine Wackernagel", "Wirtin des Holderkrugs", "inn", "door_inn", ["honey_cake", "herb_bundle"], 25, 0, 0, false],
	["smith", "Ulrich Esch", "Schmied", "smith", "", ["elder_wine", "iron_ore"], 15, 0, 0, false],
	["grocer", "Theres Mangold", "Krämerin", "grocer", "", ["herbs", "elderberries"], 20, 0, 0, false],
	["priest", "Ambrosius Lenz", "Pfarrer von St. Gallus", "priest", "", ["elder_wine", "honey_cake"], 25, -4, 1, true],
	["mayor", "Gottlieb Fenner", "Schultheiß", "", "door_office", ["ink", "honey_cake"], 30, 0, 0, false],
	["surgeon", "Severin Quast", "Wundarzt und Geburtshelfer", "surgeon", "door_surgery", ["spirits", "herb_bundle"], 20, 2, 0, false],
	["washer", "Liesel Dorn", "Seelfrau und Spinnerin", "washer", "", ["linen", "honey_cake"], 10, -3, 2, true],
	["oldwoman", "Wiebke Hagedorn", "Altenteilerin", "", "", ["seeds", "honey_cake"], 30, -2, 0, false],
]
## Leading remark lines of §2.4 (W0 drafts – P2 writes 6–8 per person).
const REMARKS := {
	&"innkeeper": {&"rep_disreputable": ["Du bist der vom Hügel. Setz dich ans Fenster, da sieht dich keiner."],
			&"rep_respected": ["Der Totengräber. Grüß Gott."],
			&"rep_renowned": ["Wackernagel hat für dich einen Stuhl am Ofen frei. Den kriegt sonst nur der Pfarrer."]},
	&"smith": {&"rep_disreputable": ["Das ist der, bei dem die Taschen leichter werden."], &"rep_respected": ["Totengräber."]},
	&"grocer": {&"rep_disreputable": ["Das ist der, bei dem die Taschen leichter werden."], &"rep_respected": ["Der Totengräber. Grüß Gott."]},
	&"priest": {&"rep_respected": ["Der Totengräber. Grüß Gott."], &"specimens": ["Quast hat wieder Post vom Hügel, sagt man."]},
	&"mayor": {&"rep_respected": ["Der Totengräber. Grüß Gott."]},
	&"surgeon": {&"rep_respected": ["Die Toten lehren die Lebenden."]},
	&"washer": {&"piety_devout": ["Du riechst nach Wacholder. Das ist ein guter Geruch für einen wie dich."],
			&"rep_respected": ["Der Totengräber. Grüß Gott."]},
	&"oldwoman": {&"rep_respected": ["Der Totengräber. Grüß Gott."]},
}


func _villagers() -> void:
	for v: Array in VILLAGERS:
		var d := VillagerData.new()
		d.npc_id = StringName(v[0])
		d.display_name = v[1]
		d.role = v[2]
		d.dialogue_id = StringName("v_" + String(v[0]))
		d.shop_id = StringName(v[3])
		d.home_door = StringName(v[4])
		d.gifts_liked = _sn(v[5])
		d.start_value = v[6]
		d.specimen_delta = v[7]
		d.returned_delta = v[8]
		d.piety_sensitive = v[9]
		var remarks: Dictionary[StringName, PackedStringArray] = {}
		var src: Dictionary = REMARKS.get(d.npc_id, {})
		for key: Variant in src:
			remarks[StringName(str(key))] = PackedStringArray(src[key])
		d.remarks = remarks
		_save(d, OUT + "/villagers/%s.tres" % v[0])


# --- schedules §2.2 (region village; the priest's consecration day on the graveyard) ----------------

## [start, travel, activity, animation, path, dialogue, visible, region, today_flag]
func _entry(spec: Array) -> ScheduleEntry:
	var e := ScheduleEntry.new()
	e.start_minute = _hm(spec[0])
	e.travel_minutes = spec[1]
	e.activity = StringName(spec[2])
	e.animation = StringName(spec[3])
	e.path = PackedStringArray(spec[4])
	e.dialogue_id = StringName(spec[5])
	e.visible = spec[6]
	e.region = StringName(spec[7]) if spec.size() > 7 else &"village"
	e.today_flag = StringName(spec[8]) if spec.size() > 8 else &""
	return e


const SCHEDULES := {
	&"innkeeper": [
		["00:00", 0, "home", "idle", ["v_inn_door"], "", false],
		["06:00", 10, "walk", "walk", ["v_inn_door", "v_well"], "", true],
		["06:10", 0, "idle", "talk", ["v_well"], "v_innkeeper", true],
		["06:40", 10, "walk", "walk", ["v_well", "v_inn_door"], "", true],
		["06:50", 0, "shop", "idle", ["v_in_inn_bar"], "v_innkeeper", true],
		["23:30", 0, "home", "idle", ["v_inn_door"], "", false]],
	&"smith": [
		["00:00", 0, "home", "idle", ["v_house_n"], "", false],
		["06:30", 10, "walk", "walk", ["v_house_n", "v_anger_w", "v_anvil"], "", true],
		["06:40", 0, "shop", "work", ["v_anvil"], "v_smith", true],
		["12:00", 0, "idle", "idle", ["v_in_inn_table"], "v_smith", true],
		["13:00", 6, "walk", "walk", ["v_inn_door", "v_anger_w", "v_anvil"], "", true],
		["13:06", 0, "shop", "work", ["v_anvil"], "v_smith", true],
		["17:30", 4, "walk", "walk", ["v_anvil", "v_linden"], "", true],
		["17:34", 0, "idle", "idle", ["v_linden"], "v_smith", true],
		["19:00", 0, "home", "idle", ["v_house_n"], "", false]],
	&"grocer": [
		["00:00", 0, "home", "idle", ["v_shop_window"], "", false],
		["07:25", 0, "shop", "work", ["v_shop_window"], "v_grocer", true],
		["14:00", 5, "walk", "walk", ["v_shop_window", "v_well"], "", true],
		["14:05", 0, "idle", "talk", ["v_well"], "v_grocer", true],
		["14:30", 5, "walk", "walk", ["v_well", "v_shop_window"], "", true],
		["14:35", 0, "shop", "work", ["v_shop_window"], "v_grocer", true],
		["18:00", 0, "home", "idle", ["v_shop_window"], "", false]],
	&"priest": [
		["00:00", 0, "home", "idle", ["v_church_door"], "", false],
		["08:00", 0, "shop", "idle", ["v_church_door"], "v_priest", true],
		["11:30", 8, "walk", "walk", ["v_church_door", "v_well", "v_hagedorn_gate"], "", true],
		["11:38", 0, "home", "idle", ["v_hagedorn_gate"], "", false],
		["16:00", 0, "shop", "idle", ["v_church_door"], "v_priest", true],
		["18:00", 10, "walk", "walk", ["v_church_door", "v_inn_door"], "", true],
		["18:10", 0, "idle", "idle", ["v_in_inn_table"], "v_priest", true],
		["20:00", 0, "home", "idle", ["v_church_door"], "", false],
		# The consecration day (§2.9): up the coach road to the Lindenacker and back (graveyard region).
		["08:40", 40, "walk", "walk", ["road_end", "road_mid", "gate_outside", "dropoff", "w_east_pass", "w_linden_n", "linden_spot"], "", true, "", "linden_consecration_day"],
		["09:20", 0, "bless", "talk", ["linden_spot"], "priest_linden", true, "", "linden_consecration_day"],
		["10:30", 40, "walk", "walk", ["linden_spot", "w_linden_n", "w_east_pass", "dropoff", "gate_outside", "road_mid", "road_end"], "", true, "", "linden_consecration_day"],
		["11:10", 0, "home", "idle", ["road_end"], "", false, "", "linden_consecration_day"]],
	&"mayor": [
		["00:00", 0, "home", "idle", ["v_office_door"], "", false],
		["07:55", 0, "idle", "idle", ["v_in_office_desk"], "v_mayor", true],
		["12:00", 20, "walk", "walk", ["v_office_door", "v_well", "v_anger_w", "v_board"], "", true],
		["12:20", 0, "idle", "idle", ["v_board"], "v_mayor", true],
		["13:00", 5, "walk", "walk", ["v_board", "v_office_door"], "", true],
		["13:05", 0, "idle", "idle", ["v_in_office_desk"], "v_mayor", true],
		["16:00", 5, "walk", "walk", ["v_office_door", "v_board"], "", true],
		["16:05", 0, "idle", "idle", ["v_board"], "v_mayor", true],
		["18:00", 5, "walk", "walk", ["v_board", "v_inn_door"], "", true],
		["18:05", 0, "idle", "idle", ["v_in_inn_table"], "v_mayor", true],
		["21:00", 0, "home", "idle", ["v_office_door"], "", false]],
	&"surgeon": [
		["00:00", 0, "home", "idle", ["v_surgery_door"], "", false],
		["07:55", 0, "shop", "idle", ["v_in_surgery_desk"], "v_surgeon", true],
		["12:00", 10, "walk", "walk", ["v_surgery_door", "v_anger_w", "v_house_n"], "", true],
		["12:10", 0, "home", "idle", ["v_house_n"], "", false],
		["13:50", 10, "walk", "walk", ["v_house_n", "v_anger_w", "v_surgery_door"], "", true],
		["14:00", 0, "shop", "idle", ["v_in_surgery_desk"], "v_surgeon", true],
		["18:00", 6, "walk", "walk", ["v_surgery_door", "v_well", "v_bridge"], "", true],
		["18:06", 0, "idle", "idle", ["v_bridge"], "v_surgeon", true],
		["19:30", 0, "home", "idle", ["v_surgery_door"], "", false]],
	&"washer": [
		["00:00", 0, "home", "idle", ["v_dorn_door"], "", false],
		["06:30", 8, "walk", "walk", ["v_dorn_door", "v_wash"], "", true],
		["06:38", 0, "idle", "work", ["v_wash"], "v_washer", true],
		["09:00", 0, "home", "idle", ["v_dorn_door"], "", false],
		["12:00", 0, "shop", "work", ["v_dorn_door"], "v_washer", true],
		["15:00", 5, "walk", "walk", ["v_dorn_door", "v_well"], "", true],
		["15:05", 0, "idle", "talk", ["v_well"], "v_washer", true],
		["16:30", 5, "walk", "walk", ["v_well", "v_dorn_door"], "", true],
		["16:35", 0, "shop", "work", ["v_dorn_door"], "v_washer", true],
		["19:00", 0, "home", "idle", ["v_dorn_door"], "", false]],
	&"oldwoman": [
		["00:00", 0, "home", "idle", ["v_hagedorn_gate"], "", false],
		["09:00", 6, "walk", "walk", ["v_hagedorn_gate", "v_well_bench"], "", true],
		["09:06", 0, "idle", "sit", ["v_well_bench"], "v_oldwoman", true],
		["11:00", 6, "walk", "walk", ["v_well_bench", "v_hagedorn_gate"], "", true],
		["11:06", 0, "home", "idle", ["v_hagedorn_gate"], "", false],
		["14:00", 0, "idle", "idle", ["v_hagedorn_gate"], "v_oldwoman", true],
		["17:00", 0, "home", "idle", ["v_hagedorn_gate"], "", false]],
}
## Osric's village entries (§2.2): added to the unchanged graveyard entries of carter_schedule.tres.
const CARTER_VILLAGE := [
	["11:10", 8, "walk", "walk", ["v_road_in", "v_bridge", "v_anger_w", "v_remise"], "", true],
	["11:18", 0, "idle", "idle", ["v_remise"], "carter_village", true],
	["14:00", 5, "walk", "walk", ["v_remise", "v_inn_door"], "", true],
	["14:05", 0, "idle", "idle", ["v_in_inn_corner"], "carter_village", true],
	["17:30", 0, "home", "idle", ["v_road_in"], "", false],
	["22:00", 0, "idle", "idle", ["v_in_inn_corner"], "carter_village", true],
	["23:30", 0, "home", "idle", ["v_road_in"], "", false],
]


func _schedules() -> void:
	for npc: StringName in SCHEDULES:
		var s := NpcSchedule.new()
		s.npc_id = npc
		s.display_name = _villager_name(npc)
		var entries: Array[ScheduleEntry] = []
		for spec: Array in SCHEDULES[npc]:
			entries.append(_entry(spec))
		s.entries = entries
		_save(s, OUT + "/schedules/%s_schedule.tres" % npc)
	var carter := (load("res://data/npc/carter_schedule.tres") as NpcSchedule).duplicate(true) as NpcSchedule
	var all: Array[ScheduleEntry] = carter.entries.duplicate()
	for spec: Array in CARTER_VILLAGE:
		all.append(_entry(spec))
	carter.entries = all
	_save(carter, OUT + "/schedules/carter_schedule.tres")


func _villager_name(npc: StringName) -> String:
	for v: Array in VILLAGERS:
		if StringName(v[0]) == npc:
			return v[1]
	return ""


# --- shops §2.3 ------------------------------------------------------------------------------------

const SHOPS := {
	&"grocer": ["Krämerladen", "grocer",
		{"linen": [3, 6], "seeds": [1, 6], "juniper": [2, 4], "altar_candle": [2, 4], "prep_jar": [2, 4], "beeswax": [1, 4],
			"honey_cake": [1, 4], "gold_leaf": [6, 1, "friend"]},
		{"herbs": [1, 8], "elderberries": [1, 8], "herb_bundle": [3, 4], "wound_salve": [4, 3], "yarn": [1, 6]}],
	&"smith": ["Schmiede", "smith",
		{"iron_fittings": [3, 6], "iron_bar": [6, 2], "steel_rod": [6, 2]},
		{"iron_ore": [1, 6], "charcoal": [1, 8]}],
	&"inn": ["Holderkrug", "innkeeper", {"spirits": [3, 4], "elder_wine": [2, 3]}, {"elderberries": [2, 10], "herbs": [1, 4]}],
	&"priest": ["Kirchentür", "priest", {"altar_candle": [2, 6]}, {}],
	&"surgeon": ["Wundarztstube", "surgeon", {"prep_jar": [2, 4], "prep_jar_small": [3, 4], "spirits": [3, 2]},
		{"fever_tincture": [6, 3], "wound_salve": [5, 2], "antidote": [7, 2], "bitter_drops": [6, 2], "dropsy_powder": [8, 2]}],
	&"washer": ["Liesels Spinnplatz", "washer", {"yarn": [1, 4], "linen": [2, 2]}, {"burial_gown": [6, 2], "shroud": [3, 2]}],
}


func _shops() -> void:
	for id: StringName in SHOPS:
		var spec: Array = SHOPS[id]
		var s := ShopData.new()
		s.id = id
		s.title = spec[0]
		s.npc_id = StringName(spec[1])
		var sells: Dictionary[StringName, Dictionary] = {}
		for item: String in spec[2]:
			var row: Array = spec[2][item]
			var d := {"price": row[0], "per_day": row[1]}
			if row.size() > 2:
				d["requires_tier"] = StringName(row[2])
			sells[StringName(item)] = d
		s.sells = sells
		var buys: Dictionary[StringName, Dictionary] = {}
		for item: String in spec[3]:
			var row: Array = spec[3][item]
			buys[StringName(item)] = {"price": row[0], "per_day": row[1]}
		s.buys = buys
		_save(s, OUT + "/shops/%s.tres" % id)


# --- orders §2.5 -------------------------------------------------------------------------------------

## id: [giver, kind, title, request, items, coins, target, conditions, days, requires_flag, requires_orders,
##      requires_tier, reward_coins, reward_rel, reward_rep, extra_rel, fail_rel, board, recipient, accept_flag]
const ORDERS := [
	["o_fenner_linden", "mayor", "section", "Der Lindenacker", "Pforte, Stümpfe, Brombeeren und Steine räumen. Die Gemeinde gibt das Land, wenn du es urbar machst.",
		{}, 0, "linden", {}, 0, "", [], "", 0, 8, 2, {}, {}, false, "", "linden_granted"],
	["o_fenner_well", "mayor", "deliver", "Die Brunnenfassung", "Vier Werksteine für die neue Brunnenfassung. Gib sie beim Schmied ab.",
		{"workstone": 4}, 0, "", {}, 4, "", [], "", 6, 6, 1, {"smith": 4}, {}, false, "smith", ""],
	["o_fenner_bridge", "mayor", "donate", "Die Holderbrücke", "Zwanzig Münzen und sechs Bretter für neue Bohlen.",
		{"wood": 6}, 20, "", {}, 6, "", ["o_fenner_well"], "", 0, 10, 3, {}, {}, false, "", ""],
	["o_rosine_berries", "innkeeper", "deliver", "Holunder für den Wein", "Acht Hände voll Holunderbeeren für den Holunderwein.",
		{"elderberries": 8}, 0, "", {}, 5, "", [], "", 6, 8, 0, {}, {}, false, "", ""],
	["o_rosine_tincture", "innkeeper", "deliver", "Fieber im Haus", "Jakob fiebert, und der Quast nimmt zu viel.",
		{"fever_tincture": 2}, 0, "", {"substitutes": {"fever_tincture": "bitter_drops"}}, 4, "", ["o_rosine_berries"], "", 8, 10, 0, {}, {}, false, "", ""],
	["o_esch_charcoal", "smith", "deliver", "Kohle für die Esse", "Sechs Säcke Holzkohle.",
		{"charcoal": 6}, 0, "", {}, 5, "", [], "", 7, 8, 0, {}, {}, false, "", ""],
	["o_esch_stone", "smith", "stone", "Ein Stein für den Meister", "Wendel Gratz war mein Lehrmeister. Ein Bogenstein mit einer Fackel.",
		{}, 0, "old_01", {"stone_shape": "stone_arch", "ornament": "orn_torch"}, 6, "", ["o_esch_charcoal"], "acquainted", 10, 10, 1, {}, {}, false, "", ""],
	["o_mangold_stone", "grocer", "stone", "Ein Stein für die Mutter", "Dorothee Mahn. Eine Stele mit Mohn, und etwas soll darauf stehen.",
		{}, 0, "old_08", {"stone_shape": "stone_stele", "ornament": "orn_poppy", "inscription": true}, 6, "", [], "acquainted", 12, 10, 1, {}, {}, false, "", ""],
	["o_lenz_service", "priest", "bury", "Eine Aussegnung", "Die nächste, die man dir bringt: eingekleidet und ausgesegnet, mit Trauergästen.",
		{}, 0, "next_delivery", {"service": true, "chapel_level": 2}, 3, "linden_consecrated", [], "", 6, 8, 1, {}, {}, false, "", ""],
	["o_lenz_poor", "priest", "donate", "Armenspeisung", "Zwölf Münzen und vier Honigkuchen für die Armenspeisung.",
		{"honey_cake": 4}, 12, "", {}, 5, "", [], "trusted", 0, 8, 2, {}, {}, false, "", ""],
	["o_quast_tincture", "surgeon", "deliver", "Fiebertinktur", "Zwei Fläschchen Fiebertinktur.",
		{"fever_tincture": 2}, 0, "", {}, 5, "", [], "", 10, 8, 0, {}, {}, false, "", ""],
	["o_quast_specimen", "surgeon", "deliver", "Für das Kabinett", "Ein Präparat im Glas – Herz, Lunge, Magen, Leber oder Nieren –, gut lesbar.",
		{"specimen_jar": 1}, 0, "", {"min_clarity": 0.6, "organ": ["heart", "lung", "stomach", "liver", "kidneys"]}, 6, "anatomy_known", [], "", 10, 10, 0, {}, {}, false, "", ""],
	["o_quast_antidote", "surgeon", "deliver", "Rattengift", "Der kleine Kehr hat vom Rattengift genascht. Ich habe nicht genug.",
		{"antidote": 2}, 0, "", {"teaching": "l_stomach"}, 2, "anatomy_known", [], "", 12, 8, 1, {"innkeeper": 4}, {}, false, "", ""],
	["o_fenner_dropsy", "mayor", "deliver", "Die Beine des Schultheißen", "Meine Beine, Totengräber. Sagen Sie es keinem.",
		{"dropsy_powder": 1}, 0, "", {}, 5, "anatomy_known", [], "trusted", 10, 8, 0, {}, {}, false, "", ""],
	["o_quast_cabinet", "surgeon", "deliver", "Für die Universität", "Ein Schaupräparat für das Kabinett der Universität.",
		{"display_specimen": 1}, 0, "", {"standing": 2}, 6, "anatomy_known", [], "", 14, 10, 0, {}, {}, false, "", ""],
	["o_liesel_gowns", "washer", "deliver", "Totenhemden", "Zwei Totenhemden – für die, die nicht zu dir hinaufkommen.",
		{"burial_gown": 2}, 0, "", {}, 6, "", [], "acquainted", 8, 8, 0, {}, {}, false, "", ""],
	["o_hagedorn_place", "oldwoman", "bury", "Wiebke Hagedorns letzter Wunsch", "Oben liegen, mit Blick auf die Linde. Im Totenhemd, und ein Stein mit Mohn.",
		{}, 0, "d1_hagedorn", {"section": "linden", "dress": "gown", "ornament": "orn_poppy", "unharvested": true}, 3, "", [], "", 10, 0, 2, {"washer": 8}, {"washer": -10, "priest": -5}, false, "washer", ""],
	["ob_wood", "council", "deliver", "Holz für den Gemeindezaun", "Zehn Scheite für den Gemeindezaun.",
		{"wood": 10}, 0, "", {}, 1, "village_open", [], "", 5, 0, 0, {"mayor": 3}, {}, true, "mayor", ""],
	["ob_stone", "council", "deliver", "Steine für den Kirchweg", "Acht Steine für den Weg zur Kirche.",
		{"stone": 8}, 0, "", {}, 1, "village_open", [], "", 5, 0, 0, {"mayor": 3}, {}, true, "mayor", ""],
	["ob_herbs", "council", "deliver", "Kräuter für die Armen", "Vier Räucherkräuter für die Armen im Winter.",
		{"herb_bundle": 4}, 0, "", {}, 1, "village_open", [], "", 8, 0, 0, {"surgeon": 3}, {}, true, "surgeon", ""],
	["ob_yarn", "council", "deliver", "Garn für die Spinnstube", "Sechs Knäuel Garn.",
		{"yarn": 6}, 0, "", {}, 1, "village_open", [], "", 5, 0, 0, {"washer": 3}, {}, true, "washer", ""],
	["ob_gown", "council", "bury", "Im Totenhemd", "Die nächste, die man dir bringt, im Totenhemd.",
		{}, 0, "next_delivery", {"dress": "gown"}, 2, "linden_consecrated", [], "", 4, 0, 1, {}, {}, true, "", ""],
	["ob_tend", "council", "tend", "Der Lindenacker gepflegt", "Alle belegten Gräber im Lindenacker an zwei Morgen in Folge ohne Pflegeabzug.",
		{}, 0, "linden", {"mornings": 2}, 4, "linden_consecrated", [], "", 5, 0, 1, {}, {}, true, "", ""],
]


func _orders() -> void:
	var n := 0
	for spec: Array in ORDERS:
		n += 1
		var o := OrderData.new()
		o.id = StringName(spec[0])
		o.giver = StringName(spec[1])
		o.kind = StringName(spec[2])
		o.title = spec[3]
		o.request_text = spec[4]
		o.thanks_text = "Danke, Totengräber."
		o.items = _si(spec[5])
		o.coins = spec[6]
		o.target = spec[7]
		o.conditions = spec[8]
		o.days_limit = spec[9]
		o.requires_flag = StringName(spec[10])
		o.requires_orders = _sn(spec[11])
		o.requires_tier = StringName(spec[12])
		o.reward_coins = spec[13]
		o.reward_rel = spec[14]
		o.reward_rep = spec[15]
		o.extra_rel = _si(spec[16])
		o.fail_rel = _si(spec[17])
		o.board = spec[18]
		o.recipient = StringName(spec[19])
		o.accept_flag = StringName(spec[20])
		o.order = n
		_save(o, OUT + "/orders/%s.tres" % spec[0])


# --- anatomy §2.6.3 / §2.6.5 / §2.7 --------------------------------------------------------------------

## [id, organ, priority, hidden_cause, cause_id, requires_trait, text]
## W0-Notizen: hidden_cause and cause_id are ALTERNATIVES – a finding with a cause condition matches when
## the record's effective cause (hidden_cause if set, else cause_id) equals one of its non-empty two
## fields („arsenic oder poisoned", „moor_cold oder drowned_millpond"). b_stones („Seed 1 von 4") has
## no data field: SpecimenRules (P4) rolls it from the corpse seed.
const FINDINGS := [
	["b_still_heart", "heart", 30, "", "", "strange_wound", "Ein gesundes Herz. Keine Narbe, kein Fett, keine Schwäche."],
	["b_old_heart", "heart", 20, "", "old_age", "", "Ein großes, müdes Herz."],
	["b_white_stomach", "stomach", 30, "arsenic", "poisoned", "", "Ein weißlicher Belag. Es riecht nach Knoblauch."],
	["b_empty_stomach", "stomach", 10, "", "", "", "Leer. Die letzten Tage kaum gegessen."],
	["b_dry_lungs", "lung", 30, "dead_before_water", "", "", "Die Lunge ist trocken."],
	["b_wet_lungs", "lung", 20, "", "drowned_millpond", "", "Die Lunge ist schwer von Wasser."],
	["b_spotted_lungs", "lung", 20, "", "fever", "", "Fleckig, mit kleinen dunklen Herden."],
	["b_hard_liver", "liver", 30, "drink", "", "", "Hart und gelblich, mit kleinen Knoten."],
	["b_pale_liver", "liver", 30, "arsenic", "poisoned", "", "Blass, mit feinen weißen Streifen."],
	["b_stones", "kidneys", 20, "", "", "", "Zwei Steine, so groß wie Erbsen."],
	["b_moor_eyes", "eyes", 30, "drowned_millpond", "moor_cold", "", "Die Augen sind trüb, mit einem braunen Schleier."],
	["b_fever_eyes", "eyes", 20, "", "fever", "", "Gelblich und glasig."],
	["b_oath_hand", "hand", 30, "", "", "tattoo", "Eine alte Schnittnarbe quer über der Handfläche."],
	["b_worker_hand", "hand", 10, "", "", "", "Schwielen an Daumen und Zeigefinger. Ein Handwerk."],
	["b_plain", "", 0, "", "", "", "Nichts Auffälliges."],
]


func _findings() -> void:
	for spec: Array in FINDINGS:
		var f := SpecimenFindingData.new()
		f.id = StringName(spec[0])
		f.organ = StringName(spec[1])
		f.priority = spec[2]
		f.hidden_cause = StringName(spec[3])
		f.cause_id = StringName(spec[4])
		f.requires_trait = StringName(spec[5])
		f.text = spec[6]
		_save(f, OUT + "/findings/%s.tres" % spec[0])


const TEACHINGS := [
	["l_lung", "lung", "Wasser in der Lunge", "Wer ertrinkt, atmet Wasser."],
	["l_liver", "liver", "Die harte Leber", "Der Trunk macht die Leber hart."],
	["l_heart", "heart", "Das stille Herz", "Ein gesundes Herz bleibt nicht ohne Grund stehen."],
	["l_stomach", "stomach", "Der weiße Magen", "Arsenik bleicht den Magen und riecht nach Knoblauch."],
	["l_kidneys", "kidneys", "Steine", "Steine machen Schmerzen, aber selten den Tod."],
	["l_eyes", "eyes", "Moorblick", "Das Moor färbt die Augen."],
	["l_hand", "hand", "Was die Hand erzählt", "Die Hand erzählt das Handwerk."],
]


func _teachings() -> void:
	for spec: Array in TEACHINGS:
		var t := TeachingData.new()
		t.id = StringName(spec[0])
		t.organ = StringName(spec[1])
		t.title = spec[2]
		t.text = spec[3]
		_save(t, OUT + "/teachings/%s.tres" % spec[0])


## [id, cause, needs_any, needs_all, clue, text, reveals_cause]
const DEDUCTIONS := [
	["d_arsenic", "arsenic", ["b_white_stomach", "b_pale_liver"], ["l_stomach"], "c_v_arsenic", "Gedeutet: Arsenik.", true],
	["d_dry_lungs", "dead_before_water", [], ["b_dry_lungs", "l_lung"], "c_v_dry_lungs", "Gedeutet: tot, bevor sie ins Wasser kam.", true],
	["d_still_heart", "unexplained", [], ["b_still_heart", "l_heart", "f_mark"], "c_v_still_heart", "Ein Herz ohne Krankheit. Kein natürlicher Tod.", true],
	["d_drink", "drink", [], ["b_hard_liver", "l_liver"], "", "Gedeutet: der Trunk.", true],
	["d_moor", "moor_cold", ["f_cause_moor_cold", "f_cause_drowned_millpond"], ["b_moor_eyes", "l_eyes"], "", "Das Moor. Wie Osric sagte.", false],
]


func _deductions() -> void:
	for spec: Array in DEDUCTIONS:
		var d := DeductionData.new()
		d.id = StringName(spec[0])
		d.cause_id = StringName(spec[1])
		d.needs_any = _sn(spec[2])
		d.needs_all = _sn(spec[3])
		d.clue_id = StringName(spec[4])
		d.text = spec[5]
		d.reveals_cause = spec[6]
		_save(d, OUT + "/deductions/%s.tres" % spec[0])


func _medicines() -> void:
	var specs := [
		["antidote", ["stomach", "liver"], {"herb_bundle": 1, "spirits": 1}, 30, 2],
		["bitter_drops", ["liver"], {"herbs": 2, "spirits": 1}, 30, 2],
		["dropsy_powder", ["kidneys"], {"herbs": 1, "beeswax": 1}, 20, 1],
	]
	for spec: Array in specs:
		var m := MedicineData.new()
		m.id = StringName(spec[0])
		m.organs = _sn(spec[1])
		m.min_clarity = 0.45
		m.inputs = _si(spec[2])
		m.minutes = spec[3]
		m.output = StringName(spec[0])
		m.amount = spec[4]
		_save(m, OUT + "/medicines/%s.tres" % spec[0])


func _sets() -> void:
	var specs := [
		["set_chest", "Brustraum", ["heart", "lung"], false, 5, ""],
		["set_body", "Leib", ["stomach", "liver", "kidneys"], false, 6, ""],
		["set_senses", "Sinne und Hand", ["eyes", "hand"], false, 8, ""],
		["set_complete", "Lehrsammlung", ["heart", "lung", "stomach", "liver", "kidneys", "eyes", "hand"], true, 15, "university_letter"],
	]
	for spec: Array in specs:
		var s := CollectionSetData.new()
		s.id = StringName(spec[0])
		s.title = spec[1]
		s.organs = _sn(spec[2])
		s.needs_display = spec[3]
		s.reward_coins = spec[4]
		s.standing = 1
		s.sets_flag = StringName(spec[5])
		_save(s, OUT + "/sets/%s.tres" % spec[0])


# --- items §2.8, recipes / station §2.7 ---------------------------------------------------------------

## [id, name, category, stack, unique, description]
const ITEMS := [
	["prep_jar", "Präparatglas", 6, 10, false, "Ein Glas mit weitem Hals und einem Wachsdeckel. Leer wiegt es fast nichts."],
	["prep_jar_small", "Kleines Präparatglas", 6, 10, false, "Ein kleines, dunkles Glas mit zwei Siegeln. Man sieht nicht hinein."],
	["spirits", "Branntwein", 6, 10, false, "Klarer Branntwein aus dem Holderkrug. Hält, was man hineinlegt."],
	["beeswax", "Bienenwachs", 6, 10, false, "Ein Block gelbes Wachs von der Krämerin. Für Salben und Siegel."],
	["anatomy_case", "Präparierbesteck", 4, 1, false, "Eine geschlossene Ledertasche von Quast. Man öffnet sie nur am Tisch."],
	["specimen_jar", "Präparat im Glas", 5, 1, true, "Ein trübes Glas mit Wachsdeckel. Auf dem Etikett steht ein Name."],
	["specimen_bundle", "Präparat im Bündel", 5, 1, true, "In Leinen geschlagen und verschnürt. Es hält nicht lange."],
	["bone_specimen", "Knochenpräparat", 5, 1, true, "Ein geschlossener Holzkasten mit einem Leinenpaket darin und einem Etikett."],
	["antidote", "Gegengift", 1, 5, false, "Ein beschriftetes Fläschchen: Gegengift, nach Quast."],
	["bitter_drops", "Bittertropfen", 1, 5, false, "Ein beschriftetes Fläschchen: Bittertropfen, nach Quast."],
	["dropsy_powder", "Wassersuchtpulver", 1, 5, false, "Ein gefaltetes Pulverbriefchen: gegen die Wassersucht, nach Quast."],
	["display_specimen", "Schaupräparat", 5, 1, true, "Eine Glasglocke auf einem Holzsockel, versiegelt. Das Etikett trägt einen Namen."],
	["fever_tincture", "Fiebertinktur", 1, 5, false, "Kräuter und Holunder in Branntwein. Senkt das Fieber, wenn man Glück hat."],
	["wound_salve", "Wundsalbe", 1, 10, false, "Eine Dose Salbe aus Kräutern und Wachs."],
	["corpse_balm", "Totensalbe", 6, 10, false, "Kräuter in Wachs gerührt. Hält den Verfall zurück wie Wacholder, ohne Rauch."],
	["honey_cake", "Honigkuchen", 5, 10, false, "Ein Stück Honigkuchen von der Krämerin, in Papier gewickelt."],
	["elder_wine", "Holunderwein", 5, 5, false, "Dunkler Holunderwein aus dem Holderkrug."],
]


func _items() -> void:
	for spec: Array in ITEMS:
		var it := ItemData.new()
		it.id = StringName(spec[0])
		it.display_name = spec[1]
		it.category = spec[2]
		it.max_stack = spec[3]
		it.unique = spec[4]
		it.description = spec[5]
		_save(it, ITEMS_OUT + "/%s.tres" % spec[0])


func _recipes_and_station() -> void:
	var specs := [
		["fever_tincture", "Fiebertinktur ansetzen", {"herbs": 2, "elderberries": 1, "spirits": 1}, "fever_tincture", 1, 30],
		["wound_salve", "Wundsalbe rühren", {"herb_bundle": 1, "beeswax": 1}, "wound_salve", 2, 20],
		["corpse_balm", "Totensalbe rühren", {"herbs": 2, "beeswax": 1}, "corpse_balm", 1, 20],
	]
	for spec: Array in specs:
		var r := RecipeData.new()
		r.id = StringName(spec[0])
		r.display_name = spec[1]
		r.inputs = _si(spec[2])
		r.output_id = StringName(spec[3])
		r.output_amount = spec[4]
		r.craft_minutes = spec[5]
		r.station = &"pult"
		r.category = &"material"
		_save(r, OUT + "/recipes/%s.tres" % spec[0])
	var st := StationData.new()
	st.id = &"pult"
	st.display_name = "Präparierpult"
	st.site_id = "pult"
	st.build_inputs = _si({"wood": 6, "iron_fittings": 2, "stone": 2})
	st.build_coins = 12
	st.build_minutes = 90
	st.panel = &"crafting"
	st.prompt_use = "[E] Präparierpult benutzen"
	st.build_text = "Ein Pult mit Schieferlade an der kalten Wand. Daneben ein Regal mit sieben Fächern hinter Tüchern."
	st.coin_part_label = "Glaswaren und Wachstuch von Quast"
	_save(st, OUT + "/stations/pult.tres")


# --- Lindenacker §2.9, D1, journal §1.6 ----------------------------------------------------------------

func _section() -> void:
	var s := SectionData.new()
	s.id = &"linden"
	s.display_name = "Lindenacker"
	s.order = 8
	s.starts_unlocked = false
	s.decor_cap = 6
	s.unlock_text = "Der Lindenacker ist geweiht. Acht Stellen unter der alten Linde."
	s.requires_flag = &"linden_granted"
	s.requires_flag_text = "Hier ist noch Gemeindewald."
	s.counts_for_cemetery = false
	s.is_burial = true
	s.unlock_flag = &"linden_consecrated"
	_save(s, OUT + "/sections/linden.tres")


func _story() -> void:
	var d := StoryCorpseData.new()
	d.id = &"d1_hagedorn"
	d.order = 6
	d.earliest_day = 1
	d.display_name = "Wiebke Hagedorn"
	d.age = 81
	d.cause_id = &"old_age"
	d.traits = _sn(["strange_wound"])
	d.valuables_coins = 0
	d.look = 1
	d.finds = _sn(["f_d1_poppy", "f_d1_mark", "f_d1_note"])
	d.arrival_note = "Die alte Hagedorn. Heute Nacht, im Schlaf, sagt Liesel. Sie hat mir letzte Woche aufgetragen, dir auszurichten: nicht trödeln. Ich richte es aus."
	d.after_flag = &"village_open_day"
	d.after_days = 8
	d.section = &"linden"
	d.requires_flag = &"linden_consecrated"
	d.due_flag = &"hagedorn_dead"
	_save(d, OUT + "/story/d1_hagedorn.tres")
	var finds := [
		["f_d1_poppy", "clothing", "Mohn am Mieder", "Getrockneter Mohn am Mieder, mit einem roten Faden gebunden.", 0.0, ""],
		["f_d1_mark", "wounds", "Das Zeichen, frisch verheilt", "Das Zeichen über ihrem Herzen ist frisch verheilt. Drei Wochen, nicht mehr. Sie hat es gewusst.", 0.3, "c_v_hagedorn"],
		["f_d1_note", "pockets", "Ein Zettel in der Schürze", "In der Schürze ein Zettel: ‚Für den Totengräber. Linde, Mohn, Totenhemd. Und schau nach, wer mich besucht hat. – W. H.‘", 0.0, ""],
	]
	for spec: Array in finds:
		var f := FindData.new()
		f.id = StringName(spec[0])
		f.step = StringName(spec[1])
		f.label = spec[2]
		f.text = spec[3]
		f.min_freshness = spec[4]
		f.story_only = true
		f.clue_id = StringName(spec[5])
		_save(f, OUT + "/finds/%s.tres" % spec[0])


func _journal() -> void:
	var clues := [
		["c_v_three_visitors", "Drei Besucher", "talk", 30, "Ich hab ihm drei genannt: den Pfarrer, den Wundarzt und die Seelfrau. Er hat einen Namen unterstrichen. Welchen, hat er mir nicht gezeigt."],
		["c_v_deathbook", "Das Zeichen im Sterbebuch", "page", 31, "Am Rand des Sterbebuchs steht neben fünf Namen ein kleiner Dreistrich. Die Tinte ist älter als der Eintrag des Todestags. Jemand hat die Namen vorher eingetragen."],
		["c_v_washing", "Was die Seelfrau sah", "talk", 32, "Liesel hat das Zeichen seit dem Winter, als die Fähre kenterte, an den Toten gesehen und es Lorenz gemeldet, jedes Mal. Seit er fort ist, meldet sie es niemandem mehr. Sie schreibt die Namen in ihr Gesangbuch."],
		["c_v_hagedorn", "Drei Wochen alt", "mark", 33, "Wiebke Hagedorns Zeichen ist frisch verheilt, etwa drei Wochen alt. In ihrer Schürze steckt ein Zettel: ‚Für den Totengräber. Linde, Mohn, Totenhemd. Und schau nach, wer mich besucht hat. – W. H.‘"],
		["c_v_arsenic", "Arsenik im Fieber", "note", 34, "Im Dorf stirbt man nicht immer an dem, was Osric sagt."],
		["c_v_dry_lungs", "Trockene Lungen", "note", 35, "Im Dorf stirbt man nicht immer an dem, was Osric sagt."],
		["c_v_still_heart", "Ein Herz ohne Krankheit", "note", 36, "Ein gesundes Herz eines Gezeichneten, still stehen geblieben. Quast: „Ich habe so ein Herz schon zweimal eingelegt. Beide Male lag morgens ein Zettel vor meiner Tür.“"],
	]
	for spec: Array in clues:
		var c := ClueData.new()
		c.id = StringName(spec[0])
		c.title = spec[1]
		c.kind = StringName(spec[2])
		c.order = spec[3]
		c.text = spec[4]
		_save(c, OUT + "/clues/%s.tres" % spec[0])
	var a := InsightData.new()
	a.id = &"i_deathbook"
	a.order = 7
	a.title = "Vorher eingetragen"
	a.question = "Wer schreibt die Namen auf?"
	a.text = "Im Sterbebuch steht das Zeichen neben Namen, deren Tod erst Wochen später eingetragen wurde. Liesel hat es an ihren Leibern gesehen, Lorenz hat nach denen gefragt, die die Kranken besuchen. Wer zeichnet, kommt ins Haus, solange sie noch leben, und schreibt sie vorher auf. Drei kommen in Frage. Eine davon hat Lorenz geholfen."
	a.requires = _sn(["c_v_deathbook", "c_v_washing", "c_v_three_visitors"])
	a.sets_flag = &"insight_deathbook"
	a.optional = false
	_save(a, OUT + "/insights/i_deathbook.tres")
	var b := InsightData.new()
	b.id = &"i_burn_it"
	b.order = 8
	b.title = "Verbrennt es"
	b.question = "Was wollte der Zettel bei Quast?"
	b.text = "Zweimal hat Quast ein gesundes, stilles Herz eines Gezeichneten eingelegt. Beide Male lag am nächsten Morgen ein Zettel vor seiner Tür, in derselben schrägen Hand wie die Warnbriefe: ‚Verbrennt es.‘ Lorenz will nicht, dass sie aufbewahrt werden."
	b.requires = _sn(["c_v_still_heart", "c_warning_letter"])
	b.sets_flag = &"insight_burn_it"
	b.optional = true
	_save(b, OUT + "/insights/i_burn_it.tres")


# --- interiors §4.3 / §4.7 -------------------------------------------------------------------------------

func _interiors() -> void:
	var base := load("res://tests/fixtures/phase6/interiors/chapel.tres") as InteriorConfig
	var rooms := {
		&"inn": [10.0, 8.0, 12.0, 1.1, 0.3, 0.0, 0.0, 3.0, 1.6],
		&"surgery": [9.0, 7.0, 11.0, 1.1, 0.3, 0.0, 0.0, 0.0, 0.0],
		&"office": [9.0, 7.0, 11.0, 0.0, 0.0, 0.6, 0.2, 0.0, 0.0],
	}
	for id: StringName in rooms:
		var spec: Array = rooms[id]
		var c := base.duplicate(true) as InteriorConfig
		c.camera_distance = spec[0]
		c.camera_zoom_min = spec[1]
		c.camera_zoom_max = spec[2]
		c.lantern_night_energy = spec[3]
		c.lantern_day_energy = spec[4]
		c.candle_night_energy = spec[5]
		c.candle_day_energy = spec[6]
		c.stove_night_energy = spec[7]
		c.stove_day_energy = spec[8]
		_save(c, OUT + "/interiors/%s.tres" % id)
