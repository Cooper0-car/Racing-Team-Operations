class_name TrackView
extends Control
## Draws a TrackData and (optionally) the cars of a running RaceSimulation.
## Camera: fit whole track, or follow a car. Mouse wheel zooms, drag pans.

var track: TrackData
var sim: RaceSimulation
var follow_idx: int = -1           # car index to follow, -1 = whole track
var highlight_team: String = ""
var show_zones: bool = false
var show_labels: bool = true
var zoom_mul: float = 1.0
var pan: Vector2 = Vector2.ZERO
var follow_zoom: float = 4.0       # pixels per metre when following
var _dragging := false
var _cam_center := Vector2.ZERO
var _cam_scale := 1.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_track(t: TrackData) -> void:
	track = t
	pan = Vector2.ZERO
	zoom_mul = 1.0
	queue_redraw()


func _process(_delta: float) -> void:
	if sim:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if follow_idx >= 0:
				follow_zoom = minf(follow_zoom * 1.15, 12.0)
			else:
				zoom_mul = minf(zoom_mul * 1.15, 12.0)
			queue_redraw()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if follow_idx >= 0:
				follow_zoom = maxf(follow_zoom / 1.15, 0.3)
			else:
				zoom_mul = maxf(zoom_mul / 1.15, 0.5)
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging and follow_idx < 0:
		pan += (event as InputEventMouseMotion).relative / _cam_scale
		queue_redraw()


func _update_camera() -> void:
	var b := track.bounds.grow(track.width * 3.0)
	var fit := minf(size.x / maxf(b.size.x, 1.0), size.y / maxf(b.size.y, 1.0)) * 0.94
	if follow_idx >= 0 and sim and follow_idx < sim.cars.size():
		var c: RaceCar = sim.cars[follow_idx]
		_cam_center = track.position_at(c.progress, c.lateral)
		_cam_scale = follow_zoom
	else:
		_cam_center = b.get_center() - pan
		_cam_scale = fit * zoom_mul


func world_to_screen(p: Vector2) -> Vector2:
	return (p - _cam_center) * _cam_scale + size * 0.5


func screen_to_world(p: Vector2) -> Vector2:
	return (p - size * 0.5) / _cam_scale + _cam_center


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b0d10"))
	if track == null or track.samples.size() < 3:
		return
	_update_camera()
	var s := _cam_scale
	draw_set_transform(size * 0.5 - _cam_center * s, 0.0, Vector2(s, s))
	var pts := track.samples.duplicate()
	pts.append(track.samples[0])
	var w := track.width
	# runoff, barrier, kerb-ish edge, asphalt
	draw_polyline(pts, Color("1a2a1f"), w * 3.2, true)
	draw_polyline(pts, Color("3a3f47"), w + 2.4, true)
	draw_polyline(pts, Color("d8dde3"), w + 0.8, true)
	draw_polyline(pts, Color("2a2e35"), w, true)
	# sector markers + start/finish
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_line_across(0.0, Color.WHITE, 3.0)
	_draw_line_across(float(track.sectors[0]) * track.length, Color(UI.WARN, 0.8), 2.0)
	_draw_line_across(float(track.sectors[1]) * track.length, Color(UI.CYAN, 0.8), 2.0)
	if show_zones:
		for z in track.overtake_zones:
			var zp := world_to_screen(track.samples[z["index"]])
			draw_circle(zp, 4.0 + 6.0 * z["strength"], Color(UI.GOOD, 0.35))
	if sim:
		_draw_cars()


func _draw_line_across(dist: float, col: Color, width: float) -> void:
	var i := track.index_at(dist)
	var p := track.samples[i]
	var n := track.normals[i]
	var a := world_to_screen(p + n * track.width * 0.55)
	var b := world_to_screen(p - n * track.width * 0.55)
	draw_line(a, b, col, width)


func _draw_cars() -> void:
	var font := get_theme_default_font()
	# draw back-to-front so the leader is on top
	var order: Array = sim.order.duplicate()
	order.reverse()
	for c in order:
		if c.dnf:
			continue
		var wp := track.position_at(c.progress, c.lateral)
		var sp := world_to_screen(wp)
		if sp.x < -20 or sp.y < -20 or sp.x > size.x + 20 or sp.y > size.y + 20:
			continue
		var tg := track.tangent_at(c.progress)
		var player: bool = c.team.id == highlight_team
		var px_len := 5.5 * _cam_scale
		if px_len > 10.0:
			# zoomed in: proper oriented car shape
			var fwd := tg * 2.75 * _cam_scale
			var side := Vector2(-tg.y, tg.x) * 1.0 * _cam_scale
			var poly := PackedVector2Array([sp + fwd + side * 0.6, sp + fwd - side * 0.6, sp - fwd - side, sp - fwd + side])
			draw_colored_polygon(poly, c.color)
			draw_line(sp - fwd * 0.2 + side, sp - fwd * 0.2 - side, c.team.secondary, maxf(1.0, _cam_scale * 0.5))
		else:
			var r := 6.0 if player else 5.0
			draw_circle(sp, r + 1.5, c.team.secondary if player else Color(0, 0, 0, 0.8))
			draw_circle(sp, r, c.color)
		if c.finished:
			draw_circle(sp, 3.0, Color.WHITE)
		if show_labels and (player or follow_idx == c.idx or c.position <= 3):
			var txt := "%d %s" % [c.position, c.label]
			var off := Vector2(9, -8)
			draw_string(font, sp + off + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.9))
			draw_string(font, sp + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE if player else Color(1, 1, 1, 0.75))
		if c.incident_time > 0.0 and c.incident_factor < 0.6:
			draw_arc(sp, 10.0, 0.0, TAU, 16, UI.WARN, 2.0)
