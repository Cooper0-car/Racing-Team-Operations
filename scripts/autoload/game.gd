extends Node
## Global game controller: current career, settings, and screen navigation.

signal screen_requested(screen: String, params: Dictionary)
signal career_changed

const SETTINGS_PATH := "user://settings.json"

var career: Career = null
var settings := {
	"autosave": true,
	"default_race_speed": 2,
	"ui_scale": 1.0,
	"master_volume": 0.8,
	"units": "metric",
	"language": "en",
}
var debug_enabled := false


func _ready() -> void:
	load_settings()


func goto(screen: String, params: Dictionary = {}) -> void:
	screen_requested.emit(screen, params)


func start_career(setup: Dictionary) -> void:
	career = Career.create(setup)
	career_changed.emit()
	autosave()


func load_career(slot: String) -> bool:
	var c := SaveSystem.load_career(slot)
	if c == null:
		return false
	career = c
	career_changed.emit()
	return true


func autosave() -> void:
	if career and settings.get("autosave", true):
		SaveSystem.save_career(career, "autosave")


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in parsed:
			settings[k] = parsed[k]
	apply_settings()


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "  "))
	apply_settings()


func apply_settings() -> void:
	var tree := get_tree()
	if tree and tree.root:
		tree.root.content_scale_factor = float(settings.get("ui_scale", 1.0))
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(settings.get("master_volume", 0.8)), 0.0001)))
