extends Node
## Persistent user settings (user://settings.cfg).

const PATH := "user://settings.cfg"
const SECTION := "settings"

const DEFAULTS: Dictionary = {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"sfx_enabled": true,
	"fullscreen": false,
	"anim_speed": 1.0,      # 0 = off, 1 = normal, 2 = fast
	"ai_delay": 0.55,       # seconds between AI steps
	"language": "zh_CN",
	"colorblind": false,
	"ui_scale": 1.0,
}

var _values: Dictionary = {}

func _ready() -> void:
	load_settings()
	_apply_all()

func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))

func set_value(key: String, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key)
	save_settings()
	EventBus.setting_changed.emit(key, value)

func load_settings() -> void:
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in DEFAULTS.keys():
		if cfg.has_section_key(SECTION, k):
			_values[k] = cfg.get_value(SECTION, k)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in _values.keys():
		cfg.set_value(SECTION, k, _values[k])
	cfg.save(PATH)

func _apply_all() -> void:
	for k in _values.keys():
		_apply(k)

func _apply(key: String) -> void:
	match key:
		"sfx_enabled":
			SfxManager.muted = not bool(_values[key])
		"fullscreen":
			if DisplayServer.get_name() == "headless" or OS.has_feature("mobile") or OS.has_feature("web"):
				return
			var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(_values[key]) else DisplayServer.WINDOW_MODE_WINDOWED
			DisplayServer.window_set_mode(mode)
		"language":
			TranslationServer.set_locale(str(_values[key]))
