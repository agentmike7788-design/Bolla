class_name Phase4Texts
extends RefCounted
## Pure text builders of the Phase-4 UI (docs/PHASE4_DESIGN.md §7): the morgue table tabs
## (exam step buttons, loss forecast, preparation lines, the harvest consequence line), the
## trade panel, the chapter panel „Sechs Gruben“, the Ehrwürdig condition, the HUD journal
## badge and the notification styles. Input = plain values / system dictionaries, so every
## string is testable without a world. Piety is never shown as a number (§7, §14).

# --- morgue table ---------------------------------------------------------------------------

const TAB_EXAM := "Untersuchen"
const TAB_PREP := "Herrichten"
const TAB_HARVEST := "Verwerten"
const TEXT_STEP := "%s · %s"
const TEXT_STEP_DONE := "%s ✓"
const TEXT_EXAM_ALL := "Gründlich untersuchen (%s)"
const TEXT_EXAM_ALL_DONE := "Alles untersucht"
const TEXT_LOSS := "Noch ca. %s, dann verblassen %s."
const TEXT_LOSS_NOW := "Die Spuren verblassen gerade."
const LOSS_NOUNS: Dictionary[String, String] = {"Hautzeichen": "die Hautzeichen", "Feine Spuren": "die feinen Spuren"}
const LOSS_NOUN_FALLBACK := "die Spuren"
const TEXT_HOURS := "%d h"
const TEXT_MINUTES := "%d Min"
const STAGE_NAMES: Array[String] = ["Verfallen", "Verwesend", "Welk", "Frisch"]
const STAGE_IDS: Array[StringName] = [&"rotten", &"decaying", &"wilted", &"fresh"]
const TEXT_FIND_STAMP := "→ Merkbuch"
const TEXT_STEP_GROUP := "%s"
const TEXT_NO_FINDS := "Noch nichts untersucht. Was du nicht ansiehst, nimmt sie mit ins Grab."
const TEXT_FINDS := "Funde"

const TEXT_WASH := "Waschen · %s · Grabqualität %s"
const TEXT_WASH_DONE := "✓ Gewaschen"
const TEXT_DRESS_CAPTION := "Einkleiden"
const TEXT_DRESS := "%s · %s · Grabqualität %s"
const TEXT_DRESS_DONE := "✓ Im %s"
const DRESS_LABELS: Dictionary[StringName, String] = {&"shroud": "Leichentuch", &"gown": "Totenhemd"}
const TEXT_LAY_OUT := "Aufbahren · %s · Grabqualität %s"
const TEXT_LAY_OUT_DONE := "✓ Aufgebahrt"
const TEXT_LAY_OUT_HINT := "Augen schließen, Hände falten, Haar kämmen, einen Zweig auflegen."
const TEXT_BALM := "Mit Wacholder räuchern · %s"
const TEXT_BALM_ACTIVE := "Geräuchert bis %s"
const TEXT_BALM_HINT := "Wacholderrauch verlangsamt den Verfall für 18 Stunden."
const TEXT_FULL_PREP := "Voll hergerichtet."

const TEXT_HARVEST := "%s · %s"
const TEXT_HARVEST_DONE := "%s – genommen"
const TEXT_HARVEST_CONFIRM := "Wirklich? Noch einmal klicken"
const TEXT_CONSEQUENCE_ITEM := "+1 %s (Ilse zahlt %d)"
const TEXT_CONSEQUENCE_QUALITY := "Grabqualität %s"
const TEXT_CONSEQUENCE_REPUTATION := "Ruf %s"
const TEXT_CONSEQUENCE_GHOST := "Der Geist wird es wissen."
const TEXT_HARVEST_INTRO := "Was die Stillen mitbrachten, kauft nachts Ilse Kranich an der Westmauer."
const TEXT_TAKE_P4 := "Nehmen: +%d Münzen · Grabqualität %s · Ruf %s"

# --- trade ----------------------------------------------------------------------------------

const TRADE_TITLE := "Ilse Kranich"
const TRADE_SUBTITLE := "An der Westmauer, die Laterne auf dem Stein"
const TRADE_SELL := "Verkaufen"
const TRADE_BUY := "Kaufen"
const TRADE_SELL_ONE := "1 verkaufen"
const TRADE_SELL_ALL := "Alle verkaufen"
const TRADE_BUY_ONE := "Kaufen"
const TRADE_PRICE := "je %d %s"
const TRADE_BONUS := "+%d"
const TRADE_BONUS_LINE := "„Du bist verlässlich geworden.“"
const TRADE_SUM := "Zusammen: %d %s"
const TRADE_STOCK := "noch %d heute Nacht"
const TRADE_SOLD_OUT := "heute Nacht nichts mehr"
const TRADE_NOTHING := "Nichts im Gepäck, was sie nimmt."
const TRADE_VALUABLES := "Wertsachen nimmt sie nicht – die zahlen am Tisch."
const TRADE_COINS := "Deine Münzen: %d"
const TRADE_AWAY := "Ilse ist nicht mehr an der Mauer."
const TRADE_NO_COINS := "Nicht genug Münzen."
const TRADE_NO_ROOM := "Kein Platz im Gepäck."
const TRADE_AFTER_SELL := "„Die Stillen danken es dir nicht. Ich schon.“"
const TRADE_AFTER_BUY: Dictionary[StringName, String] = {
	&"linen": "„Aus einem Nachlass. Frag nicht, aus welchem.“",
	&"juniper": "„Gegen den Geruch. Und gegen das, was mit ihm kommt.“",
	&"gold_leaf": "„Nicht atmen, wenn du es auflegst. Es fliegt dir sonst davon.“",
}
const TRADE_AFTER_BUY_FALLBACK := "„Gute Wahl. Die Nacht ist lang.“"
const TRADE_GREETING_FALLBACK := "„Guten Abend, Totengräber.“"
const TRADE_HINT := "Die Münzen gehen sofort über den Stein. [Esc] zurück zum Gespräch"
const COIN_ONE := "Münze"
const COIN_MANY := "Münzen"

# --- chapter „Sechs Gruben“ -----------------------------------------------------------------

const CHAPTER_TITLE := "Sechs Gruben"
const CHAPTER_INTRO := "Alle sechs Gruben im Holunderwinkel sind belegt und tragen ihr Zeichen. Der Holunder blüht über ihnen, als wäre nichts gewesen."
const CHAPTER_ROWS: Array[String] = ["Tage", "Bestattungen", "Hergerichtet", "Verwertet", "Pietät", "Erkenntnisse", "Geister"]
const CHAPTER_GHOSTS := "%d zufrieden · %d unruhig"
const CHAPTER_INSIGHTS := "%d/%d"
const CHAPTER_CLOSING: Dictionary[StringName, String] = {
	&"devout": "Du gehst leise zwischen ihnen. Sie wissen, wer ihnen die Hände gefaltet hat.",
	&"considerate": "Du hast mit ihnen gesprochen, wenn keiner zuhörte. Manche haben geantwortet.",
	&"matter_of_fact": "Ein Handwerk wie jedes andere. Die Gruben sind voll, die Schaufel ist sauber.",
	&"callous": "Du bist schneller geworden. Die Toten gehen dir inzwischen aus dem Weg.",
	&"hardhearted": "Ilses Kiepe war oft schwer. Die Stillen haben mitgezählt.",
}
const CHAPTER_NOT_LORENZ := "Lorenz Aschau lebt. Unter dem Birkenhang ist es nicht still."
const CHAPTER_LORENZ_OPEN := "Wer in dem fremden Mantel liegt, hast du nicht gefragt. Der Hügel weiß es."
const CHAPTER_CONTINUE_HINT := "Das Spiel geht weiter. Der Hügel erinnert sich."

# --- cemetery / HUD -------------------------------------------------------------------------

const TEXT_VENERABLE_MISSING := "Für „%s“ fehlt noch: %s"
const TEXT_VENERABLE_OK := "„%s“ verlangt Zier und Pflege – beides ist erfüllt."
const TEXT_JOURNAL_BADGE := "[J] Merkbuch"
const TEXT_JOURNAL_BADGE_NEW := "[J] Merkbuch · %d neu"

# --- notifications --------------------------------------------------------------------------

const STYLE_QUIET := &"NoteQuiet"
const STYLE_STORY := &"NoteStory"
const STORY_CAPTION := "Osric an der Bahre"
## Quiet texts of other systems (no signal colour, §7: piety tier notices without numbers).
const QUIET_TEXTS: PackedStringArray = [
	"Du merkst, dass dir das nicht mehr schwerfällt.",
	"Du merkst, dass du leiser gehst.",
	"Jemand wartet an der Westmauer.",
	"Es riecht streng.",
	"Die Geister deuten nicht mehr ins Moos.",
]
## Events of the story thread shown on a wood-framed card (door note, key).
const STORY_TEXTS: PackedStringArray = [
	"An deiner Hüttentür steckt ein Zettel.",
]
const STORY_PREFIXES: PackedStringArray = ["An der Bahre hängt ein rostiger Schlüssel"]


## "3 h" from 90 minutes on (rounded), below "40 Min" (rounded to 5, at least 5).
static func duration(minutes: int) -> String:
	if minutes >= 90:
		return TEXT_HOURS % roundi(float(minutes) / 60.0)
	return TEXT_MINUTES % maxi(5, roundi(float(minutes) / 5.0) * 5)


## CorpseCare.next_loss dictionary → „Noch ca. 3 h, dann verblassen die Hautzeichen.“ ("" = none).
static func loss_text(next_loss: Dictionary) -> String:
	if next_loss.is_empty():
		return ""
	var minutes := int(next_loss.get("minutes", -1))
	if minutes < 0:
		return ""
	if minutes == 0:
		return TEXT_LOSS_NOW
	var noun: String = LOSS_NOUNS.get(str(next_loss.get("label", "")), LOSS_NOUN_FALLBACK)
	return TEXT_LOSS % [duration(minutes), noun]


## Step button: "Kleidung · 10 Min" / "Kleidung ✓".
static func step_text(step: Dictionary) -> String:
	var label := str(step.get("label", ""))
	if bool(step.get("done", false)):
		return TEXT_STEP_DONE % label
	return TEXT_STEP % [label, UIKit.minutes(int(step.get("minutes", 0)))]


static func exam_all_text(minutes: int, open_steps: int) -> String:
	return TEXT_EXAM_ALL_DONE if open_steps <= 0 else TEXT_EXAM_ALL % UIKit.minutes(minutes)


## Stage index 0 (rotten) … 3 (fresh) of a stage id; −1 unknown.
static func stage_index(stage: StringName) -> int:
	return STAGE_IDS.find(stage)


static func wash_text(entry: Dictionary, economy: EconomyConfig) -> String:
	if bool(entry.get("done", false)):
		return TEXT_WASH_DONE
	return TEXT_WASH % [UIKit.minutes(int(entry.get("minutes", 0))), UIKit.signed(EconomyConfig.resolve(economy).quality_washed)]


static func dress_text(kind: StringName, entry: Dictionary, economy: EconomyConfig) -> String:
	var eco := EconomyConfig.resolve(economy)
	var q := int(eco.dress_quality.get(kind, eco.quality_shroud))
	return TEXT_DRESS % [DRESS_LABELS.get(kind, String(kind)), UIKit.minutes(int(entry.get("minutes", 0))), UIKit.signed(q)]


static func dressed_text(kind: StringName) -> String:
	return TEXT_DRESS_DONE % DRESS_LABELS.get(kind, String(kind))


static func lay_out_text(entry: Dictionary, economy: EconomyConfig) -> String:
	if bool(entry.get("done", false)):
		return TEXT_LAY_OUT_DONE
	return TEXT_LAY_OUT % [UIKit.minutes(int(entry.get("minutes", 0))), UIKit.signed(EconomyConfig.resolve(economy).quality_laid_out)]


## "Mit Wacholder räuchern · 10 Min" or, while a window runs, "Geräuchert bis 04:10".
static func balm_text(entry: Dictionary) -> String:
	if bool(entry.get("active", false)) and int(entry.get("until", -1)) >= 0:
		return TEXT_BALM_ACTIVE % UIKit.clock(int(entry.get("until", 0)))
	return TEXT_BALM % UIKit.minutes(int(entry.get("minutes", 0)))


static func harvest_text(entry: Dictionary) -> String:
	if bool(entry.get("done", false)):
		return TEXT_HARVEST_DONE % str(entry.get("label", ""))
	return TEXT_HARVEST % [str(entry.get("verb", "")), UIKit.minutes(int(entry.get("minutes", 0)))]


## Consequence line of a harvest from UtilizationRules.effects() – without the piety (§7):
## „+1 Zopf (Ilse zahlt 4) · Grabqualität −1 · Ruf −3 · Der Geist wird es wissen.“
## `bonus` = Ilse's piety bonus per item. {} → "".
static func consequence_line(effects: Dictionary, bonus: int = 0) -> String:
	if effects.is_empty():
		return ""
	var parts := PackedStringArray()
	var item := StringName(str(effects.get("item", "")))
	if item != &"":
		parts.append(TEXT_CONSEQUENCE_ITEM % [UIKit.item_name(item), maxi(int(effects.get("price", 0)) + bonus, 0)])
	parts.append(TEXT_CONSEQUENCE_QUALITY % UIKit.signed(int(effects.get("quality", 0))))
	var rep := int(effects.get("reputation", 0))
	if rep != 0:
		parts.append(TEXT_CONSEQUENCE_REPUTATION % UIKit.signed(rep))
	if int(effects.get("mood", 0)) != 0:
		parts.append(TEXT_CONSEQUENCE_GHOST)
	return " · ".join(parts)


# --- trade ----------------------------------------------------------------------------------

static func coins(n: int) -> String:
	return COIN_ONE if absi(n) == 1 else COIN_MANY


static func price_text(price: int) -> String:
	return TRADE_PRICE % [price, coins(price)]


static func sum_text(total: int) -> String:
	return TRADE_SUM % [total, coins(total)]


static func stock_text(left: int) -> String:
	return TRADE_STOCK % left if left > 0 else TRADE_SOLD_OUT


## Ilse's greeting in quotes (NightTrade.greeting(), "" = the fallback).
static func greeting_text(greeting: String) -> String:
	var g := greeting.strip_edges()
	if g == "":
		return TRADE_GREETING_FALLBACK
	return g if g.begins_with("„") else "„%s“" % g


static func after_buy(item_id: StringName) -> String:
	return TRADE_AFTER_BUY.get(item_id, TRADE_AFTER_BUY_FALLBACK)


# --- chapter ----------------------------------------------------------------------------------

## Closing lines of the chapter panel: the tier line + the Lorenz line (§1.3, §2.7).
static func chapter_closing(piety_tier: StringName, not_lorenz: bool) -> String:
	var first: String = CHAPTER_CLOSING.get(piety_tier, CHAPTER_CLOSING[&"matter_of_fact"])
	return "%s\n%s" % [first, CHAPTER_NOT_LORENZ if not_lorenz else CHAPTER_LORENZ_OPEN]


## Main insights (not optional) of the data; fallback 5 (§1.4).
static func main_insight_total(insights: Array = []) -> int:
	var list: Array = insights if not insights.is_empty() else Database.insights()
	var n := 0
	for raw: Variant in list:
		var i := raw as InsightData
		# Phase 7: the later insights (i_deathbook, …) are not part of the Phase-4 chapter.
		# Phase 8 (P6): neither is i_underlined („Der unterstrichene Name“, chapter „Wer heraufkommt“).
		if i != null and not i.optional and not i.id in Phase7Texts.PHASE7_INSIGHTS and i.id != JournalManager.UNDERLINED_INSIGHT:
			n += 1
	return n if n > 0 else 5


## Values of CHAPTER_ROWS from Graveyard.chapter_context().
static func chapter_values(context: Dictionary, insights_total: int) -> PackedStringArray:
	var tier := StringName(str(context.get("piety_tier", "")))
	if tier == &"":
		tier = PietyRules.tier(int(context.get("piety", 0)), PietyRules._cfg(null))
	return PackedStringArray([
		str(int(context.get("days", TimeManager.day))),
		str(int(context.get("burials", 0))),
		str(int(context.get("prepared", 0))),
		str(int(context.get("utilized", 0))),
		PietyRules.label(tier),
		CHAPTER_INSIGHTS % [int(context.get("insights", 0)), insights_total],
		CHAPTER_GHOSTS % [int(context.get("content_ghosts", 0)), int(context.get("restless_ghosts", 0))],
	])


# --- cemetery ---------------------------------------------------------------------------------

## „Für „Ehrwürdig“ fehlt noch: Zier 8/12 · Pflegeabzug 9 (höchstens 6)“ ("" = nothing missing).
static func venerable_missing_text(missing: Variant) -> String:
	var parts := PackedStringArray()
	if missing is PackedStringArray:
		parts = missing
	elif missing is Array:
		for p: Variant in missing:
			parts.append(str(p))
	if parts.is_empty():
		return ""
	return TEXT_VENERABLE_MISSING % [CemeteryRating.label(&"venerable"), " · ".join(parts)]


static func journal_badge(unread: int) -> String:
	return TEXT_JOURNAL_BADGE_NEW % unread if unread > 0 else TEXT_JOURNAL_BADGE


# --- notifications ----------------------------------------------------------------------------

## Theme variation of a notification: quiet notices, story events, otherwise by kind ("" = kind).
static func note_style(text: String) -> StringName:
	if text in QUIET_TEXTS:
		return STYLE_QUIET
	if text in STORY_TEXTS or _is_arrival_note(text):
		return STYLE_STORY
	for prefix: String in STORY_PREFIXES:
		if text.begins_with(prefix):
			return STYLE_STORY
	return &""


## Caption above a story notification ("" = none): Osric's arrival lines.
static func note_caption(text: String) -> String:
	return STORY_CAPTION if _is_arrival_note(text) else ""


static func _is_arrival_note(text: String) -> bool:
	for raw: Variant in Database.story_corpses():
		var s := raw as StoryCorpseData
		if s != null and s.arrival_note != "" and s.arrival_note == text:
			return true
	return false
