extends Node
## Global game controller: current career, settings, localisation and screen navigation.

signal screen_requested(screen: String, params: Dictionary)
signal career_changed
signal settings_changed

const SETTINGS_PATH := "user://settings.json"
const SETTINGS_VERSION := 2
const LANGUAGES := {"ko": "한국어", "en": "English"}
const I18N_DIR := "res://data/i18n/"

var career: Career = null
var settings := {
	"settings_version": SETTINGS_VERSION,
	"language": "ko",
	"units": "metric",
	"autosave": true,
	"default_race_speed": 2,
	"race_camera": "track",
	"radio": "all",
	"show_racing_line": false,
	"sim_detail": "standard",
	"ui_scale": 1.0,
	"window_mode": "windowed",
	"vsync": true,
	"graphics": "high",
	"master_volume": 0.8,
	"sfx_volume": 0.8,
	"ui_sounds": true,
}
var debug_enabled := false
var current_screen := ""
var current_params: Dictionary = {}


func _ready() -> void:
	_load_translations()
	load_settings()
	apply_settings()


func goto(screen: String, params: Dictionary = {}) -> void:
	current_screen = screen
	current_params = params
	screen_requested.emit(screen, params)


## Rebuilds the current screen (after a language or units change).
func reload_screen() -> void:
	if current_screen != "":
		screen_requested.emit(current_screen, current_params)


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


# ---------------------------------------------------------------- settings

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in parsed:
		if settings.has(k):
			settings[k] = parsed[k]
	settings["default_race_speed"] = int(settings["default_race_speed"])
	settings["ui_scale"] = float(settings["ui_scale"])
	# v1 settings files stored "en" as the default language; Korean is the default from v2
	if int(parsed.get("settings_version", 1)) < SETTINGS_VERSION:
		settings["language"] = "ko"
		settings["settings_version"] = SETTINGS_VERSION


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "  "))
	apply_settings()


func set_setting(key: String, value) -> void:
	var old = settings.get(key)
	settings[key] = value
	save_settings()
	if key in ["language", "units"] and old != value:
		reload_screen()
	settings_changed.emit()


func apply_settings() -> void:
	TranslationServer.set_locale(str(settings.get("language", "ko")))
	var tree := get_tree()
	if tree and tree.root:
		tree.root.content_scale_factor = float(settings.get("ui_scale", 1.0))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.get("vsync", true) else DisplayServer.VSYNC_DISABLED)
		var wm := DisplayServer.WINDOW_MODE_WINDOWED
		match str(settings.get("window_mode", "windowed")):
			"maximized": wm = DisplayServer.WINDOW_MODE_MAXIMIZED
			"fullscreen": wm = DisplayServer.WINDOW_MODE_FULLSCREEN
		if DisplayServer.window_get_mode() != wm:
			DisplayServer.window_set_mode(wm)
	_set_bus_volume("Master", float(settings.get("master_volume", 0.8)))
	_set_bus_volume("SFX", float(settings.get("sfx_volume", 0.8)))


func _set_bus_volume(bus_name: String, v: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(bus, v <= 0.001)


func sim_dt() -> float:
	return 1.0 / 60.0 if settings.get("sim_detail", "standard") == "high" else 1.0 / 30.0


func imperial() -> bool:
	return settings.get("units", "metric") == "imperial"


# ---------------------------------------------------------------- localisation

## Translations are plain JSON (English source text -> translation), loaded at runtime.
func _load_translations() -> void:
	var dir := DirAccess.open(I18N_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var file := FileAccess.open(I18N_DIR + f, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("Invalid translation file " + f)
			continue
		var t := Translation.new()
		t.locale = f.get_basename()
		for k in parsed:
			if k.begins_with("_"):
				continue
			t.add_message(k, str(parsed[k]))
		TranslationServer.add_translation(t)
