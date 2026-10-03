extends Control
## Main menu: Continue, New Career, Load, Custom Race, Track Creator, Track Library, Settings, Exit.

const VERSION := "v0.2"

var side: VBoxContainer
var bg_track: TrackView


func open(_params: Dictionary) -> void:
	# animated background: an AI race on a random track
	bg_track = TrackView.new()
	bg_track.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_track.modulate = Color(1, 1, 1, 0.35)
	bg_track.interactive = false
	bg_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_track.show_labels = false
	bg_track.show_markers = false
	add_child(bg_track)
	_start_bg_race()

	var root := UI.hbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var left := UI.vbox(10)
	left.custom_minimum_size.x = 420
	var lp := UI.panel(left, Color(UI.PANEL, 0.92), 36)
	root.add_child(lp)
	left.add_child(UI.label("RACING TEAM", 40, UI.TEXT, true))
	left.add_child(UI.label("OPERATIONS", 40, UI.ACCENT, true))
	left.add_child(UI.muted(tr("Team management  ·  Car development  ·  Custom tracks"), 14))
	left.add_child(UI.spacer(false))

	var latest := SaveSystem.latest_slot()
	var cont := UI.accent_button(tr("Continue"), func(): _load(latest), 340)
	cont.disabled = latest == ""
	if latest != "":
		var info := SaveSystem.slot_info(latest)
		cont.tooltip_text = tr("%s — Season %d, Round %d") % [info.get("team_name", "?"), int(info.get("season", 1)), int(info.get("round", 0)) + 1]
	left.add_child(cont)
	left.add_child(UI.button(tr("New Career"), func(): Game.goto("team_creation"), 340))
	left.add_child(UI.button(tr("Load Career"), _show_load, 340))
	left.add_child(UI.button(tr("Custom Race"), func(): Game.goto("custom_race"), 340))
	left.add_child(UI.button(tr("Track Creator"), func(): Game.goto("editor", {"back": "menu"}), 340))
	left.add_child(UI.button(tr("Track Library"), func(): Game.goto("library", {"back": "menu"}), 340))
	left.add_child(UI.button(tr("Settings"), func(): Game.goto("settings", {"back": "menu"}), 340))
	left.add_child(UI.button(tr("Exit"), func(): get_tree().quit(), 340))
	left.add_child(UI.spacer(false))
	left.add_child(UI.muted("%s  ·  %s  ·  F12 = %s" % [VERSION, tr("Phase 4: track creator"), tr("debug menu")], 12))

	side = UI.vbox(10)
	side.custom_minimum_size.x = 520
	var holder := UI.vbox(0)
	holder.add_child(UI.spacer(false))
	holder.add_child(side)
	holder.add_child(UI.spacer(false))
	root.add_child(UI.spacer())
	root.add_child(holder)
	root.add_child(UI.spacer())


func _start_bg_race() -> void:
	var ids := DataDB.sorted_track_ids()
	if ids.is_empty():
		return
	var track := TrackData.load_id(ids[randi() % ids.size()])
	if track == null or not track.is_valid():
		return
	var c := Career.create({"name": "-", "abbr": "-", "driver_ids": []})
	var sim := RaceSimulation.new()
	var grid := c.entries()
	grid.shuffle()
	sim.setup(track, grid, 99, randi(), "")
	sim.time = 0.0
	bg_track.set_track(track)
	bg_track.sim = sim


func _process(delta: float) -> void:
	if bg_track and bg_track.sim:
		bg_track.sim.advance(delta * 2.0)


func _load(slot: String) -> void:
	if Game.load_career(slot):
		Game.goto("hub")
	else:
		UI.toast(self, tr("Could not load save '%s'.") % slot, UI.BAD)


func _show_load() -> void:
	UI.clear(side)
	var cv: Array = UI.card("Load Career")
	side.add_child(cv[0])
	var any := false
	for slot in SaveSystem.SLOTS:
		var info := SaveSystem.slot_info(slot)
		if info.is_empty():
			continue
		any = true
		var row := UI.hbox(8)
		var txt := "%s  —  %s\n%s · %s · %s" % [tr(slot.to_upper()), info.get("team_name", "?"),
			tr("Season %d, Round %d") % [int(info.get("season", 1)), int(info.get("round", 0)) + 1], Fmt.money(int(info.get("balance", 0))), info.get("saved_at", "")]
		var l := UI.label(txt, 13)
		UI.expand(l)
		row.add_child(l)
		row.add_child(UI.button(tr("Load"), _load.bind(slot)))
		row.add_child(UI.button(tr("Delete"), func(): SaveSystem.delete_slot(slot); _show_load()))
		cv[1].add_child(row)
	if not any:
		cv[1].add_child(UI.muted(tr("No saved careers yet.")))
