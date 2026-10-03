extends Control
## Track creator: draw / edit a circuit, see generated geometry live, test it in Race Mode, save it.

const T := TrackEditorCanvas.Tool
const TOOLS := [
	[T.SELECT, "Select / Move", "V"], [T.DRAW, "Draw freehand", "D"], [T.ADD, "Add point", "A"],
	[T.DELETE, "Delete point", "X"], [T.START, "Start / finish", "S"], [T.SECTOR2, "Sector 2 start", "2"],
	[T.SECTOR3, "Sector 3 start", "3"], [T.DRS, "DRS zone", "Z"], [T.PIT, "Pit lane", "P"],
]
const TOOL_HELP := {
	T.SELECT: "Drag control points to shape the track. Drag empty space to pan, mouse wheel to zoom.",
	T.DRAW: "Hold the left mouse button and draw a closed loop. It replaces the current layout.",
	T.ADD: "Click anywhere to insert a control point into the nearest part of the track.",
	T.DELETE: "Click a control point to remove it.",
	T.START: "Click on the track to place the start/finish line.",
	T.SECTOR2: "Click on the track where sector 2 begins.",
	T.SECTOR3: "Click on the track where sector 3 begins.",
	T.DRS: "Click on a straight to add a DRS zone up to the next braking point. Click a zone to remove it.",
	T.PIT: "Click the pit entry, then the pit exit. Use 'Flip pit side' to change the side.",
}
const MAX_UNDO := 80

var track: TrackData
var canvas: TrackEditorCanvas
var dirty := false
var snap_enabled := false
var _undo: Array = []
var _redo: Array = []
var _full_timer: Timer
var _tool_buttons := {}
var _name_edit: LineEdit
var _loc_edit: LineEdit
var _laps_spin: SpinBox
var _width_slider: HSlider
var _width_lbl: Label
var _point_box: VBoxContainer
var _stats_box: VBoxContainer
var _valid_box: VBoxContainer
var _help_lbl: Label
var _msg_lbl: Label
var _mode_btn: Button
var _save_btn: Button
var _race_box: HBoxContainer
var _race_sim: RaceSimulation
var _race_speed := 2
var _confirm: ConfirmationDialog
var _back_to := "library"


func open(params: Dictionary) -> void:
	_back_to = params.get("back", "library")
	if params.has("track_id") and DataDB.tracks.has(params["track_id"]):
		track = TrackData.from_dict(DataDB.get_track(params["track_id"]))
		if track.builtin:
			# built-in tracks are read-only: edit a copy
			track.builtin = false
			track.id = ""
			track.name = track.name + " " + tr("(copy)")
			dirty = true
	elif params.has("template"):
		track = TrackData.template(params["template"])
		dirty = true
	else:
		track = TrackData.new()
		track.name = tr("New Track")
		track.location = tr("Custom")
	_full_timer = Timer.new()
	_full_timer.one_shot = true
	_full_timer.wait_time = 0.35
	_full_timer.timeout.connect(_full_rebuild)
	add_child(_full_timer)
	_build_ui()
	canvas.set_track(track)
	fit_view()
	set_tool(T.DRAW if track.points.size() < 3 else T.SELECT)
	_refresh_all()


# ================================================================ UI

func _build_ui() -> void:
	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# ---- top bar
	var tb := UI.hbox(8)
	root.add_child(UI.panel(tb, UI.PANEL, 8))
	tb.add_child(UI.label(tr("TRACK CREATOR"), 18, UI.ACCENT, true))
	_name_edit = LineEdit.new()
	_name_edit.text = track.name
	_name_edit.custom_minimum_size.x = 240
	_name_edit.max_length = 40
	_name_edit.text_changed.connect(func(t): track.name = t; dirty = true; _refresh_save())
	tb.add_child(_name_edit)
	_mode_btn = UI.accent_button(tr("Race Mode ▶"), _toggle_mode)
	_mode_btn.tooltip_text = tr("Run AI cars on this layout right now. Switch back to keep editing.")
	tb.add_child(_mode_btn)
	_race_box = UI.hbox(4)
	_race_box.visible = false
	for s in [1, 2, 4, 8]:
		_race_box.add_child(UI.button("%dx" % s, func(): _race_speed = s))
	_race_box.add_child(UI.button(tr("Restart"), _start_race_mode))
	tb.add_child(_race_box)
	tb.add_child(UI.spacer())
	_msg_lbl = UI.label("", 14, UI.MUTED)
	tb.add_child(_msg_lbl)
	tb.add_child(UI.button(tr("Undo"), undo))
	tb.add_child(UI.button(tr("Redo"), redo))
	_save_btn = UI.accent_button(tr("Save"), save)
	tb.add_child(_save_btn)
	tb.add_child(UI.button(tr("Save as copy"), save_copy))
	tb.add_child(UI.button(tr("Custom race"), _custom_race))
	tb.add_child(UI.button(tr("Back"), _back))

	var body := UI.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	# ---- left: tools
	var left := UI.vbox(4)
	var lp := UI.panel(UI.scroll(left), UI.PANEL, 8)
	lp.custom_minimum_size.x = 230
	body.add_child(lp)
	left.add_child(UI.label(tr("TOOLS"), 12, UI.MUTED, true))
	for td in TOOLS:
		var b := UI.button("%s  [%s]" % [tr(td[1]), td[2]], set_tool.bind(td[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_tool_buttons[td[0]] = b
		left.add_child(b)
	_help_lbl = UI.note("")
	left.add_child(_help_lbl)
	left.add_child(HSeparator.new())
	left.add_child(UI.label(tr("NEW LAYOUT"), 12, UI.MUTED, true))
	var nh := UI.hbox(4)
	for tpl in [["Circle", "circle"], ["Oval", "oval"], ["Square", "square"]]:
		nh.add_child(UI.expand(UI.button(tr(tpl[0]), _new_template.bind(tpl[1]))))
	left.add_child(nh)
	left.add_child(UI.button(tr("Clear and draw"), _clear_and_draw))
	left.add_child(HSeparator.new())
	left.add_child(UI.label(tr("SHAPE"), 12, UI.MUTED, true))
	left.add_child(UI.button(tr("Smooth corners"), _shape_op.bind("smooth")))
	var sh := UI.hbox(4)
	sh.add_child(UI.expand(UI.button(tr("Scale -10%"), _shape_op.bind("shrink"))))
	sh.add_child(UI.expand(UI.button(tr("Scale +10%"), _shape_op.bind("grow"))))
	left.add_child(sh)
	left.add_child(UI.button(tr("Reverse direction"), _shape_op.bind("reverse")))
	left.add_child(UI.check(tr("Snap to 10 m grid"), false, func(on): snap_enabled = on))
	left.add_child(HSeparator.new())
	left.add_child(UI.label(tr("FEATURES"), 12, UI.MUTED, true))
	left.add_child(UI.button(tr("Auto DRS zones"), _feature_op.bind("auto_drs")))
	left.add_child(UI.button(tr("Clear DRS zones"), _feature_op.bind("clear_drs")))
	left.add_child(UI.button(tr("Auto pit lane"), _feature_op.bind("auto_pit")))
	left.add_child(UI.button(tr("Flip pit side"), _feature_op.bind("flip_pit")))
	left.add_child(UI.button(tr("Remove pit lane"), _feature_op.bind("remove_pit")))
	left.add_child(HSeparator.new())
	left.add_child(UI.label(tr("VIEW"), 12, UI.MUTED, true))
	left.add_child(UI.check(tr("Racing line"), true, func(on): canvas.show_line = on; canvas.queue_redraw()))
	left.add_child(UI.check(tr("Braking zones"), true, func(on): canvas.show_braking = on; canvas.queue_redraw()))
	left.add_child(UI.check(tr("Overtaking zones"), true, func(on): canvas.show_zones = on; canvas.queue_redraw()))
	left.add_child(UI.check(tr("Elevation colours"), false, func(on): canvas.elevation_colors = on; canvas.invalidate()))
	left.add_child(UI.button(tr("Fit view  [F]"), fit_view))

	# ---- centre: canvas
	canvas = TrackEditorCanvas.new()
	canvas.ed = self
	canvas.show_line = true
	canvas.show_braking = true
	canvas.show_zones = true
	canvas.focus_mode = Control.FOCUS_ALL
	UI.expand(canvas, true, true)
	body.add_child(canvas)

	# ---- right: properties, stats, validation
	var right := UI.vbox(10)
	var rp := UI.panel(UI.scroll(right), UI.PANEL, 10)
	rp.custom_minimum_size.x = 340
	body.add_child(rp)
	right.add_child(UI.label(tr("TRACK"), 12, UI.MUTED, true))
	_loc_edit = LineEdit.new()
	_loc_edit.text = track.location
	_loc_edit.max_length = 40
	_loc_edit.text_changed.connect(func(t): track.location = t; dirty = true; _refresh_save())
	right.add_child(UI.form_row(tr("Location"), _loc_edit, 110))
	_laps_spin = SpinBox.new()
	_laps_spin.min_value = 1
	_laps_spin.max_value = 100
	_laps_spin.value = track.default_laps
	_laps_spin.value_changed.connect(func(v): track.default_laps = int(v); dirty = true; _refresh_save())
	right.add_child(UI.form_row(tr("Race laps"), _laps_spin, 110))
	var wh := UI.hbox(6)
	_width_slider = UI.slider(TrackData.MIN_WIDTH, TrackData.MAX_WIDTH, 0.5, track.width, _on_width_all)
	UI.expand(_width_slider)
	wh.add_child(_width_slider)
	_width_lbl = UI.label("", 13)
	_width_lbl.custom_minimum_size.x = 56
	wh.add_child(_width_lbl)
	right.add_child(UI.form_row(tr("Width (all)"), wh, 110))
	right.add_child(HSeparator.new())
	_point_box = UI.vbox(6)
	right.add_child(_point_box)
	right.add_child(HSeparator.new())
	right.add_child(UI.label(tr("VALIDATION"), 12, UI.MUTED, true))
	_valid_box = UI.vbox(4)
	right.add_child(_valid_box)
	right.add_child(HSeparator.new())
	right.add_child(UI.label(tr("GENERATED STATISTICS"), 12, UI.MUTED, true))
	_stats_box = UI.vbox(3)
	right.add_child(_stats_box)

	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = tr("You have unsaved changes. Leave without saving?")
	_confirm.ok_button_text = tr("Leave")
	_confirm.cancel_button_text = tr("Cancel")
	_confirm.confirmed.connect(_leave)
	add_child(_confirm)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var k := event as InputEventKey
	if k.ctrl_pressed and k.keycode == KEY_Z:
		undo()
	elif k.ctrl_pressed and (k.keycode == KEY_Y or (k.shift_pressed and k.keycode == KEY_Z)):
		redo()
	elif k.ctrl_pressed and k.keycode == KEY_S:
		save()
	elif k.keycode == KEY_DELETE and canvas.selected >= 0:
		_delete_selected()
	elif k.keycode == KEY_ESCAPE:
		select_point(-1)
		canvas.pit_pending_entry = -1.0
	elif k.keycode == KEY_F:
		fit_view()
	else:
		for td in TOOLS:
			if OS.get_keycode_string(k.keycode) == td[2]:
				set_tool(td[0])
				return
		return
	get_viewport().set_input_as_handled()


# ================================================================ state

func set_tool(t: int) -> void:
	if canvas.race_mode:
		return
	canvas.tool = t
	canvas.pit_pending_entry = -1.0
	for k in _tool_buttons:
		var b: Button = _tool_buttons[k]
		if k == t:
			b.add_theme_stylebox_override("normal", UI._box(UI.ACCENT.darkened(0.35), UI.ACCENT, 1, 4, 8, 6))
		else:
			b.remove_theme_stylebox_override("normal")
	_help_lbl.text = tr(TOOL_HELP[t])
	canvas.queue_redraw()


func select_point(i: int) -> void:
	canvas.selected = i
	_refresh_point_panel()
	canvas.queue_redraw()


func message(text: String, col: Color = UI.MUTED) -> void:
	_msg_lbl.text = tr(text)
	_msg_lbl.add_theme_color_override("font_color", col)


func push_undo() -> void:
	_undo.append(track.to_dict())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()


func discard_undo() -> void:
	if not _undo.is_empty():
		_undo.pop_back()


func undo() -> void:
	if _undo.is_empty() or canvas.race_mode:
		return
	_redo.append(track.to_dict())
	_restore(_undo.pop_back())


func redo() -> void:
	if _redo.is_empty() or canvas.race_mode:
		return
	_undo.append(track.to_dict())
	_restore(_redo.pop_back())


func _restore(d: Dictionary) -> void:
	var keep_id := track.id
	var keep_builtin := track.builtin
	var keep_name := track.name
	track = TrackData.from_dict(d, true)
	track.id = keep_id
	track.builtin = keep_builtin
	track.name = keep_name
	canvas.set_track(track)
	canvas.selected = -1
	dirty = true
	_refresh_all()


## Geometry changed. full=false: fast rebuild (no racing line) now + full rebuild shortly after.
func changed(full: bool, refit: bool = false) -> void:
	dirty = true
	if full:
		_full_rebuild()
	else:
		track.use_racing_line = false
		track.build()
		canvas.invalidate()
		_full_timer.start()
		_refresh_save()
	if refit:
		fit_view()


func _full_rebuild() -> void:
	track.use_racing_line = true
	track.build()
	canvas.invalidate()
	_refresh_all()


func fit_view() -> void:
	canvas.pan = Vector2.ZERO
	canvas.zoom_mul = 1.0
	if track.points.size() >= 3:
		canvas.fixed_rect = canvas.fit_rect().grow(150.0)
	else:
		canvas.fixed_rect = Rect2(-1200, -800, 2400, 1600)
	canvas.queue_redraw()


func _refresh_all() -> void:
	_refresh_point_panel()
	_refresh_stats()
	_refresh_save()
	_width_lbl.text = Fmt.metres(track.width)


func _refresh_save() -> void:
	var v := track.validate() if track.length > 0.0 else {"errors": [["Draw a track first.", []]], "warnings": []}
	_save_btn.disabled = not v["errors"].is_empty()
	_save_btn.text = tr("Save") + (" *" if dirty else "")
	UI.clear(_valid_box)
	if v["errors"].is_empty() and v["warnings"].is_empty():
		_valid_box.add_child(UI.label(tr("✓ Track is valid and ready to race."), 13, UI.GOOD))
	for e in v["errors"]:
		var l := UI.note("✗ " + (tr(e[0]) % e[1] if e[1].size() > 0 else tr(e[0])))
		l.add_theme_color_override("font_color", UI.BAD)
		_valid_box.add_child(l)
	for w in v["warnings"]:
		var l2 := UI.note("! " + (tr(w[0]) % w[1] if w[1].size() > 0 else tr(w[0])))
		l2.add_theme_color_override("font_color", UI.WARN)
		_valid_box.add_child(l2)


func _refresh_point_panel() -> void:
	UI.clear(_point_box)
	var i := canvas.selected
	if i < 0 or i >= track.points.size():
		_point_box.add_child(UI.label(tr("CONTROL POINT"), 12, UI.MUTED, true))
		_point_box.add_child(UI.note(tr("Select a control point to edit its width, runoff, banking and elevation.")))
		return
	_point_box.add_child(UI.label(tr("CONTROL POINT %d") % (i + 1), 12, UI.MUTED, true))
	_prop_row(tr("Width"), TrackData.MIN_WIDTH, TrackData.MAX_WIDTH, 0.5, track.pt_width[i], "width", func(v): return Fmt.metres(v))
	_prop_row(tr("Runoff"), 1.0, 60.0, 1.0, track.pt_runoff[i], "runoff", func(v): return Fmt.metres(v) + ("  " + tr("(wall)") if v < 6.0 else ""))
	_prop_row(tr("Banking"), -30.0, 30.0, 0.5, track.pt_bank[i], "bank", func(v): return "%.1f°" % v)
	_prop_row(tr("Elevation"), -40.0, 120.0, 0.5, track.pt_elev[i], "elev", func(v): return Fmt.metres(v))
	var h := UI.hbox(4)
	h.add_child(UI.expand(UI.button(tr("Apply to all points"), _apply_all.bind(i))))
	h.add_child(UI.button(tr("Delete"), _delete_selected))
	_point_box.add_child(h)
	_point_box.add_child(UI.note(tr("Runoff under 6 m means walls: mistakes there end in the barriers. Banking adds grip in corners. Slopes change acceleration and braking. Raise a section 5 m above another to build a bridge.")))


func _prop_row(label_text: String, mn: float, mx: float, st: float, value: float, key: String, fmt: Callable) -> void:
	var h := UI.hbox(6)
	var vl := UI.label(fmt.call(value), 13)
	vl.custom_minimum_size.x = 92
	var on_change := func(v: float) -> void:
		_set_prop(key, v)
		vl.text = fmt.call(v)
	var sl := UI.slider(mn, mx, st, value, on_change, 120)
	sl.drag_started.connect(push_undo)
	UI.expand(sl)
	h.add_child(sl)
	h.add_child(vl)
	_point_box.add_child(UI.form_row(label_text, h, 80))


func _delete_selected() -> void:
	if canvas.selected < 0:
		return
	if track.points.size() <= 4:
		message("A track needs at least 4 control points.", UI.WARN)
		return
	push_undo()
	track.remove_point(canvas.selected)
	select_point(-1)
	changed(true)


func _set_prop(key: String, v: float) -> void:
	var i := canvas.selected
	if i < 0:
		return
	match key:
		"width": track.pt_width[i] = v
		"runoff": track.pt_runoff[i] = v
		"bank": track.pt_bank[i] = v
		"elev": track.pt_elev[i] = v
	changed(false)


func _apply_all(i: int) -> void:
	push_undo()
	for k in track.points.size():
		track.pt_width[k] = track.pt_width[i]
		track.pt_runoff[k] = track.pt_runoff[i]
		track.pt_bank[k] = track.pt_bank[i]
	changed(true)


func _on_width_all(v: float) -> void:
	if track.points.is_empty():
		track.width = v
		return
	track.set_all_width(v)
	_width_lbl.text = Fmt.metres(v)
	changed(false)


func _refresh_stats() -> void:
	UI.clear(_stats_box)
	if track.length <= 0.0:
		_stats_box.add_child(UI.muted(tr("No track yet.")))
		return
	var s := track.stats
	for row in [
		["Length", Fmt.km(s["length_m"])], ["Corners", str(s["corners"])],
		["Reference lap", Fmt.lap_time(s["ref_lap_time"])], ["Average speed", Fmt.speed(s["avg_speed_kph"])],
		["Top speed", Fmt.speed(s["top_speed_kph"])], ["Full throttle", "%d%%" % int(s["full_throttle_pct"])],
		["Longest straight", Fmt.metres(s["longest_straight_m"])], ["Elevation change", Fmt.metres(s["elevation_change_m"])],
		["Max gradient", "%.1f%%" % s["max_grade_pct"]], ["Max banking", "%.1f°" % s["max_bank_deg"]],
		["DRS zones", str(s["drs_zones"])], ["Pit lane", Fmt.metres(s["pit_lane_m"]) if s["pit_lane_m"] > 0 else "-"],
		["Bridges", str(s["bridges"])], ["Overtaking zones", str(track.overtake_zones.size())]]:
		var h := UI.hbox()
		h.add_child(UI.label(tr(row[0]), 13, UI.MUTED))
		h.add_child(UI.spacer())
		h.add_child(UI.label(row[1], 13))
		_stats_box.add_child(h)
	_stats_box.add_child(UI.stat_bar(tr("Overtaking ease"), s["overtaking"], 100.0, UI.CYAN, 130))
	_stats_box.add_child(UI.stat_bar(tr("Tyre wear"), s["tire_wear"], 100.0, UI.WARN, 130))
	_stats_box.add_child(UI.stat_bar(tr("Downforce demand"), s["downforce"], 100.0, UI.PURPLE, 130))
	_stats_box.add_child(UI.stat_bar(tr("Difficulty"), s["difficulty"], 100.0, UI.BAD, 130))


# ================================================================ operations

func _new_template(kind: String) -> void:
	push_undo()
	var t := TrackData.template(kind)
	track.points = t.points
	track.pt_width = t.pt_width; track.pt_runoff = t.pt_runoff; track.pt_bank = t.pt_bank; track.pt_elev = t.pt_elev
	track.start_u = 0.0
	track.drs_zones = t.drs_zones
	track.pit = t.pit
	changed(true, true)
	set_tool(T.SELECT)


func _clear_and_draw() -> void:
	push_undo()
	track.points = PackedVector2Array()
	track.pt_width.clear(); track.pt_runoff.clear(); track.pt_bank.clear(); track.pt_elev.clear()
	track.drs_zones.clear()
	track.pit = {}
	track.build()
	canvas.invalidate()
	select_point(-1)
	fit_view()
	set_tool(T.DRAW)
	_refresh_all()


func _shape_op(op: String) -> void:
	if track.points.size() < 3:
		return
	push_undo()
	match op:
		"smooth": track.smooth_points()
		"grow": track.scale_track(1.1)
		"shrink": track.scale_track(1.0 / 1.1)
		"reverse": track.reverse()
	changed(true, op != "smooth" and op != "reverse")


func _feature_op(op: String) -> void:
	if track.length <= 0.0:
		return
	push_undo()
	match op:
		"auto_drs":
			track.auto_drs()
			message(tr("%d DRS zone(s) placed.") % track.drs_zones.size(), UI.GOOD)
		"clear_drs":
			track.drs_zones.clear()
		"auto_pit":
			track.auto_pit()
		"flip_pit":
			if not track.pit.is_empty():
				track.pit["side"] = -int(track.pit["side"])
		"remove_pit":
			track.pit = {}
	track.rebuild_features()
	dirty = true
	canvas.invalidate()
	_refresh_all()


# ================================================================ race mode

func _toggle_mode() -> void:
	if canvas.race_mode:
		canvas.race_mode = false
		canvas.sim = null
		_race_sim = null
		_mode_btn.text = tr("Race Mode ▶")
		_race_box.visible = false
		message("Edit mode.")
		canvas.queue_redraw()
		return
	if not track.is_valid():
		message("Fix the validation errors before racing.", UI.BAD)
		return
	_full_rebuild()
	canvas.race_mode = true
	_mode_btn.text = tr("◼ Edit Mode")
	_race_box.visible = true
	_start_race_mode()


func _start_race_mode() -> void:
	var temp := Career.create({"name": "-", "abbr": "-", "driver_ids": []})
	var grid := temp.entries()
	grid.shuffle()
	_race_sim = RaceSimulation.new()
	_race_sim.tick = Game.sim_dt()
	_race_sim.setup(track, grid, maxi(track.default_laps, 1), randi(), "")
	canvas.sim = _race_sim
	canvas.follow_idx = -1
	message("Race mode: AI cars are driving your layout.", UI.GOOD)


func _process(delta: float) -> void:
	if _race_sim and canvas.race_mode:
		_race_sim.advance(delta * _race_speed)
		if _race_sim.done:
			_start_race_mode()


# ================================================================ save / leave

func save() -> bool:
	if not track.is_valid():
		message("Fix the validation errors before saving.", UI.BAD)
		return false
	if track.name.strip_edges() == "":
		track.name = tr("New Track")
	if track.id == "" or DataDB.is_builtin_track(track.id):
		track.id = DataDB.new_track_id(track.name)
	if DataDB.save_user_track(track.to_dict()):
		dirty = false
		TrackData.clear_cache()
		message(tr("Saved \"%s\".") % track.name, UI.GOOD)
		Sfx.play("success")
		_refresh_save()
		return true
	message("Save failed.", UI.BAD)
	return false


func save_copy() -> void:
	track.id = ""
	track.name = track.name + " " + tr("(copy)")
	_name_edit.text = track.name
	save()


func _custom_race() -> void:
	if dirty and not save():
		return
	if track.id == "":
		return
	Game.goto("custom_race", {"track_id": track.id})


func _back() -> void:
	if dirty and track.points.size() >= 3:
		_confirm.popup_centered()
	else:
		_leave()


func _leave() -> void:
	Game.goto("library", {"back": _back_to})
