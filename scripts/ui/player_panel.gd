class_name PlayerPanel
extends PanelContainer

signal detail_requested(player_index: int)

var _player_index: int = 0
var _built: bool = false
var _name_lbl: Label
var _score_lbl: Label
var _sub_lbl: Label
var _badges: Dictionary = {} # gem -> {panel, lbl}

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	v.add_child(hdr)

	_name_lbl = Label.new()
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.add_theme_font_size_override("font_size", 14)
	hdr.add_child(_name_lbl)

	_score_lbl = Label.new()
	_score_lbl.add_theme_font_size_override("font_size", 15)
	_score_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	hdr.add_child(_score_lbl)

	var detail_btn := Button.new()
	detail_btn.text = "藏品"
	detail_btn.custom_minimum_size = Vector2(44, 26)
	detail_btn.add_theme_font_size_override("font_size", 11)
	UITheme.style_button(detail_btn, Color("2A201A"))
	detail_btn.pressed.connect(func() -> void: detail_requested.emit(_player_index))
	hdr.add_child(detail_btn)

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
		Color("33261F") if is_current else Color("1F1714"),
		UITheme.GOLD_ACCENT if is_current else Color("4A3B31"),
		8,
		2 if is_current else 1,
		4
	))

	_name_lbl.text = "%s%s" % [p.name, " [AI]" if p.is_ai else ""]
	_name_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT if is_current else UITheme.TEXT_MAIN)
	_score_lbl.text = "%d 分" % p.get_score()
	_sub_lbl.text = "已制 %d 件 · 留存 %d · 名士 %d · 材料 %d/10" % [
		p.purchased.size(), p.reserved.size(), p.masters.size(), p.total_chips()
	]

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
