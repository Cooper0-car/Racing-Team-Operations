extends VBoxContainer


func build(hub) -> void:
	var c: Career = hub.career
	add_theme_constant_override("separation", 12)
	add_child(UI.title("Championship standings — season %d" % c.season, 22))
	var row := UI.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)

	var dc: Array = UI.card("Drivers")
	UI.expand(dc[0], true, true)
	row.add_child(dc[0])
	var rows := []
	var hl := []
	var ds := c.driver_standings()
	for i in ds.size():
		var e: Dictionary = ds[i]
		var t: Team = e["team"]
		if t == null:
			continue
		if t.is_player:
			hl.append(rows.size())
		rows.append(["P%d" % (i + 1), UI.swatch(t.primary), e["driver"].full_name(), t.abbr, str(e["wins"]), str(e["points"])])
	var sc := UI.scroll(UI.table(["Pos", "", "Driver", "Team", "Wins", "Pts"], rows, [44, 4, 0, 50, 50, 50], hl))
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dc[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	dc[1].add_child(sc)

	var tc: Array = UI.card("Constructors")
	UI.expand(tc[0], true, true)
	row.add_child(tc[0])
	rows = []
	hl = []
	var ts := c.team_standings()
	for i in ts.size():
		var t: Team = ts[i]["team"]
		if t.is_player:
			hl.append(i)
		rows.append(["P%d" % (i + 1), UI.swatch(t.primary), t.name, "%d" % t.car.overall(), "%d" % int(t.reputation), str(ts[i]["points"])])
	tc[1].add_child(UI.table(["Pos", "", "Team", "Car", "Rep", "Pts"], rows, [44, 4, 0, 50, 50, 50], hl))
	if not c.history.is_empty():
		tc[1].add_child(HSeparator.new())
		tc[1].add_child(UI.label("Past seasons", 14, UI.MUTED))
		for h in c.history:
			tc[1].add_child(UI.label("Season %d: %s / %s — you finished P%d (%d pts)" % [h["season"], h["driver_champion"], h["team_champion"], h["player_position"], h["player_points"]], 13))
