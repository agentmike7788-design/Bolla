class_name ToolAnimConfig
extends Resource
## G7 Runde 2: tools in the gravekeeper's hands (data/config/tool_anim_config.tres). The shovel hangs
## on the rig's "tool" bone: on the back in every clip except the tool clips below. An action clip
## listed in held_tools first plays the tool's draw clip (from the back into the hands), then loops,
## and when the action ends or is cancelled the stow clip puts the tool back (stow_walk_clips while
## walking off). Loading and changing rooms put it back at once (PlayerAnimator.reset_tool).
## G7 Runde 2 (Werkzeuge): the belt tools (axe, pickaxe, hammer, saw – on the same "tool" bone – and
## the chisel on arm_l) live in the tool bag: hidden until their draw clip reaches draw_show_at,
## hidden again when the stow clip reaches stow_hide_at. While one is out the shovel stays on the back
## (PlayerAnimator re-parents it onto the spine). action_clips maps the code-driven actions (stations,
## building, grave markers) to their clip; clearables / gather nodes carry their clip in their data.

## Action clip → tool kind it is played with (the clip itself shows the tool in the hands).
@export var held_tools: Dictionary[StringName, StringName] = {&"dig": &"shovel"}
## Tool kind → one-shot clip taking it from the back into the hands (ends in the first frame of the
## action clip).
@export var draw_clips: Dictionary[StringName, StringName] = {&"shovel": &"shovel_draw"}
## Tool kind → one-shot clip putting it back on the back (starts in the first frame of the action
## clip, ends at rest).
@export var stow_clips: Dictionary[StringName, StringName] = {&"shovel": &"shovel_stow"}
## Tool kind → the same while walking (one walk cycle, ends in walk's first frame).
@export var stow_walk_clips: Dictionary[StringName, StringName] = {&"shovel": &"shovel_stow_walk"}
## Cross-fades (s): draw → action clip, action clip → stow.
@export var hold_blend: float = 0.05
@export var stow_blend: float = 0.15
## Action clip → its own draw → hold cross-fade (s), for a clip the draw clip does not end in
## (the chisel shares the hammer's draw).
@export var hold_blends: Dictionary[StringName, float] = {}
## Action clip → fraction of its cycle where the blade bites (the work sound, AudioEvents.work_beat).
@export var bite_at: Dictionary[StringName, float] = {&"dig": 0.16}
## Action clip → the work cue sounded at the bite (overrides the label keyword cue; dig keeps it).
@export var beat_cues: Dictionary[StringName, StringName] = {}
## Action clip → fraction of its cycle where the earth is thrown (earth clods leave the blade).
@export var toss_at: Dictionary[StringName, float] = {&"dig": 0.78}
## Marker on the tool bone where the clods leave (rig bone marker).
@export var blade_marker: StringName = &"shovel_blade"
## Earth clods: a few painted crumbs per throw, thrown towards the character's left (+X) and forward.
@export var clod_amount: int = 6
@export var clod_lifetime: float = 0.75
@export var clod_size: float = 0.045
@export var clod_speed: float = 2.0
@export var clod_spread_deg: float = 22.0
@export var clod_direction: Vector3 = Vector3(0.75, 0.9, 0.35)
@export var clod_color: Color = Color("#4E3F31")

# --- G7 Runde 2 (Werkzeuge) ---------------------------------------------------------------
## Tool kind → its mesh node(s) in the gravekeeper model (the chisel kind shows hammer and chisel).
@export var tool_meshes: Dictionary[StringName, PackedStringArray] = {&"shovel": PackedStringArray(["Shovel"])}
## Tool kinds that stay visible in their resting place (the shovel on the back); all others are
## hidden in the tool bag while not out.
@export var resting_visible: Array[StringName] = [&"shovel"]
## Draw clip → fraction where the fist reaches the bag and the tool appears.
@export var draw_show_at: Dictionary[StringName, float] = {}
## Stow clip → fraction where the tool is back in the bag and disappears.
@export var stow_hide_at: Dictionary[StringName, float] = {}
## Action clip → (marker, colour) of the chips at the bite: wood chips, stone splinters (sparing).
@export var chip_markers: Dictionary[StringName, StringName] = {}
@export var chip_colors: Dictionary[StringName, Color] = {}
@export var chip_amount: int = 5
@export var chip_lifetime: float = 0.5
@export var chip_size: float = 0.03
@export var chip_speed: float = 1.6
@export var chip_spread_deg: float = 55.0
## Code-driven action → clip (stations: "station_<id>", building, grave markers, stone carving);
## unknown keys keep the caller's own clip (clip_for).
@export var action_clips: Dictionary[StringName, StringName] = {}


## The clip for the code-driven action `key` (tool_anim_config.tres action_clips), else `fallback`.
static func clip_for(key: StringName, fallback: StringName = &"interact") -> StringName:
	var cfg := Database.config(&"tool_anim_config") as ToolAnimConfig
	if cfg == null:
		return fallback
	return cfg.action_clips.get(key, fallback)


# --- G7 Runde 2 (Bestatten): the dead laid into the open grave (PlayerBurial) -----------------
## The burial runs as one timed action with this clip (GravePlot -> Player.start_burial): he steps
## to the long side of the pit (burial_step_clip), lowers the dead onto the pit floor
## (burial_lower_clip), stands a moment in silence (burial_mourn_clip), then draws the shovel and
## fills the grave with burial_throws throws of burial_fill_clip (the earth rises with each throw,
## the last one ends the action: the fresh mound). Only the real seconds of the bar follow this
## sequence (burial_seconds) – the game minutes stay those of ActionConfig / ToolRules.
@export var burial_action_clip: StringName = &"bury"
@export var burial_step_clip: StringName = &"carry_walk"
@export var burial_lower_clip: StringName = &"corpse_lower"
@export var burial_mourn_clip: StringName = &"mourn"
@export var burial_fill_clip: StringName = &"dig"
## Seconds of the step to the pit, of the lowering (= the clip's length) and of the silence (ditto).
@export var burial_step_seconds: float = 0.5
@export var burial_lower_seconds: float = 1.8
@export var burial_silence_seconds: float = 1.0
@export var burial_throws: int = 3
## After the last throw, until the earth has landed and the mound replaces the pit (s).
@export var burial_tail_seconds: float = 0.35
## Where he stands (plot-local, the pit's long side first; +Z = foot end), facing the pit's centre
## line. The first spot free of world bodies wins; none free: he stays where he is.
@export var burial_stands: Array[Vector3] = [Vector3(-1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.45),
		Vector3(-1.0, 0.0, -0.45), Vector3(0.0, 0.0, 1.62)]
## The corpse on the pit floor (plot-local; the corpse models lie along their local X with the head
## at +X, so yaw 90° puts the head at the marker end, -Z). Inside the pit's floor ring
## (half 0.38 x 0.82 m; walls from half 0.47 x 0.97 m) – the corpse is 0.58 m wide, 1.74 m long.
@export var burial_corpse_offset: Vector3 = Vector3(-0.05, 0.035, 0.0)
@export var burial_corpse_yaw_deg: float = 90.0
## Fractions of the lowering: the corpse reaches burial_hover_height above the floor in his hands
## (release_at), then sinks onto the floor (touch_at, burial_down_cue sounds).
@export var burial_hover_height: float = 0.5
@export var burial_release_at: float = 0.58
@export var burial_touch_at: float = 0.86
@export var burial_down_cue: StringName = &"corpse_down"
## After throw n (1 … burial_throws - 1): the fresh mound rises in the pit to burial_fill_scales[n-1]
## of its height while the corpse settles burial_sink[n-1] m into the floor (the earth covers it).
@export var burial_fill_scales: PackedFloat32Array = [0.34, 0.66]
@export var burial_sink: PackedFloat32Array = [0.08, 0.17]
## How fast the earth rises after a throw / the corpse goes back into the arms on a cancel (1/s).
@export var burial_fill_rate: float = 6.0
@export var burial_return_rate: float = 9.0
## The clods of a filling throw go forward into the pit (player-local, he faces +Z).
@export var burial_clod_direction: Vector3 = Vector3(0.2, 0.85, 0.9)


## Real seconds of the burial sequence with `anim`'s clip lengths (-1 = no rig: the usual bar).
func burial_seconds(anim: AnimationPlayer) -> float:
	var fill := burial_fill_clip
	var draw: StringName = draw_clips.get(held_tools.get(fill, &""), &"")
	if anim == null or not anim.has_animation(fill) or not anim.has_animation(draw):
		return -1.0
	var cycle := anim.get_animation(fill).length
	var toss := float(toss_at.get(fill, 1.0))
	var fixed := burial_step_seconds + burial_lower_seconds + burial_silence_seconds + anim.get_animation(draw).length
	return fixed + (maxi(burial_throws, 1) - 1 + toss) * cycle + burial_tail_seconds
