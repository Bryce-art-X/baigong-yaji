class_name BoardView
extends Control

signal return_to_menu_requested
signal restart_requested
signal settings_requested

var _controller: GameController
var state: GameState
var _selected_gems: Array[String] = []
var _discard_pool: Dictionary = {}
var _stats_recorded: bool = false
var _is_tutorial: bool = false
var _is_daily: bool = false
var _tutorial_step: int = 0
var _last_human_idx: int = -1
var _ai_timer: Timer

# Selected card state (works identically for PC click & Mobile tap)
var _sel_card_source: String = "" # "" / "board" / "reserved"
var _sel_tier: int = 0
var _sel_slot: int = -1
var _sel_res_idx: int = -1

var _top_status_lbl: Label
var _undo_btn: Button
var _anim_btn: Button
var _sfx_btn: Button
var _player_panels: Array[PlayerPanel] = []
var _master_slots: Array[MasterView] = []
var _deck_btns: Dictionary = {} # tier -> Button
var _card_slots: Dictionary = {} # tier -> Array[CardView]
var _dashboard: PlayerDashboard
var _bank_slots: Dictionary = {} # gem -> {btn, sel_lbl, cnt_lbl}
var _selection_tray: HBoxContainer
var _selection_lbl: Label
var _confirm_take_btn: Button
var _clear_take_btn: Button
var _log_lbl: RichTextLabel

var _card_action_panel: PanelContainer
var _act_title_lbl: Label
var _act_breakdown_lbl: Label
var _act_buy_btn: Button
var _act_res_btn: Button

var _tutorial_bar: PanelContainer
var _tutorial_lbl: Label
var _fx: FxLayer
var _curtain_overlay: ColorRect
var _curtain_lbl: Label
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

func start_game(p_state: GameState, p_is_tutorial: bool = false, p_is_daily: bool = false) -> void:
	_controller = GameController.new(p_state)
	_controller.events_applied.connect(_on_events_applied)
	state = _controller.state
	_selected_gems.clear()
	_discard_pool.clear()
	_clear_card_selection()
	_stats_recorded = false
	_is_tutorial = p_is_tutorial
	_is_daily = p_is_daily
	_tutorial_step = 0
	if _tutorial_bar != null:
		_tutorial_bar.visible = _is_tutorial
	_last_human_idx = -1
	for p in state.players:
		if not p.is_ai:
			_last_human_idx = p.index
			break
	EventBus.game_started.emit(state)
	_refresh_all()
	_schedule_ai_if_needed()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or state == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z and event.ctrl_pressed:
			if _undo_btn != null and not _undo_btn.disabled:
				_on_undo_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if _confirm_take_btn != null and not _confirm_take_btn.disabled and not _modal_overlay.visible and not _curtain_overlay.visible:
				_on_confirm_take_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if _sel_card_source != "":
				_clear_card_selection()
				_refresh_board_and_dash()
				get_viewport().set_input_as_handled()
			elif _modal_overlay.visible and state.phase == GameState.TurnPhase.ACTION:
				_modal_overlay.visible = false
				get_viewport().set_input_as_handled()
			elif not _selected_gems.is_empty():
				_selected_gems.clear()
				_refresh_bank_and_selection()
				get_viewport().set_input_as_handled()

func _build_skeleton() -> void:
	var bg := TextureRect.new()
	bg.texture = UITheme.table_bg()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vig_sh: Shader = load("res://assets/shaders/table_vignette.gdshader")
	if vig_sh != null:
		var mat := ShaderMaterial.new()
		mat.shader = vig_sh
		bg.material = mat
	add_child(bg)

	var scrim := ColorRect.new()
	scrim.color = Color(0.05, 0.03, 0.02, 0.30)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)

	# Tutorial Guide Bar
	_tutorial_bar = PanelContainer.new()
	_tutorial_bar.visible = false
	_tutorial_bar.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("263628"), UITheme.AFFORD_GREEN, 8, 1, 2))
	main_vbox.add_child(_tutorial_bar)
	_tutorial_lbl = Label.new()
	_tutorial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_lbl.add_theme_font_size_override("font_size", 14)
	_tutorial_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	_tutorial_bar.add_child(_tutorial_lbl)

	# Top Bar
	var top_bar := PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.PANEL_BG, UITheme.GOLD_DIM, 8, 1))
	main_vbox.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "百工雅集"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	top_hbox.add_child(title_lbl)

	_top_status_lbl = Label.new()
	_top_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_status_lbl.add_theme_font_size_override("font_size", 14)
	_top_status_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	top_hbox.add_child(_top_status_lbl)

	_undo_btn = Button.new()
	_undo_btn.text = "悔棋"
	_undo_btn.disabled = true
	UITheme.style_button(_undo_btn)
	_undo_btn.pressed.connect(_on_undo_pressed)
	top_hbox.add_child(_undo_btn)

	_anim_btn = Button.new()
	UITheme.style_button(_anim_btn)
	_update_anim_btn_label()
	_anim_btn.pressed.connect(_on_cycle_anim_speed)
	top_hbox.add_child(_anim_btn)

	_sfx_btn = Button.new()
	_sfx_btn.text = "音效: 关" if SfxManager.muted else "音效: 开"
	UITheme.style_button(_sfx_btn)
	_sfx_btn.pressed.connect(func() -> void:
		Settings.set_value("sfx_enabled", SfxManager.muted)
		_sfx_btn.text = "音效: 关" if SfxManager.muted else "音效: 开"
		SfxManager.play_click()
	)
	top_hbox.add_child(_sfx_btn)

	var set_btn := Button.new()
	set_btn.text = "设置"
	UITheme.style_button(set_btn)
	set_btn.pressed.connect(func() -> void:
		SfxManager.play_click()
		settings_requested.emit()
	)
	top_hbox.add_child(set_btn)

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
	body.add_theme_constant_override("separation", 10)
	main_vbox.add_child(body)

	# Left: Floating Player Plaques + Action Log below
	var left_v := VBoxContainer.new()
	left_v.custom_minimum_size = Vector2(222, 0)
	left_v.add_theme_constant_override("separation", 6)
	body.add_child(left_v)

	for _i in range(4):
		var pp := PlayerPanel.new()
		pp.visible = false
		pp.detail_requested.connect(func(idx: int) -> void:
			if state != null and idx >= 0 and idx < state.players.size():
				_show_player_detail_modal(state.players[idx])
		)
		left_v.add_child(pp)
		_player_panels.append(pp)

	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("16100D", 0.72), Color("4E3D28", 0.55), 8, 1, 2))
	left_v.add_child(log_panel)

	var log_v := VBoxContainer.new()
	log_v.add_theme_constant_override("separation", 4)
	log_panel.add_child(log_v)

	var log_hdr := Label.new()
	log_hdr.text = "雅集纪要"
	log_hdr.add_theme_font_size_override("font_size", 13)
	log_hdr.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	log_v.add_child(log_hdr)

	_log_lbl = RichTextLabel.new()
	_log_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_lbl.scroll_following = true
	_log_lbl.add_theme_font_size_override("normal_font_size", 11)
	_log_lbl.add_theme_color_override("default_color", UITheme.TEXT_MUTED)
	log_v.add_child(_log_lbl)

	# Center: Masters + 3x4 Cards + Touch/PC Action Popover + 3-Zone PlayerDashboard
	var center_v := VBoxContainer.new()
	center_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_v.add_theme_constant_override("separation", 6)
	body.add_child(center_v)

	var masters_row := HBoxContainer.new()
	masters_row.alignment = BoxContainer.ALIGNMENT_CENTER
	masters_row.add_theme_constant_override("separation", 10)
	center_v.add_child(masters_row)

	for _i in range(5):
		var mv := MasterView.new()
		mv.visible = false
		masters_row.add_child(mv)
		_master_slots.append(mv)

	var tiers_center := CenterContainer.new()
	tiers_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_v.add_child(tiers_center)

	var tiers_box := VBoxContainer.new()
	tiers_box.add_theme_constant_override("separation", 8)
	tiers_center.add_child(tiers_box)

	for tier in [3, 2, 1]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		tiers_box.add_child(row)

		var deck_btn := Button.new()
		deck_btn.custom_minimum_size = Vector2(110, 154)
		deck_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		deck_btn.pressed.connect(func() -> void: _on_reserve_deck(tier))
		var pat := TextureRect.new()
		pat.texture = UITheme.card_pattern(tier)
		pat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pat.stretch_mode = TextureRect.STRETCH_SCALE
		pat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_btn.add_child(pat)
		row.add_child(deck_btn)
		_deck_btns[tier] = deck_btn

		_card_slots[tier] = []
		for _slot in range(4):
			var cv := CardView.new()
			cv.card_tapped.connect(_on_board_card_tapped)
			row.add_child(cv)
			_card_slots[tier].append(cv)

	# Bottom: 3-Zone Player Dashboard
	_dashboard = PlayerDashboard.new()
	_dashboard.reserved_card_tapped.connect(_on_reserved_card_tapped)
	_dashboard.inspect_requested.connect(func(idx: int) -> void:
		if state != null and idx >= 0 and idx < state.players.size():
			_show_player_detail_modal(state.players[idx])
	)
	center_v.add_child(_dashboard)

	# Right: Physical Round Chip Tray
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(204, 0)
	right_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("17110E", 0.72), Color("5C4828", 0.5), 10, 1))
	body.add_child(right_panel)

	var right_v := VBoxContainer.new()
	right_v.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_v)

	var bank_hdr := Label.new()
	bank_hdr.text = "库房玉石（点击拿取）"
	bank_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bank_hdr.add_theme_font_size_override("font_size", 14)
	bank_hdr.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	right_v.add_child(bank_hdr)

	var bank_grid := GridContainer.new()
	bank_grid.columns = 2
	bank_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bank_grid.add_theme_constant_override("h_separation", 12)
	bank_grid.add_theme_constant_override("v_separation", 10)
	right_v.add_child(bank_grid)

	for g in GemTypes.ALL_GEMS:
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 2)
		bank_grid.add_child(cell)

		var chip_btn := Button.new()
		chip_btn.custom_minimum_size = Vector2(68, 68)
		chip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		chip_btn.pressed.connect(func() -> void: _on_bank_gem_clicked(g))
		cell.add_child(chip_btn)

		var icon := TextureRect.new()
		icon.texture = UITheme.gem_icon(g)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.offset_left = -22
		icon.offset_top = -22
		icon.offset_right = 22
		icon.offset_bottom = 22
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_btn.add_child(icon)

		var sel_lbl := Label.new()
		sel_lbl.visible = false
		sel_lbl.position = Vector2(42, 2)
		sel_lbl.size = Vector2(26, 22)
		sel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sel_lbl.add_theme_font_size_override("font_size", 14)
		sel_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
		sel_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		sel_lbl.add_theme_constant_override("shadow_offset_x", 1)
		sel_lbl.add_theme_constant_override("shadow_offset_y", 1)
		sel_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_btn.add_child(sel_lbl)

		var cnt_lbl := Label.new()
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt_lbl.add_theme_font_size_override("font_size", 12)
		cell.add_child(cnt_lbl)

		_bank_slots[g] = {"btn": chip_btn, "sel_lbl": sel_lbl, "cnt_lbl": cnt_lbl}

	_selection_tray = HBoxContainer.new()
	_selection_tray.alignment = BoxContainer.ALIGNMENT_CENTER
	_selection_tray.custom_minimum_size = Vector2(0, 32)
	_selection_tray.add_theme_constant_override("separation", 8)
	right_v.add_child(_selection_tray)

	_selection_lbl = Label.new()
	_selection_lbl.text = "点击玉石：拿 3 异色或 2 同色"
	_selection_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_selection_lbl.add_theme_font_size_override("font_size", 12)
	_selection_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	right_v.add_child(_selection_lbl)

	var sel_btns := HBoxContainer.new()
	sel_btns.add_theme_constant_override("separation", 6)
	right_v.add_child(sel_btns)

	_confirm_take_btn = Button.new()
	_confirm_take_btn.text = "确认拿取"
	_confirm_take_btn.custom_minimum_size = Vector2(0, 44)
	_confirm_take_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(_confirm_take_btn, Color("295439"), UITheme.AFFORD_GREEN)
	_confirm_take_btn.pressed.connect(_on_confirm_take_pressed)
	sel_btns.add_child(_confirm_take_btn)

	_clear_take_btn = Button.new()
	_clear_take_btn.text = "清空"
	_clear_take_btn.custom_minimum_size = Vector2(64, 44)
	UITheme.style_button(_clear_take_btn)
	_clear_take_btn.pressed.connect(func() -> void:
		_selected_gems.clear()
		_refresh_bank_and_selection()
	)
	sel_btns.add_child(_clear_take_btn)

	# FX Overlay
	_fx = FxLayer.new()
	add_child(_fx)

	# Floating Unified PC/Mobile Card Action & Payment Breakdown Bar (anchored above dashboard)
	_card_action_panel = PanelContainer.new()
	_card_action_panel.visible = false
	_card_action_panel.anchor_left = 0.5
	_card_action_panel.anchor_right = 0.5
	_card_action_panel.anchor_top = 1.0
	_card_action_panel.anchor_bottom = 1.0
	_card_action_panel.offset_left = -360.0
	_card_action_panel.offset_right = 360.0
	_card_action_panel.offset_top = -234.0
	_card_action_panel.offset_bottom = -158.0
	_card_action_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("221813", 0.97), UITheme.GOLD_ACCENT, 12, 2, 14))
	add_child(_card_action_panel)

	var act_hbox := HBoxContainer.new()
	act_hbox.add_theme_constant_override("separation", 12)
	_card_action_panel.add_child(act_hbox)

	var act_info_v := VBoxContainer.new()
	act_info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_info_v.alignment = BoxContainer.ALIGNMENT_CENTER
	act_info_v.add_theme_constant_override("separation", 2)
	act_hbox.add_child(act_info_v)

	_act_title_lbl = Label.new()
	_act_title_lbl.add_theme_font_size_override("font_size", 15)
	_act_title_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	act_info_v.add_child(_act_title_lbl)

	_act_breakdown_lbl = Label.new()
	_act_breakdown_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_act_breakdown_lbl.add_theme_font_size_override("font_size", 12)
	_act_breakdown_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	act_info_v.add_child(_act_breakdown_lbl)

	_act_buy_btn = Button.new()
	_act_buy_btn.text = "打造入库"
	_act_buy_btn.custom_minimum_size = Vector2(110, 44)
	_act_buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_act_buy_btn.pressed.connect(_on_action_buy_pressed)
	act_hbox.add_child(_act_buy_btn)

	_act_res_btn = Button.new()
	_act_res_btn.text = "留存 (+1赤金)"
	_act_res_btn.custom_minimum_size = Vector2(120, 44)
	_act_res_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_act_res_btn.pressed.connect(_on_action_reserve_pressed)
	act_hbox.add_child(_act_res_btn)

	var act_cancel := Button.new()
	act_cancel.text = "取消"
	act_cancel.custom_minimum_size = Vector2(64, 44)
	act_cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.style_button(act_cancel)
	act_cancel.pressed.connect(func() -> void:
		_clear_card_selection()
		_refresh_board_and_dash()
	)
	act_hbox.add_child(act_cancel)

	# Hot-seat privacy curtain
	_curtain_overlay = ColorRect.new()
	_curtain_overlay.color = Color("120D0B", 0.96)
	_curtain_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain_overlay.visible = false
	add_child(_curtain_overlay)

	var curtain_center := CenterContainer.new()
	curtain_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain_overlay.add_child(curtain_center)

	var curtain_panel := PanelContainer.new()
	curtain_panel.custom_minimum_size = Vector2(380, 190)
	curtain_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("241B17"), UITheme.GOLD_ACCENT, 12, 2))
	curtain_center.add_child(curtain_panel)

	var curtain_v := VBoxContainer.new()
	curtain_v.alignment = BoxContainer.ALIGNMENT_CENTER
	curtain_v.add_theme_constant_override("separation", 16)
	curtain_panel.add_child(curtain_v)

	_curtain_lbl = Label.new()
	_curtain_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_curtain_lbl.add_theme_font_size_override("font_size", 20)
	_curtain_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	curtain_v.add_child(_curtain_lbl)

	var curtain_btn := Button.new()
	curtain_btn.text = "准备好了"
	curtain_btn.custom_minimum_size = Vector2(160, 44)
	curtain_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.style_button(curtain_btn, Color("295439"), UITheme.AFFORD_GREEN)
	curtain_btn.pressed.connect(func() -> void:
		_curtain_overlay.visible = false
		SfxManager.play_click()
	)
	curtain_v.add_child(curtain_btn)

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

func _human_count() -> int:
	var n := 0
	for p in state.players:
		if not p.is_ai:
			n += 1
	return n

func _update_anim_btn_label() -> void:
	var spd := float(Settings.get_value("anim_speed"))
	if spd <= 0.01:
		_anim_btn.text = "动画: 关"
	elif spd >= 1.5:
		_anim_btn.text = "动画: 快"
	else:
		_anim_btn.text = "动画: 正常"

func _on_cycle_anim_speed() -> void:
	var spd := float(Settings.get_value("anim_speed"))
	var next := 2.0 if (spd > 0.5 and spd < 1.5) else (0.0 if spd >= 1.5 else 1.0)
	Settings.set_value("anim_speed", next)
	_update_anim_btn_label()
	SfxManager.play_click()

func _clear_card_selection() -> void:
	_sel_card_source = ""
	_sel_tier = 0
	_sel_slot = -1
	_sel_res_idx = -1
	if _card_action_panel != null:
		_card_action_panel.visible = false

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
	_refresh_board_and_dash()
	_refresh_bank_and_selection()
	_refresh_log()
	_refresh_tutorial_bar()

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
		if _human_count() >= 2 and cur.index != _last_human_idx:
			_last_human_idx = cur.index
			_curtain_lbl.text = "请将设备交给「%s」" % cur.name
			_curtain_overlay.visible = true

	if state.phase == GameState.TurnPhase.DISCARD_CHIPS and not cur.is_ai:
		_show_discard_modal()
	elif state.phase == GameState.TurnPhase.CHOOSE_MASTER and not cur.is_ai:
		_show_choose_master_modal()
	elif state.phase == GameState.TurnPhase.GAME_OVER:
		if not _stats_recorded:
			_stats_recorded = true
			SaveManager.record_game_result(state)
			if _is_daily:
				var human_won := false
				var human_sc := 0
				for p in state.players:
					if not p.is_ai:
						human_sc = maxi(human_sc, p.get_score())
						if state.winner_indices.has(p.index):
							human_won = true
				SaveManager.record_daily_result(human_won, human_sc, state.round_number)
			var newly_ach := Achievements.evaluate_game_over(state, _is_daily)
			if not newly_ach.is_empty() and _fx != null:
				var ach_names: Array[String] = []
				for aid in newly_ach:
					ach_names.append("「%s」" % Achievements.get_title(aid))
				_fx.show_banner("解锁成就：" + " ".join(ach_names))
			SaveManager.clear_autosave()
			SfxManager.play_victory()
		_show_game_over_modal()
	else:
		_modal_overlay.visible = false

func _refresh_players() -> void:
	for i in range(_player_panels.size()):
		var pp := _player_panels[i]
		if i < state.players.size():
			pp.visible = true
			var is_cur := (i == state.current_player_idx) and (state.phase != GameState.TurnPhase.GAME_OVER)
			pp.update_player(state.players[i], is_cur)
		else:
			pp.visible = false

func _refresh_masters() -> void:
	var viewer := _active_human_viewer()
	for i in range(_master_slots.size()):
		var mv := _master_slots[i]
		if i < state.masters.size():
			mv.visible = true
			mv.setup(state.masters[i], false, viewer)
		else:
			mv.visible = false

func _refresh_board_and_dash() -> void:
	var human_turn := _is_human_turn()
	var viewer := _active_human_viewer()

	for tier in [3, 2, 1]:
		var deck_btn: Button = _deck_btns[tier]
		var rem: int = state.decks[tier].size()
		deck_btn.text = "%s\n\n· %d ·" % [["", "壹", "贰", "叁"][tier], rem]
		deck_btn.disabled = not (human_turn and rem > 0 and viewer.reserved.size() < GameState.MAX_RESERVED)
		var deck_sb := StyleBoxFlat.new()
		deck_sb.bg_color = UITheme.tier_bg_color(tier).darkened(0.15)
		deck_sb.border_color = Color("C8B288", 0.55)
		deck_sb.set_border_width_all(2)
		deck_sb.border_width_bottom = 6
		deck_sb.border_width_right = 4
		deck_sb.set_corner_radius_all(9)
		deck_sb.shadow_color = Color(0, 0, 0, 0.65)
		deck_sb.shadow_size = 8
		deck_sb.shadow_offset = Vector2(4, 6)
		deck_btn.add_theme_stylebox_override("normal", deck_sb)
		deck_btn.add_theme_stylebox_override("hover", deck_sb)
		deck_btn.add_theme_stylebox_override("pressed", deck_sb)
		deck_btn.add_theme_stylebox_override("disabled", deck_sb)
		deck_btn.add_theme_font_size_override("font_size", 18)
		deck_btn.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
		deck_btn.add_theme_color_override("font_disabled_color", UITheme.TEXT_MUTED)

		var slots: Array = _card_slots[tier]
		for slot in range(4):
			var cv: CardView = slots[slot]
			var is_sel: bool = (_sel_card_source == "board" and int(_sel_tier) == int(tier) and _sel_slot == slot)
			cv.setup_board_card(state.board[tier][slot], tier, slot, viewer, human_turn, is_sel)

	var sel_res := _sel_res_idx if _sel_card_source == "reserved" else -1
	_dashboard.update_dashboard(viewer, human_turn, sel_res)
	_refresh_card_action_panel(viewer, human_turn)

func _active_human_viewer() -> PlayerState:
	var cur := state.current_player()
	if not cur.is_ai:
		return cur
	for p in state.players:
		if not p.is_ai:
			return p
	return cur

func _on_board_card_tapped(cv: CardView) -> void:
	if cv.card == null or not _is_human_turn():
		return
	if _sel_card_source == "board" and _sel_tier == cv.tier and _sel_slot == cv.slot:
		_clear_card_selection()
	else:
		_sel_card_source = "board"
		_sel_tier = cv.tier
		_sel_slot = cv.slot
		_sel_res_idx = -1
	_refresh_board_and_dash()
	if _card_action_panel.visible and float(Settings.get_value("anim_speed")) > 0.01:
		TweenFX.pop_in(_card_action_panel, 0.18)

func _on_reserved_card_tapped(cv: CardView, res_idx: int) -> void:
	if cv.card == null or not _is_human_turn():
		return
	if _sel_card_source == "reserved" and _sel_res_idx == res_idx:
		_clear_card_selection()
	else:
		_sel_card_source = "reserved"
		_sel_tier = cv.tier
		_sel_slot = -1
		_sel_res_idx = res_idx
	_refresh_board_and_dash()
	if _card_action_panel.visible and float(Settings.get_value("anim_speed")) > 0.01:
		TweenFX.pop_in(_card_action_panel, 0.18)

func _refresh_card_action_panel(viewer: PlayerState, human_turn: bool) -> void:
	if _sel_card_source == "" or not human_turn:
		_card_action_panel.visible = false
		return

	var card: CardData.CraftCard = null
	if _sel_card_source == "board" and state.board.has(_sel_tier) and _sel_slot >= 0 and _sel_slot < 4:
		card = state.board[_sel_tier][_sel_slot]
	elif _sel_card_source == "reserved" and _sel_res_idx >= 0 and _sel_res_idx < viewer.reserved.size():
		card = viewer.reserved[_sel_res_idx]

	if card == null:
		_clear_card_selection()
		return

	_card_action_panel.visible = true
	var tier_names := ["", "一阶·源地", "二阶·商坊", "三阶·殿堂"]
	var pt_str := " · +%d 声望" % card.prestige if card.prestige > 0 else ""
	_act_title_lbl.text = "「%s」（%s · 产出 %s%s）" % [card.name, tier_names[card.tier], GemTypes.gem_name(card.bonus), pt_str]

	var pay := viewer.compute_payment(card)
	var sf: Dictionary = pay["shortfall"]
	var parts: Array[String] = []
	for g in GemTypes.BASE_GEMS:
		var raw_c := int(card.cost.get(g, 0))
		if raw_c == 0:
			continue
		var disc := int(viewer.discounts.get(g, 0))
		var after_d := maxi(0, raw_c - disc)
		var miss := int(sf.get(g, 0))
		if miss == 0:
			parts.append("%s %d(减%d) ✓" % [GemTypes.gem_short(g), raw_c, mini(raw_c, disc)])
		else:
			parts.append("%s 缺%d(需%d减%d有%d)" % [GemTypes.gem_short(g), miss, raw_c, disc, int(viewer.chips[g])])

	var gn := int(pay["gold_needed"])
	var gs := int(pay["gold_shortage"])
	var summary := ""
	if bool(pay["valid"]):
		summary = "可打造！" if gn == 0 else ("需用赤金 ×%d 补齐，可打造！" % gn)
	else:
		summary = "尚缺 %d 枚（赤金不足）" % gs
	_act_breakdown_lbl.text = "费用检定：" + " | ".join(parts) + "  →  " + summary

	_act_buy_btn.disabled = not bool(pay["valid"])
	UITheme.style_button(_act_buy_btn, Color("295439") if bool(pay["valid"]) else Color("2A211C"), UITheme.AFFORD_GREEN if bool(pay["valid"]) else UITheme.GOLD_DIM)

	_act_res_btn.visible = (_sel_card_source == "board")
	var can_res := viewer.reserved.size() < GameState.MAX_RESERVED
	_act_res_btn.disabled = not can_res
	UITheme.style_button(_act_res_btn, Color("473522"), UITheme.GOLD_ACCENT if can_res else UITheme.GOLD_DIM)

func _on_action_buy_pressed() -> void:
	if _sel_card_source == "board":
		_on_buy_requested(_sel_tier, _sel_slot, -1)
	elif _sel_card_source == "reserved":
		_on_buy_requested(_sel_tier, -1, _sel_res_idx)

func _on_action_reserve_pressed() -> void:
	if _sel_card_source == "board":
		_on_reserve_board(_sel_tier, _sel_slot)

func _refresh_bank_and_selection() -> void:
	var human_turn := _is_human_turn()

	for g in GemTypes.ALL_GEMS:
		var slot_d: Dictionary = _bank_slots[g]
		var chip_btn: Button = slot_d["btn"]
		var sel_lbl: Label = slot_d["sel_lbl"]
		var cnt_lbl: Label = slot_d["cnt_lbl"]
		var amt := int(state.bank[g])
		var sel_cnt: int = _selected_gems.count(g)
		var can_pick := (g != GemTypes.GOLD) and human_turn and _can_add_to_selection(g)

		chip_btn.disabled = (g == GemTypes.GOLD) or (not can_pick and sel_cnt == 0)
		var chip_sb := StyleBoxFlat.new()
		chip_sb.bg_color = GemTypes.gem_color(g).darkened(0.45) if sel_cnt == 0 else GemTypes.gem_color(g).darkened(0.18)
		chip_sb.border_color = UITheme.GOLD_ACCENT if sel_cnt > 0 else Color("E8DEC8", 0.55)
		chip_sb.set_border_width_all(3 if sel_cnt > 0 else 2)
		chip_sb.set_corner_radius_all(999)
		chip_sb.shadow_color = Color(0, 0, 0, 0.55)
		chip_sb.shadow_size = 6
		chip_sb.shadow_offset = Vector2(2, 4)
		var hover_sb := chip_sb.duplicate() as StyleBoxFlat
		hover_sb.border_color = UITheme.GOLD_ACCENT
		hover_sb.bg_color = chip_sb.bg_color.lightened(0.12)
		chip_btn.add_theme_stylebox_override("normal", chip_sb)
		chip_btn.add_theme_stylebox_override("hover", hover_sb)
		chip_btn.add_theme_stylebox_override("pressed", chip_sb)
		chip_btn.add_theme_stylebox_override("disabled", chip_sb)

		sel_lbl.visible = sel_cnt > 0
		if sel_cnt > 0:
			sel_lbl.text = "+%d" % sel_cnt
		cnt_lbl.text = "%s ×%d" % [GemTypes.gem_name(g), amt]
		cnt_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED if g == GemTypes.GOLD else UITheme.TEXT_MAIN)

	for c in _selection_tray.get_children():
		c.queue_free()

	if _selected_gems.is_empty():
		_selection_lbl.text = "点击玉石：拿 3 异色，或双击同种（≥4）"
		_confirm_take_btn.disabled = true
	else:
		for g in _selected_gems:
			var tr := TextureRect.new()
			tr.texture = UITheme.gem_icon(g)
			tr.custom_minimum_size = Vector2(28, 28)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_selection_tray.add_child(tr)
		_selection_lbl.text = "待拿取 %d 枚材料" % _selected_gems.size()
		_confirm_take_btn.disabled = not (human_turn and _is_selection_valid())

func _on_bank_gem_clicked(g: String) -> void:
	if not _is_human_turn() or g == GemTypes.GOLD:
		return
	var chip_btn: Button = _bank_slots[g]["btn"]
	if _can_add_to_selection(g):
		_selected_gems.append(g)
		SfxManager.play_click()
		if float(Settings.get_value("anim_speed")) > 0.01:
			TweenFX.punch_in(chip_btn, 0.20, 0.10)
		_refresh_bank_and_selection()
	elif _selected_gems.has(g):
		_selected_gems.erase(g)
		SfxManager.play_click()
		_refresh_bank_and_selection()

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
			return false
		return not _selected_gems.has(g)
	return false

func _is_selection_valid() -> bool:
	if _selected_gems.size() == 2 and _selected_gems[0] == _selected_gems[1]:
		return bool(RulesEngine.can_take_two_same(state, _selected_gems[0])["ok"])
	return bool(RulesEngine.can_take_different(state, _selected_gems)["ok"])

func _on_events_applied(_action: GameAction, evs: Array) -> void:
	EventBus.game_events.emit(evs)
	if _fx == null:
		return
	var anim_on := float(Settings.get_value("anim_speed")) > 0.01
	for ev in evs:
		match str(ev.get("type", "")):
			"take":
				var pi := int(ev.get("player", 0))
				if _is_tutorial and not state.players[pi].is_ai and _tutorial_step == 0:
					_tutorial_step = 1
				var gems: Dictionary = ev.get("gems", {})
				var delay := 0.0
				for g in gems.keys():
					var target_pos := _dashboard.get_chip_center(str(g)) if not state.players[pi].is_ai else _player_center(pi)
					for _k in range(int(gems[g])):
						_fx.fly_chip(str(g), _bank_center(str(g)), target_pos, delay)
						delay += 0.07
			"reserve":
				var pi := int(ev.get("player", 0))
				if _is_tutorial and not state.players[pi].is_ai and _tutorial_step <= 1:
					_tutorial_step = 2
				if bool(ev.get("gold", false)):
					var target_pos := _dashboard.get_chip_center(GemTypes.GOLD) if not state.players[pi].is_ai else _player_center(pi)
					_fx.fly_chip(GemTypes.GOLD, _bank_center(GemTypes.GOLD), target_pos, 0.0)
			"buy":
				var pi := int(ev.get("player", 0))
				if not state.players[pi].is_ai:
					SaveManager.unlock_codex_entry("cards", str(ev.get("card_id", "")))
					if _is_tutorial and _tutorial_step <= 2:
						_tutorial_step = 3
				var bonus_g := ""
				var card_tier := 1
				for c in state.players[pi].purchased:
					if c.id == str(ev.get("card_id", "")):
						bonus_g = c.bonus
						card_tier = c.tier
						break
				var target_pos := _dashboard.get_stack_center(bonus_g) if (not state.players[pi].is_ai and bonus_g != "") else _player_center(pi)
				if str(ev.get("from", "")) == "board":
					var t := int(ev.get("tier", 1))
					var s := int(ev.get("slot", 0))
					if bonus_g != "":
						_fx.fly_card(_card_center(t, s), target_pos, bonus_g)
				var pay: Dictionary = ev.get("payment", {})
				var delay := 0.0
				for g in pay.keys():
					var from_pos := _dashboard.get_chip_center(str(g)) if not state.players[pi].is_ai else _player_center(pi)
					for _k in range(int(pay[g])):
						_fx.fly_chip(str(g), from_pos, _bank_center(str(g)), delay)
						delay += 0.04
				var pts := int(ev.get("prestige", 0))
				_fx.burst_gold(target_pos, 24 if pts > 0 else 12)
				if anim_on and card_tier >= 3:
					TweenFX.shake(self, 0.22, 4.0)
				if pts > 0:
					_fx.float_text("+%d 声望" % pts, target_pos, UITheme.GOLD_ACCENT)
			"refill":
				var tier := int(ev.get("tier", 1))
				var slot := int(ev.get("slot", 0))
				if _card_slots.has(tier) and slot >= 0 and slot < 4 and anim_on:
					TweenFX.pop_in(_card_slots[tier][slot], 0.26)
			"master":
				var pi := int(ev.get("player", 0))
				var mid := str(ev.get("master_id", ""))
				if not state.players[pi].is_ai:
					SaveManager.unlock_codex_entry("masters", mid)
				var m_name := ""
				for m in state.players[pi].masters:
					if m.id == mid:
						m_name = "%s·%s" % [m.name, m.title]
						break
				_fx.burst_gold(_player_center(pi), 30)
				if anim_on:
					TweenFX.shake(self, 0.25, 5.0)
				_fx.show_banner("名士「%s」亲临 %s 的雅集 (+%d 声望)" % [m_name, state.players[pi].name, int(ev.get("prestige", 3))])
			"final_round":
				_fx.show_banner("【终局钟鸣】%s 率先达到 %d 声望，本轮结束后结算！" % [state.players[int(ev["player"])].name, int(ev["score"])])

func _player_center(idx: int) -> Vector2:
	if idx >= 0 and idx < _player_panels.size() and _player_panels[idx].visible:
		var p := _player_panels[idx]
		return p.global_position + p.size * 0.5
	return Vector2(140, 200)

func _bank_center(gem: String) -> Vector2:
	if _bank_slots.has(gem):
		var b: Button = _bank_slots[gem]["btn"]
		return b.global_position + b.size * 0.5
	return Vector2(1260, 260)

func _card_center(tier: int, slot: int) -> Vector2:
	if _card_slots.has(tier) and slot >= 0 and slot < _card_slots[tier].size():
		var cv: CardView = _card_slots[tier][slot]
		return cv.global_position + cv.size * 0.5
	return Vector2(720, 450)

func _on_undo_pressed() -> void:
	if _controller == null:
		return
	_ai_timer.stop()
	if _controller.undo_last_human_action():
		state = _controller.state
		_selected_gems.clear()
		_discard_pool.clear()
		_clear_card_selection()
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
		_clear_card_selection()
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
		_clear_card_selection()
		SfxManager.play_buy(card_prestige)
		if state.players[state.current_player_idx].masters.size() > prev_masters:
			SfxManager.play_master()
		_after_player_move()

func _on_reserve_board(tier: int, slot: int) -> void:
	var res := _controller.apply(GameAction.reserve_board(tier, slot))
	if bool(res["ok"]):
		_selected_gems.clear()
		_clear_card_selection()
		SfxManager.play_reserve()
		_after_player_move()

func _on_reserve_deck(tier: int) -> void:
	var res := _controller.apply(GameAction.reserve_deck(tier))
	if bool(res["ok"]):
		_selected_gems.clear()
		_clear_card_selection()
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
		var prev_hist := state.history.size()
		AIAgent.take_turn_step(state)
		if state.history.size() > prev_hist:
			var act := GameAction.from_dict(state.history.back())
			var evs: Array = []
			match act.type:
				GameAction.Type.TAKE_DIFFERENT:
					var g_map := {}
					for g in act.params.get("gems", []):
						g_map[g] = 1
					evs.append({"type": "take", "player": act.player, "gems": g_map})
					SfxManager.play_take_chip(g_map.size())
				GameAction.Type.TAKE_TWO:
					evs.append({"type": "take", "player": act.player, "gems": {str(act.params.get("gem", "")): 2}})
					SfxManager.play_take_chip(2)
				GameAction.Type.BUY_BOARD:
					evs.append({"type": "refill", "tier": int(act.params["tier"]), "slot": int(act.params["slot"])})
					SfxManager.play_buy(1)
				GameAction.Type.BUY_RESERVED:
					SfxManager.play_buy(1)
				GameAction.Type.RESERVE_BOARD, GameAction.Type.RESERVE_DECK:
					SfxManager.play_reserve()
			_on_events_applied(act, evs)
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
	if float(Settings.get_value("anim_speed")) > 0.01:
		TweenFX.pop_in(_modal_panel, 0.22)

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
		minus_b.custom_minimum_size = Vector2(36, 32)
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
		plus_b.custom_minimum_size = Vector2(36, 32)
		plus_b.disabled = ret >= owned or chosen_sum >= excess
		UITheme.style_button(plus_b)
		plus_b.pressed.connect(func() -> void:
			_discard_pool[g] += 1
			_show_discard_modal()
		)
		row.add_child(plus_b)

	var ok_btn := Button.new()
	ok_btn.text = "确认归还"
	ok_btn.custom_minimum_size = Vector2(0, 40)
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
	replay_btn.custom_minimum_size = Vector2(120, 40)
	UITheme.style_button(replay_btn, Color("295439"), UITheme.AFFORD_GREEN)
	replay_btn.pressed.connect(func() -> void:
		_modal_overlay.visible = false
		restart_requested.emit()
	)
	btns.add_child(replay_btn)

	var menu_btn := Button.new()
	menu_btn.text = "返回主阁"
	menu_btn.custom_minimum_size = Vector2(120, 40)
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
		+ "4. 任意匠师达到目标声望（默认 15 分）触发终局轮，该轮结束后分高者胜（同分比制成器物少者胜）。\n"
		+ "5. 操作：点击任意卡牌即可查看详细费用拆解并选择「打造」或「留存」，PC/手机触控一致。"
	)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	_modal_content.add_child(body)

	var close_btn := Button.new()
	close_btn.text = "知晓"
	close_btn.custom_minimum_size = Vector2(120, 38)
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
	close_btn.custom_minimum_size = Vector2(120, 38)
	UITheme.style_button(close_btn)
	close_btn.pressed.connect(func() -> void: _modal_overlay.visible = false)
	_modal_content.add_child(close_btn)

func _refresh_tutorial_bar() -> void:
	if _tutorial_bar == null or not _is_tutorial:
		return
	var tips: Array[String] = [
		"【新手引导 1/4】请先点击右侧「库房玉石」选取 3 种不同材料，再点击「确认拿取」。",
		"【新手引导 2/4】点击展示区任意一张图谱，在下方弹出条点击「留存 (+1赤金)」，锁定图谱并获赠赤金。",
		"【新手引导 3/4】绿色边框带「可造」印章的器物表示材料充足！点击它再点「打造入库」即可获得永久折扣。",
		"【新手引导 4/4】继续采材打造并堆叠 5 色折扣柱，率先达到 6 声望即可完成雅集试炼！",
	]
	_tutorial_lbl.text = tips[clampi(_tutorial_step, 0, tips.size() - 1)]
