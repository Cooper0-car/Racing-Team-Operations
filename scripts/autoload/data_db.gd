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


## Saves a player-made track to user://tracks/<id>.json and refreshes the track list.
func save_user_track(d: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(USER_TRACK_DIR)
	var data := d.duplicate(true)
	data.erase("builtin")
	var f := FileAccess.open(USER_TRACK_DIR + str(data["id"]) + ".json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, " "))
	f.close()
	reload_tracks()
	return true


func delete_user_track(id: String) -> void:
	var path := USER_TRACK_DIR + id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	reload_tracks()


func is_builtin_track(id: String) -> bool:
	return bool(tracks.get(id, {}).get("builtin", false))


## Unique id for a new custom track.
func new_track_id(name: String) -> String:
	var slug := ""
	for ch in name.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			slug += ch
		elif slug != "" and not slug.ends_with("_"):
			slug += "_"
	slug = slug.trim_suffix("_").substr(0, 24)
	if slug == "":
		slug = "track"
	var id := "custom_" + slug
	var n := 2
	while tracks.has(id):
		id = "custom_%s_%d" % [slug, n]
		n += 1
	return id


## Track ids sorted: built-in first, then custom, each alphabetically by name.
func sorted_track_ids() -> Array:
	var ids := tracks.keys()
	ids.sort_custom(func(a, b):
		var ba: bool = tracks[a].get("builtin", false)
		var bb: bool = tracks[b].get("builtin", false)
		if ba != bb:
			return ba
		return str(tracks[a].get("name", a)) < str(tracks[b].get("name", b)))
	return ids


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
