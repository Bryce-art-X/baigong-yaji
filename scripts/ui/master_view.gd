class_name MasterView
extends PanelContainer

signal master_clicked(master_id: String)

var master_data: CardData.MasterTile
var clickable: bool = false

var _built: bool = false
var _name_lbl: Label
var _pts_lbl: Label
var _title_lbl: Label
var _req_pips: Dictionary = {} # gem -> {panel, lbl}

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(150, 88)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vbox.add_child(top)

	var icon := TextureRect.new()
	icon.texture = UITheme.master_icon()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(icon)

	_name_lbl = Label.new()
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.add_theme_font_size_override("font_size", 15)
	_name_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	top.add_child(_name_lbl)

	_pts_lbl = Label.new()
	_pts_lbl.add_theme_font_size_override("font_size", 15)
	_pts_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	top.add_child(_pts_lbl)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 11)
	_title_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(_title_lbl)

	var req_row := HBoxContainer.new()
	req_row.add_theme_constant_override("separation", 5)
	vbox.add_child(req_row)

	for g in GemTypes.BASE_GEMS:
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(32, 24)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.add_theme_stylebox_override("panel", UITheme.make_chip_style(g, 5, 1))
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", GemTypes.gem_text_color(g))
		pip.add_child(lbl)
		req_row.add_child(pip)
		_req_pips[g] = {"panel": pip, "lbl": lbl}

func setup(m: CardData.MasterTile, is_clickable: bool = false) -> void:
	_ensure_built()
	master_data = m
	clickable = is_clickable
	add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("2D211B"), UITheme.GOLD_ACCENT if is_clickable else UITheme.GOLD_DIM, 8, 2, 5))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_clickable else Control.CURSOR_ARROW

	_name_lbl.text = m.name
	_pts_lbl.text = "+%d" % m.prestige
	_title_lbl.text = m.title

	for g in GemTypes.BASE_GEMS:
		var req := int(m.requirements.get(g, 0))
		var pip: PanelContainer = _req_pips[g]["panel"]
		var lbl: Label = _req_pips[g]["lbl"]
		pip.visible = req > 0
		if req > 0:
			lbl.text = "%s%d" % [GemTypes.gem_short(g), req]

func _gui_input(event: InputEvent) -> void:
	if clickable and master_data != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		master_clicked.emit(master_data.id)
