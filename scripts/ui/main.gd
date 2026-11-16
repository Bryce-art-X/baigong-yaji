extends Control

var _menu: MainMenu
var _board: BoardView
var _codex: CodexModal
var _settings: SettingsModal
var _last_configs: Array = []
var _last_target: int = 15
var _last_tutorial: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BgmManager.ensure_running(self)

	_menu = MainMenu.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.start_game_requested.connect(_on_start_game)
	_menu.continue_game_requested.connect(_on_continue_game)
	_menu.tutorial_requested.connect(_on_start_tutorial)
	_menu.codex_requested.connect(func() -> void: _codex.open_codex())
	_menu.settings_requested.connect(func() -> void: _settings.visible = true)
	add_child(_menu)

	_board = BoardView.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.visible = false
	_board.return_to_menu_requested.connect(_on_return_to_menu)
	_board.restart_requested.connect(_on_restart)
	_board.settings_requested.connect(func() -> void: _settings.visible = true)
	add_child(_board)

	_codex = CodexModal.new()
	add_child(_codex)

	_settings = SettingsModal.new()
	add_child(_settings)

func _on_start_game(player_configs: Array, target_prestige: int) -> void:
	_last_configs = player_configs
	_last_target = target_prestige
	_last_tutorial = false
	var state := RulesEngine.create_game(player_configs, target_prestige)
	_menu.visible = false
	_board.visible = true
	_board.start_game(state, false)

func _on_start_tutorial() -> void:
	var cfgs := [
		{"name": "初学雅士", "is_ai": false, "ai_level": 0},
		{"name": "书童小墨", "is_ai": true, "ai_level": 0, "ai_persona": "balanced"},
	]
	_last_configs = cfgs
	_last_target = 6
	_last_tutorial = true
	var state := RulesEngine.create_game(cfgs, 6, 202601)
	_menu.visible = false
	_board.visible = true
	_board.start_game(state, true)

func _on_continue_game() -> void:
	var saved := SaveManager.load_autosave()
	if saved != null:
		_menu.visible = false
		_board.visible = true
		_board.start_game(saved, false)

func _on_restart() -> void:
	if _last_tutorial:
		_on_start_tutorial()
	elif not _last_configs.is_empty():
		_on_start_game(_last_configs, _last_target)

func _on_return_to_menu() -> void:
	_board.visible = false
	_menu.visible = true
	_menu.refresh_meta()
