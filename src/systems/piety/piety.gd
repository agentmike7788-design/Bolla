class_name Piety
extends Node
## STUB (P3) – docs/PHASE4_DESIGN.md §2.7, §3.4. Systems/Piety (group &"piety", not saved: the
## value lives in GameState.stats.piety, flags piety_last_day / piety_used_day). Events are
## called directly by the triggering system (change / event), never from signal listeners.

const GROUP := &"piety"


func _init() -> void:
	add_to_group(GROUP, true)


func value() -> int:
	return 0


func tier() -> StringName:
	return &"matter_of_fact"


## Clamps, GameState.stats.piety, piety_changed; tier change → quiet notification.
func change(_delta: int, _reason: String) -> void:
	pass


## PietyConfig.events[kind]
func event(_kind: StringName, _reason: String) -> void:
	pass


## Idempotent (flag piety_last_day); returns the applied delta.
func apply_daily(_day: int) -> int:
	return 0


## PietyConfig.gift_by_tier of the current tier.
func gift_coins() -> int:
	return 2


## PietyConfig.buyer_bonus_by_tier of the current tier.
func buyer_bonus() -> int:
	return 0
