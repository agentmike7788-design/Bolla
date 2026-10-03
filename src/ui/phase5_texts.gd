class_name Phase5Texts
extends RefCounted
## Texts and small pure helpers of the Phase-5 UI (docs/PHASE5_DESIGN.md §7): build-site panel,
## station panels (tool effect, kiln status), the tool belt, the HUD chapter line, the objective
## lines, the day summary additions and the chapter panel „Namen in Stein“. Reads only its
## arguments and static game data (Database, configs) – never live game state.

# --- build site ---------------------------------------------------------------------------
const BUILD_TITLE := "Bauplatz: %s"
const BUILD_COSTS := "Was der Bau braucht"
const BUILD_HAVE := "%d / %d"
## "Meißelsatz aus Hollerbrück · 15 Münzen"
const BUILD_COIN_ROW := "%s · %d %s"
const BUILD_COIN_FALLBACK := "Teile aus Hollerbrück"
const BUILD_DURATION := "Dauer"
const BUILD_BUTTON := "Bauen (%s)"
const BUILD_NOTE := "Verbraucht wird erst, wenn der Bau steht. Eine Station bleibt, wo sie gebaut ist."
const BUILD_COINS_HAVE := "Münzen im Beutel: %d"

# --- station panels -------------------------------------------------------------------------
const TOOL_REPLACES := "ersetzt: %s"
const TOOL_EFFECT := "%s %d → %d Min"
const TOOL_NEW := "%s: neu · %d Min"
const TOOL_HAVE := "Hängt schon am Gürtel."
const TOOL_HAVE_BETTER := "Am Gürtel hängt schon %s."
const KILN_ALONE := "läuft allein · %s"
const KILN_UNTIL := "fertig um %s"
const KILN_LEFT := "noch %s"
const KILN_READY := "fertig – holen"
const KILN_RUNNING := "Der Meiler brennt"
const KILN_DONE := "Der Meiler ist ausgebrannt"
const HOURS := "%d Std."
const HOURS_MINUTES := "%d Std. %d Min"

# --- tool belt ------------------------------------------------------------------------------
const BELT_TITLE := "Werkzeuggürtel"
const BELT_TIER := "Stufe %d"
const BELT_NO_TOOL := "keine"
const BELT_OTHER := "Pflege & Verwertung"
## Info line under the belt while no tier tool is hovered.
const BELT_HINT := "Die beste Stufe am Gürtel gilt von selbst. Zeig auf ein Werkzeug, dann steht hier seine Wirkung."
const BELT_FASTER := "%s dauert %d statt %d Minuten."
const BELT_SAME := "%s: %d Minuten."
const BELT_OPENS := "%s: %d Minuten – geht erst mit %s."
const BELT_NEXT := "Nächste Stufe: %s (%s)"
const BELT_TOP := "Beste Stufe erreicht."
## Names of the tool-driven actions (ActionConfig.action_tools keys).
const ACTION_NAMES: Dictionary[StringName, String] = {&"dig": "Graben", &"bury": "Bestatten"}

# --- HUD / objective --------------------------------------------------------------------------
## Cemetery tooltip: „Werkhof 2/3 · Werkzeug 2/3 · Meisterstein 0/1"
const CHAPTER_LINE := "Werkhof %d/%d · Werkzeug %d/%d · Meisterstein %d/%d"
const CHAPTER_LINE_DONE := "Namen in Stein: erreicht"
const OBJ_OSRIC := "Sprich mit Osric über den Bruch"
const OBJ_GATE := "Ostpforte aufschließen"
const OBJ_BUILD := "Bauplatz: %s bauen"
const OBJ_BOULDERS := "Findlinge brechen"
const OBJ_BOULDERS_TOOL := "Findlinge brechen – Spitzhacke nötig"
const OBJ_KILN := "Holzkohle ist fertig"
const OBJ_STONE_READY := "Ein Stein liegt bereit – setz ihn bei %s"
const OBJ_TOOLS := "Werkzeug: %s"
const OBJ_MASTER := "Setz den Meisterstein"
const OBJ_NAMELESS := "Gräber ohne Namen: %d"

# --- day summary ------------------------------------------------------------------------------
const DAY_GATHERED := "Gesammelt"
const DAY_CRAFTED := "Hergestellt"
const DAY_BUILT := "Gebaut"
const DAY_SPENT := "Ausgaben"
## "27 Münzen (Bau 15 · Osric 12)"
const DAY_SPENT_VALUE := "%d %s (%s)"
const SPENT_LABELS: Dictionary[StringName, String] = {&"license": "Brief", &"build": "Bau", &"building": "Gebäude", &"osric": "Osric", &"ilse": "Ilse",
		&"village": "Dorf", &"donation": "Spenden", &"round": "Runden", &"consecration": "Weihe"}

# --- chapter „Namen in Stein" -------------------------------------------------------------------
const CHAPTER_ID := &"names_in_stone"
const CHAPTER_TITLE := "Namen in Stein"
const CHAPTER_INTRO := "Werkzeug, Tuch und Stein – Dinge, die länger halten als der, der sie macht. Die Toten haben ihre Namen zurück."
const CHAPTER_ROWS: PackedStringArray = ["Tage seit dem Werkhof", "Stationen", "Werkzeug", "Steine gesetzt",
		"Gräber mit Namen", "Ausgaben seit dem Werkhof", "Zufriedene Geister"]
const CHAPTER_STONES := "%d (davon %d %s)"
const CHAPTER_MASTER_ONE := "Meisterstein"
const CHAPTER_MASTER_MANY := "Meistersteine"
const CHAPTER_GHOSTS := "%d → %d"
const CHAPTER_FINAL_FALLBACK := "Die Namen stehen jetzt da, wo der Regen sie nicht wegwäscht."
const NONE := "–"
const COIN_ONE := "Münze"
const COIN_MANY := "Münzen"


static func coins(n: int) -> String:
	return COIN_ONE if n == 1 else COIN_MANY


## "90 Min", "8 Std.", "3 Std. 20 Min" (minutes < 60 stay minutes).
static func duration(minutes: int) -> String:
	var m := maxi(minutes, 0)
	if m < 60:
		return UIKit.minutes(m)
	if m % 60 == 0:
		return HOURS % (m / 60)
	return HOURS_MINUTES % [m / 60, m % 60]


# --- build site ---------------------------------------------------------------------------

## Cost rows of a station: [{id, name, need, have, ok, coin: bool}] – items in build_inputs order,
## then the coins as their own row („Meißelsatz aus Hollerbrück · 15 Münzen").
static func build_rows(station: StationData, inv: Inventory) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if station == null:
		return out
	var valid := is_instance_valid(inv)
	for id: StringName in station.build_inputs:
		var need := int(station.build_inputs[id])
		var have := inv.count(id) if valid else 0
		out.append({"id": id, "name": UIKit.item_name(id), "need": need, "have": have, "ok": have >= need, "coin": false})
	if station.build_coins > 0:
		var have_coins := inv.count(WorkshopRules.COIN) if valid else 0
		var label := station.coin_part_label if station.coin_part_label != "" else BUILD_COIN_FALLBACK
		out.append({"id": WorkshopRules.COIN, "name": BUILD_COIN_ROW % [label, station.build_coins, coins(station.build_coins)],
				"need": station.build_coins, "have": have_coins, "ok": have_coins >= station.build_coins, "coin": true})
	return out


# --- tools ------------------------------------------------------------------------------------

## [{label, base, min_tier}] of what a tool kind speeds up: the actions of ActionConfig.action_tools
## (Graben, Bestatten) and the gather kinds with this tool (Lehm stechen, Erle fällen, …).
static func tool_tasks(kind: StringName, actions: ActionConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kind == &"":
		return out
	if actions != null:
		for action: StringName in actions.action_tools:
			if actions.action_tools[action] != kind:
				continue
			var base: Variant = actions.get(String(action) + "_minutes")
			if base is int:
				out.append({"label": ACTION_NAMES.get(action, String(action)), "base": int(base), "min_tier": 0})
	for res: Resource in Database.gather_kinds():
		var g := res as GatherNodeData
		if g != null and g.tool_kind == kind:
			out.append({"label": g.verb if g.verb != "" else g.display_name, "base": g.minutes, "min_tier": g.min_tier})
	return out


## Station panel, tool recipe: "Graben 50 → 35 Min · Bestatten 25 → 20 Min" (from `from_tier` to
## `tier`); tasks the old tier could not do come first: "Erle fällen: neu · 50 Min". At most `limit`.
static func tool_effect(kind: StringName, from_tier: int, tier: int, actions: ActionConfig, limit: int = 2) -> String:
	var opened := PackedStringArray()
	var faster := PackedStringArray()
	var act := actions if actions != null else ActionConfig.new()
	for task: Dictionary in tool_tasks(kind, act):
		var min_tier := int(task.min_tier)
		if tier < min_tier:
			continue
		var after := act.tool_minutes(int(task.base), tier)
		if from_tier < min_tier:
			opened.append(TOOL_NEW % [task.label, after])
			continue
		var before := act.tool_minutes(int(task.base), from_tier)
		if after < before:
			faster.append(TOOL_EFFECT % [task.label, before, after])
	# New tasks first (Werkstein with the master pick), then what gets faster.
	opened.append_array(faster)
	return " · ".join(opened.slice(0, limit))


## Belt tooltip lines of one kind at `tier` (compared with tier 0): „Graben dauert 35 statt 60
## Minuten." · „Erle fällen: 35 Minuten." · tasks still closed: „Werkstein brechen: 25 Minuten –
## geht erst mit Meisterhacke."
static func belt_effect_lines(kind: StringName, tier: int, actions: ActionConfig, tools: ToolConfig) -> PackedStringArray:
	var out := PackedStringArray()
	var act := actions if actions != null else ActionConfig.new()
	for task: Dictionary in tool_tasks(kind, act):
		var min_tier := int(task.min_tier)
		var base := int(task.base)
		if tier < min_tier:
			out.append(BELT_OPENS % [task.label, act.tool_minutes(base, min_tier), ToolRules.tool_name(kind, min_tier, tools)])
			continue
		var now := act.tool_minutes(base, tier)
		if min_tier <= 0 and now < base:
			out.append(BELT_FASTER % [task.label, now, base])
		else:
			out.append(BELT_SAME % [task.label, now])
	return out


## Full belt tooltip of one tier tool: name (tier), the effect lines and the next step.
static func belt_tooltip(kind: StringName, tier: int, actions: ActionConfig, tools: ToolConfig) -> String:
	var name := ToolRules.tool_name(kind, tier, tools)
	var label: String = tools.labels.get(kind, String(kind)) if tools != null else String(kind)
	var head := "%s – %s" % [name, BELT_TIER % tier] if name != "" else "%s: %s" % [label, BELT_NO_TOOL]
	var lines := PackedStringArray([head])
	lines.append_array(belt_effect_lines(kind, tier, actions, tools))
	var next := ToolRules.tool_name(kind, tier + 1, tools)
	if next != "":
		var hint: String = tools.source_hint.get(kind, "") if tools != null else ""
		lines.append(BELT_NEXT % [next, hint if tier <= 0 and hint != "" else "Esse"])
	else:
		lines.append(BELT_TOP)
	return "\n".join(lines)


# --- HUD ----------------------------------------------------------------------------------------

## „Werkhof 2/3 · Werkzeug 2/3 · Meisterstein 0/1" from Workshop.goal_progress() ({} → "").
static func chapter_line(progress: Dictionary) -> String:
	if progress.is_empty() or not progress.has("stations"):
		return ""
	var s: Array = progress.get("stations", [0, 0])
	var t: Array = progress.get("tools", [0, 0])
	var m: Array = progress.get("master", [0, 0])
	return CHAPTER_LINE % [int(s[0]), int(s[1]), int(t[0]), int(t[1]), int(m[0]), int(m[1])]


## Tool goal text for the objective: "Schaufel 1/1 · Axt 0/1 · Spitzhacke 1/2".
static func tool_goal_text(tiers: Dictionary, goal: Dictionary, tools: ToolConfig) -> String:
	var parts := PackedStringArray()
	for kind: Variant in goal:
		var label: String = tools.labels.get(StringName(str(kind)), str(kind)) if tools != null else str(kind)
		parts.append("%s %d/%d" % [label, mini(int(tiers.get(kind, 0)), int(goal[kind])), int(goal[kind])])
	return " · ".join(parts)


# --- day summary --------------------------------------------------------------------------------

## "6 Holz, 3 Flachs" from {item_id: amount} ("" when empty).
static func amounts_text(amounts: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: Variant in amounts:
		if int(amounts[id]) > 0:
			parts.append("%d %s" % [int(amounts[id]), UIKit.item_name(StringName(str(id)))])
	return ", ".join(parts)


## "27 Münzen (Bau 15 · Osric 12)" from {reason: coins} ("" when nothing was spent).
static func spent_text(spent: Dictionary) -> String:
	var total := 0
	var parts := PackedStringArray()
	for reason: StringName in SPENT_LABELS:
		var n := int(spent.get(reason, spent.get(String(reason), 0)))
		if n > 0:
			total += n
			parts.append("%s %d" % [SPENT_LABELS[reason], n])
	for key: Variant in spent:
		if not SPENT_LABELS.has(StringName(str(key))) and int(spent[key]) > 0:
			total += int(spent[key])
			parts.append("%s %d" % [str(key), int(spent[key])])
	if total <= 0:
		return ""
	return DAY_SPENT_VALUE % [total, coins(total), " · ".join(parts)]


## "Webstuhl, Esse" from station ids.
static func stations_text(ids: Array) -> String:
	var parts := PackedStringArray()
	for id: Variant in ids:
		var s := Database.station(StringName(str(id))) as StationData
		parts.append(s.display_name if s != null and s.display_name != "" else str(id))
	return ", ".join(parts)


# --- chapter panel ------------------------------------------------------------------------------

## Values of CHAPTER_ROWS from Workshop.chapter_context().
static func chapter_values(context: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	out.append(str(int(context.get("workshop_days", 0))))
	var built: Array = context.get("stations", [])
	out.append(stations_text(built) if not built.is_empty() else NONE)
	var tools := Database.config(&"tool_config") as ToolConfig
	var tiers: Dictionary = context.get("tool_tiers", {})
	var names := PackedStringArray()
	for kind: Variant in tiers:
		var n := ToolRules.tool_name(StringName(str(kind)), int(tiers[kind]), tools)
		if n != "":
			names.append(n)
	out.append(" · ".join(names) if not names.is_empty() else NONE)
	var master := int(context.get("master_stones", 0))
	out.append(CHAPTER_STONES % [int(context.get("stones_set", 0)), master, CHAPTER_MASTER_ONE if master == 1 else CHAPTER_MASTER_MANY])
	out.append("%d/%d" % [int(context.get("named_graves", 0)), int(context.get("graves_total", 0))])
	var spent := spent_text(context.get("coins_spent", {}))
	out.append(spent if spent != "" else NONE)
	out.append(CHAPTER_GHOSTS % [int(context.get("content_before", 0)), int(context.get("content_now", 0))])
	return out
