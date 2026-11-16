extends Node


var save_icons: Array[Image]
var save_path: String
signal settings_changed(value)
var settings := {
	"fullscreen": false,
	"quality": Preset.MEDIUM,
}:
	set(value):
		settings = value
		settings_changed.emit()
enum Preset { LOW, MEDIUM, HIGH }
func save_capture() -> void:
	for i in save_icons:
		i.save_png("user://save_icon.png")
