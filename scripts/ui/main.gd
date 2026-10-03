extends Control
## Root scene: owns the active screen and swaps screens on Game.goto().

const SCREENS := {
	"menu": preload("res://scripts/ui/screens/main_menu.gd"),
	"team_creation": preload("res://scripts/ui/screens/team_creation.gd"),
	"hub": preload("res://scripts/ui/screens/career_hub.gd"),
	"race": preload("res://scripts/ui/screens/race_screen.gd"),
	"results": preload("res://scripts/ui/screens/race_results.gd"),
	"library": preload("res://scripts/ui/screens/track_library.gd"),
	"custom_race": preload("res://scripts/ui/screens/custom_race.gd"),
	"editor": preload("res://scripts/ui/screens/track_editor.gd"),
	"settings": preload("res://scripts/ui/screens/settings_screen.gd"),
}

var current: Control
var debug_panel: Control


func _ready() -> void:
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	Game.screen_requested.connect(_on_screen_requested)
	Game.apply_settings()
	Game.goto("menu")


func _on_screen_requested(screen: String, params: Dictionary) -> void:
	if current:
		remove_child(current)
		current.queue_free()
	var s: Control = SCREENS[screen].new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.name = screen
	add_child(s)
	if debug_panel:
		move_child(debug_panel, -1)
	current = s
	if s.has_method("open"):
		s.open(params)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		toggle_debug()


func toggle_debug() -> void:
	if debug_panel:
		debug_panel.queue_free()
		debug_panel = null
		return
	debug_panel = preload("res://scripts/ui/debug_panel.gd").new()
	add_child(debug_panel)
