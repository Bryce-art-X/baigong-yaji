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
var _root: VBoxContainer
var _empty_lbl: Label
var _seal: PanelContainer
var _seal_spacer: Control
var _prestige_lbl: Label
var _tier_lbl: Label
var _bonus_icon: TextureRect
var _title_lbl: Label
var _cost_pips: Dictionary = {} # gem -> {panel, lbl}
var _buy_btn: Button
var _res_btn: Button

func _ensure_built(is_res: bool) -> void:
	if _built:
		return
	_built = true
	_is_res_mode = is_res
	if is_res:
		custom_minimum_size = Vector2(160, 118)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		custom_minimum_size = Vector2(150, 146)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL

	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)

	_empty_lbl = Label.new()
	_empty_lbl.text = "已空"
	_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_lbl.add_theme_color_override("font_color", Color("5B4D42"))
	_empty_lbl.visible = false
	add_child(_empty_lbl)

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
	add_child(_art_rect)

	_art_scrim = ColorRect.new()
	_art_scrim.color = Color(0.08, 0.05, 0.04, 0.56)
	_art_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_scrim)

	_pattern_rect = TextureRect.new()
	_pattern_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pattern_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pattern_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_pattern_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pattern_rect)

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 5)
	add_child(_root)

	# Header: Prestige Seal + Tier + SVG Gem Icon
	var header := HBoxContainer.new()
	_root.add_child(header)

	_seal = PanelContainer.new()
	_seal.custom_minimum_size = Vector2(28, 26)
	var seal_sb := StyleBoxFlat.new()
	seal_sb.bg_color = UITheme.SEAL_RED
	seal_sb.border_color = UITheme.GOLD_ACCENT
	seal_sb.set_border_width_all(1)
	seal_sb.set_corner_radius_all(4)
	_seal.add_theme_stylebox_override("panel", seal_sb)
	_prestige_lbl = Label.new()
	_prestige_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prestige_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prestige_lbl.add_theme_font_size_override("font_size", 15)
	_prestige_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	_seal.add_child(_prestige_lbl)
	header.add_child(_seal)

	_seal_spacer = Control.new()
	_seal_spacer.custom_minimum_size = Vector2(28, 26)
	header.add_child(_seal_spacer)

	_tier_lbl = Label.new()
	_tier_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_lbl.add_theme_font_size_override("font_size", 11)
	_tier_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	header.add_child(_tier_lbl)

	_bonus_icon = TextureRect.new()
	_bonus_icon.custom_minimum_size = Vector2(28, 28)
	_bonus_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bonus_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(_bonus_icon)

	# Craft Title
	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.clip_text = true
	_title_lbl.add_theme_font_size_override("font_size", 15)
	_title_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	_root.add_child(_title_lbl)

	# Cost row (circular pips with SIZE_SHRINK_CENTER so they never stretch vertically!)
	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 6)
	cost_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(cost_row)

	for g in GemTypes.BASE_GEMS:
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(28, 28)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.add_theme_stylebox_override("panel", UITheme.make_chip_style(g, 999, 1))
		var c_lbl := Label.new()
		c_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c_lbl.add_theme_font_size_override("font_size", 12)
		c_lbl.add_theme_color_override("font_color", GemTypes.gem_text_color(g))
		pip.add_child(c_lbl)
		cost_row.add_child(pip)
		_cost_pips[g] = {"panel": pip, "lbl": c_lbl}

	# Action buttons
	var actions_box := HBoxContainer.new()
	actions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_box.add_theme_constant_override("separation", 6)
	_root.add_child(actions_box)

	_buy_btn = Button.new()
	_buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_btn.custom_minimum_size = Vector2(0, 30)
	_buy_btn.add_theme_font_size_override("font_size", 12)
	_buy_btn.pressed.connect(func() -> void: buy_requested.emit(tier, slot, reserved_idx))
	actions_box.add_child(_buy_btn)

	if not is_res:
		_res_btn = Button.new()
		_res_btn.text = "留存"
		_res_btn.custom_minimum_size = Vector2(48, 30)
		_res_btn.add_theme_font_size_override("font_size", 12)
		_res_btn.pressed.connect(func() -> void: reserve_requested.emit(tier, slot))
		actions_box.add_child(_res_btn)

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

func _apply_data(viewer: PlayerState) -> void:
	if card == null:
		_art_rect.visible = false
		_art_scrim.visible = false
		_pattern_rect.visible = false
		_root.visible = false
		_empty_lbl.visible = true
		tooltip_text = ""
		add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("1B1411", 0.7), Color("382C25"), 8, 1, 2))
		return

	_art_rect.visible = true
	_art_rect.texture = UITheme.card_art(card.bonus)
	if _art_mat != null:
		_art_mat.set_shader_parameter("foil_strength", 0.32 if (is_affordable and interactive) else 0.0)
	_art_scrim.visible = true
	_pattern_rect.visible = true
	_pattern_rect.texture = UITheme.card_pattern(card.tier)
	_root.visible = true
	_empty_lbl.visible = false

	var pay_info := viewer.compute_payment(card) if viewer != null else {"valid": false, "gold_needed": 0, "gold_shortage": 0, "shortfall": {}}
	is_affordable = bool(pay_info["valid"])
	can_reserve = (not _is_res_mode) and viewer != null and viewer.reserved.size() < GameState.MAX_RESERVED

	var tip_lines: Array[String] = ["%s（%s·%d 声望）" % [card.name, GemTypes.gem_name(card.bonus), card.prestige]]
	if viewer != null:
		if is_affordable:
			var gn := int(pay_info["gold_needed"])
			tip_lines.append("当前可打造" + ("（需补赤金 ×%d）" % gn if gn > 0 else "（材料充足）"))
		else:
			var sf: Dictionary = pay_info.get("shortfall", {})
			var parts: Array[String] = []
			for g in GemTypes.BASE_GEMS:
				var need := int(sf.get(g, 0))
				if need > 0:
					parts.append("%s×%d" % [GemTypes.gem_name(g), need])
			tip_lines.append("尚差：" + ("、".join(parts) if not parts.is_empty() else "无") + "（可抵赤金 %d 枚）" % int(viewer.chips.get(GemTypes.GOLD, 0)))
	tooltip_text = "\n".join(tip_lines)

	var base_bg := UITheme.tier_bg_color(card.tier)
	var border_col := UITheme.AFFORD_GREEN if (is_affordable and interactive) else UITheme.GOLD_DIM
	add_theme_stylebox_override("panel", UITheme.make_panel_style(base_bg, border_col, 10, 2 if is_affordable else 1, 6))

	_seal.visible = card.prestige > 0
	_seal_spacer.visible = card.prestige <= 0
	_prestige_lbl.text = str(card.prestige)
	_tier_lbl.text = ["", "一阶雅物", "二阶名匠", "三阶传世"][card.tier]
	_bonus_icon.texture = UITheme.gem_icon(card.bonus)
	_title_lbl.text = card.name

	for g in GemTypes.BASE_GEMS:
		var c_amt := int(card.cost.get(g, 0))
		var pip: PanelContainer = _cost_pips[g]["panel"]
		var lbl: Label = _cost_pips[g]["lbl"]
		pip.visible = c_amt > 0
		if c_amt > 0:
			lbl.text = str(c_amt)

	_buy_btn.text = "打造" if is_affordable else ("差 %d" % int(pay_info["gold_shortage"]))
	_buy_btn.disabled = not (is_affordable and interactive)
	UITheme.style_button(_buy_btn, Color("295439") if is_affordable else Color("241D19"), UITheme.AFFORD_GREEN if is_affordable else UITheme.GOLD_DIM)

	if _res_btn != null:
		_res_btn.disabled = not (can_reserve and interactive)
		UITheme.style_button(_res_btn, Color("473522"), UITheme.GOLD_DIM)

func _gui_input(event: InputEvent) -> void:
	if not _is_hovered or card == null or _art_mat == null:
		return
	if float(Settings.get_value("anim_speed")) <= 0.01:
		return
	if event is InputEventMouseMotion:
		var nx := clampf(event.position.x / maxf(1.0, size.x), 0.0, 1.0)
		var ny := clampf(event.position.y / maxf(1.0, size.y), 0.0, 1.0)
		_art_mat.set_shader_parameter("mouse_norm", Vector2(nx, ny))
		_art_mat.set_shader_parameter("rot_y_deg", (nx - 0.5) * 14.0)
		_art_mat.set_shader_parameter("rot_x_deg", -(ny - 0.5) * 14.0)

func _on_hover_enter() -> void:
	if card == null:
		return
	_is_hovered = true
	z_index = 10
	pivot_offset = size * 0.5
	var border_col := UITheme.AFFORD_GREEN if (is_affordable and interactive) else UITheme.GOLD_ACCENT
	add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.tier_bg_color(card.tier).lightened(0.08), border_col, 10, 2, 10))
	_art_scrim.color = Color(0.08, 0.05, 0.04, 0.36)
	if _art_mat != null:
		_art_mat.set_shader_parameter("foil_strength", 0.75 if is_affordable else 0.45)
	if float(Settings.get_value("anim_speed")) > 0.01:
		if _hover_tw != null and _hover_tw.is_running():
			_hover_tw.kill()
		_hover_tw = create_tween()
		_hover_tw.tween_property(self, "scale", Vector2(1.035, 1.035), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_hover_exit() -> void:
	if card == null:
		return
	_is_hovered = false
	z_index = 0
	var border_col := UITheme.AFFORD_GREEN if (is_affordable and interactive) else UITheme.GOLD_DIM
	add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.tier_bg_color(card.tier), border_col, 10, 2 if is_affordable else 1, 6))
	_art_scrim.color = Color(0.08, 0.05, 0.04, 0.56)
	if _art_mat != null:
		_art_mat.set_shader_parameter("rot_x_deg", 0.0)
		_art_mat.set_shader_parameter("rot_y_deg", 0.0)
		_art_mat.set_shader_parameter("foil_strength", 0.32 if (is_affordable and interactive) else 0.0)
	if float(Settings.get_value("anim_speed")) > 0.01:
		if _hover_tw != null and _hover_tw.is_running():
			_hover_tw.kill()
		_hover_tw = create_tween()
		_hover_tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
