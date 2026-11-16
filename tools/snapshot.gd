extends SceneTree
## UI snapshot tool. Renders main menu, fresh board, and active mid-game board
## (with purchased stacks, reserved card, held chips, and selected card action bar)
## at desktop + phone landscape resolutions into tools/out/.

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1440, 900),   # desktop 16:10 (design size)
	Vector2i(1280, 720),   # minimum desktop
	Vector2i(2400, 1080),  # phone landscape 20:9
]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var out_dir := ProjectSettings.globalize_path("res://tools/out")
	DirAccess.make_dir_recursive_absolute(out_dir)

	for res in RESOLUTIONS:
		DisplayServer.window_set_size(res)
		root.size = res
		var tag := "%dx%d" % [res.x, res.y]

		var main_node: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main_node)
		await _settle()
		_save(out_dir.path_join("menu_%s.png" % tag))

		main_node._on_start_game([
			{"name": "雅士甲", "is_ai": false, "ai_level": 1},
			{"name": "墨匠乙", "is_ai": true, "ai_level": 1, "ai_persona": "artisan"},
			{"name": "宗师丙", "is_ai": true, "ai_level": 2, "ai_persona": "scholar"},
		], 15)
		await _settle()
		_save(out_dir.path_join("board_%s.png" % tag))

		if res.x == 1440:
			var board: Node = main_node._board
			var p0 = board.state.players[0]
			p0.chips = {"jade": 2, "porcelain": 3, "bamboo": 1, "cinnabar": 0, "ink": 1, "gold": 1}
			p0.discounts = {"jade": 1, "porcelain": 2, "bamboo": 1, "cinnabar": 0, "ink": 1}
			for g in ["jade", "porcelain", "bamboo", "cinnabar", "ink"]:
				var c := CardData.CraftCard.new("sim_" + g, "试样", 1, g, 1 if g == "porcelain" else 0, {})
				p0.purchased.append(c)
			p0.purchased.append(CardData.CraftCard.new("sim_p2", "官窑", 2, "porcelain", 2, {}))
			p0.reserved.append(board.state.board[2][0])
			board._on_board_card_tapped(board._card_slots[1][0])
			await create_timer(0.28).timeout
			await _settle()
			_save(out_dir.path_join("midgame_%s.png" % tag))

		main_node.queue_free()
		await process_frame

	print("Snapshots written to ", out_dir)
	quit(0)

func _settle() -> void:
	for i in range(4):
		await process_frame

func _save(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("  saved ", path.get_file(), " ", img.get_size())
