class_name CorpseDeliveryRules
extends RefCounted
## Daily delivery rules (docs §2.5, Phase 3 §2.7), used by CorpseManager: when a delivery is
## due, when it is refused (occupied bier, no free plot, cemetery full), the free biers, its
## arrival minute and the report of a skipped delivery. Stateless – the manager keeps the
## delivery bookkeeping (and calls the reputation event of a missed delivery).

const FLAG_DELIVERY_SKIPPED := &"delivery_skipped"
const STAT_MISSED := &"missed_deliveries"
const MINUTES_PER_DAY := 1440

const REASON_OCCUPIED := "Die Bahre ist noch belegt."
const REASON_NO_PLOT := "Es gibt keine freie Grabstelle."
const REASON_NO_DROPOFF := "Es gibt keine Bahre für die Lieferung."
const NOTE_SKIPPED := "Heute keine Leiche: %s"


## Day (1-based) of the world time `now_total`.
static func day_of(now_total: int) -> int:
	return _div(now_total, MINUTES_PER_DAY) + 1


## The day's delivery minute is reached at world time `now_total` (never without tables).
static func is_due(now_total: int, tables: CorpseTables) -> bool:
	return tables != null and now_total % MINUTES_PER_DAY >= tables.delivery_minute


## The corpse arrived at the day's delivery minute – but never after now.
static func arrival_total(day: int, now_total: int, tables: CorpseTables) -> int:
	return mini(now_total, (day - 1) * MINUTES_PER_DAY + tables.delivery_minute)


## A graveyard exists and no plot is left for a new corpse – and none ever comes back.
## Phase 4 (§2.11): `reserved` plots (pending story corpses, reserved_plots) are not free for it.
static func is_cemetery_full(graveyard: Node, unburied: int, reserved: int = 0) -> bool:
	return graveyard != null and graveyard.has_method("free_plot_count") \
			and int(graveyard.call("free_plot_count")) <= unburied + maxi(0, reserved)


## Phase 4 (§2.11 rule 2): plots a random corpse must leave free for the `pending` story
## corpses – only those no LOCKED plot can still take (a section unlocked later brings them),
## so the reservation bites once the remaining capacity is final (never on day 2 of a new game).
## Only in a world that has plots of the story's section (`story_section`, StoryConfig
## .chapter_section = the Holunderwinkel): without them (Phase-3 world) nothing is reserved.
static func reserved_plots(graveyard: Node, pending: int, story_section: StringName = &"") -> int:
	if pending <= 0 or graveyard == null:
		return 0
	if story_section != &"":
		if not graveyard.has_method("plots_in_section") \
				or (graveyard.call("plots_in_section", story_section) as PackedStringArray).is_empty():
			return 0
	var locked := 0
	if graveyard.has_method("locked_plot_count"):
		locked = int(graveyard.call("locked_plot_count"))
	return maxi(0, pending - locked)


static func free_plot_count(graveyard: Node) -> int:
	if graveyard == null or not graveyard.has_method("free_plot_count"):
		return 0
	return int(graveyard.call("free_plot_count"))


## Why the delivery to `dropoff` is refused ("" = it may happen): no dropoff, an occupied
## bier, or no more free plots than unburied corpses.
static func blocked_reason(dropoff: Node, graveyard: Node, unburied: int, dropoff_group: StringName) -> String:
	if dropoff == null or not dropoff.has_method("is_free"):
		push_warning("[CorpseManager] no dropoff node in group '%s'" % dropoff_group)
		return REASON_NO_DROPOFF
	if not bool(dropoff.call("is_free")):
		return REASON_OCCUPIED
	if free_plot_count(graveyard) <= unburied:
		return REASON_NO_PLOT
	return ""


## World transform of the dropoff's corpse slot (identity without slot_transform).
static func slot_transform(dropoff: Node) -> Transform3D:
	return dropoff.call("slot_transform") if dropoff.has_method("slot_transform") else Transform3D.IDENTITY


## Stat missed_deliveries (+ count corpses), flag delivery_skipped, delivery_skipped + a
## warning notification.
static func report_skip(day: int, reason: String, count: int = 1) -> void:
	GameState.add_stat(STAT_MISSED, maxi(count, 1))
	GameState.set_flag(FLAG_DELIVERY_SKIPPED, day)
	EventBus.delivery_skipped.emit(day, reason)
	EventBus.notification_requested.emit(NOTE_SKIPPED % reason, &"warning")


## The free biers among `dropoffs` (all nodes of group &"dropoff"), in the given order.
static func free_dropoffs(dropoffs: Array[Node]) -> Array[Node]:
	var out: Array[Node] = []
	for dropoff: Node in dropoffs:
		if is_instance_valid(dropoff) and dropoff.has_method("is_free") and bool(dropoff.call("is_free")):
			out.append(dropoff)
	return out


@warning_ignore("integer_division")
static func _div(a: int, b: int) -> int:
	return a / b
