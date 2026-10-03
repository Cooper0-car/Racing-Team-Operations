extends VBoxContainer


func build(hub) -> void:
	var c: Career = hub.career
	var t := c.player_team()
	add_theme_constant_override("separation", 12)
	add_child(UI.title("Finance", 22))
	var row := UI.hbox(14)
	add_child(row)

	var bal: Array = UI.card("Balance")
	UI.expand(bal[0])
	row.add_child(bal[0])
	bal[1].add_child(UI.label(Fmt.money(t.finance.balance), 30, UI.GOOD if t.finance.balance >= 0 else UI.BAD, true))
	# projected per-race cash flow
	var rounds := float(c.calendar.size())
	var salaries := 0
	for did in t.driver_ids:
		salaries += int(c.drivers[did].salary / rounds)
	var travel := int(DataDB.balance["travel_cost_per_race"] * float(t.hq_def().get("travel_mult", 1.0)))
	var ops := int(DataDB.balance["base_operations_cost_per_race"])
	var sponsor := int(float(DataDB.balance["base_sponsor_per_race_at_rep_50"]) * (0.4 + t.reputation / 50.0 * 0.6) * float(t.hq_bonus().get("sponsor_mult", 1.0)) * float(Career.DIFFICULTY[c.difficulty]["player_income"]))
	bal[1].add_child(UI.label(tr("Projected per race"), 14, UI.MUTED))
	bal[1].add_child(UI.label("%s  +%s" % [tr("Sponsors"), Fmt.money(sponsor)], 14, UI.GOOD))
	bal[1].add_child(UI.note(tr("Prize money depends on results (P20 %s … P1 %s per car)") % [Fmt.money(DataDB.balance["prize_per_position"][19]), Fmt.money(DataDB.balance["prize_per_position"][0])]))
	bal[1].add_child(UI.label("%s  -%s" % [tr("Driver salaries"), Fmt.money(salaries)], 14, UI.BAD))
	bal[1].add_child(UI.label("%s  -%s" % [tr("Travel"), Fmt.money(travel)], 14, UI.BAD))
	bal[1].add_child(UI.label("%s  -%s" % [tr("Operations"), Fmt.money(ops)], 14, UI.BAD))

	var sea: Array = UI.card(tr("Season %d by category") % c.season)
	UI.expand(sea[0])
	row.add_child(sea[0])
	var sm := t.finance.summary(c.season)
	var keys := sm.keys()
	keys.sort_custom(func(a, b): return sm[a] > sm[b])
	for k in keys:
		if k == "Start":
			continue
		var h := UI.hbox()
		h.add_child(UI.label(tr(k), 14))
		h.add_child(UI.spacer())
		h.add_child(UI.label(Fmt.money(sm[k]), 14, UI.GOOD if sm[k] >= 0 else UI.BAD))
		sea[1].add_child(h)

	# balance history chart (end of each round this season)
	var hist := []
	var bal_now := t.finance.balance
	var per_round := {}
	for e in t.finance.ledger:
		if int(e["season"]) == c.season:
			per_round[int(e["round"])] = per_round.get(int(e["round"]), 0) + int(e["amount"])
	var running := bal_now
	var vals := []
	for r in range(c.round_idx, -1, -1):
		vals.push_front(running / 1000000.0)
		running -= per_round.get(r, 0)
	vals.push_front(running / 1000000.0)
	var ch: Array = UI.card(tr("Balance trend ($M), season %d") % c.season)
	UI.expand(ch[0])
	row.add_child(ch[0])
	var chart := LineChart.new()
	chart.x_label = tr("Round")
	chart.y_format = "%.1f"
	chart.custom_minimum_size = Vector2(320, 200)
	chart.set_series([{"name": tr("Balance"), "color": UI.GOOD, "values": vals}])
	ch[1].add_child(chart)

	var led: Array = UI.card("Transactions")
	UI.expand(led[0], true, true)
	add_child(led[0])
	var rows := []
	var entries := t.finance.ledger.duplicate()
	entries.reverse()
	for e in entries.slice(0, 80):
		if int(e["amount"]) == 0:
			continue
		rows.append(["S%d R%d" % [e["season"], int(e["round"]) + 1], tr(e["category"]), Finance.note_text(e), UI.label(Fmt.money(int(e["amount"])), 14, UI.GOOD if int(e["amount"]) >= 0 else UI.BAD)])
	var sc := UI.scroll(UI.table([tr("When"), tr("Category"), tr("Description"), tr("Amount")], rows, [70, 150, 0, 100]))
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	led[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	led[1].add_child(sc)
