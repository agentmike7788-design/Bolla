class_name CashBook
extends Node
## STUB (P3) – Systems/CashBook (docs/PHASE10_DESIGN.md §2.6, §3.1, §3.3, §3.4, §5.1), groups &"cash_book", &"saveable",
## save_id cash_book / 86: the gravekeeper's cash book – every income by source (EventBus.payment_received, trader_trade,
## shop_trade; source from the reason text, CashBookRules.source_of) and every expense by purpose (EventBus.coins_spent,
## GameState.COIN_REASONS), „ohne Beleg" from the comparison with the holdings once an hour and at the day change, day
## pages for keep_days (62), month pages unlimited, sums only (no single entries). Listens and books only in its own
## state (§3.3); EventBus.cash_booked per booking. The book begins on the first day it sees (open_day = the day of the
## first load_state with an empty node / a new game).
## W0: open_day, day_page, month_page, booked_income and untracked_in answer from load_state (§5.1 {open_day,
## last_holdings, last_check, days, months}); everything else is inert. W1 (P3) fills the bodies; the signatures are the
## contract.

const GROUP := &"cash_book"

@export var save_id: String = "cash_book"
@export var save_order: int = 86

## Rules; null = data/config/cash_book_config.tres (resolved lazily).
var config: CashBookConfig

## W0 stub store (P3 may rename it – the fixtures use load_state only).
var _open_day: int = -1
var _days: Dictionary = {}
var _months: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## -1 = not open yet.
func open_day() -> int:
	return _open_day


## {in: {source: n}, out: {purpose: n}, untracked, holdings}
func day_page(day: int) -> Dictionary:
	return _page(_days.get(str(day)))


func week_page(_week: int) -> Dictionary:
	return {}


func month_page(month_key: String) -> Dictionary:
	return _page(_months.get(month_key))


func booked_income(month_key: String, receipt_only: bool) -> int:
	var page := month_page(month_key)
	var total := 0
	var incoming: Dictionary = page.get("in", {})
	for source: Variant in incoming:
		# W0: the receipt flag straight from CashBookConfig.sources (P3 may route it through CashBookRules.is_receipt).
		var spec: Variant = _cfg().sources.get(StringName(str(source)), {})
		if not receipt_only or (spec is Dictionary and bool((spec as Dictionary).get("receipt", false))):
			total += int(incoming[source])
	return total


func untracked_in(month_key: String) -> int:
	return int(month_page(month_key).get("untracked", 0))


## Chapter panel, bots.
func totals_since(_day: int) -> Dictionary:
	return {}


## §5.1 {open_day, last_holdings, last_check, days, months}.
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	var od: Variant = data.get("open_day", -1)
	_open_day = int(od) if (od is int or od is float) else -1
	_days = (data.get("days") as Dictionary).duplicate(true) if data.get("days") is Dictionary else {}
	_months = (data.get("months") as Dictionary).duplicate(true) if data.get("months") is Dictionary else {}


func _cfg() -> CashBookConfig:
	if config == null:
		config = Database.config(&"cash_book_config") as CashBookConfig
		if config == null:
			config = CashBookConfig.new()
	return config


## A stored page as {in, out, untracked} with integer sums ({} for anything else).
static func _page(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var src := raw as Dictionary
	var out := {"in": {}, "out": {}, "untracked": 0}
	for side: String in ["in", "out"]:
		var part: Variant = src.get(side)
		if part is Dictionary:
			for k: Variant in part:
				var v: Variant = (part as Dictionary)[k]
				if v is int or v is float:
					(out[side] as Dictionary)[StringName(str(k))] = int(v)
	var u: Variant = src.get("untracked", 0)
	out["untracked"] = int(u) if (u is int or u is float) else 0
	if src.has("holdings"):
		var h: Variant = src.get("holdings")
		out["holdings"] = int(h) if (h is int or h is float) else 0
	return out
