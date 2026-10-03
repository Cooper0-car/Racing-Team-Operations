class_name UI
extends RefCounted
## UI construction helpers + the dark motorsport theme. All screens are built in code.

const BG := Color("0d0f13")
const PANEL := Color("151920")
const PANEL2 := Color("1c2129")
const PANEL3 := Color("252b35")
const LINE := Color("2b323d")
const TEXT := Color("e8ebf0")
const MUTED := Color("8a94a3")
const ACCENT := Color("e10600")
const GOOD := Color("2ecc71")
const WARN := Color("f5c518")
const BAD := Color("ff4d4d")
const PURPLE := Color("b26bff")
const CYAN := Color("3fc1ff")

static var _theme: Theme
static var font_regular: Font
static var font_bold: Font


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	font_regular = _load_font("res://assets/fonts/Pretendard-Regular.otf")
	font_bold = _load_font("res://assets/fonts/Pretendard-Bold.otf")
	if font_regular:
		t.default_font = font_regular
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
	t.set_stylebox("normal", "Button", _box(PANEL3, LINE, 1, 4, 8, 6))
	t.set_stylebox("hover", "Button", _box(Color("2f3642"), Color("4a5463"), 1, 4, 8, 6))
	t.set_stylebox("pressed", "Button", _box(ACCENT.darkened(0.25), ACCENT, 1, 4, 8, 6))
	t.set_stylebox("disabled", "Button", _box(Color(PANEL3, 0.5), Color(LINE, 0.5), 1, 4, 8, 6))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color(ACCENT, 0.6), 1, 4, 8, 6))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, LINE, 1, 6, 12, 12))
	t.set_stylebox("panel", "Panel", _box(PANEL, LINE, 1, 6, 0, 0))
	for le in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", le, _box(PANEL2, LINE, 1, 4, 8, 6))
		t.set_stylebox("focus", le, _box(PANEL2, ACCENT, 1, 4, 8, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("normal", "OptionButton", _box(PANEL3, LINE, 1, 4, 8, 6))
	t.set_stylebox("hover", "OptionButton", _box(Color("2f3642"), Color("4a5463"), 1, 4, 8, 6))
	t.set_stylebox("pressed", "OptionButton", _box(PANEL3, ACCENT, 1, 4, 8, 6))
	t.set_stylebox("panel", "PopupMenu", _box(PANEL2, LINE, 1, 4, 6, 6))
	t.set_stylebox("hover", "PopupMenu", _box(ACCENT.darkened(0.3), Color(0, 0, 0, 0), 0, 2, 4, 2))
	t.set_stylebox("background", "ProgressBar", _box(PANEL3, Color(0, 0, 0, 0), 0, 3, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _box(ACCENT, Color(0, 0, 0, 0), 0, 3, 0, 0))
	t.set_stylebox("panel", "TabContainer", _box(PANEL, LINE, 1, 6, 10, 10))
	t.set_stylebox("panel", "ItemList", _box(PANEL2, LINE, 1, 4, 4, 4))
	t.set_stylebox("selected", "ItemList", _box(ACCENT.darkened(0.3), Color(0, 0, 0, 0), 0, 2, 2, 2))
	t.set_stylebox("selected_focus", "ItemList", _box(ACCENT.darkened(0.2), Color(0, 0, 0, 0), 0, 2, 2, 2))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TooltipPanel", _box(PANEL3, LINE, 1, 4, 8, 6))
	t.set_stylebox("separator", "HSeparator", _line_box())
	for cb in ["CheckButton", "CheckBox"]:
		t.set_stylebox("normal", cb, _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 4, 4))
		t.set_stylebox("pressed", cb, _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 4, 4))
		t.set_stylebox("hover", cb, _box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 4, 4, 4))
		t.set_stylebox("hover_pressed", cb, _box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 4, 4, 4))
		t.set_stylebox("focus", cb, StyleBoxEmpty.new())
		t.set_color("font_color", cb, TEXT)
		t.set_color("font_pressed_color", cb, TEXT)
		t.set_color("font_hover_color", cb, Color.WHITE)
		t.set_color("font_hover_pressed_color", cb, Color.WHITE)
	_theme = t
	return t


## Pretendard covers Hangul + Latin; Godot's built-in font is the fallback for symbols.
static func _load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var f = load(path)
	if f is FontFile:
		f.fallbacks = [ThemeDB.fallback_font]
	return f


static func _box(bg: Color, border: Color, bw: int, radius: int, px: int, py: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = px
	s.content_margin_right = px
	s.content_margin_top = py
	s.content_margin_bottom = py
	return s


static func _line_box() -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = LINE
	s.thickness = 1
	return s


static func panel_box(bg: Color = PANEL, border: Color = LINE, pad: int = 12) -> StyleBoxFlat:
	return _box(bg, border, 1, 6, pad, pad)


# ---------------------------------------------------------------- builders

static func label(text: String, size: int = 15, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold and font_bold:
		l.add_theme_font_override("font", font_bold)
	return l


static func title(text: String, size: int = 26) -> Label:
	return label(Fmt.t(text).to_upper(), size, TEXT, true)


static func muted(text: String, size: int = 13) -> Label:
	return label(text, size, MUTED)


## Wrapping explanatory text (never forces its container wider).
static func note(text: String, size: int = 13) -> Label:
	var l := label(text, size, MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	return l


static func button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func(): Sfx.play("click"))
	b.pressed.connect(cb)
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	return b


static func accent_button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := button(text, cb, min_w)
	b.add_theme_stylebox_override("normal", _box(ACCENT, ACCENT.lightened(0.2), 1, 4, 14, 8))
	b.add_theme_stylebox_override("hover", _box(ACCENT.lightened(0.12), ACCENT.lightened(0.3), 1, 4, 14, 8))
	b.add_theme_stylebox_override("pressed", _box(ACCENT.darkened(0.2), ACCENT, 1, 4, 14, 8))
	return b


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func panel(child: Control = null, bg: Color = PANEL, pad: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(bg, LINE, pad))
	if child:
		p.add_child(child)
	return p


## Panel with a small uppercase heading; returns [panel, content_vbox].
static func card(heading: String, bg: Color = PANEL) -> Array:
	var v := vbox(8)
	if heading != "":
		v.add_child(label(Fmt.t(heading).to_upper(), 12, MUTED, true))
	var p := panel(v, bg)
	return [p, v]


static func spacer(h: bool = true) -> Control:
	var c := Control.new()
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func expand(c: Control, h: bool = true, v: bool = false) -> Control:
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if v:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func swatch(col: Color, w: int = 4, h: int = 18) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(w, h)
	return r


## Horizontal labelled bar for 0..100 values.
static func stat_bar(name: String, value: float, max_value: float = 100.0, col: Color = ACCENT, name_w: int = 150) -> HBoxContainer:
	var h := hbox(8)
	var n := label(name, 13, MUTED)
	n.custom_minimum_size.x = name_w
	n.clip_text = true
	h.add_child(n)
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := _box(col, Color(0, 0, 0, 0), 0, 3, 0, 0)
	bar.add_theme_stylebox_override("fill", fill)
	h.add_child(bar)
	var v := label("%d" % int(round(value)), 13, TEXT)
	v.custom_minimum_size.x = 30
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	return h


static func rating_color(v: float) -> Color:
	if v >= 80.0:
		return GOOD
	if v >= 65.0:
		return CYAN
	if v >= 50.0:
		return WARN
	return BAD


## Simple table: headers + rows of strings (or Controls). col_w: min widths, 0 = expand.
static func table(headers: Array, rows: Array, col_w: Array, highlight_rows: Array = []) -> VBoxContainer:
	var v := vbox(0)
	var head := _row(headers, col_w, true)
	v.add_child(head)
	for i in rows.size():
		var r := _row(rows[i], col_w, false)
		var bg := PANEL2 if i % 2 == 0 else PANEL
		if i in highlight_rows:
			bg = Color(ACCENT, 0.18)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _box(bg, Color(0, 0, 0, 0), 0, 0, 6, 3))
		p.add_child(r)
		v.add_child(p)
	return v


static func _row(cells: Array, col_w: Array, header: bool) -> Control:
	var h := hbox(6)
	for i in cells.size():
		var c = cells[i]
		var ctrl: Control
		if c is Control:
			ctrl = c
		else:
			ctrl = label(str(c), 12 if header else 14, MUTED if header else TEXT)
			ctrl.clip_text = true
		var w: int = col_w[i] if i < col_w.size() else 0
		if w > 0:
			ctrl.custom_minimum_size.x = w
		else:
			ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ctrl.custom_minimum_size.x = 120
		h.add_child(ctrl)
	if header:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _box(PANEL3, Color(0, 0, 0, 0), 0, 0, 6, 4))
		p.add_child(h)
		return p
	return h


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func option(items: Array, selected: int, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(Fmt.t(str(it)))
	o.select(selected)
	o.item_selected.connect(cb)
	return o


## Modal-ish message popup.
static func toast(parent: Node, text: String, col: Color = ACCENT) -> void:
	var p := panel(label(Fmt.t(text), 15), PANEL3)
	p.add_theme_stylebox_override("panel", _box(PANEL3, col, 2, 6, 16, 10))
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.position.y = 70
	p.z_index = 100
	parent.add_child(p)
	p.position.x = (parent.get_viewport().get_visible_rect().size.x - p.get_combined_minimum_size().x) * 0.5
	var tw := p.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


## Display name for a performance dimension key (e.g. "top_speed" -> "Top Speed", translated).
static func dim_name(key: String) -> String:
	return Fmt.t(key.capitalize())


## Labelled row used in forms: name on the left, control expanding on the right.
static func form_row(name: String, ctrl: Control, name_w: int = 150) -> HBoxContainer:
	var h := hbox(10)
	var l := label(name, 14)
	l.custom_minimum_size.x = name_w
	h.add_child(l)
	expand(ctrl)
	h.add_child(ctrl)
	return h


static func slider(min_v: float, max_v: float, step_v: float, value: float, cb: Callable, w: int = 180) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step_v
	sl.value = value
	sl.custom_minimum_size.x = w
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.value_changed.connect(cb)
	return sl


static func check(text: String, on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.toggled.connect(cb)
	return c
