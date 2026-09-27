class_name Bed
extends Node3D
## The gravekeeper's bed in the hut interior (docs §11, logic of the former HutDoor).
## Rest until evening / sleep until morning (+ day summary and autosave in slot 0).
## Times come from TimeConfig: "rest" from wake_minute until rest_until_minute, "sleep" from
## sleep_from_minute (or after midnight before wake_minute).
## Day summary ("today" = since the last sleep or the new game): the baselines are GameState
## flags day_burials_base / day_coins_base, written on every sleep (missing = new game: 0
## burials, the start coins). coins_today is the net change of the player's coins.

const MODE_REST := &"rest"
const MODE_SLEEP := &"sleep"
const SUMMARY_PANEL := &"day_summary"
const STAT_DAYS := &"days_played"
const STAT_BURIALS := &"burials"
const FLAG_BURIALS_BASE := &"day_burials_base"
const FLAG_COINS_BASE := &"day_coins_base"
const COIN_ITEM := &"coin"
const GRAVEYARD_GROUP := &"graveyard"
const MINUTES_PER_HOUR := 60

const PROMPT_REST := "[E] Ausruhen bis %s"
const PROMPT_SLEEP := "[E] Schlafen bis %s"
const TEXT_RESTED := "Du ruhst dich bis %s aus."
const TEXT_AUTOSAVED := "Automatisch gespeichert."
const TEXT_AUTOSAVE_FAILED := "Automatisches Speichern fehlgeschlagen."

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


## &"rest", &"sleep" or &"" (nothing offered right now).
func mode() -> StringName:
	var cfg := TimeManager.config
	var minute := TimeManager.minute_of_day
	if minute >= cfg.sleep_from_minute or minute < cfg.wake_minute:
		return MODE_SLEEP
	if minute < cfg.rest_until_minute:
		return MODE_REST
	return &""


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and not _is_carrying(player) and mode() != &""


func get_interaction_prompt(player: Player) -> String:
	var current := mode()
	if current == &"":
		return ""
	if player != null and _is_carrying(player):
		return Player.TEXT_HANDS_FULL
	var cfg := TimeManager.config
	if current == MODE_REST:
		return PROMPT_REST % _clock(cfg.rest_until_minute)
	return PROMPT_SLEEP % _clock(cfg.wake_minute)


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	if mode() == MODE_REST:
		rest()
	else:
		sleep(player)


## Skips to rest_until_minute (deliveries and decay run through the time signals).
func rest() -> void:
	var target := TimeManager.config.rest_until_minute
	TimeManager.advance(TimeManager.minutes_until(target))
	EventBus.notification_requested.emit(TEXT_RESTED % _clock(target), &"info")


## Skips to the next wake_minute, counts the day, shows the day summary, autosaves (slot 0).
func sleep(player: Player) -> void:
	var cfg := TimeManager.config
	var ended_day := TimeManager.day if TimeManager.minute_of_day >= cfg.wake_minute else maxi(TimeManager.day - 1, 1)
	TimeManager.advance(TimeManager.minutes_until(cfg.wake_minute))
	GameState.add_stat(STAT_DAYS, 1)
	var summary := day_summary(player)
	summary["day"] = ended_day
	GameState.set_flag(FLAG_BURIALS_BASE, GameState.get_stat(STAT_BURIALS))
	GameState.set_flag(FLAG_COINS_BASE, _coins(player))
	EventBus.ui_panel_requested.emit(SUMMARY_PANEL, summary)
	if SaveManager.save_game(SaveManager.AUTOSAVE_SLOT) == OK:
		EventBus.notification_requested.emit(TEXT_AUTOSAVED, &"info")
	else:
		EventBus.notification_requested.emit(TEXT_AUTOSAVE_FAILED, &"warning")


## {day, burials_today, coins_today, total, rating} relative to the last sleep.
func day_summary(player: Player) -> Dictionary:
	var graveyard := get_tree().get_first_node_in_group(GRAVEYARD_GROUP) as Graveyard if is_inside_tree() else null
	var total := graveyard.total_quality() if graveyard != null else 0
	var burials_base: Variant = GameState.get_flag(FLAG_BURIALS_BASE, 0)
	var coins_base: Variant = GameState.get_flag(FLAG_COINS_BASE, _start_coins(player))
	return {
		"day": TimeManager.day,
		"burials_today": GameState.get_stat(STAT_BURIALS) - int(burials_base),
		"coins_today": _coins(player) - int(coins_base),
		"total": total,
		"rating": graveyard.rating() if graveyard != null else CemeteryRating.NEGLECTED,
	}


static func _coins(player: Player) -> int:
	return player.inventory.count(COIN_ITEM) if player != null else 0


static func _start_coins(player: Player) -> int:
	if player == null or player.config == null:
		return 0
	return int(player.config.start_items.get(COIN_ITEM, 0))


@warning_ignore("integer_division")
static func _clock(minute: int) -> String:
	return "%02d:%02d" % [minute / MINUTES_PER_HOUR, minute % MINUTES_PER_HOUR]


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)
