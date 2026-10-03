extends Control
## Post-race classification + analysis.

var mode := "career"
var sim: RaceSimulation
var results: Array = []
var summary: Dictionary = {}


func open(params: Dictionary) -> void:
	mode = params.get("mode", "career")
	sim = params["sim"]
	results = params["results"]
	summary = params.get("summary", {})
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var root := UI.vbox(12)
	margin.add_child(root)
	var head := UI.hbox()
	head.add_child(UI.title("Race result — " + sim.track.name, 24))
	head.add_child(UI.spacer())
	head.add_child(UI.accent_button("Continue ▶", _continue, 180))
	root.add_child(head)

	var body := UI.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	# classification
	var cl: Array = UI.card("Classification")
	UI.expand(cl[0], true, true)
	cl[0].size_flags_stretch_ratio = 1.4
	body.add_child(cl[0])
	var by_id := {}
	for c in sim.cars:
		by_id[c.driver.id] = c
	var rows := []
	var hl := []
	var winner_time: float = results[0]["time"]
	for i in results.size():
		var r: Dictionary = results[i]
		var c: RaceCar = by_id[r["driver_id"]]
		if c.team.id == sim.player_team_id:
			hl.append(i)
		var gained: int = r["grid"] - r["position"]
		var gl := UI.label("%+d" % gained if gained != 0 else "=", 14, UI.GOOD if gained > 0 else (UI.BAD if gained < 0 else UI.MUTED))
		var time_txt := ""
		if r["dnf"]:
			time_txt = "DNF (%s)" % r["dnf_reason"]
		elif i == 0:
			time_txt = Fmt.race_time(r["time"])
		elif r["laps"] < results[0]["laps"]:
			time_txt = "+%d lap%s" % [results[0]["laps"] - r["laps"], "s" if results[0]["laps"] - r["laps"] > 1 else ""]
		else:
			time_txt = "+%.3f" % (r["time"] - winner_time)
		var bl := UI.label(Fmt.lap_time(r["best_lap"]), 14, UI.PURPLE if r["fastest_lap"] else UI.TEXT)
		rows.append(["P%d" % r["position"], UI.swatch(c.team.primary), c.driver.full_name(), c.team.abbr, "P%d" % r["grid"], gl, str(r["laps"]), time_txt, bl, str(r.get("points", 0)), str(r["overtakes"]), str(r["mistakes"])])
	var sc := UI.scroll(UI.table(["Pos", "", "Driver", "Team", "Grid", "+/-", "Laps", "Time / Gap", "Best lap", "Pts", "OT", "Err"], rows, [40, 4, 0, 46, 46, 36, 40, 170, 80, 36, 30, 30], hl))
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cl[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	cl[1].add_child(sc)

	# analysis column
	var right := UI.vbox(12)
	UI.expand(right, true, true)
	body.add_child(UI.scroll(right))
	right.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mode == "career" and not summary.is_empty():
		var sm: Array = UI.card("Team summary")
		right.add_child(sm[0])
		sm[1].add_child(UI.label("Points scored: %d" % summary["player_points"], 18, UI.TEXT, true))
		sm[1].add_child(UI.label("Income: +%s   Expenses: -%s" % [Fmt.money(summary["player_income"]), Fmt.money(summary["player_expenses"])], 14))
		var net: int = summary["player_income"] - summary["player_expenses"]
		sm[1].add_child(UI.label("Net: %s" % Fmt.money(net), 15, UI.GOOD if net >= 0 else UI.BAD))
	var players := []
	for c in sim.cars:
		if c.team.id == sim.player_team_id:
			players.append(c)
	if players.is_empty():
		players = [sim.order[0], sim.order[1]]
	for c in players:
		right.add_child(_driver_analysis(c))
	var pc: Array = UI.card("Position by lap")
	right.add_child(pc[0])
	var chart := LineChart.new()
	chart.invert_y = true
	chart.y_min_override = 1.0
	chart.y_max_override = float(sim.cars.size())
	chart.y_format = "P%.0f"
	chart.custom_minimum_size = Vector2(380, 200)
	var series := []
	var pal := [UI.ACCENT, UI.CYAN]
	for i in players.size():
		var c: RaceCar = players[i]
		var vals: Array = [c.grid_pos] + c.positions_by_lap
		series.append({"name": c.label, "color": c.team.primary if i == 0 else c.team.secondary.lerp(pal[1], 0.5), "values": vals})
	chart.set_series(series)
	pc[1].add_child(chart)
	var lc: Array = UI.card("Lap times (s)")
	right.add_child(lc[0])
	var chart2 := LineChart.new()
	chart2.custom_minimum_size = Vector2(380, 200)
	var s2 := []
	for i in players.size():
		var c: RaceCar = players[i]
		var vals := c.lap_times.slice(1)   # skip the standing-start lap
		s2.append({"name": c.label, "color": c.team.primary if i == 0 else c.team.secondary.lerp(pal[1], 0.5), "values": vals})
	chart2.x_label = "Lap"
	chart2.set_series(s2)
	lc[1].add_child(chart2)


func _driver_analysis(c: RaceCar) -> PanelContainer:
	var cv: Array = UI.card(c.driver.full_name())
	var v: VBoxContainer = cv[1]
	var finish := "DNF — " + c.dnf_reason if c.dnf else "P%d (from P%d)" % [c.position, c.grid_pos]
	v.add_child(UI.label(finish, 16, UI.TEXT, true))
	var laps := c.lap_times.slice(1)
	var avg := 0.0
	for t in laps:
		avg += t
	avg = avg / laps.size() if laps.size() > 0 else 0.0
	v.add_child(UI.label("Best %s  ·  Avg %s  ·  Best sectors %s / %s / %s" % [Fmt.lap_time(c.best_lap), Fmt.lap_time(avg), Fmt.sector(c.best_sectors[0]), Fmt.sector(c.best_sectors[1]), Fmt.sector(c.best_sectors[2])], 13))
	# car potential = theoretical clean lap of this car with a perfect (100 pace) driver on fresh tyres
	var car_potential := PerformanceModel.lap_time(sim.track, c.profile, 1.0)
	if c.best_lap < INF:
		var pct := car_potential / c.best_lap * 100.0
		v.add_child(UI.stat_bar("Driver vs car potential", pct, 100.0, UI.rating_color((pct - 95.0) * 20.0), 170))
		var verdict := "Driver extracted almost everything from the car." if pct > 98.8 else ("Solid drive; small margin left." if pct > 98.0 else "Driver left time on the table — or tyres/traffic cost pace.")
		v.add_child(UI.note(verdict))
	v.add_child(UI.label("Tyre wear at finish: %d%%  ·  Overtakes %d  ·  Lost places to passes %d  ·  Mistakes %d" % [int(c.tire_wear * 100.0), c.overtakes, c.times_overtaken, c.mistakes], 13))
	for inc in c.incidents:
		v.add_child(UI.label("• " + inc, 13, UI.WARN))
	return cv[0]


func _continue() -> void:
	if mode == "career":
		Game.goto("hub", {"page": "dashboard"})
	else:
		Game.goto("custom_race")
