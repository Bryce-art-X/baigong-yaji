class_name MainMenu
extends Control

signal start_game_requested(player_configs: Array, target_prestige: int)
signal continue_game_requested

var _player_count: int = 3
var _target_prestige: int = 15
var _seat_modes: Array[int] = [0, 2, 2, 1] # 0=真人, 1=书童AI, 2=匠师AI
var _seat_names: Array[String] = ["雅士甲", "墨匠乙", "瓷师丙", "玉匠丁"]

var _seats_box: VBoxContainer
var _count_btns: Array[Button] = []
var _target_btns: Array[Button] = []
var _continue_btn: Button
var _stats_lbl: Label

func _ready() -> void:
	_build_ui()
	_refresh_seats()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG_DARK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 480)
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.PANEL_BG, UITheme.GOLD_ACCENT, 14, 2))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "百 工 雅 集"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "采玉琢瓷 · 聚匠成器 · 邀名士共赴雅集"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(subtitle)

	var icon_strip := HBoxContainer.new()
	icon_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_strip.add_theme_constant_override("separation", 14)
	vbox.add_child(icon_strip)
	for g in GemTypes.ALL_GEMS:
		var tr := TextureRect.new()
		tr.texture = UITheme.gem_icon(g)
		tr.custom_minimum_size = Vector2(32, 32)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_strip.add_child(tr)

	# Player count
	var count_row := HBoxContainer.new()
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	count_row.add_theme_constant_override("separation", 10)
	vbox.add_child(count_row)

	var c_lbl := Label.new()
	c_lbl.text = "对局人数："
	c_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	count_row.add_child(c_lbl)

	for n in [2, 3, 4]:
		var b := Button.new()
		b.text = "%d 人局" % n
		b.pressed.connect(func() -> void:
			_player_count = n
			_refresh_option_buttons()
			_refresh_seats()
		)
		_count_btns.append(b)
		count_row.add_child(b)

	# Target prestige
	var target_row := HBoxContainer.new()
	target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	target_row.add_theme_constant_override("separation", 10)
	vbox.add_child(target_row)

	var t_lbl := Label.new()
	t_lbl.text = "胜负目标："
	t_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	target_row.add_child(t_lbl)

	for pts in [12, 15]:
		var b := Button.new()
		b.text = "%d 声望%s" % [pts, "（快局）" if pts == 12 else "（标准）"]
		b.pressed.connect(func() -> void:
			_target_prestige = pts
			_refresh_option_buttons()
		)
		_target_btns.append(b)
		target_row.add_child(b)

	_refresh_option_buttons()

	# Seats config
	var seats_panel := PanelContainer.new()
	seats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seats_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("1E1714"), UITheme.GOLD_DIM, 8, 1))
	vbox.add_child(seats_panel)

	_seats_box = VBoxContainer.new()
	_seats_box.add_theme_constant_override("separation", 8)
	seats_panel.add_child(_seats_box)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var start_btn := Button.new()
	start_btn.text = "开启新局"
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.custom_minimum_size = Vector2(0, 44)
	start_btn.add_theme_font_size_override("font_size", 18)
	UITheme.style_button(start_btn, Color("295439"), UITheme.AFFORD_GREEN)
	start_btn.pressed.connect(_on_start_pressed)
	btn_row.add_child(start_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "继续上次雅集"
	_continue_btn.custom_minimum_size = Vector2(160, 44)
	_continue_btn.add_theme_font_size_override("font_size", 16)
	UITheme.style_button(_continue_btn, Color("473522"), UITheme.GOLD_ACCENT)
	_continue_btn.pressed.connect(func() -> void: continue_game_requested.emit())
	btn_row.add_child(_continue_btn)

	_stats_lbl = Label.new()
	_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_lbl.add_theme_font_size_override("font_size", 12)
	_stats_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(_stats_lbl)

	refresh_meta()

func refresh_meta() -> void:
	if _continue_btn != null:
		_continue_btn.visible = SaveManager.has_autosave()
	if _stats_lbl != null:
		var st := SaveManager.load_stats()
		var gp := int(st["games_played"])
		var wins := int(st["wins"])
		var best := int(st["best_score"])
		var fast := int(st["fastest_win_round"])
		if gp == 0:
			_stats_lbl.text = "雅集战绩：尚无完赛记录"
		else:
			var fast_s := "%d 轮" % fast if fast > 0 else "-"
			_stats_lbl.text = "雅集战绩：%d 局 · %d 胜 · 最高 %d 声望 · 最快胜局 %s" % [gp, wins, best, fast_s]

func _refresh_option_buttons() -> void:
	var counts: Array[int] = [2, 3, 4]
	for i in range(_count_btns.size()):
		var active: bool = counts[i] == _player_count
		UITheme.style_button(_count_btns[i], Color("4F3B22") if active else Color("2A211C"), UITheme.GOLD_ACCENT if active else UITheme.GOLD_DIM)
	var targets: Array[int] = [12, 15]
	for i in range(_target_btns.size()):
		var active: bool = targets[i] == _target_prestige
		UITheme.style_button(_target_btns[i], Color("4F3B22") if active else Color("2A211C"), UITheme.GOLD_ACCENT if active else UITheme.GOLD_DIM)

func _refresh_seats() -> void:
	for c in _seats_box.get_children():
		c.queue_free()

	var mode_labels := ["真人操作", "书童 AI（易）", "匠师 AI（中）", "宗师 AI（难）"]
	var personas := ["balanced", "artisan", "scholar", "interceptor"]
	for i in range(_player_count):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_seats_box.add_child(row)

		var name_edit := LineEdit.new()
		name_edit.text = _seat_names[i]
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.text_changed.connect(func(new_text: String) -> void:
			_seat_names[i] = new_text
		)
		row.add_child(name_edit)

		var mode_btn := Button.new()
		mode_btn.custom_minimum_size = Vector2(156, 0)
		mode_btn.text = mode_labels[_seat_modes[i]]
		UITheme.style_button(mode_btn, Color("2E241E") if _seat_modes[i] == 0 else Color("3B2D22"))
		mode_btn.pressed.connect(func() -> void:
			_seat_modes[i] = (_seat_modes[i] + 1) % 4
			_refresh_seats()
		)
		row.add_child(mode_btn)

func _on_start_pressed() -> void:
	var personas := ["balanced", "artisan", "scholar", "interceptor"]
	var configs: Array = []
	for i in range(_player_count):
		var m := _seat_modes[i]
		configs.append({
			"name": _seat_names[i].strip_edges() if not _seat_names[i].strip_edges().is_empty() else "匠师 %d" % (i + 1),
			"is_ai": m > 0,
			"ai_level": maxi(0, m - 1),
			"ai_persona": personas[i % personas.size()] if m > 0 else "balanced"
		})
	start_game_requested.emit(configs, _target_prestige)
