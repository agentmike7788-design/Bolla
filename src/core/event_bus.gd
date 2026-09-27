extends Node
## Global signal hub. Systems communicate through these signals instead of
## holding direct references to each other. Add signals here only when two or
## more independent systems need them.

signal game_booted
signal debug_mode_changed(enabled: bool)
