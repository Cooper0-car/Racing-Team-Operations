extends Node
## Read-only static game data loaded from res://data/*.json.
## Custom (player-made) tracks live in user://tracks and are merged into the track list.

const DATA_DIR := "res://data/"
const USER_TRACK_DIR := "user://tracks/"

var balance: Dictionary = {}
var components: Array = []           # Array of component definition dicts
var component_by_id: Dictionary = {}
var dimensions: Array = []
var drivers: Array = []              # template drivers (copied into a career)
var teams: Array = []                # template AI teams
var championships: Array = []
var tracks: Dictionary = {}          # id -> raw track dict


func _ready() -> void:
	reload()


func reload() -> void:
	balance = _load_json(DATA_DIR + "balance.json")
	var comp: Dictionary = _load_json(DATA_DIR + "components.json")
	components = comp.get("components", [])
	dimensions = comp.get("dimensions", [])
	component_by_id.clear()
	for c in components:
		component_by_id[c["id"]] = c
	drivers = _load_json(DATA_DIR + "drivers.json").get("drivers", [])
	teams = _load_json(DATA_DIR + "teams.json").get("teams", [])
	championships = _load_json(DATA_DIR + "championships.json").get("championships", [])
	reload_tracks()


func reload_tracks() -> void:
	tracks.clear()
	for dir_path in [DATA_DIR + "tracks/", USER_TRACK_DIR]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".json"):
				var t: Dictionary = _load_json(dir_path + f)
				if t.has("id") and t.has("points"):
					t["builtin"] = dir_path.begins_with("res://")
					tracks[t["id"]] = t


func get_track(id: String) -> Dictionary:
	return tracks.get(id, {})


func get_championship(id: String) -> Dictionary:
	for c in championships:
		if c["id"] == id:
			return c
	return {}


func find_in(list: Array, id: String) -> Dictionary:
	for e in list:
		if e.get("id", "") == id:
			return e
	return {}


func philosophy(id: String) -> Dictionary:
	return find_in(balance.get("philosophies", []), id)


static func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DataDB: cannot open " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DataDB: invalid JSON in " + path)
		return {}
	return parsed
