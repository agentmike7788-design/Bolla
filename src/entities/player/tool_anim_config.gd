class_name ToolAnimConfig
extends Resource
## G7 Runde 2: tools in the gravekeeper's hands (data/config/tool_anim_config.tres). The shovel hangs
## on the rig's "tool" bone: on the back in every clip except the tool clips below. An action clip
## listed in held_tools first plays the tool's draw clip (from the back into the hands), then loops,
## and when the action ends or is cancelled the stow clip puts the tool back (stow_walk_clips while
## walking off). Loading and changing rooms put it back at once (PlayerAnimator.reset_tool).

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
## Action clip → fraction of its cycle where the blade bites (the work sound, AudioEvents.work_beat).
@export var bite_at: Dictionary[StringName, float] = {&"dig": 0.16}
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
