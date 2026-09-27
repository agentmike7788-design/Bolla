extends Node
## Build-wide configuration flags. Gameplay balancing values do NOT live here;
## they belong in Resource files under res://data/.

var version: String = ProjectSettings.get_setting("application/config/version", "dev")

## Debug tools are available in debug builds only. Release exports have
## OS.is_debug_build() == false, which disables them automatically.
var debug_enabled: bool = OS.is_debug_build()


func set_debug_enabled(value: bool) -> void:
	if not OS.is_debug_build():
		return
	debug_enabled = value
	EventBus.debug_mode_changed.emit(value)
