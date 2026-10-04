class_name AudioEventMap
extends Resource
## Which sound answers which game event (data/audio/audio_events.tres). Audio only listens –
## it never changes game state.

## EventBus signal → cue. Key "signal" plays on every emit; "signal@<arg index>=<value>" only
## when str(argument) == value, conditions chain ("workshop_job_changed@0=forge@2=started"); the
## key with most conditions wins, the plain key is the fallback. Several cues: "a,b" (together).
@export var signal_cues: Dictionary[String, String] = {}
## Timed actions (EventBus.timed_action_started label): the first keyword contained in the label
## (case-insensitive, in this order) picks the repeating work cue …
@export var action_keywords: Dictionary[String, StringName] = {}
## … else the player's action animation does (&"dig" → &"dig"); &"" = silent.
@export var action_animation_cues: Dictionary[StringName, StringName] = {}
## Seconds between two plays of a work cue while the action runs (default work_interval).
@export var work_intervals: Dictionary[StringName, float] = {}
@export var work_interval: float = 0.9
## UI panel opened / closed (UIPanel.panel_id) → cue; missing ids use panel_open / panel_close.
@export var panel_open_cues: Dictionary[StringName, StringName] = {}
@export var panel_close_cues: Dictionary[StringName, StringName] = {}
@export var panel_open: StringName = &"ui_open"
@export var panel_close: StringName = &"ui_close"
## Buttons: pressed / hovered; inside these panels a press turns a page instead.
@export var button_press: StringName = &"ui_click"
@export var button_hover: StringName = &"ui_hover"
@export var page_panels: Array[StringName] = [&"journal", &"grave_register"]
@export var page_cue: StringName = &"ui_page"
## The gravekeeper's hands: picked up / put down (corpse = carried node in group "corpse").
@export var pickup_cue: StringName = &"pickup"
@export var putdown_cue: StringName = &"putdown"
@export var corpse_pickup_cue: StringName = &"cloth"
@export var corpse_putdown_cue: StringName = &"corpse_down"
## MorgueTable.sound_hook cues (AnatomyConfig.sound_cue) that map to another cue id.
@export var hook_aliases: Dictionary[StringName, StringName] = {}
