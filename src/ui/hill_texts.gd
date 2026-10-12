class_name HillTexts
extends RefCounted
## German texts of the requests on the gate's notice board (G8 Runde 6 „Bitten vom Hügel",
## docs/PHASE8_DESIGN.md G8 Runde 6 §5): notes, the panel, the HUD lines, the journal tab. The requests' own
## texts live in data/hill_requests/*.tres.

const ACCEPTED := "Angenommen: %s"
const FAILED := "Zu spät: %s. Der Zettel hängt nicht mehr am Tor."
const POSTED_ONE := "Osric hat eine Bitte ans Tor geheftet."
const POSTED_MANY := "Osric hat %s Bitten ans Tor geheftet."
const NUMBER_WORDS: Array[String] = ["keine", "eine", "zwei", "drei", "vier"]
const REWARD_NOTE := "Bitte erfüllt: %s – %s"
const REWARD_NOTE_PLAIN := "Bitte erfüllt: %s"
const FINDING := "%s: %s"
const GRAVE_FALLBACK := "einem Grab ohne Namen"
const SEP := " · "

# Notice board
const PROMPT := "[E] Bitten am Tor lesen"
const BOARD_EMPTY := "Heute hängt kein Zettel am Tor."

# Panel
const PANEL_TITLE := "Bitten vom Hügel"
const PANEL_HEAD := "Zettel am Friedhofstor – Osric bringt sie aus dem Dorf herauf."
const PANEL_FROM := "von %s"
const PANEL_DEADLINE := "Frist: %s"
const PANEL_LEFT := "noch %s"
const PANEL_LAST_DAY := "heute der letzte Tag"
const PANEL_HANGS := "hängt noch %s"
const PANEL_REWARD := "Lohn: %s"
const PANEL_ACCEPT := "Annehmen"
const PANEL_ACCEPTED := "Angenommen"
const PANEL_DELIVER := "Abgabe bei Osric am Karren (morgens bis 10:00, abends 18:30–21:00)."
const PANEL_COUNT := "Angenommen: %d von %d"
const PANEL_NEXT := "Neue Bitten bringt Osric am Morgen."
const PANEL_HINT := "↑/↓ wählen · Enter annehmen · Esc schließen"

# HUD
const OBJ_ACTIVE := "Bitte: %s (%s)"
const OBJ_DELIVER_READY := "Bitte: %s – bei Osric abgeben"
const OBJ_WAITING_ONE := "Eine Bitte am Tor wartet"
const OBJ_WAITING_MANY := "%s Bitten am Tor warten"

# Journal
const PAGE_LABEL := "Bitten"
const PAGE_ACTIVE := "Angenommene Bitten"
const PAGE_OFFERED := "Am Tor"
const PAGE_NONE := "Keine Bitte angenommen."
const PAGE_NONE_OFFERED := "Kein Zettel am Tor."
const PAGE_DONE := "Erledigt und versäumt"
const PAGE_NONE_DONE := "Noch nichts erledigt."
const PAGE_DONE_ENTRY := "%s – Tag %d"
const PAGE_DONE_STAMP := "erledigt"
const PAGE_FAILED_STAMP := "versäumt"
const PAGE_QUOTE := "Die Leute unten fragen selten. Wenn sie fragen, ist es ihnen wichtig."

# Osric
const CARTER_HANDED := "Für die Leute unten – Osric nimmt es mit."


static func posted(n: int) -> String:
	return POSTED_ONE if n == 1 else POSTED_MANY % number_word(n)


static func number_word(n: int) -> String:
	return NUMBER_WORDS[n] if n >= 0 and n < NUMBER_WORDS.size() else str(n)


## „Bitte erfüllt: Drei Scheite für Osric – 3 Münzen · Ruf +1“.
static func reward_note(title: String, parts: PackedStringArray) -> String:
	return REWARD_NOTE % [title, SEP.join(parts)] if not parts.is_empty() else REWARD_NOTE_PLAIN % title


## „Anna Gerber: Schwindsucht“ – the finding of an exam request.
static func finding(dead: String, cause: String) -> String:
	return FINDING % [dead, cause] if dead != "" else cause


## „1 Tag“ / „2 Tage“.
static func days(n: int) -> String:
	return "%d %s" % [n, "Tag" if n == 1 else "Tage"]


## Deadline words of an offered (`left` < 0: its days_limit) or accepted request.
static func deadline(days_limit: int, left: int) -> String:
	if left < 0:
		return PANEL_DEADLINE % days(maxi(1, days_limit))
	if left <= 1:
		return PANEL_LAST_DAY
	return PANEL_LEFT % days(left)


## HUD line of an accepted request ({title, left, kind, ready} of HillRequests.objective_state).
static func objective(entry: Dictionary) -> String:
	var title := str(entry.get("title", ""))
	if bool(entry.get("ready", false)):
		return OBJ_DELIVER_READY % title
	var left := int(entry.get("left", 1))
	return OBJ_ACTIVE % [title, PANEL_LAST_DAY if left <= 1 else PANEL_LEFT % days(left)]


static func waiting(n: int) -> String:
	return OBJ_WAITING_ONE if n == 1 else OBJ_WAITING_MANY % number_word(n).capitalize()
