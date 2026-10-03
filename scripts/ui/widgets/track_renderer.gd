class_name TrackRenderer
extends RefCounted
## Builds a 2D triangle mesh for a track: runoff, barriers, asphalt, edge lines and kerbs.
## Sections are drawn lowest elevation first so bridges correctly pass over lower track.

const C_GRASS := Color("1c3524")
const C_GRAVEL := Color("4a4232")
const C_WALL_ZONE := Color("30343b")
const C_BARRIER := Color("9aa3ad")
const C_ASPHALT := Color("40454e")
const C_EDGE := Color("e4e8ec")
const C_KERB_RED := Color("c8312b")
const C_SHADOW := Color(0, 0, 0, 0.45)
const CHUNK := 6


static func build(t: TrackData, elevation_colors: bool = false, detail: String = "high") -> ArrayMesh:
	var m := t.samples.size()
	if m < 3:
		return null
	var emin := INF
	var emax := -INF
	for e in t.elev_at:
		emin = minf(emin, e)
		emax = maxf(emax, e)
	var layered := not t.crossings.is_empty()
	# group chunks by elevation level; within a level draw layer by layer
	var levels := {}
	for c0 in range(0, m, CHUNK):
		var c1 := mini(c0 + CHUNK, m)
		var avg := 0.0
		for i in range(c0, c1):
			avg += t.elev_at[i]
		avg /= float(c1 - c0)
		var lvl := int(floor((avg - emin) / (TrackData.BRIDGE_CLEARANCE * 0.8))) if layered else 0
		if not levels.has(lvl):
			levels[lvl] = []
		levels[lvl].append([c0, c1])
	var keys := levels.keys()
	keys.sort()
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	for lvl in keys:
		var chunks: Array = levels[lvl]
		if lvl > 0:
			for ch in chunks:
				_band(t, ch, verts, cols, func(i): return t.width_at[i] * 0.5 + 2.5, func(i): return -(t.width_at[i] * 0.5 + 2.5), func(_i): return C_SHADOW, Vector2(7, 7))
		if detail != "low":
			for ch in chunks:
				_band(t, ch, verts, cols, func(i): return t.width_at[i] * 0.5 + t.runoff_at[i], func(i): return -(t.width_at[i] * 0.5 + t.runoff_at[i]), func(i): return _runoff_color(t.runoff_at[i]))
			for ch in chunks:
				_band(t, ch, verts, cols, func(i): return t.width_at[i] * 0.5 + t.runoff_at[i] + 1.2, func(i): return t.width_at[i] * 0.5 + t.runoff_at[i], func(_i): return C_BARRIER)
				_band(t, ch, verts, cols, func(i): return -(t.width_at[i] * 0.5 + t.runoff_at[i]), func(i): return -(t.width_at[i] * 0.5 + t.runoff_at[i] + 1.2), func(_i): return C_BARRIER)
		for ch in chunks:
			_band(t, ch, verts, cols, func(i): return t.width_at[i] * 0.5, func(i): return -t.width_at[i] * 0.5,
				func(i): return _asphalt(t, i, emin, emax, elevation_colors))
		for ch in chunks:
			_band(t, ch, verts, cols, func(i): return t.width_at[i] * 0.5 + 0.6, func(i): return t.width_at[i] * 0.5 - 0.4, func(i): return _edge(t, i))
			_band(t, ch, verts, cols, func(i): return -(t.width_at[i] * 0.5 - 0.4), func(i): return -(t.width_at[i] * 0.5 + 0.6), func(i): return _edge(t, i))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Adds quads between lateral offsets a(i) and b(i) for samples in chunk [c0, c1].
static func _band(t: TrackData, ch: Array, verts: PackedVector2Array, cols: PackedColorArray, a: Callable, b: Callable, col: Callable, shift: Vector2 = Vector2.ZERO) -> void:
	var m := t.samples.size()
	for i in range(ch[0], ch[1]):
		var j := (i + 1) % m
		var pa_i: Vector2 = t.samples[i] + t.normals[i] * float(a.call(i)) + shift
		var pb_i: Vector2 = t.samples[i] + t.normals[i] * float(b.call(i)) + shift
		var pa_j: Vector2 = t.samples[j] + t.normals[j] * float(a.call(j)) + shift
		var pb_j: Vector2 = t.samples[j] + t.normals[j] * float(b.call(j)) + shift
		var c: Color = col.call(i)
		verts.append(pa_i); verts.append(pb_i); verts.append(pa_j)
		verts.append(pa_j); verts.append(pb_i); verts.append(pb_j)
		for k in 6:
			cols.append(c)


static func _runoff_color(r: float) -> Color:
	if r < 6.0:
		return C_WALL_ZONE
	if r > 35.0:
		return C_GRAVEL
	return C_GRASS


static func _asphalt(t: TrackData, i: int, emin: float, emax: float, elevation_colors: bool) -> Color:
	if elevation_colors and emax - emin > 0.5:
		var f := (t.elev_at[i] - emin) / (emax - emin)
		return Color("1f4f8a").lerp(Color("c8782a"), f)
	var c := C_ASPHALT
	if absf(t.bank_at[i]) > 3.0:
		c = c.lerp(Color("4a3f5c"), clampf(absf(t.bank_at[i]) / 25.0, 0.0, 0.7))
	return c


static func _edge(t: TrackData, i: int) -> Color:
	# red/white kerbs where the racing line runs close to the edge in corners
	if t.radius[i] < 160.0 and absf(t.line_offset[i]) > t.width_at[i] * 0.5 - 2.5:
		return C_KERB_RED if (i / 2) % 2 == 0 else C_EDGE
	return C_EDGE
