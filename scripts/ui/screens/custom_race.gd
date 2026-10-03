extends Control
## Quick race outside career: pick track, laps, grid order and a team to control.

var track_ids: Array = []
var track_idx := 0
var laps := 10
var grid_mode := 0            # 0 qualifying, 1 random, 2 reverse qualifying
var team_idx := 0
var temp: Career
var teams: Array = []
var view: TrackView
var laps_spin: SpinBox


func open(_params: Dictionary) -> void:
	temp = Career.create({"name": "-", "abbr": "-", "driver_ids": []})
	temp.team_order.erase(temp.player_team_id)
	temp.teams.erase(temp.player_team_id)
	for tid in temp.team_order:
		teams.append(temp.teams[tid])
	track_ids = DataDB.tracks.keys()
	track_ids.sort()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var root := UI.vbox(12)
	margin.add_child(root)
	var head := UI.hbox()
	head.add_child(UI.title("Custom race", 24))
	head.add_child(UI.spacer())
	head.add_child(UI.button("Back", func(): Game.goto("menu")))
	root.add_child(head)
	var body := UI.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var cv: Array = UI.card("Race settings")
	cv[0].custom_minimum_size.x = 420
	body.add_child(cv[0])
	var v: VBoxContainer = cv[1]
	v.add_child(_row("Track", UI.option(track_ids.map(func(id): return DataDB.tracks[id]["name"]), 0, _on_track)))
	laps_spin = SpinBox.new()
	laps_spin.min_value = 1
	laps_spin.max_value = 80
	laps_spin.value_changed.connect(func(val): laps = int(val))
	v.add_child(_row("Laps", laps_spin))
	v.add_child(_row("Grid", UI.option(["Qualifying", "Random", "Reverse qualifying"], 0, func(i): grid_mode = i)))
	v.add_child(_row("Your team", UI.option(teams.map(func(t): return t.name), 0, func(i): team_idx = i)))
	v.add_child(_row("Weather", UI.label("Clear (weather system arrives in Phase 3)", 13, UI.MUTED)))
	v.add_child(_row("Tyre rules", UI.label("Single compound, no pit stops (Phase 3)", 13, UI.MUTED)))
	v.add_child(UI.spacer(false))
	v.add_child(UI.accent_button("Start race", _start))
	var pv: Array = UI.card("Preview")
	UI.expand(pv[0], true, true)
	pv[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(pv[0])
	view = TrackView.new()
	view.show_zones = true
	UI.expand(view, true, true)
	pv[1].add_child(view)
	_on_track(0)


func _row(name: String, c: Control) -> HBoxContainer:
	var h := UI.hbox(10)
	var l := UI.label(name)
	l.custom_minimum_size.x = 110
	h.add_child(l)
	UI.expand(c)
	h.add_child(c)
	return h


func _on_track(i: int) -> void:
	track_idx = i
	var t := TrackData.load_id(track_ids[i])
	view.set_track(t)
	laps = t.default_laps
	laps_spin.set_value_no_signal(laps)


func _start() -> void:
	var track := TrackData.load_id(track_ids[track_idx])
	var entries := temp.entries()
	var grid := []
	if grid_mode == 1:
		grid = entries.duplicate()
		grid.shuffle()
	else:
		var q := Qualifying.run(track, entries, temp.rng)
		for r in q:
			grid.append({"driver": r["driver"], "team": r["team"]})
		if grid_mode == 2:
			grid.reverse()
	var sim := RaceSimulation.new()
	sim.setup(track, grid, laps, randi(), teams[team_idx].id)
	Game.goto("race", {"mode": "custom", "sim": sim})
