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


# ---------------------------------------------------------------- units (Settings → Units)

static func speed(kph: float) -> String:
	if Game.imperial():
		return "%d mph" % int(round(kph * 0.621371))
	return "%d km/h" % int(round(kph))


static func km(metres: float) -> String:
	if Game.imperial():
		return "%.2f mi" % (metres / 1609.344)
	return "%.2f km" % (metres / 1000.0)


static func metres(m: float) -> String:
	if Game.imperial():
		return "%d ft" % int(round(m * 3.28084))
	return "%d m" % int(round(m))


## Translate (usable from static code).
static func t(key: String) -> String:
	return TranslationServer.translate(key)
