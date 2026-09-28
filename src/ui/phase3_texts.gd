class_name Phase3Texts
extends RefCounted
## Pure text builders of the Phase-3 UI (docs/PHASE3_DESIGN.md §7): build-bar reasons and
## key help, decor captions and tooltips, the HUD tooltips for cemetery quality and reputation,
## the trend arrow and the tier-change notifications. Input = plain values / CemeteryStatus
## dictionaries, so every string is testable without a world.

## Build-mode status line per can_place reason (§7; &"limit" is built from the decor kind).
const REASONS: Dictionary[StringName, String] = {
	&"route": "Weg freihalten",
	&"grave_ring": "Zu nah am Grab",
	&"obstacle": "Erst roden",
	&"player": "Du stehst im Weg",
	&"locked_section": "Dieser Teil ist noch nicht freigelegt",
	&"blocked": "Hier lässt sich nichts aufstellen",
	&"occupied": "Hier steht schon etwas",
	&"dirt_spot": "Hier wächst Unkraut – nur Kies oder Beet",
	&"corpse": "Eine Leiche liegt im Weg",
	&"no_item": "Keine Zier im Gepäck – an der Werkbank bauen",
}
const TEXT_LIMIT := "Höchstens %d %s"
const TEXT_LIMIT_TOTAL := "Höchstens %d Zierstücke auf dem Friedhof"
const TEXT_VALID := "%s hier aufstellen (%s)"
const TEXT_REMOVE_HINT := "%s abbauen: [Rechtsklick/X]"
const TEXT_EMPTY_BAR := "Keine Zier im Gepäck – an der Werkbank bauen (Rezepte „Zier“)"
const BUILD_HELP := "[Linksklick/E] aufstellen · [Rechtsklick/X] abbauen · [R/Mausrad] drehen · [1–8] wählen · [B] fertig"
## Plural of a decor kind for the limit text (fallback: "<n>× <name>").
const PLURALS: Dictionary[StringName, String] = {
	&"decor_lantern": "Grablaternen",
	&"decor_bench_wood": "Holzbänke",
	&"decor_bench_stone": "Steinbänke",
	&"decor_flowerbed": "Blumenbeete",
	&"decor_grave_vase": "Grabvasen",
	&"decor_path_gravel": "Kiesplatten",
}
const TEXT_ZIER := "Zier +%d"
const TEXT_ZIER_PER := "Zier +%d je %d"
const TEXT_SECTION_DECOR := "%s: Zier %d/%d"
const TEXT_COUNTS_MAX := "zählt bis %d Stück"
const TEXT_FOOTPRINT := "%d × %d Felder"
const TEXT_WALKABLE := "begehbar, darf auf Wege"
const TEXT_GRAVE_RING := "darf ans Grab"
const TEXT_NO_DIRT := "hält Unkraut fern"
const TEXT_GHOST := "freut Geister bis %s m"
const TEXT_PLACE_MAX := "höchstens %d aufstellbar"
const TEXT_LIGHT := "leuchtet nachts"
const LIGHT_DECOR := &"decor_lantern"
## Workbench hint for decor recipes (§7).
const TEXT_RECIPE_DECOR := "Zier +%d – zählt je Abschnitt bis zur Obergrenze"
const TEXT_RECIPE_DECOR_PER := "Zier +%d je %d Stück – zählt je Abschnitt bis zur Obergrenze"

## Trend arrows (forecast of the next daily drift).
const ARROW_UP := "▲"
const ARROW_DOWN := "▼"
const ARROW_FLAT := "–"
const TEXT_REPUTATION := "Ruf: %s"

const TEXT_Q_PARTS := "Gräber %d · Zier %s · Pflege %s"
const TEXT_Q_NEXT := "%s ab %d – es fehlen %d"
const TEXT_Q_TOP := "Höchste Stufe erreicht."
const TEXT_R_HEAD := "Ruf %d von 100 · %s"
const TEXT_R_PAY := "Bezahlung %s je Bestattung"
const TEXT_R_DELIVERY := "1 Lieferung am Tag"
const TEXT_R_DELIVERY_ODD := "Lieferung nur an ungeraden Tagen"
const TEXT_R_STIPEND := "Pflegegeld %d"
const TEXT_R_TOMORROW := "morgen %s"
const TEXT_R_NEXT := "%s ab %d"

const TEXT_TIER_UP := "Der Friedhof gilt jetzt als „%s“."
const TEXT_TIER_DOWN := "Der Friedhof gilt nur noch als „%s“."
const TEXT_REP_TIER := "In Hollerbrück bist du jetzt %s."


# --- build bar ------------------------------------------------------------------------------

## Status text for a can_place reason ("" for &"ok").
static func reason_text(reason: StringName, decor: DecorData = null, max_placed: int = 80) -> String:
	if reason == &"ok":
		return ""
	if reason == &"limit":
		if decor != null and decor.place_max > 0:
			return TEXT_LIMIT % [decor.place_max, PLURALS.get(decor.id, decor.display_name)]
		return TEXT_LIMIT_TOTAL % max_placed
	return REASONS.get(reason, String(reason))


## "Zier +3" / "Zier +1 je 4".
static func zier_text(decor: DecorData) -> String:
	if decor == null:
		return ""
	if decor.zier_divisor > 1:
		return TEXT_ZIER_PER % [decor.zier, decor.zier_divisor]
	return TEXT_ZIER % decor.zier


## Multi-line tooltip of a build-bar slot: name, Zier, footprint, specialities.
static func decor_tooltip(decor: DecorData) -> String:
	if decor == null:
		return ""
	var first := PackedStringArray([zier_text(decor)])
	if decor.counted_max > 0:
		first.append(TEXT_COUNTS_MAX % decor.counted_max)
	var special := PackedStringArray([TEXT_FOOTPRINT % [decor.footprint.x, decor.footprint.y]])
	if decor.walkable:
		special.append(TEXT_WALKABLE)
	elif decor.allow_grave_ring:
		special.append(TEXT_GRAVE_RING)
	if decor.suppresses_dirt:
		special.append(TEXT_NO_DIRT)
	if decor.ghost_bonus_radius > 0.0:
		special.append(TEXT_GHOST % _metres(decor.ghost_bonus_radius))
	if decor.id == LIGHT_DECOR:
		special.append(TEXT_LIGHT)
	if decor.place_max > 0:
		special.append(TEXT_PLACE_MAX % decor.place_max)
	return "\n".join([decor.display_name, " · ".join(first), " · ".join(special)])


## "Ostwiese: Zier 6/9" from a CemeteryStatus.sections() entry.
static func section_decor_text(section: Dictionary) -> String:
	if section.is_empty():
		return ""
	return TEXT_SECTION_DECOR % [str(section.get("name", "")), int(section.get("decor", 0)), int(section.get("decor_cap", 0))]


## Workbench line / tooltip for a decor recipe ("" for other outputs).
static func recipe_decor_hint(decor: DecorData) -> String:
	if decor == null:
		return ""
	if decor.zier_divisor > 1:
		return TEXT_RECIPE_DECOR_PER % [decor.zier, decor.zier_divisor]
	return TEXT_RECIPE_DECOR % decor.zier


# --- HUD ------------------------------------------------------------------------------------

static func arrow(forecast: int) -> String:
	if forecast > 0:
		return ARROW_UP
	if forecast < 0:
		return ARROW_DOWN
	return ARROW_FLAT


## Tooltip of the quality block: "Gräber 48 · Zier +12 · Pflege −3" + next tier.
static func quality_tooltip(breakdown: Dictionary) -> String:
	var lines := PackedStringArray([TEXT_Q_PARTS % [int(breakdown.get("graves", 0)),
			UIKit.signed(int(breakdown.get("decor", 0))), UIKit.signed(-int(breakdown.get("dirt", 0)))]])
	var next: StringName = StringName(str(breakdown.get("next_rating", "")))
	var missing := Phase4Texts.venerable_missing_text(breakdown.get("venerable_missing", PackedStringArray()))
	var gated := missing != "" and StringName(str(breakdown.get("rating", ""))) != &"venerable"
	if next != &"" and gated and int(breakdown.get("total", 0)) >= int(breakdown.get("next_at", 0)):
		pass # the points are there – only the Ehrwürdig condition is missing (line below)
	elif next != &"":
		var at := int(breakdown.get("next_at", 0))
		lines.append(TEXT_Q_NEXT % [CemeteryRating.label(next), at, maxi(at - int(breakdown.get("total", 0)), 0)])
	else:
		lines.append(TEXT_Q_TOP)
	# Phase 4 §2.14: „Ehrwürdig“ also needs decor and tending – name what is missing.
	if gated:
		lines.append(missing)
	return "\n".join(lines)


## Tooltip of the reputation line (§7): value + tier, effects, tomorrow's drift, next tier.
static func reputation_tooltip(rep: Dictionary) -> String:
	var effects := PackedStringArray([TEXT_R_PAY % UIKit.signed(int(rep.get("pay_bonus", 0)))])
	effects.append(TEXT_R_DELIVERY_ODD if bool(rep.get("every_other_day", false)) else TEXT_R_DELIVERY)
	effects.append(TEXT_R_STIPEND % int(rep.get("stipend", 0)))
	effects.append(TEXT_R_TOMORROW % UIKit.signed(int(rep.get("forecast", 0))))
	var lines := PackedStringArray([TEXT_R_HEAD % [int(rep.get("value", 0)), str(rep.get("label", ""))], " · ".join(effects)])
	var next: StringName = StringName(str(rep.get("next_tier", "")))
	if next != &"":
		lines.append(TEXT_R_NEXT % [ReputationRules.label(next), int(rep.get("next_at", 0))])
	return "\n".join(lines)


## Notification for a cemetery tier change ("" when unchanged / unknown).
static func rating_change_text(old_rating: StringName, new_rating: StringName) -> String:
	var a := CemeteryRating.TIERS.find(old_rating)
	var b := CemeteryRating.TIERS.find(new_rating)
	if a < 0 or b < 0 or a == b:
		return ""
	return (TEXT_TIER_UP if b > a else TEXT_TIER_DOWN) % CemeteryRating.label(new_rating)


## Notification for a reputation tier change ("" when unchanged / unknown).
static func reputation_change_text(old_tier: StringName, new_tier: StringName) -> String:
	if old_tier == new_tier or ReputationRules.tier_index(old_tier) < 0 or ReputationRules.tier_index(new_tier) < 0:
		return ""
	return TEXT_REP_TIER % ReputationRules.label(new_tier).to_lower()


static func _metres(m: float) -> String:
	return String.num(m, 1).replace(".", ",")
