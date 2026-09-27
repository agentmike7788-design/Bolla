extends Node
## Boot scene. In Phase 0 it only proves the project starts cleanly.
## Later it will load the title screen / first world scene.


func _ready() -> void:
	print("[Boot] The Last Gravekeeper v%s — debug=%s" % [GameConfig.version, GameConfig.debug_enabled])
	EventBus.game_booted.emit()
