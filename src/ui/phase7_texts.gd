class_name Phase7Texts
extends RefCounted
## Texts and small pure helpers of the Phase-7 UI (docs/PHASE7_DESIGN.md §7): the village shops, gifts,
## orders (board, dialogue, the Merkbuch page „Aufträge"), the Merkbuch page „Hollerbrück", the
## anatomist's panel, the lecture, the pult, the collection, the cause deduction, the specimen card of the
## crypt table, the HUD (region name, remarks), the objective lines, the register / death note / day
## summary additions and the chapter panel „Ein Name im Dorf".
## Reads only its arguments and static game data (Database, configs) – never live game state.
## The anatomy stays implied: words like „Glas", „Bündel", „Etikett", never what lies inside.

const NONE := "–"
const COIN := &"coin"
const PIP_ON := "●"
const PIP_OFF := "○"
const PIPS := 5
const CHECK_ON := "✓"
const CHECK_OFF := "–"
const SEP := " · "

# --- people & relationships -----------------------------------------------------------------------
const COUNCIL := &"council"
const COUNCIL_NAME := "die Gemeinde"
const COUNCIL_TITLE := "Gemeinde"
const REL_LINE := "%s  %s"
const NOT_MET := "noch nicht begegnet"
const VILLAGER_ORDER: Array[StringName] = [&"innkeeper", &"smith", &"grocer", &"priest", &"mayor", &"surgeon", &"washer",
		&"oldwoman"]
## Short names for lines like „+8 Fenner" (fallback: the last word of the display name).
const SHORT_NAMES: Dictionary[StringName, String] = {
	&"innkeeper": "Rosine", &"smith": "Esch", &"grocer": "Theres", &"priest": "Lenz", &"mayor": "Fenner",
	&"surgeon": "Quast", &"washer": "Liesel", &"oldwoman": "Hagedorn", &"council": "Gemeinde",
}

# --- shop panel -----------------------------------------------------------------------------------
const SHOP_BUY := "Kaufen"
const SHOP_SELL := "Verkaufen"
const SHOP_ONE := "1"
const SHOP_FIVE := "5"
const SHOP_PRICE := "%d %s"
const SHOP_PRICE_BB := "[s]%d[/s] %d %s"
const SHOP_SURCHARGE := "+%d (Ruf)"
const SHOP_STOCK := "noch %d heute"
const SHOP_SOLD_OUT := "heute ausverkauft"
const SHOP_BOUGHT_LEFT := "nimmt noch %d"
const SHOP_ENOUGH := "nimmt heute nichts mehr"
const SHOP_HELD := "du hast %d"
const SHOP_COINS := "Münzen im Beutel: %d"
const SHOP_HINT := "Umschalt + Klick: 5 Stück"
const SHOP_NOTHING_BOUGHT := "Hier wird nichts angekauft."
const SHOP_NOTHING_SOLD := "Hier gibt es nichts zu kaufen."
const SHOP_CLOSED := "Gerade steht niemand am Laden."
const SHOP_AFTER_BUY := "„Bitte sehr.“"
const SHOP_AFTER_SELL := "„Das nehm ich gern.“"
const SHOP_TITLE_FALLBACK := "Laden"
const SHOP_DISCOUNT_TIP := "Für Vertraute einen Taler weniger."

# --- gift panel -----------------------------------------------------------------------------------
const GIFT_TITLE := "Ein Geschenk für %s"
const GIFT_INTRO := "Einmal am Tag. Was jemand mag, merkst du dir, sobald es angenommen wurde."
const GIFT_BUTTON := "Schenken"
const GIFT_LIKED := "mag das"
const GIFT_NOTHING := "Du hast nichts dabei, was sich verschenken ließe."
const GIFT_THANKS := "„Das ist nett von dir. Wirklich.“"
const GIFT_TODAY := "Für heute hast du schon etwas mitgebracht."
const GIFT_KNOWN_FLAG := "gifts_known_%s"

# --- orders ---------------------------------------------------------------------------------------
const ORDERS_TITLE_BOARD := "Gemeindetafel an der Linde"
const ORDERS_TITLE_ASK := "Eine Bitte"
const ORDERS_EMPTY := "Heute hängt nichts an der Tafel."
const ORDER_FROM := "von %s"
const ORDER_FOR := "abzugeben bei %s"
const ORDER_DAYS_OFFER := "Frist: %d %s"
const ORDER_DAYS_LEFT := "noch %d %s"
const ORDER_DAYS_TODAY := "bis morgen früh"
const ORDER_NO_DEADLINE := "ohne Frist"
const ORDER_ACCEPT := "Annehmen"
const ORDER_ACCEPTED := "Angenommen"
const ORDER_DONE := "Erledigt"
const ORDER_FAILED := "Versäumt"
const ORDER_REWARD_COINS := "%d %s"
const ORDER_REWARD_REL := "▲ %s %s"
const ORDER_REWARD_REP := "Ruf %s"
const ORDER_PAGE := "Karte %d / %d  ·  [ ] blättern"
const ORDER_ACTIVE_COUNT := "Laufende Aufträge: %d von %d"
const DAY_ONE := "Tag"
const DAY_MANY := "Tage"
## OrderData.conditions → checklist label.
const CONDITION_LABELS: Dictionary[String, String] = {
	"dress": "eingekleidet", "service": "Aussegnung", "prepared": "voll hergerichtet", "unharvested": "unverwertet",
	"section": "Abschnitt", "stone_shape": "Steinform", "ornament": "Zierde", "gilded": "vergoldet", "inscription": "Inschrift",
	"mornings": "Morgen in Folge", "min_clarity": "Klarheit", "organ": "Präparat",
}
const DRESS_WORDS: Dictionary[String, String] = {"shroud": "Leichentuch", "gown": "Totenhemd"}
const SECTION_WORDS: Dictionary[String, String] = {"linden": "Lindenacker"}
const ORDER_TEND := "%d Morgen ohne Pflegeabzug"
const ORDER_GRAVE_OF := "Grab von %s"
const ORDER_SECTION_CLEAR := "%s räumen"
# Merkbuch page „Aufträge"
const PAGE_ORDERS := "Aufträge"
const PAGE_ORDERS_ACTIVE := "Laufend"
const PAGE_ORDERS_DONE := "Erledigt"
const PAGE_ORDERS_FAILED := "Versäumt"
const PAGE_ORDERS_NONE := "Noch hast du keinem im Dorf etwas versprochen."
const PAGE_ORDERS_NONE_DONE := "Noch nichts erledigt."
const PAGE_ORDER_DONE_DAY := "erledigt · %s"
const PAGE_ORDER_DONE := "erledigt"
const PAGE_ORDER_TIMES := "erledigt · %d ×"
const PAGE_ORDER_GOAL := "Erledigt: %d (von %d verschiedenen Auftraggebern)"

# --- Merkbuch page „Hollerbrück" ---------------------------------------------------------------------
const PAGE_VILLAGE := "Hollerbrück"
const PAGE_VILLAGE_REP := "Was man im Dorf über dich sagt: %s"
const PAGE_VILLAGE_TALKED_TODAY := "Zuletzt gesprochen: heute"
const PAGE_VILLAGE_TALKED := "Zuletzt gesprochen: –"
const PAGE_VILLAGE_LIKES := "mag: %s"
const PAGE_VILLAGE_LIKES_UNKNOWN := "mag: ?"
const PAGE_VILLAGE_SHOP := "Laden: %s"
const PAGE_VILLAGE_NO_SHOP := "kein Laden"
const PAGE_VILLAGE_GONE := "Ruht jetzt oben im Lindenacker."
const PAGE_VILLAGE_HINT := "Acht Leute, acht Gesichter. Die Pietät steht in keinem Buch."

# --- anatomist panel ------------------------------------------------------------------------------
const ANATOMIST_TITLE := "Wundarztstube"
const ANATOMIST_SUB := "Severin Quast nimmt, was in Gläsern liegt."
const ANATOMIST_EMPTY := "„Bringen Sie mir, was die Erde nicht vermisst.“"
const ANATOMIST_SELL := "Verkaufen (%d)"
const ANATOMIST_EXPERTISE := "Gutachten (%s)"
const ANATOMIST_LECTURE := "Für die Vorlesung"
const ANATOMIST_SELL_HINT := "Im Dorf wird man davon hören."
const ANATOMIST_PRICE := "%d %s"
const ANATOMIST_STANDING := "+%d Ansehen"
const ANATOMIST_SPOILS_IN := "verdorben in ≈ %s"
const ANATOMIST_SPOILED := "verdorben"
const ANATOMIST_AWAY := "Quast ist gerade nicht da."
const ANATOMIST_SOLD := "„Danke. Es wird gut aufbewahrt.“ (+%d %s)"
const ANATOMIST_EXPERTISE_LABEL := "Quast sieht es sich an"
const ANATOMIST_RESULT_TITLE := "Gutachten"
const ANATOMIST_RESULT_TEACHING := "Neuer Lehrsatz: %s"
const ANATOMIST_RESULT_KNOWN := "Den Lehrsatz kanntest du schon."
const ANATOMIST_RESULT_STAYS := "Das Glas bleibt bei Quast."
const ANATOMIST_COINS := "Münzen im Beutel: %d"
const CONTAINER_WORDS: Dictionary[StringName, String] = {
	&"jar": "im Glas", &"bundle": "im Bündel", &"display": "Schaupräparat", &"bone": "Knochenpräparat",
}
const STATE_WORDS: Dictionary[StringName, String] = {
	&"held": "bei dir", &"sold": "an Quast verkauft", &"researched": "bei Quast (Gutachten)",
	&"lectured": "in Quasts Kabinett (Vorlesung)", &"used": "zu einer Arznei angesetzt", &"returned": "zurückgelegt",
}
const STATE_SHELF := "in der Sammlung"
const STATE_COLD := "im Kühlfach"

# --- lecture panel ----------------------------------------------------------------------------------
const LECTURE_TITLE := "Ein Präparat für heute Abend"
const LECTURE_INTRO := "Die Läden sind geschlossen, eine Lampe brennt. Drei Studenten warten auf den Bänken. Der Tisch bleibt unter seinem Tuch."
const LECTURE_FEE := "Honorar %d %s"
const LECTURE_BUTTON := "Vorlesung halten (%s)"
const LECTURE_PICK := "Wähle ein Glas, einen Kasten oder ein Schaupräparat."
const LECTURE_EMPTY := "Du hast nichts dabei, was auf dem Lesepult stehen könnte."
const LECTURE_ACTION := "Quast spricht zur Bank"
const LECTURE_RESULT := "Die Vorlesung ist vorbei"
const LECTURE_RESULT_FEE := "Honorar: %d %s"
const LECTURE_RESULT_TEACHING := "Mitschrift: %s"
const LECTURE_RESULT_KNOWN := "Die Mitschrift kennst du schon."
const LECTURE_RESULT_STAYS := "Das Glas bleibt im Kabinett."
const LECTURE_NOT_TONIGHT := "Heute ist kein Vorlesungsabend."
## Three lines of Quast's talk per organ – plain and calm, nothing about the inside.
const LECTURE_LINES: Dictionary[StringName, PackedStringArray] = {
	&"heart": ["„Meine Herren, das Glas hier trägt einen Namen. Merken Sie ihn sich.“", "„Was wir die Stärke eines Menschen nennen, sitzt nicht nur hier. Aber hier hört sie auf.“", "„Schreiben Sie: Ein gesundes Herz bleibt nicht ohne Grund stehen.“"],
	&"lung": ["„Atmen Sie einmal tief, bevor Sie schreiben.“", "„Wer im Wasser stirbt, atmet es. Wer vorher stirbt, nicht.“", "„Der Unterschied steht in keinem Totenschein.“"],
	&"stomach": ["„Hier endet, was ein Mensch zuletzt zu sich nahm.“", "„Manche Gifte riechen. Man muss nur lange genug stillhalten.“", "„Schreiben Sie es auf, auch wenn es niemand hören will.“"],
	&"liver": ["„Ein langes Leben schreibt sich hier hinein, Glas für Glas.“", "„Urteilen Sie nicht. Notieren Sie.“", "„Der Trunk macht hart, was weich sein sollte.“"],
	&"kidneys": ["„Unscheinbar, meine Herren. Und doch hat dieser Mensch gelitten.“", "„Steine machen Schmerzen. Selten den Tod.“", "„Man stirbt meistens an etwas anderem als dem, was weh tut.“"],
	&"eyes": ["„Das Glas ist dunkel. Lassen Sie es dunkel.“", "„Das Moor färbt, was es berührt. Auch das, womit wir sehen.“", "„Wir sehen hin, damit andere es nicht müssen.“"],
	&"hand": ["„Eine Hand erzählt mehr als ein Kirchenbuch.“", "„Schwielen sind ein Lebenslauf.“", "„Sie bleibt in Leinen. Das genügt für heute.“"],
}

# --- pult panel ------------------------------------------------------------------------------------
const PULT_TITLE := "Präparierpult"
const PULT_INTRO := "Kalt und still. Was hier entsteht, bleibt verschlossen."
const PULT_PIECES := "Präparate"
const PULT_IN_COLD := "im Kühlfach"
const PULT_TAKE_OUT := "Herausnehmen"
const PULT_NONE := "Kein Präparat bei dir oder im Kühlfach."
const PULT_ACTIONS := "Handgriffe"
const PULT_SEAL := "Einlegen (%s)"
const PULT_DISPLAY := "Schaupräparat (%s)"
const PULT_BONE := "Knochenpräparat (%s)"
const PULT_INSPECT := "Begutachten (%s)"
const PULT_MEDICINES := "Arzneien"
const PULT_BOOK := "Aus Quasts Rezeptbuch"
const PULT_NO_BOOK := "Quasts Rezeptbuch fehlt."
const PULT_MED_NEEDS := "braucht: %s im Glas (Klarheit ab %s)"
const PULT_MED_RESULT := "ergibt %d × %s"
const PULT_MED_PRICE := "Quast zahlt %d je Stück"
const PULT_MED_BUTTON := "Ansetzen (%s)"
const PULT_CHOSEN := "Gewählt: %s"
const PULT_PICK := "Wähle ein Präparat."
const PULT_CRAFTING_BUTTON := "Präparate und Arzneien"
const PULT_INSPECTED := "Befund: %s"
const LABEL_SEAL := "Einlegen"
const LABEL_DISPLAY := "Schaupräparat herrichten"
const LABEL_BONE := "Knochenpräparat herrichten"
const LABEL_INSPECT := "Präparat begutachten"
const LABEL_MEDICINE := "%s ansetzen"
const INPUT_ROW := "%d× %s %d / %d"

# --- collection panel --------------------------------------------------------------------------------
const COLLECTION_TITLE := "Präparatesammlung"
const COLLECTION_HINT := "Was im Regal steht, fehlt im Grab."
const COLLECTION_STANDING := "Ansehen bei der Universität: %d"
const COLLECTION_EMPTY_SLOT := "%s – leer"
const COLLECTION_PLACE := "Aufstellen"
const COLLECTION_TAKE := "Herausnehmen"
const COLLECTION_SETS := "Sätze"
const COLLECTION_SET_REWARD := "%d %s"
const COLLECTION_SET_DONE := "✓ %s"
const COLLECTION_SET_OPEN := "○ %s"
const COLLECTION_SET_DISPLAY := "mindestens ein Schaupräparat"
const COLLECTION_HELD := "Bei dir"
const COLLECTION_NOTHING := "Nichts bei dir, was ins Regal passt."

# --- deduction panel ----------------------------------------------------------------------------------
const DEDUCTION_TITLE := "Ursache deuten"
const DEDUCTION_FOR := "%s · laut Osric: %s"
const DEDUCTION_CARDS := "Was du weißt"
const DEDUCTION_CAUSES := "Woran starb sie?"
const DEDUCTION_BUTTON := "Deuten"
const DEDUCTION_PICK := "Wähle zwei oder drei Karten und eine Ursache."
const DEDUCTION_SELECTED := "%d von höchstens 3 Karten · %s"
const DEDUCTION_NO_CAUSE := "keine Ursache gewählt"
const DEDUCTION_RESULT := "Gedeutet: %s"
const DEDUCTION_DONE := "Schon gedeutet: %s"
const DEDUCTION_NO_CARDS := "Noch keine Befund-Karte. Ein Präparat muss erst begutachtet werden."
const CARD_KIND_FINDING := &"finding"
const CARD_KIND_FIND := &"find"
const CARD_KIND_TEACHING := &"teaching"
const CARD_KIND_WORDS: Dictionary[StringName, String] = {&"finding": "Befund", &"find": "Fund", &"teaching": "Lehrsatz"}
## Causes beyond the CorpseTables (§2.6.5).
const EXTRA_CAUSE_LABELS: Dictionary[StringName, String] = {
	&"arsenic": "Arsenik", &"dead_before_water": "Tot, bevor sie ins Wasser kam", &"drink": "Der Trunk",
	&"unexplained": "Kein natürlicher Tod",
}

# --- specimen card at the crypt table -------------------------------------------------------------------
const TAB_ORGANS := "Präparate"
const ORGANS_HEAD := "Genommen: %d von höchstens %d"
const ORGANS_INTRO := "Ein Tuch über sie, ein Glas oder Leinen, ein Name auf dem Etikett."
const ORGAN_JAR := "Glas"
const ORGAN_BUNDLE := "Bündel"
const ORGAN_TAKE := "%s nehmen (%s)"
const ORGAN_CONFIRM := "Wirklich? Noch einmal drücken."
const ORGAN_CONFIRM_GRAVE := "Das bleibt ihr fehlen. Wirklich? Noch einmal drücken."
const ORGAN_INPUTS := "braucht %s"
const ORGAN_INPUT_OK := "%s ✓"
const ORGAN_INPUT_MISSING := "%s fehlt"
const ORGAN_CONSEQUENCE := "Qualität %s · Ruf %s · der Geist wird es merken"
const ORGAN_CONSEQUENCE_GRAVE := "Qualität %s · Ruf %s · das wird ihr fehlen"
const ORGAN_CLARITY := "Klarheit: %s"
const ORGAN_TAKEN := "Genommen – %s"
const ORGAN_RETURNED := "Zurückgelegt"
const CAUSE_REVEALED := "laut Osric: %s · gedeutet: %s"
const GRAVE_ORGANS: Array[StringName] = [&"eyes", &"hand"]

# --- HUD ------------------------------------------------------------------------------------------
const REGION_FALLBACK: Dictionary[StringName, String] = {&"village": "Hollerbrück · Anger", &"graveyard": "Friedhof auf dem Hügel"}
const REMARK_SECONDS := 4.0
const REGION_SECONDS := 3.0

# --- objective ------------------------------------------------------------------------------------
const OBJ_OSRIC := "Sprich mit Osric"
const OBJ_GO := "Geh nach Hollerbrück"
const OBJ_MAYOR := "Der Schultheiß erwartet dich in der Amtsstube"
const OBJ_LINDEN := "Lindenacker: %d/%d"
const OBJ_CONSECRATE := "Bitte den Pfarrer um die Weihe"
const OBJ_PRIEST_COMES := "Der Pfarrer kommt am Vormittag"
const OBJ_SURGEON := "Der Wundarzt will dich sprechen"
const OBJ_HAGEDORN := "Wiebke Hagedorns letzter Wunsch"
const OBJ_ORDER := "Auftrag: %s (noch %d %s)"
const OBJ_ORDER_TODAY := "Auftrag: %s (bis morgen früh)"
const OBJ_GOAL := "Ein Name im Dorf: %d/%d"
const OBJ_BOARD := "Die Gemeindetafel hat neue Bitten"

# --- register / death note / day summary -------------------------------------------------------------
const REGISTER_COLUMN := "Präparate"
const REGISTER_COLUMN_WIDTH := 120.0
const REGISTER_SEAL := " ◆"
const REGISTER_RETURNED := "%d (%d ✓)"
const LINDEN_GRAVE := "Linde %d"
const NOTE_SPECIMENS := "Präparate"
const NOTE_SPECIMEN_LINE := "%s %s – %s"
const NOTE_FINDING := "Befund: %s"
const NOTE_QUAST := "laut Quast: %s"
const NOTE_REVEALED := "gedeutet: %s"
const NOTE_DEDUCE := "Ursache deuten"
const DAY_VILLAGE := "Im Dorf"
const DAY_VILLAGE_VALUE := "+%d eingenommen · %d ausgegeben"
const DAY_ORDERS := "Aufträge erledigt"
const DAY_RELATIONS := "Beziehungen"
const DAY_SPECIMENS := "Präparate"
const DAY_SPECIMEN_PARTS: Dictionary[StringName, String] = {
	&"taken": "genommen", &"sold": "verkauft", &"researched": "begutachtet (Quast)", &"lectured": "in der Vorlesung",
	&"used": "zu Arzneien", &"returned": "zurückgelegt",
}
const SPENT_LABELS: Dictionary[StringName, String] = {&"village": "Dorf", &"donation": "Spenden", &"round": "Runden",
		&"consecration": "Weihe"}
## payment_received reasons counted as village income (prefixes).
const VILLAGE_INCOME_PREFIXES: PackedStringArray = ["Verkauf im Dorf", "Auftrag:", "Präparat an Quast", "Honorar der Vorlesung",
		"Die Universität zahlt"]

# --- chapter „Ein Name im Dorf" ---------------------------------------------------------------------
const CHAPTER_ID := &"name_in_village"
const CHAPTER_TITLE := "Ein Name im Dorf"
const CHAPTER_INTRO := "Drei Meilen hinunter. Jetzt grüßen sie dich am Brunnen, und manche wissen, was du oben tust."
const CHAPTER_ROWS: PackedStringArray = ["Tage seit dem Wegstein", "Wege ins Dorf", "Aufträge", "Beziehungen", "Ruf",
		"Im Lindenacker bestattet", "Präparate", "Deutungen", "Ansehen bei der Universität", "Im Dorf eingenommen",
		"Im Dorf ausgegeben", "Erkenntnisse"]
const CHAPTER_ORDERS_VALUE := "%d (%s)"
const CHAPTER_SPECIMENS_VALUE := "genommen %d · verkauft %d · begutachtet %d · Vorlesung %d · Arznei %d · Sammlung %d · zurückgelegt %d"
const CHAPTER_FINAL_FALLBACK := "Unten im Dorf kennen sie jetzt deinen Namen. Oben auf dem Hügel kennen sie ihn schon länger."
const INSIGHT_TITLES: Dictionary[StringName, String] = {&"i_deathbook": "Vorher eingetragen", &"i_burn_it": "Verbrennt es"}
## Phase-7 insights – not part of the Phase-4 chapter count (bug fix §P3: „x/6").
const PHASE7_INSIGHTS: Array[StringName] = [&"i_deathbook", &"i_burn_it"]


# --- people ---------------------------------------------------------------------------------------

## „●●●○○" for a relationship value 0…100 (one dot per 20, rounded).
static func pips(value: int) -> String:
	var on := clampi(roundi(float(clampi(value, 0, 100)) / 20.0), 0, PIPS)
	return PIP_ON.repeat(on) + PIP_OFF.repeat(PIPS - on)


## „Vertraut  ●●●○○".
static func rel_line(value: int, tier: StringName) -> String:
	return REL_LINE % [RelationshipRules.word(tier), pips(value)]


## Display name of a villager / the council / an unknown id.
static func person_name(npc_id: StringName) -> String:
	if npc_id == COUNCIL:
		return COUNCIL_NAME
	var data := Database.villager(npc_id) as VillagerData
	if data != null and data.display_name != "":
		return data.display_name
	return String(npc_id)


static func short_name(npc_id: StringName) -> String:
	if SHORT_NAMES.has(npc_id):
		return SHORT_NAMES[npc_id]
	var full := person_name(npc_id)
	var parts := full.split(" ", false)
	return parts[parts.size() - 1] if not parts.is_empty() else full


static func days_word(n: int) -> String:
	return DAY_ONE if n == 1 else DAY_MANY


static func coins(n: int) -> String:
	return Phase5Texts.coins(n)


## „07:25–14:00, 14:35–18:00" – the schedule entries of a villager with activity shop.
static func shop_hours(schedule: NpcSchedule) -> String:
	if schedule == null:
		return ""
	var entries: Array[ScheduleEntry] = []
	for e: ScheduleEntry in schedule.entries:
		if e != null and e.today_flag == &"":
			entries.append(e)
	entries.sort_custom(func(a: ScheduleEntry, b: ScheduleEntry) -> bool: return a.start_minute < b.start_minute)
	var parts := PackedStringArray()
	for i: int in entries.size():
		var e := entries[i]
		if e.activity != &"shop" or not e.visible:
			continue
		var end := entries[(i + 1) % entries.size()].start_minute
		parts.append("%s–%s" % [UIKit.clock(e.start_minute + maxi(e.travel_minutes, 0)), UIKit.clock(end)])
	return ", ".join(parts)


## Items of `liked` as names („Honigkuchen, Kräuterbündel").
static func likes_text(liked: Array) -> String:
	var names := PackedStringArray()
	for id: Variant in liked:
		names.append(UIKit.item_name(StringName(str(id))))
	return ", ".join(names)


# --- shop -----------------------------------------------------------------------------------------

## Row text of a buy row: {price_bb (BBCode), surcharge} from the base and the current price.
static func shop_price(base: int, price: int) -> Dictionary:
	var out := {"bb": SHOP_PRICE % [price, coins(price)], "surcharge": "", "discount": false}
	if base > 0 and price < base:
		out["bb"] = SHOP_PRICE_BB % [base, price, coins(price)]
		out["discount"] = true
	elif base > 0 and price > base:
		out["surcharge"] = SHOP_SURCHARGE % (price - base)
	return out


static func stock_text(left: int) -> String:
	return SHOP_STOCK % left if left > 0 else SHOP_SOLD_OUT


static func bought_text(left: int) -> String:
	return SHOP_BOUGHT_LEFT % left if left > 0 else SHOP_ENOUGH


# --- orders ---------------------------------------------------------------------------------------

## The card of one order: {id, title, giver, giver_name, recipient_name, text, checks: Array[{label, ok}],
## deadline, reward: PackedStringArray, state}. `inv` for the item checks (may be null); `days_left` < 0
## = not accepted (the offer's limit is shown).
static func order_card(o: OrderData, state: StringName, inv: Inventory, days_left: int) -> Dictionary:
	if o == null:
		return {}
	var card := {"id": o.id, "title": o.title, "giver": o.giver, "giver_name": person_name(o.giver),
			"recipient_name": person_name(o.recipient) if o.recipient != &"" and o.recipient != o.giver else "",
			"text": o.request_text, "state": state}
	card["checks"] = order_checks(o, inv)
	card["deadline"] = deadline_text(o, days_left)
	card["reward"] = reward_parts(o)
	return card


## Checklist: items (have/need, ✓ when enough), coins, the bury / stone / tend conditions (plain).
static func order_checks(o: OrderData, inv: Inventory) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: StringName in o.items:
		var need := int(o.items[item])
		var have := inv.count(item) if inv != null else 0
		if item in OrderRules.SPECIMEN_ITEMS and inv != null:
			have = OrderRules.matching_specimens(o, item, inv).size()
		var sub := OrderRules.substitute(o, item)
		if sub != &"" and inv != null:
			have += inv.count(sub)
		var label := "%d× %s" % [need, UIKit.item_name(item)]
		if sub != &"":
			label += " (oder %s)" % UIKit.item_name(sub)
		out.append({"label": "%s  %d/%d" % [label, mini(have, need), need], "ok": have >= need})
	if o.coins > 0:
		var have_c := inv.count(COIN) if inv != null else 0
		out.append({"label": "%d %s" % [o.coins, coins(o.coins)], "ok": have_c >= o.coins})
	for key: Variant in o.conditions:
		var k := str(key)
		var value: Variant = o.conditions[key]
		match k:
			"dress":
				out.append({"label": DRESS_WORDS.get(str(value), str(value)), "ok": false})
			"section":
				out.append({"label": SECTION_WORDS.get(str(value), str(value)), "ok": false})
			"mornings":
				out.append({"label": ORDER_TEND % int(value), "ok": false})
			"service", "prepared", "unharvested", "gilded":
				if value == true or str(value) == "true":
					out.append({"label": CONDITION_LABELS[k], "ok": false})
			"stone_shape", "ornament", "inscription":
				out.append({"label": "%s: %s" % [CONDITION_LABELS[k], stone_word(k, str(value))], "ok": false})
	return out


static func stone_word(kind: String, value: String) -> String:
	var words := {"arch": "Bogenstein", "stele": "Stele", "cross": "Steinkreuz", "round": "Rundstein", "torch": "Fackel",
			"poppy": "Mohn", "true": "ja"}
	return str(words.get(value, value)) if kind != "inscription" else ("ja" if value == "true" else value)


## „Frist: 4 Tage" (offer) · „noch 2 Tage" / „bis morgen früh" (accepted) · „ohne Frist".
static func deadline_text(o: OrderData, days_left: int) -> String:
	if o == null or o.days_limit <= 0:
		return ORDER_NO_DEADLINE
	if days_left < 0:
		return ORDER_DAYS_TODAY if o.days_limit == 1 and o.board else ORDER_DAYS_OFFER % [o.days_limit, days_word(o.days_limit)]
	if days_left <= 0:
		return ORDER_DAYS_TODAY
	return ORDER_DAYS_LEFT % [days_left, days_word(days_left)]


## [„6 Münzen", „▲ +6 Fenner", „▲ +4 Esch", „Ruf +1"].
static func reward_parts(o: OrderData) -> PackedStringArray:
	var out := PackedStringArray()
	if o.reward_coins > 0:
		out.append(ORDER_REWARD_COINS % [o.reward_coins, coins(o.reward_coins)])
	if o.reward_rel != 0 and o.giver != COUNCIL:
		out.append(ORDER_REWARD_REL % [UIKit.signed(o.reward_rel), short_name(o.giver)])
	for npc: StringName in o.extra_rel:
		out.append(ORDER_REWARD_REL % [UIKit.signed(int(o.extra_rel[npc])), short_name(npc)])
	if o.reward_rep != 0:
		out.append(ORDER_REWARD_REP % UIKit.signed(o.reward_rep))
	return out


## Days until the deadline of an accepted order (deadline_day − today; −1 = no deadline).
static func days_left(deadline_day: int, today: int) -> int:
	return maxi(deadline_day - today, 0) if deadline_day > 0 else -1


# --- anatomy --------------------------------------------------------------------------------------

static func organ_label(organ: StringName, cfg: AnatomyConfig = null) -> String:
	var c := cfg if cfg != null else _anatomy()
	return str(c.organ(organ).get("label", String(organ)))


static func container_word(container: StringName) -> String:
	return CONTAINER_WORDS.get(container, String(container))


## „≈ 4 h" / „≈ 40 Min" from effective minutes left.
static func eta_text(minutes: float) -> String:
	var m := maxi(roundi(minutes), 0)
	if m < 60:
		return "%d Min" % m
	return "%d h" % roundi(float(m) / 60.0)


## A bundle's minutes until spoiled (−1 = never: jar, bone, display). Linear fall from the clarity of
## now over the rest of bundle_minutes, × 1 / cold factor at the current minute.
static func spoil_minutes(spec: SpecimenRecord, now_total: int, cfg: AnatomyConfig = null) -> float:
	if spec == null or spec.container != SpecimenRecord.CONTAINER_BUNDLE:
		return -1.0
	var c := cfg if cfg != null else _anatomy()
	var clarity := SpecimenRules.clarity(spec, now_total, c)
	if clarity <= 0.0 or spec.clarity_at_harvest <= 0.0:
		return 0.0
	var per_minute := spec.clarity_at_harvest / float(maxi(c.bundle_minutes, 1))
	var factor := maxf(SpecimenRules.cold_factor_at(spec, now_total), 0.01)
	return clarity / per_minute / factor


## One row of a held specimen: {uid, organ, organ_label, name, container, container_word, clarity,
## clarity_word, spoiled, eta, label}.
static func specimen_row(spec: SpecimenRecord, record: CorpseRecord, now_total: int, cfg: AnatomyConfig = null) -> Dictionary:
	var c := cfg if cfg != null else _anatomy()
	var who := spec.corpse_name
	if record != null and record.age > 0:
		who = "%s, %d" % [who, record.age]
	var clarity := SpecimenRules.clarity(spec, now_total, c)
	var spoiled := SpecimenRules.is_spoiled(spec, now_total, c)
	var eta := spoil_minutes(spec, now_total, c)
	return {"uid": spec.uid, "organ": spec.organ, "organ_label": organ_label(spec.organ, c), "name": who,
			"container": spec.container, "container_word": container_word(spec.container), "clarity": clarity,
			"clarity_word": SpecimenRules.WORD_SPOILED if spoiled else SpecimenRules.clarity_word(clarity, c),
			"spoiled": spoiled, "eta": ANATOMIST_SPOILED if spoiled else (ANATOMIST_SPOILS_IN % eta_text(eta) if eta >= 0.0 else ""),
			"label": "%s – %s – %s" % [organ_label(spec.organ, c), who, container_word(spec.container)]}


## Quast's three lines for an organ.
static func lecture_lines(organ: StringName) -> PackedStringArray:
	return LECTURE_LINES.get(organ, PackedStringArray(["„Meine Herren, schreiben Sie mit.“", "„Die Toten lehren die Lebenden.“", "„Das genügt für heute.“"]))


## Where a specimen is now (death note, exam card): „im Glas, bei dir" · „an Quast verkauft" …
static func whereabouts(spec: SpecimenRecord, on_shelf: bool, in_cold: bool) -> String:
	if spec == null:
		return NONE
	if spec.state == SpecimenRecord.STATE_HELD:
		var where := STATE_SHELF if on_shelf else (STATE_COLD if in_cold else STATE_WORDS[&"held"])
		return "%s, %s" % [container_word(spec.container), where]
	return STATE_WORDS.get(spec.state, String(spec.state))


# --- deduction ------------------------------------------------------------------------------------

## German label of a cause id (CorpseTables label, the extra causes, else the id).
static func cause_label(cause: StringName) -> String:
	if EXTRA_CAUSE_LABELS.has(cause):
		return EXTRA_CAUSE_LABELS[cause]
	var tables := Database.corpse_tables() as CorpseTables
	if tables != null:
		var c: Dictionary = tables.get_cause(cause)
		if not c.is_empty():
			return str(c.get("label", cause))
	return String(cause)


## {id, kind (finding | find | teaching), kind_word, title, text} of a deduction card.
static func card(card_id: String) -> Dictionary:
	var id := StringName(card_id)
	var finding := Database.finding(id) as SpecimenFindingData
	if finding != null:
		return {"id": card_id, "kind": CARD_KIND_FINDING, "kind_word": CARD_KIND_WORDS[CARD_KIND_FINDING],
				"title": organ_label(finding.organ) if finding.organ != &"" else CARD_KIND_WORDS[CARD_KIND_FINDING], "text": finding.text}
	var teaching := Database.teaching(id) as TeachingData
	if teaching != null:
		return {"id": card_id, "kind": CARD_KIND_TEACHING, "kind_word": CARD_KIND_WORDS[CARD_KIND_TEACHING],
				"title": teaching.title, "text": teaching.text}
	var find := Database.find(id) as FindData
	if find != null:
		return {"id": card_id, "kind": CARD_KIND_FIND, "kind_word": CARD_KIND_WORDS[CARD_KIND_FIND], "title": find.label,
				"text": find.text}
	var kind := CARD_KIND_FINDING if card_id.begins_with("b_") else (CARD_KIND_TEACHING if card_id.begins_with("l_") else CARD_KIND_FIND)
	return {"id": card_id, "kind": kind, "kind_word": CARD_KIND_WORDS[kind], "title": card_id, "text": ""}


# --- specimen card at the table ---------------------------------------------------------------------

## „Qualität −2 · Ruf −3 · der Geist wird es merken" (eyes / hand: „… das wird ihr fehlen"), no piety.
static func organ_consequence(organ: StringName, cfg: AnatomyConfig = null, rep_cfg: ReputationConfig = null) -> String:
	var c := cfg if cfg != null else _anatomy()
	var row := c.organ(organ)
	var quality := int(row.get("quality", 0))
	var r := rep_cfg if rep_cfg != null else Database.config(&"reputation_config") as ReputationConfig
	var event := StringName(str(row.get("reputation_event", "organ_taken")))
	var rep := int(r.event_points.get(event, 0)) if r != null else 0
	return (ORGAN_CONSEQUENCE_GRAVE if organ in GRAVE_ORGANS else ORGAN_CONSEQUENCE) % [UIKit.signed(quality), UIKit.signed(rep)]


## „braucht Präparatglas ✓, Branntwein fehlt".
static func inputs_text(inputs: Dictionary, inv: Inventory) -> String:
	var parts := PackedStringArray()
	for id: Variant in inputs:
		var need := int(inputs[id])
		var have := inv.count(StringName(str(id))) if inv != null else 0
		var name := UIKit.item_name(StringName(str(id))) if need == 1 else "%d× %s" % [need, UIKit.item_name(StringName(str(id)))]
		parts.append((ORGAN_INPUT_OK if have >= need else ORGAN_INPUT_MISSING) % name)
	return ORGAN_INPUTS % ", ".join(parts) if not parts.is_empty() else ""


# --- objective --------------------------------------------------------------------------------------

## Phase-7 objective line from CemeteryStatus.phase7_state() ("" = nothing / before village_open).
static func objective(world: Dictionary) -> String:
	if not bool(world.get("p7", false)):
		return ""
	if not bool(world.get("p7_intro", false)):
		return OBJ_OSRIC
	if not bool(world.get("visited", false)):
		return OBJ_GO
	if not bool(world.get("linden_granted", false)):
		return OBJ_MAYOR
	var cleared := bool(world.get("linden_cleared", false))
	if not cleared and int(world.get("linden_total", 0)) > 0:
		return OBJ_LINDEN % [int(world.get("linden_done", 0)), int(world.get("linden_total", 0))]
	if not bool(world.get("consecrated", false)):
		return OBJ_PRIEST_COMES if bool(world.get("consecration_paid", false)) else OBJ_CONSECRATE
	if bool(world.get("surgeon_waiting", false)):
		return OBJ_SURGEON
	if bool(world.get("hagedorn_open", false)):
		return OBJ_HAGEDORN
	var urgent: Dictionary = world.get("urgent_order", {})
	if not urgent.is_empty():
		var left := int(urgent.get("days_left", 0))
		return OBJ_ORDER_TODAY % str(urgent.get("title", "")) if left <= 0 else OBJ_ORDER % [str(urgent.get("title", "")), left, days_word(left)]
	if not bool(world.get("goal_done", false)):
		return OBJ_GOAL % [int(world.get("goal_parts", 0)), int(world.get("goal_total", 4))]
	if int(world.get("board_open", 0)) > 0:
		return OBJ_BOARD
	return ""


# --- day summary ------------------------------------------------------------------------------------

## True for a payment the village made (shop sale, order, Quast, lecture, the university).
static func is_village_income(reason: String) -> bool:
	for prefix: String in VILLAGE_INCOME_PREFIXES:
		if reason.begins_with(prefix):
			return true
	return false


## „Fenner ▲ 2 · Liesel ▼ 3" from {npc_id: delta}.
static func relations_text(deltas: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: StringName in VILLAGER_ORDER:
		var d := int(deltas.get(id, deltas.get(String(id), 0)))
		if d > 0:
			parts.append("%s ▲ %d" % [short_name(id), d])
		elif d < 0:
			parts.append("%s ▼ %d" % [short_name(id), -d])
	return SEP.join(parts)


## „2 genommen · 1 verkauft" from {state: n}.
static func specimens_text(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for state: StringName in DAY_SPECIMEN_PARTS:
		var n := int(counts.get(state, counts.get(String(state), 0)))
		if n > 0:
			parts.append("%d %s" % [n, DAY_SPECIMEN_PARTS[state]])
	return SEP.join(parts)


# --- chapter ------------------------------------------------------------------------------------------

## Values of CHAPTER_ROWS from Village.chapter_context().
static func chapter_values(context: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	out.append(str(int(context.get("village_days", 0))))
	out.append(str(int(context.get("village_trips", 0))))
	var by_giver: Dictionary = context.get("orders_by_giver", {})
	var parts := PackedStringArray()
	var keys: Array = by_giver.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return _giver_rank(StringName(str(a))) < _giver_rank(StringName(str(b))))
	for g: Variant in keys:
		parts.append("%s %d" % [short_name(StringName(str(g))), int(by_giver[g])])
	out.append(CHAPTER_ORDERS_VALUE % [int(context.get("orders_done", 0)), SEP.join(parts)] if not parts.is_empty() else str(int(context.get("orders_done", 0))))
	var rels: Dictionary = context.get("relationships", {})
	var rel_parts := PackedStringArray()
	for id: StringName in VILLAGER_ORDER:
		if rels.has(id) or rels.has(String(id)):
			rel_parts.append("%s %s" % [short_name(id), str(rels.get(id, rels.get(String(id), "")))])
	out.append(SEP.join(rel_parts) if not rel_parts.is_empty() else NONE)
	out.append(str(context.get("reputation_tier", NONE)))
	out.append(str(int(context.get("linden_burials", 0))))
	var s: Dictionary = context.get("specimens", {})
	out.append(CHAPTER_SPECIMENS_VALUE % [int(s.get("specimens_taken", 0)), int(s.get("specimens_sold", 0)),
			int(s.get("specimens_researched", 0)), int(s.get("lectures_attended", 0)), int(s.get("medicines_made", 0)),
			int(s.get("specimens_collected", 0)), int(s.get("specimens_returned", 0))])
	out.append(str(int(context.get("deductions", 0))))
	out.append(str(int(context.get("university_standing", 0))))
	var earned: Dictionary = context.get("coins_earned_village", {})
	var e_total := 0
	var e_parts := PackedStringArray()
	for key: Variant in earned:
		var n := int(earned[key])
		if n > 0:
			e_total += n
			e_parts.append("%s %d" % [str(key), n])
	out.append("%d %s (%s)" % [e_total, coins(e_total), SEP.join(e_parts)] if e_total > 0 else NONE)
	var spent := Phase5Texts.spent_text(context.get("coins_spent_village", {}))
	out.append(spent if spent != "" else NONE)
	var titles := PackedStringArray()
	for id: Variant in context.get("insights_phase7", PackedStringArray()):
		titles.append(insight_title(StringName(str(id))))
	out.append(SEP.join(titles) if not titles.is_empty() else NONE)
	return out


static func insight_title(id: StringName) -> String:
	var data := Database.insight(id) as InsightData
	if data != null and data.title != "":
		return data.title
	return INSIGHT_TITLES.get(id, String(id))


static func _giver_rank(id: StringName) -> int:
	var i := VILLAGER_ORDER.find(id)
	return i if i >= 0 else VILLAGER_ORDER.size()


static func _anatomy() -> AnatomyConfig:
	var cfg := Database.config(&"anatomy_config") as AnatomyConfig
	return cfg if cfg != null else AnatomyConfig.new()
