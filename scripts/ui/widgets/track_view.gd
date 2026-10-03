class_name TrackView
extends Control
## Draws a TrackData (mesh + overlays) and optionally the cars of a running RaceSimulation.
## Camera: fit whole track, or follow a car. Mouse wheel zooms at the cursor, drag pans.

var track: TrackData
var sim: RaceSimulation
var follow_idx: int = -1           # car index to follow, -1 = whole track
var highlight_team: String = ""
var show_zones: bool = false       # overtaking zones
var show_labels: bool = true
var show_line: bool = false        # racing line
var show_braking: bool = false
var show_drs: bool = true
var show_pit: bool = true
var show_markers: bool = true      # start/finish + sector lines
var elevation_colors: bool = false
var interactive: bool = true
var fixed_rect := Rect2()          # when set, the camera fits this rect instead of the track (editor)
var zoom_mul: float = 1.0
var pan: Vector2 = Vector2.ZERO
var follow_zoom: float = 4.0       # pixels per metre when following
var _dragging := false
var _cam_center := Vector2.ZERO
var _cam_scale := 1.0
var _mesh: ArrayMesh
var _mesh_key := ""
var _edges: Array = []             # smooth outline polylines for "high" graphics


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE


func set_track(t: TrackData) -> void:
	track = t
	pan = Vector2.ZERO
	zoom_mul = 1.0
	invalidate()


## Call after the track geometry changed.
func invalidate() -> void:
	_mesh_key = ""
	queue_redraw()


func _process(_delta: float) -> void:
	if sim:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var f := 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
			zoom_at(mb.position, f)
			accept_event()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging and follow_idx < 0:
		pan += (event as InputEventMouseMotion).relative / _cam_scale
		queue_redraw()


func zoom_at(screen_pos: Vector2, f: float) -> void:
	if follow_idx >= 0:
		follow_zoom = clampf(follow_zoom * f, 0.3, 14.0)
	else:
		var before := screen_to_world(screen_pos)
		zoom_mul = clampf(zoom_mul * f, 0.25, 30.0)
		_update_camera()
		var after := screen_to_world(screen_pos)
		pan += after - before
	queue_redraw()


func fit_rect() -> Rect2:
	if track == null or track.samples.is_empty():
		return Rect2(-1000, -700, 2000, 1400)
	var grow := 40.0
	for r in track.runoff_at:
		grow = maxf(grow, r + 20.0)
	return track.bounds.grow(grow)


func _update_camera() -> void:
	var b := fixed_rect if fixed_rect.has_area() else fit_rect()
	var fit := minf(size.x / maxf(b.size.x, 1.0), size.y / maxf(b.size.y, 1.0)) * 0.94
	if follow_idx >= 0 and sim and follow_idx < sim.cars.size():
		var c: RaceCar = sim.cars[follow_idx]
		_cam_center = track.car_position(c.progress, c.lateral)
		_cam_scale = follow_zoom
	else:
		_cam_center = b.get_center() - pan
		_cam_scale = fit * zoom_mul


func world_to_screen(p: Vector2) -> Vector2:
	return (p - _cam_center) * _cam_scale + size * 0.5


func screen_to_world(p: Vector2) -> Vector2:
	return (p - size * 0.5) / _cam_scale + _cam_center


func _ensure_mesh() -> void:
	var detail := str(Game.settings.get("graphics", "high"))
	var key := "%d|%s|%s|%d" % [track.get_instance_id(), detail, str(elevation_colors), track.samples.size()]
	if key != _mesh_key:
		_mesh = TrackRenderer.build(track, elevation_colors, detail)
		_mesh_key = key
		_edges.clear()
		if detail == "high" and track.crossings.is_empty():
			for side in [1.0, -1.0]:
				var e := PackedVector2Array()
				for i in track.samples.size():
					e.append(track.samples[i] + track.normals[i] * side * (track.width_at[i] * 0.5 + 0.1))
				e.append(e[0])
				_edges.append(e)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b0d10"))
	_draw_background()
	if track == null or track.samples.size() < 3:
		return
	_update_camera()
	_ensure_mesh()
	var s := _cam_scale
	draw_set_transform(size * 0.5 - _cam_center * s, 0.0, Vector2(s, s))
	if _mesh:
		draw_mesh(_mesh, null)
	for e in _edges:
		draw_polyline(e, TrackRenderer.C_EDGE, maxf(0.9, 1.1 / s), true)
	if show_pit and track.pit_path.size() > 1:
		draw_polyline(track.pit_path, Color("3a4049"), 7.0)
		draw_polyline(track.pit_path, Color("596270"), 0.8)
	if show_line:
		var lp := track.line_points.duplicate()
		lp.append(track.line_points[0])
		draw_polyline(lp, Color(UI.CYAN, 0.75), maxf(0.6, 1.4 / s))
	if show_braking:
		for z in track.braking_zones:
			var pts := PackedVector2Array()
			var i: int = z["start"]
			var guard := 0
			while i != z["end"] and guard < 400:
				pts.append(track.line_points[i])
				i = (i + 1) % track.samples.size()
				guard += 1
			if pts.size() > 1:
				draw_polyline(pts, Color(UI.BAD, 0.85), maxf(1.0, 2.5 / s))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if show_drs:
		for r in track.drs_ranges:
			_draw_side_band(r["start"], r["length"], UI.GOOD)
	if show_markers:
		_draw_line_across(0.0, Color.WHITE, 3.0)
		_draw_line_across(float(track.sectors[0]) * track.length, Color(UI.WARN, 0.85), 2.0)
		_draw_line_across(float(track.sectors[1]) * track.length, Color(UI.CYAN, 0.85), 2.0)
	if show_zones:
		for z in track.overtake_zones:
			var zp := world_to_screen(track.line_points[z["index"]])
			draw_circle(zp, 4.0 + 6.0 * z["strength"], Color(UI.GOOD, 0.35))
	if sim:
		_draw_cars()


func _draw_background() -> void:
	# subtle grid gives a sense of scale (100 m)
	if track == null:
		return
	_update_camera()
	var step := 100.0
	if _cam_scale * step < 18.0:
		step = 500.0
	var tl := screen_to_world(Vector2.ZERO)
	var br := screen_to_world(size)
	var col := Color(1, 1, 1, 0.025)
	var x := floorf(tl.x / step) * step
	while x < br.x:
		var sx := world_to_screen(Vector2(x, 0)).x
		draw_line(Vector2(sx, 0), Vector2(sx, size.y), col, 1.0)
		x += step
	var y := floorf(tl.y / step) * step
	while y < br.y:
		var sy := world_to_screen(Vector2(0, y)).y
		draw_line(Vector2(0, sy), Vector2(size.x, sy), col, 1.0)
		y += step


func _draw_side_band(start: float, span: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var d := 0.0
	while d <= span:
		var i := track.index_at(start + d)
		pts.append(world_to_screen(track.samples[i] + track.normals[i] * -(track.width_at[i] * 0.5 + 2.0)))
		d += track.step * 2.0
	if pts.size() > 1:
		draw_polyline(pts, Color(col, 0.8), 3.0)


func _draw_line_across(dist: float, col: Color, width: float) -> void:
	var i := track.index_at(dist)
	var p := track.samples[i]
	var n := track.normals[i]
	var a := world_to_screen(p + n * track.width_at[i] * 0.55)
	var b := world_to_screen(p - n * track.width_at[i] * 0.55)
	draw_line(a, b, col, width)


func _draw_cars() -> void:
	var font := get_theme_default_font()
	var order: Array = sim.order.duplicate()
	order.reverse()
	for c in order:
		if c.dnf:
			continue
		var off_track: bool = c.incident_time > 0.0 and absf(c.lateral_target) > track.width_at[track.index_at(c.progress)] * 0.5
		var wp := track.car_position(c.progress, c.lateral, off_track or c.finished)
		var sp := world_to_screen(wp)
		if sp.x < -20 or sp.y < -20 or sp.x > size.x + 20 or sp.y > size.y + 20:
			continue
		var tg := track.tangent_at(c.progress)
		var player: bool = c.team.id == highlight_team
		var px_len := 5.5 * _cam_scale
		if px_len > 10.0:
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
		if c.drs_zone >= 0 and track.drs_at[track.index_at(c.progress)] == c.drs_zone:
			draw_arc(sp, 9.0, 0.0, TAU, 14, UI.GOOD, 1.5)
		if show_labels and (player or follow_idx == c.idx or c.position <= 3):
			var txt := "%d %s" % [c.position, c.label]
			var off := Vector2(9, -8)
			draw_string(font, sp + off + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.9))
			draw_string(font, sp + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE if player else Color(1, 1, 1, 0.75))
		if c.incident_time > 0.0 and c.incident_factor < 0.6:
			draw_arc(sp, 10.0, 0.0, TAU, 16, UI.WARN, 2.0)
