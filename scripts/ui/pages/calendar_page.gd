extends VBoxContainer
## Season calendar: results so far + editing (this season before round 1, or next season).

var hub
var career: Career
var editing := false


func build(p_hub) -> void:
	hub = p_hub
	career = hub.career
	var c := career
	add_theme_constant_override("separation", 12)
	var head := UI.hbox()
	head.add_child(UI.title(tr("Calendar — season %d") % c.season, 22))
	head.add_child(UI.spacer())
	var can_edit_now := c.round_idx == 0 and not c.has_qualified()
	head.add_child(UI.button(tr("Close editor") if editing else (tr("Edit this season") if can_edit_now else tr("Edit next season")), _toggle_edit))
	add_child(head)
	if editing:
		_build_editor(can_edit_now)
		return
	var rows := []
	var hl := []
	for i in c.calendar.size():
		var tid: String = c.calendar[i]
		var td := DataDB.get_track(tid)
		var status := tr("Upcoming")
		var winner := "-"
		var ours := "-"
		if i < c.round_results.size():
			status = tr("Completed")
			var res: Array = c.round_results[i]["results"]
			var w: Dictionary = res[0]
			winner = "%s (%s)" % [c.drivers[w["driver_id"]].full_name(), c.teams[w["team_id"]].abbr]
			var mine := []
			for r in res:
				if r["team_id"] == c.player_team_id:
					mine.append("DNF" if r["dnf"] else "P%d" % r["position"])
			ours = " / ".join(mine)
		elif i == c.round_idx:
			status = tr("NEXT")
			hl.append(i)
		var custom := "" if td.get("builtin", true) else " ★"
		rows.append(["R%d" % (i + 1), str(td.get("name", tid)) + custom, td.get("location", ""), status, winner, ours])
	add_child(UI.table([tr("Rnd"), tr("Circuit"), tr("Location"), tr("Status"), tr("Winner"), tr("Our result")], rows, [50, 0, 200, 100, 260, 120], hl))
	if not c.next_calendar.is_empty():
		add_child(UI.note(tr("Next season: %d rounds (%s).") % [c.next_calendar.size(), ", ".join(c.next_calendar.map(func(id): return DataDB.get_track(id).get("name", id)))]))
	add_child(UI.note(tr("★ = your own track. Build new circuits in the Track Creator and add them here.")))


func _build_editor(this_season: bool) -> void:
	var c := career
	var initial: Array = c.calendar if this_season else (c.next_calendar if not c.next_calendar.is_empty() else c.calendar)
	add_child(UI.note(tr("Changes apply to this season immediately.") if this_season else tr("Changes apply when the next season starts.")))
	var picker := CalendarPicker.new()
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker.setup(initial)
	add_child(picker)
	var h := UI.hbox()
	h.add_child(UI.spacer())
	h.add_child(UI.accent_button(tr("Apply calendar"), _apply.bind(picker, this_season)))
	add_child(h)


func _apply(picker: CalendarPicker, this_season: bool) -> void:
	if this_season:
		career.calendar = picker.calendar.duplicate()
		career.notify("New calendar: %d rounds this season.", [career.calendar.size()], "info")
	else:
		career.next_calendar = picker.calendar.duplicate()
	editing = false
	Game.autosave()
	hub.refresh()
	UI.toast(hub, tr("Calendar saved."), UI.GOOD)


func _toggle_edit() -> void:
	editing = not editing
	UI.clear(self)
	build(hub)
