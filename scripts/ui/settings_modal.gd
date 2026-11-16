class_name SettingsModal
extends ColorRect

func _ready() -> void:
	color = Color(0, 0, 0, 0.74)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 360)
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.PANEL_BG, UITheme.GOLD_ACCENT, 12, 2))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "雅阁设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	vbox.add_child(title)

	_add_slider_row(vbox, "主音量", "master_volume")
	_add_slider_row(vbox, "背景古乐", "music_volume")
	_add_slider_row(vbox, "器物音效", "sfx_volume")

	# Animation speed
	var anim_row := HBoxContainer.new()
	anim_row.add_theme_constant_override("separation", 8)
	vbox.add_child(anim_row)
	var a_lbl := Label.new()
	a_lbl.text = "动画演出速度"
	a_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	anim_row.add_child(a_lbl)
	for pair in [["关闭", 0.0], ["正常", 1.0], ["快速", 2.0]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(64, 34)
		var val: float = pair[1]
		UITheme.style_button(b)
		b.pressed.connect(func() -> void:
			Settings.set_value("anim_speed", val)
			SfxManager.play_click()
		)
		anim_row.add_child(b)

	# AI delay
	var ai_row := HBoxContainer.new()
	ai_row.add_theme_constant_override("separation", 8)
	vbox.add_child(ai_row)
	var ai_lbl := Label.new()
	ai_lbl.text = "AI 思考节奏"
	ai_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	ai_row.add_child(ai_lbl)
	for pair in [["极快", 0.2], ["正常", 0.55], ["从容", 1.0]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(64, 34)
		var val: float = pair[1]
		UITheme.style_button(b)
		b.pressed.connect(func() -> void:
			Settings.set_value("ai_delay", val)
			SfxManager.play_click()
		)
		ai_row.add_child(b)

	# Fullscreen (desktop only)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var fs_row := HBoxContainer.new()
		vbox.add_child(fs_row)
		var fs_lbl := Label.new()
		fs_lbl.text = "全屏模式"
		fs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fs_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
		fs_row.add_child(fs_lbl)
		var fs_btn := Button.new()
		fs_btn.custom_minimum_size = Vector2(100, 34)
		fs_btn.text = "已开启" if bool(Settings.get_value("fullscreen")) else "窗口模式"
		UITheme.style_button(fs_btn)
		fs_btn.pressed.connect(func() -> void:
			var nxt := not bool(Settings.get_value("fullscreen"))
			Settings.set_value("fullscreen", nxt)
			fs_btn.text = "已开启" if nxt else "窗口模式"
			SfxManager.play_click()
		)
		fs_row.add_child(fs_btn)

	var close_btn := Button.new()
	close_btn.text = "完成"
	close_btn.custom_minimum_size = Vector2(140, 40)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.style_button(close_btn, Color("295439"), UITheme.AFFORD_GREEN)
	close_btn.pressed.connect(func() -> void:
		SfxManager.play_click()
		visible = false
	)
	vbox.add_child(close_btn)

func _add_slider_row(parent: VBoxContainer, label_text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(96, 0)
	lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Settings.get_value(key))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var pct := Label.new()
	pct.custom_minimum_size = Vector2(44, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.text = "%d%%" % int(round(slider.value * 100.0))
	pct.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	row.add_child(pct)

	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_value(key, v)
		pct.text = "%d%%" % int(round(v * 100.0))
	)
