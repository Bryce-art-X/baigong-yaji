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

var _actions_box: HBoxContainer
var _buy_btn: Button
var _res_btn: Button

func setup_board_card(p_card: CardData.CraftCard, p_tier: int, p_slot: int, viewer: PlayerState, p_interactive: bool) -> void:
	card = p_card
	tier = p_tier
	slot = p_slot
	reserved_idx = -1
	interactive = p_interactive
	_build(viewer)

func setup_reserved_card(p_card: CardData.CraftCard, p_res_idx: int, viewer: PlayerState, p_interactive: bool) -> void:
	card = p_card
	tier = p_card.tier
	slot = -1
	reserved_idx = p_res_idx
	interactive = p_interactive
	_build(viewer)

func _build(viewer: PlayerState) -> void:
	for c in get_children():
		c.queue_free()

	var is_res := reserved_idx >= 0
	custom_minimum_size = Vector2(174, 154) if not is_res else Vector2(162, 124)

	if card == null:
		add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("1B1411"), Color("382C25"), 8, 1, 2))
		var empty_lbl := Label.new()
		empty_lbl.text = "已空"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color("5B4D42"))
		add_child(empty_lbl)
		return

	var pay_info := viewer.compute_payment(card) if viewer != null else {"valid": false, "gold_needed": 0, "gold_shortage": 0, "shortfall": {}}
	is_affordable = bool(pay_info["valid"])
	can_reserve = (not is_res) and viewer != null and viewer.reserved.size() < GameState.MAX_RESERVED

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

	if not mouse_entered.is_connected(_on_hover_enter):
		mouse_entered.connect(_on_hover_enter)
		mouse_exited.connect(_on_hover_exit)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	add_child(root)

	# Header: Prestige Seal + Tier + SVG Gem Icon
	var header := HBoxContainer.new()
	root.add_child(header)

	if card.prestige > 0:
		var seal := PanelContainer.new()
		seal.custom_minimum_size = Vector2(28, 26)
		var seal_sb := StyleBoxFlat.new()
		seal_sb.bg_color = UITheme.SEAL_RED
		seal_sb.border_color = UITheme.GOLD_ACCENT
		seal_sb.set_border_width_all(1)
		seal_sb.set_corner_radius_all(4)
		seal.add_theme_stylebox_override("panel", seal_sb)
		var p_lbl := Label.new()
		p_lbl.text = str(card.prestige)
		p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p_lbl.add_theme_font_size_override("font_size", 15)
		p_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
		seal.add_child(p_lbl)
		header.add_child(seal)
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(28, 26)
		header.add_child(spacer)

	var tier_lbl := Label.new()
	tier_lbl.text = ["", "一阶雅物", "二阶名匠", "三阶传世"][card.tier]
	tier_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	header.add_child(tier_lbl)

	var bonus_icon := TextureRect.new()
	bonus_icon.texture = UITheme.gem_icon(card.bonus)
	bonus_icon.custom_minimum_size = Vector2(28, 28)
	bonus_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bonus_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(bonus_icon)

	# Craft Title + Center Emblem
	var title := Label.new()
	title.text = card.name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	root.add_child(title)

	# Cost row
	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 5)
	cost_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cost_row)

	for g in GemTypes.BASE_GEMS:
		var c_amt := int(card.cost.get(g, 0))
		if c_amt > 0:
			var pip := PanelContainer.new()
			pip.custom_minimum_size = Vector2(26, 24)
			pip.add_theme_stylebox_override("panel", UITheme.make_chip_style(g, 999, 1))
			var c_lbl := Label.new()
			c_lbl.text = str(c_amt)
			c_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			c_lbl.add_theme_font_size_override("font_size", 12)
			c_lbl.add_theme_color_override("font_color", GemTypes.gem_text_color(g))
			pip.add_child(c_lbl)
			cost_row.add_child(pip)

	# Action buttons (Buy / Reserve)
	_actions_box = HBoxContainer.new()
	_actions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions_box.add_theme_constant_override("separation", 6)
	root.add_child(_actions_box)

	_buy_btn = Button.new()
	_buy_btn.text = "打造" if is_affordable else ("差 %d" % int(pay_info["gold_shortage"]))
	_buy_btn.disabled = not (is_affordable and interactive)
	_buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_btn.add_theme_font_size_override("font_size", 12)
	UITheme.style_button(_buy_btn, Color("295439") if is_affordable else Color("241D19"), UITheme.AFFORD_GREEN if is_affordable else UITheme.GOLD_DIM)
	_buy_btn.pressed.connect(func() -> void: buy_requested.emit(tier, slot, reserved_idx))
	_actions_box.add_child(_buy_btn)

	if not is_res:
		_res_btn = Button.new()
		_res_btn.text = "留存"
		_res_btn.disabled = not (can_reserve and interactive)
		_res_btn.add_theme_font_size_override("font_size", 12)
		UITheme.style_button(_res_btn, Color("473522"), UITheme.GOLD_DIM)
		_res_btn.pressed.connect(func() -> void: reserve_requested.emit(tier, slot))
		_actions_box.add_child(_res_btn)

func _on_hover_enter() -> void:
	if card == null:
		return
	var border_col := UITheme.AFFORD_GREEN if (is_affordable and interactive) else UITheme.GOLD_ACCENT
	add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.tier_bg_color(card.tier).lightened(0.08), border_col, 10, 2, 8))

func _on_hover_exit() -> void:
	if card == null:
		return
	var border_col := UITheme.AFFORD_GREEN if (is_affordable and interactive) else UITheme.GOLD_DIM
	add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.tier_bg_color(card.tier), border_col, 10, 2 if is_affordable else 1, 6))
