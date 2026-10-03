class_name Career
extends RefCounted
## Whole career state. Everything here is serialised by SaveSystem.

const SAVE_VERSION := 1
const DIFFICULTY := {
	"easy":       {"name": "Easy",       "ai_budget": 0.8, "ai_dev": 0.8, "player_income": 1.15},
	"normal":     {"name": "Normal",     "ai_budget": 1.0, "ai_dev": 1.0, "player_income": 1.0},
	"hard":       {"name": "Hard",       "ai_budget": 1.2, "ai_dev": 1.15, "player_income": 0.9},
	"simulation": {"name": "Simulation", "ai_budget": 1.0, "ai_dev": 1.1, "player_income": 0.9},
}

var season: int = 1
var round_idx: int = 0
var championship_id: String = ""
var calendar: Array = []                 # track ids
var difficulty: String = "normal"
var player_team_id: String = ""
var teams: Dictionary = {}               # id -> Team
var team_order: Array = []               # stable display order
var drivers: Dictionary = {}             # id -> Driver
var driver_points: Dictionary = {}
var team_points: Dictionary = {}
var round_results: Array = []            # per round: {track_id, track_name, results, quali}
var history: Array = []                  # past seasons summary
var notifications: Array = []
var weekend: Dictionary = {}             # {round, quali:[{driver_id, team_id, best, sectors}], grid:[driver_ids]}
var rng_state: int = 0
var rng := RandomNumberGenerator.new()


# ------------------------------------------------------------ creation

## setup: {name, abbr, primary, secondary, logo_shape, budget_id, hq, car_level, philosophy, driver_ids, difficulty}
static func create(setup: Dictionary) -> Career:
	var c := Career.new()
	c.rng.randomize()
	c.difficulty = setup.get("difficulty", "normal")
	var champ: Dictionary = DataDB.championships[0]
	c.championship_id = champ["id"]
	c.calendar = champ["calendar"].duplicate()
	var diff: Dictionary = DIFFICULTY[c.difficulty]
	for d in DataDB.drivers:
		var dr := Driver.from_dict(d)
		dr.contract_years = c.rng.randi_range(1, 3)
		c.drivers[dr.id] = dr
	for td in DataDB.teams:
		var t := Team.new()
		t.id = td["id"]; t.name = td["name"]; t.abbr = td["abbr"]
		t.primary = Color.html(td["primary"]); t.secondary = Color.html(td["secondary"])
		t.logo_shape = c.rng.randi_range(0, 5)
		t.philosophy = td.get("philosophy", "balanced")
		t.reputation = float(td.get("reputation", 50))
		t.car = Car.create(float(td["perf"]), float(td["rel"]), c.rng)
		t.finance.balance = int(float(td["budget"]) * diff["ai_budget"])
		t.driver_ids = td["drivers"].duplicate()
		for did in t.driver_ids:
			c.drivers[did].team_id = t.id
		c.teams[t.id] = t
		c.team_order.append(t.id)
	# player team
	var bal: Dictionary = DataDB.balance
	var p := Team.new()
	p.id = "team_player"
	p.is_player = true
	p.name = setup.get("name", "My Racing Team")
	p.abbr = setup.get("abbr", "MRT")
	p.primary = setup.get("primary", Color("#e10600"))
	p.secondary = setup.get("secondary", Color.WHITE)
	p.logo_shape = int(setup.get("logo_shape", 0))
	p.hq = setup.get("hq", "uk")
	p.philosophy = setup.get("philosophy", "balanced")
	p.reputation = float(bal.get("reputation_start", 35)) + float(p.hq_bonus().get("reputation", 0))
	var lvl := DataDB.find_in(bal["car_levels"], setup.get("car_level", "mid"))
	var perf := float(lvl["perf"]) + float(p.mod("start_perf", 0))
	var rel := float(lvl["rel"]) + float(p.mod("start_rel", 0)) + float(p.hq_bonus().get("reliability", 0))
	p.car = Car.create(perf, rel, c.rng)
	for cid in p.hq_bonus().get("component_bonus", {}):
		p.car.components[cid].performance += float(p.hq_bonus()["component_bonus"][cid])
	var budget := DataDB.find_in(bal["budgets"], setup.get("budget_id", "medium"))
	p.finance.balance = int(float(budget["amount"]) * float(lvl["budget_mult"]) * float(p.mod("budget_mult", 1.0)))
	p.finance.add(0, "Start", "Team founded", 1, 0)
	p.driver_ids = setup.get("driver_ids", []).duplicate()
	for did in p.driver_ids:
		var dr: Driver = c.drivers[did]
		dr.team_id = p.id
		dr.contract_years = 2
		dr.salary = c.player_salary_for(dr, p)
	c.teams[p.id] = p
	c.team_order.insert(0, p.id)
	c.player_team_id = p.id
	c._reset_standings()
	c.notify("Welcome to the %s, %s! First race: %s." % [champ["name"], p.name, c.next_track_name()], "info")
	return c


func player_salary_for(dr: Driver, team: Team) -> int:
	var s := float(dr.salary)
	if dr.age <= 22:
		s *= float(team.mod("young_salary_mult", 1.0))
	return int(s)


func _reset_standings() -> void:
	driver_points.clear()
	team_points.clear()
	for tid in teams:
		team_points[tid] = 0
		for did in teams[tid].driver_ids:
			driver_points[did] = 0
	round_results.clear()
	weekend.clear()


# ------------------------------------------------------------ queries

func player_team() -> Team:
	return teams[player_team_id]


func free_agents() -> Array:
	var out := []
	for did in drivers:
		if drivers[did].team_id == "":
			out.append(drivers[did])
	out.sort_custom(func(a, b): return a.overall() > b.overall())
	return out


func is_season_over() -> bool:
	return round_idx >= calendar.size()


func next_track_id() -> String:
	return "" if is_season_over() else calendar[round_idx]


func next_track_name() -> String:
	return DataDB.get_track(next_track_id()).get("name", "-")


func race_laps(track: TrackData) -> int:
	var champ := DataDB.get_championship(championship_id)
	return maxi(3, int(round(track.default_laps * float(champ.get("laps_scale", 1.0)))))


func entries() -> Array:
	var out := []
	for tid in team_order:
		var t: Team = teams[tid]
		for did in t.driver_ids:
			out.append({"driver": drivers[did], "team": t})
	return out


func driver_standings() -> Array:
	var out := []
	for did in driver_points:
		var d: Driver = drivers[did]
		out.append({"driver": d, "team": teams.get(d.team_id), "points": driver_points[did], "wins": _count_wins(did)})
	out.sort_custom(func(a, b): return a["points"] > b["points"] if a["points"] != b["points"] else a["wins"] > b["wins"])
	return out


func team_standings() -> Array:
	var out := []
	for tid in team_points:
		out.append({"team": teams[tid], "points": team_points[tid]})
	out.sort_custom(func(a, b): return a["points"] > b["points"])
	return out


func team_position(tid: String) -> int:
	var st := team_standings()
	for i in st.size():
		if st[i]["team"].id == tid:
			return i + 1
	return st.size()


func _count_wins(did: String) -> int:
	var n := 0
	for rr in round_results:
		if rr["results"].size() > 0 and rr["results"][0]["driver_id"] == did:
			n += 1
	return n


func notify(text: String, type: String = "info") -> void:
	notifications.push_front({"season": season, "round": round_idx, "text": text, "type": type})
	if notifications.size() > 60:
		notifications.resize(60)


# ------------------------------------------------------------ car development

func upgrade_cost(team: Team, cid: String) -> int:
	var c: CarComponent = team.car.components[cid]
	var base := float(c.def().get("base_cost", 300000))
	var growth := float(DataDB.balance.get("upgrade_cost_growth", 0.12))
	var cost := base * pow(1.0 + growth, c.level)
	cost *= float(team.hq_def().get("upgrade_cost_mult", 1.0))
	cost *= float(team.mod("upgrade_cost_mult", 1.0))
	return int(round(cost / 1000.0) * 1000)


func upgrade_gain(team: Team, cid: String) -> float:
	var c: CarComponent = team.car.components[cid]
	var step := float(DataDB.balance.get("upgrade_step_perf", 3.0)) + float(team.mod("upgrade_perf_bonus", 0.0))
	return step * clampf(1.15 - c.performance / 110.0, 0.15, 1.0)   # diminishing returns


func upgrade_component(team: Team, cid: String) -> bool:
	var cost := upgrade_cost(team, cid)
	if not team.finance.can_afford(cost):
		return false
	var c: CarComponent = team.car.components[cid]
	var gain := upgrade_gain(team, cid)
	c.performance = minf(c.performance + gain, 100.0)
	c.reliability = maxf(c.reliability - float(DataDB.balance.get("upgrade_reliability_penalty", 2.0)) - float(team.mod("upgrade_rel_penalty_bonus", 0.0)), 5.0)
	c.wear = 0.0
	c.level += 1
	team.finance.add(-cost, "Development", "%s upgrade (Lv %d)" % [c.display_name(), c.level], season, round_idx)
	if team.is_player:
		notify("%s upgraded to level %d (+%.1f performance)." % [c.display_name(), c.level, gain], "car")
	return true


func maintenance_cost(team: Team, cid: String) -> int:
	var c: CarComponent = team.car.components[cid]
	return int(round(c.wear * float(DataDB.balance.get("maintenance_cost_per_wear", 120000)) / 1000.0) * 1000)


func maintain_component(team: Team, cid: String) -> bool:
	var cost := maintenance_cost(team, cid)
	if cost <= 0 or not team.finance.can_afford(cost):
		return false
	team.car.components[cid].wear = 0.0
	team.finance.add(-cost, "Maintenance", "%s rebuilt" % team.car.components[cid].display_name(), season, round_idx)
	return true


## Spends money to raise reliability of a part (trading money for finishing races).
func reliability_cost(team: Team, cid: String) -> int:
	return int(upgrade_cost(team, cid) * 0.5)


func improve_reliability(team: Team, cid: String) -> bool:
	var cost := reliability_cost(team, cid)
	var c: CarComponent = team.car.components[cid]
	if c.reliability >= 99.0 or not team.finance.can_afford(cost):
		return false
	c.reliability = minf(c.reliability + 5.0, 99.0)
	team.finance.add(-cost, "Development", "%s reliability work" % c.display_name(), season, round_idx)
	return true


# ------------------------------------------------------------ race weekend

func run_qualifying(track: TrackData) -> Array:
	var q := Qualifying.run(track, entries(), rng)
	var quali := []
	var grid := []
	for r in q:
		quali.append({"driver_id": r["driver"].id, "team_id": r["team"].id, "best": r["best"], "sectors": r["sectors"], "mistake": r["mistake"]})
		grid.append(r["driver"].id)
	weekend = {"round": round_idx, "season": season, "track_id": track.id, "quali": quali, "grid": grid}
	if quali.size() > 0:
		drivers[quali[0]["driver_id"]].stats["poles"] += 1
	return quali


func has_qualified() -> bool:
	return weekend.get("round", -1) == round_idx and weekend.get("season", -1) == season and weekend.has("grid")


func grid_entries() -> Array:
	var out := []
	for did in weekend["grid"]:
		var d: Driver = drivers[did]
		out.append({"driver": d, "team": teams[d.team_id]})
	return out


## Apply the race outcome to the whole career. Returns a summary for the UI.
func apply_race_result(track: TrackData, results: Array) -> Dictionary:
	var bal: Dictionary = DataDB.balance
	var pts_table: Array = bal["points"]
	var prize_table: Array = bal["prize_per_position"]
	var rounds := float(calendar.size())
	var summary := {"points": {}, "prize": {}, "income": {}, "expenses": {}, "player_lines": []}
	var team_round_points := {}
	for tid in teams:
		team_round_points[tid] = 0
	# points + driver stats
	for r in results:
		var pos: int = r["position"]
		var pts := 0
		if not r["dnf"] and pos <= pts_table.size():
			pts = int(pts_table[pos - 1])
		r["points"] = pts
		driver_points[r["driver_id"]] = driver_points.get(r["driver_id"], 0) + pts
		team_points[r["team_id"]] = team_points.get(r["team_id"], 0) + pts
		team_round_points[r["team_id"]] += pts
		var d: Driver = drivers[r["driver_id"]]
		d.stats["starts"] += 1
		d.stats["points"] += pts
		if r["dnf"]:
			d.stats["dnfs"] += 1
		elif pos == 1:
			d.stats["wins"] += 1
		if not r["dnf"] and pos <= 3:
			d.stats["podiums"] += 1
	# per-team finance
	for tid in teams:
		var t: Team = teams[tid]
		var inc := 0
		for r in results:
			if r["team_id"] == tid:
				inc += int(prize_table[mini(r["position"] - 1, prize_table.size() - 1)]) if not r["dnf"] else int(prize_table[prize_table.size() - 1] * 0.5)
		var sponsor := int(float(bal["base_sponsor_per_race_at_rep_50"]) * (0.4 + t.reputation / 50.0 * 0.6) * float(t.hq_bonus().get("sponsor_mult", 1.0)))
		if t.is_player:
			inc = int(inc * DIFFICULTY[difficulty]["player_income"])
			sponsor = int(sponsor * DIFFICULTY[difficulty]["player_income"])
		t.finance.add(inc, "Prize money", "Round %d %s" % [round_idx + 1, track.name], season, round_idx)
		t.finance.add(sponsor, "Sponsors", "Round %d sponsor payments" % [round_idx + 1], season, round_idx)
		var salaries := 0
		for did in t.driver_ids:
			salaries += int(drivers[did].salary / rounds)
		var travel := int(float(bal["travel_cost_per_race"]) * float(t.hq_def().get("travel_mult", 1.0)))
		var ops := int(bal["base_operations_cost_per_race"])
		t.finance.add(-salaries, "Driver salaries", "Round %d" % [round_idx + 1], season, round_idx)
		t.finance.add(-travel, "Travel", "Trip to %s" % track.location, season, round_idx)
		t.finance.add(-ops, "Operations", "Factory & staff running costs", season, round_idx)
		var repairs := 0
		for r in results:
			if r["team_id"] == tid:
				for inc_txt in r["incidents"]:
					if "retired" in inc_txt or "Crash" in inc_txt:
						repairs += 300000
					elif "Contact" in inc_txt:
						repairs += 80000
		if repairs > 0:
			t.finance.add(-repairs, "Repairs", "Accident damage", season, round_idx)
		# component wear from racing
		for cid in t.car.components:
			var comp: CarComponent = t.car.components[cid]
			comp.wear = minf(comp.wear + float(bal["component_wear_per_race"]) * rng.randf_range(0.7, 1.3), 1.0)
		summary["income"][tid] = inc + sponsor
		summary["expenses"][tid] = salaries + travel + ops + repairs
		_update_reputation(t, results, team_round_points[tid])
	_update_morale(results)
	var player := player_team()
	var best := 99
	for r in results:
		if r["team_id"] == player.id and not r["dnf"]:
			best = mini(best, r["position"])
	round_results.append({"track_id": track.id, "track_name": track.name, "season": season,
		"results": _strip_results(results), "quali": weekend.get("quali", [])})
	summary["player_points"] = team_round_points[player.id]
	summary["player_income"] = summary["income"][player.id]
	summary["player_expenses"] = summary["expenses"][player.id]
	if best == 1:
		notify("VICTORY at %s!" % track.name, "success")
	elif best <= 3:
		notify("Podium at %s (P%d)." % [track.name, best], "success")
	notify("%s: scored %d points. Income %s, expenses %s." % [track.name, team_round_points[player.id], Fmt.money(summary["player_income"]), Fmt.money(summary["player_expenses"])], "finance")
	if player.finance.balance < 0:
		notify("WARNING: team balance is negative! Cut spending or the team will fold.", "warning")
	# AI teams react
	AITeamManager.after_race(self)
	round_idx += 1
	weekend.clear()
	return summary


func _strip_results(results: Array) -> Array:
	var out := []
	for r in results:
		out.append({"driver_id": r["driver_id"], "team_id": r["team_id"], "position": r["position"], "grid": r["grid"],
			"laps": r["laps"], "time": r["time"], "best_lap": r["best_lap"], "dnf": r["dnf"], "dnf_reason": r["dnf_reason"],
			"points": r.get("points", 0), "overtakes": r["overtakes"], "mistakes": r["mistakes"]})
	return out


func _update_reputation(t: Team, results: Array, pts: int) -> void:
	var delta := pts * 0.08
	for r in results:
		if r["team_id"] != t.id:
			continue
		if not r["dnf"] and r["position"] == 1:
			delta += 2.0
		elif not r["dnf"] and r["position"] <= 3:
			delta += 0.8
		if r["dnf"] and "failure" in r["dnf_reason"]:
			delta -= 0.6
	if pts == 0:
		delta -= 0.3 * (t.reputation / 50.0)
	if t.finance.balance < 0:
		delta -= 1.0
	t.reputation = clampf(t.reputation + delta, 1.0, 100.0)


func _update_morale(results: Array) -> void:
	var by_driver := {}
	for r in results:
		by_driver[r["driver_id"]] = r
	for tid in teams:
		var t: Team = teams[tid]
		if t.driver_ids.size() < 2:
			continue
		for i in 2:
			var me: Dictionary = by_driver.get(t.driver_ids[i], {})
			var mate: Dictionary = by_driver.get(t.driver_ids[1 - i], {})
			if me.is_empty():
				continue
			var d: Driver = drivers[t.driver_ids[i]]
			var dm := 0.0
			dm += me.get("points", 0) * 0.25
			if me["dnf"]:
				dm -= 4.0 if "failure" in me["dnf_reason"] else 2.0
			if not mate.is_empty():
				dm += 1.5 if me["position"] < mate["position"] else -1.0
			dm += (60.0 - d.morale) * 0.05     # drift back to neutral
			d.change_morale(dm)


# ------------------------------------------------------------ season

## Ends the season: prizes, ageing, development, new calendar. Returns summary.
func end_season() -> Dictionary:
	var bal: Dictionary = DataDB.balance
	var st := team_standings()
	var prizes: Array = bal["season_team_prize"]
	var champion_driver: Dictionary = driver_standings()[0]
	var summary := {"season": season, "driver_champion": champion_driver["driver"].full_name(), "team_champion": st[0]["team"].name,
		"player_position": team_position(player_team_id), "player_points": team_points[player_team_id]}
	for i in st.size():
		var t: Team = st[i]["team"]
		var prize := int(prizes[mini(i, prizes.size() - 1)])
		t.finance.add(prize, "Prize money", "Season %d constructors' P%d" % [season, i + 1], season, round_idx)
		if i == 0:
			t.reputation = minf(t.reputation + 8.0, 100.0)
	history.append(summary)
	# driver ageing and development
	for did in drivers:
		var d: Driver = drivers[did]
		d.age += 1
		_develop_driver(d)
		if d.contract_years > 0:
			d.contract_years -= 1
		if d.contract_years == 0 and d.team_id != "":
			d.contract_years = 2  # Phase 1: contracts auto-renew; full negotiation comes with Phase 2
			if d.team_id == player_team_id:
				notify("%s's contract was extended by 2 seasons." % d.full_name(), "info")
	notify("Season %d finished. Constructors' position: P%d. Prize money paid." % [season, summary["player_position"]], "success")
	season += 1
	round_idx = 0
	_reset_standings()
	return summary


func _develop_driver(d: Driver) -> void:
	var team: Team = teams.get(d.team_id)
	var dev_mult := 1.0
	if team and d.age <= 23:
		dev_mult = float(team.mod("young_dev_mult", 1.0))
	var potential := d.attr("potential")
	for k in ["raw_pace", "qualifying_pace", "race_pace", "consistency", "racecraft", "overtaking", "defending", "braking", "tire_management", "wet_skill"]:
		var v := d.attr(k)
		var delta := 0.0
		if d.age <= 27:
			delta = maxf(0.0, (potential - v) * 0.12) * dev_mult + rng.randf_range(-0.5, 1.0)
		elif d.age <= 32:
			delta = rng.randf_range(-0.5, 0.8)
		else:
			delta = -rng.randf_range(0.3, 1.8) * (d.age - 32) * 0.5
		d.attributes[k] = int(clampf(v + delta, 20.0, 99.0))
	d.attributes["experience"] = int(minf(d.attr("experience") + 4.0, 99.0))


# ------------------------------------------------------------ save

func to_dict() -> Dictionary:
	var t := {}
	for tid in teams:
		t[tid] = teams[tid].to_dict()
	var d := {}
	for did in drivers:
		d[did] = drivers[did].to_dict()
	return {
		"version": SAVE_VERSION, "season": season, "round_idx": round_idx, "championship_id": championship_id,
		"calendar": calendar, "difficulty": difficulty, "player_team_id": player_team_id,
		"teams": t, "team_order": team_order, "drivers": d,
		"driver_points": driver_points, "team_points": team_points, "round_results": round_results,
		"history": history, "notifications": notifications, "weekend": weekend, "rng_state": str(rng.state),
	}


static func from_dict(data: Dictionary) -> Career:
	var c := Career.new()
	c.season = int(data.get("season", 1))
	c.round_idx = int(data.get("round_idx", 0))
	c.championship_id = data.get("championship_id", "")
	c.calendar = data.get("calendar", []).duplicate()
	c.difficulty = data.get("difficulty", "normal")
	c.player_team_id = data.get("player_team_id", "")
	for did in data.get("drivers", {}):
		c.drivers[did] = Driver.from_dict(data["drivers"][did])
	for tid in data.get("teams", {}):
		c.teams[tid] = Team.from_dict(data["teams"][tid])
	c.team_order = data.get("team_order", []).duplicate()
	for k in data.get("driver_points", {}):
		c.driver_points[k] = int(data["driver_points"][k])
	for k in data.get("team_points", {}):
		c.team_points[k] = int(data["team_points"][k])
	c.round_results = data.get("round_results", []).duplicate(true)
	c.history = data.get("history", []).duplicate(true)
	c.notifications = data.get("notifications", []).duplicate(true)
	c.weekend = data.get("weekend", {}).duplicate(true)
	if c.weekend.has("round"):
		c.weekend["round"] = int(c.weekend["round"])
		c.weekend["season"] = int(c.weekend.get("season", c.season))
	c.rng.randomize()
	if data.has("rng_state"):
		c.rng.state = str(data["rng_state"]).to_int()
	return c
