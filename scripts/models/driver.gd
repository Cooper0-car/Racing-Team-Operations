class_name Driver
extends RefCounted
## A racing driver. Attributes are 20..99.

const ATTRIBUTE_NAMES := {
	"raw_pace": "Raw Pace", "qualifying_pace": "Qualifying Pace", "race_pace": "Race Pace",
	"consistency": "Consistency", "racecraft": "Racecraft", "overtaking": "Overtaking",
	"defending": "Defending", "braking": "Braking", "wet_skill": "Wet Weather",
	"tire_management": "Tire Management", "fuel_management": "Fuel Management", "starts": "Starts",
	"aggression": "Aggression", "risk_taking": "Risk Taking", "feedback": "Feedback Quality",
	"adaptability": "Adaptability", "concentration": "Concentration", "fitness": "Fitness",
	"experience": "Experience", "potential": "Development Potential",
	"marketability": "Marketability", "reputation": "Reputation",
}

var id: String = ""
var first_name: String = ""
var last_name: String = ""
var nationality: String = ""
var age: int = 25
var traits: Array = []
var attributes: Dictionary = {}
var morale: float = 70.0
var team_id: String = ""            # "" = free agent
var salary: int = 0                 # per season
var contract_years: int = 0
# career stats
var stats: Dictionary = {"starts": 0, "wins": 0, "podiums": 0, "poles": 0, "points": 0, "dnfs": 0}


func full_name() -> String:
	return first_name + " " + last_name


func short_name() -> String:
	return last_name.substr(0, 3).to_upper()


func traits_text() -> String:
	return ", ".join(traits.map(func(t): return tr(t)))


func attr(key: String) -> float:
	return float(attributes.get(key, 50))


## Weighted single-number rating used in lists.
func overall() -> int:
	return int(round((attr("race_pace") * 2.0 + attr("qualifying_pace") + attr("consistency") + attr("racecraft") + attr("tire_management")) / 6.0))


func change_morale(delta: float) -> void:
	morale = clamp(morale + delta, 0.0, 100.0)


func to_dict() -> Dictionary:
	return {
		"id": id, "first_name": first_name, "last_name": last_name, "nationality": nationality,
		"age": age, "traits": traits, "attributes": attributes, "morale": morale,
		"team_id": team_id, "salary": salary, "contract_years": contract_years, "stats": stats,
	}


static func from_dict(d: Dictionary) -> Driver:
	var dr := Driver.new()
	dr.id = d.get("id", "")
	dr.first_name = d.get("first_name", "")
	dr.last_name = d.get("last_name", "")
	dr.nationality = d.get("nationality", "")
	dr.age = int(d.get("age", 25))
	dr.traits = d.get("traits", []).duplicate()
	dr.attributes = {}
	for k in d.get("attributes", {}):
		dr.attributes[k] = int(d["attributes"][k])
	dr.morale = float(d.get("morale", 70))
	dr.team_id = d.get("team_id", "")
	dr.salary = int(d.get("salary", 0))
	dr.contract_years = int(d.get("contract_years", 0))
	var s: Dictionary = d.get("stats", {})
	for k in dr.stats:
		dr.stats[k] = int(s.get(k, 0))
	return dr
