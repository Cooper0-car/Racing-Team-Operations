class_name Fmt
extends RefCounted
## Display formatting helpers.


static func money(v: int) -> String:
	var neg := v < 0
	var a := absf(v)
	var s := ""
	if a >= 1000000.0:
		s = "$%.2fM" % (a / 1000000.0)
	elif a >= 1000.0:
		s = "$%dK" % int(round(a / 1000.0))
	else:
		s = "$%d" % int(a)
	return ("-" if neg else "") + s


static func lap_time(t: float) -> String:
	if t <= 0.0 or t == INF:
		return "-"
	var m := int(t / 60.0)
	var s := t - m * 60.0
	return "%d:%06.3f" % [m, s]


static func race_time(t: float) -> String:
	if t <= 0.0:
		return "-"
	var h := int(t / 3600.0)
	var m := int(fmod(t, 3600.0) / 60.0)
	var s := fmod(t, 60.0)
	if h > 0:
		return "%d:%02d:%06.3f" % [h, m, s]
	return "%d:%06.3f" % [m, s]


static func sector(t: float) -> String:
	if t <= 0.0 or t == INF:
		return "-"
	return "%.3f" % t


static func ordinal(n: int) -> String:
	return "P%d" % n


static func pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))
