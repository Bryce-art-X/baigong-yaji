class_name CardView
extends PanelContainer

signal card_tapped(card_view: CardView)

var card: CardData.CraftCard
var tier: int = 1
var slot: int = -1
var reserved_idx: int = -1
var is_affordable: bool = false
var can_reserve: bool = false
var interactive: bool = true
var is_selected: bool = false

var _built: bool = false
var _is_res_mode: bool = false
var _is_hovered: bool = false
var _art_rect: TextureRect
var _art_mat: ShaderMaterial
var _art_scrim: ColorRect
var _pattern_rect: TextureRect
var _hover_tw: Tween
var _root: Control
var _empty_lbl: Label
var _prestige_lbl: Label
var _tier_tag: Label
var _bonus_icon: TextureRect
var _title_lbl: Label
var _status_pill: PanelContainer
var _status_lbl: Label
var _cost_pips: Dictionary = {} # gem -> {row, panel, lbl, hint_lbl}

func _ensure_built(is_res: bool) -> void:
	if _built:
		return
	_built = true
	_is_res_mode = is_res
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if is_res:
		custom_minimum_size = Vector2(74, 102)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		custom_minimum_size = Vector2(110, 154)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)

	_empty_lbl = Label.new()
	_empty_lbl.text = "空"
	_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_lbl.add_theme_color_override("font_color", Color("5B4D42", 0.5))
	_empty_lbl.visible = false
	add_child(_empty_lbl)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)

	# Full-bleed tier-specific gongbi artwork
	_art_rect = TextureRect.new()
	_art_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = load("res://assets/shaders/card_3d_foil.gdshader")
	if sh != null:
		_art_mat = ShaderMaterial.new()
		_art_mat.shader = sh
		_art_rect.material = _art_mat
	_root.add_child(_art_rect)

	_art_scrim = ColorRect.new()
	_art_scrim.color = Color(0.05, 0.04, 0.03, 0.22)
	_art_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_art_scrim)

	_pattern_rect = TextureRect.new()
	_pattern_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pattern_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pattern_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_pattern_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pattern_rect)

	# Top translucent banner (Prestige left, Tier center, Gem icon right)
	var top_band := ColorRect.new()
	top_band.color = Color(0.08, 0.06, 0.05, 0.72)
	top_band.anchor_left = 0.0
	top_band.anchor_right = 1.0
	top_band.anchor_top = 0.0
	top_band.offset_bottom = 30.0 if is_res else 34.0
	top_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_band)

	_prestige_lbl = Label.new()
	_prestige_lbl.position = Vector2(7, 0)
	_prestige_lbl.size = Vector2(28, 32)
	_prestige_lbl.add_theme_font_size_override("font_size", 18 if is_res else 22)
	_prestige_lbl.add_theme_color_override("font_color", Color("F8E7C0"))
	_prestige_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	_prestige_lbl.add_theme_constant_override("shadow_offset_x", 1)
	_prestige_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_prestige_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prestige_lbl)

	_tier_tag = Label.new()
	_tier_tag.anchor_left = 0.0
	_tier_tag.anchor_right = 1.0
	_tier_tag.offset_top = 6.0
	_tier_tag.offset_bottom = 26.0
	_tier_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_tag.add_theme_font_size_override("font_size", 9 if is_res else 10)
	_tier_tag.add_theme_color_override("font_color", Color("D7C4A1", 0.85))
	_tier_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tier_tag)

	_bonus_icon = TextureRect.new()
	_bonus_icon.anchor_left = 1.0
	_bonus_icon.anchor_right = 1.0
	var ic_sz := 22.0 if is_res else 26.0
	_bonus_icon.offset_left = -(ic_sz + 5.0)
	_bonus_icon.offset_right = -5.0
	_bonus_icon.offset_top = 4.0
	_bonus_icon.offset_bottom = 4.0 + ic_sz
	_bonus_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bonus_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bonus_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bonus_icon)

	# Bottom ribbon for craft name
	var bot_band := ColorRect.new()
	bot_band.color = Color(0.06, 0.04, 0.03, 0.68)
	bot_band.anchor_left = 0.0
	bot_band.anchor_right = 1.0
	bot_band.anchor_top = 1.0
	bot_band.anchor_bottom = 1.0
	bot_band.offset_top = -20.0 if is_res else -24.0
	bot_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bot_band)

	# Bottom-left vertical stack of circular cost pips + per-gem check/shortage indicator
	var cost_col := VBoxContainer.new()
	cost_col.anchor_left = 0.0
	cost_col.anchor_top = 1.0
	cost_col.anchor_bottom = 1.0
	cost_col.offset_left = 5.0
	cost_col.offset_top = -126.0
	cost_col.offset_right = 64.0
	cost_col.offset_bottom = -5.0
	cost_col.alignment = BoxContainer.ALIGNMENT_END
	cost_col.add_theme_constant_override("separation", 2 if is_res else 3)
	cost_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cost_col)

	for g in GemTypes.BASE_GEMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_col.add_child(row)

		var pip_sz := 19 if is_res else 23
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(pip_sz, pip_sz)
		pip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb := UITheme.make_chip_style(g, 999, 2)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		pip.add_theme_stylebox_override("panel", sb)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var c_lbl := Label.new()
		c_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c_lbl.add_theme_font_size_override("font_size", 10 if is_res else 12)
		c_lbl.add_theme_color_override("font_color", GemTypes.gem_text_color(g))
		c_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_child(c_lbl)
		row.add_child(pip)

		var hint_lbl := Label.new()
		hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint_lbl.add_theme_font_size_override("font_size", 10 if is_res else 12)
		hint_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		hint_lbl.add_theme_constant_override("outline_size", 4)
		hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hint_lbl)

		_cost_pips[g] = {"row": row, "panel": pip, "lbl": c_lbl, "hint": hint_lbl}

	# Bottom-right craft title
	_title_lbl = Label.new()
	_title_lbl.anchor_left = 0.0
	_title_lbl.anchor_right = 1.0
	_title_lbl.anchor_top = 1.0
	_title_lbl.anchor_bottom = 1.0
	_title_lbl.offset_left = 28.0
	_title_lbl.offset_right = -5.0
	_title_lbl.offset_top = -20.0 if is_res else -23.0
	_title_lbl.offset_bottom = -2.0
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.clip_text = true
	_title_lbl.add_theme_font_size_override("font_size", 10 if is_res else 11)
	_title_lbl.add_theme_color_override("font_color", Color("F5E8CD"))
	_title_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	_title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	_title_lbl.add_theme_constant_override("shadow_offset_y", 1)
	_title_lbl.visible = not is_res
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title_lbl)

	# Top-right/bottom-right affordability seal ("可造" or "需金×1")
	_status_pill = PanelContainer.new()
	_status_pill.visible = false
	_status_pill.anchor_left = 1.0
	_status_pill.anchor_right = 1.0
	_status_pill.anchor_top = 0.0
	_status_pill.offset_left = -52.0
	_status_pill.offset_right = -4.0
	_status_pill.offset_top = 34.0
	_status_pill.offset_bottom = 52.0
	_status_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_status_pill)

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 10)
	_status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_pill.add_child(_status_lbl)

func setup_board_card(p_card: CardData.CraftCard, p_tier: int, p_slot: int, viewer: PlayerState, p_interactive: bool, p_selected: bool = false) -> void:
	_ensure_built(false)
	card = p_card
	tier = p_tier
	slot = p_slot
	reserved_idx = -1
	interactive = p_interactive
	is_selected = p_selected
	_apply_data(viewer)

func setup_reserved_card(p_card: CardData.CraftCard, p_res_idx: int, viewer: PlayerState, p_interactive: bool, p_selected: bool = false) -> void:
	_ensure_built(true)
	card = p_card
	tier = p_card.tier
	slot = -1
	reserved_idx = p_res_idx
	interactive = p_interactive
	is_selected = p_selected
	_apply_data(viewer)

func _make_card_style(border_col: Color, border_w: int, shadow_sz: int, shadow_off: Vector2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.tier_bg_color(card.tier) if card != null else Color("16110E", 0.45)
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(9)
	sb.shadow_color = Color(0, 0, 0, 0.62)
	sb.shadow_size = shadow_sz
	sb.shadow_offset = shadow_off
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb

func _apply_data(viewer: PlayerState) -> void:
	if card == null:
		_root.visible = false
		_empty_lbl.visible = true
		tooltip_text = ""
		scale = Vector2.ONE
		z_index = 0
		add_theme_stylebox_override("panel", _make_card_style(Color("3D3028", 0.5), 1, 2, Vector2(1, 2)))
		return

	_root.visible = true
	_empty_lbl.visible = false

	var pay_info := viewer.compute_payment(card) if viewer != null else {"valid": false, "gold_needed": 0, "gold_shortage": 0, "shortfall": {}}
	is_affordable = bool(pay_info["valid"])
	can_reserve = (not _is_res_mode) and viewer != null and viewer.reserved.size() < GameState.MAX_RESERVED

	var border_col := UITheme.GOLD_ACCENT if is_selected else (UITheme.AFFORD_GREEN if (is_affordable and interactive) else Color("C8B288", 0.72))
	var bw := 3 if is_selected else 2
	add_theme_stylebox_override("panel", _make_card_style(border_col, bw, 12 if is_selected else 7, Vector2(4, 8) if is_selected else Vector2(3, 5)))
	z_index = 15 if is_selected else 0
	pivot_offset = size * 0.5
	scale = Vector2(1.07, 1.07) if is_selected else Vector2.ONE

	_art_rect.texture = UITheme.card_art(card.bonus, card.tier)
	if _art_mat != null:
		_art_mat.set_shader_parameter("foil_strength", 0.75 if is_selected else (0.35 if (is_affordable and interactive) else 0.0))
	_pattern_rect.texture = UITheme.card_pattern(card.tier)

	_prestige_lbl.text = str(card.prestige) if card.prestige > 0 else ""
	_tier_tag.text = ["", "源地", "商坊", "殿堂"][card.tier]
	_bonus_icon.texture = UITheme.gem_icon(card.bonus)
	_title_lbl.text = card.name

	# Clear per-gem affordability check directly on each cost pip
	var shortfall: Dictionary = pay_info.get("shortfall", {})
	for g in GemTypes.BASE_GEMS:
		var c_amt := int(card.cost.get(g, 0))
		var d: Dictionary = _cost_pips[g]
		var row: HBoxContainer = d["row"]
		var pip: PanelContainer = d["panel"]
		var lbl: Label = d["lbl"]
		var hint: Label = d["hint"]
		row.visible = c_amt > 0
		if c_amt > 0:
			lbl.text = str(c_amt)
			var short_amt := int(shortfall.get(g, 0))
			var sb := UITheme.make_chip_style(g, 999, 2)
			sb.content_margin_left = 0
			sb.content_margin_right = 0
			sb.content_margin_top = 0
			sb.content_margin_bottom = 0
			if viewer != null and short_amt == 0:
				sb.border_color = UITheme.AFFORD_GREEN
				pip.modulate.a = 0.78
				hint.text = "✓"
				hint.add_theme_color_override("font_color", Color("68F0A8"))
			elif viewer != null and short_amt > 0:
				sb.border_color = Color("FF7B6B")
				pip.modulate.a = 1.0
				hint.text = "-%d" % short_amt
				hint.add_theme_color_override("font_color", Color("FFB4A6"))
			else:
				pip.modulate.a = 1.0
				hint.text = ""
			pip.add_theme_stylebox_override("panel", sb)

	# Clear status seal on card when affordable
	if is_affordable and interactive:
		_status_pill.visible = true
		var gn := int(pay_info["gold_needed"])
		var p_sb := StyleBoxFlat.new()
		p_sb.bg_color = Color("1E5634", 0.92) if gn == 0 else Color("6B4F19", 0.94)
		p_sb.border_color = UITheme.AFFORD_GREEN if gn == 0 else UITheme.GOLD_ACCENT
		p_sb.set_border_width_all(1)
		p_sb.set_corner_radius_all(4)
		_status_pill.add_theme_stylebox_override("panel", p_sb)
		_status_lbl.text = "可造" if gn == 0 else "金×%d" % gn
		_status_lbl.add_theme_color_override("font_color", Color("E8FFE8") if gn == 0 else UITheme.GOLD_ACCENT)
	else:
		_status_pill.visible = false

func _gui_input(event: InputEvent) -> void:
	if card == null:
		return
	if _is_hovered and _art_mat != null and float(Settings.get_value("anim_speed")) > 0.01 and event is InputEventMouseMotion:
		var nx := clampf(event.position.x / maxf(1.0, size.x), 0.0, 1.0)
		var ny := clampf(event.position.y / maxf(1.0, size.y), 0.0, 1.0)
		_art_mat.set_shader_parameter("mouse_norm", Vector2(nx, ny))
		_art_mat.set_shader_parameter("rot_y_deg", (nx - 0.5) * 14.0)
		_art_mat.set_shader_parameter("rot_x_deg", -(ny - 0.5) * 14.0)
	elif interactive and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SfxManager.play_click()
		if float(Settings.get_value("anim_speed")) > 0.01:
			TweenFX.punch_in(self, 0.22, 0.08)
		card_tapped.emit(self)

func _on_hover_enter() -> void:
	if card == null or is_selected:
		return
	_is_hovered = true
	z_index = 10
	pivot_offset = size * 0.5
	var border_col := UITheme.AFFORD_GREEN if (is_affordable and interactive) else UITheme.GOLD_ACCENT
	add_theme_stylebox_override("panel", _make_card_style(border_col, 2, 11, Vector2(4, 8)))
	_art_scrim.color = Color(0.05, 0.04, 0.03, 0.12)
	if _art_mat != null:
		_art_mat.set_shader_parameter("foil_strength", 0.72 if is_affordable else 0.40)
	if float(Settings.get_value("anim_speed")) > 0.01:
		if _hover_tw != null and _hover_tw.is_running():
			_hover_tw.kill()
		_hover_tw = create_tween()
		_hover_tw.tween_property(self, "scale", Vector2(1.045, 1.045), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_hover_exit() -> void:
	if card == null or is_selected:
		return
	_is_hovered = false
	z_index = 0
	var border_col := UITheme.AFFORD_GREEN if (is_affordable and interactive) else Color("C8B288", 0.72)
	add_theme_stylebox_override("panel", _make_card_style(border_col, 2, 7, Vector2(3, 5)))
	_art_scrim.color = Color(0.05, 0.04, 0.03, 0.22)
	if _art_mat != null:
		_art_mat.set_shader_parameter("rot_x_deg", 0.0)
		_art_mat.set_shader_parameter("rot_y_deg", 0.0)
		_art_mat.set_shader_parameter("foil_strength", 0.35 if (is_affordable and interactive) else 0.0)
	if float(Settings.get_value("anim_speed")) > 0.01:
		if _hover_tw != null and _hover_tw.is_running():
			_hover_tw.kill()
		_hover_tw = create_tween()
		_hover_tw.tween_property(self, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
