class_name PlayerPanel
extends PanelContainer
## Compact tabletop plaque for all players (and especially opponents), showing
## score, 5-color discount columns, held chips, and mini card-backs for locked cards.

signal detail_requested(player_index: int)

var _player_index: int = 0
var _built: bool = false
var _name_lbl: Label
var _score_lbl: Label
var _sub_lbl: Label
var _badges: Dictionary = {} # gem -> {panel, lbl}
var _lock_backs: Array[PanelContainer] = []
var _lock_lbls: Array[Label] = []

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	v.add_child(hdr)

	_name_lbl = Label.new()
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.add_theme_font_size_override("font_size", 13)
	hdr.add_child(_name_lbl)

	# Mini locked card-back indicators (up to 3)
	for _i in range(3):
		var lb := PanelContainer.new()
		lb.custom_minimum_size = Vector2(16, 22)
		lb.visible = false
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("362820")
		sb.border_color = UITheme.GOLD_ACCENT
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		lb.add_theme_stylebox_override("panel", sb)
		var ll := Label.new()
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ll.add_theme_font_size_override("font_size", 9)
		ll.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
		lb.add_child(ll)
		hdr.add_child(lb)
		_lock_backs.append(lb)
		_lock_lbls.append(ll)

	_score_lbl = Label.new()
	_score_lbl.add_theme_font_size_override("font_size", 15)
	_score_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	hdr.add_child(_score_lbl)

	_sub_lbl = Label.new()
	_sub_lbl.add_theme_font_size_override("font_size", 11)
	_sub_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	v.add_child(_sub_lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)

	for g in GemTypes.ALL_GEMS:
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", UITheme.make_chip_style(g, 5, 1))
		var b_lbl := Label.new()
		b_lbl.add_theme_font_size_override("font_size", 11)
		b_lbl.add_theme_color_override("font_color", GemTypes.gem_text_color(g))
		badge.add_child(b_lbl)
		row.add_child(badge)
		_badges[g] = {"panel": badge, "lbl": b_lbl}

func update_player(p: PlayerState, is_current: bool) -> void:
	_ensure_built()
	_player_index = p.index
	add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color("31231B", 0.92) if is_current else Color("1D1512", 0.84),
		UITheme.GOLD_ACCENT if is_current else Color("544234", 0.75),
		8,
		2 if is_current else 1,
		5
	))

	var ai_tag := ""
	if p.is_ai:
		var lv_names: Array[String] = ["书童", "匠师", "宗师"]
		var lv_name: String = lv_names[clampi(p.ai_level, 0, 2)]
		ai_tag = " [%s·%s]" % [lv_name, AIAgent.persona_label(p.ai_persona)]
	_name_lbl.text = "%s%s" % [p.name, ai_tag]
	_name_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT if is_current else UITheme.TEXT_MAIN)
	_score_lbl.text = "%d 分" % p.get_score()
	_sub_lbl.text = "已购 %d · 名士 %d · 货币 %d/10（点此查藏品）" % [
		p.purchased.size(), p.masters.size(), p.total_chips()
	]

	for i in range(3):
		if i < p.reserved.size():
			_lock_backs[i].visible = true
			_lock_lbls[i].text = ["", "壹", "贰", "叁"][p.reserved[i].tier]
		else:
			_lock_backs[i].visible = false

	for g in GemTypes.ALL_GEMS:
		var chip_n := int(p.chips[g])
		var disc_n := int(p.discounts.get(g, 0))
		var badge: PanelContainer = _badges[g]["panel"]
		var b_lbl: Label = _badges[g]["lbl"]
		badge.visible = (chip_n > 0 or disc_n > 0)
		if badge.visible:
			if g == GemTypes.GOLD:
				b_lbl.text = "金%d" % chip_n
			elif disc_n > 0:
				b_lbl.text = "%s%d(+%d)" % [GemTypes.gem_short(g), chip_n, disc_n]
			else:
				b_lbl.text = "%s%d" % [GemTypes.gem_short(g), chip_n]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		detail_requested.emit(_player_index)
