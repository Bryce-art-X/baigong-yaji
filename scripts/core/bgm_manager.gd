class_name BgmManager
extends Node
## Gentle procedural Chinese pentatonic ambient loop (guzheng/chime timbre)
## routed to the "Music" audio bus. Zero external audio files required.

const SCALE: Array[float] = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25]
const PHRASE: Array[int] = [0, 2, 4, 5, 4, 2, 1, 3, 4, 2, 0, -1, 2, 4, 7, 5]

static var _instance: BgmManager = null
var _timer: Timer
var _step: int = 0

static func ensure_running(parent: Node) -> void:
	if _instance != null and is_instance_valid(_instance):
		return
	if DisplayServer.get_name() == "headless":
		return
	_instance = BgmManager.new()
	_instance.name = "BgmManager"
	parent.add_child(_instance)

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.15
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

func _on_tick() -> void:
	if SfxManager.muted or float(Settings.get_value("music_volume")) <= 0.01:
		return
	var note_idx: int = PHRASE[_step % PHRASE.size()]
	_step += 1
	if note_idx < 0:
		return
	_play_ambient_note(SCALE[note_idx], 1.4, 0.09)

func _play_ambient_note(freq: float, dur: float, vol: float) -> void:
	var player := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = dur + 0.05
	player.stream = gen
	player.bus = &"Music" if AudioServer.get_bus_index(&"Music") >= 0 else &"Master"
	player.volume_db = linear_to_db(clampf(vol, 0.01, 1.0))
	add_child(player)
	player.play()

	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb != null:
		var frames: int = int(gen.mix_rate * dur)
		var phase: float = 0.0
		var inc: float = freq / gen.mix_rate
		for n in range(frames):
			var attack: float = minf(1.0, float(n) / 400.0)
			var decay: float = pow(1.0 - float(n) / float(frames), 2.2)
			var sample: float = (sin(phase * TAU) * 0.72 + sin(phase * 2.0 * TAU) * 0.22 + sin(phase * 3.0 * TAU) * 0.06) * attack * decay
			pb.push_frame(Vector2(sample, sample))
			phase = fmod(phase + inc, 1.0)

	get_tree().create_timer(dur + 0.1).timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)
