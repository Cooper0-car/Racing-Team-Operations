class_name CarComponent
extends RefCounted
## One physical part of the car. performance/reliability 0..100, wear 0..1.

var id: String = ""
var performance: float = 60.0
var reliability: float = 78.0
var wear: float = 0.0
var level: int = 0                  # number of upgrades applied
var weight_kg: float = 0.0


func def() -> Dictionary:
	return DataDB.component_by_id.get(id, {})


func display_name() -> String:
	return def().get("name", id)


## Reliability after wear is taken into account.
func effective_reliability() -> float:
	return clamp(reliability - wear * 35.0, 1.0, 100.0)


## Performance after wear (worn parts lose a little performance).
func effective_performance() -> float:
	return performance * (1.0 - wear * 0.06)


## Chance (0..1) that this part fails during one race lap.
func failure_chance_per_lap() -> float:
	var r := effective_reliability() / 100.0
	return pow(1.0 - r, 2.2) * 0.0035


func to_dict() -> Dictionary:
	return {"id": id, "performance": performance, "reliability": reliability, "wear": wear, "level": level, "weight_kg": weight_kg}


static func from_dict(d: Dictionary) -> CarComponent:
	var c := CarComponent.new()
	c.id = d.get("id", "")
	c.performance = float(d.get("performance", 60))
	c.reliability = float(d.get("reliability", 78))
	c.wear = float(d.get("wear", 0))
	c.level = int(d.get("level", 0))
	c.weight_kg = float(d.get("weight_kg", 0))
	return c
