extends Control
## Track library: browse, preview and manage built-in and player-made tracks.

var back := "menu"
var list: ItemList
var view: TrackView
var stats_box: VBoxContainer
var actions: HBoxContainer
var ids: Array = []
var selected_id := ""
var _rename_dialog: ConfirmationDialog
var _rename_edit: LineEdit
var _delete_dialog: ConfirmationDialog


func open(params: Dictionary) -> void:
	back = params.get("back", "menu")
	selected_id = params.get("select", "")
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var root := UI.vbox(12)
	margin.add_child(root)
	var head := UI.hbox()
	head.add_child(UI.title("Track library", 24))
	head.add_child(UI.spacer())
	head.add_child(UI.accent_button(tr("+ New track"), func(): Game.goto("editor", {"back": back})))
	head.add_child(UI.button(tr("Back"), _back))
	root.add_child(head)
	var body := UI.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	list = ItemList.new()
	list.custom_minimum_size.x = 280
	list.item_selected.connect(_select)
	body.add_child(list)
	var mid: Array = UI.card("")
	UI.expand(mid[0], true, true)
	mid[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(mid[0])
	actions = UI.hbox(6)
	mid[1].add_child(actions)
	view = TrackView.new()
	view.show_zones = true
	view.show_line = true
	UI.expand(view, true, true)
	mid[1].add_child(view)
	mid[1].add_child(UI.note(tr("Mouse wheel = zoom, drag = pan. Cyan: racing line. Green dots: overtaking zones. Green edge lines: DRS. Yellow/blue lines: sector boundaries.")))
	stats_box = UI.vbox(6)
	var sp := UI.panel(UI.scroll(stats_box))
	sp.custom_minimum_size.x = 340
	body.add_child(sp)
	_build_dialogs()
	_fill_list()


func _build_dialogs() -> void:
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = tr("Rename track")
	_rename_edit = LineEdit.new()
	_rename_edit.max_length = 40
	_rename_dialog.add_child(_rename_edit)
	_rename_dialog.ok_button_text = tr("Rename")
	_rename_dialog.cancel_button_text = tr("Cancel")
	_rename_dialog.confirmed.connect(_do_rename)
	add_child(_rename_dialog)
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = tr("Delete track")
	_delete_dialog.ok_button_text = tr("Delete")
	_delete_dialog.cancel_button_text = tr("Cancel")
	_delete_dialog.confirmed.connect(_do_delete)
	add_child(_delete_dialog)


func _fill_list() -> void:
	list.clear()
	ids = DataDB.sorted_track_ids()
	var sel := 0
	for i in ids.size():
		var t: Dictionary = DataDB.tracks[ids[i]]
		list.add_item("%s%s" % [t["name"], "" if t.get("builtin", false) else "  ★"])
		if ids[i] == selected_id:
			sel = i
	if ids.size() > 0:
		list.select(sel)
		_select(sel)


func _select(i: int) -> void:
	selected_id = ids[i]
	var t := TrackData.load_id(selected_id)
	view.set_track(t)
	var builtin := DataDB.is_builtin_track(selected_id)
	UI.clear(actions)
	actions.add_child(UI.button(tr("Edit copy") if builtin else tr("Edit"), func(): Game.goto("editor", {"track_id": selected_id, "back": back})))
	actions.add_child(UI.button(tr("Duplicate"), _duplicate))
	var rn := UI.button(tr("Rename"), _rename)
	rn.disabled = builtin
	actions.add_child(rn)
	var dl := UI.button(tr("Delete"), _delete)
	dl.disabled = builtin
	actions.add_child(dl)
	actions.add_child(UI.spacer())
	actions.add_child(UI.button(tr("Race here"), func(): Game.goto("custom_race", {"track_id": selected_id})))
	if builtin:
		actions.add_child(UI.muted(tr("Built-in tracks are read-only."), 12))
	_fill_stats(t)


func _fill_stats(t: TrackData) -> void:
	UI.clear(stats_box)
	var s := t.stats
	stats_box.add_child(UI.label(t.name, 20, UI.TEXT, true))
	stats_box.add_child(UI.muted(t.location + ("" if DataDB.is_builtin_track(t.id) else "  ·  " + tr("Custom track"))))
	for pair in [["Length", Fmt.km(t.length)], ["Corners", str(t.corners.size())], ["Average width", Fmt.metres(s["avg_width_m"])],
			["Default race length", tr("%d laps") % t.default_laps], ["Reference lap", Fmt.lap_time(s["ref_lap_time"])],
			["Average speed", Fmt.speed(s["avg_speed_kph"])], ["Top speed", Fmt.speed(s["top_speed_kph"])],
			["Full throttle", "%d%%" % int(s["full_throttle_pct"])], ["Longest straight", Fmt.metres(s["longest_straight_m"])],
			["Elevation change", Fmt.metres(s["elevation_change_m"])], ["Max banking", "%.1f°" % s["max_bank_deg"]],
			["DRS zones", str(s["drs_zones"])], ["Pit lane", Fmt.metres(s["pit_lane_m"]) if s["pit_lane_m"] > 0 else "-"],
			["Bridges", str(s["bridges"])], ["Overtaking zones", str(t.overtake_zones.size())]]:
		var h := UI.hbox()
		h.add_child(UI.label(tr(pair[0]), 14, UI.MUTED))
		h.add_child(UI.spacer())
		h.add_child(UI.label(pair[1], 14))
		stats_box.add_child(h)
	stats_box.add_child(HSeparator.new())
	stats_box.add_child(UI.stat_bar(tr("Overtaking ease"), s["overtaking"], 100.0, UI.CYAN, 140))
	stats_box.add_child(UI.stat_bar(tr("Tyre wear"), s["tire_wear"], 100.0, UI.WARN, 140))
	stats_box.add_child(UI.stat_bar(tr("Downforce demand"), s["downforce"], 100.0, UI.PURPLE, 140))
	stats_box.add_child(UI.stat_bar(tr("Difficulty"), s["difficulty"], 100.0, UI.BAD, 140))
	stats_box.add_child(HSeparator.new())
	stats_box.add_child(UI.label(tr("Lap time share"), 14, UI.MUTED))
	var dem := t.demands()
	for k in dem:
		stats_box.add_child(UI.stat_bar(UI.dim_name(k), dem[k] * 100.0, 100.0, UI.ACCENT, 140))


func _duplicate() -> void:
	var d := DataDB.get_track(selected_id).duplicate(true)
	d["name"] = str(d["name"]) + " " + tr("(copy)")
	d["id"] = DataDB.new_track_id(d["name"])
	# keep generated defaults explicit so the copy looks identical
	var t := TrackData.load_id(selected_id)
	var td := t.to_dict()
	td["id"] = d["id"]
	td["name"] = d["name"]
	DataDB.save_user_track(td)
	selected_id = td["id"]
	_fill_list()
	UI.toast(self, tr("Track duplicated."), UI.GOOD)


func _rename() -> void:
	_rename_edit.text = str(DataDB.get_track(selected_id).get("name", ""))
	_rename_dialog.popup_centered(Vector2i(420, 110))
	_rename_edit.grab_focus()


func _do_rename() -> void:
	var name := _rename_edit.text.strip_edges()
	if name == "":
		return
	var d := DataDB.get_track(selected_id).duplicate(true)
	d["name"] = name
	DataDB.save_user_track(d)
	TrackData.clear_cache()
	_fill_list()


func _delete() -> void:
	var used := Game.career != null and selected_id in Game.career.calendar
	_delete_dialog.dialog_text = tr("Delete \"%s\"? This cannot be undone.") % DataDB.get_track(selected_id).get("name", "")
	if used:
		_delete_dialog.dialog_text += "\n" + tr("It is on the loaded career's calendar and will be replaced there.")
	_delete_dialog.popup_centered()


func _do_delete() -> void:
	DataDB.delete_user_track(selected_id)
	TrackData.clear_cache()
	if Game.career:
		Game.career.replace_missing_tracks()
	selected_id = ""
	_fill_list()


func _back() -> void:
	Game.goto(back)
