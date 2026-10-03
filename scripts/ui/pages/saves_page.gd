extends VBoxContainer

var hub


func build(p_hub) -> void:
	hub = p_hub
	add_theme_constant_override("separation", 12)
	add_child(UI.title("Save / Load", 22))
	var cv: Array = UI.card("Save slots")
	add_child(cv[0])
	for slot in SaveSystem.SLOTS:
		var info := SaveSystem.slot_info(slot)
		var h := UI.hbox(10)
		var nm := UI.label(tr(slot.to_upper()), 15, UI.TEXT, true)
		nm.custom_minimum_size.x = 110
		h.add_child(nm)
		var desc := tr("Empty")
		if not info.is_empty():
			desc = "%s — %s — %s — %s" % [info.get("team_name", "?"), tr("Season %d, Round %d") % [int(info.get("season", 1)), int(info.get("round", 0)) + 1], Fmt.money(int(info.get("balance", 0))), info.get("saved_at", "")]
		h.add_child(UI.expand(UI.label(desc, 14, UI.TEXT if not info.is_empty() else UI.MUTED)))
		if slot != "autosave":
			h.add_child(UI.button(tr("Save here"), _save.bind(slot)))
		var lb := UI.button(tr("Load"), _load.bind(slot))
		lb.disabled = info.is_empty()
		h.add_child(lb)
		cv[1].add_child(h)
	cv[1].add_child(UI.note(tr("The autosave slot is written after every race and when you return to the main menu (if enabled in Settings).")))


func _save(slot: String) -> void:
	if SaveSystem.save_career(hub.career, slot):
		UI.toast(hub, tr("Saved to %s.") % tr(slot.to_upper()), UI.GOOD)
	else:
		UI.toast(hub, "Save failed!", UI.BAD)
	hub.refresh()


func _load(slot: String) -> void:
	if Game.load_career(slot):
		Game.goto("hub")
	else:
		UI.toast(hub, "Load failed.", UI.BAD)
