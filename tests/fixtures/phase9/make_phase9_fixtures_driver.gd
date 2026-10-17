extends RefCounted
## Driver of make_phase9_fixtures.gd (loaded after the autoloads exist). Writes the Phase-9 W1 fixtures
## (docs/PHASE9_DESIGN.md §12 W0) from the contract tables of §1–§2 and the four new data/config files
## (class defaults = contract values):
##   godot --headless --path . -s res://tests/fixtures/phase9/make_phase9_fixtures.gd
## Historical tool of W0 (Lead) – the fixtures are the contract snapshot; W1 tests load them, owners
## never regenerate them for balancing (the data files under data/ belong to the owners).

const OUT := "res://tests/fixtures/phase9"
const ITEMS_OUT := "res://tests/fixtures/items"

var _failed := false


func run() -> bool:
	_configs()
	_extended_configs()
	_quests()
	_light_list()
	_letters()
	_stranger_offers()
	_large_requests()
	_quest_orders()
	_items()
	_journal()
	_story()
	_night_path()
	_section()
	return not _failed


# --- helpers ------------------------------------------------------------------------------------

## Every script variable written explicitly (ResourceSaver drops values equal to the class default –
## a fixture must not follow later changes of a class default). Resources with sub-resources
## (QuestData, LightListData, large OrderData, NightPathData) go through ResourceSaver.
func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if res is QuestData or res is LightListData or res is NightPathData or (res is OrderData and not (res as OrderData).parts.is_empty()):
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


static func _ps(list: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for v: Variant in list:
		out.append(str(v))
	return out


static func _hm(text: String) -> int:
	var p := text.split(":")
	return int(p[0]) * 60 + int(p[1])


# --- data/config + fixtures of the new configs ----------------------------------------------------

const QUESTIONS := ["Wie tief graben Sie im Frost?", "Wer kommt zuerst, wenn einer stirbt?",
		"Haben Sie je einen gesehen, der drei Wochen vorher wusste, dass er geht?",
		"Wie schwer ist ein Mann nach drei Tagen im November?",
		"Schreiben Sie auf, wer wann kommt, Herr Totengräber? Ich schon.",
		"Brennt bei Ihnen nachts ein Licht? Bei mir brennt immer eins. Ich lese."]


func _configs() -> void:
	var stranger := StrangerConfig.new()
	stranger.questions = _ps(QUESTIONS)
	var pairs := {&"quest_config": QuestConfig.new(), &"who_knows_config": WhoKnowsConfig.new(),
			&"letters_config": LettersConfig.new(), &"stranger_config": stranger}
	for name: StringName in pairs:
		_save(pairs[name], "res://data/config/%s.tres" % name)
		_save((pairs[name] as Resource).duplicate(true), OUT + "/%s_fixture.tres" % name)


## Phase-9 values of existing configs (W0: class default and data/config carry them too; the fixture
## is the W0 snapshot) + the ghost lines (Phase-8 fixture + by_letter + by_story d3_sieber).
func _extended_configs() -> void:
	for name: StringName in [&"orders_config", &"hill_requests_config", &"reputation_config", &"piety_config",
			&"relationship_config", &"npc_life_config"]:
		var res := (Database.config(name) as Resource).duplicate(true)
		_save(res, OUT + "/%s_fixture.tres" % name)
	var lines := (load("res://tests/fixtures/phase8/ghost_lines_fixture.tres") as GhostLines).duplicate(true) as GhostLines
	lines.by_letter = _ps(["Du hast es mir vorgelesen. Sie schreibt immer noch so schief.",
			"Das war für Martha. Bring es ihr. Nein – lies es mir noch einmal."])
	var stories := lines.by_story.duplicate(true)
	stories[&"d3_sieber"] = _ps(["Grete hat gesagt, ich soll mich nicht beeilen. Ich hab mich nicht beeilt.",
			"Da stand einer mit einer Laterne vor meiner Tür. Für mich hat noch nie einer Wache gestanden.",
			"Keiner hat was gesagt. Ich auch nicht. Das hatten wir so in der Familie."])
	lines.by_story = stories
	_save(lines, OUT + "/ghost_lines_fixture.tres")


# --- chains (§2.1, §2.2.3, §2.4.5, §2.5.2) ---------------------------------------------------------

func _step(id: String, title: String, hint: String, on: StringName, ids: Array, count: int = 0, orders: Array = []) -> QuestStepData:
	var s := QuestStepData.new()
	s.id = StringName(id)
	s.title = title
	s.hint = hint
	s.complete_on = on
	s.complete_ids = _sn(ids)
	s.complete_count = count
	s.order_ids = _sn(orders)
	return s


func _choice(id: String, label: String, actions: Array, ending: String = "", conditions: Array = [], block: String = "") -> QuestChoiceData:
	var c := QuestChoiceData.new()
	c.id = StringName(id)
	c.label = label
	c.actions = _ps(actions)
	c.ending = StringName(ending)
	c.conditions = _ps(conditions)
	c.block_text = block
	return c


func _ending(id: String, title: String, summary: String, flag: String, settle: String, closing: String) -> QuestEndingData:
	var e := QuestEndingData.new()
	e.id = StringName(id)
	e.title = title
	e.summary = summary
	e.flag = StringName(flag)
	e.settle_on = StringName(settle)
	e.closing_line = closing
	return e


func _quests() -> void:
	var main := QuestData.new()
	main.id = &"q_who_knows"
	main.kind = QuestData.KIND_MAIN
	main.title = "Wer weiß, wann?"
	main.summary = "Auf der Rückseite von Lorenz' Kladde stehen sechs Daten und je ein Buchstabe. Unter fünf Daten liegt einer auf dem Hügel. Unter dem letzten noch keiner."
	main.giver = &"priest"
	main.open_conditions = _ps(["flag:p9_open"])
	main.order = 10
	var h5 := _step("h5", "Wem sagst du es?", "Lenz, Quast, Liesel – oder niemandem.", QuestStepData.ON_CHOICE, [])
	h5.choices = [
		_choice("confide_priest", "Pfarrer Lenz", ["rel_add:priest:4", "set_flag:q_confide_priest"]),
		_choice("confide_surgeon", "Severin Quast", ["rel_add:surgeon:4", "set_flag:q_confide_surgeon"]),
		_choice("confide_washer", "Liesel Dorn", ["rel_add:washer:4", "set_flag:q_confide_washer"]),
		_choice("confide_none", "Niemandem", ["set_flag:q_confide_none"]),
	] as Array[QuestChoiceData]
	var h6 := _step("h6", "Was wird aus Johann?", "Johann sitzt an Gretes Grab oder auf der Bank vor dem Haus.", QuestStepData.ON_CHOICE, [])
	h6.choices = [
		_choice("away", "„Geh fort, Johann. Über den Hügel.“", ["set_flag:q_end_away", "piety_event:sent_away",
				"rep_event:sent_away_rumor", "goodwill:kin_sieber:2", "note_event:q_sent_away"], "away", ["letter_posted"],
				"Er glaubt dir nicht. Er würde einem Brief glauben."),
		_choice("stay", "„Bleib. Ich mach dir das Grab neben Grete.“", ["set_flag:q_end_stay", "set_flag:q_sieber_dies",
				"goodwill:kin_sieber:4", "note_event:q_stayed"], "stay"),
		_choice("public", "„Wir gehen zum Fenner.“", ["set_flag:q_end_public", "set_flag:q_sieber_dies", "rep_event:public_duty",
				"piety_event:made_public", "rel_add:mayor:4", "goodwill:kin_sieber:-1", "set_flag:fenner_lightbook",
				"note_event:q_public"], "public"),
		_choice("silent", "(Nichts sagen)", ["set_flag:q_end_silent", "set_flag:q_sieber_dies"], "silent"),
	] as Array[QuestChoiceData]
	h6.deadline_flag = &"q_light_day"
	h6.deadline_offset = 17
	h6.fallback_choice = &"silent"
	main.steps = [
		_step("h1", "Die Rückseite", "Lies Lorenz' Kladde am Schreibpult in der Hütte.", QuestStepData.ON_NOTE, ["kladde_read"]),
		_step("h2", "Wer liegt unter dem Datum?", "Vergleich das Grabregister mit der Liste – und die Daten an den Gräbern.",
				QuestStepData.ON_NOTE, ["date_grave"], 5),
		_step("h3", "Wer hat das Licht gesehen?", "Frag die, die nachts die Fenster sehen.", QuestStepData.ON_INSIGHT, ["i_light_before"]),
		_step("h4", "„S.“", "Drei Häuser im Dorf fangen mit S an.", QuestStepData.ON_FLAG, ["q_sieber_marked"]),
		h5,
		h6,
	] as Array[QuestStepData]
	main.endings = [
		_ending("away", "Über den Hügel", "Johann ist fortgegangen, wie Lorenz.", "q_end_away", "sieber_gone",
				"Johann ist über den Hügel gegangen. Ob er angekommen ist, steht in keinem Brief, den du bekommen hast. Noch nicht."),
		_ending("stay", "Bei Grete", "Johann ist geblieben. Du hast ihm das Grab neben Grete gemacht.", "q_end_stay", "sieber_buried",
				"Johann hat sich nicht beeilt. Du hast ihm die Erde so tief gemacht, wie man es kann. Wann der Nächste kommt, steht in keinem Heft, das du hast."),
		_ending("public", "Vor der Gemeinde", "Fenner hat einen Wächter vor die Siebers gestellt. Johann ist trotzdem gestorben.", "q_end_public",
				"sieber_buried", "Fenner hat jetzt ein Buch für Lichter. Es hat sechs Einträge. Lorenz hatte auch sechs."),
		_ending("silent", "Geschwiegen", "Du hast nichts gesagt. Das Dorf hat seinen eigenen Lauf.", "q_end_silent", "sieber_buried",
				"Du hast die Liste gelesen und zugeklappt. Das Dorf hat sie nie gesehen. Das Licht schon."),
	] as Array[QuestEndingData]
	_save(main, OUT + "/quests/q_who_knows.tres")

	var letters := QuestData.new()
	letters.id = &"q_letters"
	letters.title = "Briefe ohne Antwort"
	letters.summary = "In den Taschen der Toten stecken Briefe an die Lebenden, und die Post bringt Briefe an die Toten. Du bist der Einzige, der beides in der Hand hat."
	letters.giver = &"carter"
	letters.open_conditions = _ps(["flag:p9_open"])
	letters.order = 20
	var l5 := _step("l5", "An L. Aschau", "Ein Brief mit Anker und Schlange.", QuestStepData.ON_CHOICE, [])
	l5.choices = [
		_choice("open", "Öffnen", ["add_clue:c_q_ferry_letter", "piety_event:letter_read_sealed", "set_flag:lorenz_letter_opened"], "done"),
		_choice("keep", "Versiegelt aufheben", ["set_flag:lorenz_letter_kept"], "done"),
		_choice("liesel", "Liesel geben", ["rel_add:washer:4", "set_flag:lorenz_letter_liesel"], "done"),
		_choice("burn", "Verbrennen", ["set_flag:lorenz_letter_burned"], "done"),
	] as Array[QuestChoiceData]
	letters.steps = [
		_step("l1", "Ein Brief in der Tasche", "Ein Toter hatte einen Brief bei sich. Wohin damit?", QuestStepData.ON_NOTE, ["pocket_decided"], 1),
		_step("l2", "Post für den Hügel", "Osric hat Post für einen, der oben liegt.", QuestStepData.ON_NOTE, ["post_decided"], 1),
		_step("l3", "Für den Bruder", "Gesa Ott hat einen Brief für ihren Bruder beim Militär.", QuestStepData.ON_ORDER,
				["oq_gesa_brother"], 0, ["oq_gesa_brother"]),
		_step("l4", "Eine Antwort", "Schreib einem, der auf Antwort wartet.", QuestStepData.ON_NOTE, ["answer_posted"], 1),
		l5,
	] as Array[QuestStepData]
	letters.endings = [_ending("done", "Briefe ohne Antwort", "Die Briefe sind dort, wo sie hingehören – oder in der Asche.",
			"q_letters_done", "", "")] as Array[QuestEndingData]
	_save(letters, OUT + "/quests/q_letters.tres")

	var case_q := QuestData.new()
	case_q.id = &"q_case"
	case_q.title = "Der Herr mit dem Koffer"
	case_q.summary = "Ein Herr aus der Stadt wartet am Tor und stellt Fragen, die man in Hollerbrück nicht stellt. Er zahlt immer passend."
	case_q.giver = &"stranger"
	case_q.open_conditions = _ps(["flag:p9_open"])
	case_q.order = 30
	var k5 := _step("k5", "Was er mitnimmt", "Am letzten Tag seines zweiten Besuchs.", QuestStepData.ON_CHOICE, [])
	k5.choices = [
		_choice("fenner", "Ihn bei Fenner anzeigen", ["rep_event:case_reported", "rel_add:mayor:4", "rel_add:surgeon:-6",
				"set_flag:case_end_fenner"], "fenner"),
		_choice("deal", "Mit ihm handeln", ["set_flag:case_end_deal"], "deal"),
		_choice("ilse", "Ihn zu Ilse schicken", ["piety_event:case_to_ilse", "set_flag:case_end_ilse"], "ilse"),
	] as Array[QuestChoiceData]
	case_q.steps = [
		_step("k1", "Fragen am Tor", "Ein Herr in einem Stadtrock wartet am Tor.", QuestStepData.ON_NOTE, ["stranger_answered"], 1),
		_step("k2", "Was er kaufen will", "Er will etwas kaufen. Er sagt nicht, wofür.", QuestStepData.ON_NOTE, ["stranger_offers_seen"], 1),
		_step("k3", "Wer zahlt für Frische?", "Wer hat ihn schon einmal gesehen?", QuestStepData.ON_CLUE, ["c_q_case_lorenz"]),
		_step("k4", "Der Koffer", "Rosine hat einen Koffer, den sie nicht anfassen will.", QuestStepData.ON_ORDER, ["oq_case_return"], 0,
				["oq_case_return"]),
		k5,
	] as Array[QuestStepData]
	case_q.endings = [
		_ending("fenner", "Über die Brücke", "Fenner und der Nachtwächter haben ihn über die Brücke gebracht.", "case_end_fenner", "", ""),
		_ending("deal", "Ein Handel", "Er hat bekommen, was er wollte. Fast.", "case_end_deal", "", ""),
		_ending("ilse", "An der Westmauer", "Er ist in der Nacht zu Ilse gegangen und am Morgen fort.", "case_end_ilse", "", ""),
	] as Array[QuestEndingData]
	_save(case_q, OUT + "/quests/q_case.tres")


# --- the list (§2.2.1) ----------------------------------------------------------------------------

func _light_list() -> void:
	var rows := [
		# id, initial, ink, story_id, fixed_text, open, witness_npc, witness_clue
		["e_dorn", "D.", "old", "s5_moor", "2. Julmond 1833", false, "washer", "c_q_light_dorn"],
		["e_quendel", "Q.", "fresh", "s1_quendel", "", false, "carter", "c_q_light_quendel"],
		["e_wernstein", "W.", "fresh", "s3_wernstein", "", false, "innkeeper", "c_q_light_wernstein"],
		["e_hagedorn", "H.", "fresh", "d1_hagedorn", "", false, "grocer", "c_q_light_hagedorn"],
		["e_ott", "O.", "fresh", "d2_ott", "", false, "kin_ott", "c_q_light_ott"],
		["e_open", "S.", "fresh", "", "", true, "beggar", "c_q_sieber"],
	]
	var list := LightListData.new()
	var entries: Array[LightEntryData] = []
	for r: Array in rows:
		var e := LightEntryData.new()
		e.id = StringName(r[0])
		e.initial = r[1]
		e.ink = StringName(r[2])
		e.story_id = StringName(r[3])
		e.fixed_text = r[4]
		e.open = r[5]
		e.witness_npc = StringName(r[6])
		e.witness_clue = StringName(r[7])
		entries.append(e)
	list.entries = entries
	list.footer = "Licht. Drei Wochen."
	list.struck = "Wer weiß, wann?"
	_save(list, OUT + "/quests/who_knows/list.tres")


# --- letters (§2.4.2, §2.4.3) ---------------------------------------------------------------------

func _letters() -> void:
	var rows := [
		# id, kind, outside, text, sealed, sender, recipient, asks, conditions, choice_actions, reply_text, story_id
		["lp_l1_carter", "pocket", "An Rosine Wackernagel, Holderkrug",
				"Rosine. Ich zahl die zwei Bier, wenn ich wiederkomme. Heb sie mir auf. Und sag dem Osric nicht, dass ich dir schulde, der lacht sonst.",
				false, "ein Fuhrknecht aus Ellbach", "innkeeper", "", [], {&"deliver": ["rel_add:innkeeper:3"]}, "", ""],
		["lp_l2_sister", "pocket", "An Grete Hollmann, bei Kaufmann Seidel, in der Stadt",
				"Liebe Schwester. Sag Mutter nichts. Ich komm zu Lichtmess. Der Dienst ist schwer, aber das Brot ist gut. Deine Anne.",
				true, "eine Magd", "town", "", [], {}, "Danke, dass Sie es mir geschrieben haben. Jetzt weiß ich es wenigstens.", ""],
		["lp_l3_burn", "pocket", "Ungelesen verbrennen",
				"Komm nicht zurück nach Hollerbrück. Was du suchst, sucht dich auch.",
				true, "ein Tagelöhner", "none", "burn", [], {&"read": ["add_clue:c_warning_letter"]}, "", ""],
		["lg_priest", "pocket", "An Herrn Pfarrer Lenz",
				"Herr Pfarrer. 1829 hab ich drei Gulden aus dem Opferstock genommen. Ich hab sie zurückgelegt, mit Zins. Ich wollt's nur gesagt haben.",
				true, "ein Altbauer", "priest", "", [], {&"deliver": ["rel_add:priest:3"]}, "", ""],
		["lg_grocer", "pocket", "An Theres Mangold, Krämerin",
				"Theres. Holunderwein wie bei Mutter: Beeren nach dem ersten Frost, Honig statt Zucker, und nie vor Lichtmess aufmachen.",
				false, "eine Base", "grocer", "", [], {&"deliver": ["rel_add:grocer:3"]}, "", ""],
		["lg_wife", "pocket", "An meine Frau",
				"Der Rock hängt im Schrank. Verkauf ihn nicht unter zwei Gulden. Und zünd mir keine Kerze an, das ist zu teuer.",
				true, "ein Ehemann", "", "", ["kin_house"], {&"deliver": ["goodwill:kin:2"]}, "", ""],
		["lg_nobody", "pocket", "An den, der das findet",
				"Ich hatte keine Angst. Sag es keinem, sonst glaubt es keiner.",
				false, "ein Unbekannter", "none", "grave", [], {}, "", ""],
		["lg_town", "pocket", "An das Kontor Bremer & Sohn, in der Stadt",
				"Die Ware ist bis Ellbach gekommen. Weiter nicht. Ich auch nicht.",
				true, "ein Händler", "town", "", [], {}, "", ""],
		["lg_smith", "pocket", "An Meister Esch, Schmiede",
				"Meister. Ich hab die Zange mitgenommen. Sie ist im Graben bei der Mühle. Es tut mir leid.",
				false, "ein Lehrling", "smith", "", [], {&"deliver": ["rel_add:smith:3", "give_item:iron_fittings:1"]}, "", ""],
		["lg_lambert", "pocket", "An Lambert Grell",
				"Lambert. Die Ziegelei nimmt wieder Leute. Komm, wenn du willst. Fragen tut hier keiner.",
				false, "ein Ziegler", "robber", "", ["robber_fate:let_go"], {&"deliver": ["piety_event:letter_delivered"]}, "", ""],
		["lp_d3_grete", "pocket", "An Grete",
				"(Ein Zettel mit einem gemalten Kreuz. Darin eine graue Haarlocke.)",
				false, "Johann Sieber", "grave", "grave", ["story:d3_sieber"], {&"bury": ["piety_event:letter_buried"]}, "", ""],
		["lpo_quendel", "post", "An Marthe Quendel, Hollerbrück",
				"Marthe. Du schreibst nicht mehr. Bist du mir böse? Ich hab dir doch das Tuch geschickt. Deine Schwester Dora, Ellbach.",
				true, "ihre Schwester aus Ellbach", "grave", "", [], {}, "", "s1_quendel"],
		["lpo_wernstein", "post", "An Jungfer Ida Wernstein, Hollerbrück",
				"Die Stelle als Köchin ist Ihre, wenn Sie bis Martini kommen. Wir erwarten Sie. Frau Amtmann Seidel.",
				true, "eine Herrschaft in der Stadt", "grave", "", [], {}, "", "s3_wernstein"],
		["lpo_ott", "post", "An Gerhard Ott, Hollerbrück",
				"Vater. Wir stehen jetzt in Mainz. Es regnet. Schreib mir, ob die Kuh gekalbt hat. Dein Peter.",
				true, "sein Sohn beim Militär", "kin_ott", "", [], {&"deliver": ["goodwill:kin_ott:4"]}, "", "d2_ott"],
		["lpo_hagedorn", "post", "An Wiebke Hagedorn, Hollerbrück",
				"Werte Frau Hagedorn. Ob Sie zu Weihnachten wieder die zweite Stimme singen? Ohne Sie fällt der Alt so dünn aus. Der Gesangverein.",
				true, "der Gesangverein", "grave", "", [], {}, "", "d1_hagedorn"],
		["lpo_aschau", "post", "An L. Aschau, Totengräber zu Hollerbrück",
				"Die Fähre geht wieder. Sag, wann.",
				true, "(gesiegelt mit Anker und Schlange)", "none", "", [], {}, "", ""],
	]
	for r: Array in rows:
		var l := LetterData.new()
		l.id = StringName(r[0])
		l.kind = StringName(r[1])
		l.outside = r[2]
		l.text = r[3]
		l.sealed = r[4]
		l.sender = r[5]
		l.recipient = StringName(r[6])
		l.asks = StringName(r[7])
		l.conditions = _ps(r[8])
		var acts: Dictionary[StringName, PackedStringArray] = {}
		for k: Variant in r[9]:
			acts[StringName(str(k))] = _ps(r[9][k])
		l.choice_actions = acts
		l.reply_text = r[10]
		l.story_id = StringName(r[11])
		_save(l, OUT + "/letters/%s.tres" % r[0])


# --- Brenneisen's offers (§2.5.2 K2, K5) ----------------------------------------------------------

func _stranger_offers() -> void:
	var rows := [
		["so_soil", "Eine Handvoll Erde von einem frischen Grab", "soil_pouch", 3, ["fresh_grave_days:5"],
				["piety_event:soil_sold"], "Eine Handvoll. Für die Wissenschaft, sagt er."],
		["so_register", "Eine Abschrift des Grabregisters", "register_extract", 10, ["has_item:register_extract"],
				["piety_event:register_sold", "note_event:register_sold"], "Lenz wird es erfahren."],
		["so_specimen", "Ein Präparat", "", 0, ["flag:anatomy_known"], ["note_event:visit_specimen_rumor"],
				"Er zahlt mehr als Quast. Im Dorf wird man davon reden."],
		["so_kladde", "Lorenz' Kladde", "lorenz_ledger_2", 40, ["quest_ended:q_who_knows"],
				["piety_event:kladde_sold", "set_flag:kladde_sold"], "Die Liste brauchen Sie nicht mehr, sagt er."],
	]
	for r: Array in rows:
		var o := StrangerOfferData.new()
		o.id = StringName(r[0])
		o.label = r[1]
		o.item = StringName(r[2])
		o.price = r[3]
		o.conditions = _ps(r[4])
		o.actions = _ps(r[5])
		o.note = r[6]
		_save(o, OUT + "/stranger/offers/%s.tres" % r[0])


# --- larger requests (§2.3.3) ---------------------------------------------------------------------

func _part(kind: String, title: String, conditions: Dictionary = {}, items: Dictionary = {}, recipient: String = "") -> OrderData:
	var p := OrderData.new()
	p.kind = StringName(kind)
	p.title = title
	p.conditions = conditions
	p.items = _si(items)
	p.recipient = StringName(recipient)
	p.category = OrderData.CATEGORY_HILL
	return p


func _large_requests() -> void:
	var rows := [
		# id, place, giver, title, request, thanks, days, coins, rep, conditions, cooldown, order, parts, in_order
		["hrl_ferry_graves", "gate", "priest", "Die Gräber der Fähre",
				"Pfarrer Lenz lässt durch Osric ausrichten: „Im Alten Hof liegen die von der Fähre. Keiner kommt mehr zu ihnen. Mach es dort ordentlich, und hör hin, ob einer redet.“",
				"Lenz liest Osrics Zettel zweimal. „Dann haben sie wieder einen, der hinsieht“, lässt er sagen.", 3, 4, 2,
				{"min_day": 2, "reward_items": {"altar_candle": 2}}, 9, 10,
				[_part("tend", "Die vier Pflegestellen im Alten Hof säubern", {"spots": ["dirt_y03", "dirt_y04", "dirt_y07", "dirt_y08"]}),
				_part("decor", "Zwei Zierstücke im Alten Hof", {"decor": ["decor_flowerbed", "decor_grave_vase", "decor_lantern"],
						"section": "yard", "amount": 2}),
				_part("ghost", "Nachts einem Geist im Alten Hof zuhören", {"section": "yard"})], false],
		["hrl_crosses", "gate", "mayor", "Drei Kreuze für den Hohlweg",
				"Gottlieb Fenner, der Schultheiß: „Am Hohlweg sind drei verunglückt, über die Jahre. Die Gemeinde will drei Kreuze. Schlicht. Osric stellt sie auf.“",
				"Fenner hat die Kreuze ins Gemeindebuch eingetragen, sagt Osric. „Drei Stück, ordentlich.“", 3, 4, 2,
				{"min_day": 2}, 8, 20,
				[_part("craft", "Drei Holzkreuze an der Werkbank", {"recipe": "wooden_cross", "amount": 3}),
				_part("deliver", "Bei Osric abgeben", {}, {"wooden_cross": 3}, "carter")], true],
		["hrl_proper_grave", "gate", "carter", "Ein Grab, wie es sich gehört",
				"Osric: „Den Nächsten bring ich dir morgen. Mach ihn, wie es sich gehört. Ganz. Von vorn bis hinten. Einmal will ich das sehen.“",
				"„So“, sagt Osric und nimmt die Mütze ab. „So hab ich's mir gedacht.“", 3, 5, 2,
				{"min_day": 3, "reward_items": {"linen": 1}}, 10, 30,
				[_part("exam", "Die nächste Lieferung gründlich untersuchen"),
				_part("prep", "Gewaschen, gekleidet, aufgebahrt bestatten", {"washed": true, "dressed": true, "laid_out": true}),
				_part("marker", "Ein Grabstein", {"marker": "gravestone_simple"}),
				_part("tend", "Die zwei Nachbargräber säubern", {"grave": "neighbors", "count": 2})], true],
		["hrl_bench_path", "gate", "grocer", "Ein Platz zum Ausruhen",
				"Theres Mangold: „Der Weg hinauf ist lang für alte Knie. Mach einen Platz zum Ausruhen frei, stell eine Bank hin und harke das Laub weg. Dann setz ich mich auch.“",
				"Theres hat sich gesetzt, sagt Osric. Ziemlich lange. Dann hat sie ihm Samen für dich mitgegeben.", 3, 4, 2,
				{"min_day": 3, "reward_items": {"seeds": 1}}, 9, 40,
				[_part("clear", "Ein Hindernis im Birkenhang oder Holunderwinkel roden", {"sections": ["north", "elder"]}),
				_part("craft", "Eine Holzbank an der Werkbank", {"recipe": "decor_bench_wood", "amount": 1}),
				_part("decor", "Die Bank am Weg aufstellen", {"decor": ["decor_bench_wood"], "amount": 1}),
				_part("tend", "Das Laub ringsum harken", {"spots": ["dirt_n01", "dirt_n02"], "requires_item": "rake"})], false],
		["hrl_restless", "gate", "washer", "Eine Nacht für die Unruhigen",
				"Liesel Dorn: „Manche reden nachts. Hör dreien zu, in einer Nacht. Und am Morgen mach ihnen die Gräber sauber. Dann schlafen sie besser. Ich auch.“",
				"„Drei“, sagt Liesel durch Osric. „Das ist eine gute Nacht gewesen. Für sie.“", 2, 3, 2,
				{"min_day": 4, "reward_items": {"linen": 1}}, 9, 50,
				[_part("ghosts", "Drei Geistern in einer Nacht zuhören", {"times": 3}),
				_part("tend", "Am Morgen ihre Gräber säubern", {"grave": "ghosts_tonight"})], true],
		["hrl_widow_wood", "gate", "kin_kehr", "Holz für die Witwen",
				"Martha Kehr: „Bei den Witwen am Bach ist kein Holz mehr im Schuppen. Zehn Scheite, mehr braucht's nicht für den Anfang. Osric fährt es hinunter.“",
				"Martha Kehr lässt danken. „Jetzt rauchen bei ihnen wieder die Schornsteine. Das sieht man vom Hügel aus.“", 2, 4, 2,
				{"min_day": 2}, 8, 60,
				[_part("gather", "Zehn Holz schlagen oder roden", {"item": "wood", "amount": 10}),
				_part("deliver", "Bei Osric abgeben", {}, {"wood": 10}, "carter")], true],
		["hrl_lantern_path", "gate", "carter", "Licht am Kutschweg",
				"Osric: „Nachts seh ich das Tor erst, wenn der Gaul davorsteht. Zwei Laternen, und einmal stehst du da, wenn ich vorbeikomm. Damit ich weiß, dass einer wach ist.“",
				"„Zwei Lichter und einer, der winkt“, sagt Osric. „Jetzt fahr ich gern vorbei.“", 3, 4, 2,
				{"min_day": 5}, 9, 70,
				[_part("craft", "Zwei Grablaternen an der Werkbank", {"recipe": "decor_lantern", "amount": 2}),
				_part("decor", "Am Tor aufstellen", {"decor": ["decor_lantern"], "amount": 2, "near": "gate"}),
				_part("visit", "Nachts am Tor stehen, bis Osric vorbeifährt", {"place": "gate_outside", "minutes": 20,
						"window": [_hm("21:30"), _hm("23:00")], "label": "[E] Am Tor warten, bis Osric vorbeifährt (20 Min)"})], false],
		["hrl_old_names", "gate", "priest", "Namen, die man noch lesen kann",
				"Pfarrer Lenz: „Auf den alten Gräbern kann man die Namen nicht mehr lesen. Zwei sollen wieder einen haben. Und hör hin, ob einer von ihnen etwas sagt.“",
				"Lenz hat die beiden Namen ins Sterbebuch nachgetragen, sagt Osric. „Spät, aber ordentlich.“", 3, 5, 2,
				{"min_day": 6}, 10, 80,
				[_part("craft", "Zwei Steine für Altgräber (sonst Holzkreuze)", {"recipe": "gravestone_simple", "alt_recipe": "wooden_cross",
						"alt_unless_station": "mason", "amount": 2}),
				_part("tend", "Die Grabstellen säubern", {"grave": "old_dirty", "count": 2}),
				_part("ghost", "Einem dieser Geister zuhören", {"grave": "request_graves"})], false],
		["hrv_bridge_stones", "village", "mayor", "Steine für die Holderbrücke",
				"An der Gemeindetafel: Die Holderbrücke braucht neue Steine am Pfeiler. Die Gemeinde bittet den Totengräber, der weiß, wo Stein liegt. – G. Fenner, Schultheiß",
				"Fenner nickt an der Brücke. „Das hält wieder. Länger als ich, hoffentlich.“", 3, 5, 2,
				{"requires_flag": "village_open"}, 9, 110,
				[_part("gather", "Acht Steine sammeln", {"item": "stone", "amount": 8}),
				_part("gather", "Zwei Werksteine im Steinbruch", {"item": "workstone", "amount": 2}),
				_part("visit", "An der Brücke abladen", {"place": "v_bridge_unload", "minutes": 20, "label": "[E] Steine abladen (20 Min)"})], false],
		["hrv_paul_day", "village", "kin_kehr", "Ein Tag für Paul",
				"Martha Kehr an der Gemeindetafel: „Paul hat bald Namenstag. Ich möcht ihm Blumen aufs Grab, und Quast braucht Kräuter für mein Herz. Und dann möcht ich oben mit dir stehen. Einmal.“",
				"Martha Kehr hat lange am Grab gestanden, sagt Rosine. „Danach hat sie gelacht. Zum ersten Mal seit dem Sommer.“", 3, 3, 2,
				{"requires_flag": "p8_open", "reward_goodwill": {"kin_kehr": 2}}, 10, 120,
				[_part("deliver", "Zwei Kräuterbündel an Quast", {}, {"herb_bundle": 2}, "surgeon"),
				_part("flowers", "Grabblumen auf die Gräber der Kehrs", {"graves": "kin_kehr"}),
				_part("meet", "Martha am Grab treffen", {"npc": "kin_kehr", "place": "kin_grave", "window": [_hm("09:30"), _hm("12:00")]})], false],
		["hrv_inn_cellar", "village", "innkeeper", "Der Keller im Holderkrug",
				"Rosine Wackernagel: „Im Keller steht das Wasser, und der Holunder muss rein, bevor er gärt. Bring Beeren und Holz, und pack einmal mit an. Ich zahl in Wein.“",
				"„Trocken und voll“, sagt Rosine. „So mag ich meinen Keller. Und dich auch, heute.“", 2, 4, 1,
				{"requires_flag": "village_open", "reward_items": {"elder_wine": 1}}, 9, 130,
				[_part("gather", "Sechs Holunderbeeren", {"item": "elderberries", "amount": 6}),
				_part("gather", "Vier Holz", {"item": "wood", "amount": 4}),
				_part("visit", "Im Keller helfen", {"place": "v_inn_cellar_help", "minutes": 40, "window": [_hm("14:00"), _hm("17:00")],
						"label": "[E] Rosine im Keller helfen (40 Min)"})], false],
		["hrv_church_candles", "village", "priest", "Kerzen für St. Gallus",
				"Pfarrer Lenz an der Gemeindetafel: „Der Advent kommt, und der Altar hat nur Stummel. Vier Kerzen, eine Andacht oben in der Kapelle, und dann kommen Sie zu mir in die Kirche.“",
				"Lenz zündet die erste Kerze an, als Sie hereinkommen. „Die anderen drei warten. Wie wir alle.“", 3, 4, 2,
				{"requires_flag": "buildings_open"}, 10, 140,
				[_part("deliver", "Vier Altarkerzen besorgen", {}, {"altar_candle": 4}, "priest"),
				_part("devotion", "Eine Andacht in der Kapelle"),
				_part("meet", "Lenz in der Kirche treffen", {"npc": "priest", "place": "church", "window": [_hm("16:00"), _hm("18:00")]})], false],
	]
	for r: Array in rows:
		var o := OrderData.new()
		o.id = StringName(r[0])
		o.place = StringName(r[1])
		o.giver = StringName(r[2])
		o.title = r[3]
		o.request_text = r[4]
		o.thanks_text = r[5]
		o.days_limit = r[6]
		o.reward_coins = r[7]
		o.reward_rep = r[8]
		var cond: Dictionary = (r[9] as Dictionary).duplicate(true)
		if cond.has("requires_flag"):
			o.requires_flag = StringName(str(cond["requires_flag"]))
			cond.erase("requires_flag")
		o.conditions = cond
		o.cooldown_days = r[10]
		o.order = r[11]
		o.parts.assign(r[12])
		o.parts_in_order = r[13]
		o.kind = &"large"
		o.size = OrderData.SIZE_LARGE
		o.category = OrderData.CATEGORY_HILL
		_save(o, OUT + "/hill_requests/large/%s.tres" % r[0])


# --- orders of category quest (§2.4.4, §2.2.7 ending B, §2.5.2 K4) --------------------------------

func _quest_orders() -> void:
	var rows := [
		# id, giver, recipient, kind, title, request, items, target, conditions, days_limit
		["oq_gesa_brother", "kin_ott", "", "deliver", "Für den Bruder",
				"Gesa Ott: „Mein Bruder steht beim Militär. Er weiß nicht, dass Vater tot ist. Ich hab's aufgeschrieben. Gib es der Post, wenn sie kommt.“",
				{}, "post", {"letter": "gesa_brother", "carriers": ["peddler", "carter"], "or_pay": "straw_bouquet"}, 3],
		["oq_fenner_seal", "mayor", "priest", "deliver", "Fenners Siegel",
				"Fenner: „Eine Bekanntmachung der Gemeinde für den Pfarrer. Versiegelt. Sie bleibt versiegelt.“",
				{}, "", {"sealed": true, "seal_broken_rel": {"mayor": -3}}, 2],
		["oq_liesel_bundle", "washer", "kin_sieber", "deliver", "Ein Bündel für die Siebers",
				"Liesel Dorn: „Bring das zu Anna Sieber. Leinen. Für später. Sie weiß schon.“",
				{}, "door_sieber", {"gives": {"linen": 2}, "requires_flag_not": "sieber_gone"}, 2],
		["oq_jakob_father", "apprentice", "", "task", "An Vater",
				"Jakob hält dir einen gefalteten Zettel hin. „Für Vater. Er hat kein Grab. Du weißt doch, wo man so was hinbringt.“",
				{}, "", {"action_id": "jakob_letter", "places": ["church", "v_bridge"]}, 0],
		["oq_johann_evening", "kin_sieber", "", "meet", "Ein Abend bei Johann",
				"Johann sitzt auf der Bank vor dem Haus. „Setz dich. Wenn du willst. Ich hab Zeit.“",
				{}, "", {"npc": "kin_sieber", "place": "v_sieber_bench", "window": [_hm("18:00"), _hm("20:00")], "times": 2, "minutes": 30}, 0],
		["oq_case_return", "innkeeper", "stranger", "deliver", "Der Koffer",
				"Rosine: „Bring ihn rauf, er wartet am Tor. Ich fass das Ding nicht an.“",
				{"stranger_case": 1}, "stranger_gate", {}, 1],
	]
	var order := 900
	for r: Array in rows:
		var o := OrderData.new()
		o.id = StringName(r[0])
		o.giver = StringName(r[1])
		o.recipient = StringName(r[2])
		o.kind = StringName(r[3])
		o.title = r[4]
		o.request_text = r[5]
		o.thanks_text = ""
		o.items = _si(r[6])
		o.target = r[7]
		o.conditions = r[8]
		o.days_limit = r[9]
		o.category = OrderData.CATEGORY_QUEST
		o.order = order
		order += 1
		_save(o, OUT + "/orders/%s.tres" % r[0])


# --- items (§2.9) ---------------------------------------------------------------------------------

func _items() -> void:
	var rows := [
		["letter", "Brief", "Ein gefalteter Brief. Außen eine Aufschrift in einer Hand, die selten schreibt.", ItemData.Category.GOODS, 1, true],
		["letter_reply", "Antwort", "Eine Antwort in deiner Hand, gefaltet und bereit für die Post.", ItemData.Category.GOODS, 1, true],
		["nameless_letter", "Brief ohne Namen", "Ein Brief ohne Absender, in einer Hand, die nicht deine sein soll. Wie Lorenz sie schrieb.",
				ItemData.Category.GOODS, 1, false],
		["stranger_case", "Ein Lederkoffer", "Ein brauner Lederkoffer mit Messingschloss. Schwerer, als er aussieht. Er riecht nach Branntwein.",
				ItemData.Category.GOODS, 1, false],
		["case_card", "Visitenkarte „C. Brenneisen, Commissionär“", "Eine steife Karte mit Goldrand. Auf der Rückseite eine Adresse in der Stadt.",
				ItemData.Category.GOODS, 1, false],
		["soil_pouch", "Eine Handvoll Grabeserde", "Erde von einem frischen Grab, in ein Tuch geknotet. Nur einer will so etwas kaufen.",
				ItemData.Category.GOODS, 3, false],
		["straw_bouquet", "Strohblumen-Strauß", "Gesas Strohblumen, mit Garn gebunden. Halten auf einem Grab länger als frische.",
				ItemData.Category.MATERIAL, 3, false],
	]
	for r: Array in rows:
		var item := ItemData.new()
		item.id = StringName(r[0])
		item.display_name = r[1]
		item.description = r[2]
		item.category = r[3]
		item.max_stack = r[4]
		item.unique = r[5]
		_save(item, ITEMS_OUT + "/%s.tres" % r[0])


# --- journal (§2.2) -------------------------------------------------------------------------------

func _journal() -> void:
	var clues := [
		["c_q_dates", "Die Liste", "page", "Auf der Rückseite der Seite mit den drei Namen: sechs Einträge, ein Datum und ein Buchstabe. Die ersten in brauner, alter Tinte, die späteren in schwarzer, frischer. Darunter: ‚Licht. Drei Wochen.‘ Und durchgestrichen: ‚Wer weiß, wann?‘"],
		["c_q_three_weeks", "Immer drei Wochen", "note", "Immer drei Wochen. Nie zwanzig Tage, nie zweiundzwanzig."],
		["c_q_light_dorn", "Licht bei den Dorns", "talk", "Bei uns brannte ein Licht in der Kammer. Kaspar hat gesagt, das war ich. Ich hab gesagt, das war er. Drei Wochen später ist er ins Moor gegangen und nicht wiedergekommen."],
		["c_q_light_quendel", "Licht bei der Quendel", "talk", "Bei der Quendel brannte Licht, oben, um eins. Osric fährt da nachts vorbei. Er hält nie an. Diesmal hätte er vielleicht sollen, sagt er."],
		["c_q_light_wernstein", "Licht bei der Wernstein", "talk", "Ida Wernstein hat Rosine erzählt, in ihrer Kammer hätte die ganze Nacht ein Licht gebrannt, und sie hätte keins angezündet. Am nächsten Tag lag ein Brief unter ihrer Tür."],
		["c_q_light_hagedorn", "Licht bei der Hagedorn", "talk", "Theres sah vom Laden aus ein Licht bei der Hagedorn, und die Alte war gesund wie ein Pferd. Man denkt sich bei Licht nichts. Das ist ja das Schlimme."],
		["c_q_light_ott", "Licht bei den Otts", "talk", "Drei Wochen vorher brannte schon mal eins, in Vaters Kammer. Da war er noch gesund. Er hat gesagt, er war's nicht. Gesa lacht da nicht mehr."],
		["c_q_sieber", "Bei den Siebers", "talk", "Bei den Siebers, oben beim Alten. Keiner hat es angezündet. Es war einfach da, und um fünf war es weg. Johann sagt, er war's nicht. Er lügt nie, der Alte. Er ist zu langsam zum Lügen."],
		["c_q_hand_answers", "Die schräge Hand antwortet", "letter", "An der Hüttentür steckt ein Zettel in der schrägen Hand der Warnbriefe: ‚Du schreibst wie er. Gut.‘"],
		["c_q_ferry_letter", "Die Fähre geht wieder", "letter", "Ein Brief an L. Aschau, gesiegelt mit Anker und Schlange: ‚Die Fähre geht wieder. Sag, wann.‘"],
		["c_q_case_lorenz", "Der Herr war schon einmal da", "talk", "Brenneisen hat Lambert Grell bezahlt – für Nachrichten, sagt er, nicht für Leiber. Vor einem Jahr war er schon bei Lorenz. Lorenz hat ihn mit der Schaufel vom Hügel gejagt."],
		["c_q_case_list", "Ein Blatt im Koffer", "page", "Im Koffer, zwischen Samt und Gläsern, ein Brief von Quast (‚Die beiden letzten, wie besprochen.‘) und ein Blatt: ‚Hollerbrück – Gezeichnete. Herzen still. Zahle das Doppelte.‘"],
	]
	var order := 400
	for r: Array in clues:
		var c := ClueData.new()
		c.id = StringName(r[0])
		c.title = r[1]
		c.kind = StringName(r[2])
		c.text = r[3]
		c.order = order
		order += 1
		_save(c, OUT + "/clues/%s.tres" % r[0])
	var i := InsightData.new()
	i.id = &"i_light_before"
	i.order = 40
	i.title = "Das Licht vorher"
	i.question = "Was haben die Lichter mit den Toten zu tun?"
	i.text = "In der Nacht, in der einer gezeichnet wird, brennt in seinem Haus ein Licht, das keiner aus dem Haus angezündet hat. Drei Wochen später stirbt er. Wer das Licht sieht, weiß, wann. Lorenz hat die Lichter gezählt."
	i.requires = _sn(["c_q_dates", "c_q_three_weeks"])
	i.any_clues = _sn(["c_q_light_dorn", "c_q_light_quendel", "c_q_light_wernstein", "c_q_light_hagedorn", "c_q_light_ott"])
	i.any_count = 3
	i.sets_flag = &"insight_light_before"
	_save(i, OUT + "/insights/i_light_before.tres")


# --- D3 Johann Sieber (§2.7) ----------------------------------------------------------------------

func _story() -> void:
	var d := StoryCorpseData.new()
	d.id = &"d3_sieber"
	d.order = 8
	d.earliest_day = 1
	d.display_name = "Johann Sieber"
	d.age = 71
	d.cause_id = &"old_age"
	d.traits = _sn(["strange_wound"])
	d.valuables_coins = 0
	d.look = 2
	d.finds = _sn(["f_d3_mark", "f_d3_ribbon"])
	d.arrival_note = "Der alte Sieber. Heute Nacht. Liesel war schon da. Er hat gesagt, ich soll dir sagen: nicht beeilen. Ich hab's ausgerichtet."
	d.section = &"linden_row4"
	d.requires_flag = &"q_sieber_dies"
	d.due_flag = &"sieber_dead"
	_save(d, OUT + "/story/d3_sieber.tres")
	var finds := [
		["f_d3_mark", "wounds", "Das Zeichen, verheilt", "Das Zeichen über dem Herzen, verheilt seit drei Wochen. Auf den Tag.", 0.3, "strange_wound"],
		["f_d3_ribbon", "pockets", "Ein Band", "Ein Band aus Gretes Haube.", 0.0, ""],
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


# --- np_sieber (§2.2.2) ---------------------------------------------------------------------------

func _visit(npc: StringName, night: int, enter: String, leave: String, anim: StringName = &"walk") -> NightVisitData:
	var v := NightVisitData.new()
	v.npc_id = npc
	v.night_offset = night
	v.enter_minute = _hm(enter)
	v.leave_minute = _hm(leave)
	v.clue_id = &""
	v.animation = anim
	return v


func _night_path() -> void:
	var p := NightPathData.new()
	p.id = &"np_sieber"
	p.house = &"house_sieber"
	p.patient = "Johann Sieber"
	p.start_offset = 19
	p.end_offset = 20
	p.visits = [_visit(&"surgeon", 19, "22:30", "23:10"), _visit(&"priest", 20, "21:00", "21:40"),
			_visit(&"washer", 20, "02:40", "05:30")] as Array[NightVisitData]
	p.death_offset = 20
	p.death_minute = 130
	p.death_flag = &"sieber_dead"
	p.watch_spot = &"watch_sieber"
	p.anchor_flag = &"q_light_day"
	p.cancel_flag = &"sieber_gone"
	_save(p, OUT + "/night/paths/np_sieber.tres")


# --- the fourth row (§2.6) ------------------------------------------------------------------------

func _section() -> void:
	var s := (Database.section(&"linden_row3") as SectionData).duplicate(true) as SectionData
	s.id = &"linden_row4"
	s.display_name = "Vierte Reihe am Lindenacker"
	s.order = 10
	s.unlock_text = "Die Gemeinde gibt dir die vierte Reihe. Die letzte, sagt Fenner."
	s.requires_flag = &"linden_row4_granted"
	s.unlock_flag = &"linden_row4_granted"
	_save(s, OUT + "/sections/linden_row4.tres")
