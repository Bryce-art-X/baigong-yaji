extends Control

var _menu: MainMenu
var _board: BoardView
var _last_configs: Array = []
var _last_target: int = 15

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_menu = MainMenu.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.start_game_requested.connect(_on_start_game)
	_menu.continue_game_requested.connect(_on_continue_game)
	add_child(_menu)

	_board = BoardView.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.visible = false
	_board.return_to_menu_requested.connect(_on_return_to_menu)
	_board.restart_requested.connect(_on_restart)
	add_child(_board)

func _on_start_game(player_configs: Array, target_prestige: int) -> void:
	_last_configs = player_configs
	_last_target = target_prestige
	var state := RulesEngine.create_game(player_configs, target_prestige)
	_menu.visible = false
	_board.visible = true
	_board.start_game(state)

func _on_continue_game() -> void:
	var saved := SaveManager.load_autosave()
	if saved != null:
		_menu.visible = false
		_board.visible = true
		_board.start_game(saved)

func _on_restart() -> void:
	if not _last_configs.is_empty():
		_on_start_game(_last_configs, _last_target)

func _on_return_to_menu() -> void:
	_board.visible = false
	_menu.visible = true
	_menu.refresh_meta()
