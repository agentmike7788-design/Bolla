extends RefCounted
## Driver of make_phase8_fixtures.gd (loaded after the autoloads exist). Writes the Phase-8 W1 fixtures
## (docs/PHASE8_DESIGN.md §12 W0) from the contract tables of §1–§2 and the five new data/config files
## (class defaults = contract values):
##   godot --headless --path . -s res://tests/fixtures/phase8/make_phase8_fixtures.gd
## Historical tool of W0 (Lead) – the fixtures are the contract snapshot; W1 tests load them, owners
## never regenerate them for balancing (the data files under data/ belong to the owners).

const OUT := "res://tests/fixtures/phase8"
const ITEMS_OUT := "res://tests/fixtures/items"

var _failed := false


func run() -> bool:
	_configs()
	_extended_configs()
	_villagers()
	_kin()
	_wishes()
	_chatters()
	_apprentice_tasks()
	_friendship()
	_friend_orders()
	_festivals()
	_wanderers()
	_night_paths()
	_items()
	_recipe()
	_shops()
	_journal()
	_story()
	return not _failed


# --- helpers ------------------------------------------------------------------------------------

## Every script variable written explicitly (ResourceSaver drops values equal to the class default –
## a fixture must not follow later changes of a class default). Resources with sub-resources
## (FriendStoryData, NightPathData) go through ResourceSaver.
func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if res is FriendStoryData or res is NightPathData:
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


static func _win(from: String, to: String) -> Vector2i:
	return Vector2i(_hm(from), _hm(to))


# --- data/config + fixtures of the new configs ----------------------------------------------------

func _configs() -> void:
	var pairs := {
		&"npc_life_config": NpcLifeConfig.new(), &"visitor_config": VisitorConfig.new(),
		&"grave_care_config": GraveCareConfig.new(), &"apprentice_config": ApprenticeConfig.new(),
		&"robber_config": RobberConfig.new(),
	}
	for name: StringName in pairs:
		_save(pairs[name], "res://data/config/%s.tres" % name)
		_save((pairs[name] as Resource).duplicate(true), OUT + "/%s_fixture.tres" % name)


## Phase-8 values of existing configs (W0: class default and data/config carry them too; the fixture
## is the W0 snapshot).
func _extended_configs() -> void:
	for name: StringName in [&"npc_config", &"relationship_config", &"orders_config", &"reputation_config", &"piety_config",
			&"story_config", &"action_config"]:
		var res := (Database.config(name) as Resource).duplicate(true)
		_save(res, OUT + "/%s_fixture.tres" % name)
	var lines := (load("res://tests/fixtures/phase7/ghost_lines_fixture.tres") as GhostLines).duplicate(true) as GhostLines
	lines.by_flowers = PackedStringArray(["Es riecht nach Heide. Das kenne ich vom Hof."])
	lines.by_candle = PackedStringArray(["Ein Licht. Für mich?"])
	lines.by_visited = PackedStringArray(["Sie war da. Sie hat nicht geweint. Das ist ihre Art."])
	lines.by_disturbed = PackedStringArray(["Jemand war an mir. Nicht du. Du gräbst anders."])
	lines.by_lights = PackedStringArray(["So viele Lichter. Ich dachte, ich bin allein hier oben."])
	var stories := lines.by_story.duplicate(true)
	stories[&"d2_ott"] = PackedStringArray(["Drei waren da. Einer hat gebetet, einer hat gezählt, eine hat gewartet.",
			"Gesa hat Strohblumen gebracht. Die halten länger als ich."])
	lines.by_story = stories
	_save(lines, OUT + "/ghost_lines_fixture.tres")


# --- villagers (§2.1, §2.4): the real data + the Phase-8 fields -----------------------------------

const MOOD_LINES := {
	"innkeeper": [["Totengräber. Bier oder Neuigkeiten?", "Setz dich, wenn du willst. Steh, wenn du musst."],
			["Heute läuft's, Totengräber. Sogar der Ofen zieht.", "Na, du siehst ja fast lebendig aus."],
			["Lass mich. Nein, bleib. Ich weiß nicht.", "Heute ist so ein Tag. Du kennst die."],
			["Heute nicht, Totengräber. Morgen.", "Wenn du was willst, sag's schnell."]],
	"smith": [["Der Hammer wartet. Was gibt's?", "Eisen ist geduldig. Ich nicht."],
			["Heute klingt der Amboss richtig.", "Gutes Wetter zum Schmieden. Also jedes."],
			["Ich hab heute an den Meister gedacht. Lass gut sein.", "Das Feuer will nicht recht."],
			["Heute nicht, Totengräber. Morgen.", "Nicht jetzt. Das Eisen wird kalt."]],
	"grocer": [["Was darf's sein? Bezahlt wird gleich.", "Garn, Kerzen, Leinen. Das Übliche."],
			["Heute hatte ich drei Kunden. Drei!", "Na, Totengräber, heute sogar mit Lächeln?"],
			["Heute ist das Buch der Mutter schwer.", "Ich zähl heute nicht gern."],
			["Heute nicht, Totengräber. Morgen.", "Fass nichts an, was du nicht kaufst."]],
	"priest": [["Gott zum Gruß, Totengräber.", "Die Toten ruhen. Wir arbeiten."],
			["Ein guter Tag für die Lebenden, Totengräber.", "Heute singt sogar der Küster richtig."],
			["Ich war die Nacht auf. Frag nicht, wo.", "Manche Tage sind länger als das Sterbebuch."],
			["Heute nicht, Totengräber. Morgen.", "Was man über dich sagt, gefällt mir nicht."]],
	"mayor": [["Totengräber. Die Gemeinde hört.", "Kurz, bitte. Die Akten warten."],
			["Die Beine tragen heute. Das ist schon was.", "Ein ordentlicher Tag. Alles in den Büchern."],
			["Die Beine. Lassen wir das.", "Heute ist mir das Amtshaus zu groß."],
			["Heute nicht, Totengräber. Morgen.", "Das kommt ins Protokoll. Nicht gegen dich. Noch nicht."]],
	"surgeon": [["Totengräber. Sie sehen gesund aus. Leider.", "Was führt Sie her? Ein Wehwehchen?"],
			["Heute ist keiner gestorben. Ich zähle das.", "Sie kommen mir gelegen, Totengräber."],
			["Ich habe heute Nacht nicht geschlafen. Das sieht man, ich weiß.", "Es gibt Fenster, an denen ich nicht vorbeigehen kann."],
			["Heute nicht, Totengräber. Morgen.", "Ich habe keine Zeit für Höflichkeiten."]],
	"washer": [["Totengräber. Die Spindel dreht sich.", "Setz dich. Oder geh. Beides recht."],
			["Heute ist der Faden gut. Das kommt selten.", "Du kommst wie gerufen. Das tut fast keiner."],
			["Heute wasch ich nur. Reden kann ich morgen.", "Es hängt wieder ein Tuch im Fenster. Ich weiß, was das heißt."],
			["Heute nicht, Totengräber. Morgen.", "Was du mit den Toten machst, geht mich was an."]],
}
## §2.1.3 reaction remarks (key event_<event>; P1/P2 write 1–2 per person and event).
const EVENT_REMARKS := {
	"smith": {"event_apprentice_hired": "Der Wackernagel-Junge harkt jetzt bei dir? Gib ihm einen Stiel, der zu ihm passt."},
	"innkeeper": {"event_jakob_scolded": "Er sagt, du warst streng. Gut. Ich bin's nicht genug.",
			"event_robber_reported": "Den Grell haben sie in die Stadt gebracht. Der hat bei mir noch zwei Bier offen."},
	"grocer": {"event_wish_done": "Die Kehr sagt, das Grab sieht aus wie ein Garten. Sie hat geweint. Das ist gut.",
			"event_kathrein_danced": "Du trittst wie einer, der Erde gewohnt ist."},
	"mayor": {"event_grave_disturbed": "Ein offenes Grab auf dem Hügel. Das kommt ins Protokoll, Totengräber. Nicht gegen dich."},
	"washer": {"event_robber_let_go": "Du hast ihn laufen lassen. Das hätte Lorenz auch getan."},
	"priest": {"event_lights_all": "Kein Grab ohne Licht. Das hatten wir noch nie.",
			"event_noise_at_grave": "Man sagt, du hast gehackt, während der Brandt gebetet hat. Hack ein andermal."},
}
## npc → [circle, visit_grave, visit_every_days, graveyard_npc].
const VILLAGER_P8 := {
	"innkeeper": [["house_kehr", "house_brandt"], "", 0, "npc_innkeeper_g"],
	"smith": [["house_brandt"], "old_01", 6, "npc_smith_g"],
	"grocer": [["house_sieber", "house_kehr"], "old_08", 5, "npc_grocer_g"],
	"priest": [[], "", 0, "npc_priest"],
	"mayor": [["house_sieber"], "", 0, "npc_mayor_g"],
	"surgeon": [[], "", 0, ""],
	"washer": [["cottage_dorn", "cottage_hagedorn"], "", 4, "npc_washer_g"],
	"oldwoman": [[], "", 0, ""],
}


func _villagers() -> void:
	for id: String in VILLAGER_P8:
		var v := (Database.villager(StringName(id)) as VillagerData).duplicate(true) as VillagerData
		var spec: Array = VILLAGER_P8[id]
		v.circle = _sn(spec[0])
		v.visit_grave = spec[1]
		v.visit_every_days = spec[2]
		v.graveyard_npc = StringName(spec[3])
		if id != "oldwoman":
			v.story_id = StringName(id)
			v.favor_id = StringName("fav_" + id)
			var moods: Dictionary[StringName, PackedStringArray] = {}
			var lines: Array = MOOD_LINES[id]
			for i: int in 4:
				moods[[&"plain", &"cheerful", &"low", &"cross"][i]] = PackedStringArray(lines[i])
			v.mood_lines = moods
		var remarks := v.remarks.duplicate(true)
		var extra: Dictionary = EVENT_REMARKS.get(id, {})
		for key: String in extra:
			remarks[StringName(key)] = PackedStringArray([extra[key]])
		v.remarks = remarks
		_save(v, OUT + "/villagers/%s.tres" % id)


# --- visitors (§2.1.4, §2.2) ----------------------------------------------------------------------

func _kin() -> void:
	var rows := [
		# kin_id, name, house, npc, villager, kneels, bouquet, dialogue, fixed, every, minute, first
		["kin_kehr", "Martha Kehr", "house_kehr", "npc_kin_kehr", "", true, "ph_prop_bouquet_heath", "kin_kehr", [], 0, 0, 0],
		["kin_brandt", "Hinrich Brandt", "house_brandt", "npc_kin_brandt", "", false, "ph_prop_bouquet_fir", "kin_brandt", [], 0, 0, 0],
		["kin_ott", "Gesa Ott", "house_ott", "npc_kin_ott", "", true, "ph_prop_bouquet_straw", "kin_ott", [], 0, 0, 0],
		["kin_sieber", "Johann Sieber", "house_sieber", "npc_kin_sieber", "", false, "", "kin_sieber", [], 0, 0, 0],
		["kin_smith", "Ulrich Esch", "", "npc_smith_g", "smith", false, "", "v_smith", ["old_01"], 6, _hm("13:40"), 2],
		["kin_grocer", "Theres Mangold", "", "npc_grocer_g", "grocer", true, "ph_prop_bouquet_rose", "v_grocer", ["old_08"], 5, _hm("14:40"), 2],
		["kin_washer", "Liesel Dorn", "cottage_dorn", "npc_washer_g", "washer", true, "", "v_washer", [], 4, _hm("09:40"), 1],
	]
	for r: Array in rows:
		var k := KinData.new()
		k.kin_id = StringName(r[0])
		k.display_name = r[1]
		k.house = StringName(r[2])
		k.npc_path_id = StringName(r[3])
		k.villager_id = StringName(r[4])
		k.kneels = r[5]
		k.bouquet_model = StringName(r[6])
		k.dialogue_id = StringName(r[7])
		k.fixed_graves = PackedStringArray(r[8])
		k.visit_every_days = r[9]
		k.visit_minute = r[10]
		k.first_offset = r[11]
		_save(k, OUT + "/kin/%s.tres" % r[0])


const WISH_FAILED := "Nichts. Na ja. Du hast viele."
const LINES := ["Ruhe sanft", "Unvergessen", "Hier ruht ein fleißiger Mensch", "Wir sehen uns wieder", "Geliebt und betrauert",
		"Sein Tagwerk ist getan"]


func _wishes() -> void:
	var rows := [
		["w_tend", "tend", "Hältst du es sauber, bis ich wiederkomme?", "Sauber. Das hätte ihm gefallen. Hier, nimm.", ""],
		["w_flowers", "flowers", "Ein paar Blumen. Heide, wenn's geht, die hält den Winter. Ich komm in drei Tagen wieder.",
				"Heide. Du hast es nicht vergessen. Hier, nimm. Nein, nimm es.", ""],
		["w_candle", "candle", "Stell ihm einmal ein Licht hin. Er hatte Angst im Dunkeln.",
				"Es hat gebrannt, sagt man im Dorf. Danke dir.", ""],
		["w_vase", "vase", "Eine Vase, damit die Blumen nicht umfallen.", "Jetzt stehen sie. Danke dir.", ""],
	]
	for i: int in LINES.size():
		rows.append(["w_line_%d" % (i + 1), "line", "Kannst du ‚%s' darunter setzen?" % LINES[i],
				"Da steht es. Jetzt ist es wahr.", LINES[i]])
	for r: Array in rows:
		var w := WishData.new()
		w.id = StringName(r[0])
		w.kind = StringName(r[1])
		w.ask_text = r[2]
		w.done_text = r[3]
		w.failed_text = WISH_FAILED
		w.line_text = r[4]
		_save(w, OUT + "/wishes/%s.tres" % r[0])


# --- chatters (§2.1.2) ----------------------------------------------------------------------------

func _chatters() -> void:
	var rows := [
		# id, region, [a, b], place, window, conditions, lines, sets_flag
		["ch_well_spin", "village", ["grocer", "washer"], "v_well", _win("16:00", "16:30"), [],
				["Du spinnst zu dünn, Dorn. Das reißt.", "Für die Toten reicht's. Die ziehen nicht dran."], ""],
		["ch_linden_bench", "village", ["mayor", "smith"], "v_linden", _win("17:34", "18:00"), [],
				["Der Brunnen hält, Esch.", "Der hält länger als wir."], ""],
		["ch_inn_council", "village", ["mayor", "priest"], "v_in_inn_table", _win("18:10", "20:00"), [],
				["Wieder drei im Sterbebuch diesen Monat, Hochwürden.", "Ich zähle nicht, Fenner. Ich schreibe."], ""],
		["ch_inn_carter", "village", ["innkeeper", "carter"], "v_in_inn_bar", _win("14:05", "17:30"), [],
				["Faulhaber, du riechst nach Hügel.", "Der Hügel riecht nach mir. Das ist was anderes."], ""],
		["ch_bridge_water", "village", ["beggar", "surgeon"], "v_bridge", _win("18:06", "19:30"), ["p8_open"],
				["Sie schauen jeden Abend ins Wasser, Doktor.", "Und Sie jeden Abend mir zu."], ""],
		["ch_church_alms", "village", ["priest", "beggar"], "v_church_door", _win("08:00", "11:30"), ["p8_open"],
				["Hast du gegessen, Veit?", "Gestern, Hochwürden. Ich spar mir den Rest."], ""],
		["ch_rumor_robber", "village", ["carter", "innkeeper"], "v_in_inn_bar", _win("14:05", "17:30"), ["p8_open", "open_days_gte:2"],
				["Drüben bei Ellbach haben sie wieder eins offen gefunden.",
				"Bei uns nicht. Bei uns liegt einer auf dem Hügel, der nicht schläft."], "robber_known"],
		["ch_inn_jakob", "village", ["innkeeper", "apprentice"], "v_in_inn_bar", _win("17:00", "21:00"), ["apprentice_hired"],
				["Hast du dir die Hände gewaschen?", "Zweimal. Die Erde geht nicht ab."], ""],
		["ch_gate_jakob", "graveyard", ["apprentice", "carter"], "gate_outside", _win("07:55", "08:20"), ["apprentice_hired"],
				["Was bringst du heute, Herr Faulhaber?", "Heute nichts, Junge. Freu dich nicht zu früh."], ""],
		["ch_grave_kehr", "graveyard", ["apprentice", "kin_kehr"], "", _win("09:30", "16:00"), ["apprentice_hired"],
				["Ich mach nur das Laub weg, Frau Kehr.", "Mach nur. Er hat Laub nie leiden können."], ""],
		["ch_market_rival", "village", ["grocer", "peddler"], "v_well", _win("10:00", "14:00"), ["p8_open"],
				["Bei mir kostet der Zwirn einen.", "Bei Ihnen kostet er auch einen, wenn er reißt."], ""],
		["ch_gate_peddler", "graveyard", ["peddler", "beggar"], "peddler_gate", _win("15:40", "16:20"), ["p8_open"],
				["Immer noch hier, Veit?", "Wo soll ich hin? Die Toten geben nichts, aber sie nehmen auch nichts."], ""],
		["ch_smith_mayor", "village", ["mayor", "smith"], "v_anvil", _win("12:20", "13:00"), ["flag:robber_known"],
				["Ein Gitter für jedes frische Grab, Esch? Was kostet das die Gemeinde?", "Weniger als ein offenes."], ""],
		["ch_surgery_priest", "village", ["priest", "surgeon"], "v_church_door", _win("11:30", "11:40"), ["sick_light"],
				["Bei den Otts brennt Licht.", "Ich weiß. Ich war schon da."], ""],
		["ch_lights_prepare", "village", ["washer", "priest"], "v_church_door", _win("16:00", "16:40"), ["fest_eve:fest_lights"],
				["Wie viele Kerzen dieses Jahr?", "Eine mehr als letztes. Wie jedes Jahr."], ""],
		["ch_after_lights", "village", ["grocer", "innkeeper"], "v_well", _win("16:00", "16:30"), ["fest_after:fest_lights", "flag:lights_all"],
				["Oben brannte jedes Grab. Hat er alle selbst angezündet?", "Er und mein Junge."], ""],
	]
	for r: Array in rows:
		var c := ChatterData.new()
		c.id = StringName(r[0])
		c.region = StringName(r[1])
		c.npcs = _sn(r[2])
		c.place = StringName(r[3])
		c.window = r[4]
		c.conditions = PackedStringArray(r[5])
		c.lines = PackedStringArray(r[6])
		c.sets_flag = StringName(r[7])
		_save(c, OUT + "/chatter/%s.tres" % r[0])


# --- apprentice (§2.5.2) --------------------------------------------------------------------------

func _apprentice_tasks() -> void:
	var rows := [
		["rake", "Laub harken", [0, 15, 10], "apprentice_rake", "", "leaves", 0, "rake", "neighbour_leaves",
				"Oh. Das war nicht das richtige Grab.", 1],
		["weed", "Unkraut jäten", [0, 30, 20], "", "", "weeds", 0, "weed", "flowers_torn",
				"Oh. Die Blumen waren mit dran.", 2],
		["water", "Blumen gießen", [0, 7, 5], "watering_can", "", "flowers", 0, "water", "flowers_trodden",
				"Oh. Da bin ich reingetreten.", 3],
		["candle", "Grabkerzen", [0, 5, 4], "", "grave_candle", "candle", 900, "candle", "candle_broken",
				"Die Kerze ist mir gebrochen. Sie brennt trotzdem. Ein bisschen schief.", 4],
	]
	for r: Array in rows:
		var t := ApprenticeTaskData.new()
		t.id = StringName(r[0])
		t.label = r[1]
		t.minutes = PackedInt32Array(r[2])
		t.tool_item = StringName(r[3])
		t.consumes = StringName(r[4])
		t.spot_kind = StringName(r[5])
		t.from_minute = r[6]
		t.animation = StringName(r[7])
		t.mistake_kind = StringName(r[8])
		t.mistake_text = r[9]
		t.order = r[10]
		_save(t, OUT + "/apprentice/tasks/%s.tres" % r[0])


# --- friendship (§2.4) ----------------------------------------------------------------------------

## npc → [name key of the order ids, favour label, effect, params, return orders].
const STORIES := {
	"innkeeper": ["rosine", "Ein Wort im Krug", "rumor_shield",
			{"days": 5, "events": [&"lecture_rumor", &"visit_neglected", &"visit_disturbed", &"visit_noise", &"visit_specimen_rumor", &"grave_disturbed"]}],
	"smith": ["esch", "Umsonst geschmiedet", "free_iron",
			{"choices": {&"iron_fittings": 3, &"steel_rod": 1, &"mortsafe_loan": 10}}],
	"grocer": ["mangold", "Aus der Stadt bestellt", "order_ware", {"shop": &"peddler", "next_morning": true}],
	"priest": ["lenz", "Fürbitte", "prayer", {"mood": 3, "nights": 3}],
	"mayor": ["fenner", "Der Nachtwächter", "night_watch", {"rep_event": &"fenner_watch"}],
	"surgeon": ["quast", "Arznei umsonst", "free_medicine", {"items": {&"fever_tincture": 2}}],
	"washer": ["liesel", "Totenwäsche", "corpse_wash", {"minute": 580, "minutes": 60, "steps": [&"wash", &"dress"]}],
}
## npc → three steps [title, conditions, order ids, reward_rep, fallback_event].
const STEPS := {
	"innkeeper": [["Der Junge", [], ["of_rosine_1"], 0, ""], ["Konrads Name", [], ["of_rosine_2"], 1, ""],
			["Oben bei Jakob", ["apprentice_level_gte:2"], ["of_rosine_3"], 0, ""]],
	"smith": [["Meister Gratz", [], ["of_esch_1"], 0, ""], ["Ein Gitter für die Frischen", ["flag:robber_known"], ["of_esch_2"], 0, ""],
			["Feierabend unter der Linde", [], ["of_esch_3"], 0, ""]],
	"grocer": [["Mutters Grab", [], ["of_mangold_1"], 0, ""], ["Das Anschreibebuch", [], ["of_mangold_2"], 0, "lights_after"],
			["Für die ohne Namen", [], ["of_mangold_3"], 1, ""]],
	"priest": [["Die Namen im Buch", [], ["of_lenz_1"], 0, ""], ["Das Archiv", [], ["of_lenz_2"], 0, ""],
			["Das Wort am Lichtgang", [], ["of_lenz_3"], 0, "lights_after"]],
	"mayor": [["Die Beine", [], ["of_fenner_1"], 0, ""], ["Ein Platz mit Blick", [], ["of_fenner_2"], 0, ""],
			["Eine Runde von mir", [], ["of_fenner_3"], 0, ""]],
	"surgeon": [["Unter Kollegen", [], ["of_quast_1"], 0, ""], ["Die Kiste für die Stadt", [], ["of_quast_2"], 0, ""],
			["Was ich nicht aufschreibe", [], ["of_quast_3"], 0, ""]],
	"washer": [["Kaspar", [], ["of_liesel_1", "of_liesel_1_alt"], 0, ""], ["Die Totenwache", [], ["of_liesel_2"], 0, "next_corpse"],
			["Das Gesangbuch", [], ["of_liesel_3"], 0, ""]],
}


func _friendship() -> void:
	for npc: String in STORIES:
		var spec: Array = STORIES[npc]
		var story := FriendStoryData.new()
		story.npc_id = StringName(npc)
		story.favor_id = StringName("fav_" + npc)
		var steps: Array[FriendStepData] = []
		for i: int in 3:
			var row: Array = STEPS[npc][i]
			var s := FriendStepData.new()
			s.step = i + 1
			s.title = row[0]
			s.min_value = [40, 55, 70][i]
			s.conditions = PackedStringArray(row[1])
			s.order_ids = _sn(row[2])
			s.start_node = StringName("story_%d" % (i + 1))
			s.end_node = StringName("story_%d_done" % (i + 1))
			s.reward_rel = [6, 8, 10][i]
			s.reward_rep = row[3]
			s.reward_flag = StringName("friend_%s_%d" % [npc, i + 1])
			s.gap_days = 1
			s.fallback_event = StringName(row[4])
			steps.append(s)
		story.steps = steps
		_save(story, OUT + "/friendship/stories/%s.tres" % npc)
		var f := FavorData.new()
		f.id = StringName("fav_" + npc)
		f.npc_id = StringName(npc)
		f.label = spec[1]
		f.effect = StringName(spec[2])
		f.params = spec[3]
		f.return_orders = _sn(["of_%s_return_1" % spec[0], "of_%s_return_2" % spec[0]])
		_save(f, OUT + "/friendship/favors/fav_%s.tres" % npc)


## The friend orders (OrderData category friend): the 21 steps (+ Liesel's variant) and the 14 return favours.
func _friend_orders() -> void:
	var rows := [
		# id, giver, kind, title, request, items, coins, target, conditions, recipient, requires_flag
		["of_rosine_1", "innkeeper", "task", "Der Junge",
				"Du hast Augen wie einer, der nicht viel schläft. Gut. Mein Jakob schläft zu viel. Nimm ihn mit hinauf. Er soll lernen, was die Leute brauchen, auch wenn sie es nicht wollen.",
				{}, 0, "", {"action_id": &"apprentice_first_day"}, "", ""],
		["of_rosine_2", "innkeeper", "deliver", "Konrads Name",
				"Konrad hat kein Grab. Das Wasser hat ihn behalten. Mach ihm eine Tafel mit seinem Namen, und bring sie dem Pfarrer.",
				{&"memorial_plate": 1}, 0, "", {}, "priest", ""],
		["of_rosine_3", "innkeeper", "meet", "Oben bei Jakob",
				"Ich will ihn einmal sehen, oben bei dir. Wenn er's kann. Um drei, an der Bank bei der Hütte.",
				{}, 0, "", {"npc": &"innkeeper", "place": &"apprentice_lunch", "window": [900, 940], "times": 1}, "", ""],
		["of_esch_1", "smith", "tend", "Meister Gratz",
				"Der alte Gratz hat mir das Schmieden beigebracht. Halt ihm das Grab sauber. Drei Morgen in Folge, dann glaub ich's.",
				{}, 0, "old_01", {"mornings": 3}, "", ""],
		["of_esch_2", "smith", "deliver", "Ein Gitter für die Frischen",
				"In der Stadt haben sie Gitter über den frischen Gräbern. Ich kann das auch. Bring mir Eisen und Kohle.",
				{&"iron_bar": 4, &"charcoal": 2}, 0, "", {}, "", "robber_known"],
		["of_esch_3", "smith", "meet", "Feierabend unter der Linde",
				"Setz dich abends mal zu mir unter die Linde. Zweimal. Einmal ist Zufall.",
				{}, 0, "", {"npc": &"smith", "place": &"v_linden", "window": [1054, 1140], "times": 2, "minutes": 20}, "", ""],
		["of_mangold_1", "grocer", "task", "Mutters Grab",
				"Setz Mutter Christrosen aufs Grab und halt sie frisch, bis ich wiederkomme.",
				{}, 0, "old_08", {"action_id": &"flowers_fresh", "until": &"next_visit"}, "", ""],
		["of_mangold_2", "grocer", "deliver", "Das Anschreibebuch",
				"Im Buch der Mutter stehen noch Schulden von Toten. Schreib mir ab, wer davon oben liegt.",
				{&"register_extract": 1}, 0, "", {}, "", ""],
		["of_mangold_3", "grocer", "task", "Für die ohne Namen",
				"Drei Töpfe Christrosen, für drei, zu denen keiner kommt. Halt sie frisch bis zum dritten Morgen.",
				{}, 0, "", {"action_id": &"flowers_fresh", "count": 3, "kinless": true, "mornings": 3, "gives": {&"flower_seedlings": 3}}, "", ""],
		["of_lenz_1", "priest", "deliver", "Die Namen im Buch",
				"Ich brauche Namen und Tage der Toten im Lindenacker fürs Sterbebuch. Schreib sie mir ab.",
				{&"register_extract": 1}, 0, "", {}, "", ""],
		["of_lenz_2", "priest", "task", "Das Archiv",
				"Das Pfarrarchiv ist in Unordnung. Hilf mir am Abend, es zu ordnen.",
				{}, 0, "", {"action_id": &"archive_help", "place": &"church", "window": [960, 1080]}, "", ""],
		["of_lenz_3", "priest", "task", "Das Wort am Lichtgang",
				"Am Lichtgang lese ich die Namen derer, zu denen keiner hinaufgeht. Lies sie mit mir.",
				{}, 0, "", {"action_id": &"lights_names", "place": &"lights_lenz", "minute": 1060, "minutes": 10}, "", ""],
		["of_fenner_1", "mayor", "deliver", "Die Beine",
				"Die Wassersucht wird schlimmer. Einen Wacholderumschlag, wenn du hast. Diskret.",
				{&"juniper": 2, &"linen": 1}, 0, "", {"or_items": {&"dropsy_powder": 1}}, "", ""],
		["of_fenner_2", "mayor", "meet", "Ein Platz mit Blick",
				"Ich möchte mir einen Platz ansehen. Für später. Sehr viel später, verstehen Sie. Mit Blick aufs Amtshaus, wenn man das von oben sieht.",
				{}, 0, "l_12", {"npc": &"mayor", "place": &"gv_l_12", "window": [960, 1000], "times": 1, "gives_flag": &"archive_key"}, "", ""],
		["of_fenner_3", "mayor", "meet", "Eine Runde von mir",
				"Komm abends in den Krug. Heute zahl ich.",
				{}, 0, "", {"npc": &"mayor", "place": &"v_in_inn_table", "window": [1085, 1260], "times": 1}, "", ""],
		["of_quast_1", "surgeon", "deliver", "Unter Kollegen",
				"Die Wöchnerin bei den Siebers braucht Wundsalbe. Zwei Tiegel. Sie können das, hört man.",
				{&"wound_salve": 2}, 0, "", {}, "", ""],
		["of_quast_2", "surgeon", "deliver", "Die Kiste für die Stadt",
				"Diese Kiste muss morgen früh mit Faulhaber in die Stadt. Bis zwanzig vor acht an seinem Karren.",
				{&"quast_crate": 1}, 0, "", {"by_minute": 460}, "carter", ""],
		["of_quast_3", "surgeon", "meet", "Was ich nicht aufschreibe",
				"Kommen Sie abends an die Brücke. Ich erzähle Ihnen etwas, das ich nicht aufschreibe.",
				{}, 0, "", {"npc": &"surgeon", "place": &"v_bridge", "window": [1086, 1170], "times": 1}, "", ""],
		["of_liesel_1", "washer", "task", "Kaspar",
				"Er heißt nicht Lorenz. Er heißt Kaspar. Setz seinen Namen auf den Stein.",
				{}, 0, "s5_moor", {"action_id": &"name_line", "minutes": 40, "item": &"ink"}, "", "insight_not_lorenz"],
		["of_liesel_1_alt", "washer", "tend", "Wiebke",
				"Halt der Hagedorn das Grab sauber, drei Morgen, und stell ihr eine Nacht ein Licht hin.",
				{}, 0, "d1_hagedorn", {"mornings": 3, "candle_nights": 1}, "", ""],
		["of_liesel_2", "washer", "task", "Die Totenwache",
				"Halt einmal mit mir Totenwache. Wenn einer unten liegt, komm ich um halb zehn.",
				{}, 0, "", {"action_id": &"vigil", "place": &"crypt", "minute": 1290, "minutes": 60}, "", ""],
		["of_liesel_3", "washer", "meet", "Das Gesangbuch",
				"Hier stehen sie alle. Die mit dem Zeichen. Wenn ich sterbe, kommt das Buch mit mir hinunter. Versprich es.",
				{}, 0, "", {"npc": &"washer", "place": &"v_dorn_door", "window": [960, 1140], "times": 1, "gives_flag": &"promise_liesel_book"}, "", ""],
		# return favours (§2.4 „Gegengefallen", one of the pool chosen; offered the day after, 3 days)
		["of_rosine_return_1", "innkeeper", "deliver", "Holunder für Rosine", "Sechs Hände Holunderbeeren, wenn du welche findest.",
				{&"elderberries": 6}, 0, "", {}, "", ""],
		["of_rosine_return_2", "innkeeper", "task", "Ein Tag für Jakob", "Gib dem Jungen einen Tag frei. Den Lohn trotzdem.",
				{}, 0, "", {"action_id": &"jakob_day_off"}, "", ""],
		["of_esch_return_1", "smith", "deliver", "Kohle für die Esse", "Sechs Säcke Kohle. Die Esse frisst.",
				{&"charcoal": 6}, 0, "", {}, "", ""],
		["of_esch_return_2", "smith", "deliver", "Werkstein für den Amboss", "Zwei Werksteine. Der Amboss braucht ein neues Bett.",
				{&"workstone": 2}, 0, "", {}, "", ""],
		["of_mangold_return_1", "grocer", "deliver", "Kräuter für den Laden", "Acht Bund Kräuter. Die Stadt will sie.",
				{&"herbs": 8}, 0, "", {}, "", ""],
		["of_mangold_return_2", "grocer", "deliver", "Garn für den Laden", "Vier Strang Garn. Meins ist alle.",
				{&"yarn": 4}, 0, "", {}, "", ""],
		["of_lenz_return_1", "priest", "deliver", "Kerzen für den Altar", "Vier Altarkerzen. Der Advent kommt.",
				{&"altar_candle": 4}, 0, "", {}, "", ""],
		["of_lenz_return_2", "priest", "task", "Blumen für einen Vergessenen", "Ein Grab, zu dem keiner kommt, mit frischen Blumen.",
				{}, 0, "", {"action_id": &"flowers_fresh", "count": 1, "kinless": true}, "", ""],
		["of_fenner_return_1", "mayor", "deliver", "Holz für den Gemeindezaun", "Zehn Scheit Holz für den Zaun der Gemeinde.",
				{&"wood": 10}, 0, "", {}, "", ""],
		["of_fenner_return_2", "mayor", "donate", "Die Armenkasse", "Fünf Münzen in die Armenkasse. Für die Ordnung.",
				{}, 5, "", {}, "", ""],
		["of_quast_return_1", "surgeon", "deliver", "Kräuterbündel", "Zwei Kräuterbündel. Für die Salben.",
				{&"herb_bundle": 2}, 0, "", {}, "", ""],
		["of_quast_return_2", "surgeon", "deliver", "Weingeist", "Eine Flasche Weingeist. Fragen Sie nicht.",
				{&"spirits": 1}, 0, "", {}, "", ""],
		["of_liesel_return_1", "washer", "deliver", "Leinen für die Toten", "Zwei Bahnen Leinen. Für die Nächsten.",
				{&"linen": 2}, 0, "", {}, "", ""],
		["of_liesel_return_2", "washer", "deliver", "Garn für die Spindel", "Vier Strang Garn.",
				{&"yarn": 4}, 0, "", {}, "", ""],
	]
	var order := 200
	for r: Array in rows:
		var o := OrderData.new()
		o.id = StringName(r[0])
		o.giver = StringName(r[1])
		o.kind = StringName(r[2])
		o.title = r[3]
		o.request_text = r[4]
		o.thanks_text = "Danke, Totengräber."
		var items: Dictionary[StringName, int] = {}
		for key: Variant in (r[5] as Dictionary):
			items[StringName(str(key))] = int(r[5][key])
		o.items = items
		o.coins = r[6]
		o.target = r[7]
		o.conditions = r[8]
		o.recipient = StringName(r[9])
		o.requires_flag = StringName(r[10])
		o.category = OrderData.CATEGORY_FRIEND
		o.order = order
		order += 1
		_save(o, OUT + "/orders/%s.tres" % r[0])


# --- festivals, wanderers, night (§2.6, §2.7, §1.6) -----------------------------------------------

func _festivals() -> void:
	var k := FestivalData.new()
	k.id = &"fest_kathrein"
	k.calendar_day = 54
	k.shift_rule = FestivalData.SHIFT_NONE
	k.day_flag = &"fest_kathrein_day"
	k.window = _win("19:00", "23:00")
	k.region = &"village"
	k.music_context = &"fest"
	k.effects = {"room": &"inn", "presence_minutes": 30, "presence_rel": 2, "dance_rel": 3, "dance_minutes": 15,
			"dance_partners": 2, "dance_tier": &"acquainted", "round": 5,
			"end_line": "Kathrein stellt den Tanz ein. Bis Weihnachten wird hier gesessen."}
	_save(k, OUT + "/festivals/fest_kathrein.tres")
	var l := FestivalData.new()
	l.id = &"fest_lights"
	l.calendar_day = 58
	l.shift_rule = FestivalData.SHIFT_OPEN_PLUS
	l.shift_days = 3
	l.day_flag = &"fest_lights_day"
	l.window = _win("16:00", "18:30")
	l.region = &"graveyard"
	l.music_context = &"lights"
	l.effects = {"candles": 12, "candles_minute": _hm("07:40"), "gather_minute": _hm("16:00"), "arrive": [_hm("16:45"), _hm("17:00")],
			"at_graves": [_hm("17:00"), _hm("17:40")], "speech_minute": _hm("17:40"), "check_minute": _hm("18:00"), "leave": [_hm("18:00"), _hm("18:30")],
			"lights_all": {"rep_event": &"lights_all", "rel_all": 2, "rel": {&"priest": 3}, "goodwill": 2, "piety_event": &"lights_all"},
			"lights_some": {"rep_event": &"lights_some", "share": 0.5},
			"early_ghosts": {"from": _hm("17:00"), "minutes": 30, "alpha": 0.35}, "ghost_candle_mood": 2,
			"shift_line": "Wir haben ihn verschoben. Der Hügel war nicht so weit.",
			"speech": "Wir zünden kein Licht für Gott an. Der sieht auch so. Wir zünden es für die an, die den Weg vergessen haben. Und für die, die noch hier unten sind und ihn suchen."}
	_save(l, OUT + "/festivals/fest_lights.tres")


func _wanderers() -> void:
	var v := WandererData.new()
	v.id = &"beggar"
	v.display_name = "Veit Ammer"
	v.dialogue_id = &"beggar"
	v.alms_coins = 1
	v.alms_piety = &"alms"
	v.alms_for_clue = 3
	v.clue_id = &"c_n_veit"
	_save(v, OUT + "/wanderers/beggar.tres")
	var h := WandererData.new()
	h.id = &"peddler"
	h.display_name = "Hanne Vogelsang"
	h.dialogue_id = &"peddler"
	h.shop_id = &"peddler"
	h.every_days = 6
	h.day_rest = 1
	_save(h, OUT + "/wanderers/peddler.tres")


func _visit(npc: StringName, night: int, enter: String, leave: String, clue: StringName, anim: StringName = &"walk") -> NightVisitData:
	var v := NightVisitData.new()
	v.npc_id = npc
	v.night_offset = night
	v.enter_minute = _hm(enter)
	v.leave_minute = _hm(leave)
	v.clue_id = clue
	v.animation = anim
	return v


func _night_paths() -> void:
	var ott := NightPathData.new()
	ott.id = &"np_ott"
	ott.house = &"house_ott"
	ott.patient = "Gerhard Ott"
	ott.start_offset = 3
	ott.end_offset = 4
	var ott_visits: Array[NightVisitData] = [
		_visit(&"surgeon", 3, "22:30", "23:10", &"c_n_quast_visit"),
		_visit(&"priest", 4, "21:00", "21:40", &"c_n_lenz_visit", &"lantern_walk"),
		_visit(&"washer", 4, "02:40", "05:30", &"c_n_liesel_watch"),
	]
	ott.visits = ott_visits
	ott.death_offset = 4
	ott.death_minute = _hm("02:10")
	ott.death_flag = &"ott_dead"
	ott.watch_spot = &"watch_ott"
	_save(ott, OUT + "/night/paths/np_ott.tres")
	var kehr := NightPathData.new()
	kehr.id = &"np_kehr"
	kehr.house = &"house_kehr"
	kehr.patient = "Paul Kehr"
	kehr.start_offset = 7
	kehr.end_offset = 8
	var kehr_visits: Array[NightVisitData] = [
		_visit(&"surgeon", 7, "22:30", "23:10", &"c_n_quast_visit"),
		_visit(&"priest", 8, "21:00", "21:30", &"c_n_lenz_visit", &"lantern_walk"),
	]
	kehr.visits = kehr_visits
	kehr.watch_spot = &"watch_kehr"
	_save(kehr, OUT + "/night/paths/np_kehr.tres")


# --- items, recipe, shops (§2.6.2, §2.11) ---------------------------------------------------------

func _items() -> void:
	var rows := [
		["flower_seedlings", "Grabblumen", "Winterheide und Christrosen im Topf, zum Setzen auf ein Grab. Halten frisch, solange man gießt.",
				ItemData.Category.MATERIAL, 10],
		["grave_candle", "Grabkerze", "Eine Kerze im Glas. Brennt vom Nachmittag bis zum Hahnenschrei auf einem Grab.",
				ItemData.Category.MATERIAL, 10],
		["watering_can", "Gießkanne", "Eine Blechkanne mit Brause. Sechs Füllungen, das Regenfass an der Hütte füllt nach.",
				ItemData.Category.TOOL, 1],
		["apprentice_rake", "Kinderrechen", "Ein kleiner Rechen mit kurzem Stiel. Für Jakobs Kiste.", ItemData.Category.TOOL, 1],
		["mortsafe", "Grabgitter", "Ein eisernes Gitter über dem Hügel, wie man es 1834 gegen Leichenräuber setzt.", ItemData.Category.GOODS, 4],
		["wax_wreath", "Wachskranz", "Blasse Blüten aus Wachs. Welken nie, riechen nach nichts.", ItemData.Category.GOODS, 5],
		["register_extract", "Abschrift aus dem Grabregister", "Namen und Tage der Toten, sauber abgeschrieben aus dem Grabregister der Hütte.",
				ItemData.Category.GOODS, 5],
		["memorial_plate", "Namenstafel „Konrad Wackernagel“", "Eine kleine Steintafel mit vergoldetem Namen. Für einen, der kein Grab hat.",
				ItemData.Category.CRAFTED, 1],
		["quast_crate", "Versiegelte Kiste", "Eine Kiste mit Quasts Siegel, für die Stadt. Innen raschelt Stroh.", ItemData.Category.GOODS, 1],
		["lorenz_ledger_2", "Lorenz' zweite Kladde", "Ein schmales, abgegriffenes Heft mit Faden. Lorenz' Hand, zwischen Kirchenrechnungen versteckt.",
				ItemData.Category.GOODS, 1],
	]
	for r: Array in rows:
		var item := ItemData.new()
		item.id = StringName(r[0])
		item.display_name = r[1]
		item.description = r[2]
		item.category = r[3]
		item.max_stack = r[4]
		_save(item, ITEMS_OUT + "/%s.tres" % r[0])


func _recipe() -> void:
	var r := RecipeData.new()
	r.id = &"memorial_plate"
	r.display_name = "Namenstafel"
	r.inputs = _si({"workstone": 1, "ink": 1, "gold_leaf": 1})
	r.output_id = &"memorial_plate"
	r.output_amount = 1
	r.craft_minutes = 40
	r.station = &"mason"
	r.category = &"grave"
	r.requires_flag = &"friend_innkeeper_2"
	_save(r, OUT + "/recipes/memorial_plate.tres")


func _shops() -> void:
	var p := ShopData.new()
	p.id = &"peddler"
	p.npc_id = &"peddler"
	p.title = "Hannes Kiepe"
	p.sells = {&"flower_seedlings": {"price": 2, "per_day": 6}, &"grave_candle": {"price": 1, "per_day": 8},
			&"watering_can": {"price": 4, "per_day": 1}, &"wax_wreath": {"price": 5, "per_day": 1},
			&"gold_leaf": {"price": 6, "per_day": 1}, &"ink": {"price": 2, "per_day": 3}}
	p.buys = {&"yarn": {"price": 1, "per_day": 6}, &"wound_salve": {"price": 4, "per_day": 2},
			&"herb_bundle": {"price": 3, "per_day": 3}, &"elder_wine": {"price": 3, "per_day": 2}}
	p.coin_reason = &"peddler"
	_save(p, OUT + "/shops/peddler.tres")
	var grocer := (Database.shop(&"grocer") as ShopData).duplicate(true) as ShopData
	var gs := grocer.sells.duplicate(true)
	gs[&"flower_seedlings"] = {"price": 2, "per_day": 4}
	gs[&"grave_candle"] = {"price": 1, "per_day": 6}
	grocer.sells = gs
	_save(grocer, OUT + "/shops/grocer.tres")
	var smith := (Database.shop(&"smith") as ShopData).duplicate(true) as ShopData
	var ss := smith.sells.duplicate(true)
	ss[&"watering_can"] = {"price": 4, "per_day": 1}
	ss[&"apprentice_rake"] = {"price": 3, "per_day": 1}
	ss[&"mortsafe"] = {"price": 12, "per_day": 2, "requires_flag": &"robber_known", "price_after_flag": {"flag": &"friend_smith_2", "price": 8}}
	smith.sells = ss
	_save(smith, OUT + "/shops/smith.tres")


# --- journal, story (§1.6, §2.9) ------------------------------------------------------------------

const UNDERLINED_TEXT := {
	"washer": "Lorenz hat die Seelfrau unterstrichen. Sie kommt, bevor man nach ihr schickt, und sie hat ihm jedes Zeichen gemeldet, das sie fand. Vielleicht wollte er sie in der Nähe haben, weil er ihr nicht traute. Vielleicht wollte er sie schützen. Auf der Seite steht nicht, welches von beiden.",
	"priest": "Lorenz hat den Pfarrer unterstrichen. Lenz schreibt die Namen ins Sterbebuch, manchmal, bevor einer tot ist, und er geht zu jedem, der den Versehgang braucht. Vielleicht wusste Lorenz, warum die Tinte früher da ist. Vielleicht hat er sich nur gewundert. Auf der Seite steht nicht, welches von beiden.",
	"surgeon": "Lorenz hat den Wundarzt unterstrichen. Quast geht zu jedem Krankenlicht, auch wenn ihn keiner holt, und er schreibt nicht auf, was er dort lässt. Vielleicht wollte Lorenz ihn fragen. Vielleicht hat er es nicht mehr gewagt. Auf der Seite steht nicht, welches von beiden.",
}


func _journal() -> void:
	var clues := [
		["c_n_veit", "Drei gehen nachts", "talk", "Nachts gehen drei durchs Dorf. Der Pfarrer mit der Laterne, der Doktor mit dem Koffer, die Dorn mit dem Tuch. Wohin, sieht man am Fenster: wo das Krankenlicht brennt. Lorenz hat mich das auch gefragt. Ich hab's ihm gesagt. Danach hat er mir nie wieder was gegeben, nur noch genickt."],
		["c_n_quast_visit", "Der Krankenbesuch", "note", "Quast bleibt vierzig Minuten. Er lässt ein Fläschchen da und schreibt beim Hinausgehen nichts auf. Er schreibt sonst alles auf."],
		["c_n_lenz_visit", "Der Versehgang", "note", "Lenz bleibt eine halbe Stunde. Beim Hinausgehen bleibt er unter der Laterne stehen und schreibt etwas in sein Brevier."],
		["c_n_liesel_watch", "Die Totenwache", "note", "Liesel kommt eine halbe Stunde nach dem Tod. Niemand hat nach ihr geschickt. Das Krankenlicht brennt noch."],
		["c_n_ott_three", "Drei Spuren", "mark", "Quasts Fläschchen in der Tasche, ein Wachstropfen von Lenz' Kerze am Kragen, ein frisch gewaschenes Hemd unter dem Kittel. Drei waren bei Gerhard Ott, bevor er starb."],
		["c_n_kladde", "Lorenz' zweite Kladde", "page", "Zwischen den Kirchenrechnungen von 1831 steckt ein schmales Heft in Lorenz' Hand. Auf der letzten beschriebenen Seite stehen drei Namen: A. Lenz · S. Quast · L. Dorn. Einer ist zweimal unterstrichen. Darunter: ‚Wer kommt, bevor man ruft?'"],
		["c_n_robber", "Wer zahlt den Grell?", "talk", "Ein Herr mit einem Koffer. Er riecht nach Branntwein und zahlt für Frische. Er sagt, für die Wissenschaft. Mehr weiß der Grell nicht."],
	]
	var order := 300
	for r: Array in clues:
		var c := ClueData.new()
		c.id = StringName(r[0])
		c.title = r[1]
		c.kind = StringName(r[2])
		c.text = r[3]
		c.order = order
		order += 1
		_save(c, OUT + "/clues/%s.tres" % r[0])
	for variant: String in UNDERLINED_TEXT:
		var i := InsightData.new()
		i.id = &"i_underlined"
		i.order = 30
		i.title = "Der unterstrichene Name"
		i.question = "Wen hat Lorenz verdächtigt?"
		i.text = UNDERLINED_TEXT[variant]
		i.requires = _sn(["c_n_veit", "c_n_kladde"])
		i.any_clues = _sn(["c_n_quast_visit", "c_n_lenz_visit", "c_n_liesel_watch", "c_n_ott_three"])
		i.any_count = 2
		i.sets_flag = &"insight_underlined"
		_save(i, OUT + ("/insights/i_underlined.tres" if variant == "washer" else "/insights/i_underlined_%s.tres" % variant))


func _story() -> void:
	var d := StoryCorpseData.new()
	d.id = &"d2_ott"
	d.order = 7
	d.earliest_day = 1
	d.display_name = "Gerhard Ott"
	d.age = 74
	d.cause_id = &"old_age"
	d.traits = _sn(["strange_wound"])
	d.valuables_coins = 0
	d.look = 2
	d.finds = _sn(["f_d2_bottle", "f_d2_wax", "f_d2_shirt", "f_d2_mark"])
	d.arrival_note = "Der alte Ott. Heute Nacht. Liesel war schon da, als ich kam. Sie ist immer schon da."
	d.section = &"linden"
	d.requires_flag = &"p8_open"
	d.due_flag = &"ott_dead"
	_save(d, OUT + "/story/d2_ott.tres")
	var finds := [
		["f_d2_bottle", "pockets", "Ein Fläschchen, halb leer", "Ein Fläschchen, halb leer. Auf dem Etikett: ‚nach Quast – drei Tropfen am Abend'.", 0.0, ""],
		["f_d2_wax", "clothing", "Ein Wachstropfen am Kragen", "Ein Wachstropfen am Kragen. Kirchenkerzen tropfen so.", 0.0, ""],
		["f_d2_shirt", "clothing", "Ein frisch gewaschenes Hemd", "Das Hemd unter dem Kittel ist frisch gewaschen und gestärkt. Wer wäscht einen Mann, bevor er tot ist?", 0.0, ""],
		["f_d2_mark", "wounds", "Das Zeichen, verheilt", "Das Zeichen über dem Herzen, verheilt seit gut drei Wochen. Wie bei der Hagedorn.", 0.3, "strange_wound"],
	]
	for r: Array in finds:
		var f := FindData.new()
		f.id = StringName(r[0])
		f.step = StringName(r[1])
		f.label = r[2]
		f.text = r[3]
		f.min_freshness = r[4]
		f.trait_id = StringName(r[5])
		f.story_only = true
		_save(f, OUT + "/finds/%s.tres" % r[0])
