extends SceneTree
## UI snapshot tool. Renders the main menu and an in-game board at several
## resolutions (desktop + phone landscape) into tools/out/ for visual review.
##
## Usage (needs a GPU window, NOT --headless):
##   godot --path . --script res://tools/snapshot.gd

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1440, 900),   # desktop 16:10 (design size)
	Vector2i(1920, 1080),  # desktop 16:9
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
			{"name": "墨匠乙", "is_ai": true, "ai_level": 1},
			{"name": "瓷师丙", "is_ai": true, "ai_level": 1},
		], 15)
		await _settle()
		_save(out_dir.path_join("board_%s.png" % tag))

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
