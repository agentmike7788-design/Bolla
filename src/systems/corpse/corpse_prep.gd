class_name CorpsePrep
extends RefCounted
## Pure preparation rules (docs/PHASE4_DESIGN.md §2.3, §2.5, §3.4): wash, dress (shroud /
## gown), lay out, juniper smoking. The running-window check of &"balm" reads the world clock
## (TimeManager); everything else only the record, the inventory and the config.

const ACTION_WASH := &"wash"
const ACTION_DRESS := &"dress"
const ACTION_LAY_OUT := &"lay_out"
const ACTION_BALM := &"balm"
const ACTIONS: Array[StringName] = [ACTION_WASH, ACTION_DRESS, ACTION_LAY_OUT, ACTION_BALM]

const REASON_NO_CORPSE := "Auf dem Tisch liegt keine Leiche."
const REASON_UNKNOWN := "Das geht hier nicht."
const REASON_WASHED := "Die Leiche ist schon gewaschen."
const REASON_DRESSED_WASH := "Nach dem Einkleiden nicht mehr möglich."
const REASON_DRESSED := "Die Leiche ist bereits eingehüllt."
const REASON_DECIDE_FIRST := "Erst über die Wertsachen entscheiden."
const REASON_UNKNOWN_DRESS := "Diese Kleidung gibt es nicht."
const REASON_LAID_OUT := "Die Leiche ist schon aufgebahrt."
const REASON_BALM_ACTIVE := "Der Wacholderrauch hängt noch über ihr."
const REASON_BALM_MAX := "Mehr Rauch hilft ihr nicht mehr."
## "<Werkzeug> nötig – Werkbank." · "Kein <Item> – an der Werkbank herstellen." · "Kein <Item> mehr."
const FORMAT_NO_TOOL := "%s nötig – Werkbank."
const FORMAT_NO_ITEM := "Kein %s – an der Werkbank herstellen."
const FORMAT_NO_BALM := "Keine %s mehr – Osric verkauft sie."


## "" = possible. wash (tool, not dressed, not washed) · dress (kind shroud/gown, item,
## valuables decided, not dressed) · lay_out (tool, not laid out) · balm (item, no running
## window, < balm_max_windows).
static func block_reason(record: CorpseRecord, action: StringName, inv: Inventory, cfg: PrepConfig, kind: StringName = &"") -> String:
	if record == null:
		return REASON_NO_CORPSE
	var c := _cfg(cfg)
	match action:
		ACTION_WASH:
			if record.washed:
				return REASON_WASHED
			if record.is_dressed():
				return REASON_DRESSED_WASH
			if not _has(inv, c.wash_tool):
				return FORMAT_NO_TOOL % _item_name(c.wash_tool)
		ACTION_DRESS:
			if record.is_dressed():
				return REASON_DRESSED
			if not c.dress.has(kind):
				return REASON_UNKNOWN_DRESS
			if record.needs_valuables_decision():
				return REASON_DECIDE_FIRST
			if not _has(inv, c.dress_item(kind)):
				return FORMAT_NO_ITEM % _item_name(c.dress_item(kind))
		ACTION_LAY_OUT:
			if record.laid_out:
				return REASON_LAID_OUT
			if not _has(inv, c.lay_out_tool):
				return FORMAT_NO_TOOL % _item_name(c.lay_out_tool)
		ACTION_BALM:
			if is_balm_active(record, TimeManager.total_minutes()):
				return REASON_BALM_ACTIVE
			if record.balm_windows.size() / 2 >= c.balm_max_windows:
				return REASON_BALM_MAX
			if not _has(inv, c.balm_item):
				return FORMAT_NO_BALM % _item_name(c.balm_item)
		_:
			return REASON_UNKNOWN
	return ""


static func minutes(action: StringName, cfg: PrepConfig, kind: StringName = &"") -> int:
	var c := _cfg(cfg)
	match action:
		ACTION_WASH:
			return c.wash_minutes
		ACTION_DRESS:
			return c.dress_minutes(kind)
		ACTION_LAY_OUT:
			return c.lay_out_minutes
		ACTION_BALM:
			return c.balm_minutes
	return 0


## A juniper window [start, end) contains `now_total`.
static func is_balm_active(record: CorpseRecord, now_total: int) -> bool:
	if record == null:
		return false
	var w := record.balm_windows
	for i: int in range(0, w.size() - 1, 2):
		if now_total >= w[i] and now_total < w[i + 1]:
			return true
	return false


## End of the running window (−1 = none) – for "geräuchert bis 04:10".
static func balm_end(record: CorpseRecord, now_total: int) -> int:
	if record == null:
		return -1
	var w := record.balm_windows
	for i: int in range(0, w.size() - 1, 2):
		if now_total >= w[i] and now_total < w[i + 1]:
			return w[i + 1]
	return -1


static func _has(inv: Inventory, id: StringName) -> bool:
	return inv != null and id != &"" and inv.has(id)


static func _item_name(id: StringName) -> String:
	if Database.has_item(id):
		var item := Database.item(id) as ItemData
		if item != null and item.display_name != "":
			return item.display_name
	return String(id)


static func _cfg(cfg: PrepConfig) -> PrepConfig:
	if cfg != null:
		return cfg
	var data := Database.config(&"prep_config") as PrepConfig
	return data if data != null else PrepConfig.new()
