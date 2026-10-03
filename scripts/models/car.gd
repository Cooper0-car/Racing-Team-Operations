class_name Car
extends RefCounted
## A team's race car: a set of components. Performance dimensions are derived, never stored.

var components: Dictionary = {}   # id -> CarComponent


static func create(perf: float, rel: float, rng: RandomNumberGenerator = null) -> Car:
	var car := Car.new()
	for d in DataDB.components:
		var c := CarComponent.new()
		c.id = d["id"]
		var spread := 0.0
		var rspread := 0.0
		if rng:
			spread = rng.randf_range(-4.0, 4.0)
			rspread = rng.randf_range(-4.0, 4.0)
		c.performance = clamp(perf + spread, 10.0, 100.0)
		c.reliability = clamp(rel + rspread, 10.0, 100.0)
		c.weight_kg = float(d.get("weight_kg", 0))
		car.components[c.id] = c
	return car


func get_component(id: String) -> CarComponent:
	return components.get(id)


## Performance dimensions 0..100, computed as weighted averages of component performance.
func dimensions() -> Dictionary:
	var sums := {}
	var weights := {}
	for dim in DataDB.dimensions:
		sums[dim] = 0.0
		weights[dim] = 0.0
	for cid in components:
		var c: CarComponent = components[cid]
		var dims: Dictionary = c.def().get("dims", {})
		for dim in dims:
			if sums.has(dim):
				sums[dim] += c.effective_performance() * float(dims[dim])
				weights[dim] += float(dims[dim])
	var out := {}
	for dim in sums:
		out[dim] = sums[dim] / weights[dim] if weights[dim] > 0.0 else 50.0
	out["reliability"] = average_reliability()
	return out


func average_reliability() -> float:
	if components.is_empty():
		return 0.0
	var s := 0.0
	for cid in components:
		s += (components[cid] as CarComponent).effective_reliability()
	return s / components.size()


func total_weight() -> float:
	var w := 0.0
	for cid in components:
		w += (components[cid] as CarComponent).weight_kg
	return w


## Single headline number for lists.
func overall() -> int:
	var d := dimensions()
	var s := 0.0
	for k in ["top_speed", "acceleration", "braking", "low_speed_cornering", "high_speed_cornering", "traction"]:
		s += d[k]
	return int(round(s / 6.0))


func to_dict() -> Dictionary:
	var comps := {}
	for cid in components:
		comps[cid] = (components[cid] as CarComponent).to_dict()
	return {"components": comps}


static func from_dict(d: Dictionary) -> Car:
	var car := Car.new()
	var comps: Dictionary = d.get("components", {})
	for cid in comps:
		car.components[cid] = CarComponent.from_dict(comps[cid])
	# Components added to the database after the save was made get default values.
	for def in DataDB.components:
		if not car.components.has(def["id"]):
			var c := CarComponent.new()
			c.id = def["id"]
			c.weight_kg = float(def.get("weight_kg", 0))
			car.components[c.id] = c
	return car
