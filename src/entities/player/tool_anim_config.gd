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
## Burying while carrying: the corpse is laid down beside him (CarrySocket, player-local; he faces
## +Z, his right is -X) while the shovel is out, and taken up again when it is stowed.
@export var carry_aside_position: Vector3 = Vector3(-0.85, 0.0, 0.35)
@export var carry_aside_yaw_deg: float = 90.0
## How fast the socket moves there and back (1/s, exponential).
@export var carry_aside_rate: float = 9.0

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
