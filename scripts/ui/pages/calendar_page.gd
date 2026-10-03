extends VBoxContainer


func build(hub) -> void:
	var c: Career = hub.career
	add_theme_constant_override("separation", 12)
	add_child(UI.title("Calendar — season %d" % c.season, 22))
	var rows := []
	var hl := []
	for i in c.calendar.size():
		var tid: String = c.calendar[i]
		var td := DataDB.get_track(tid)
		var status := "Upcoming"
		var winner := "-"
		var ours := "-"
		if i < c.round_results.size():
			status = "Completed"
			var res: Array = c.round_results[i]["results"]
			var w: Dictionary = res[0]
			winner = "%s (%s)" % [c.drivers[w["driver_id"]].full_name(), c.teams[w["team_id"]].abbr]
			var mine := []
			for r in res:
				if r["team_id"] == c.player_team_id:
					mine.append("DNF" if r["dnf"] else "P%d" % r["position"])
			ours = " / ".join(mine)
		elif i == c.round_idx:
			status = "NEXT"
			hl.append(i)
		rows.append(["R%d" % (i + 1), td.get("name", tid), td.get("location", ""), status, winner, ours])
	add_child(UI.table(["Rnd", "Circuit", "Location", "Status", "Winner", "Our result"], rows, [50, 0, 200, 100, 260, 120], hl))
