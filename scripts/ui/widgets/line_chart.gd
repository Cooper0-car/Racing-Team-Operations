class_name LineChart
extends Control
## Minimal multi-series line chart. series: [{name, color, values:Array[float]}]

var series: Array = []
var invert_y := false          # true for position charts (P1 at top)
var y_min_override := NAN
var y_max_override := NAN
var y_format := "%.1f"
var x_label := "Lap"


func _ready() -> void:
	custom_minimum_size = Vector2(300, 180)


func set_series(s: Array) -> void:
	series = s
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), UI.PANEL2)
	var pad_l := 46.0
	var pad_b := 22.0
	var pad_t := 10.0
	var pad_r := 10.0
	var area := Rect2(pad_l, pad_t, size.x - pad_l - pad_r, size.y - pad_t - pad_b)
	var ymin := INF
	var ymax := -INF
	var n := 0
	for s in series:
		for v in s["values"]:
			if v == null or is_inf(float(v)) or is_nan(float(v)):
				continue
			ymin = minf(ymin, float(v))
			ymax = maxf(ymax, float(v))
		n = maxi(n, s["values"].size())
	if not is_nan(y_min_override):
		ymin = y_min_override
	if not is_nan(y_max_override):
		ymax = y_max_override
	if n < 2 or ymin == INF:
		draw_string(font, Vector2(pad_l, size.y * 0.5), "No data", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
		return
	if absf(ymax - ymin) < 0.0001:
		ymax += 1.0
		ymin -= 1.0
	# grid
	for g in 5:
		var gy := area.position.y + area.size.y * g / 4.0
		draw_line(Vector2(area.position.x, gy), Vector2(area.end.x, gy), UI.LINE, 1.0)
		var val := lerpf(ymax, ymin, g / 4.0) if not invert_y else lerpf(ymin, ymax, g / 4.0)
		draw_string(font, Vector2(4, gy + 4), y_format % val, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.MUTED)
	draw_string(font, Vector2(area.end.x - 40, size.y - 4), "%s %d" % [x_label, n], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.MUTED)
	for s in series:
		var pts := PackedVector2Array()
		var vals: Array = s["values"]
		for i in vals.size():
			var v := float(vals[i])
			if is_inf(v) or is_nan(v):
				continue
			var x := area.position.x + area.size.x * i / float(maxi(n - 1, 1))
			var t := (v - ymin) / (ymax - ymin)
			if invert_y:
				t = 1.0 - t
			var y := area.end.y - area.size.y * t
			pts.append(Vector2(x, y))
		if pts.size() >= 2:
			draw_polyline(pts, s["color"], 2.0, true)
	# legend
	var lx := area.position.x + 6
	for s in series:
		draw_rect(Rect2(lx, pad_t + 2, 10, 10), s["color"])
		draw_string(font, Vector2(lx + 14, pad_t + 11), s["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.TEXT)
		lx += 20 + font.get_string_size(s["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10
