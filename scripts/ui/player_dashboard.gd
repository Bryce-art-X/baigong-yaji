class_name PlayerDashboard
extends PanelContainer
## Dedicated 3-zone bottom dashboard for the current human player:
##   1) Held Currency Chips (手里货币 X/10)
##   2) Purchased Discount Columns (已购资产 · 5-color stacked engine columns)
##   3) Reserved / Locked Cards (锁卡区 · 3 slots, tap to craft)

signal reserved_card_tapped(card_view: CardView, res_idx: int)
signal inspect_requested(player_idx: int)

var _built: bool = false
var _player_idx: int = 0
var _chips_title: Label
var _chip_cells: Dictionary = {} # gem -> {panel, icon, count_lbl}
var _stack_cols: Dictionary = {} # gem -> {col_box, count_lbl, pips_box}
var _res_title: Label
var _res_slots: Array[CardView] = []
var _res_placeholders: Array[PanelContainer] = []

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("19120F", 0.90), Color("8B6D32", 0.75), 12, 2, 8))

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# --- Zone 1: Held Currency Chips ---
	var z1 := VBoxContainer.new()
	z1.add_theme_constant_override("separation", 4)
	root.add_child(z1)

	_chips_title = Label.new()
	_chips_title.text = "手里货币 (0/10)"
	_chips_title.add_theme_font_size_override("font_size", 12)
	_chips_title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	z1.add_child(_chips_title)

	var chips_row := HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 4)
	z1.add_child(chips_row)

	for g in GemTypes.ALL_GEMS:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(38, 66)
		cell.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("241B16"), UITheme.GOLD_DIM, 7, 1, 2))
		chips_row.add_child(cell)

		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 2)
		cell.add_child(cv)

		var icon := TextureRect.new()
		icon.texture = UITheme.gem_icon(g)
		icon.custom_minimum_size = Vector2(24, 24)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cv.add_child(icon)

		var cnt := Label.new()
		cnt.text = "0"
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", 15)
		cv.add_child(cnt)

		_chip_cells[g] = {"panel": cell, "icon": icon, "cnt": cnt}

	var sep1 := VSeparator.new()
	root.add_child(sep1)

	# --- Zone 2: Purchased Cards (5-color permanent discount columns) ---
	var z2 := VBoxContainer.new()
	z2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	z2.add_theme_constant_override("separation", 6)
	root.add_child(z2)

	var z2_hdr := HBoxContainer.new()
	z2.add_child(z2_hdr)

	var z2_lbl := Label.new()
	z2_lbl.text = "已购器物（永久材料减免 · 叠放）"
	z2_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	z2_lbl.add_theme_font_size_override("font_size", 13)
	z2_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	z2_hdr.add_child(z2_lbl)

	var detail_btn := Button.new()
	detail_btn.text = "藏品明细"
	detail_btn.custom_minimum_size = Vector2(74, 24)
	detail_btn.add_theme_font_size_override("font_size", 11)
	UITheme.style_button(detail_btn)
	detail_btn.pressed.connect(func() -> void: inspect_requested.emit(_player_idx))
	z2_hdr.add_child(detail_btn)

	var cols_row := HBoxContainer.new()
	cols_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols_row.add_theme_constant_override("separation", 5)
	z2.add_child(cols_row)

	for g in GemTypes.BASE_GEMS:
		var col_panel := PanelContainer.new()
		col_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_panel.custom_minimum_size = Vector2(46, 66)
		col_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("211915"), GemTypes.gem_color(g).darkened(0.35), 8, 1, 2))
		cols_row.add_child(col_panel)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 3)
		col_panel.add_child(cv)

		var top_h := HBoxContainer.new()
		top_h.alignment = BoxContainer.ALIGNMENT_CENTER
		top_h.add_theme_constant_override("separation", 4)
		cv.add_child(top_h)

		var ic := TextureRect.new()
		ic.texture = UITheme.gem_icon(g)
		ic.custom_minimum_size = Vector2(18, 18)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top_h.add_child(ic)

		var disc_lbl := Label.new()
		disc_lbl.text = "0"
		disc_lbl.add_theme_font_size_override("font_size", 15)
		top_h.add_child(disc_lbl)

		var pips_box := VBoxContainer.new()
		pips_box.add_theme_constant_override("separation", 2)
		cv.add_child(pips_box)

		_stack_cols[g] = {"panel": col_panel, "lbl": disc_lbl, "pips": pips_box}

	var sep2 := VSeparator.new()
	root.add_child(sep2)

	# --- Zone 3: Reserved / Locked Cards (3 slots) ---
	var z3 := VBoxContainer.new()
	z3.add_theme_constant_override("separation", 6)
	root.add_child(z3)

	_res_title = Label.new()
	_res_title.text = "锁卡手牌 (0/3)"
	_res_title.add_theme_font_size_override("font_size", 13)
	_res_title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	z3.add_child(_res_title)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 6)
	z3.add_child(res_row)

	for i in range(3):
		var slot_box := Control.new()
		slot_box.custom_minimum_size = Vector2(74, 102)
		res_row.add_child(slot_box)

		var ph := PanelContainer.new()
		ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ph.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("1B1411", 0.55), Color("4A3B31", 0.55), 8, 1, 1))
		var ph_lbl := Label.new()
		ph_lbl.text = "空位"
		ph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ph_lbl.add_theme_font_size_override("font_size", 11)
		ph_lbl.add_theme_color_override("font_color", Color("6B5B4D"))
		ph.add_child(ph_lbl)
		slot_box.add_child(ph)
		_res_placeholders.append(ph)

		var rcv := CardView.new()
		rcv.visible = false
		var res_idx := i
		rcv.card_tapped.connect(func(cv: CardView) -> void:
			reserved_card_tapped.emit(cv, res_idx)
		)
		slot_box.add_child(rcv)
		_res_slots.append(rcv)

func update_dashboard(p: PlayerState, interactive: bool, selected_res_idx: int = -1) -> void:
	_ensure_built()
	_player_idx = p.index
	_chips_title.text = "%s · 手里货币 (%d/10)" % [p.name, p.total_chips()]

	for g in GemTypes.ALL_GEMS:
		var amt := int(p.chips.get(g, 0))
		var d: Dictionary = _chip_cells[g]
		var cell: PanelContainer = d["panel"]
		var icon: TextureRect = d["icon"]
		var cnt: Label = d["cnt"]
		cnt.text = str(amt)
		cnt.add_theme_color_override("font_color", UITheme.GOLD_ACCENT if (amt > 0 and g == GemTypes.GOLD) else (UITheme.TEXT_MAIN if amt > 0 else Color("5E5146")))
		icon.modulate.a = 1.0 if amt > 0 else 0.32
		cell.add_theme_stylebox_override("panel", UITheme.make_panel_style(
			Color("2A201A") if amt > 0 else Color("1B1512"),
			GemTypes.gem_color(g).lightened(0.2) if amt > 0 else Color("3B3028"),
			8, 2 if amt > 0 else 1, 2
		))

	# Group purchased cards by bonus color to show real stacked miniature cards
	var grouped: Dictionary = {}
	for g in GemTypes.BASE_GEMS:
		grouped[g] = []
	for c in p.purchased:
		grouped[c.bonus].append(c)

	for g in GemTypes.BASE_GEMS:
		var list: Array = grouped[g]
		var sc: Dictionary = _stack_cols[g]
		var lbl: Label = sc["lbl"]
		var pips: VBoxContainer = sc["pips"]
		lbl.text = "+%d" % list.size() if not list.is_empty() else "0"
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN if not list.is_empty() else Color("6B5D52"))

		for child in pips.get_children():
			child.queue_free()
		# Show up to 5 stacked miniature card strips with prestige marks
		var show_n := mini(list.size(), 5)
		for idx in range(show_n):
			var c: CardData.CraftCard = list[list.size() - show_n + idx]
			var strip := PanelContainer.new()
			strip.custom_minimum_size = Vector2(0, 12)
			var sb := StyleBoxFlat.new()
			sb.bg_color = GemTypes.gem_color(g).darkened(0.25)
			sb.border_color = UITheme.GOLD_ACCENT if c.prestige > 0 else Color("E8DEC8", 0.5)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(3)
			strip.add_theme_stylebox_override("panel", sb)
			if c.prestige > 0:
				var pl := Label.new()
				pl.text = "%d★" % c.prestige
				pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				pl.add_theme_font_size_override("font_size", 9)
				pl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
				strip.add_child(pl)
			pips.add_child(strip)

	# Reserved cards
	_res_title.text = "锁卡手牌 (%d/3)" % p.reserved.size()
	for i in range(3):
		if i < p.reserved.size():
			_res_placeholders[i].visible = false
			_res_slots[i].visible = true
			_res_slots[i].setup_reserved_card(p.reserved[i], i, p, interactive, selected_res_idx == i)
		else:
			_res_placeholders[i].visible = true
			_res_slots[i].visible = false

func get_stack_center(gem: String) -> Vector2:
	if _stack_cols.has(gem):
		var p: Control = _stack_cols[gem]["panel"]
		return p.global_position + p.size * 0.5
	return global_position + size * 0.5

func get_chip_center(gem: String) -> Vector2:
	if _chip_cells.has(gem):
		var p: Control = _chip_cells[gem]["panel"]
		return p.global_position + p.size * 0.5
	return global_position + size * 0.5
