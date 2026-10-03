extends VBoxContainer
## Race weekend: track briefing -> qualifying -> race.

var hub
var career: Career
var track: TrackData


func build(p_hub) -> void:
	hub = p_hub
	career = hub.career
	add_theme_constant_override("separation", 12)
	if career.is_season_over():
		add_child(UI.title("Season complete", 22))
		add_child(UI.muted("All rounds have been raced. Press 'End Season' in the top bar."))
		return
	track = TrackData.load_id(career.next_track_id())
	var head := UI.hbox(12)
	head.add_child(UI.title("Round %d — %s" % [career.round_idx + 1, track.name], 22))
	head.add_child(UI.spacer())
	head.add_child(UI.label(track.location, 15, UI.MUTED))
	add_child(head)

	var row := UI.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	# track
	var tcard: Array = UI.card("Circuit")
	UI.expand(tcard[0], true, true)
	tcard[0].size_flags_stretch_ratio = 1.3
	row.add_child(tcard[0])
	var tv := TrackView.new()
	tv.show_zones = true
	tv.set_track(track)
	UI.expand(tv, true, true)
	tv.custom_minimum_size = Vector2(300, 280)
	tcard[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	tcard[1].add_child(tv)
	var s := track.stats
	tcard[1].add_child(UI.note("Length %.2f km  ·  %d laps  ·  %d corners  ·  longest straight %d m  ·  ref. top speed %d km/h  ·  green dots = overtaking zones" % [
		track.length / 1000.0, career.race_laps(track), track.corners.size(), int(s["longest_straight_m"]), int(s["top_speed_kph"])]))

	# briefing: what this track demands vs our car
	var mid := UI.vbox(12)
	UI.expand(mid, true, true)
	row.add_child(mid)
	var br: Array = UI.card("Engineering briefing")
	mid.add_child(br[0])
	var dem := track.demands()
	var dims := career.player_team().car.dimensions()
	var avg := _field_average()
	br[1].add_child(UI.note("Share of lap time spent in each phase, and your car vs. the field average:"))
	for k in ["top_speed", "high_speed_cornering", "low_speed_cornering", "braking", "traction"]:
		var h := UI.hbox(8)
		var n := UI.label(k.capitalize(), 13, UI.MUTED)
		n.custom_minimum_size.x = 160
		h.add_child(n)
		var pct := UI.label("%2d%% of lap" % int(dem[k] * 100.0), 13)
		pct.custom_minimum_size.x = 80
		h.add_child(pct)
		var diff: float = dims[k] - avg[k]
		h.add_child(UI.label("%+.1f vs field" % diff, 13, UI.GOOD if diff >= 0 else UI.BAD))
		br[1].add_child(h)
	br[1].add_child(UI.stat_bar("Overtaking ease", s["overtaking"], 100.0, UI.CYAN, 160))
	br[1].add_child(UI.stat_bar("Tyre stress", s["tire_wear"], 100.0, UI.WARN, 160))
	br[1].add_child(UI.stat_bar("Downforce demand", s["downforce"], 100.0, UI.PURPLE, 160))
	br[1].add_child(UI.stat_bar("Difficulty", s["difficulty"], 100.0, UI.BAD, 160))

	# session
	var ses: Array = UI.card("Session")
	UI.expand(ses[0], true, true)
	mid.add_child(ses[0])
	var sv: VBoxContainer = ses[1]
	if not career.has_qualified():
		sv.add_child(UI.label("Qualifying: three flying laps each, best time sets the grid.", 14))
		sv.add_child(UI.accent_button("Run Qualifying", _qualify))
	else:
		_show_quali(sv)
		var h2 := UI.hbox(8)
		h2.add_child(UI.accent_button("Start Race (%d laps)" % career.race_laps(track), _start_race))
		sv.add_child(h2)


func _field_average() -> Dictionary:
	var out := {}
	var n := 0
	for tid in career.teams:
		if tid == career.player_team_id:
			continue
		var d := (career.teams[tid] as Team).car.dimensions()
		for k in d:
			out[k] = out.get(k, 0.0) + d[k]
		n += 1
	for k in out:
		out[k] /= n
	return out


func _qualify() -> void:
	career.run_qualifying(track)
	Game.autosave()
	hub.refresh()


func _show_quali(sv: VBoxContainer) -> void:
	var q: Array = career.weekend["quali"]
	var pole: float = q[0]["best"]
	var rows := []
	var hl := []
	for i in q.size():
		var e: Dictionary = q[i]
		var d: Driver = career.drivers[e["driver_id"]]
		var tm: Team = career.teams[e["team_id"]]
		if tm.is_player:
			hl.append(i)
		var secs: Array = e["sectors"]
		rows.append(["P%d" % (i + 1), UI.swatch(tm.primary), d.full_name(), tm.abbr, Fmt.lap_time(e["best"]),
			"+%.3f" % (e["best"] - pole) if i > 0 else "POLE", Fmt.sector(secs[0]), Fmt.sector(secs[1]), Fmt.sector(secs[2]), "mistake" if e["mistake"] else ""])
	var tbl := UI.table(["Pos", "", "Driver", "Team", "Time", "Gap", "S1", "S2", "S3", ""], rows, [40, 4, 0, 46, 80, 70, 60, 60, 60, 60], hl)
	var sc := UI.scroll(tbl)
	sc.custom_minimum_size.y = 260
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(sc)


func _start_race() -> void:
	Game.goto("race", {"mode": "career", "track_id": track.id})
