extends VBoxContainer
## Car development: per-component upgrades, reliability work and rebuilds.

var hub
var career: Career
var team: Team


func build(p_hub) -> void:
	hub = p_hub
	career = hub.career
	team = career.player_team()
	add_theme_constant_override("separation", 12)
	var head := UI.hbox()
	head.add_child(UI.title("Car development", 22))
	head.add_child(UI.spacer())
	head.add_child(UI.label("Balance: " + Fmt.money(team.finance.balance), 16, UI.GOOD if team.finance.balance >= 0 else UI.BAD))
	add_child(head)
	var row := UI.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)

	var left: Array = UI.card("Performance dimensions  (overall %d)" % team.car.overall())
	left[0].custom_minimum_size.x = 380
	row.add_child(left[0])
	var dims := team.car.dimensions()
	for k in DataDB.dimensions:
		left[1].add_child(UI.stat_bar(k.capitalize(), dims[k], 100.0, UI.rating_color(dims[k])))
	left[1].add_child(UI.stat_bar("Reliability", dims["reliability"], 100.0, UI.rating_color(dims["reliability"])))
	left[1].add_child(UI.muted("Weight: %d kg" % int(team.car.total_weight())))
	var note := UI.muted("Each component feeds several dimensions. Upgrading raises performance but new parts are less proven (-reliability). Worn parts lose performance and fail more often; rebuild them between races.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left[1].add_child(note)

	var right: Array = UI.card("Components")
	UI.expand(right[0], true, true)
	row.add_child(right[0])
	var rows := []
	for d in DataDB.components:
		var cid: String = d["id"]
		var comp: CarComponent = team.car.components[cid]
		var up_cost := career.upgrade_cost(team, cid)
		var up := UI.button("Upgrade %s (+%.1f)" % [Fmt.money(up_cost), career.upgrade_gain(team, cid)], _upgrade.bind(cid))
		up.disabled = not team.finance.can_afford(up_cost) or comp.performance >= 100.0
		var rel_cost := career.reliability_cost(team, cid)
		var rel := UI.button("+Rel %s" % Fmt.money(rel_cost), _reliability.bind(cid))
		rel.disabled = not team.finance.can_afford(rel_cost) or comp.reliability >= 99.0
		var m_cost := career.maintenance_cost(team, cid)
		var rb := UI.button("Rebuild %s" % Fmt.money(m_cost), _rebuild.bind(cid))
		rb.disabled = m_cost <= 0 or not team.finance.can_afford(m_cost)
		var dims_txt := ", ".join((d["dims"] as Dictionary).keys().map(func(k): return k.replace("_", " ")))
		var name_l := UI.label(comp.display_name(), 14)
		name_l.tooltip_text = "Affects: " + dims_txt
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		rows.append([name_l, "Lv %d" % comp.level,
			UI.label("%.1f" % comp.performance, 14, UI.rating_color(comp.performance)),
			UI.label("%.0f" % comp.effective_reliability(), 14, UI.rating_color(comp.effective_reliability())),
			UI.label(Fmt.pct(comp.wear), 14, UI.BAD if comp.wear > 0.5 else (UI.WARN if comp.wear > 0.25 else UI.TEXT)),
			up, rel, rb])
	var tbl := UI.table(["Component", "Lv", "Perf", "Rel", "Wear", "", "", ""], rows, [0, 50, 50, 44, 50, 210, 120, 140])
	var sc := UI.scroll(tbl)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	right[1].add_child(sc)


func _upgrade(cid: String) -> void:
	if career.upgrade_component(team, cid):
		hub.refresh()
		UI.toast(hub, "%s upgraded." % team.car.components[cid].display_name(), UI.GOOD)


func _reliability(cid: String) -> void:
	if career.improve_reliability(team, cid):
		hub.refresh()


func _rebuild(cid: String) -> void:
	if career.maintain_component(team, cid):
		hub.refresh()
