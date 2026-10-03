class_name Qualifying
extends RefCounted
## Single-lap qualifying. Each driver gets 3 flying laps; the best one counts.
## Uses the same physics speed profile as the race, so car/track/driver all matter.


## entries: Array of {driver, team}. Returns sorted Array of
## {driver, team, best, sectors, runs:[times], mistake:bool}
static func run(track: TrackData, entries: Array, rng: RandomNumberGenerator) -> Array:
	var out := []
	for e in entries:
		var driver: Driver = e["driver"]
		var team: Team = e["team"]
		var params := PerformanceModel.with_driver(PerformanceModel.car_params(team.car.dimensions()), driver)
		var profile := PerformanceModel.speed_profile(track, params)
		var mult := PerformanceModel.driver_factor(driver, team, true)
		var base := PerformanceModel.lap_time(track, profile, mult)
		var sectors := PerformanceModel.sector_times(track, profile, mult)
		var spread := (100.0 - driver.attr("consistency")) * 0.00008 + 0.0006
		var runs := []
		var best := INF
		var best_scale := 1.0
		var mistake := false
		for r in 3:
			var scale := 1.0 + absf(rng.randfn(0.0, spread))
			# mistakes ruin a lap; risk-takers find more time but err more often
			var p_mist := 0.04 * (1.6 - driver.attr("consistency") / 100.0) * (0.7 + driver.attr("risk_taking") / 150.0)
			if rng.randf() < p_mist:
				scale += 0.01 + rng.randf() * 0.02
				mistake = true
			scale -= (driver.attr("risk_taking") - 50.0) * 0.00003
			var t := base * scale
			runs.append(t)
			if t < best:
				best = t
				best_scale = scale
		var sec := []
		for s in sectors:
			sec.append(s * best_scale)
		out.append({"driver": driver, "team": team, "best": best, "sectors": sec, "runs": runs, "mistake": mistake})
	out.sort_custom(func(a, b): return a["best"] < b["best"])
	return out
