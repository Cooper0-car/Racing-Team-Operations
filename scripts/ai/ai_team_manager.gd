class_name AITeamManager
extends RefCounted
## Decisions made by AI-controlled teams between races.
## AI teams play by the same rules as the player: same prices, same upgrade effects.

const PRIORITY := {
	"balanced":       ["engine", "floor", "suspension", "brakes", "rear_wing", "front_wing", "chassis", "gearbox"],
	"aggressive_dev": ["floor", "engine", "front_wing", "rear_wing", "diffuser", "turbo", "suspension"],
	"reliability":    ["engine", "gearbox", "suspension", "chassis", "brakes", "cooling"],
	"race":           ["tire_package", "suspension", "engine", "floor", "brakes"],
	"qualifying":     ["engine", "floor", "front_wing", "rear_wing", "turbo", "weight_reduction"],
}


static func after_race(career: Career) -> void:
	var diff: Dictionary = Career.DIFFICULTY[career.difficulty]
	for tid in career.teams:
		var t: Team = career.teams[tid]
		if t.is_player:
			continue
		_maintain(career, t)
		_develop(career, t, float(diff["ai_dev"]))


static func _maintain(career: Career, t: Team) -> void:
	for cid in t.car.components:
		var c: CarComponent = t.car.components[cid]
		if c.wear > 0.45 and t.finance.balance > 6000000:
			career.maintain_component(t, cid)


static func _develop(career: Career, t: Team, dev_mult: float) -> void:
	# keep a reserve covering ~4 races of running costs
	var reserve := 7000000
	var spend_budget := int((t.finance.balance - reserve) * 0.35 * dev_mult)
	if spend_budget <= 0:
		return
	var order: Array = PRIORITY.get(t.philosophy, PRIORITY["balanced"]).duplicate()
	# fix weak reliability first
	for cid in t.car.components:
		var c: CarComponent = t.car.components[cid]
		if c.reliability < 70.0 and spend_budget > career.reliability_cost(t, cid):
			var cost := career.reliability_cost(t, cid)
			if career.improve_reliability(t, cid):
				spend_budget -= cost
	# pick upgrades with the best gain-per-cost from the priority list, plus the weakest part
	var weakest := ""
	var weakest_perf := INF
	for cid in t.car.components:
		if t.car.components[cid].performance < weakest_perf:
			weakest_perf = t.car.components[cid].performance
			weakest = cid
	order.push_front(weakest)
	var guard := 0
	while spend_budget > 0 and guard < 6:
		guard += 1
		var best_cid := ""
		var best_score := 0.0
		for cid in order:
			var cost := career.upgrade_cost(t, cid)
			if cost > spend_budget:
				continue
			var score := career.upgrade_gain(t, cid) / float(cost) * (1.0 + career.rng.randf() * 0.3)
			if score > best_score:
				best_score = score
				best_cid = cid
		if best_cid == "":
			break
		var c2 := career.upgrade_cost(t, best_cid)
		if career.upgrade_component(t, best_cid):
			spend_budget -= c2
		else:
			break
