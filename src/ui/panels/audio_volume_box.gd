class_name AudioVolumeBox
extends VBoxContainer
## Volume sliders (pause menu „Ton …"): one row per bus, 0–100 %, written straight to Audio and
## saved in the user settings file (Audio.set_volume) – never in the save game.

const TEXT_ROW := "%s"
const TEXT_PERCENT := "%d %%"
## Bus → shown name, in this order.
const ROWS: Array[Array] = [
	[&"Master", "Gesamt"],
	[&"Music", "Musik"],
	[&"Ambience", "Atmosphäre"],
	[&"SFX", "Geräusche"],
	[&"UI", "Oberfläche"],
]
const STEP := 5.0

## bus -> HSlider
var sliders: Dictionary[StringName, HSlider] = {}
var _values: Dictionary[StringName, Label] = {}


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	for row: Array in ROWS:
		var bus: StringName = row[0]
		var line := UIKit.hbox(12)
		var name_label := UIKit.label(TEXT_ROW % row[1])
		name_label.custom_minimum_size.x = 150.0
		line.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = STEP
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 220.0
		slider.focus_mode = Control.FOCUS_ALL
		line.add_child(slider)
		var value := UIKit.label("", &"DimLabel")
		value.custom_minimum_size.x = 60.0
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value)
		add_child(line)
		sliders[bus] = slider
		_values[bus] = value
		slider.value_changed.connect(_on_changed.bind(bus))


## Shows the current volumes (without writing them back).
func refresh() -> void:
	for bus: StringName in sliders:
		var v := roundf(Audio.get_volume(bus) * 100.0)
		sliders[bus].set_value_no_signal(v)
		_values[bus].text = TEXT_PERCENT % int(v)


func _on_changed(value: float, bus: StringName) -> void:
	_values[bus].text = TEXT_PERCENT % int(value)
	Audio.set_volume(bus, value / 100.0)
