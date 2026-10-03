extends Control
## Main menu: New Career, Continue, Load, Track Library, Custom Race, Settings, Exit.

var side: VBoxContainer
var bg_track: TrackView


func open(_params: Dictionary) -> void:
	# animated background: an AI race on a random built-in track
	bg_track = TrackView.new()
	bg_track.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_track.modulate = Color(1, 1, 1, 0.35)
	bg_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_track.show_labels = false
	add_child(bg_track)
	_start_bg_race()

	var root := UI.hbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var left := UI.vbox(10)
	left.custom_minimum_size.x = 420
	var lp := UI.panel(left, Color(UI.PANEL, 0.92), 36)
	root.add_child(lp)
	left.add_child(UI.label("RACING TEAM", 40, UI.TEXT, true))
	left.add_child(UI.label("OPERATIONS", 40, UI.ACCENT, true))
	left.add_child(UI.muted("Team management  ·  Car development  ·  Custom tracks", 14))
	left.add_child(UI.spacer(false))

	var latest := SaveSystem.latest_slot()
	var cont := UI.accent_button("Continue", func(): _load(latest), 340)
	cont.disabled = latest == ""
	if latest != "":
		var info := SaveSystem.slot_info(latest)
		cont.tooltip_text = "%s — Season %d, Round %d" % [info.get("team_name", "?"), int(info.get("season", 1)), int(info.get("round", 0)) + 1]
	left.add_child(cont)
	left.add_child(UI.button("New Career", func(): Game.goto("team_creation"), 340))
	left.add_child(UI.button("Load Career", _show_load, 340))
	left.add_child(UI.button("Custom Race", func(): Game.goto("custom_race"), 340))
	left.add_child(UI.button("Track Library", func(): Game.goto("library"), 340))
	var tc := UI.button("Track Creator  (Phase 4)", func(): pass, 340)
	tc.disabled = true
	tc.tooltip_text = "The track editor is the next development phase."
	left.add_child(tc)
	left.add_child(UI.button("Settings", _show_settings, 340))
	left.add_child(UI.button("Exit", func(): get_tree().quit(), 340))
	left.add_child(UI.spacer(false))
	left.add_child(UI.muted("v0.1  ·  Phase 1: playable core  ·  F12 = debug menu", 12))

	side = UI.vbox(10)
	side.custom_minimum_size.x = 460
	var holder := UI.vbox(0)
	holder.add_child(UI.spacer(false))
	holder.add_child(side)
	holder.add_child(UI.spacer(false))
	root.add_child(UI.spacer())
	root.add_child(holder)
	root.add_child(UI.spacer())


func _start_bg_race() -> void:
	var ids := DataDB.tracks.keys()
	if ids.is_empty():
		return
	var track := TrackData.load_id(ids[randi() % ids.size()])
	var c := Career.create({"name": "-", "abbr": "-", "driver_ids": []})
	var sim := RaceSimulation.new()
	var grid := c.entries()
	grid.shuffle()
	sim.setup(track, grid, 99, randi(), "")
	sim.time = 0.0
	bg_track.set_track(track)
	bg_track.sim = sim


func _process(delta: float) -> void:
	if bg_track and bg_track.sim:
		bg_track.sim.advance(delta * 2.0)


func _load(slot: String) -> void:
	if Game.load_career(slot):
		Game.goto("hub")
	else:
		UI.toast(self, "Could not load save '%s'." % slot, UI.BAD)


func _show_load() -> void:
	UI.clear(side)
	var cv: Array = UI.card("Load Career")
	side.add_child(cv[0])
	var any := false
	for slot in SaveSystem.SLOTS:
		var info := SaveSystem.slot_info(slot)
		if info.is_empty():
			continue
		any = true
		var row := UI.hbox(8)
		var txt := "%s  —  %s\nSeason %d · Round %d · %s · %s" % [slot.to_upper(), info.get("team_name", "?"), int(info.get("season", 1)), int(info.get("round", 0)) + 1, Fmt.money(int(info.get("balance", 0))), info.get("saved_at", "")]
		var l := UI.label(txt, 13)
		UI.expand(l)
		row.add_child(l)
		row.add_child(UI.button("Load", _load.bind(slot)))
		row.add_child(UI.button("Delete", func(): SaveSystem.delete_slot(slot); _show_load()))
		cv[1].add_child(row)
	if not any:
		cv[1].add_child(UI.muted("No saved careers yet."))


func _show_settings() -> void:
	UI.clear(side)
	var cv: Array = UI.card("Settings")
	side.add_child(cv[0])
	var v: VBoxContainer = cv[1]
	var auto := CheckButton.new()
	auto.text = "Autosave after every race"
	auto.button_pressed = bool(Game.settings.get("autosave", true))
	auto.toggled.connect(func(on): Game.settings["autosave"] = on; Game.save_settings())
	v.add_child(auto)
	var speeds := [1, 2, 4, 8]
	var cur := speeds.find(int(Game.settings.get("default_race_speed", 2)))
	var h := UI.hbox()
	h.add_child(UI.label("Default race speed"))
	h.add_child(UI.spacer())
	h.add_child(UI.option(["1x", "2x", "4x", "8x"], maxi(cur, 0), func(i): Game.settings["default_race_speed"] = speeds[i]; Game.save_settings()))
	v.add_child(h)
	var scales := [0.85, 1.0, 1.15, 1.3]
	var h2 := UI.hbox()
	h2.add_child(UI.label("UI scale"))
	h2.add_child(UI.spacer())
	h2.add_child(UI.option(["85%", "100%", "115%", "130%"], maxi(scales.find(float(Game.settings.get("ui_scale", 1.0))), 1), func(i): Game.settings["ui_scale"] = scales[i]; Game.save_settings()))
	v.add_child(h2)
	var h3 := UI.hbox()
	h3.add_child(UI.label("Master volume"))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(Game.settings.get("master_volume", 0.8))
	sl.custom_minimum_size.x = 200
	sl.value_changed.connect(func(val): Game.settings["master_volume"] = val; Game.save_settings())
	h3.add_child(UI.spacer())
	h3.add_child(sl)
	v.add_child(h3)
	v.add_child(UI.note("Audio, graphics quality and language options arrive with the polish phase."))
