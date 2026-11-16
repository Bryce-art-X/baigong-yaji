class_name AchievementsModal
extends ColorRect

var _progress_lbl: Label
var _list_box: VBoxContainer

func _ready() -> void:
	color = Color(0, 0, 0, 0.78)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 520)
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.PANEL_BG, UITheme.GOLD_ACCENT, 12, 2))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	vbox.add_child(hdr)

	var title := Label.new()
	title.text = "百工成就录"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	hdr.add_child(title)

	_progress_lbl = Label.new()
	_progress_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_lbl.add_theme_font_size_override("font_size", 14)
	_progress_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	hdr.add_child(_progress_lbl)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(88, 36)
	UITheme.style_button(close_btn, Color("472422"), UITheme.SEAL_RED)
	close_btn.pressed.connect(func() -> void:
		SfxManager.play_click()
		visible = false
	)
	hdr.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_box)

func open_achievements() -> void:
	visible = true
	for c in _list_box.get_children():
		c.queue_free()

	var unlocked := Achievements.load_unlocked()
	_progress_lbl.text = "已达成 %d / %d" % [unlocked.size(), Achievements.DEFINITIONS.size()]

	for d in Achievements.DEFINITIONS:
		var got := unlocked.has(str(d["id"]))
		var item := PanelContainer.new()
		item.add_theme_stylebox_override("panel", UITheme.make_panel_style(
			Color("2B211C") if got else Color("1B1512"),
			UITheme.GOLD_ACCENT if got else Color("42362E"),
			8, 1, 2
		))
		_list_box.add_child(item)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		item.add_child(row)

		var badge := Label.new()
		badge.text = "【已成】" if got else "【未竟】"
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", UITheme.GOLD_ACCENT if got else UITheme.TEXT_MUTED)
		row.add_child(badge)

		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)

		var n_lbl := Label.new()
		n_lbl.text = str(d["name"])
		n_lbl.add_theme_font_size_override("font_size", 15)
		n_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN if got else UITheme.TEXT_MUTED)
		v.add_child(n_lbl)

		var desc := Label.new()
		desc.text = str(d["desc"])
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		v.add_child(desc)
