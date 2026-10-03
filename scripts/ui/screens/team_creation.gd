extends Control
## New career: create the team and sign two drivers.

var setup := {
	"name": "Apex Dynamics", "abbr": "APX", "primary": Color("e10600"), "secondary": Color("ffffff"),
	"logo_shape": 0, "budget_id": "medium", "hq": "uk", "car_level": "mid", "philosophy": "balanced",
	"driver_ids": [], "difficulty": "normal", "calendar": [],
}
var logo: TeamLogo
var info_box: VBoxContainer
var driver_box: VBoxContainer
var start_btn: Button
var budget_lbl: Label
var free_agents: Array = []
var cal_btn: Button
var cal_dialog: AcceptDialog


func open(_params: Dictionary) -> void:
	# free agent pool (drivers not assigned to an AI team in the database)
	var taken := {}
	for t in DataDB.teams:
		for d in t["drivers"]:
			taken[d] = true
	for d in DataDB.drivers:
		if not taken.has(d["id"]):
			free_agents.append(Driver.from_dict(d))
	free_agents.sort_custom(func(a, b): return a.overall() > b.overall())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := UI.vbox(14)
	margin.add_child(root)
	var top := UI.hbox(12)
	top.add_child(UI.title("Create your team", 28))
	top.add_child(UI.spacer())
	top.add_child(UI.button(tr("Back"), func(): Game.goto("menu")))
	root.add_child(top)

	var cols := UI.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# ---- left: identity + setup
	var lcard: Array = UI.card("Identity")
	lcard[0].custom_minimum_size.x = 380
	cols.add_child(lcard[0])
	var lv: VBoxContainer = lcard[1]
	lv.add_child(_field(tr("Team name"), _line(setup["name"], 28, func(t): setup["name"] = t; _refresh())))
	lv.add_child(_field(tr("Abbreviation"), _line(setup["abbr"], 3, func(t): setup["abbr"] = t.to_upper(); _refresh())))
	var colors := UI.hbox(10)
	colors.add_child(UI.label(tr("Colours")))
	colors.add_child(UI.spacer())
	colors.add_child(_color_btn("primary"))
	colors.add_child(_color_btn("secondary"))
	lv.add_child(colors)
	lv.add_child(_field(tr("Logo"), UI.option(TeamLogo.SHAPES, 0, func(i): setup["logo_shape"] = i; _refresh())))
	var bal: Dictionary = DataDB.balance
	lv.add_child(HSeparator.new())
	lv.add_child(_field(tr("Budget"), _opt(bal["budgets"], "budget_id")))
	lv.add_child(_field(tr("Headquarters"), _opt(bal["headquarters"], "hq")))
	lv.add_child(_field(tr("Starting car"), _opt(bal["car_levels"], "car_level")))
	lv.add_child(_field(tr("Philosophy"), _opt(bal["philosophies"], "philosophy")))
	var diffs := Career.DIFFICULTY.keys()
	lv.add_child(_field(tr("Difficulty"), UI.option(diffs.map(func(k): return Career.DIFFICULTY[k]["name"]), diffs.find("normal"), func(i): setup["difficulty"] = diffs[i]; _refresh())))
	lv.add_child(HSeparator.new())
	setup["calendar"] = DataDB.championships[0]["calendar"].duplicate()
	cal_btn = UI.button("", _open_calendar)
	lv.add_child(_field(tr("Season calendar"), cal_btn))
	lv.add_child(UI.note(tr("Add your own tracks from the track creator to the season.")))

	# ---- middle: preview + explanation
	var mcard: Array = UI.card("Preview")
	mcard[0].custom_minimum_size.x = 300
	cols.add_child(mcard[0])
	var mv: VBoxContainer = mcard[1]
	var lh := UI.hbox(14)
	logo = TeamLogo.new()
	logo.custom_minimum_size = Vector2(110, 110)
	lh.add_child(logo)
	budget_lbl = UI.label("", 14)
	budget_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.expand(budget_lbl)
	lh.add_child(budget_lbl)
	mv.add_child(lh)
	info_box = UI.vbox(6)
	mv.add_child(info_box)

	# ---- right: drivers
	var rcard: Array = UI.card("Sign two drivers (free agents)")
	UI.expand(rcard[0], true, true)
	cols.add_child(rcard[0])
	driver_box = UI.vbox(4)
	var sc := UI.scroll(driver_box)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rcard[1].add_child(sc)
	rcard[1].size_flags_vertical = Control.SIZE_EXPAND_FILL

	var bottom := UI.hbox(10)
	bottom.add_child(UI.spacer())
	start_btn = UI.accent_button(tr("Start Career"), _start, 220)
	bottom.add_child(start_btn)
	root.add_child(bottom)
	cal_dialog = AcceptDialog.new()
	cal_dialog.title = tr("Season calendar")
	cal_dialog.ok_button_text = tr("Done")
	var picker := CalendarPicker.new()
	picker.custom_minimum_size = Vector2(880, 460)
	picker.setup(setup["calendar"])
	picker.changed.connect(func(cal): setup["calendar"] = cal.duplicate(); _refresh())
	cal_dialog.add_child(picker)
	add_child(cal_dialog)
	_refresh()


func _open_calendar() -> void:
	cal_dialog.popup_centered(Vector2i(920, 540))


func _field(name: String, ctrl: Control) -> HBoxContainer:
	var h := UI.hbox(10)
	var l := UI.label(name)
	l.custom_minimum_size.x = 130
	h.add_child(l)
	UI.expand(ctrl)
	h.add_child(ctrl)
	return h


func _line(text: String, max_len: int, cb: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.max_length = max_len
	e.text_changed.connect(cb)
	return e


func _color_btn(key: String) -> ColorPickerButton:
	var b := ColorPickerButton.new()
	b.color = setup[key]
	b.edit_alpha = false
	b.custom_minimum_size = Vector2(70, 30)
	b.color_changed.connect(func(c): setup[key] = c; _refresh())
	return b


func _opt(list: Array, key: String) -> OptionButton:
	var names := list.map(func(e): return e["name"])
	var ids := list.map(func(e): return e["id"])
	return UI.option(names, ids.find(setup[key]), func(i): setup[key] = ids[i]; _refresh())


func _starting_budget() -> int:
	var bal: Dictionary = DataDB.balance
	var b := DataDB.find_in(bal["budgets"], setup["budget_id"])
	var lvl := DataDB.find_in(bal["car_levels"], setup["car_level"])
	var ph := DataDB.philosophy(setup["philosophy"])
	return int(float(b["amount"]) * float(lvl["budget_mult"]) * float(ph.get("mods", {}).get("budget_mult", 1.0)))


func _salary_total() -> int:
	var s := 0
	var ph: Dictionary = DataDB.philosophy(setup["philosophy"]).get("mods", {})
	for d in free_agents:
		if d.id in setup["driver_ids"]:
			s += int(d.salary * (float(ph.get("young_salary_mult", 1.0)) if d.age <= 22 else 1.0))
	return s


func _refresh() -> void:
	logo.set_style(setup["primary"], setup["secondary"], setup["logo_shape"], setup["abbr"])
	var budget := _starting_budget()
	budget_lbl.text = "%s\n%s: %s\n%s: %s" % [setup["name"], tr("Starting budget"), Fmt.money(budget), tr("Driver salaries / season"), Fmt.money(_salary_total())]
	if cal_btn:
		cal_btn.text = tr("%d rounds — edit") % setup["calendar"].size()
	UI.clear(info_box)
	var bal: Dictionary = DataDB.balance
	for pair in [["Budget", bal["budgets"], "budget_id"], ["Headquarters", bal["headquarters"], "hq"], ["Car", bal["car_levels"], "car_level"], ["Philosophy", bal["philosophies"], "philosophy"]]:
		var e := DataDB.find_in(pair[1], setup[pair[2]])
		info_box.add_child(UI.label(tr(pair[0]) + ": " + tr(e["name"]), 14, UI.TEXT))
		var d := UI.muted(tr(e.get("desc", "")), 13)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_box.add_child(d)
	_refresh_drivers()
	var ok: bool = setup["driver_ids"].size() == 2 and setup["name"].strip_edges() != "" and setup["abbr"].length() >= 2
	start_btn.disabled = not ok
	start_btn.tooltip_text = "" if ok else tr("Pick a name, a 2-3 letter abbreviation and two drivers.")


func _refresh_drivers() -> void:
	UI.clear(driver_box)
	var rows := []
	var hl := []
	for i in free_agents.size():
		var d: Driver = free_agents[i]
		var picked: bool = d.id in setup["driver_ids"]
		if picked:
			hl.append(i)
		var b := UI.button(tr("Release") if picked else tr("Sign"), _toggle_driver.bind(d.id))
		b.disabled = not picked and setup["driver_ids"].size() >= 2
		var traits := d.traits_text()
		rows.append([b, d.full_name(), str(d.age), d.nationality, _rate(d.overall()), _rate(d.attr("qualifying_pace")), _rate(d.attr("race_pace")), _rate(d.attr("consistency")), _rate(d.attr("potential")), traits, Fmt.money(d.salary)])
	driver_box.add_child(UI.table(["", tr("Driver"), tr("Age"), tr("Nat"), tr("OVR"), tr("Quali"), tr("Race"), tr("Cons"), tr("Pot"), tr("Traits"), tr("Salary")], rows, [74, 0, 34, 40, 38, 44, 40, 40, 34, 150, 66], hl))


func _rate(v: float) -> Label:
	return UI.label(str(int(v)), 14, UI.rating_color(v))


func _toggle_driver(id: String) -> void:
	var ids: Array = setup["driver_ids"]
	if id in ids:
		ids.erase(id)
	elif ids.size() < 2:
		ids.append(id)
	_refresh()


func _start() -> void:
	Game.start_career(setup)
	Game.goto("hub")
