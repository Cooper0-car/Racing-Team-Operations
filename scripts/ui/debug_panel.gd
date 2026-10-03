extends PanelContainer
## Developer tools (F12). Operates on the current career and/or running race.


func _ready() -> void:
	add_theme_stylebox_override("panel", UI._box(Color(0.05, 0.05, 0.07, 0.96), UI.WARN, 2, 6, 12, 12))
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(get_viewport_rect().size.x - 340, 70)
	custom_minimum_size.x = 320
	z_index = 200
	var v := UI.vbox(6)
	add_child(v)
	v.add_child(UI.label("DEBUG MENU (F12)", 14, UI.WARN, true))
	v.add_child(UI.button("Add $10M", _money))
	v.add_child(UI.button("Max all player components", _max_car))
	v.add_child(UI.button("Repair all wear (player)", _repair))
	v.add_child(UI.button("Player drivers: +10 all attributes", _boost_drivers))
	v.add_child(UI.button("Skip race (simulate instantly)", _skip_race))
	v.add_child(UI.button("Race: set player tyre wear 90%", _wear))
	v.add_child(UI.button("Race: force failure on player car", _fail))
	v.add_child(UI.button("Race: everyone Push mode", _push_all))
	v.add_child(UI.button("Reload data files", func(): DataDB.reload(); _msg("Data reloaded")))
	v.add_child(UI.button("Close", func(): get_parent().toggle_debug()))


func _msg(t: String) -> void:
	UI.toast(get_parent(), t, UI.WARN)


func _career_ok() -> bool:
	if Game.career == null:
		_msg("No career loaded")
		return false
	return true


func _refresh_hub() -> void:
	var cur = get_parent().current
	if cur and cur.has_method("refresh"):
		cur.refresh()


func _money() -> void:
	if _career_ok():
		var c := Game.career
		c.player_team().finance.add(10000000, "Debug", "Debug money", c.season, c.round_idx)
		_refresh_hub()


func _max_car() -> void:
	if _career_ok():
		for cid in Game.career.player_team().car.components:
			var comp: CarComponent = Game.career.player_team().car.components[cid]
			comp.performance = 95.0
			comp.reliability = 95.0
			comp.wear = 0.0
		_refresh_hub()


func _repair() -> void:
	if _career_ok():
		for cid in Game.career.player_team().car.components:
			Game.career.player_team().car.components[cid].wear = 0.0
		_refresh_hub()


func _boost_drivers() -> void:
	if _career_ok():
		for did in Game.career.player_team().driver_ids:
			var d: Driver = Game.career.drivers[did]
			for k in d.attributes:
				d.attributes[k] = mini(99, int(d.attributes[k]) + 10)
		_refresh_hub()


func _skip_race() -> void:
	if not _career_ok():
		return
	var c := Game.career
	if c.is_season_over():
		_msg("Season over — end it first")
		return
	var track := TrackData.load_id(c.next_track_id())
	if not c.has_qualified():
		c.run_qualifying(track)
	var sim := RaceSimulation.new()
	sim.setup(track, c.grid_entries(), c.race_laps(track), c.rng.randi(), c.player_team_id)
	sim.run_to_end()
	var summary := c.apply_race_result(track, sim.results())
	Game.autosave()
	Game.goto("results", {"mode": "career", "sim": sim, "results": sim.results(), "summary": summary})


func _race_sim() -> RaceSimulation:
	var cur = get_parent().current
	if cur and "sim" in cur and cur.sim is RaceSimulation:
		return cur.sim
	_msg("No race running")
	return null


func _wear() -> void:
	var s := _race_sim()
	if s:
		for c in s.cars:
			if s.is_player_car(c):
				c.tire_wear = 0.9


func _fail() -> void:
	var s := _race_sim()
	if s:
		for c in s.cars:
			if s.is_player_car(c) and c.is_running():
				s._retire(c, "Debug failure")
				s._event(c, "failure", "%s retires (debug failure)." % c.driver.last_name)
				return


func _push_all() -> void:
	var s := _race_sim()
	if s:
		for c in s.cars:
			c.mode = RaceCar.Mode.PUSH
