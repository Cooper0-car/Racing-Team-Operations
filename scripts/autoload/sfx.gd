extends Node
## Small procedural sound effects (no audio files needed): UI clicks, start lights, chequered flag.
## Everything plays on the "SFX" bus, whose volume is controlled in Settings.

var _streams := {}
var _players: Array = []
var _next := 0


func _ready() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
	_streams["click"] = _tone([[1400.0, 0.025]], 0.25)
	_streams["light"] = _tone([[660.0, 0.16]], 0.35)
	_streams["go"] = _tone([[990.0, 0.45]], 0.4)
	_streams["flag"] = _tone([[784.0, 0.12], [988.0, 0.12], [1175.0, 0.3]], 0.35)
	_streams["alert"] = _tone([[440.0, 0.1], [330.0, 0.18]], 0.35)
	_streams["success"] = _tone([[660.0, 0.08], [880.0, 0.16]], 0.3)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	Game.apply_settings()


func play(name: String) -> void:
	if not _streams.has(name):
		return
	if name == "click" and not Game.settings.get("ui_sounds", true):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.play()


## notes: [[frequency_hz, seconds], ...] played back to back with a short fade per note.
static func _tone(notes: Array, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	for n in notes:
		var freq: float = n[0]
		var count := int(rate * float(n[1]))
		for i in count:
			var t := float(i) / rate
			var env := minf(1.0, float(i) / (rate * 0.004)) * minf(1.0, float(count - i) / (rate * 0.03))
			var s := sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.2
			var v := int(clampf(s * env * volume, -1.0, 1.0) * 32767.0)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
