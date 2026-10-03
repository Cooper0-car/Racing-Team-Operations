extends Control
## Settings window. Every option is applied immediately and stored in user://settings.json.

const SECTIONS := [["general", "General"], ["display", "Display"], ["audio", "Audio"], ["race", "Race"], ["controls", "Controls"]]

var back := "menu"
var back_params: Dictionary = {}
var section := "general"
var content: VBoxContainer
var nav_buttons := {}


func open(params: Dictionary) -> void:
	back = params.get("back", "menu")
	back_params = params.get("back_params", {})
	section = params.get("section", "general")
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := UI.vbox(14)
	margin.add_child(root)
	var head := UI.hbox()
	head.add_child(UI.title("Settings", 26))
	head.add_child(UI.spacer())
	head.add_child(UI.button(tr("Reset to defaults"), _reset))
	head.add_child(UI.accent_button(tr("Done"), _done, 140))
	root.add_child(head)
	var body := UI.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var nav := UI.vbox(4)
	var np := UI.panel(nav, UI.PANEL, 10)
	np.custom_minimum_size.x = 220
	body.add_child(np)
	for s in SECTIONS:
		var b := UI.button(tr(s[1]), _show.bind(s[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav.add_child(b)
		nav_buttons[s[0]] = b
	content = UI.vbox(12)
	var cp := UI.panel(UI.scroll(content), UI.PANEL, 20)
	UI.expand(cp, true, true)
	body.add_child(cp)
	_show(section)


func _show(id: String) -> void:
	section = id
	Game.current_params["section"] = id
	for k in nav_buttons:
		var b: Button = nav_buttons[k]
		if k == id:
			b.add_theme_stylebox_override("normal", UI._box(UI.ACCENT.darkened(0.35), UI.ACCENT, 1, 4, 8, 6))
		else:
			b.remove_theme_stylebox_override("normal")
	UI.clear(content)
	call("_section_" + id)


func _row(name: String, ctrl: Control, hint: String = "") -> void:
	var v := UI.vbox(2)
	var h := UI.hbox(12)
	var l := UI.label(tr(name), 15)
	l.custom_minimum_size.x = 260
	h.add_child(l)
	ctrl.custom_minimum_size.x = maxf(ctrl.custom_minimum_size.x, 260)
	h.add_child(ctrl)
	h.add_child(UI.spacer())
	v.add_child(h)
	if hint != "":
		var n := UI.note(tr(hint), 12)
		n.custom_minimum_size.x = 520
		v.add_child(n)
	content.add_child(v)


func _choice(key: String, options: Array, labels: Array) -> OptionButton:
	var cur := options.find(Game.settings.get(key))
	return UI.option(labels, maxi(cur, 0), func(i): Game.set_setting(key, options[i]))


func _toggle(key: String) -> CheckButton:
	return UI.check(tr("On"), bool(Game.settings.get(key, false)), func(on): Game.set_setting(key, on))


func _volume(key: String) -> HBoxContainer:
	var h := UI.hbox(8)
	var lbl := UI.label("%d%%" % int(float(Game.settings.get(key, 0.8)) * 100.0), 14)
	lbl.custom_minimum_size.x = 50
	var on_change := func(v: float) -> void:
		Game.settings[key] = v
		Game.apply_settings()
		lbl.text = "%d%%" % int(v * 100.0)
	var sl := UI.slider(0.0, 1.0, 0.05, float(Game.settings.get(key, 0.8)), on_change, 220)
	sl.drag_ended.connect(func(_c): Game.save_settings(); Sfx.play("click"))
	h.add_child(sl)
	h.add_child(lbl)
	return h


# ---------------------------------------------------------------- sections

func _section_general() -> void:
	content.add_child(UI.title("General", 20))
	var langs := Game.LANGUAGES.keys()
	_row("Language", UI.option(langs.map(func(k): return Game.LANGUAGES[k]), maxi(langs.find(Game.settings["language"]), 0),
		func(i): Game.set_setting("language", langs[i])), "Changes all menus immediately.")
	_row("Units", _choice("units", ["metric", "imperial"], ["Metric (km, km/h, m)", "Imperial (mi, mph, ft)"]))
	_row("Autosave", _toggle("autosave"), "Saves the career after every race and when returning to the main menu.")
	_row("UI sounds", _toggle("ui_sounds"))


func _section_display() -> void:
	content.add_child(UI.title("Display", 20))
	_row("Window mode", _choice("window_mode", ["windowed", "maximized", "fullscreen"], ["Windowed", "Maximized", "Fullscreen"]))
	_row("UI scale", _choice("ui_scale", [0.85, 1.0, 1.15, 1.3], ["85%", "100%", "115%", "130%"]), "Makes all text and panels larger or smaller.")
	_row("Graphics quality", _choice("graphics", ["low", "medium", "high"], ["Low", "Medium", "High"]),
		"High: smooth anti-aliased track edges and full detail. Medium: full detail. Low: fastest, track surface only.")
	_row("V-Sync", _toggle("vsync"), "Limits the frame rate to the monitor refresh rate.")


func _section_audio() -> void:
	content.add_child(UI.title("Audio", 20))
	_row("Master volume", _volume("master_volume"))
	_row("Effects volume", _volume("sfx_volume"), "Button clicks, start lights and the chequered flag.")
	var test := UI.button(tr("Play test sound"), func(): Sfx.play("flag"))
	_row("Test", test)
	content.add_child(UI.note(tr("Music and engine sounds are planned for the polish phase.")))


func _section_race() -> void:
	content.add_child(UI.title("Race", 20))
	_row("Default race speed", _choice("default_race_speed", [1, 2, 4, 8], ["1x", "2x", "4x", "8x"]))
	_row("Default camera", _choice("race_camera", ["track", "player"], ["Whole track", "Follow my lead driver"]))
	_row("Radio & race control messages", _choice("radio", ["all", "important", "player"], ["All messages", "Important only", "My team only"]))
	_row("Show racing line in races", _toggle("show_racing_line"))
	_row("Simulation detail", _choice("sim_detail", ["standard", "high"], ["Standard (30 steps/s)", "High (60 steps/s)"]),
		"High is more precise in traffic but uses more CPU when fast-forwarding.")


func _section_controls() -> void:
	content.add_child(UI.title("Controls", 20))
	var rows := [
		["Space", "Pause / resume race"], ["1 / 2 / 3 / 4", "Race speed 1x / 2x / 4x / 8x"],
		["Mouse wheel", "Zoom (at the cursor)"], ["Drag", "Pan the track view"], ["F12", "Developer / debug menu"],
		["V D A X", "Editor: select, draw, add point, delete point"], ["S 2 3", "Editor: start line, sector 2, sector 3"],
		["Z P", "Editor: DRS zone, pit lane"], ["F", "Editor: fit view"], ["Ctrl+Z / Ctrl+Y", "Editor: undo / redo"],
		["Ctrl+S", "Editor: save"], ["Delete / Esc", "Editor: delete selected point / deselect"],
	]
	var trows := []
	for r in rows:
		trows.append([r[0], tr(r[1])])
	content.add_child(UI.table([tr("Key"), tr("Action")], trows, [200, 0]))


func _reset() -> void:
	var lang: String = Game.settings["language"]
	for k in ["units", "autosave", "default_race_speed", "race_camera", "radio", "show_racing_line", "sim_detail",
			"ui_scale", "window_mode", "vsync", "graphics", "master_volume", "sfx_volume", "ui_sounds"]:
		Game.settings[k] = {"units": "metric", "autosave": true, "default_race_speed": 2, "race_camera": "track", "radio": "all",
			"show_racing_line": false, "sim_detail": "standard", "ui_scale": 1.0, "window_mode": "windowed", "vsync": true,
			"graphics": "high", "master_volume": 0.8, "sfx_volume": 0.8, "ui_sounds": true}[k]
	Game.settings["language"] = lang
	Game.save_settings()
	Game.reload_screen()


func _done() -> void:
	Game.goto(back, back_params)
