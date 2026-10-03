class_name TeamLogo
extends Control
## Procedural team logo: a shape in the primary colour with the abbreviation.

const SHAPES := ["Shield", "Circle", "Diamond", "Hexagon", "Chevron", "Square"]

var primary := Color.RED
var secondary := Color.WHITE
var shape := 0
var abbr := "TEA"


static func make(team: Team, px: int = 48) -> TeamLogo:
	var l := TeamLogo.new()
	l.primary = team.primary
	l.secondary = team.secondary
	l.shape = team.logo_shape
	l.abbr = team.abbr
	l.custom_minimum_size = Vector2(px, px)
	return l


func set_style(p: Color, s: Color, sh: int, a: String) -> void:
	primary = p; secondary = s; shape = sh; abbr = a
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	var pts := PackedVector2Array()
	match shape:
		0:  # shield
			pts = PackedVector2Array([c + Vector2(-r, -r * 0.9), c + Vector2(r, -r * 0.9), c + Vector2(r * 0.9, r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.9, r * 0.2)])
		1:  # circle
			for i in 32:
				pts.append(c + Vector2.from_angle(TAU * i / 32.0) * r * 0.95)
		2:  # diamond
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		3:  # hexagon
			for i in 6:
				pts.append(c + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * r * 0.97)
		4:  # chevron
			pts = PackedVector2Array([c + Vector2(-r, -r * 0.7), c + Vector2(0, -r * 0.2), c + Vector2(r, -r * 0.7), c + Vector2(r, r * 0.3), c + Vector2(0, r * 0.9), c + Vector2(-r, r * 0.3)])
		_:  # rounded square
			pts = PackedVector2Array([c + Vector2(-r, -r) * 0.9, c + Vector2(r, -r) * 0.9, c + Vector2(r, r) * 0.9, c + Vector2(-r, r) * 0.9])
	draw_colored_polygon(pts, primary)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, secondary, maxf(2.0, r * 0.08), true)
	var font := get_theme_default_font()
	var fs := int(r * 0.62)
	var tw := font.get_string_size(abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-tw * 0.5, fs * 0.35), abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, secondary)
