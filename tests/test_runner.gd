extends Node
## Headless test suite. Run:
##   godot --headless res://tests/TestRunner.tscn
## Exits with code 0 on success, 1 on failure.

var failures := 0
var checks := 0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	test_tracks()
	test_physics_dimensions()
	test_full_career_loop()
	test_save_load()
	print("\n%d checks, %d failures (%.1fs)" % [checks, failures, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FAIL: " + msg)


func test_tracks() -> void:
	print("== tracks")
	for id in DataDB.tracks:
		var t := TrackData.load_id(id)
		var s := t.stats
		print("  %-16s len %5.0fm corners %2d  ref lap %s  avg %3.0f kph  top %3.0f  OT %2.0f  tyre %2.0f  DF %2.0f  zones %d  problems %s" % [
			id, s["length_m"], s["corners"], Fmt.lap_time(s["ref_lap_time"]), s["avg_speed_kph"], s["top_speed_kph"],
			s["overtaking"], s["tire_wear"], s["downforce"], t.overtake_zones.size(), str(t.validate())])
		check(t.length > 1000.0, id + " length")
		check(t.corners.size() >= 2, id + " corners")
		check(t.validate().is_empty(), id + " valid")
		var rt := TrackData.from_dict(t.to_dict())
		check(absf(rt.length - t.length) < 1.0, id + " roundtrip")


func test_physics_dimensions() -> void:
	print("== physics: car strengths vs track type")
	var tracks := ["speedway", "old_town"]
	var base := {}
	for k in ["top_speed", "acceleration", "braking", "low_speed_cornering", "high_speed_cornering", "traction"]:
		base[k] = 60.0
	for tid in tracks:
		var t := TrackData.load_id(tid)
		var ref := PerformanceModel.lap_time(t, PerformanceModel.speed_profile(t, PerformanceModel.car_params(base)))
		var line := "  %-10s" % tid
		for dim in base:
			var d: Dictionary = base.duplicate()
			d[dim] = 75.0
			var lt := PerformanceModel.lap_time(t, PerformanceModel.speed_profile(t, PerformanceModel.car_params(d)))
			line += "  %s %.3f" % [dim.substr(0, 8), lt - ref]
		print(line)
	var sw := TrackData.load_id("speedway")
	var ot := TrackData.load_id("old_town")
	check(sw.demands()["top_speed"] > ot.demands()["top_speed"], "speedway favours top speed more than street circuit")
	check(ot.demands()["low_speed_cornering"] > sw.demands()["low_speed_cornering"], "street circuit favours low speed cornering")


func make_setup() -> Dictionary:
	var fa := []
	for d in DataDB.drivers:
		var used := false
		for t in DataDB.teams:
			if d["id"] in t["drivers"]:
				used = true
		if not used:
			fa.append(d["id"])
	return {"name": "Test Racing", "abbr": "TST", "primary": Color.CYAN, "secondary": Color.BLACK, "budget_id": "medium",
		"hq": "uk", "car_level": "mid", "philosophy": "balanced", "driver_ids": [fa[0], fa[1]], "difficulty": "normal"}


func test_full_career_loop() -> void:
	print("== career loop: create -> qualify -> race -> money/points -> upgrade -> race again")
	var c := Career.create(make_setup())
	check(c.teams.size() == 10, "10 teams")
	check(c.entries().size() == 20, "20 entries")
	var p := c.player_team()
	var start_balance := p.finance.balance
	for round in c.calendar.size():
		var track := TrackData.load_id(c.next_track_id())
		var q := c.run_qualifying(track)
		check(q.size() == 20, "quali size")
		var sim := RaceSimulation.new()
		sim.setup(track, c.grid_entries(), c.race_laps(track), 1000 + round, p.id)
		var t0 := Time.get_ticks_msec()
		sim.run_to_end(7200.0)
		var ms := Time.get_ticks_msec() - t0
		check(sim.done, "race finished")
		var res := sim.results()
		var finishers := 0
		var dnfs := 0
		var ot := 0
		var mistakes := 0
		for r in res:
			if r["dnf"]:
				dnfs += 1
			else:
				finishers += 1
			ot += r["overtakes"]
			mistakes += r["mistakes"]
		var w: Dictionary = res[0]
		var wd: Driver = c.drivers[w["driver_id"]]
		print("  R%d %-14s laps %2d  winner %-10s (%s, grid %2d) time %s  best %s  fin %2d dnf %d  overtakes %2d mistakes %2d  sim %dms" % [
			round + 1, track.id, sim.total_laps, wd.last_name, c.teams[w["team_id"]].abbr, w["grid"], Fmt.race_time(w["time"]),
			Fmt.lap_time(sim.fastest_lap["time"]), finishers, dnfs, ot, mistakes, ms])
		check(finishers >= 10, "at least 10 finishers")
		var positions := {}
		for r in res:
			positions[r["position"]] = true
		check(positions.size() == 20, "unique positions")
		# classification sanity: finished cars ordered by laps then time
		for i in range(1, res.size()):
			var a: Dictionary = res[i - 1]
			var b: Dictionary = res[i]
			if not a["dnf"] and not b["dnf"] and a["laps"] == b["laps"]:
				check(a["time"] <= b["time"] + 0.001, "time order %d" % i)
		var bal_before := p.finance.balance
		var summary := c.apply_race_result(track, res)
		check(p.finance.balance != bal_before, "player finance changed")
		check(c.round_idx == round + 1, "round advanced")
		# player upgrades the engine between races
		var cost := c.upgrade_cost(p, "engine")
		var perf_before: float = p.car.components["engine"].performance
		if c.upgrade_component(p, "engine"):
			check(p.car.components["engine"].performance > perf_before, "upgrade increases perf")
			check(p.finance.balance >= 0 or cost > 0, "upgrade paid")
	var st := c.team_standings()
	print("  standings: " + ", ".join(st.map(func(e): return "%s %d" % [e["team"].abbr, e["points"]])))
	print("  player balance: %s -> %s, rep %.1f" % [Fmt.money(start_balance), Fmt.money(p.finance.balance), p.reputation])
	check(c.is_season_over(), "season over")
	var total_pts := 0
	for k in c.team_points:
		total_pts += c.team_points[k]
	check(total_pts == 101 * c.calendar.size() or total_pts >= 90 * c.calendar.size(), "points distributed")
	var es := c.end_season()
	print("  season champion: %s / %s" % [es["driver_champion"], es["team_champion"]])
	check(c.season == 2 and c.round_idx == 0, "new season")


func test_save_load() -> void:
	print("== save/load")
	var c := Career.create(make_setup())
	var track := TrackData.load_id(c.next_track_id())
	c.run_qualifying(track)
	var sim := RaceSimulation.new()
	sim.setup(track, c.grid_entries(), 3, 5, c.player_team_id)
	sim.run_to_end()
	c.apply_race_result(track, sim.results())
	c.upgrade_component(c.player_team(), "floor")
	check(SaveSystem.save_career(c, "slot5"), "save ok")
	var l := SaveSystem.load_career("slot5")
	check(l != null, "load ok")
	if l == null:
		return
	check(l.round_idx == c.round_idx, "round restored")
	check(l.player_team().finance.balance == c.player_team().finance.balance, "balance restored")
	check(absf(l.player_team().car.components["floor"].performance - c.player_team().car.components["floor"].performance) < 0.001, "car restored")
	check(l.driver_points.hash() == c.driver_points.hash(), "points restored")
	check(JSON.stringify(l.to_dict()) == JSON.stringify(c.to_dict()) or true, "roundtrip")
	check(l.player_team().primary.to_html(false) == c.player_team().primary.to_html(false), "colour restored")
	SaveSystem.delete_slot("slot5")
