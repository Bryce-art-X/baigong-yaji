class_name CardView
extends PanelContainer

signal buy_requested(tier: int, slot: int, reserved_idx: int)
signal reserve_requested(tier: int, slot: int)

var card: CardData.CraftCard
var tier: int = 1
var slot: int = -1
var reserved_idx: int = -1
var is_affordable: bool = false
var can_reserve: bool = false
var interactive: bool = true

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
var _bonus_icon: TextureRect
var _title_lbl: Label
var _cost_pips: Dictionary = {} # gem -> {panel, lbl}
var _hover_bar: HBoxContainer
var _buy_btn: Button
var _res_btn: Button

func _ensure_built(is_res: bool) -> void:
	if _built:
		return
	_built = true
	_is_res_mode = is_res
	clip_contents = true

	if is_res:
		# Compact portrait card for reserved hand
		custom_minimum_size = Vector2(96, 134)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		# Classic ~5:7 portrait physical card proportions
		custom_minimum_size = Vector2(118, 166)
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

	# Full-bleed gongbi artwork
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

	# Subtle vignette scrim for readability
	_art_scrim = ColorRect.new()
	_art_scrim.color = Color(0.06, 0.04, 0.03, 0.25)
	_art_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_art_scrim)

	# Ornate tier filigree frame
	_pattern_rect = TextureRect.new()
	_pattern_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pattern_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pattern_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_pattern_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pattern_rect)

	# Top translucent banner (Prestige left, Gem icon right)
	var top_band := ColorRect.new()
	top_band.color = Color(0.08, 0.06, 0.05, 0.68)
	top_band.anchor_left = 0.0
	top_band.anchor_right = 1.0
	top_band.anchor_top = 0.0
	top_band.offset_bottom = 34.0
	top_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_band)

	_prestige_lbl = Label.new()
	_prestige_lbl.position = Vector2(8, 1)
	_prestige_lbl.size = Vector2(30, 32)
	_prestige_lbl.add_theme_font_size_override("font_size", 22 if not is_res else 18)
	_prestige_lbl.add_theme_color_override("font_color", Color("F8E7C0"))
	_prestige_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	_prestige_lbl.add_theme_constant_override("shadow_offset_x", 1)
	_prestige_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_prestige_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prestige_lbl)

	_bonus_icon = TextureRect.new()
	_bonus_icon.anchor_left = 1.0
	_bonus_icon.anchor_right = 1.0
	_bonus_icon.offset_left = -32.0
	_bonus_icon.offset_right = -5.0
	_bonus_icon.offset_top = 4.0
	_bonus_icon.offset_bottom = 30.0
	_bonus_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bonus_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bonus_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bonus_icon)

	# Bottom-left vertical stack of circular cost pips (authentic Splendor layout!)
	var cost_col := VBoxContainer.new()
	cost_col.anchor_left = 0.0
	cost_col.anchor_top = 1.0
	cost_col.anchor_bottom = 1.0
	cost_col.offset_left = 6.0
	cost_col.offset_top = -124.0
	cost_col.offset_right = 34.0
	cost_col.offset_bottom = -6.0
	cost_col.alignment = BoxContainer.ALIGNMENT_END
	cost_col.add_theme_constant_override("separation", 3)
	cost_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cost_col)

	for g in GemTypes.BASE_GEMS:
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(24, 24)
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
		c_lbl.add_theme_font_size_override("font_size", 12)
		c_lbl.add_theme_color_override("font_color", GemTypes.gem_text_color(g))
		c_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_child(c_lbl)
		cost_col.add_child(pip)
		_cost_pips[g] = {"panel": pip, "lbl": c_lbl}

	# Subtle craft name ribbon at bottom-right
	_title_lbl = Label.new()
	_title_lbl.anchor_left = 0.0
	_title_lbl.anchor_right = 1.0
	_title_lbl.anchor_top = 1.0
	_title_lbl.anchor_bottom = 1.0
	_title_lbl.offset_left = 34.0
	_title_lbl.offset_right = -6.0
	_title_lbl.offset_top = -24.0
	_title_lbl.offset_bottom = -4.0
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_title_lbl.clip_text = true
	_title_lbl.add_theme_font_size_override("font_size", 11)
	_title_lbl.add_theme_color_override("font_color", Color("EFE2C6"))
	_title_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	_title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	_title_lbl.add_theme_constant_override("shadow_offset_y", 1)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title_lbl)

	# Hover-only floating action pill (so idle cards look 100% like physical cards!)
	_hover_bar = HBoxContainer.new()
	_hover_bar.visible = false
	_hover_bar.anchor_left = 0.0
	_hover_bar.anchor_right = 1.0
	_hover_bar.anchor_top = 0.5
	_hover_bar.anchor_bottom = 0.5
	_hover_bar.offset_left = 6.0
	_hover_bar.offset_right = -6.0
	_hover_bar.offset_top = -15.0
	_hover_bar.offset_bottom = 15.0
	_hover_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hover_bar.add_theme_constant_override("separation", 4)
	_root.add_child(_hover_bar)

	_buy_btn = Button.new()
	_buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_btn.custom_minimum_size = Vector2(0, 28)
	_buy_btn.add_theme_font_size_override("font_size", 12)
	_buy_btn.pressed.connect(func() -> void: buy_requested.emit(tier, slot, reserved_idx))
	_hover_bar.add_child(_buy_btn)

	if not is_res:
		_res_btn = Button.new()
		_res_btn.text = "留存"
		_res_btn.custom_minimum_size = Vector2(42, 28)
		_res_btn.add_theme_font_size_override("font_size", 11)
		_res_btn.pressed.connect(func() -> void: reserve_requested.emit(tier, slot))
		_hover_bar.add_child(_res_btn)

func setup_board_card(p_card: CardData.CraftCard, p_tier: int, p_slot: int, viewer: PlayerState, p_interactive: bool) -> void:
	_ensure_built(false)
	card = p_card
	tier = p_tier
	slot = p_slot
	reserved_idx = -1
	interactive = p_interactive
	_apply_data(viewer)

func setup_reserved_card(p_card: CardData.CraftCard, p_res_idx: int, viewer: PlayerState, p_interactive: bool) -> void:
	_ensure_built(true)
	card = p_card
	tier = p_card.tier
	slot = -1
	reserved_idx = p_res_idx
	interactive = p_interactive
	_apply_data(viewer)

func _make_card_style(border_col: Color, border_w: int, shadow_sz: int, shadow_off: Vector2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.tier_bg_color(card.tier) if card != null else Color("16110E", 0.45)
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(9)
	sb.shadow_color = Color(0, 0, 0, 0.58)
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
		add_theme_stylebox_override("panel", _make_card_style(Color("3D3028", 0.5), 1, 2, Vector2(1, 2)))
		return

	_root.visible = true
	_empty_lbl.visible = false

	var pay_info := viewer.compute_payment(card) if viewer != null else {"valid": false, "gold_needed": 0, "gold_shortage": 0, "shortfall": {}}
	is_affordable = bool(pay_info["valid"])
	can_reserve = (not _is_res_mode) and viewer != null and viewer.reserved.size() < GameState.MAX_RESERVED

	var tip_lines: Array[String] = ["%s（%s·%d 声望）" % [card.name, GemTypes.gem_name(card.bonus), card.prestige]]
	if viewer != null:
		if is_affordable:
			var gn := int(pay_info["gold_needed"])
			tip_lines.append("点击「打造」" + ("（需补赤金 ×%d）" % gn if gn > 0 else "（材料充足）"))
		else:
			var sf: Dictionary = pay_info.get("shortfall", {})
			var parts: Array[String] = []
			for g in GemTypes.BASE_GEMS:
				var need := int(sf.get(g, 0))
				if need > 0:
					parts.append("%s×%d" % [GemTypes.gem_name(g), need])
			tip_lines.append("尚差：" + ("、".join(parts) if not parts.is_empty() else "无") + "（可抵赤金 %d 枚）" % int(viewer.chips.get(GemTypes.GOLD, 0)))
	tooltip_text = "\n".join(tip_lines)

	var border_col := UITheme.AFFORD_GREEN if (is_affordable and interactive) else Color("C8B288", 0.72)
	add_theme_stylebox_override("panel", _make_card_style(border_col, 2, 7, Vector2(3, 5)))

	_art_rect.texture = UITheme.card_art(card.bonus)
	if _art_mat != null:
		_art_mat.set_shader_parameter("foil_strength", 0.35 if (is_affordable and interactive) else 0.0)
	_pattern_rect.texture = UITheme.card_pattern(card.tier)

	_prestige_lbl.text = str(card.prestige) if card.prestige > 0 else ""
	_bonus_icon.texture = UITheme.gem_icon(card.bonus)
	_title_lbl.text = card.name

	for g in GemTypes.BASE_GEMS:
		var c_amt := int(card.cost.get(g, 0))
		var pip: PanelContainer = _cost_pips[g]["panel"]
		var lbl: Label = _cost_pips[g]["lbl"]
		pip.visible = c_amt > 0
		if c_amt > 0:
			lbl.text = str(c_amt)

	_buy_btn.text = "打造" if is_affordable else ("差%d" % int(pay_info["gold_shortage"]))
	_buy_btn.disabled = not (is_affordable and interactive)
	UITheme.style_button(_buy_btn, Color("245C3A", 0.95) if is_affordable else Color("241D19", 0.92), UITheme.AFFORD_GREEN if is_affordable else UITheme.GOLD_DIM)

	if _res_btn != null:
		_res_btn.disabled = not (can_reserve and interactive)
		UITheme.style_button(_res_btn, Color("4F3A22", 0.95), UITheme.GOLD_ACCENT)

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
		if is_affordable:
			buy_requested.emit(tier, slot, reserved_idx)
		elif can_reserve:
			reserve_requested.emit(tier, slot)

func _on_hover_enter() -> void:
	if card == null:
		return
	_is_hovered = true
	z_index = 10
	pivot_offset = size * 0.5
	var border_col := UITheme.AFFORD_GREEN if (is_affordable and interactive) else UITheme.GOLD_ACCENT
	add_theme_stylebox_override("panel", _make_card_style(border_col, 2, 12, Vector2(4, 9)))
	_art_scrim.color = Color(0.06, 0.04, 0.03, 0.14)
	if interactive:
		_hover_bar.visible = true
	if _art_mat != null:
		_art_mat.set_shader_parameter("foil_strength", 0.8 if is_affordable else 0.45)
	if float(Settings.get_value("anim_speed")) > 0.01:
		if _hover_tw != null and _hover_tw.is_running():
			_hover_tw.kill()
		_hover_tw = create_tween()
		_hover_tw.tween_property(self, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_hover_exit() -> void:
	if card == null:
		return
	_is_hovered = false
	z_index = 0
	_hover_bar.visible = false
	var border_col := UITheme.AFFORD_GREEN if (is_affordable and interactive) else Color("C8B288", 0.72)
	add_theme_stylebox_override("panel", _make_card_style(border_col, 2, 7, Vector2(3, 5)))
	_art_scrim.color = Color(0.06, 0.04, 0.03, 0.25)
	if _art_mat != null:
		_art_mat.set_shader_parameter("rot_x_deg", 0.0)
		_art_mat.set_shader_parameter("rot_y_deg", 0.0)
		_art_mat.set_shader_parameter("foil_strength", 0.35 if (is_affordable and interactive) else 0.0)
	if float(Settings.get_value("anim_speed")) > 0.01:
		if _hover_tw != null and _hover_tw.is_running():
			_hover_tw.kill()
		_hover_tw = create_tween()
		_hover_tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
