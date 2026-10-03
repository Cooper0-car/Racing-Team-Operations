class_name PerformanceModel
extends RefCounted
## Converts car performance dimensions + driver into physical parameters,
## and computes a speed profile around a track from those parameters.
## Track geometry therefore decides which car strengths matter:
##   tight corners  -> mechanical grip (low_speed_cornering), traction, braking
##   fast corners   -> aero grip (high_speed_cornering)
##   long straights -> top_speed, acceleration

const G := 9.81


static func reference_params() -> Dictionary:
	var d := {}
	for k in ["top_speed", "acceleration", "braking", "low_speed_cornering", "high_speed_cornering", "traction"]:
		d[k] = 60.0
	return car_params(d)


## dims: 0..100 performance dimensions from Car.dimensions()
static func car_params(dims: Dictionary) -> Dictionary:
	var ts: float = dims.get("top_speed", 50.0) / 100.0
	var acc: float = dims.get("acceleration", 50.0) / 100.0
	var br: float = dims.get("braking", 50.0) / 100.0
	var lsc: float = dims.get("low_speed_cornering", 50.0) / 100.0
	var hsc: float = dims.get("high_speed_cornering", 50.0) / 100.0
	var tr: float = dims.get("traction", 50.0) / 100.0
	return {
		"vmax": 78.0 + 14.0 * ts,                   # m/s
		"accel": 8.0 + 6.0 * acc,                   # m/s^2 at low speed
		"traction": 0.55 + 0.45 * tr,               # caps low-speed acceleration
		"mu_mech": 1.25 + 0.55 * lsc,               # mechanical lateral grip (g)
		"c_aero": 0.00016 + 0.00012 * hsc,          # aero grip per (m/s)^2 (g)
		"mu_brake": 1.25 + 1.0 * br,                 # braking grip (g)
		"grip": 1.0,                                # tyre/weather multiplier
	}


static func with_driver(params: Dictionary, driver: Driver) -> Dictionary:
	var p := params.duplicate()
	p["mu_brake"] = p["mu_brake"] * (0.93 + 0.1 * driver.attr("braking") / 100.0)
	return p


static func accel_at(p: Dictionary, v: float) -> float:
	var a: float = p["accel"]
	if v < 45.0:
		a *= lerpf(p["traction"], 1.0, v / 45.0)
	return maxf(a * (1.0 - pow(v / p["vmax"], 2.2)), 0.0)


static func decel_at(p: Dictionary, v: float) -> float:
	return G * (p["mu_brake"] + p["c_aero"] * v * v * 1.1) * p["grip"]


## bank_deg: banking angle; it adds tan(angle) to the available lateral grip.
static func corner_speed(p: Dictionary, r: float, bank_deg: float = 0.0) -> float:
	var gm: float = p["grip"]
	var mu: float = p["mu_mech"] * gm + tan(deg_to_rad(clampf(absf(bank_deg), 0.0, 45.0)))
	var denom: float = 1.0 - r * G * p["c_aero"] * gm
	if denom < 0.04:
		return p["vmax"]
	return minf(sqrt(r * G * mu / denom), p["vmax"])


## Max achievable speed at every track sample, respecting braking and acceleration limits.
static func speed_profile(track: TrackData, p: Dictionary) -> PackedFloat32Array:
	var m := track.samples.size()
	var v := PackedFloat32Array()
	v.resize(m)
	if m == 0:
		return v
	var has_bank := track.bank_at.size() == m
	var has_grade := track.grade_at.size() == m
	for i in m:
		v[i] = corner_speed(p, track.radius[i], track.bank_at[i] if has_bank else 0.0)
	var ds := track.step
	# backward pass (braking), twice around for the closed loop. Uphill helps braking.
	for pass_i in 2:
		for jj in m:
			var i := m - 1 - jj
			var nxt := v[(i + 1) % m]
			var g := track.grade_at[i] if has_grade else 0.0
			var lim := sqrt(nxt * nxt + 2.0 * maxf(decel_at(p, nxt) + G * g, 2.0) * ds)
			if v[i] > lim:
				v[i] = lim
	# forward pass (acceleration). Uphill costs acceleration, downhill adds to it.
	for pass_i in 2:
		for i in m:
			var cur := v[i]
			var g2 := track.grade_at[i] if has_grade else 0.0
			# net acceleration may be negative on steep climbs (the car slows down uphill)
			var net := maxf(accel_at(p, cur) - G * g2, -4.0)
			if net >= 0.0:
				net = maxf(net, 0.15)
			var lim := sqrt(maxf(cur * cur + 2.0 * net * ds, 1.0))
			var j := (i + 1) % m
			if v[j] > lim:
				v[j] = lim
	return v


static func lap_time(track: TrackData, profile: PackedFloat32Array, mult: float = 1.0) -> float:
	var t := 0.0
	var m := profile.size()
	for i in m:
		var a := profile[i] * mult
		var b := profile[(i + 1) % m] * mult
		t += track.step / maxf((a + b) * 0.5, 1.0)
	return t


## Lap time split into the 3 sectors.
static func sector_times(track: TrackData, profile: PackedFloat32Array, mult: float = 1.0) -> Array:
	var out := [0.0, 0.0, 0.0]
	var m := profile.size()
	for i in m:
		var a := profile[i] * mult
		var b := profile[(i + 1) % m] * mult
		out[track.sector_of(i * track.step)] += track.step / maxf((a + b) * 0.5, 1.0)
	return out


## Driver's speed multiplier from attributes (race or qualifying).
static func driver_factor(driver: Driver, team: Team, qualifying: bool) -> float:
	var pace := driver.attr("qualifying_pace") if qualifying else driver.attr("race_pace")
	var f := 1.0 - (100.0 - pace) * 0.0007
	f += (driver.morale - 70.0) * 0.00004
	f += (driver.attr("experience") - 60.0) * 0.00002
	if qualifying:
		f += float(team.mod("quali_bonus", 0.0))
	else:
		f += float(team.mod("race_bonus", 0.0))
	return f
