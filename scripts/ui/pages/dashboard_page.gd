extends VBoxContainer


func build(hub) -> void:
	var c: Career = hub.career
	var t := c.player_team()
	add_theme_constant_override("separation", 14)
	add_child(UI.title("Dashboard", 22))
	var row := UI.hbox(14)
	add_child(row)

	# championship
	var champ: Array = UI.card("Championship")
	UI.expand(champ[0])
	row.add_child(champ[0])
	var pos := c.team_position(t.id)
	var st := c.team_standings()
	champ[1].add_child(UI.label("P%d  ·  %d pts" % [pos, c.team_points.get(t.id, 0)], 26, UI.TEXT, true))
	if pos > 1:
		var ahead: Dictionary = st[pos - 2]
		champ[1].add_child(UI.muted("%d pts behind %s (P%d)" % [ahead["points"] - c.team_points.get(t.id, 0), ahead["team"].name, pos - 1]))
	else:
		champ[1].add_child(UI.label("Leading the constructors' championship!", 14, UI.GOOD))
	var ds := c.driver_standings()
	for i in ds.size():
		if ds[i]["driver"].team_id == t.id:
			champ[1].add_child(UI.label("%s — P%d, %d pts" % [ds[i]["driver"].full_name(), i + 1, ds[i]["points"]], 14))

	# next race
	var nr: Array = UI.card("Next race")
	UI.expand(nr[0])
	row.add_child(nr[0])
	if c.is_season_over():
		nr[1].add_child(UI.label("Season complete", 20, UI.TEXT, true))
		nr[1].add_child(UI.note("Use 'End Season' in the top bar to collect prize money and start season %d." % (c.season + 1)))
	else:
		var td := TrackData.load_id(c.next_track_id())
		nr[1].add_child(UI.label("Round %d: %s" % [c.round_idx + 1, td.name], 20, UI.TEXT, true))
		nr[1].add_child(UI.muted("%s  ·  %.2f km  ·  %d laps  ·  %d corners" % [td.location, td.length / 1000.0, c.race_laps(td), td.corners.size()]))
		var tv := TrackView.new()
		tv.custom_minimum_size = Vector2(260, 150)
		tv.set_track(td)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nr[1].add_child(tv)
		nr[1].add_child(UI.accent_button("Go to race weekend", hub.show_page.bind("weekend")))

	# finance
	var fin: Array = UI.card("Finance")
	UI.expand(fin[0])
	row.add_child(fin[0])
	fin[1].add_child(UI.label(Fmt.money(t.finance.balance), 26, UI.GOOD if t.finance.balance >= 0 else UI.BAD, true))
	var last_round := c.round_idx - 1
	if last_round >= 0:
		var sm := t.finance.summary(c.season, last_round)
		var inc := 0
		var exp := 0
		for k in sm:
			if sm[k] > 0:
				inc += sm[k]
			else:
				exp += sm[k]
		fin[1].add_child(UI.label("Last round:  +%s  /  %s" % [Fmt.money(inc), Fmt.money(exp)], 14))
	var per_race := 0
	for did in t.driver_ids:
		per_race += int(c.drivers[did].salary / float(c.calendar.size()))
	per_race += int(DataDB.balance["travel_cost_per_race"] * float(t.hq_def().get("travel_mult", 1.0))) + int(DataDB.balance["base_operations_cost_per_race"])
	fin[1].add_child(UI.muted("Fixed costs per race ≈ %s" % Fmt.money(per_race)))
	fin[1].add_child(UI.button("Open finances", hub.show_page.bind("finance")))

	var row2 := UI.hbox(14)
	row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row2)
	# car
	var car: Array = UI.card("Car performance  (overall %d)" % t.car.overall())
	UI.expand(car[0], true, true)
	row2.add_child(car[0])
	var dims := t.car.dimensions()
	for k in ["top_speed", "acceleration", "braking", "low_speed_cornering", "high_speed_cornering", "traction", "tire_usage", "reliability"]:
		car[1].add_child(UI.stat_bar(k.capitalize(), dims[k], 100.0, UI.rating_color(dims[k])))
	car[1].add_child(UI.button("Develop car", hub.show_page.bind("car")))
	# drivers
	var drv: Array = UI.card("Drivers")
	UI.expand(drv[0], true, true)
	row2.add_child(drv[0])
	for did in t.driver_ids:
		var d: Driver = c.drivers[did]
		drv[1].add_child(UI.label("%s  (%d, OVR %d)" % [d.full_name(), d.age, d.overall()], 15, UI.TEXT, true))
		drv[1].add_child(UI.stat_bar("Morale", d.morale, 100.0, UI.rating_color(d.morale), 70))
		drv[1].add_child(UI.muted("Season: %d pts  ·  Career: %d starts, %d wins, %d podiums" % [c.driver_points.get(did, 0), d.stats["starts"], d.stats["wins"], d.stats["podiums"]]))
	# notifications
	var nt: Array = UI.card("Notifications")
	UI.expand(nt[0], true, true)
	row2.add_child(nt[0])
	var nl := UI.vbox(6)
	var sc := UI.scroll(nl)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nt[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	nt[1].add_child(sc)
	for n in c.notifications.slice(0, 25):
		var col := UI.TEXT
		match n["type"]:
			"success": col = UI.GOOD
			"warning": col = UI.BAD
			"finance": col = UI.CYAN
			"car": col = UI.WARN
		var l := UI.label("S%d R%d  %s" % [n["season"], int(n["round"]) + 1, n["text"]], 13, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.add_child(l)
