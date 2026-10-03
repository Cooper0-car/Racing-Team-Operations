class_name Team
extends RefCounted

var id: String = ""
var name: String = ""
var abbr: String = ""
var primary: Color = Color.RED
var secondary: Color = Color.WHITE
var logo_shape: int = 0            # index into TeamLogo.SHAPES
var hq: String = "uk"
var philosophy: String = "balanced"
var reputation: float = 35.0
var is_player: bool = false
var driver_ids: Array = []         # [driver1, driver2]
var car: Car
var finance: Finance = Finance.new()


func mods() -> Dictionary:
	return DataDB.philosophy(philosophy).get("mods", {})


func mod(key: String, default_value = 0.0):
	return mods().get(key, default_value)


func hq_bonus() -> Dictionary:
	return DataDB.balance.get("hq_bonus", {}).get(hq, {})


func hq_def() -> Dictionary:
	return DataDB.find_in(DataDB.balance.get("headquarters", []), hq)


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "abbr": abbr,
		"primary": primary.to_html(false), "secondary": secondary.to_html(false),
		"logo_shape": logo_shape, "hq": hq, "philosophy": philosophy, "reputation": reputation,
		"is_player": is_player, "driver_ids": driver_ids, "car": car.to_dict(), "finance": finance.to_dict(),
	}


static func from_dict(d: Dictionary) -> Team:
	var t := Team.new()
	t.id = d.get("id", "")
	t.name = d.get("name", "")
	t.abbr = d.get("abbr", "")
	t.primary = Color.html(d.get("primary", "ff0000"))
	t.secondary = Color.html(d.get("secondary", "ffffff"))
	t.logo_shape = int(d.get("logo_shape", 0))
	t.hq = d.get("hq", "uk")
	t.philosophy = d.get("philosophy", "balanced")
	t.reputation = float(d.get("reputation", 35))
	t.is_player = bool(d.get("is_player", false))
	t.driver_ids = d.get("driver_ids", []).duplicate()
	t.car = Car.from_dict(d.get("car", {}))
	t.finance = Finance.from_dict(d.get("finance", {}))
	return t
