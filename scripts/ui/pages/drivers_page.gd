extends VBoxContainer
## Driver details + replacing a driver with a free agent.

var hub
var career: Career
var team: Team
var replacing := ""


func build(p_hub) -> void:
	hub = p_hub
	career = hub.career
	team = career.player_team()
	add_theme_constant_override("separation", 12)
	add_child(UI.title("Drivers", 22))
	var row := UI.hbox(14)
	add_child(row)
	for did in team.driver_ids:
		row.add_child(_driver_card(career.drivers[did]))

	var fa: Array = UI.card("Free agents" + ("  —  choose a replacement for %s" % career.drivers[replacing].full_name() if replacing != "" else ""))
	UI.expand(fa[0], true, true)
	add_child(fa[0])
	fa[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rows := []
	for d in career.free_agents():
		var fee := int(d.salary * 0.25)
		var b := UI.button("Sign (fee %s)" % Fmt.money(fee), _sign.bind(d.id))
		b.disabled = replacing == "" or not team.finance.can_afford(fee)
		rows.append([b, d.full_name(), str(d.age), d.nationality, _r(d.overall()), _r(d.attr("qualifying_pace")), _r(d.attr("race_pace")), _r(d.attr("consistency")), _r(d.attr("racecraft")), _r(d.attr("potential")), ", ".join(d.traits), Fmt.money(career.player_salary_for(d, team))])
	var tbl := UI.table(["", "Driver", "Age", "Nat", "OVR", "Quali", "Race", "Cons", "Craft", "Pot", "Traits", "Salary/yr"], rows, [140, 0, 34, 40, 38, 44, 40, 40, 40, 34, 150, 70])
	var sc := UI.scroll(tbl)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fa[1].add_child(sc)
	if replacing == "":
		fa[1].add_child(UI.note("Press 'Replace' on one of your drivers to sign a free agent in their place (signing fee = 25% of yearly salary)."))


func _driver_card(d: Driver) -> PanelContainer:
	var cv: Array = UI.card("")
	UI.expand(cv[0])
	var v: VBoxContainer = cv[1]
	var h := UI.hbox()
	h.add_child(UI.label(d.full_name(), 20, UI.TEXT, true))
	h.add_child(UI.spacer())
	h.add_child(UI.button("Cancel" if replacing == d.id else "Replace", _toggle_replace.bind(d.id)))
	v.add_child(h)
	v.add_child(UI.muted("%s  ·  Age %d  ·  %s  ·  OVR %d" % [d.nationality, d.age, ", ".join(d.traits), d.overall()]))
	v.add_child(UI.muted("Contract: %s / season, %d season(s) left  ·  Season points %d" % [Fmt.money(d.salary), d.contract_years, career.driver_points.get(d.id, 0)]))
	v.add_child(UI.stat_bar("Morale", d.morale, 100.0, UI.rating_color(d.morale)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	for k in Driver.ATTRIBUTE_NAMES:
		var b := UI.stat_bar(Driver.ATTRIBUTE_NAMES[k], d.attr(k), 100.0, UI.rating_color(d.attr(k)), 120)
		b.custom_minimum_size.x = 260
		grid.add_child(b)
	v.add_child(grid)
	v.add_child(UI.muted("Career: %d starts · %d wins · %d podiums · %d poles · %d points · %d DNFs" % [d.stats["starts"], d.stats["wins"], d.stats["podiums"], d.stats["poles"], d.stats["points"], d.stats["dnfs"]]))
	return cv[0]


func _r(v: float) -> Label:
	return UI.label(str(int(v)), 14, UI.rating_color(v))


func _toggle_replace(did: String) -> void:
	replacing = "" if replacing == did else did
	UI.clear(self)
	build(hub)


func _sign(new_id: String) -> void:
	var nd: Driver = career.drivers[new_id]
	var fee := int(nd.salary * 0.25)
	if replacing == "" or not team.finance.can_afford(fee):
		return
	var old: Driver = career.drivers[replacing]
	var i := team.driver_ids.find(replacing)
	team.driver_ids[i] = new_id
	old.team_id = ""
	old.contract_years = 0
	nd.team_id = team.id
	nd.salary = career.player_salary_for(nd, team)
	nd.contract_years = 2
	if not career.driver_points.has(new_id):
		career.driver_points[new_id] = 0
	team.finance.add(-fee, "Driver salaries", "Signing fee: " + nd.full_name(), career.season, career.round_idx)
	career.notify("%s signed to replace %s." % [nd.full_name(), old.full_name()], "info")
	# the remaining driver doesn't love the churn
	for did in team.driver_ids:
		if did != new_id:
			career.drivers[did].change_morale(-2.0)
	replacing = ""
	hub.refresh()
