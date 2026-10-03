class_name TrackEditorCanvas
extends TrackView
## Interactive canvas of the track editor. Tools operate directly on `track` (a TrackData)
## and report changes to the owning editor screen through `ed` (push_undo / changed / select).

enum Tool { SELECT, DRAW, ADD, DELETE, START, SECTOR2, SECTOR3, DRS, PIT }

var ed                              # owning track_editor.gd screen
var tool: int = Tool.SELECT
var selected: int = -1
var hover_point: int = -1
var race_mode := false
var _drag_point := -1
var _drag_moved := false
var _pan_drag := false
var _stroke := PackedVector2Array()
var pit_pending_entry := -1.0       # spline u of a pit entry waiting for its exit click
const PICK_PX := 12.0


func _gui_input(event: InputEvent) -> void:
	if race_mode:
		super._gui_input(event)
		return
	if event is InputEventMouseButton:
		_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_mouse_motion(event as InputEventMouseMotion)


func _mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if mb.pressed:
			zoom_at(mb.position, 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
		accept_event()
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
		_pan_drag = mb.pressed
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var world := screen_to_world(mb.position)
	if mb.pressed:
		grab_focus()
		match tool:
			Tool.SELECT:
				var pi := _pick_point(mb.position)
				if pi >= 0:
					ed.select_point(pi)
					ed.push_undo()
					_drag_point = pi
					_drag_moved = false
				else:
					ed.select_point(-1)
					_pan_drag = true
			Tool.DRAW:
				_stroke = PackedVector2Array([world])
			Tool.ADD:
				_add_point(world)
			Tool.DELETE:
				var pd := _pick_point(mb.position)
				if pd >= 0:
					if track.points.size() <= 4:
						ed.message("A track needs at least 4 control points.", UI.WARN)
					else:
						ed.push_undo()
						track.remove_point(pd)
						ed.select_point(-1)
						ed.changed(true)
			Tool.START, Tool.SECTOR2, Tool.SECTOR3, Tool.DRS, Tool.PIT:
				_track_click(world)
	else:
		if tool == Tool.DRAW and _stroke.size() > 1:
			_finish_stroke()
		if _drag_point >= 0:
			if _drag_moved:
				ed.changed(true)
			else:
				ed.discard_undo()
			_drag_point = -1
		_pan_drag = false


func _mouse_motion(mm: InputEventMouseMotion) -> void:
	var world := screen_to_world(mm.position)
	if _pan_drag:
		pan += mm.relative / _cam_scale
		queue_redraw()
		return
	if _drag_point >= 0:
		track.points[_drag_point] = _snap(world)
		_drag_moved = true
		ed.changed(false)
		return
	if tool == Tool.DRAW and not _stroke.is_empty() and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if _stroke[_stroke.size() - 1].distance_to(world) > maxf(6.0, 4.0 / _cam_scale):
			_stroke.append(world)
			queue_redraw()
		return
	var hp := _pick_point(mm.position) if tool in [Tool.SELECT, Tool.DELETE] else -1
	if hp != hover_point:
		hover_point = hp
		queue_redraw()


func _snap(p: Vector2) -> Vector2:
	if ed.snap_enabled:
		return (p / 10.0).round() * 10.0
	return p


func _pick_point(screen_pos: Vector2) -> int:
	if track == null:
		return -1
	var best := -1
	var best_d := PICK_PX * PICK_PX
	for i in track.points.size():
		var d := world_to_screen(track.points[i]).distance_squared_to(screen_pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func _add_point(world: Vector2) -> void:
	ed.push_undo()
	world = _snap(world)
	if track.points.size() < 3 or track.samples.is_empty():
		track.points.append(world)
		track._ensure_props()
		ed.changed(true)
		ed.select_point(track.points.size() - 1)
		return
	var si := track.nearest_sample(world)
	var u := track.sample_u[si]
	var seg := int(floor(u))
	var idx := track.insert_point(seg, world, u - seg)
	ed.changed(true)
	ed.select_point(idx)


func _finish_stroke() -> void:
	var pts := TrackData.stroke_to_points(_stroke, maxf(8.0, 6.0 / _cam_scale), 35.0)
	_stroke.clear()
	if pts.size() < 4:
		ed.message("Stroke too short: draw a closed loop.", UI.WARN)
		queue_redraw()
		return
	ed.push_undo()
	track.points = pts
	track.pt_width.clear(); track.pt_runoff.clear(); track.pt_bank.clear(); track.pt_elev.clear()
	track.start_u = 0.0
	track.drs_zones.clear()
	track.pit = {}
	track._ensure_props()
	ed.changed(true, true)
	if track.overlaps.is_empty():
		track.auto_drs()
		track.auto_pit()
		ed._refresh_all()
		canvas_refresh()
	ed.set_tool(Tool.SELECT)
	ed.message("Track created from your drawing. Drag the points to refine it.", UI.GOOD)


func canvas_refresh() -> void:
	invalidate()


func _track_click(world: Vector2) -> void:
	if track.samples.is_empty():
		return
	var si := track.nearest_sample(world)
	if track.samples[si].distance_to(world) > track.width_at[si] * 0.5 + 40.0 / maxf(_cam_scale, 0.05):
		ed.message("Click on the track.", UI.WARN)
		return
	var dist := si * track.step
	match tool:
		Tool.START:
			ed.push_undo()
			track.start_u = track.sample_u[si]
			ed.changed(true)
		Tool.SECTOR2, Tool.SECTOR3:
			var f := dist / track.length
			var s1: float = track.sectors[0]
			var s2: float = track.sectors[1]
			if tool == Tool.SECTOR2:
				s1 = f
			else:
				s2 = f
			if s1 <= 0.03 or s2 >= 0.97 or s1 >= s2 - 0.03:
				ed.message("Sector 2 must start after the line and before sector 3.", UI.WARN)
				return
			ed.push_undo()
			track.sectors = [snappedf(s1, 0.001), snappedf(s2, 0.001)]
			ed.changed(false)
		Tool.DRS:
			_toggle_drs(si)
		Tool.PIT:
			if pit_pending_entry < 0.0:
				pit_pending_entry = track.sample_u[si]
				ed.message("Pit entry set. Now click where the pit lane exit should be.", UI.CYAN)
				queue_redraw()
			else:
				ed.push_undo()
				var side := int(track.pit.get("side", 1)) if not track.pit.is_empty() else 1
				track.pit = {"entry": pit_pending_entry, "exit": track.sample_u[si], "side": side}
				pit_pending_entry = -1.0
				ed.changed(false)


func _toggle_drs(si: int) -> void:
	var dist := si * track.step
	# clicking inside an existing zone removes it
	for zi in track.drs_ranges.size():
		var r: Dictionary = track.drs_ranges[zi]
		if fposmod(dist - r["start"], track.length) <= r["length"]:
			ed.push_undo()
			track.drs_zones.remove_at(zi)
			ed.changed(false)
			ed.message("DRS zone removed.", UI.CYAN)
			return
	# otherwise create a zone from here to the next braking point
	var m := track.samples.size()
	var end := -1
	for k in range(1, m):
		var i := (si + k) % m
		if track.ref_profile[(i + 1) % m] < track.ref_profile[i] - 0.05:
			end = si + k
			break
	if end < 0 or (end - si) * track.step < 150.0:
		ed.message("Not enough straight here for a DRS zone (needs 150 m before the next braking point).", UI.WARN)
		return
	ed.push_undo()
	track.drs_zones.append([track.sample_u[si], track.dist_to_u(end * track.step - 20.0)])
	ed.changed(false)


func _draw() -> void:
	super._draw()
	if track == null:
		return
	var font := get_theme_default_font()
	if track.points.size() < 3 and _stroke.is_empty():
		var msg := tr("Hold the left mouse button and draw a closed loop, or choose a template under New.")
		draw_string(font, Vector2(24, size.y - 30), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.MUTED)
	if race_mode:
		return
	# control polygon + points
	var n := track.points.size()
	if n >= 2:
		for i in n:
			var a := world_to_screen(track.points[i])
			var b := world_to_screen(track.points[(i + 1) % n])
			draw_dashed_line(a, b, Color(1, 1, 1, 0.12), 1.0, 6.0)
	for i in n:
		var sp := world_to_screen(track.points[i])
		var col := Color(1, 1, 1, 0.9)
		var r := 5.0
		if i == selected:
			col = UI.ACCENT
			r = 7.5
		elif i == hover_point:
			col = UI.WARN if tool == Tool.DELETE else UI.CYAN
			r = 6.5
		draw_circle(sp, r + 2.0, Color(0, 0, 0, 0.7))
		draw_circle(sp, r, col)
		if _cam_scale > 0.25 or i == selected:
			draw_string(font, sp + Vector2(8, -6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55))
	# problems
	for oi in track.overlaps:
		draw_arc(world_to_screen(track.samples[oi]), 16.0, 0.0, TAU, 20, UI.BAD, 3.0)
	for c in track.crossings:
		var cp := world_to_screen(track.samples[c["b"]])
		draw_rect(Rect2(cp - Vector2(7, 4), Vector2(14, 8)), UI.WARN, false, 2.0)
	if pit_pending_entry >= 0.0 and not track.samples.is_empty():
		var pd := track.u_to_dist(pit_pending_entry)
		draw_circle(world_to_screen(track.position_at(pd)), 7.0, UI.CYAN)
	# freehand stroke in progress
	if _stroke.size() > 1:
		var sp2 := PackedVector2Array()
		for p in _stroke:
			sp2.append(world_to_screen(p))
		draw_polyline(sp2, UI.ACCENT, 3.0, true)
		draw_circle(sp2[0], 6.0, UI.GOOD)
