extends Node
## Global signal hub (docs/VERTICAL_SLICE_DESIGN.md §3.3).
## Signals are notifications only: listeners never change game state (inventory,
## stats, records) in response – the emitting system has already done that.
@warning_ignore_start("unused_signal")

signal game_booted
signal debug_mode_changed(enabled: bool)

# Time (TimeManager)
signal time_tick(day: int, minute_of_day: int)
signal hour_changed(day: int, hour: int)
signal day_started(day: int)
signal time_skipped(from_total: int, to_total: int)

# Game flow
signal new_game_started
signal world_ready(world: Node)
signal notification_requested(text: String, kind: StringName)
signal interaction_focus_changed(prompt: String, enabled: bool)
signal timed_action_started(label: String, duration_sec: float)
signal timed_action_progress(ratio: float)
signal timed_action_finished(completed: bool)

# Corpses & graves (CorpseManager, Graveyard)
signal corpse_arrived(corpse_id: String)
signal corpse_updated(corpse_id: String)
signal corpse_buried(corpse_id: String, grave_id: String)
signal grave_state_changed(grave_id: String, state: int)
signal grave_completed(grave_id: String, corpse_id: String, quality: int, breakdown: Array)
signal cemetery_quality_changed(total: int, rating: StringName)
signal payment_received(amount: int, reason: String)
signal delivery_skipped(day: int, reason: String)
signal slice_completed

# UI
signal ui_panel_requested(panel: StringName, context: Dictionary)
signal ui_modal_changed(open: bool)

# Dialogue
signal dialogue_requested(dialogue_id: StringName, speaker: Node)
signal dialogue_ended(dialogue_id: StringName)

# Save
signal game_saved(slot: int)
signal game_loaded(slot: int)
