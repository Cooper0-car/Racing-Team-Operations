class_name RaceCar
extends RefCounted
## Runtime state of one car during a race session.

enum Mode { CONSERVE, NORMAL, PUSH }
const MODE_NAMES := ["Conserve", "Standard", "Push"]

var idx: int = 0
var driver: Driver
var team: Team
var color: Color
var label: String = ""

var params: Dictionary = {}
var profile: PackedFloat32Array = PackedFloat32Array()   # max speed per sample (car+driver, fresh tyres)
var base_mult: float = 1.0          # driver pace factor
var potential_lap: float = 0.0      # theoretical clean lap time
var tu_mult: float = 1.0            # tyre wear multiplier from car tire_usage

# dynamic state
var progress: float = 0.0           # total metres travelled (negative on the grid)
var speed: float = 0.0
var lateral: float = 0.0
var lateral_target: float = 0.0
var mode: int = Mode.NORMAL
var tire_wear: float = 0.0          # 0..1
var damage_mult: float = 1.0        # permanent loss from damage/failures this race
var lap_variation: float = 0.0      # per-lap consistency noise
var incident_time: float = 0.0      # seconds left in current incident
var incident_factor: float = 1.0    # speed factor during incident
var start_delay: float = 0.0
var pass_timer: float = 0.0         # while > 0, car is alongside / passing (ignores blocking)
var pass_target: RaceCar = null
var blocked: bool = false
var attempted_zone: int = -1        # overtake zone index already attempted this lap
var drs_zone: int = -1              # DRS zone currently open for this car
var drs_checked: int = -1           # last detection point evaluated
var drs_boost: float = 0.0          # seconds of DRS-assisted overtaking chance left
var last_corner_checked: int = -1
var grid_pos: int = 0
var position: int = 0

# results
var laps_done: int = 0
var finished: bool = false
var finish_time: float = 0.0
var dnf: bool = false
var dnf_reason: String = ""         # untranslated key, may contain %s
var dnf_arg: String = ""
var lap_start_time: float = 0.0
var lap_times: Array = []
var best_lap: float = INF
var sector_start: float = 0.0
var cur_sector: int = 0
var cur_sectors: Array = [0.0, 0.0, 0.0]
var last_sectors: Array = [0.0, 0.0, 0.0]
var best_sectors: Array = [INF, INF, INF]
var positions_by_lap: Array = []
var tire_by_lap: Array = []
var overtakes: int = 0
var times_overtaken: int = 0
var mistakes: int = 0
var incidents: Array = []           # strings
var cp_times: Dictionary = {}       # checkpoint index -> time
var radio_flags: Dictionary = {}


func is_running() -> bool:
	return not finished and not dnf


func current_lap() -> int:
	return laps_done + 1


func tire_factor() -> float:
	var f := 1.0 - 0.03 * tire_wear
	if tire_wear > 0.8:
		f -= (tire_wear - 0.8) * 0.25
	return f


func mode_factor() -> float:
	match mode:
		Mode.CONSERVE: return 0.985
		Mode.PUSH: return 1.006
	return 1.0


func mode_wear() -> float:
	match mode:
		Mode.CONSERVE: return 0.65
		Mode.PUSH: return 1.5
	return 1.0


func mode_risk() -> float:
	match mode:
		Mode.CONSERVE: return 0.5
		Mode.PUSH: return 1.8
	return 1.0


func dnf_text() -> String:
	return tr(dnf_reason) % tr(dnf_arg) if dnf_arg != "" else tr(dnf_reason)


func incident_texts() -> Array:
	var out := []
	for inc in incidents:
		var args := []
		for a in inc[1]:
			args.append(tr(a) if a is String else a)
		out.append(tr(inc[0]) % args if args.size() > 0 else tr(inc[0]))
	return out


func total_time() -> float:
	return finish_time


## Slow the car to `factor` of normal speed for `duration` seconds.
func _start_incident(duration: float, factor: float) -> void:
	if incident_time > 0.0:
		incident_factor = minf(incident_factor, factor)
		incident_time = maxf(incident_time, duration)
	else:
		incident_factor = factor
		incident_time = duration
