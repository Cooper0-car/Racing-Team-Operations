extends Node
## Career saves (JSON) in user://saves/. Slots: "autosave", "slot1".."slot5".

const SAVE_DIR := "user://saves/"
const SLOTS := ["autosave", "slot1", "slot2", "slot3", "slot4", "slot5"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func save_career(career: Career, slot: String) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := career.to_dict()
	var team := career.player_team()
	data["meta"] = {
		"slot": slot, "team_name": team.name, "season": career.season, "round": career.round_idx,
		"balance": team.finance.balance, "saved_at": Time.get_datetime_string_from_system(false, true),
		"unix": Time.get_unix_time_from_system(),
	}
	var tmp := SAVE_DIR + slot + ".json.tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write save " + tmp)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	# write-then-rename so a crash never leaves a half-written save
	var final_path := SAVE_DIR + slot + ".json"
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	return DirAccess.rename_absolute(tmp, final_path) == OK


func load_career(slot: String) -> Career:
	var path := SAVE_DIR + slot + ".json"
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Corrupt save: " + path)
		return null
	return Career.from_dict(parsed)


func slot_info(slot: String) -> Dictionary:
	var path := SAVE_DIR + slot + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"slot": slot, "corrupt": true}
	return parsed.get("meta", {"slot": slot})


func delete_slot(slot: String) -> void:
	var path := SAVE_DIR + slot + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Most recently written save slot, or "" if none.
func latest_slot() -> String:
	var best := ""
	var best_t := -1.0
	for s in SLOTS:
		var info := slot_info(s)
		if info.is_empty() or info.get("corrupt", false):
			continue
		var t := float(info.get("unix", 0))
		if t > best_t:
			best_t = t
			best = s
	return best
