extends Control
## Live race: track view, timing tower, strategy commands, radio/race-control feed.

const SPEEDS := [0, 1, 2, 4, 8]

var mode := "career"           # "career" | "custom"
var career: Career
var sim: RaceSimulation
var track: TrackData
var player_team_id := ""
var speed := 2
var tower_rows: Array = []     # per position: {panel, labels...}
var player_panels: Array = []  # per player car: {car, labels, mode_buttons}
var feed: VBoxContainer
var feed_scroll: ScrollContainer
var view: TrackView
var lap_lbl: Label
var time_lbl: Label
var lights_lbl: Label
var speed_buttons := {}
var cam_opt: OptionButton
var finish_btn: Button
var _tower_timer := 0.0
var _results_applied := false
var fast_forward := false
var _last_light := 99
var _flag_played := false


func open(params: Dictionary) -> void:
	mode = params.get("mode", "career")
	speed = int(Game.settings.get("default_race_speed", 2))
	if mode == "career":
		career = Game.career
		track = TrackData.load_id(params["track_id"])
		player_team_id = career.player_team_id
		sim = RaceSimulation.new()
		sim.tick = Game.sim_dt()
		sim.setup(track, career.grid_entries(), career.race_laps(track), career.rng.randi(), player_team_id)
	else:
		sim = params["sim"]
		track = sim.track
		player_team_id = sim.player_team_id
	sim.event_added.connect(_on_event)
	_build()
	_add_feed_line({"time": 0.0, "lap": 1, "type": "flag", "text": tr("Lights out in 3 seconds... %d laps of %s.") % [sim.total_laps, track.name], "player": false})
	if Game.settings.get("race_camera", "track") == "player":
		for c in sim.cars:
			if c.team.id == player_team_id:
				view.follow_idx = c.idx
				cam_opt.select(c.idx + 1)
				break


func _build() -> void:
	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# ---- top bar
	var tb := UI.hbox(10)
	root.add_child(UI.panel(tb, UI.PANEL, 8))
	tb.add_child(UI.label(track.name.to_upper(), 18, UI.TEXT, true))
	lap_lbl = UI.label(tr("LAP %d/%d") % [1, sim.total_laps], 18, UI.ACCENT, true)
	tb.add_child(lap_lbl)
	time_lbl = UI.label("0:00.0", 16, UI.MUTED)
	tb.add_child(time_lbl)
	tb.add_child(UI.label(tr("Weather: Clear"), 14, UI.MUTED))
	tb.add_child(UI.label("DRS" if sim.drs_enabled and not track.drs_zones.is_empty() else "", 14, UI.GOOD))
	tb.add_child(UI.spacer())
	tb.add_child(UI.muted(tr("Camera")))
	var cams := [tr("Whole track")]
	for c in sim.cars:
		cams.append(tr("Follow %s") % c.driver.last_name + (" ★" if c.team.id == player_team_id else ""))
	cam_opt = UI.option(cams, 0, func(i): view.follow_idx = i - 1; view.queue_redraw())
	tb.add_child(cam_opt)
	tb.add_child(UI.muted(tr("Speed")))
	for s in SPEEDS:
		var b := UI.button("❚❚" if s == 0 else "%dx" % s, _set_speed.bind(s))
		speed_buttons[s] = b
		tb.add_child(b)
	var skip := UI.button(tr("Sim to end"), _sim_to_end)
	skip.tooltip_text = tr("Simulate the rest of the race instantly.")
	tb.add_child(skip)
	finish_btn = UI.accent_button(tr("Results ▶"), _go_results)
	finish_btn.visible = false
	tb.add_child(finish_btn)
	_set_speed(speed)

	# ---- body
	var body := UI.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	# left: player cars + feed
	var left := UI.vbox(8)
	left.custom_minimum_size.x = 360
	body.add_child(UI.panel(left, UI.PANEL, 10))
	for c in sim.cars:
		if c.team.id == player_team_id:
			left.add_child(_player_panel(c))
	left.add_child(UI.label(tr("RACE CONTROL & RADIO"), 12, UI.MUTED, true))
	feed = UI.vbox(4)
	feed_scroll = UI.scroll(feed)
	feed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(feed_scroll)
	# centre: track
	var center := Control.new()
	UI.expand(center, true, true)
	body.add_child(center)
	view = TrackView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.set_track(track)
	view.sim = sim
	view.highlight_team = player_team_id
	view.show_line = bool(Game.settings.get("show_racing_line", false))
	center.add_child(view)
	lights_lbl = UI.label("", 64, UI.ACCENT, true)
	lights_lbl.set_anchors_preset(Control.PRESET_CENTER)
	lights_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(lights_lbl)
	# right: timing tower
	var tower := UI.vbox(1)
	tower.custom_minimum_size.x = 430
	body.add_child(UI.panel(tower, UI.PANEL, 8))
	var head := UI.hbox(4)
	for h in [["P", 26], ["", 4], ["DRIVER", 70], ["GAP", 78], ["INT", 56], ["LAST", 72], ["TYRE", 40], ["", 60]]:
		var l := UI.label(tr(h[0]) if h[0] != "" else "", 11, UI.MUTED)
		l.custom_minimum_size.x = h[1]
		head.add_child(l)
	tower.add_child(head)
	for i in sim.cars.size():
		var row := UI.hbox(4)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI._box(UI.PANEL2 if i % 2 == 0 else UI.PANEL, Color(0, 0, 0, 0), 0, 2, 4, 2))
		p.add_child(row)
		tower.add_child(p)
		var cells := []
		for w in [26, 4, 70, 78, 56, 72, 40, 60]:
			var l: Control
			if w == 4:
				l = UI.swatch(Color.WHITE, 4, 16)
			else:
				l = UI.label("", 13)
				l.clip_text = true
			l.custom_minimum_size.x = w
			row.add_child(l)
			cells.append(l)
		var idx := i
		p.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _follow_position(idx))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		tower_rows.append({"panel": p, "cells": cells})
	tower.add_child(UI.note(tr("Click a row to follow that car. Purple = fastest lap. Green ring = DRS open."), 11))


func _player_panel(c: RaceCar) -> PanelContainer:
	var v := UI.vbox(4)
	var p := UI.panel(v, UI.PANEL2, 8)
	p.add_theme_stylebox_override("panel", UI._box(UI.PANEL2, c.team.primary, 1, 6, 8, 8))
	var h := UI.hbox()
	var name_l := UI.label(c.driver.full_name(), 15, UI.TEXT, true)
	h.add_child(name_l)
	h.add_child(UI.spacer())
	var pos_l := UI.label("P%d" % c.position, 20, UI.ACCENT, true)
	h.add_child(pos_l)
	v.add_child(h)
	var info := UI.label("", 13, UI.MUTED)
	v.add_child(info)
	var sectors := UI.label("", 13)
	v.add_child(sectors)
	var tyre := ProgressBar.new()
	tyre.max_value = 100
	tyre.show_percentage = false
	tyre.custom_minimum_size.y = 8
	v.add_child(tyre)
	var mh := UI.hbox(4)
	var btns := []
	for m in 3:
		var b := UI.button(tr(RaceCar.MODE_NAMES[m]), _set_mode.bind(c.idx, m))
		UI.expand(b)
		mh.add_child(b)
		btns.append(b)
	v.add_child(mh)
	player_panels.append({"car": c, "pos": pos_l, "info": info, "sectors": sectors, "tyre": tyre, "buttons": btns})
	return p


func _set_mode(idx: int, m: int) -> void:
	sim.set_mode(idx, m)
	_refresh_player_panels()


func _set_speed(s: int) -> void:
	speed = s
	for k in speed_buttons:
		var b: Button = speed_buttons[k]
		if k == s:
			b.add_theme_stylebox_override("normal", UI._box(UI.ACCENT.darkened(0.3), UI.ACCENT, 1, 4, 8, 6))
		else:
			b.remove_theme_stylebox_override("normal")


func _follow_position(pos_idx: int) -> void:
	if pos_idx < sim.order.size():
		var c: RaceCar = sim.order[pos_idx]
		view.follow_idx = c.idx
		cam_opt.select(c.idx + 1)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _set_speed(0 if speed != 0 else 1)
			KEY_1: _set_speed(1)
			KEY_2: _set_speed(2)
			KEY_3: _set_speed(4)
			KEY_4: _set_speed(8)


func _process(delta: float) -> void:
	if sim.done:
		if not finish_btn.visible:
			finish_btn.visible = true
			lights_lbl.text = ""
		_update_tower()
		return
	if fast_forward:
		# simulate as fast as possible without freezing the window (~25 ms per frame)
		var t0 := Time.get_ticks_usec()
		while not sim.done and Time.get_ticks_usec() - t0 < 25000:
			sim.step(RaceSimulation.DT)
		lights_lbl.text = tr("SIMULATING…  LAP %d/%d") % [mini(sim.order[0].laps_done + 1, sim.total_laps), sim.total_laps]
		lights_lbl.add_theme_font_size_override("font_size", 32)
		_update_tower()
		return
	sim.advance(delta * speed)
	if sim.time < 0.0:
		var lit := clampi(int(ceil(-sim.time)), 0, 3)
		lights_lbl.text = "●".repeat(4 - lit) + "○".repeat(lit - 1) if lit > 0 else ""
		if lit != _last_light:
			_last_light = lit
			if lit > 0:
				Sfx.play("light")
	elif sim.time < 1.5:
		if _last_light != 0:
			_last_light = 0
			Sfx.play("go")
		lights_lbl.text = tr("GO!")
	else:
		lights_lbl.text = ""
	_tower_timer -= delta
	if _tower_timer <= 0.0:
		_tower_timer = 0.2
		_update_tower()
		_refresh_player_panels()


func _update_tower() -> void:
	var leader: RaceCar = sim.order[0]
	lap_lbl.text = tr("LAP %d/%d") % [mini(leader.laps_done + 1, sim.total_laps), sim.total_laps] if not sim.checkered else tr("FINISH")
	if sim.checkered and not _flag_played:
		_flag_played = true
		Sfx.play("flag")
	time_lbl.text = Fmt.race_time(maxf(sim.time, 0.0))
	for i in sim.order.size():
		var c: RaceCar = sim.order[i]
		var cells: Array = tower_rows[i]["cells"]
		var player: bool = c.team.id == player_team_id
		var col := UI.TEXT if not player else Color.WHITE
		cells[0].text = str(i + 1)
		cells[1].color = c.color
		cells[2].text = c.label
		cells[2].add_theme_color_override("font_color", c.team.primary.lightened(0.3) if player else col)
		var gap := sim.gap_to_leader(c)
		cells[3].text = gap["text"]
		var iv := sim.interval_to_ahead(c)
		cells[4].text = "" if i == 0 or c.dnf or is_inf(iv) or iv > 600.0 else "+%.1f" % iv
		cells[5].text = Fmt.lap_time(c.lap_times[-1]) if c.lap_times.size() > 0 else "-"
		var fl: bool = sim.fastest_lap["car"] == c
		cells[5].add_theme_color_override("font_color", UI.PURPLE if fl else UI.TEXT)
		cells[6].text = "%d%%" % int((1.0 - c.tire_wear) * 100.0)
		cells[6].add_theme_color_override("font_color", UI.BAD if c.tire_wear > 0.75 else (UI.WARN if c.tire_wear > 0.5 else UI.GOOD))
		var status := ""
		if c.dnf:
			status = tr("OUT")
		elif c.finished:
			status = tr("FIN")
		elif c.incident_time > 0.0 and c.incident_factor < 0.6:
			status = tr("INCIDENT")
		elif c.pass_timer > 0.0:
			status = tr("ATTACK")
		elif c.mode == RaceCar.Mode.PUSH:
			status = tr("PUSH")
		elif c.mode == RaceCar.Mode.CONSERVE:
			status = tr("SAVE")
		cells[7].text = status
		cells[7].add_theme_color_override("font_color", UI.BAD if c.dnf else UI.MUTED)
		var bg := Color(c.team.primary, 0.22) if player else (UI.PANEL2 if i % 2 == 0 else UI.PANEL)
		(tower_rows[i]["panel"] as PanelContainer).add_theme_stylebox_override("panel", UI._box(bg, Color(0, 0, 0, 0), 0, 2, 4, 2))


func _refresh_player_panels() -> void:
	for pp in player_panels:
		var c: RaceCar = pp["car"]
		pp["pos"].text = tr("OUT") if c.dnf else "P%d" % c.position
		var last := Fmt.lap_time(c.lap_times[-1]) if c.lap_times.size() > 0 else "-"
		var status := c.dnf_text() if c.dnf else (tr("Finished") if c.finished else tr("Lap %d") % c.current_lap())
		pp["info"].text = tr("%s  ·  Last %s  ·  Best %s  ·  Grid P%d") % [status, last, Fmt.lap_time(c.best_lap), c.grid_pos]
		pp["sectors"].text = tr("Sectors  %s  %s  %s   ·  Tyres %d%%") % [Fmt.sector(c.last_sectors[0]), Fmt.sector(c.last_sectors[1]), Fmt.sector(c.last_sectors[2]), int((1.0 - c.tire_wear) * 100.0)]
		pp["tyre"].value = (1.0 - c.tire_wear) * 100.0
		var fill := UI._box(UI.BAD if c.tire_wear > 0.75 else (UI.WARN if c.tire_wear > 0.5 else UI.GOOD), Color(0, 0, 0, 0), 0, 3, 0, 0)
		pp["tyre"].add_theme_stylebox_override("fill", fill)
		for m in 3:
			var b: Button = pp["buttons"][m]
			b.disabled = not c.is_running()
			if c.mode == m:
				b.add_theme_stylebox_override("normal", UI._box(UI.ACCENT.darkened(0.3), UI.ACCENT, 1, 4, 8, 6))
			else:
				b.remove_theme_stylebox_override("normal")


func _on_event(ev: Dictionary) -> void:
	_add_feed_line(ev)


func _add_feed_line(ev: Dictionary) -> void:
	# Settings → Race → radio filter
	var filt := str(Game.settings.get("radio", "all"))
	var important: bool = ev["type"] in ["flag", "incident", "failure"] or ev.get("player", false)
	if filt == "important" and not important:
		return
	if filt == "player" and not (ev.get("player", false) or ev["type"] == "flag"):
		return
	var col := UI.MUTED
	match ev["type"]:
		"radio": col = UI.CYAN
		"incident", "failure": col = UI.BAD
		"mistake": col = UI.WARN
		"overtake": col = UI.GOOD
		"flag": col = Color.WHITE
		"order": col = UI.TEXT
	if ev.get("player", false) and ev["type"] != "radio":
		col = col.lightened(0.2)
	var l := UI.label("L%d  %s" % [ev["lap"], ev["text"]], 13, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed.add_child(l)
	feed.move_child(l, 0)
	if feed.get_child_count() > 120:
		feed.get_child(feed.get_child_count() - 1).queue_free()


func _sim_to_end() -> void:
	fast_forward = true


func _go_results() -> void:
	if _results_applied:
		return
	_results_applied = true
	var res := sim.results()
	var summary := {}
	if mode == "career":
		summary = career.apply_race_result(track, res)
		Game.autosave()
	Game.goto("results", {"mode": mode, "sim": sim, "results": res, "summary": summary})
