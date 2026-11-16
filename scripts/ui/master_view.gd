class_name MasterView
extends PanelContainer

signal master_clicked(master_id: String)

var master_data: CardData.MasterTile
var clickable: bool = false

func setup(m: CardData.MasterTile, is_clickable: bool = false) -> void:
	master_data = m
	clickable = is_clickable
	custom_minimum_size = Vector2(162, 92)
	add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("2D211B"), UITheme.GOLD_ACCENT if is_clickable else UITheme.GOLD_DIM, 8, 2, 5))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_clickable else Control.CURSOR_ARROW

	for c in get_children():
		c.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vbox.add_child(top)

	var icon := TextureRect.new()
	icon.texture = UITheme.master_icon()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = m.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	top.add_child(name_lbl)

	var pts_lbl := Label.new()
	pts_lbl.text = "+%d" % m.prestige
	pts_lbl.add_theme_font_size_override("font_size", 15)
	pts_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	top.add_child(pts_lbl)

	var title_lbl := Label.new()
	title_lbl.text = m.title
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(title_lbl)

	var req_row := HBoxContainer.new()
	req_row.add_theme_constant_override("separation", 5)
	vbox.add_child(req_row)

	for g in GemTypes.BASE_GEMS:
		var req := int(m.requirements.get(g, 0))
		if req > 0:
			var pip := PanelContainer.new()
			pip.custom_minimum_size = Vector2(30, 24)
			pip.add_theme_stylebox_override("panel", UITheme.make_chip_style(g, 4, 1))
			var lbl := Label.new()
			lbl.text = "%s%d" % [GemTypes.gem_short(g), req]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", GemTypes.gem_text_color(g))
			pip.add_child(lbl)
			req_row.add_child(pip)

func _gui_input(event: InputEvent) -> void:
	if clickable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		master_clicked.emit(master_data.id)
