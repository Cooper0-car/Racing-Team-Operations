extends Control
## Quick race outside career: pick any track (built-in or custom), laps, grid order and a team to control.

var track_ids: Array = []
var track_idx := 0
var laps := 10
var grid_mode := 0            # 0 qualifying, 1 random, 2 reverse qualifying
var team_idx := 0
var drs := true
var temp: Career
var teams: Array = []
var view: TrackView
var laps_spin: SpinBox
var info: Label
var start_btn: Button


func open(params: Dictionary) -> void:
	temp = Career.create({"name": "-", "abbr": "-", "driver_ids": []})
	temp.team_order.erase(temp.player_team_id)
	temp.teams.erase(temp.player_team_id)
	for tid in temp.team_order:
		teams.append(temp.teams[tid])
	track_ids = DataDB.sorted_track_ids()
	var want: String = params.get("track_id", "")
	if want != "" and want in track_ids:
		track_idx = track_ids.find(want)
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
	head.add_child(UI.button(tr("Track library"), func(): Game.goto("library", {"back": "menu", "select": track_ids[track_idx]})))
	head.add_child(UI.button(tr("Back"), func(): Game.goto("menu")))
	root.add_child(head)
	var body := UI.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var cv: Array = UI.card("Race settings")
	cv[0].custom_minimum_size.x = 440
	body.add_child(cv[0])
	var v: VBoxContainer = cv[1]
	var names := track_ids.map(func(id): return str(DataDB.tracks[id]["name"]) + ("" if DataDB.tracks[id].get("builtin", false) else " ★"))
	v.add_child(UI.form_row(tr("Track"), UI.option(names, track_idx, _on_track), 120))
	laps_spin = SpinBox.new()
	laps_spin.min_value = 1
	laps_spin.max_value = 100
	laps_spin.value_changed.connect(func(val): laps = int(val))
	v.add_child(UI.form_row(tr("Laps"), laps_spin, 120))
	v.add_child(UI.form_row(tr("Grid"), UI.option(["Qualifying", "Random", "Reverse qualifying"], 0, func(i): grid_mode = i), 120))
	v.add_child(UI.form_row(tr("Your team"), UI.option(teams.map(func(t): return t.name), 0, func(i): team_idx = i), 120))
	v.add_child(UI.form_row(tr("DRS"), UI.check(tr("Enabled"), true, func(on): drs = on), 120))
	v.add_child(UI.form_row(tr("Weather"), UI.note(tr("Clear (weather system arrives in Phase 3)")), 120))
	v.add_child(UI.form_row(tr("Tyre rules"), UI.note(tr("Single compound, no pit stops (Phase 3)")), 120))
	info = UI.note("")
	v.add_child(info)
	v.add_child(UI.spacer(false))
	start_btn = UI.accent_button(tr("Start race"), _start)
	v.add_child(start_btn)
	var pv: Array = UI.card("Preview")
	UI.expand(pv[0], true, true)
	pv[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(pv[0])
	view = TrackView.new()
	view.show_zones = true
	UI.expand(view, true, true)
	pv[1].add_child(view)
	_on_track(track_idx)


func _on_track(i: int) -> void:
	track_idx = i
	var t := TrackData.load_id(track_ids[i])
	view.set_track(t)
	laps = t.default_laps
	laps_spin.set_value_no_signal(laps)
	var ok := t.is_valid()
	start_btn.disabled = not ok
	info.text = "%s  ·  %s  ·  %s %s" % [Fmt.km(t.length), tr("%d corners") % t.corners.size(), tr("Reference lap"), Fmt.lap_time(t.stats["ref_lap_time"])]
	if not ok:
		info.text += "\n" + tr("This track has validation errors. Open it in the track creator to fix them.")


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
	sim.tick = Game.sim_dt()
	sim.drs_enabled = drs
	sim.setup(track, grid, laps, randi(), teams[team_idx].id)
	Game.goto("race", {"mode": "custom", "sim": sim})
