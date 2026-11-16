class_name BoardView
extends Control

signal return_to_menu_requested
signal restart_requested

var _controller: GameController
var state: GameState
var _selected_gems: Array[String] = []
var _discard_pool: Dictionary = {}
var _stats_recorded: bool = false
var _ai_timer: Timer

var _top_status_lbl: Label
var _undo_btn: Button
var _sfx_btn: Button
var _players_box: VBoxContainer
var _masters_row: HBoxContainer
var _tiers_box: VBoxContainer
var _reserved_row: HBoxContainer
var _reserved_title: Label
var _bank_box: VBoxContainer
var _selection_lbl: Label
var _confirm_take_btn: Button
var _clear_take_btn: Button
var _log_lbl: RichTextLabel

var _modal_overlay: ColorRect
var _modal_panel: PanelContainer
var _modal_content: VBoxContainer

func _ready() -> void:
	SfxManager.ensure_host(self)
	_ai_timer = Timer.new()
	_ai_timer.one_shot = true
	_ai_timer.wait_time = 0.55
	_ai_timer.timeout.connect(_on_ai_timer_timeout)
	add_child(_ai_timer)
	_build_skeleton()

func start_game(p_state: GameState) -> void:
	_controller = GameController.new(p_state)
	_controller.events_applied.connect(func(_act: GameAction, evs: Array) -> void:
		EventBus.game_events.emit(evs)
	)
	state = _controller.state
	_selected_gems.clear()
	_discard_pool.clear()
	_stats_recorded = false
	EventBus.game_started.emit(state)
	_refresh_all()
	_schedule_ai_if_needed()

func _build_skeleton() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG_DARK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	margin.add_child(main_vbox)

	# Top Bar
	var top_bar := PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.PANEL_BG, UITheme.GOLD_DIM, 8, 1))
	main_vbox.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	top_bar.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "百工雅集"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	top_hbox.add_child(title_lbl)

	_top_status_lbl = Label.new()
	_top_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_status_lbl.add_theme_font_size_override("font_size", 15)
	_top_status_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	top_hbox.add_child(_top_status_lbl)

	_undo_btn = Button.new()
	_undo_btn.text = "悔棋"
	_undo_btn.disabled = true
	UITheme.style_button(_undo_btn)
	_undo_btn.pressed.connect(_on_undo_pressed)
	top_hbox.add_child(_undo_btn)

	_sfx_btn = Button.new()
	_sfx_btn.text = "音效: 关" if SfxManager.muted else "音效: 开"
	UITheme.style_button(_sfx_btn)
	_sfx_btn.pressed.connect(func() -> void:
		Settings.set_value("sfx_enabled", SfxManager.muted)
		_sfx_btn.text = "音效: 关" if SfxManager.muted else "音效: 开"
		SfxManager.play_click()
	)
	top_hbox.add_child(_sfx_btn)

	var rules_btn := Button.new()
	rules_btn.text = "雅集规制"
	UITheme.style_button(rules_btn)
	rules_btn.pressed.connect(_show_rules_modal)
	top_hbox.add_child(rules_btn)

	var menu_btn := Button.new()
	menu_btn.text = "返回主阁"
	UITheme.style_button(menu_btn, Color("472422"), UITheme.SEAL_RED)
	menu_btn.pressed.connect(func() -> void:
		_ai_timer.stop()
		return_to_menu_requested.emit()
	)
	top_hbox.add_child(menu_btn)

	# Body 3 Columns
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	main_vbox.add_child(body)

	# Left: Players
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
	left_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	body.add_child(left_panel)

	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_v)

	var p_hdr := Label.new()
	p_hdr.text = "诸位匠师"
	p_hdr.add_theme_font_size_override("font_size", 16)
	p_hdr.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	left_v.add_child(p_hdr)

	_players_box = VBoxContainer.new()
	_players_box.add_theme_constant_override("separation", 8)
	left_v.add_child(_players_box)

	# Center: Masters + 3x4 Board + Reserved
	var center_v := VBoxContainer.new()
	center_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_v.add_theme_constant_override("separation", 8)
	body.add_child(center_v)

	var masters_panel := PanelContainer.new()
	masters_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	center_v.add_child(masters_panel)

	var m_hbox := HBoxContainer.new()
	m_hbox.add_theme_constant_override("separation", 10)
	masters_panel.add_child(m_hbox)

	var m_lbl := Label.new()
	m_lbl.text = "名士\n雅客"
	m_lbl.add_theme_font_size_override("font_size", 14)
	m_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	m_hbox.add_child(m_lbl)

	_masters_row = HBoxContainer.new()
	_masters_row.add_theme_constant_override("separation", 8)
	m_hbox.add_child(_masters_row)

	var board_panel := PanelContainer.new()
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	center_v.add_child(board_panel)

	_tiers_box = VBoxContainer.new()
	_tiers_box.add_theme_constant_override("separation", 8)
	_tiers_box.alignment = BoxContainer.ALIGNMENT_CENTER
	board_panel.add_child(_tiers_box)

	var res_panel := PanelContainer.new()
	res_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	center_v.add_child(res_panel)

	var res_hbox := HBoxContainer.new()
	res_hbox.add_theme_constant_override("separation", 10)
	res_panel.add_child(res_hbox)

	_reserved_title = Label.new()
	_reserved_title.text = "留存\n图谱"
	_reserved_title.add_theme_font_size_override("font_size", 14)
	_reserved_title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	res_hbox.add_child(_reserved_title)

	_reserved_row = HBoxContainer.new()
	_reserved_row.add_theme_constant_override("separation", 8)
	res_hbox.add_child(_reserved_row)

	# Right: Bank + Log
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(270, 0)
	right_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	body.add_child(right_panel)

	var right_v := VBoxContainer.new()
	right_v.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_v)

	var bank_hdr := Label.new()
	bank_hdr.text = "库房材料（点击选取）"
	bank_hdr.add_theme_font_size_override("font_size", 16)
	bank_hdr.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	right_v.add_child(bank_hdr)

	_bank_box = VBoxContainer.new()
	_bank_box.add_theme_constant_override("separation", 6)
	right_v.add_child(_bank_box)

	_selection_lbl = Label.new()
	_selection_lbl.text = "未选材料"
	_selection_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_selection_lbl.add_theme_font_size_override("font_size", 13)
	_selection_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	right_v.add_child(_selection_lbl)

	var sel_btns := HBoxContainer.new()
	sel_btns.add_theme_constant_override("separation", 6)
	right_v.add_child(sel_btns)

	_confirm_take_btn = Button.new()
	_confirm_take_btn.text = "确认拿取"
	_confirm_take_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(_confirm_take_btn, Color("295439"), UITheme.AFFORD_GREEN)
	_confirm_take_btn.pressed.connect(_on_confirm_take_pressed)
	sel_btns.add_child(_confirm_take_btn)

	_clear_take_btn = Button.new()
	_clear_take_btn.text = "清空"
	UITheme.style_button(_clear_take_btn)
	_clear_take_btn.pressed.connect(func() -> void:
		_selected_gems.clear()
		_refresh_bank_and_selection()
	)
	sel_btns.add_child(_clear_take_btn)

	var log_hdr := Label.new()
	log_hdr.text = "雅集纪要"
	log_hdr.add_theme_font_size_override("font_size", 15)
	log_hdr.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	right_v.add_child(log_hdr)

	_log_lbl = RichTextLabel.new()
	_log_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_lbl.scroll_following = true
	_log_lbl.add_theme_font_size_override("normal_font_size", 12)
	_log_lbl.add_theme_color_override("default_color", UITheme.TEXT_MUTED)
	right_v.add_child(_log_lbl)

	# Modal Overlay
	_modal_overlay = ColorRect.new()
	_modal_overlay.color = Color(0, 0, 0, 0.72)
	_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.visible = false
	add_child(_modal_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.add_child(center)

	_modal_panel = PanelContainer.new()
	_modal_panel.custom_minimum_size = Vector2(460, 240)
	_modal_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("241B17"), UITheme.GOLD_ACCENT, 12, 2))
	center.add_child(_modal_panel)

	_modal_content = VBoxContainer.new()
	_modal_content.add_theme_constant_override("separation", 12)
	_modal_panel.add_child(_modal_content)

func _is_human_turn() -> bool:
	return state != null and state.phase == GameState.TurnPhase.ACTION and not state.current_player().is_ai

func _refresh_all() -> void:
	if state == null:
		return

	var cur := state.current_player()
	var final_tag := "  |  【终局轮】" if state.final_round_triggered else ""
	_top_status_lbl.text = "第 %d 轮  |  当前行动：%s%s  |  目标声望：%d 分%s" % [
		state.round_number,
		cur.name,
		" (自动)" if cur.is_ai else "",
		state.target_prestige,
		final_tag
	]

	_refresh_players()
	_refresh_masters()
	_refresh_board()
	_refresh_reserved()
	_refresh_bank_and_selection()
	_refresh_log()

	if _undo_btn != null:
		var can_undo := false
		for d in state.history:
			var pi := int(d.get("p", -1))
			if pi >= 0 and pi < state.players.size() and not state.players[pi].is_ai:
				can_undo = true
				break
		_undo_btn.disabled = (not can_undo) or cur.is_ai or state.phase == GameState.TurnPhase.GAME_OVER

	if not cur.is_ai and state.phase == GameState.TurnPhase.ACTION:
		SaveManager.save_autosave(state)

	# Handle modal phases
	if state.phase == GameState.TurnPhase.DISCARD_CHIPS and not cur.is_ai:
		_show_discard_modal()
	elif state.phase == GameState.TurnPhase.CHOOSE_MASTER and not cur.is_ai:
		_show_choose_master_modal()
	elif state.phase == GameState.TurnPhase.GAME_OVER:
		if not _stats_recorded:
			_stats_recorded = true
			SaveManager.record_game_result(state)
			SaveManager.clear_autosave()
			SfxManager.play_victory()
		_show_game_over_modal()
	else:
		_modal_overlay.visible = false

func _refresh_players() -> void:
	for c in _players_box.get_children():
		c.queue_free()

	for p in state.players:
		var is_cur := (p.index == state.current_player_idx) and (state.phase != GameState.TurnPhase.GAME_OVER)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.make_panel_style(
			Color("33261F") if is_cur else Color("1F1714"),
			UITheme.GOLD_ACCENT if is_cur else Color("4A3B31"),
			8,
			2 if is_cur else 1
		))
		_players_box.add_child(card)

		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)

		var hdr := HBoxContainer.new()
		v.add_child(hdr)

		var n_lbl := Label.new()
		n_lbl.text = "%s%s" % [p.name, " [AI]" if p.is_ai else ""]
		n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n_lbl.add_theme_font_size_override("font_size", 14)
		n_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT if is_cur else UITheme.TEXT_MAIN)
		hdr.add_child(n_lbl)

		var sc_lbl := Label.new()
		sc_lbl.text = "%d 分" % p.get_score()
		sc_lbl.add_theme_font_size_override("font_size", 15)
		sc_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
		hdr.add_child(sc_lbl)

		var detail_btn := Button.new()
		detail_btn.text = "藏品"
		detail_btn.add_theme_font_size_override("font_size", 11)
		UITheme.style_button(detail_btn, Color("2A201A"))
		detail_btn.pressed.connect(func() -> void: _show_player_detail_modal(p))
		hdr.add_child(detail_btn)

		var sub_lbl := Label.new()
		sub_lbl.text = "已制 %d 件 · 留存 %d · 名士 %d · 材料 %d/10" % [
			p.purchased.size(), p.reserved.size(), p.masters.size(), p.total_chips()
		]
		sub_lbl.add_theme_font_size_override("font_size", 11)
		sub_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		v.add_child(sub_lbl)

		# Discounts + Chips compact badges
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		v.add_child(row)

		for g in GemTypes.ALL_GEMS:
			var chip_n := int(p.chips[g])
			var disc_n := int(p.discounts.get(g, 0))
			if chip_n == 0 and disc_n == 0:
				continue
			var badge := PanelContainer.new()
			badge.add_theme_stylebox_override("panel", UITheme.make_chip_style(g, 5, 1))
			var b_lbl := Label.new()
			if g == GemTypes.GOLD:
				b_lbl.text = "金%d" % chip_n
			elif disc_n > 0:
				b_lbl.text = "%s%d(+%d)" % [GemTypes.gem_short(g), chip_n, disc_n]
			else:
				b_lbl.text = "%s%d" % [GemTypes.gem_short(g), chip_n]
			b_lbl.add_theme_font_size_override("font_size", 11)
			b_lbl.add_theme_color_override("font_color", GemTypes.gem_text_color(g))
			badge.add_child(b_lbl)
			row.add_child(badge)

func _refresh_masters() -> void:
	for c in _masters_row.get_children():
		c.queue_free()
	for m in state.masters:
		var mv := MasterView.new()
		mv.setup(m, false)
		_masters_row.add_child(mv)

func _refresh_board() -> void:
	for c in _tiers_box.get_children():
		c.queue_free()

	var human_turn := _is_human_turn()
	var viewer := state.current_player()

	for tier in [3, 2, 1]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_tiers_box.add_child(row)

		# Deck pile button (blind reserve)
		var deck_btn := Button.new()
		var rem: int = state.decks[tier].size()
		deck_btn.custom_minimum_size = Vector2(96, 154)
		deck_btn.text = "%s阶\n图谱\n(%d)" % [["", "一", "二", "三"][tier], rem]
		deck_btn.disabled = not (human_turn and rem > 0 and viewer.reserved.size() < GameState.MAX_RESERVED)
		UITheme.style_button(deck_btn, UITheme.tier_bg_color(tier), UITheme.GOLD_DIM)
		deck_btn.pressed.connect(func() -> void:
			_on_reserve_deck(tier)
		)
		row.add_child(deck_btn)

		for slot in range(4):
			var cv := CardView.new()
			cv.setup_board_card(state.board[tier][slot], tier, slot, viewer, human_turn)
			cv.buy_requested.connect(_on_buy_requested)
			cv.reserve_requested.connect(_on_reserve_board)
			row.add_child(cv)

func _refresh_reserved() -> void:
	for c in _reserved_row.get_children():
		c.queue_free()

	var viewer := state.current_player()
	var human_turn := _is_human_turn()
	_reserved_title.text = "%s\n留存(%d/3)" % [viewer.name, viewer.reserved.size()]

	if viewer.reserved.is_empty():
		var lbl := Label.new()
		lbl.text = "暂无留存图谱（点击展示区卡牌“留存”可锁定图谱并获赠 1 枚赤金）"
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		_reserved_row.add_child(lbl)
		return

	if viewer.is_ai:
		var lbl := Label.new()
		lbl.text = "%s 留存了 %d 张图谱（暗置）" % [viewer.name, viewer.reserved.size()]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		_reserved_row.add_child(lbl)
		return

	for i in range(viewer.reserved.size()):
		var cv := CardView.new()
		cv.setup_reserved_card(viewer.reserved[i], i, viewer, human_turn)
		cv.buy_requested.connect(_on_buy_requested)
		_reserved_row.add_child(cv)

func _refresh_bank_and_selection() -> void:
	for c in _bank_box.get_children():
		c.queue_free()

	var human_turn := _is_human_turn()

	for g in GemTypes.ALL_GEMS:
		var amt := int(state.bank[g])
		var sel_cnt: int = _selected_gems.count(g)
		var can_pick := (g != GemTypes.GOLD) and human_turn and _can_add_to_selection(g)

		var chip_btn := Button.new()
		chip_btn.custom_minimum_size = Vector2(0, 44)
		chip_btn.disabled = (g == GemTypes.GOLD) or (not can_pick and sel_cnt == 0)
		var bg_col := Color("3A2C21") if sel_cnt > 0 else Color("241C17")
		var bd_col := UITheme.GOLD_ACCENT if sel_cnt > 0 else UITheme.GOLD_DIM
		UITheme.style_button(chip_btn, bg_col, bd_col)
		if can_pick:
			chip_btn.pressed.connect(func() -> void:
				_selected_gems.append(g)
				SfxManager.play_click()
				_refresh_bank_and_selection()
			)
		elif sel_cnt > 0 and human_turn:
			chip_btn.pressed.connect(func() -> void:
				_selected_gems.erase(g)
				SfxManager.play_click()
				_refresh_bank_and_selection()
			)
		_bank_box.add_child(chip_btn)

		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_theme_constant_override("margin_left", 8)
		pad.add_theme_constant_override("margin_right", 10)
		chip_btn.add_child(pad)
		pad.add_child(row)

		var icon := TextureRect.new()
		icon.texture = UITheme.gem_icon(g)
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = GemTypes.gem_name(g)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)

		if sel_cnt > 0:
			var sel_lbl := Label.new()
			sel_lbl.text = "+%d" % sel_cnt
			sel_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sel_lbl.add_theme_font_size_override("font_size", 14)
			sel_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
			sel_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(sel_lbl)

		var cnt_lbl := Label.new()
		cnt_lbl.text = "×%d" % amt if g != GemTypes.GOLD else "×%d (留存)" % amt
		cnt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cnt_lbl.add_theme_font_size_override("font_size", 13)
		cnt_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED if g == GemTypes.GOLD else UITheme.TEXT_MAIN)
		cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cnt_lbl)

	if _selected_gems.is_empty():
		_selection_lbl.text = "点击上方材料：拿 3 种不同，或双击同种（余量 ≥ 4）"
		_confirm_take_btn.disabled = true
	else:
		var names: Array[String] = []
		for g in _selected_gems:
			names.append(GemTypes.gem_name(g))
		_selection_lbl.text = "已选：%s" % " + ".join(names)
		_confirm_take_btn.disabled = not (human_turn and _is_selection_valid())

func _can_add_to_selection(g: String) -> bool:
	var bank_amt := int(state.bank.get(g, 0))
	if bank_amt <= 0:
		return false
	if _selected_gems.is_empty():
		return true
	if _selected_gems.size() == 1:
		if _selected_gems[0] == g:
			return bank_amt >= 4
		return true
	if _selected_gems.size() == 2:
		if _selected_gems[0] == _selected_gems[1]:
			return false # already taking 2 same
		return not _selected_gems.has(g)
	return false

func _is_selection_valid() -> bool:
	if _selected_gems.size() == 2 and _selected_gems[0] == _selected_gems[1]:
		return bool(RulesEngine.can_take_two_same(state, _selected_gems[0])["ok"])
	return bool(RulesEngine.can_take_different(state, _selected_gems)["ok"])

func _on_undo_pressed() -> void:
	if _controller == null:
		return
	_ai_timer.stop()
	if _controller.undo_last_human_action():
		state = _controller.state
		_selected_gems.clear()
		_discard_pool.clear()
		SfxManager.play_click()
		_refresh_all()

func _on_confirm_take_pressed() -> void:
	if not _is_selection_valid():
		return
	var act: GameAction
	var take_cnt := _selected_gems.size()
	if take_cnt == 2 and _selected_gems[0] == _selected_gems[1]:
		act = GameAction.take_two(_selected_gems[0])
	else:
		act = GameAction.take_different(_selected_gems)
	var res := _controller.apply(act)
	if bool(res["ok"]):
		SfxManager.play_take_chip(take_cnt)
		_selected_gems.clear()
		_after_player_move()

func _on_buy_requested(tier: int, slot: int, reserved_idx: int) -> void:
	var prev_masters := state.current_player().masters.size()
	var card_prestige := 0
	if reserved_idx >= 0 and reserved_idx < state.current_player().reserved.size():
		card_prestige = state.current_player().reserved[reserved_idx].prestige
	elif state.board.has(tier) and slot >= 0 and slot < 4 and state.board[tier][slot] != null:
		card_prestige = state.board[tier][slot].prestige
	var act := GameAction.buy_reserved(reserved_idx) if reserved_idx >= 0 else GameAction.buy_board(tier, slot)
	var res := _controller.apply(act)
	if bool(res["ok"]):
		_selected_gems.clear()
		SfxManager.play_buy(card_prestige)
		if state.players[state.current_player_idx].masters.size() > prev_masters:
			SfxManager.play_master()
		_after_player_move()

func _on_reserve_board(tier: int, slot: int) -> void:
	var res := _controller.apply(GameAction.reserve_board(tier, slot))
	if bool(res["ok"]):
		_selected_gems.clear()
		SfxManager.play_reserve()
		_after_player_move()

func _on_reserve_deck(tier: int) -> void:
	var res := _controller.apply(GameAction.reserve_deck(tier))
	if bool(res["ok"]):
		_selected_gems.clear()
		SfxManager.play_reserve()
		_after_player_move()

func _after_player_move() -> void:
	_refresh_all()
	_schedule_ai_if_needed()

func _schedule_ai_if_needed() -> void:
	if state == null or state.phase == GameState.TurnPhase.GAME_OVER:
		return
	if state.current_player().is_ai:
		_ai_timer.wait_time = maxf(0.05, float(Settings.get_value("ai_delay")))
		_ai_timer.start()

func _on_ai_timer_timeout() -> void:
	if state == null or state.phase == GameState.TurnPhase.GAME_OVER:
		return
	if state.current_player().is_ai:
		AIAgent.take_turn_step(state)
		_refresh_all()
		_schedule_ai_if_needed()

func _refresh_log() -> void:
	var lines: Array[String] = []
	var start := maxi(0, state.action_log.size() - 16)
	for i in range(start, state.action_log.size()):
		lines.append("· " + state.action_log[i])
	_log_lbl.text = "\n".join(lines)

func _clear_modal() -> void:
	for c in _modal_content.get_children():
		c.queue_free()
	_modal_overlay.visible = true

func _show_discard_modal() -> void:
	_clear_modal()
	var p := state.current_player()
	var excess := p.total_chips() - GameState.MAX_CHIPS
	if _discard_pool.is_empty():
		_discard_pool = GemTypes.create_empty_pool(true)

	var title := Label.new()
	title.text = "材料超限（最多持有 10 枚）"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	_modal_content.add_child(title)

	var sub := Label.new()
	var chosen_sum := GemTypes.total_count(_discard_pool)
	sub.text = "请选择归还 %d 枚材料（已选 %d / %d）：" % [excess, chosen_sum, excess]
	sub.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	_modal_content.add_child(sub)

	for g in GemTypes.ALL_GEMS:
		var owned := int(p.chips[g])
		if owned == 0:
			continue
		var ret := int(_discard_pool[g])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_modal_content.add_child(row)

		var lbl := Label.new()
		lbl.text = "%s（持有 %d）" % [GemTypes.gem_name(g), owned]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
		row.add_child(lbl)

		var minus_b := Button.new()
		minus_b.text = "-"
		minus_b.disabled = ret <= 0
		UITheme.style_button(minus_b)
		minus_b.pressed.connect(func() -> void:
			_discard_pool[g] -= 1
			_show_discard_modal()
		)
		row.add_child(minus_b)

		var val_lbl := Label.new()
		val_lbl.text = str(ret)
		val_lbl.custom_minimum_size = Vector2(24, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
		row.add_child(val_lbl)

		var plus_b := Button.new()
		plus_b.text = "+"
		plus_b.disabled = ret >= owned or chosen_sum >= excess
		UITheme.style_button(plus_b)
		plus_b.pressed.connect(func() -> void:
			_discard_pool[g] += 1
			_show_discard_modal()
		)
		row.add_child(plus_b)

	var ok_btn := Button.new()
	ok_btn.text = "确认归还"
	ok_btn.disabled = chosen_sum != excess
	UITheme.style_button(ok_btn, Color("295439"), UITheme.AFFORD_GREEN)
	ok_btn.pressed.connect(func() -> void:
		var res := _controller.apply(GameAction.discard(_discard_pool))
		if bool(res["ok"]):
			_discard_pool.clear()
			_after_player_move()
	)
	_modal_content.add_child(ok_btn)

func _show_choose_master_modal() -> void:
	_clear_modal()
	var title := Label.new()
	title.text = "多位名士同时青睐，请择一邀约："
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	_modal_content.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_modal_content.add_child(row)

	for m in state.pending_masters:
		var mv := MasterView.new()
		mv.setup(m, true)
		mv.master_clicked.connect(func(mid: String) -> void:
			_controller.apply(GameAction.choose_master(mid))
			_after_player_move()
		)
		row.add_child(mv)

func _show_game_over_modal() -> void:
	_clear_modal()
	var title := Label.new()
	title.text = "雅集落幕 · 终局榜"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	_modal_content.add_child(title)

	var ranked := state.players.duplicate()
	ranked.sort_custom(func(a: PlayerState, b: PlayerState) -> bool:
		if a.get_score() != b.get_score():
			return a.get_score() > b.get_score()
		return a.purchased.size() < b.purchased.size()
	)

	for p in ranked:
		var is_w := state.winner_indices.has(p.index)
		var lbl := Label.new()
		lbl.text = "%s%s  —  %d 声望（制成 %d 件器物，名士 %d 位）" % [
			"【魁首】" if is_w else "　　　",
			p.name, p.get_score(), p.purchased.size(), p.masters.size()
		]
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT if is_w else UITheme.TEXT_MAIN)
		_modal_content.add_child(lbl)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	_modal_content.add_child(btns)

	var replay_btn := Button.new()
	replay_btn.text = "再开一局"
	UITheme.style_button(replay_btn, Color("295439"), UITheme.AFFORD_GREEN)
	replay_btn.pressed.connect(func() -> void:
		_modal_overlay.visible = false
		restart_requested.emit()
	)
	btns.add_child(replay_btn)

	var menu_btn := Button.new()
	menu_btn.text = "返回主阁"
	UITheme.style_button(menu_btn)
	menu_btn.pressed.connect(func() -> void:
		_modal_overlay.visible = false
		return_to_menu_requested.emit()
	)
	btns.add_child(menu_btn)

func _show_rules_modal() -> void:
	_clear_modal()
	var title := Label.new()
	title.text = "《百工雅集》规制速览"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	_modal_content.add_child(title)

	var body := Label.new()
	body.text = (
		"1. 每回合四选一：\n"
		+ "   · 采集 3 种不同基础材料（库房不足 3 种时可拿剩余全部不同种）。\n"
		+ "   · 双取 1 种材料 2 枚（需该材料库房存量 ≥ 4）。\n"
		+ "   · 留存 1 张展示区或牌库顶图谱（上限 3 张），并获 1 枚赤金（百搭）。\n"
		+ "   · 打造 1 件展示区或已留存的器物，获得对应门类永久折扣与声望。\n"
		+ "2. 手中材料上限 10 枚，超出须在回合末归还多余部分。\n"
		+ "3. 永久折扣达到名士要求时，名士自动亲临雅集（+3 声望）。\n"
		+ "4. 任意匠师达到目标声望（默认 15 分）触发终局轮，该轮结束后分高者胜（同分比制成器物少者胜）。"
	)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	_modal_content.add_child(body)

	var close_btn := Button.new()
	close_btn.text = "知晓"
	UITheme.style_button(close_btn, Color("295439"), UITheme.AFFORD_GREEN)
	close_btn.pressed.connect(func() -> void: _modal_overlay.visible = false)
	_modal_content.add_child(close_btn)

func _show_player_detail_modal(p: PlayerState) -> void:
	_clear_modal()
	var title := Label.new()
	title.text = "%s 的百工藏品（总计 %d 声望）" % [p.name, p.get_score()]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	_modal_content.add_child(title)

	if not p.masters.is_empty():
		var m_names: Array[String] = []
		for m in p.masters:
			m_names.append("%s·%s(+%d)" % [m.name, m.title, m.prestige])
		var m_lbl := Label.new()
		m_lbl.text = "亲临名士：" + "、".join(m_names)
		m_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		m_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
		_modal_content.add_child(m_lbl)

	if p.purchased.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "尚未制成任何器物。"
		empty_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		_modal_content.add_child(empty_lbl)
	else:
		var list_lbl := RichTextLabel.new()
		list_lbl.custom_minimum_size = Vector2(420, 180)
		list_lbl.add_theme_font_size_override("normal_font_size", 13)
		list_lbl.add_theme_color_override("default_color", UITheme.TEXT_MAIN)
		var lines: Array[String] = []
		for c in p.purchased:
			var pt := " · +%d声望" % c.prestige if c.prestige > 0 else ""
			lines.append("· [%s] %s%s" % [GemTypes.gem_short(c.bonus), c.name, pt])
		list_lbl.text = "\n".join(lines)
		_modal_content.add_child(list_lbl)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	UITheme.style_button(close_btn)
	close_btn.pressed.connect(func() -> void: _modal_overlay.visible = false)
	_modal_content.add_child(close_btn)
