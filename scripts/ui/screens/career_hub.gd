extends Control
## Career main interface: top bar, navigation, page area.

const PAGES := [
	["dashboard", "Dashboard", preload("res://scripts/ui/pages/dashboard_page.gd")],
	["weekend", "Race Weekend", preload("res://scripts/ui/pages/weekend_page.gd")],
	["car", "Car", preload("res://scripts/ui/pages/car_page.gd")],
	["drivers", "Drivers", preload("res://scripts/ui/pages/drivers_page.gd")],
	["standings", "Championship", preload("res://scripts/ui/pages/standings_page.gd")],
	["calendar", "Calendar", preload("res://scripts/ui/pages/calendar_page.gd")],
	["finance", "Finance", preload("res://scripts/ui/pages/finance_page.gd")],
	["saves", "Save / Load", preload("res://scripts/ui/pages/saves_page.gd")],
]

var career: Career
var top_bar: HBoxContainer
var nav: VBoxContainer
var content: MarginContainer
var current_page := "dashboard"
var nav_buttons := {}


func open(params: Dictionary) -> void:
	career = Game.career
	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var tb_panel := UI.panel(null, UI.PANEL, 10)
	top_bar = UI.hbox(14)
	tb_panel.add_child(top_bar)
	root.add_child(tb_panel)
	var body := UI.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	nav = UI.vbox(4)
	var nav_panel := UI.panel(nav, UI.PANEL, 10)
	nav_panel.custom_minimum_size.x = 210
	body.add_child(nav_panel)
	content = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 16)
	UI.expand(content, true, true)
	body.add_child(content)
	for p in PAGES:
		var b := UI.button(tr(p[1]), show_page.bind(p[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav.add_child(b)
		nav_buttons[p[0]] = b
	nav.add_child(UI.spacer(false))
	for extra in [["Track Creator", func(): Game.goto("editor", {"back": "hub"})], ["Track Library", func(): Game.goto("library", {"back": "hub"})],
			["Settings", func(): Game.goto("settings", {"back": "hub", "back_params": {"page": current_page}})], ["Main Menu", _to_menu]]:
		var eb := UI.button(tr(extra[0]), extra[1])
		eb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav.add_child(eb)
	show_page(params.get("page", "dashboard"))


func refresh_top_bar() -> void:
	UI.clear(top_bar)
	var t := career.player_team()
	top_bar.add_child(TeamLogo.make(t, 44))
	var nm := UI.vbox(0)
	nm.add_child(UI.label(t.name, 20, UI.TEXT, true))
	nm.add_child(UI.muted("%s  ·  %s" % [tr(DataDB.get_championship(career.championship_id).get("name", "")), tr(Career.DIFFICULTY[career.difficulty]["name"])], 12))
	top_bar.add_child(nm)
	top_bar.add_child(UI.spacer())
	_stat(top_bar, "Season", "%d" % career.season)
	_stat(top_bar, "Round", "%d / %d" % [mini(career.round_idx + 1, career.calendar.size()), career.calendar.size()])
	_stat(top_bar, "Position", "P%d" % career.team_position(t.id))
	_stat(top_bar, "Points", "%d" % career.team_points.get(t.id, 0))
	_stat(top_bar, "Reputation", "%d" % int(t.reputation))
	_stat(top_bar, "Balance", Fmt.money(t.finance.balance), UI.GOOD if t.finance.balance >= 0 else UI.BAD)
	if career.is_season_over():
		top_bar.add_child(UI.accent_button(tr("End Season ▶"), _end_season))
	else:
		top_bar.add_child(UI.accent_button(tr("Race Weekend ▶"), show_page.bind("weekend")))


func _stat(parent: Control, name: String, value: String, col: Color = UI.TEXT) -> void:
	var v := UI.vbox(0)
	v.add_child(UI.muted(tr(name).to_upper(), 11))
	v.add_child(UI.label(value, 18, col, true))
	parent.add_child(v)


func show_page(id: String) -> void:
	current_page = id
	refresh_top_bar()
	for k in nav_buttons:
		var b: Button = nav_buttons[k]
		if k == id:
			b.add_theme_stylebox_override("normal", UI._box(UI.ACCENT.darkened(0.35), UI.ACCENT, 1, 4, 8, 6))
		else:
			b.remove_theme_stylebox_override("normal")
	UI.clear(content)
	for p in PAGES:
		if p[0] == id:
			var page: Control = p[2].new()
			UI.expand(page, true, true)
			content.add_child(page)
			page.build(self)
			return


## Called by pages after they change career state.
func refresh() -> void:
	show_page(current_page)


func _end_season() -> void:
	var s := career.end_season()
	Game.autosave()
	show_page("dashboard")
	UI.toast(self, tr("Season %d complete — Champion: %s (%s). You finished P%d.") % [s["season"], s["driver_champion"], s["team_champion"], s["player_position"]], UI.GOOD)
	Sfx.play("flag")


func _to_menu() -> void:
	Game.autosave()
	Game.goto("menu")
