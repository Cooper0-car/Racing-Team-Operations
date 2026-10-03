"""Generates data/drivers.json and data/teams.json. Re-run to regenerate; or edit JSON directly."""
import json, random
random.seed(7)
FIRST = ["Lucas","Marco","Kenji","Oliver","Mateo","Felix","Arjun","Theo","Nico","Liam","Rafael","Hugo","Emil","Daniel","Yuki","Sebastian","Jonas","Pierre","Andrea","Victor","Max","Leo","Tomas","Ivan","Kai","Ryo","Samuel","Diego","Elias","Finn","Adrian","Jae-won","Luca","Noah","Henrik","Bruno"]
LAST = ["Moreau","Bianchi","Tanaka","Hartley","Silva","Kraus","Mehta","Laurent","Rossi","Walker","Duarte","Fischer","Lindqvist","Novak","Sato","Varga","Keller","Dubois","Conti","Petrov","Okafor","Jensen","Ferreira","Castillo","Nakamura","Brennan","Kim","Ortega","Vos","Haas","Lambert","Park","Esposito","Reyes","Strand","Marsh"]
NAT = ["GBR","ITA","JPN","GBR","ARG","GER","IND","FRA","ITA","AUS","BRA","FRA","SWE","CZE","JPN","HUN","SUI","FRA","ITA","RUS","NGR","DEN","POR","MEX","JPN","IRL","KOR","ESP","NED","AUT","BEL","KOR","ITA","USA","NOR","NZL"]
PERS = ["Aggressive","Conservative","Technical","Consistent","Unpredictable","Tire Saver","Wet Specialist","Qualifying Specialist","Race Specialist"]
ATTRS = ["raw_pace","qualifying_pace","race_pace","consistency","racecraft","overtaking","defending","braking","wet_skill","tire_management","fuel_management","starts","aggression","risk_taking","feedback","adaptability","concentration","fitness","experience","potential","marketability","reputation"]
PERS_MOD = {
 "Aggressive": {"aggression": 15, "risk_taking": 12, "overtaking": 6, "consistency": -6, "tire_management": -4},
 "Conservative": {"aggression": -12, "risk_taking": -12, "consistency": 6, "overtaking": -5},
 "Technical": {"feedback": 15, "adaptability": 6},
 "Consistent": {"consistency": 12, "concentration": 8},
 "Unpredictable": {"consistency": -12, "raw_pace": 3, "risk_taking": 10},
 "Tire Saver": {"tire_management": 14, "fuel_management": 6},
 "Wet Specialist": {"wet_skill": 18},
 "Qualifying Specialist": {"qualifying_pace": 8, "race_pace": -2},
 "Race Specialist": {"race_pace": 4, "racecraft": 8, "qualifying_pace": -3},
}
def clamp(v): return max(20, min(99, int(round(v))))
def make(i, base, age):
    d = {"id": f"drv_{i:03d}", "first_name": FIRST[i % len(FIRST)], "last_name": LAST[i % len(LAST)], "nationality": NAT[i % len(NAT)], "age": age}
    pers = random.choice(PERS)
    traits = [pers]
    if age <= 21: traits.append("Rookie")
    if age >= 33: traits.append("Veteran")
    d["traits"] = traits
    a = {}
    pace = base + random.uniform(-4, 4)
    a["raw_pace"] = pace
    a["qualifying_pace"] = pace + random.uniform(-4, 4)
    a["race_pace"] = pace + random.uniform(-4, 4)
    for k in ATTRS:
        if k not in a: a[k] = base - 6 + random.uniform(-12, 12)
    exp_years = max(0, age - 18)
    a["experience"] = 25 + exp_years * 5 + random.uniform(-5, 5)
    a["potential"] = (95 - (age - 18) * 2.5) + random.uniform(-10, 8) if age < 28 else a["raw_pace"]
    a["fitness"] = 90 - max(0, age - 30) * 2 + random.uniform(-6, 4)
    a["reputation"] = base - 12 + exp_years * 1.5 + random.uniform(-6, 6)
    for k, v in PERS_MOD[pers].items(): a[k] += v
    if age <= 21:
        a["consistency"] -= 6; a["experience"] = min(a["experience"], 35)
    d["attributes"] = {k: clamp(v) for k, v in a.items()}
    ovr = (d["attributes"]["race_pace"] * 2 + d["attributes"]["qualifying_pace"] + d["attributes"]["consistency"] + d["attributes"]["racecraft"]) / 5
    d["salary"] = int(max(250000, (ovr - 50) ** 2 * 9000 + d["attributes"]["reputation"] * 10000) // 10000 * 10000)
    d["morale"] = 70
    return d

drivers = []
bases = [90, 87, 85, 84, 82, 81, 80, 79, 78, 77, 76, 76, 75, 74, 73, 72, 71, 70]
for i, b in enumerate(bases):
    drivers.append(make(i, b, random.randint(20, 36)))
# free agents and young prospects
for j, (b, age) in enumerate([(78, 31), (74, 24), (72, 19), (70, 20), (76, 34), (69, 18), (73, 22), (71, 27), (67, 19), (75, 29), (68, 21), (73, 33)]):
    drivers.append(make(len(bases) + j, b, age))

teams = [
 {"id": "team_valkyr",  "name": "Valkyr Racing",      "abbr": "VAL", "primary": "#c8102e", "secondary": "#f2c94c", "budget": 95000000, "perf": 72, "rel": 82, "philosophy": "balanced",       "reputation": 85},
 {"id": "team_aurora",  "name": "Aurora Motorsport",  "abbr": "AUR", "primary": "#1f6feb", "secondary": "#e6edf3", "budget": 88000000, "perf": 71, "rel": 84, "philosophy": "reliability",    "reputation": 80},
 {"id": "team_kestrel", "name": "Kestrel GP",         "abbr": "KES", "primary": "#f57c00", "secondary": "#1b1b1b", "budget": 70000000, "perf": 68, "rel": 79, "philosophy": "aggressive_dev", "reputation": 70},
 {"id": "team_nordlys", "name": "Nordlys Engineering","abbr": "NOR", "primary": "#2e7d32", "secondary": "#c5e1a5", "budget": 60000000, "perf": 66, "rel": 83, "philosophy": "race",           "reputation": 62},
 {"id": "team_solaris", "name": "Solaris Team",       "abbr": "SOL", "primary": "#fbc02d", "secondary": "#3e2723", "budget": 52000000, "perf": 64, "rel": 78, "philosophy": "qualifying",     "reputation": 55},
 {"id": "team_ironclad","name": "Ironclad Racing",    "abbr": "IRC", "primary": "#78909c", "secondary": "#263238", "budget": 45000000, "perf": 62, "rel": 81, "philosophy": "reliability",    "reputation": 50},
 {"id": "team_vortex",  "name": "Vortex Speed",       "abbr": "VTX", "primary": "#8e24aa", "secondary": "#f3e5f5", "budget": 40000000, "perf": 61, "rel": 76, "philosophy": "aggressive_dev", "reputation": 45},
 {"id": "team_corsa",   "name": "Scuderia Corsa",     "abbr": "COR", "primary": "#00838f", "secondary": "#ffffff", "budget": 34000000, "perf": 59, "rel": 77, "philosophy": "balanced",       "reputation": 40},
 {"id": "team_redline", "name": "Redline Privateers", "abbr": "RDL", "primary": "#e91e63", "secondary": "#212121", "budget": 28000000, "perf": 57, "rel": 74, "philosophy": "race",           "reputation": 32},
]
for t_i, t in enumerate(teams):
    t["drivers"] = [drivers[t_i * 2]["id"], drivers[t_i * 2 + 1]["id"]]
json.dump({"_doc": "Driver database. Attributes 20-99. salary = per season.", "drivers": drivers}, open("data/drivers.json", "w"), indent=1)
json.dump({"_doc": "AI teams. perf/rel = starting component ratings.", "teams": teams}, open("data/teams.json", "w"), indent=1)
print(len(drivers), "drivers", len(teams), "teams")
