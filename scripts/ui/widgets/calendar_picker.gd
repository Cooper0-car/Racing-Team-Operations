class_name CalendarPicker
extends HBoxContainer
## Builds a season calendar from all valid tracks (built-in + custom). Emits `changed`.

signal changed(calendar: Array)

const MAX_ROUNDS := 24

var calendar: Array = []
var _avail: VBoxContainer
var _list: VBoxContainer
var _count: Label


func setup(initial: Array) -> void:
	calendar = initial.duplicate()
	add_theme_constant_override("separation", 14)
	var left := UI.vbox(6)
	UI.expand(left, true, true)
	left.add_child(UI.label(tr("AVAILABLE TRACKS"), 12, UI.MUTED, true))
	_avail = UI.vbox(3)
	var sa := UI.scroll(_avail)
	sa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sa)
	add_child(left)
	var right := UI.vbox(6)
	UI.expand(right, true, true)
	var rh := UI.hbox()
	rh.add_child(UI.label(tr("SEASON CALENDAR"), 12, UI.MUTED, true))
	rh.add_child(UI.spacer())
	_count = UI.label("", 13)
	rh.add_child(_count)
	right.add_child(rh)
	_list = UI.vbox(3)
	var sl := UI.scroll(_list)
	sl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sl)
	var bh := UI.hbox(6)
	bh.add_child(UI.button(tr("Default calendar"), func(): calendar = DataDB.championships[0]["calendar"].duplicate(); _refresh()))
	bh.add_child(UI.button(tr("Shuffle"), func(): calendar.shuffle(); _refresh()))
	right.add_child(bh)
	add_child(right)
	_refresh()


func _refresh() -> void:
	UI.clear(_avail)
	for id in DataDB.sorted_track_ids():
		var t := TrackData.load_id(id)
		if t == null:
			continue
		var h := UI.hbox(6)
		var builtin := DataDB.is_builtin_track(id)
		var nm := UI.label(t.name + ("" if builtin else " ★"), 14)
		nm.clip_text = true
		UI.expand(nm)
		h.add_child(nm)
		h.add_child(UI.muted("%s · %s" % [Fmt.km(t.length), tr("%d corners") % t.corners.size()], 12))
		var add := UI.button(tr("Add"), _add.bind(id))
		add.disabled = not t.is_valid() or calendar.size() >= MAX_ROUNDS
		if not t.is_valid():
			add.tooltip_text = tr("This track has validation errors.")
		h.add_child(add)
		_avail.add_child(h)
	UI.clear(_list)
	for i in calendar.size():
		var h2 := UI.hbox(4)
		var name := str(DataDB.get_track(calendar[i]).get("name", calendar[i]))
		var l := UI.label("R%d  %s" % [i + 1, name], 14)
		l.clip_text = true
		UI.expand(l)
		h2.add_child(l)
		var up := UI.button("▲", _move.bind(i, -1))
		up.disabled = i == 0
		h2.add_child(up)
		var dn := UI.button("▼", _move.bind(i, 1))
		dn.disabled = i == calendar.size() - 1
		h2.add_child(dn)
		var rm := UI.button("✕", _remove.bind(i))
		rm.disabled = calendar.size() <= 1
		h2.add_child(rm)
		_list.add_child(h2)
	_count.text = tr("%d rounds") % calendar.size()
	changed.emit(calendar)


func _add(id: String) -> void:
	if calendar.size() < MAX_ROUNDS:
		calendar.append(id)
		_refresh()


func _move(i: int, d: int) -> void:
	var j := i + d
	if j < 0 or j >= calendar.size():
		return
	var tmp = calendar[i]
	calendar[i] = calendar[j]
	calendar[j] = tmp
	_refresh()


func _remove(i: int) -> void:
	if calendar.size() > 1:
		calendar.remove_at(i)
		_refresh()
