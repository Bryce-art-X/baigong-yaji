class_name SfxManager
extends Node

# Pentatonic scale frequencies (C5, D5, E5, G5, A5, C6, D6, E6)
const PENTA: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.50, 1174.66, 1318.51]

static var muted: bool = false
static var _host: Node = null

static func ensure_host(tree_parent: Node) -> void:
	if _host == null or not is_instance_valid(_host):
		_host = Node.new()
		_host.name = "SfxHost"
		tree_parent.add_child(_host)

static func play_click() -> void:
	_play_notes([392.0], 0.045, 0.14, 0.0)

static func play_take_chip(count: int = 1) -> void:
	var idx := clampi(count - 1, 0, PENTA.size() - 1)
	_play_notes([PENTA[idx]], 0.09, 0.18, 0.0)

static func play_reserve() -> void:
	_play_notes([PENTA[2], PENTA[4]], 0.11, 0.16, 0.05)

static func play_buy(prestige: int = 0) -> void:
	if prestige >= 3:
		_play_notes([PENTA[0], PENTA[2], PENTA[4], PENTA[5]], 0.18, 0.18, 0.055)
	else:
		_play_notes([PENTA[0], PENTA[2], PENTA[4]], 0.14, 0.17, 0.05)

static func play_master() -> void:
	_play_notes([PENTA[1], PENTA[3], PENTA[5], PENTA[7]], 0.22, 0.20, 0.065)

static func play_victory() -> void:
	_play_notes([PENTA[0], PENTA[2], PENTA[4], PENTA[5], PENTA[7]], 0.28, 0.20, 0.08)

static func _play_notes(freqs: Array[float], dur: float, vol: float, stagger: float) -> void:
	if muted or _host == null or not is_instance_valid(_host):
		return
	for i in range(freqs.size()):
		var f: float = freqs[i]
		var delay: float = float(i) * stagger
		if delay > 0.0:
			var t := _host.get_tree().create_timer(delay)
			t.timeout.connect(func() -> void: _spawn_tone(f, dur, vol))
		else:
			_spawn_tone(f, dur, vol)

static func _spawn_tone(freq: float, dur: float, vol: float) -> void:
	if muted or _host == null or not is_instance_valid(_host):
		return
	var player := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = dur + 0.05
	player.stream = gen
	player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	player.volume_db = linear_to_db(clampf(vol, 0.01, 1.0))
	_host.add_child(player)
	player.play()

	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb != null:
		var frames: int = int(gen.mix_rate * dur)
		var phase: float = 0.0
		var inc: float = freq / gen.mix_rate
		for n in range(frames):
			var env: float = pow(1.0 - float(n) / float(frames), 1.8)
			# Soft plucked string / bell timbre (fundamental + gentle 2nd harmonic)
			var sample: float = (sin(phase * TAU) * 0.8 + sin(phase * 2.0 * TAU) * 0.2) * env
			pb.push_frame(Vector2(sample, sample))
			phase = fmod(phase + inc, 1.0)

	var cleanup := _host.get_tree().create_timer(dur + 0.12)
	cleanup.timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)
