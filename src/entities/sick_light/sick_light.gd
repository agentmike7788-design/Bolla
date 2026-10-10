class_name SickLight
extends Node3D
## The sick light in a window (docs/PHASE8_DESIGN.md §1.6, §3.1, §3.4, §4.6 D3, §4.9): at the marker
## light_window of house_ott / house_kehr; the existing window light stays on all night and a candle (emissive
## material, no new light) stands in the window while NightPaths.sick_houses has the house. Pure display, no
## interaction; refreshed every game minute (cheap: one lookup).

const NIGHT_PATHS_GROUP := &"night_paths"
const CANDLE_NAME := "Candle"
const CANDLE_PATH := "res://assets/models/props/ph_prop_grave_candle.glb"
const FLAME_COLOR := Color("#F2A93B")

@export var house: StringName = &""

var _candle: Node3D


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.game_loaded.connect(_on_loaded)
	refresh()


## Candle on ⇔ the house is in NightPaths.sick_houses(now).
func refresh() -> void:
	var on := burning()
	if on and _candle == null:
		_candle = _make_candle()
		_candle.name = CANDLE_NAME
		add_child(_candle)
	if _candle != null:
		_candle.visible = on


## The sick light burns now.
func burning() -> bool:
	var paths := get_tree().get_first_node_in_group(NIGHT_PATHS_GROUP) as NightPaths if is_inside_tree() else null
	return paths != null and paths.sick_houses(TimeManager.day, TimeManager.minute_of_day).has(String(house))


func _make_candle() -> Node3D:
	if ResourceLoader.exists(CANDLE_PATH):
		return (load(CANDLE_PATH) as PackedScene).instantiate() as Node3D
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.025
	m.bottom_radius = 0.03
	m.height = 0.14
	m.radial_segments = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#E8DFC8")
	m.material = mat
	mi.mesh = m
	mi.position = Vector3(0, 0.07, 0)
	root.add_child(mi)
	var flame := MeshInstance3D.new()
	var f := SphereMesh.new()
	f.radius = 0.02
	f.height = 0.05
	var fm := StandardMaterial3D.new()
	fm.albedo_color = FLAME_COLOR
	fm.emission_enabled = true
	fm.emission = FLAME_COLOR
	fm.emission_energy_multiplier = 2.0
	f.material = fm
	flame.mesh = f
	flame.position = Vector3(0, 0.17, 0)
	root.add_child(flame)
	return root


func _on_time_tick(_day: int, _minute: int) -> void:
	refresh()


func _on_loaded(_slot: int) -> void:
	refresh()
