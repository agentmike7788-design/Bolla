class_name CashBookConfig
extends Resource
## The gravekeeper's cash book (docs/PHASE10_DESIGN.md §2.6, §3.4): data/config/cash_book_config.tres (P3 owns the data).
## Every income with its source (EventBus.payment_received / trader_trade / shop_trade; the source follows from the
## reason text through a prefix table), every expense with its purpose (EventBus.coins_spent, GameState.COIN_REASONS),
## „ohne Beleg" from the hourly / daily comparison with the holdings. Day pages for keep_days, month pages unlimited.

## Day pages kept (62 days); the holdings are compared every 60 game minutes and at the day change.
@export var keep_days: int = 62
@export var check_every_minutes: int = 60
## {source: {label: String, prefixes: PackedStringArray, receipt: bool}} – receipt false (and „ohne Beleg") count
## for the estimate (§2.5.6). §3.4 class default {}; the §2.6 table is in the .tres (W0).
@export var sources: Dictionary[StringName, Dictionary] = {}
## COIN_REASONS → „Pacht", „Markt" … (§3.4 class default {}; the .tres carries the W0 labels).
@export var purpose_labels: Dictionary[StringName, String] = {}
@export var untracked_label: String = "ohne Beleg"
