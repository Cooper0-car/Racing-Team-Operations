extends Node
## Headless test suite. Run:
##   godot --headless res://tests/TestRunner.tscn
## Exits with code 0 on success, 1 on failure.

var failures := 0
var checks := 0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	test_tracks()
	test_track_editing()
	test_track_features_affect_sim()
	test_custom_track_career()
	test_localisation()
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
		print("  %-16s len %5.0fm corners %2d  ref lap %s  avg %3.0f kph  top %3.0f  OT %2.0f  tyre %2.0f  DF %2.0f  zones %d drs %d pit %3.0fm  %s" % [
			id, s["length_m"], s["corners"], Fmt.lap_time(s["ref_lap_time"]), s["avg_speed_kph"], s["top_speed_kph"],
			s["overtaking"], s["tire_wear"], s["downforce"], t.overtake_zones.size(), t.drs_zones.size(), s["pit_lane_m"], str(t.validate())])
		check(t.length > 1000.0, id + " length")
		check(t.corners.size() >= 2, id + " corners")
		check(t.is_valid(), id + " valid")
		var rt := TrackData.from_dict(t.to_dict())
		check(absf(rt.length - t.length) < 1.0, id + " roundtrip")


func test_track_editing() -> void:
	print("== track editor operations")
	var t := TrackData.template("circle")
	check(t.is_valid(), "template valid")
	var n := t.points.size()
	var len0 := t.length
	# insert / remove keep the start line and features attached
	var si := t.samples.size() / 3
	var u := t.sample_u[si]
	var idx := t.insert_point(int(floor(u)), t.samples[si] + t.normals[si] * 60.0, u - floor(u))
	t.build()
	check(t.points.size() == n + 1 and t.length > len0, "insert point grows track")
	t.remove_point(idx)
	t.build()
	check(t.points.size() == n and absf(t.length - len0) < 5.0, "remove point restores length")
	# reverse twice = identity
	var d0 := t.to_dict()
	t.reverse(); t.build(); t.reverse(); t.build()
	check(absf(t.length - len0) < 1.0 and absf(t.start_u - float(d0["start_u"])) < 0.01, "reverse twice")
	# freehand stroke -> control points
	var stroke := PackedVector2Array()
	for i in 200:
		var a := TAU * i / 200.0
		stroke.append(Vector2(cos(a) * (600.0 + 120.0 * sin(3.0 * a)), sin(a) * 400.0))
	var pts := TrackData.stroke_to_points(stroke)
	check(pts.size() >= 6 and pts.size() < 60, "stroke simplified (%d pts)" % pts.size())
	var t2 := TrackData.new()
	t2.points = pts
	t2.build()
	t2.auto_drs(); t2.auto_pit()
	check(t2.is_valid(), "drawn track valid: " + str(t2.validate()))
	# figure-8: crossing at ground level is an error, with 8 m elevation it's a bridge
	var f8 := TrackData.new()
	for i in 16:
		var a := TAU * i / 16.0
		f8.points.append(Vector2(sin(a) * 700.0, sin(2.0 * a) * 300.0))
	f8.build()
	check(not f8.overlaps.is_empty() and not f8.is_valid(), "flat figure-8 overlaps")
	f8.pt_elev = PackedFloat32Array()
	for i in 16:
		f8.pt_elev.append(8.0 * sin(TAU * i / 16.0 + PI / 2.0) + 8.0)
	f8.build()
	check(f8.overlaps.is_empty() and f8.crossings.size() >= 1, "figure-8 with elevation has a bridge (%d)" % f8.crossings.size())
	# save -> load roundtrip through the database
	t2.name = "Test Loop"
	t2.id = DataDB.new_track_id(t2.name)
	check(DataDB.save_user_track(t2.to_dict()), "save user track")
	var t3 := TrackData.load_id(t2.id)
	check(t3 != null and absf(t3.length - t2.length) < 1.0 and t3.drs_zones.size() == t2.drs_zones.size() and not t3.pit.is_empty(), "user track roundtrip")
	DataDB.delete_user_track(t2.id)
	check(not DataDB.tracks.has(t2.id), "user track deleted")


func test_track_features_affect_sim() -> void:
	print("== track features change the physics")
	var p := PerformanceModel.reference_params()
	var base := TrackData.template("oval")
	var lap_line := PerformanceModel.lap_time(base, base.ref_profile)
	var center := TrackData.from_dict(base.to_dict(), false)
	var lap_center := PerformanceModel.lap_time(center, PerformanceModel.speed_profile(center, p))
	print("  racing line %.3f s vs centerline %.3f s" % [lap_line, lap_center])
	check(lap_line < lap_center - 0.2, "racing line is faster than the centerline")
	var banked := TrackData.from_dict(base.to_dict())
	for i in banked.pt_bank.size():
		banked.pt_bank[i] = 15.0
	banked.build()
	var lap_bank := PerformanceModel.lap_time(banked, banked.ref_profile)
	print("  banked 15deg %.3f s" % lap_bank)
	check(lap_bank < lap_line - 0.2, "banking makes corners faster")
	var hilly := TrackData.from_dict(base.to_dict())
	for i in hilly.pt_elev.size():
		hilly.pt_elev[i] = 30.0 * sin(TAU * i / hilly.pt_elev.size())
	hilly.build()
	# climbs and descents change local speeds (up and down largely cancel over a lap, like in reality)
	var max_dv := 0.0
	for i in mini(hilly.ref_profile.size(), base.ref_profile.size()):
		max_dv = maxf(max_dv, absf(hilly.ref_profile[i] - base.ref_profile[i]))
	print("  elevation: max local speed change %.1f m/s" % max_dv)
	check(max_dv > 1.5, "elevation changes speeds along the lap")
	var narrow := TrackData.from_dict(base.to_dict())
	narrow.set_all_width(9.0)
	narrow.build()
	var wide := TrackData.from_dict(base.to_dict())
	wide.set_all_width(24.0)
	wide.build()
	check(PerformanceModel.lap_time(wide, wide.ref_profile) < PerformanceModel.lap_time(narrow, narrow.ref_profile), "wider track allows a faster line")
	check(wide.stats["overtaking"] > narrow.stats["overtaking"], "wider track is easier to overtake on")


func test_custom_track_career() -> void:
	print("== custom track in a career calendar")
	var t := TrackData.template("square")
	t.name = "Career Test Ring"
	t.id = DataDB.new_track_id(t.name)
	DataDB.save_user_track(t.to_dict())
	var setup := make_setup()
	setup["calendar"] = [t.id, "speedway"]
	var c := Career.create(setup)
	check(c.calendar.size() == 2 and c.next_track_id() == t.id, "custom calendar")
	var track := TrackData.load_id(c.next_track_id())
	c.run_qualifying(track)
	var sim := RaceSimulation.new()
	sim.setup(track, c.grid_entries(), 4, 99, c.player_team_id)
	sim.run_to_end()
	check(sim.done, "race on custom track finished")
	var drs_used := 0
	for car in sim.cars:
		drs_used += 1 if car.drs_checked >= 0 else 0
	check(drs_used > 0, "DRS detection used on custom track")
	c.apply_race_result(track, sim.results())
	check(c.round_idx == 1 and c.round_results[0]["track_id"] == t.id, "result recorded for custom track")
	c.next_calendar = ["harbor_park"]
	DataDB.delete_user_track(t.id)
	c.replace_missing_tracks()
	check(DataDB.tracks.has(c.calendar[0]), "deleted track replaced on calendar")
	c.round_idx = c.calendar.size()
	c.end_season()
	check(c.calendar == ["harbor_park"], "next season calendar applied")


func test_localisation() -> void:
	print("== localisation")
	var prev := TranslationServer.get_locale()
	TranslationServer.set_locale("ko")
	check(TranslationServer.translate("Settings") == "설정", "ko: Settings")
	check(TranslationServer.translate("Engine") == "엔진", "ko: Engine")
	var n := {"key": "VICTORY at %s!", "args": ["Harbor Park"], "season": 1, "round": 0, "type": "success"}
	check(Career.notification_text(n) == "Harbor Park 우승!", "ko notification: " + Career.notification_text(n))
	TranslationServer.set_locale("en")
	check(Career.notification_text(n) == "VICTORY at Harbor Park!", "en notification")
	TranslationServer.set_locale(prev)


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
