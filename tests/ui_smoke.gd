extends Node
## UI smoke test: drives the real screens like a player and saves screenshots.
##   xvfb-run godot --rendering-driver opengl3 res://tests/UISmoke.tscn -- <out_dir>

var out_dir := "user://screens/"
var main: Control
var errors := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _run()
	print("UI smoke finished, errors: %d" % errors)
	get_tree().quit(1 if errors > 0 else 0)


func _wait(frames: int = 3) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir + name + ".png")
	print("shot ", name)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		errors += 1
		print("UI FAIL: ", msg)


func _run() -> void:
	await _wait(10)
	_expect(TranslationServer.get_locale().begins_with("ko"), "Korean is the default language")
	await _shot("01_menu")
	await _editor_flow()
	await _settings_flow()
	Game.goto("team_creation")
	await _wait(3)
	var tc = main.current
	if _created_track != "":
		tc.setup["calendar"] = [_created_track, "harbor_park", "speedway"]
	tc._toggle_driver(tc.free_agents[0].id)
	tc._toggle_driver(tc.free_agents[1].id)
	await _wait(3)
	await _shot("02_team_creation")
	_expect(not tc.start_btn.disabled, "start enabled after picking drivers")
	tc._start()
	await _wait(5)
	_expect(Game.career != null, "career created")
	await _shot("03_dashboard")
	var hub = main.current
	for p in ["car", "drivers", "standings", "finance", "saves"]:
		hub.show_page(p)
		await _wait(3)
		await _shot("04_" + p)
	# upgrade engine through the car page
	hub.show_page("car")
	await _wait(2)
	var bal := Game.career.player_team().finance.balance
	hub.content.get_child(0)._upgrade("engine")
	await _wait(2)
	_expect(Game.career.player_team().finance.balance < bal, "upgrade spent money")
	hub.show_page("weekend")
	await _wait(3)
	await _shot("05_weekend")
	hub.content.get_child(0)._qualify()
	await _wait(3)
	await _shot("06_qualifying")
	_expect(Game.career.has_qualified(), "qualified")
	hub.content.get_child(0)._start_race()
	await _wait(5)
	var race = main.current
	race._set_speed(8)
	for i in 240:
		await get_tree().process_frame
	await _shot("07_race")
	race.view.follow_idx = race.sim.cars.size() - 1
	for c in race.sim.cars:
		if c.team.id == race.player_team_id:
			race.view.follow_idx = c.idx
			race._set_mode(c.idx, RaceCar.Mode.PUSH)
	await _wait(30)
	await _shot("08_race_follow")
	race._sim_to_end()
	var guard := 0
	while not race.sim.done and guard < 3000:
		await get_tree().process_frame
		guard += 1
	_expect(race.sim.done, "sim to end finished")
	await _wait(3)
	await _shot("09_race_finished")
	var round_before := Game.career.round_idx
	race._go_results()
	await _wait(5)
	_expect(Game.career.round_idx == round_before + 1, "round advanced after results")
	await _shot("10_results")
	main.current._continue()
	await _wait(5)
	await _shot("11_dashboard_after")
	# save + load roundtrip through UI
	main.current.show_page("saves")
	await _wait(2)
	main.current.content.get_child(0)._save("slot1")
	await _wait(2)
	main.current.content.get_child(0)._load("slot1")
	await _wait(5)
	_expect(Game.career.round_idx == round_before + 1, "loaded career matches")
	main.current.show_page("standings")
	await _wait(3)
	await _shot("12_standings")
	main.toggle_debug()
	await _wait(3)
	await _shot("13_debug")
	main.toggle_debug()
	Game.goto("library")
	await _wait(5)
	await _shot("14_library")
	Game.goto("custom_race")
	await _wait(5)
	await _shot("15_custom_race")
	main.current._start()
	await _wait(5)
	main.current._set_speed(8)
	for i in 120:
		await get_tree().process_frame
	await _shot("16_custom_race_running")
	SaveSystem.delete_slot("slot1")
	if _created_track != "":
		DataDB.delete_user_track(_created_track)


var _created_track := ""


func _editor_flow() -> void:
	Game.goto("editor", {"back": "menu"})
	await _wait(5)
	var ed = main.current
	await _shot("20_editor_empty")
	# freehand draw: feed a stroke through the canvas like a mouse drag would
	var cv: TrackEditorCanvas = ed.canvas
	ed.set_tool(TrackEditorCanvas.Tool.DRAW)
	var stroke := PackedVector2Array()
	for i in 160:
		var a := TAU * i / 160.0
		stroke.append(Vector2(cos(a) * (650.0 + 180.0 * sin(2.0 * a)), sin(a) * 420.0 + 90.0 * cos(3.0 * a)))
	cv._stroke = stroke
	cv._finish_stroke()
	await _wait(3)
	_expect(ed.track.points.size() >= 6, "drawn track has control points")
	_expect(ed.track.is_valid(), "drawn track valid: " + str(ed.track.validate()))
	ed.fit_view()
	await _wait(3)
	await _shot("21_editor_drawn")
	# select a point and raise it + bank it
	ed.select_point(2)
	ed.push_undo()
	ed._set_prop("elev", 12.0)
	ed._set_prop("bank", 10.0)
	ed._set_prop("runoff", 3.0)
	ed._full_rebuild()
	await _wait(3)
	_expect(ed.track.stats["elevation_change_m"] > 5.0, "elevation applied")
	ed.undo()
	await _wait(2)
	_expect(ed.track.stats["elevation_change_m"] < 1.0, "undo restores")
	ed.redo()
	ed.track.name = "Smoke Test Ring"
	ed._name_edit.text = ed.track.name
	await _shot("22_editor_point")
	# race mode on the unsaved layout
	ed._toggle_mode()
	ed._race_speed = 8
	for i in 150:
		await get_tree().process_frame
	_expect(ed._race_sim != null and ed._race_sim.time > 5.0, "race mode runs")
	await _shot("23_editor_race_mode")
	ed._toggle_mode()
	_expect(ed.save(), "editor save")
	_created_track = ed.track.id
	_expect(DataDB.tracks.has(_created_track), "saved track in database")
	Game.goto("library", {"back": "menu", "select": _created_track})
	await _wait(5)
	await _shot("24_library_custom")
	Game.goto("custom_race", {"track_id": _created_track})
	await _wait(5)
	_expect(main.current.track_ids[main.current.track_idx] == _created_track, "custom race preselects track")


func _settings_flow() -> void:
	Game.goto("settings", {"back": "menu"})
	await _wait(4)
	await _shot("25_settings_general")
	for sec in ["display", "audio", "race", "controls"]:
		main.current._show(sec)
		await _wait(2)
	await _shot("26_settings_race")
	Game.set_setting("units", "imperial")
	await _wait(3)
	_expect(Fmt.speed(100.0) == "62 mph", "imperial units")
	Game.set_setting("units", "metric")
	Game.set_setting("language", "en")
	await _wait(3)
	_expect(TranslationServer.translate("Settings") == "Settings", "switch to English")
	await _shot("27_settings_english")
	Game.set_setting("language", "ko")
	await _wait(3)
