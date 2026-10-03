extends Control
## Browse all tracks (built-in + player-made) with preview and generated statistics.

var back := "menu"
var list: ItemList
var view: TrackView
var stats_box: VBoxContainer
var ids: Array = []


func open(params: Dictionary) -> void:
	back = params.get("back", "menu")
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
	head.add_child(UI.button("Back", func(): Game.goto(back)))
	root.add_child(head)
	var body := UI.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	list = ItemList.new()
	list.custom_minimum_size.x = 280
	list.item_selected.connect(_select)
	body.add_child(list)
	var tv_panel: Array = UI.card("")
	UI.expand(tv_panel[0], true, true)
	tv_panel[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tv_panel[0])
	view = TrackView.new()
	view.show_zones = true
	UI.expand(view, true, true)
	tv_panel[1].add_child(view)
	tv_panel[1].add_child(UI.note("Mouse wheel = zoom, drag = pan. Green dots: overtaking zones (generated automatically from braking points after straights). Yellow/blue lines: sector boundaries."))
	stats_box = UI.vbox(6)
	var sp := UI.panel(stats_box)
	sp.custom_minimum_size.x = 340
	body.add_child(sp)
	ids = DataDB.tracks.keys()
	ids.sort()
	for id in ids:
		var t: Dictionary = DataDB.tracks[id]
		list.add_item("%s%s" % [t["name"], "" if t.get("builtin", false) else "  (custom)"])
	if ids.size() > 0:
		list.select(0)
		_select(0)


func _select(i: int) -> void:
	var t := TrackData.load_id(ids[i])
	view.set_track(t)
	UI.clear(stats_box)
	var s := t.stats
	stats_box.add_child(UI.label(t.name, 20, UI.TEXT, true))
	stats_box.add_child(UI.muted(t.location))
	for pair in [["Length", "%.3f km" % (t.length / 1000.0)], ["Corners", str(t.corners.size())], ["Track width", "%.0f m" % t.width],
			["Default race length", "%d laps" % t.default_laps], ["Reference lap", Fmt.lap_time(s["ref_lap_time"])],
			["Average speed", "%d km/h" % int(s["avg_speed_kph"])], ["Top speed", "%d km/h" % int(s["top_speed_kph"])],
			["Full throttle", "%d%%" % int(s["full_throttle_pct"])], ["Longest straight", "%d m" % int(s["longest_straight_m"])],
			["Overtaking zones", str(t.overtake_zones.size())], ["Elevation change", "flat (elevation arrives with the track editor)"]]:
		var h := UI.hbox()
		h.add_child(UI.label(pair[0], 14, UI.MUTED))
		h.add_child(UI.spacer())
		h.add_child(UI.label(pair[1], 14))
		stats_box.add_child(h)
	stats_box.add_child(HSeparator.new())
	stats_box.add_child(UI.stat_bar("Overtaking ease", s["overtaking"], 100.0, UI.CYAN, 140))
	stats_box.add_child(UI.stat_bar("Tyre wear", s["tire_wear"], 100.0, UI.WARN, 140))
	stats_box.add_child(UI.stat_bar("Downforce demand", s["downforce"], 100.0, UI.PURPLE, 140))
	stats_box.add_child(UI.stat_bar("Difficulty", s["difficulty"], 100.0, UI.BAD, 140))
	stats_box.add_child(HSeparator.new())
	stats_box.add_child(UI.label("Lap time share", 14, UI.MUTED))
	var dem := t.demands()
	for k in dem:
		stats_box.add_child(UI.stat_bar(k.capitalize(), dem[k] * 100.0, 100.0, UI.ACCENT, 140))
