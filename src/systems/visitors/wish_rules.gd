class_name WishRules
extends RefCounted
## Pure wish rules (docs/PHASE8_DESIGN.md §2.2.5, §3.4): the choice (order tend [only when neglected], flowers,
## candle, line [only on a designed stone with < 4 lines], vase – turned by the grave seed; the first kind not
## fulfilled yet), fulfilment by kind, the tip. The wish templates come from Database.wishes()
## (data/visitors/wishes: w_tend, w_flowers, w_candle, w_vase, w_line_1…6).

const ORDER: Array[StringName] = [&"tend", &"flowers", &"candle", &"line", &"vase"]
const KIND_TEND := &"tend"
const KIND_FLOWERS := &"flowers"
const KIND_CANDLE := &"candle"
const KIND_LINE := &"line"
const KIND_VASE := &"vase"
## tend is fulfilled at care spot level ≤ 1, offered only at ≥ 2 (neglected).
const TEND_MAX_LEVEL := 1


## Wish template id or &"" (no kind left for this grave).
static func choose(grave_id: String, kin_id: StringName, day: int, tree: SceneTree) -> StringName:
	var turn := posmod(hash(grave_id), ORDER.size())
	for i: int in ORDER.size():
		var kind: StringName = ORDER[(i + turn) % ORDER.size()]
		var id := _template_for(kind, grave_id, kin_id, day, tree)
		if id == &"":
			continue
		var probe := {"kind": String(kind), "grave_id": grave_id, "day": day, "template": String(id), "candle_seen": false}
		if not fulfilled(probe, tree):
			return id
	return &""


## The wish {kind, grave_id, day, template | line, candle_seen} is fulfilled now.
static func fulfilled(wish: Dictionary, tree: SceneTree) -> bool:
	var grave_id := str(wish.get("grave_id", ""))
	var care := _first(tree, &"grave_care") as GraveCare
	match StringName(str(wish.get("kind", ""))):
		KIND_TEND:
			return GraveView.dirt_level(grave_id, tree) <= TEND_MAX_LEVEL and not (care != null and care.is_disturbed(grave_id))
		KIND_FLOWERS:
			if care == null:
				return false
			var f := care.flowers_state(grave_id)
			return f == GraveCare.FLOWERS_FRESH or f == GraveCare.FLOWERS_WREATH
		KIND_CANDLE:
			if bool(wish.get("candle_seen", false)):
				return true
			return care != null and care.last_lit_night(grave_id) >= int(wish.get("day", 0))
		KIND_LINE:
			var line := line_of(wish)
			var graveyard := _first(tree, &"graveyard") as Graveyard
			var grave := graveyard.get_grave(grave_id) if graveyard != null else null
			return line != "" and grave != null and grave.extra_lines.has(line)
		KIND_VASE:
			return GraveView.has_vase(grave_id, tree)
	return false


## tip_base (+1 goodwill ≥ 6, +1 quality ≥ 15), capped by tip_cap_day − paid_today.
static func tip(goodwill: int, quality: int, paid_today: int, cfg: VisitorConfig) -> int:
	var c := cfg if cfg != null else VisitorConfig.new()
	var coins := c.tip_base
	if goodwill >= c.tip_goodwill_min:
		coins += 1
	if quality >= c.tip_quality_min:
		coins += 1
	return clampi(coins, 0, maxi(c.tip_cap_day - paid_today, 0))


## The line of a line wish (its template's line_text, or a stored "line").
static func line_of(wish: Dictionary) -> String:
	var stored := str(wish.get("line", ""))
	if stored != "":
		return stored
	var data := Database.wish(StringName(str(wish.get("template", "")))) as WishData
	return data.line_text if data != null else ""


## The template of `kind` for this grave (&"" = the kind does not apply here).
static func _template_for(kind: StringName, grave_id: String, _kin_id: StringName, day: int, tree: SceneTree) -> StringName:
	match kind:
		KIND_TEND:
			if GraveView.dirt_level(grave_id, tree) < GraveView.NEGLECTED_LEVEL:
				return &""
		KIND_LINE:
			var graveyard := _first(tree, &"graveyard") as Graveyard
			if graveyard == null or not graveyard.can_append_inscription(grave_id):
				return &""
			var grave := graveyard.get_grave(grave_id)
			var lines: Array[WishData] = []
			for res: Resource in Database.wishes():
				var w := res as WishData
				if w != null and w.kind == KIND_LINE and w.line_text != "" and not grave.extra_lines.has(w.line_text):
					lines.append(w)
			if lines.is_empty():
				return &""
			return lines[posmod(hash([grave_id, day]), lines.size())].id
	for res: Resource in Database.wishes():
		var w := res as WishData
		if w != null and w.kind == kind:
			return w.id
	return &""


static func _first(tree: SceneTree, group: StringName) -> Node:
	return tree.get_first_node_in_group(group) if tree != null else null
