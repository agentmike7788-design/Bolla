class_name OrdersConfig
extends Resource
## Orders (docs/PHASE7_DESIGN.md §2.5, §3.4): data/config/orders_config.tres.

## At most this many accepted orders at once.
@export var max_active: int = 4
## Offers on the parish board each morning.
@export var board_offers: int = 2
@export var board_giver: StringName = &"council"
## Minute of the morning check (deadlines, board offers): 06:00.
@export var refresh_minute: int = 360
# Phase 8 (docs/PHASE8_DESIGN.md §2.4): friend orders count separately (at most 2 active).
@export var max_active_friend: int = 2
# Phase 9 (docs/PHASE9_DESIGN.md §2.1): orders of category quest (errands, chain tasks) count separately (at most 3
# active) – never for the village chapter, stats.orders_done or the 4 normal / 2 friend orders.
@export var max_active_quest: int = 3
