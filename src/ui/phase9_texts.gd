class_name Phase9Texts
extends RefCounted
## German texts of the Phase-9 UI (docs/PHASE9_DESIGN.md §7, W-UI): the Merkbuch tabs „Vorhaben", „Die Liste" and
## „Briefe", the letter card, Brenneisen's panel, the large requests in the panels and the HUD, the objective lines,
## the day summary rows and the chapter panel „Wer weiß, wann?". The chains', letters' and offers' own texts live in
## data/ (P1–P6); this file only words what the UI adds around them. Never a number for a consequence (§3 rules).

const SEP := " · "

# --- Merkbuch: tabs ---------------------------------------------------------------------------------------------
const PAGE_PLANS := "Vorhaben"
const PAGE_LIST := "Die Liste"
const PAGE_LETTERS := "Briefe"
const TAB_HINT := "[Q] / [E] oder [ / ] blättern · ↑/↓ wählen · Enter · Tab wechselt die Seite · [J] oder [Esc] schließen"

# --- „Vorhaben" (§7.1) -------------------------------------------------------------------------------------------
const GROUP_LABELS: Dictionary[StringName, String] = {&"main": "Hauptkette", &"side": "Nebenketten", &"large": "Große Bitten",
		&"hill": "Bitten", &"orders": "Aufträge", &"friend": "Freundschaft", &"owed": "Was du schuldest"}
const PLANS_EMPTY := "Nichts, was auf dich wartet. Das kommt selten vor."
const PLANS_PICK := "Wähle links ein Vorhaben."
const PLANS_FROM := "von %s"
const PLANS_PIN := "Verfolgen"
const PLANS_UNPIN := "Nicht mehr verfolgen"
const PLANS_PINNED := "verfolgt"
const PLANS_PINNED_MARK := "◆"
const PLANS_STEPS := "Was geschah"
const PLANS_NOW := "Jetzt"
const PLANS_PARTS := "Teile"
const PLANS_FUTURE := "…"
const PLANS_ENDED := "Ende: %s"
const PLANS_SETTLED := "abgeschlossen"
const PLANS_ERRAND := "Botengang"
const PLANS_DEADLINE_NONE := ""
const PART_DONE := "✓"
const PART_OPEN := "○"
const HALF_STAMP := "halb"
const QUOTE_PLANS := "Was man aufschreibt, vergisst man nicht. Was man vergisst, schreibt einem keiner auf."
## Done steps of the chains as sentences in ink (step id → sentence); unknown steps keep their title.
const DONE_SENTENCES: Dictionary[StringName, String] = {
	&"h1": "Du hast Lorenz' Kladde gelesen. Auf der Rückseite steht eine Liste.",
	&"h2": "Unter fünf Daten liegt einer auf dem Hügel. Immer drei Wochen vorher.",
	&"h3": "Andere haben das Licht auch gesehen. Es brannte, bevor einer starb.",
	&"h4": "„S.“ ist Johann Sieber. Er weiß es schon.",
	&"h5": "Du hast es jemandem gesagt.",
	&"h6": "Du hast Johann gesagt, was du denkst.",
	&"l1": "Du hast über einen Brief aus einer Tasche entschieden.",
	&"l2": "Du hast über die Post für einen Toten entschieden.",
	&"l3": "Gesas Brief ist auf dem Weg zu ihrem Bruder.",
	&"l4": "Du hast eine Antwort geschrieben, und sie ist fort.",
	&"l5": "Du hast entschieden, was mit dem Brief an L. Aschau geschieht.",
	&"k1": "Du hast dem Herrn am Tor geantwortet – so oder so.",
	&"k2": "Du weißt, was er kaufen will.",
	&"k3": "Du weißt, wer für Frische zahlt.",
	&"k4": "Der Koffer ist nicht mehr im Holderkrug.",
	&"k5": "Er ist fort.",
}
## Choices as sentences (choice id → „Du hast es Liesel gesagt."); unknown ones: CHOICE_FALLBACK with the label.
const CHOICE_SENTENCES: Dictionary[StringName, String] = {
	&"confide_priest": "Du hast es Pfarrer Lenz gesagt.",
	&"confide_surgeon": "Du hast es Severin Quast gesagt.",
	&"confide_washer": "Du hast es Liesel gesagt.",
	&"confide_none": "Du hast es niemandem gesagt.",
	&"away": "Du hast Johann geraten zu gehen.",
	&"stay": "Du hast Johann versprochen, ihm das Grab neben Grete zu machen.",
	&"public": "Du bist mit Johann zum Fenner gegangen.",
	&"silent": "Du hast nichts gesagt.",
	&"open": "Du hast den Brief an L. Aschau geöffnet.",
	&"keep": "Du hast den Brief an L. Aschau versiegelt aufgehoben.",
	&"liesel": "Du hast Liesel den Brief an L. Aschau gegeben.",
	&"burn": "Du hast den Brief an L. Aschau verbrannt.",
	&"fenner": "Du hast den Herrn bei Fenner angezeigt.",
	&"deal": "Du hast mit ihm gehandelt.",
	&"ilse": "Du hast ihn zu Ilse geschickt.",
}
const CHOICE_FALLBACK := "Du hast gewählt: %s"
## Givers that are no villager / kin of Phase 7–8.
const EXTRA_PEOPLE: Dictionary[StringName, String] = {&"stranger": "Cornelius Brenneisen", &"kin_sieber_v": "Johann Sieber",
		&"kin_sieber": "Johann Sieber"}
const DAYS_LEFT_LAST := "heute der letzte Tag"
const DAYS_LEFT := "noch %d Tage"
const DAYS_LEFT_ONE := "bis morgen"

# --- „Die Liste" (§7.2) -------------------------------------------------------------------------------------------
const LIST_TITLE := "Die Rückseite der Kladde"
const LIST_UNKNOWN := "Du hast Lorenz' zweite Kladde noch nicht gelesen. Sie liegt am Pult in der Hütte – oder beim Pfarrer."
const LIST_HEAD_DATE := "Datum"
const LIST_HEAD_INITIAL := "Buchst."
const LIST_HEAD_NAME := "Name"
const LIST_HEAD_WITNESS := "Licht gesehen"
const LIST_WITNESS_YES := "✓"
const LIST_WITNESS_NO := "–"
const LIST_INK_NOTE := "Die ersten Zeilen sind braun und alt, die letzten blauschwarz und frisch."
const LIST_CONFIDE_NONE := "Niemandem sagen"
const LIST_CONFIDE_HINT := "Wem du es sagst, entscheidest du im Gespräch. Oder hier: niemandem."
const LIST_COUNT := "%d von %d Gräbern verglichen · %d von %d Zeugen gefragt"
const LIST_QUOTE := "Ein Totengräber weiß, dass jeder kommt. Einer im Dorf weiß, wann."

# --- „Briefe" (§7.2) ------------------------------------------------------------------------------------------------
const LETTERS_EMPTY := "Noch kein Brief. Die Toten haben manchmal etwas in den Taschen."
const LETTERS_OPEN := "In deiner Tasche"
const LETTERS_COPIES := "Abschriften und Verbleib"
const LETTERS_DECIDE := "Entscheiden …"
const LETTERS_NO_OPEN := "Kein Brief wartet auf eine Entscheidung."
const LETTERS_FROM := "von %s"
const LETTERS_DAY := "Tag %d"
const LETTERS_SEALED := "Versiegelt. Den Text kennst du nicht."
const LETTERS_KIND: Dictionary[StringName, String] = {&"pocket": "aus einer Tasche", &"post": "Post für den Hügel",
		&"reply": "Antwort", &"errand": "Botengang"}

# --- Brief-Karte (§7.3) ---------------------------------------------------------------------------------------------
const LETTER_TITLE := "Ein Brief"
const LETTER_OUTSIDE := "Aufschrift"
const LETTER_SENDER := "von %s"
const LETTER_TEXT_HIDDEN := "Er ist versiegelt. Was drinsteht, weißt du nicht."
const LETTER_CHOICES := "Was wird aus ihm?"
const LETTER_DONE := "Entschieden."
const LETTER_NONE := "Kein Brief in deiner Tasche."
const LETTER_COUNT := "Brief %d von %d"
const LETTER_PREV := "‹"
const LETTER_NEXT := "›"
const LETTER_HINT := "↑/↓ wählen · Enter · ‹ / › nächster Brief · Esc schließen"

# --- Brenneisen (§7.4) ------------------------------------------------------------------------------------------------
const STRANGER_TITLE := "C. Brenneisen, Commissionär"
const STRANGER_HEAD := "Er stellt den Koffer ab und schlägt das Notizbuch auf. „Ich kaufe nur, was man mir verkaufen will.“"
const STRANGER_NONE := "Er will heute nichts kaufen. Er sieht sich nur um."
const STRANGER_GONE := "Er ist nicht mehr da."
const STRANGER_PRICE := "%d %s"
const STRANGER_SELL := "Verkaufen"
const STRANGER_NO := "Nein"
const STRANGER_DECLINED := "„Wie Sie meinen.“ Er streicht etwas im Notizbuch."
const STRANGER_SOLD := "Verkauft. Er zahlt, ohne nachzuzählen."
const STRANGER_HINT := "↑/↓ wählen · Enter · Esc schließen"
const STRANGER_QUOTE := "Kein Verhandeln. Er nennt einen Preis, und der gilt."

# --- große Bitten (§2.3.4) ----------------------------------------------------------------------------------------------
const LARGE_HEAD := "Großer Bogen"
const LARGE_HEAD_VILLAGE := "Große Bitte an der Gemeindetafel"
const LARGE_PARTS := "Teile"
const LARGE_IN_ORDER := "der Reihe nach"
const LARGE_HALF_NOTE := "Mehr als die Hälfte ist getan – würde die Frist jetzt ablaufen, gälte sie als halb erfüllt."
const LARGE_READ := "Große Bitte lesen"
const LARGE_ON_BOARD := "Große Bitte: %s – von %s"
const LARGE_VILLAGE_TITLE := "Gemeindetafel – große Bitte"
const LARGE_VILLAGE_HEAD := "Ein großer, gefalteter Bogen mit Siegelfaden am rechten Rand der Tafel."
const LARGE_PART_COUNT := " (%d/%d)"

# --- HUD (§7.5) -----------------------------------------------------------------------------------------------------
const OBJ_OSRIC := "Sprich mit Osric"
const OBJ_KLADDE := "Lies Lorenz' Kladde (Hütte)"
const OBJ_LIST := "Die Liste: %d/%d Gräber verglichen"
const OBJ_WITNESS := "Wer hat das Licht gesehen? %d/%d"
const OBJ_WHO_S := "Wer ist „S.“?"
const OBJ_CONFIDE := "Wem sagst du es?"
const OBJ_DECIDE := "Was wird aus Johann? (%s)"
const OBJ_BURY := "Johann Sieber – bestatten"
const OBJ_STRANGER := "Ein Herr wartet am Tor"
const OBJ_LETTER := "Ein Brief: an %s"
const OBJ_LETTER_POST := "Post für den Hügel: %s"
const OBJ_GOAL := "Wer weiß, wann? %d/3"
const OBJ_LARGE_WAITING_GATE := "Eine große Bitte am Tor wartet"
const OBJ_LARGE_WAITING_VILLAGE := "Die Gemeindetafel hat eine große Bitte"
const OBJ_PINNED_PROGRESS := "%s %d/%d"
const DECIDE_TODAY := "heute"
const DECIDE_TOMORROW := "bis morgen Abend"
const DECIDE_DAYS := "noch %d Tage"

# --- Tageszusammenfassung (§7.6) --------------------------------------------------------------------------------------
const DAY_LETTERS := "Briefe"
const DAY_REQUESTS := "Bitten"
const DAY_STRANGER := "Der Herr mit dem Koffer"
const DAY_LETTERS_FOUND := "gefunden %d"
const DAY_LETTERS_DECIDED := "entschieden %d"
const DAY_LETTERS_POST := "Post %d"
const DAY_PARTS := "Teile %d"
const DAY_DONE := "erfüllt %d"
const DAY_HALF := "halb %d"
const DAY_FAILED := "versäumt %d"
const DAY_STRANGER_ASKED := "er fragte"
const DAY_STRANGER_SOLD := "er bekam: %s"
const DAY_STRANGER_LEFT := "er ist abgereist"
const DAY_STRANGER_CASE := "der Koffer"
const DAY_STRANGER_BRIBE := "er bot Geld"

# --- Grabregister (§7.6) ------------------------------------------------------------------------------------------------
const REGISTER_LETTER := "✉"
const REGISTER_LETTER_TIP := "Ein Brief gehört zu diesem Toten."
const REGISTER_LIGHT := "Licht: %s"

# --- Abschluss-Panel (§1.5) ---------------------------------------------------------------------------------------------
const CHAPTER_ID := &"who_knows_when"
const CHAPTER_TITLE := "Wer weiß, wann?"
const CHAPTER_INTRO := "Sechs Daten auf der Rückseite einer Kladde, und unter jedem ein Licht, das keiner angezündet hat. Du weißt jetzt, wann. Wer, weißt du nicht."
const CHAPTER_ROWS: PackedStringArray = ["Tage seit der Liste", "Das Ende", "Gesagt", "Die Liste", "Briefe", "Botengänge",
		"Größere Bitten", "Der Herr mit dem Koffer", "Erkenntnisse"]
const CHAPTER_CONFIDED: Dictionary[StringName, String] = {&"confide_priest": "Pfarrer Lenz", &"confide_surgeon": "Severin Quast",
		&"confide_washer": "Liesel Dorn", &"confide_none": "niemandem", &"": "niemandem"}
const CHAPTER_LETTERS := "zugestellt %d · vorgelesen %d · beantwortet %d · verbrannt %d · ins Grab %d"
const CHAPTER_LARGE := "erfüllt %d · halb %d · versäumt %d · Teile %d"
const CHAPTER_STRANGER := "%s · %s"
const CHAPTER_STRANGER_NONE := "nie gekommen"
const CHAPTER_STRANGER_SOLD := "bekam %d %s"
const CHAPTER_STRANGER_NOTHING := "bekam nichts"
const CHAPTER_STRANGER_ENDINGS: Dictionary[StringName, String] = {&"fenner": "über die Brücke gebracht", &"deal": "ging zufrieden",
		&"ilse": "nachts an der Westmauer", &"": "noch da"}
const CHAPTER_STRANGER_LEFT := "abgereist"
const CHAPTER_ENDING_LINE := "%s – %s"
const CHAPTER_FINAL_FALLBACK := "Johann hat sich nicht beeilt. Du hast ihm die Erde so tief gemacht, wie man es kann. Wann der Nächste kommt, steht in keinem Heft, das du hast."
const PHASE9_INSIGHTS: Array[StringName] = [&"i_light_before"]
const NONE := "–"

# --- Karte (§7.6) ---------------------------------------------------------------------------------------------------------
const MAP_STRANGER := "Der Herr mit dem Koffer"
const MAP_LARGE := "Große Bitte"
const MAP_SIEBER_LIGHT := "Licht bei den Siebers"
const MAP_BOOKMARK := "Verfolgt: %s"


## A giver's name for „Vorhaben" (villager, kin, Brenneisen; "" for none).
static func person(id: StringName) -> String:
	if id == &"":
		return ""
	if EXTRA_PEOPLE.has(id):
		return EXTRA_PEOPLE[id]
	return Phase8Texts.person_name(id)


## The giver of a large / small request (HillRules.giver_name) or of a chain / order.
static func giver_name(group: StringName, giver: StringName) -> String:
	if giver == &"":
		return ""
	if group == &"large" or group == &"hill":
		return HillRules.giver_name(giver)
	return person(giver)


## „heute der letzte Tag" · „bis morgen" · „noch 3 Tage" (QuestLog days_left; "" = none).
static func days_left(n: int) -> String:
	if n < 0:
		return ""
	if n <= 1:
		return DAYS_LEFT_LAST
	if n == 2:
		return DAYS_LEFT_ONE
	return DAYS_LEFT % (n - 1)


## The sentence of a done chain step (with its choice, if any).
static func done_sentence(step: Dictionary) -> String:
	var choice := StringName(str(step.get("choice", "")))
	if choice != &"":
		return choice_sentence(choice, str(step.get("choice_label", "")))
	var id := StringName(str(step.get("id", "")))
	return DONE_SENTENCES.get(id, str(step.get("title", "")))


static func choice_sentence(choice: StringName, label: String) -> String:
	if CHOICE_SENTENCES.has(choice):
		return CHOICE_SENTENCES[choice]
	return CHOICE_FALLBACK % label if label != "" else ""


## „Was wird aus Johann? (bis morgen Abend)" – the deadline words of the decision step.
static func decide_words(days: int) -> String:
	if days <= 1:
		return DECIDE_TODAY
	if days == 2:
		return DECIDE_TOMORROW
	return DECIDE_DAYS % (days - 1)


## The HUD line of the pinned „Vorhaben" entry (QuestLog.objective): a chain's step title (with its progress), a
## request's next part, an order's title.
static func pinned_line(entry: Dictionary) -> String:
	var line := str(entry.get("line", ""))
	var title := str(entry.get("title", ""))
	var group := StringName(str(entry.get("group", "")))
	var progress: Vector2i = entry.get("progress", Vector2i.ZERO) if entry.get("progress") is Vector2i else Vector2i.ZERO
	match group:
		&"large":
			if line == "":
				return title
			return "Bitte: %s – %s%s" % [title, line, LARGE_PART_COUNT % [progress.x, progress.y] if progress.y > 0 else ""]
		&"hill":
			return HillTexts.OBJ_ACTIVE % [title, days_left(int(entry.get("days_left", -1)))] if int(entry.get("days_left", -1)) >= 0 else "Bitte: " + title
		&"orders", &"friend", &"owed":
			var left := int(entry.get("days_left", -1))
			return "Auftrag: %s (%s)" % [title, days_left(left)] if left >= 0 else "Auftrag: " + title
	if line == "":
		return title
	if progress.y > 1:
		return OBJ_PINNED_PROGRESS % [line, progress.x, progress.y]
	return line


## Day-summary row „Briefe" ({found, decided, post}; "" = nothing).
static func letters_day_text(d: Dictionary) -> String:
	var parts := PackedStringArray()
	if int(d.get("found", 0)) > 0:
		parts.append(DAY_LETTERS_FOUND % int(d.found))
	if int(d.get("decided", 0)) > 0:
		parts.append(DAY_LETTERS_DECIDED % int(d.decided))
	if int(d.get("post", 0)) > 0:
		parts.append(DAY_LETTERS_POST % int(d.post))
	return SEP.join(parts)


## Day-summary row „Bitten" ({parts, completed, half, failed}; "" = nothing).
static func requests_day_text(d: Dictionary) -> String:
	var parts := PackedStringArray()
	if int(d.get("parts", 0)) > 0:
		parts.append(DAY_PARTS % int(d.parts))
	if int(d.get("completed", 0)) > 0:
		parts.append(DAY_DONE % int(d.completed))
	if int(d.get("half", 0)) > 0:
		parts.append(DAY_HALF % int(d.half))
	if int(d.get("failed", 0)) > 0:
		parts.append(DAY_FAILED % int(d.failed))
	return SEP.join(parts)


## Day-summary row „Der Herr mit dem Koffer" ({asked, sold: [labels], bribed, case, left}; "" = he was not there).
static func stranger_day_text(d: Dictionary) -> String:
	var parts := PackedStringArray()
	if bool(d.get("asked", false)):
		parts.append(DAY_STRANGER_ASKED)
	var sold: Array = d.get("sold", [])
	if not sold.is_empty():
		parts.append(DAY_STRANGER_SOLD % ", ".join(PackedStringArray(sold)))
	if bool(d.get("bribed", false)):
		parts.append(DAY_STRANGER_BRIBE)
	if bool(d.get("case", false)):
		parts.append(DAY_STRANGER_CASE)
	if bool(d.get("left", false)):
		parts.append(DAY_STRANGER_LEFT)
	return SEP.join(parts)


## Values of CHAPTER_ROWS from Quests.chapter_context() (+ SliceSummaryPanel.complete_who_knows_when: list, errands,
## stranger_end, stranger_sold, insights).
static func chapter_values(context: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	out.append(str(int(context.get("days_open", 0))))
	var title := str(context.get("main_title", ""))
	out.append(title if title != "" else NONE)
	out.append(CHAPTER_CONFIDED.get(StringName(str(context.get("confided", ""))), str(context.get("confided", ""))))
	var list_parts := PackedStringArray()
	for e: Variant in context.get("list", []):
		if e is Dictionary:
			var row := e as Dictionary
			var name := str(row.get("name", ""))
			list_parts.append("%s %s%s" % [str(row.get("date", "")), name if name != "" else str(row.get("initial", "")),
					" ✓" if bool(row.get("witnessed", false)) else ""])
	out.append("\n".join(list_parts) if not list_parts.is_empty() else NONE)
	out.append(CHAPTER_LETTERS % [int(context.get("letters_delivered", 0)), int(context.get("letters_read_grave", 0)),
			int(context.get("letters_answered", 0)), int(context.get("letters_burned", 0)), int(context.get("letters_buried", 0))])
	out.append(str(int(context.get("errands_done", 0))))
	out.append(CHAPTER_LARGE % [int(context.get("large_requests_done", 0)), int(context.get("large_requests_half", 0)),
			int(context.get("large_requests_failed", 0)), int(context.get("large_request_parts", 0))])
	out.append(stranger_chapter(context))
	var names := PackedStringArray()
	for id: Variant in context.get("insights", []):
		var insight := Database.insight(StringName(str(id))) as InsightData
		names.append(insight.title if insight != null else str(id))
	out.append(", ".join(names) if not names.is_empty() else NONE)
	return out


## „bekam 13 Münzen · über die Brücke gebracht" / „nie gekommen".
static func stranger_chapter(context: Dictionary) -> String:
	if not bool(context.get("stranger_seen", int(context.get("stranger_talks", 0)) > 0)):
		return CHAPTER_STRANGER_NONE
	var coins := int(context.get("stranger_coins", 0))
	var got := CHAPTER_STRANGER_SOLD % [coins, Phase8Texts.coins(coins)] if coins > 0 else CHAPTER_STRANGER_NOTHING
	var end := StringName(str(context.get("stranger_end", "")))
	var how: String = CHAPTER_STRANGER_ENDINGS.get(end, String(end))
	if end == &"" and bool(context.get("stranger_gone", false)):
		how = CHAPTER_STRANGER_LEFT
	return CHAPTER_STRANGER % [got, how]
