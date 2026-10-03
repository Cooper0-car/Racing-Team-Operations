class_name RaceSimulation
extends RefCounted
## Deterministic, UI-independent race simulation. Call step(dt) repeatedly.
## The UI only reads state and sends commands (set_mode).

signal event_added(ev: Dictionary)
signal race_finished

const DT := 1.0 / 30.0
const CAR_LEN := 5.5
const FOLLOW_GAP := 7.0
const GRID_SPACING := 8.0
const CHECKPOINTS_PER_LAP := 20
const START_COUNTDOWN := 3.0

var track: TrackData
var cars: Array = []                # Array[RaceCar]
var order: Array = []               # cars sorted by race position
var total_laps: int = 10
var time: float = -START_COUNTDOWN  # negative during start-light countdown
var checkered: bool = false
var done: bool = false
var player_team_id: String = ""
var drs_enabled := true
var events: Array = []
var rng := RandomNumberGenerator.new()
var first_cp_time: Dictionary = {}
var fastest_lap: Dictionary = {"time": INF, "car": null, "lap": 0}
var tick: float = DT                # fixed step (Settings → Simulation detail)
var _accum: float = 0.0
var _order_timer: float = 0.0
var _cp_len: float = 0.0


## grid: Array of {driver: Driver, team: Team} in starting order (pole first).
func setup(p_track: TrackData, grid: Array, laps: int, seed_value: int, p_player_team_id: String = "") -> void:
	track = p_track
	total_laps = laps
	player_team_id = p_player_team_id
	rng.seed = seed_value
	_cp_len = track.length / CHECKPOINTS_PER_LAP
	cars.clear()
	for i in grid.size():
		var e: Dictionary = grid[i]
		var c := RaceCar.new()
		c.idx = i
		c.driver = e["driver"]
		c.team = e["team"]
		c.color = c.team.primary
		c.label = c.driver.short_name()
		c.params = PerformanceModel.with_driver(PerformanceModel.car_params(c.team.car.dimensions()), c.driver)
		c.profile = PerformanceModel.speed_profile(track, c.params)
		c.base_mult = PerformanceModel.driver_factor(c.driver, c.team, false)
		c.potential_lap = PerformanceModel.lap_time(track, c.profile, c.base_mult)
		c.tu_mult = 1.3 - 0.6 * c.team.car.dimensions()["tire_usage"] / 100.0
		c.grid_pos = i + 1
		c.position = i + 1
		# grid: two columns, staggered
		c.progress = -(i * GRID_SPACING) - 6.0
		c.lateral = (-1.0 if i % 2 == 0 else 1.0) * track.width_at[0] * 0.22 - track.line_offset[0]
		c.lateral_target = c.lateral
		c.start_delay = 0.18 + (100.0 - c.driver.attr("starts")) / 100.0 * 0.45 + rng.randf() * 0.15
		c.lap_variation = _roll_lap_variation(c)
		cars.append(c)
	order = cars.duplicate()


func is_player_car(c: RaceCar) -> bool:
	return c.team.id == player_team_id


func set_mode(car_idx: int, mode: int) -> void:
	var c: RaceCar = cars[car_idx]
	if c.mode != mode:
		c.mode = mode
		if is_player_car(c):
			_event(c, "order", "%s: %s mode.", [c.driver.last_name, tr(RaceCar.MODE_NAMES[mode])])


## Advance by real delta (already multiplied by game speed). Uses fixed sub-steps.
func advance(delta: float) -> void:
	_accum += delta
	var guard := 0
	while _accum >= tick and not done and guard < 4000:
		step(tick)
		_accum -= tick
		guard += 1


func run_to_end(max_time: float = 36000.0) -> void:
	while not done and time < max_time:
		step(tick)


func step(dt: float) -> void:
	if done:
		return
	time += dt
	if time < 0.0:
		return
	var running := []
	for c in cars:
		if c.is_running():
			running.append(c)
		elif c.finished:
			c.speed = move_toward(c.speed, 30.0, 10.0 * dt)
			c.progress += c.speed * dt
			c.lateral = move_toward(c.lateral, track.width_at[track.index_at(c.progress)] * 0.35, 2.0 * dt)
	var lens := PackedFloat64Array()
	lens.resize(running.size())
	for i in running.size():
		lens[i] = fposmod(running[i].progress, track.length)
	for i in running.size():
		# nearest car in front on the track surface (ignores lap count)
		var best := -1
		var best_d := INF
		var my := lens[i]
		for j in running.size():
			if j == i:
				continue
			var d := lens[j] - my
			if d < 0.0:
				d += track.length
			if d < best_d:
				best_d = d
				best = j
		_update_car(running[i], running[best] if best >= 0 else null, dt)
	_order_timer -= dt
	if _order_timer <= 0.0 or checkered:
		_order_timer = 0.2
		_update_order()
	if checkered:
		var any := false
		for c in cars:
			if c.is_running():
				any = true
				break
		if not any:
			_update_order()
			done = true
			race_finished.emit()


func _update_car(c: RaceCar, ahead: RaceCar, dt: float) -> void:
	if time < c.start_delay:
		return
	var idx := track.index_at(c.progress)
	var target := c.profile[idx] * c.base_mult * c.mode_factor() * c.tire_factor() * c.damage_mult * (1.0 + c.lap_variation)

	# incidents (lock-ups, spins, off-track) slow the car for a while
	if c.incident_time > 0.0:
		c.incident_time -= dt
		target *= c.incident_factor
		if c.incident_time <= 0.0:
			c.lateral_target = 0.0

	# traffic + slipstream + overtaking
	c.blocked = false
	if c.pass_timer > 0.0:
		c.pass_timer -= dt
		var pt := c.pass_target
		if pt != null and fposmod(c.progress - pt.progress, track.length) > CAR_LEN + 1.0 and fposmod(c.progress - pt.progress, track.length) < track.length * 0.5:
			# pass completed (lapping a backmarker doesn't count as an overtake)
			if pt.progress > c.progress - track.length * 0.5:
				c.overtakes += 1
				pt.times_overtaken += 1
			if (is_player_car(c) or is_player_car(pt)) and pt.progress > c.progress - track.length * 0.5:
				_event(c, "overtake", "%s overtakes %s.", [c.driver.last_name, pt.driver.last_name])
			c.pass_timer = 0.0
		if c.pass_timer <= 0.0:
			c.lateral_target = 0.0
			c.pass_target = null
	if ahead != null and ahead != c:
		var gap := _gap_metres(c, ahead)
		if gap < 45.0 and track.radius[idx] > 400.0:
			target *= 1.0 + 0.02 * (1.0 - gap / 45.0)       # slipstream
		var passing := c.pass_timer > 0.0 and c.pass_target == ahead
		if passing:
			target *= 1.04
		if gap < FOLLOW_GAP + c.speed * 0.12 and not passing:
			_try_overtake(c, ahead, idx, gap)
			if c.pass_timer <= 0.0 or c.pass_target != ahead:
				c.blocked = true
				var cap := ahead.speed * (0.985 if gap < FOLLOW_GAP else 1.0)
				target = minf(target, cap)

	# DRS: activated at the detection point when within 1 s of the car ahead (from lap 2)
	var det: int = track.drs_detect_at[idx]
	if det >= 0 and c.drs_zone != det and c.drs_checked != det:
		c.drs_checked = det
		c.drs_zone = -1
		if drs_enabled and c.laps_done >= 1 and interval_to_ahead(c) < 1.0:
			c.drs_zone = det
			if is_player_car(c) and not c.radio_flags.has("drs_%d" % c.laps_done):
				c.radio_flags["drs_%d" % c.laps_done] = true
				_event(c, "radio", "Engineer to %s: \"DRS enabled. Go for it!\"", [c.driver.last_name])
	if c.drs_zone >= 0:
		if track.drs_at[idx] == c.drs_zone:
			target *= 1.035
			c.drs_boost = 2.5
		elif c.drs_boost <= 0.0:
			c.drs_zone = -1
	if c.drs_boost > 0.0:
		c.drs_boost -= dt

	# driving physics
	if c.speed < target:
		c.speed = minf(target, c.speed + PerformanceModel.accel_at(c.params, c.speed) * dt)
	else:
		c.speed = maxf(target, c.speed - PerformanceModel.decel_at(c.params, c.speed) * 1.6 * dt)
	var prev := c.progress
	c.progress += c.speed * dt
	c.lateral = move_toward(c.lateral, c.lateral_target, 3.0 * dt)

	# tyre wear: more in corners (lateral load), modulated by car, driver, mode
	var dims_tu := c.tu_mult
	var lat_load := minf(c.speed * c.speed / track.radius[idx], 40.0)
	var wear_rate := (0.0000016 + lat_load * 0.0000004) * dims_tu
	wear_rate *= (1.25 - c.driver.attr("tire_management") / 200.0) * c.mode_wear() * float(c.team.mod("tire_wear_mult", 1.0))
	c.tire_wear = minf(c.tire_wear + wear_rate * c.speed * dt, 1.0)

	_check_corner_mistake(c, idx)
	_check_sectors_and_laps(c, prev)


func _gap_metres(c: RaceCar, ahead: RaceCar) -> float:
	var g := fposmod(ahead.progress - c.progress, track.length)
	return g - CAR_LEN


func _try_overtake(c: RaceCar, ahead: RaceCar, idx: int, gap: float) -> void:
	# blue flags: a lapped car lets the faster car through
	if ahead.progress < c.progress:
		_start_pass(c, ahead, 0.9)
		return
	# opportunities happen at braking zones after straights
	var zi: int = track.zone_at[idx]
	if zi >= 0 and c.attempted_zone != zi:
		var z: Dictionary = track.overtake_zones[zi]
		c.attempted_zone = zi
		var pace_adv := (ahead.potential_lap * (1.0 + ahead.lap_variation) / ahead.tire_factor()) / (c.potential_lap * (1.0 + c.lap_variation) / c.tire_factor()) - 1.0
		var skill := (c.driver.attr("overtaking") + c.driver.attr("racecraft")) * 0.5 - (ahead.driver.attr("defending") + ahead.driver.attr("racecraft")) * 0.5
		var width_f := clampf((track.width_at[zi_idx_safe(z)] - 9.0) / 10.0, 0.0, 1.0)
		var brake_f: float = (c.params["mu_brake"] - ahead.params["mu_brake"]) * 0.3
		var aggr := c.driver.attr("aggression") / 100.0
		var chance: float = 0.06 + pace_adv * 12.0 + skill / 100.0 * 0.6 + z["strength"] * 0.35 + width_f * 0.12 + brake_f
		chance += 0.08 if c.mode == RaceCar.Mode.PUSH else 0.0
		chance += 0.22 if c.drs_boost > 0.0 else 0.0
		chance -= 0.05 if ahead.mode == RaceCar.Mode.PUSH else 0.0
		chance = clampf(chance, 0.02, 0.9)
		# driver decides whether to attempt at all
		var willing := pace_adv > -0.002 or aggr > 0.7
		if not willing:
			return
		if rng.randf() < chance:
			_start_pass(c, ahead, 0.85)
		else:
			# failed lunge: small time loss, and a chance of contact
			c._start_incident(0.15, 0.9)
			var contact := 0.035 * (c.driver.attr("aggression") + c.driver.attr("risk_taking")) / 140.0 * c.mode_risk()
			contact *= 1.4 - width_f * 0.6
			if rng.randf() < contact:
				_collision(c, ahead)
		return


func zi_idx_safe(z: Dictionary) -> int:
	return clampi(int(z["index"]), 0, track.samples.size() - 1)


func _start_pass(c: RaceCar, ahead: RaceCar, ahead_factor: float) -> void:
	c.pass_timer = 4.0
	c.pass_target = ahead
	var i := track.index_at(c.progress)
	# pass on the side with more room relative to the racing line
	var room_left := track.width_at[i] * 0.5 + track.line_offset[i]
	var room_right := track.width_at[i] * 0.5 - track.line_offset[i]
	c.lateral_target = (3.2 if room_right > room_left else -3.2)
	ahead._start_incident(1.5, ahead_factor)


func _collision(c: RaceCar, other: RaceCar) -> void:
	c.mistakes += 1
	var roll := rng.randf()
	if roll < 0.12:
		_retire(c, "Collision damage")
		c.incidents.append(["Collision with %s (retired)", [other.driver.last_name]])
		_event(c, "incident", "CONTACT! %s hits %s and is out of the race.", [c.driver.last_name, other.driver.last_name])
	else:
		c.damage_mult *= 0.985
		c._start_incident(2.5, 0.4)
		other._start_incident(1.2, 0.6)
		c.incidents.append(["Contact with %s (front wing damage)", [other.driver.last_name]])
		_event(c, "incident", "Contact between %s and %s. %s has front wing damage.", [c.driver.last_name, other.driver.last_name, c.driver.last_name])


func _check_corner_mistake(c: RaceCar, idx: int) -> void:
	# evaluate once per corner, at corner entry
	var ci: int = track.corner_start_at[idx]
	if ci >= 0 and c.last_corner_checked != ci:
		var corner: Dictionary = track.corners[ci]
		c.last_corner_checked = ci
		var severity := clampf(120.0 / maxf(corner["min_radius"], 15.0), 0.3, 4.0)
		var p := 0.0009 * severity
		p *= 1.6 - c.driver.attr("consistency") / 100.0
		p *= 1.4 - c.driver.attr("concentration") / 200.0
		p *= 0.7 + c.driver.attr("risk_taking") / 150.0
		p *= c.mode_risk()
		p *= 1.0 + c.tire_wear * 1.5
		if c.blocked:
			p *= 1.3
		if rng.randf() < p:
			_mistake(c)
		return


func _mistake(c: RaceCar) -> void:
	c.mistakes += 1
	var runoff: float = track.runoff_at[track.index_at(c.progress)]
	# little runoff = walls close by: off-track moments become crashes
	var wall_risk := clampf(6.0 / (runoff + 2.0), 0.0, 1.0)
	var r := rng.randf()
	if r >= 0.55 and r < 0.85 and rng.randf() < wall_risk * 0.35:
		r = 0.99
	if r < 0.55:
		c._start_incident(0.5 + rng.randf() * 0.6, 0.55)
		c.incidents.append(["Lock-up lap %d", [c.current_lap()]])
		_event(c, "mistake", "%s locks up and runs wide.", [c.driver.last_name])
	elif r < 0.85:
		var loss := (1.2 + rng.randf() * 2.0) * clampf(0.6 + runoff / 40.0, 0.6, 1.6)
		c._start_incident(loss, 0.45)
		c.lateral_target = (track.width_at[track.index_at(c.progress)] * 0.5 + minf(runoff, 8.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
		c.incidents.append(["Off track lap %d", [c.current_lap()]])
		_event(c, "mistake", "%s goes off track!", [c.driver.last_name])
	elif r < 0.98:
		c._start_incident(4.0 + rng.randf() * 3.0, 0.1)
		c.speed *= 0.2
		c.incidents.append(["Spin lap %d", [c.current_lap()]])
		_event(c, "mistake", "%s SPINS!", [c.driver.last_name])
	else:
		_retire(c, "Crashed")
		c.incidents.append(["Crash lap %d", [c.current_lap()]])
		_event(c, "incident", "CRASH! %s is into the barriers.", [c.driver.last_name])
		if runoff < 6.0:
			pass


func _check_sectors_and_laps(c: RaceCar, prev: float) -> void:
	if c.progress < 0.0:
		return
	# checkpoints (for gaps)
	var cp_prev := int(floor(prev / _cp_len)) if prev >= 0.0 else -1
	var cp_now := int(floor(c.progress / _cp_len))
	if cp_now > cp_prev:
		c.cp_times[cp_now] = time
		if not first_cp_time.has(cp_now):
			first_cp_time[cp_now] = time
		c.cp_times.erase(cp_now - CHECKPOINTS_PER_LAP * 2)
	# sectors
	var sec := track.sector_of(c.progress)
	if prev >= 0.0 and sec != c.cur_sector and sec == c.cur_sector + 1:
		c.cur_sectors[c.cur_sector] = time - c.sector_start
		c.sector_start = time
		c.cur_sector = sec
	# lap line
	var lap_prev := int(floor(prev / track.length)) if prev >= 0.0 else -1
	var lap_now := int(floor(c.progress / track.length))
	if lap_now > lap_prev:
		if lap_now == 0:
			c.lap_start_time = time    # crossed the line from the grid
			c.sector_start = time
			c.cur_sector = 0
			return
		_complete_lap(c)


func _complete_lap(c: RaceCar) -> void:
	var lt := time - c.lap_start_time
	c.cur_sectors[2] = time - c.sector_start
	c.last_sectors = c.cur_sectors.duplicate()
	for s in 3:
		c.best_sectors[s] = minf(c.best_sectors[s], c.cur_sectors[s])
	c.lap_start_time = time
	c.sector_start = time
	c.cur_sector = 0
	c.laps_done += 1
	c.lap_times.append(lt)
	c.tire_by_lap.append(c.tire_wear)
	c.attempted_zone = -1
	c.last_corner_checked = -1
	c.lap_variation = _roll_lap_variation(c)
	if lt < c.best_lap:
		c.best_lap = lt
	if lt < fastest_lap["time"]:
		fastest_lap = {"time": lt, "car": c, "lap": c.laps_done}
	if c.is_running() and (checkered or c.laps_done >= total_laps):
		if not checkered:
			checkered = true
			_event(c, "flag", "CHEQUERED FLAG! %s wins the race!", [c.driver.full_name()])
		c.finished = true
		c.finish_time = time
		c.lateral_target = 0.0
		return
	_check_reliability(c)
	_radio(c)


func _roll_lap_variation(c: RaceCar) -> float:
	var spread := (100.0 - c.driver.attr("consistency")) * 0.00009 + 0.0008
	return rng.randfn(0.0, spread)


func _check_reliability(c: RaceCar) -> void:
	if not c.is_running():
		return
	var total := 0.0
	var weights := []
	for cid in c.team.car.components:
		var comp: CarComponent = c.team.car.components[cid]
		var p := comp.failure_chance_per_lap() * (1.3 if c.mode == RaceCar.Mode.PUSH else 1.0)
		total += p
		weights.append([comp, p])
	if rng.randf() >= total:
		return
	var pick := rng.randf() * total
	var failed: CarComponent = weights[0][0]
	for w in weights:
		pick -= w[1]
		if pick <= 0.0:
			failed = w[0]
			break
	if rng.randf() < 0.55:
		var part: String = failed.def().get("name", failed.id)
		_retire(c, "%s failure", part)
		c.incidents.append(["%s failure (retired)", [part]])
		_event(c, "failure", "%s retires: %s failure.", [c.driver.last_name, failed.display_name()])
	else:
		c.damage_mult *= 0.975
		c.incidents.append(["%s problem", [failed.def().get("name", failed.id)]])
		_event(c, "failure", "%s has a %s problem and is losing time.", [c.driver.last_name, failed.display_name()])


## reason: untranslated key (may contain %s, filled with arg).
func _retire(c: RaceCar, reason: String, arg: String = "") -> void:
	c.dnf = true
	c.dnf_reason = reason
	c.dnf_arg = arg
	c.speed = 0.0
	c.finish_time = time


func _update_order() -> void:
	order = cars.duplicate()
	order.sort_custom(_order_less)
	for i in order.size():
		order[i].position = i + 1
	# record positions at the moment the leader completes each lap
	var leader: RaceCar = order[0]
	while leader.positions_by_lap.size() < leader.laps_done:
		for c in order:
			c.positions_by_lap.append(c.position)


func _order_less(a: RaceCar, b: RaceCar) -> bool:
	if a.dnf != b.dnf:
		return b.dnf
	if a.finished and b.finished:
		if a.laps_done != b.laps_done:
			return a.laps_done > b.laps_done
		return a.finish_time < b.finish_time
	if a.dnf and b.dnf:
		return a.progress > b.progress
	# a finished car with the same laps is ahead of a running car
	if a.finished != b.finished:
		var la := a.laps_done
		var lb := b.laps_done
		if la != lb:
			return la > lb
		return a.finished
	return a.progress > b.progress


## Gap to leader in seconds (or "+N L" lapped). Returns {"text", "seconds"}.
func gap_to_leader(c: RaceCar) -> Dictionary:
	var leader: RaceCar = order[0]
	if c == leader:
		return {"text": tr("Leader"), "seconds": 0.0}
	if c.dnf:
		return {"text": "DNF", "seconds": INF}
	if c.finished and leader.finished and c.laps_done == leader.laps_done:
		var g := c.finish_time - leader.finish_time
		return {"text": "+%.3f" % g, "seconds": g}
	var laps_down := int(floor((leader.progress - c.progress) / track.length))
	if c.finished:
		laps_down = leader.laps_done - c.laps_done
	if laps_down >= 1:
		return {"text": tr("+%d lap(s)") % laps_down, "seconds": 9999.0 + laps_down}
	var cp := int(floor(c.progress / _cp_len))
	if c.cp_times.has(cp) and first_cp_time.has(cp):
		var g2: float = c.cp_times[cp] - first_cp_time[cp]
		return {"text": "+%.1f" % g2, "seconds": g2}
	return {"text": "-", "seconds": 0.0}


func interval_to_ahead(c: RaceCar) -> float:
	if c.position <= 1:
		return 0.0
	var a: RaceCar = order[c.position - 2]
	var cp := int(floor(c.progress / _cp_len))
	if c.cp_times.has(cp) and a.cp_times.has(cp):
		return c.cp_times[cp] - a.cp_times[cp]
	return INF


func _radio(c: RaceCar) -> void:
	if not is_player_car(c) or not c.is_running():
		return
	var name := c.driver.last_name
	if c.tire_wear > 0.5 and not c.radio_flags.has("tire50"):
		c.radio_flags["tire50"] = true
		_event(c, "radio", "%s: \"Tyres are starting to go off.\" (wear %d%%)", [name, int(c.tire_wear * 100)])
	if c.tire_wear > 0.8 and not c.radio_flags.has("tire80"):
		c.radio_flags["tire80"] = true
		_event(c, "radio", "%s: \"No grip left on these tyres!\" Consider Conserve mode.", [name])
	var gap_ahead := interval_to_ahead(c)
	if gap_ahead < 1.0 and c.position > 1:
		var a: RaceCar = order[c.position - 2]
		if a.tire_wear > c.tire_wear + 0.15:
			_event(c, "radio", "Engineer: \"%s ahead is struggling on old tyres. He's vulnerable.\"", [a.driver.last_name])
	# sector comparison with teammate
	for o in cars:
		if o != c and o.team == c.team and o.is_running() and o.laps_done == c.laps_done and c.laps_done % 3 == 0:
			for s in 3:
				var d: float = c.last_sectors[s] - o.last_sectors[s]
				if d > 0.35:
					_event(c, "radio", "Engineer to %s: \"You're losing %.1fs to %s in sector %d.\"", [name, d, o.driver.last_name, s + 1])
					break


## key is translated now (events are only shown live); args are inserted as-is.
func _event(c: RaceCar, type: String, key: String, args: Array = []) -> void:
	var text := tr(key) % args if args.size() > 0 else tr(key)
	var ev := {"time": maxf(time, 0.0), "lap": c.current_lap() if c else 0, "type": type, "text": text,
		"car": c.idx if c else -1, "player": c != null and is_player_car(c)}
	events.append(ev)
	event_added.emit(ev)


## Final classification for the career system.
func results() -> Array:
	var out := []
	for c in order:
		out.append({
			"driver_id": c.driver.id, "team_id": c.team.id, "position": c.position, "grid": c.grid_pos,
			"laps": c.laps_done, "time": c.finish_time, "best_lap": c.best_lap if c.best_lap < INF else 0.0,
			"dnf": c.dnf, "dnf_reason": c.dnf_reason, "dnf_arg": c.dnf_arg, "overtakes": c.overtakes, "mistakes": c.mistakes,
			"lap_times": c.lap_times.duplicate(), "positions": c.positions_by_lap.duplicate(),
			"tire_by_lap": c.tire_by_lap.duplicate(), "incidents": c.incidents.duplicate(),
			"best_sectors": c.best_sectors.duplicate(), "potential_lap": c.potential_lap,
			"fastest_lap": fastest_lap["car"] == c,
		})
	return out
