extends Node
## Boot scene: prints version info, then hands over to the start scene.

## Title screen (Fortsetzen / Neues Spiel / Beenden).
@export_file("*.tscn") var start_scene: String = "res://src/ui/title/title_screen.tscn"


func _ready() -> void:
	print("[Boot] The Last Gravekeeper v%s — debug=%s" % [GameConfig.version, GameConfig.debug_enabled])
	EventBus.game_booted.emit()
	if start_scene != "":
		get_tree().change_scene_to_file.call_deferred(start_scene)
