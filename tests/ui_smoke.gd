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
	await _shot("01_menu")
	Game.goto("team_creation")
	await _wait(3)
	var tc = main.current
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
