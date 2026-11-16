class_name FxLayer
extends Control
## Lightweight overlay for flying chips, floating prestige popups, and master
## visit banners. Respects Settings "anim_speed" (0 = off, 1 = normal, 2 = fast).

var _banner_panel: PanelContainer
var _banner_lbl: Label
var _banner_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_banner()

func _build_banner() -> void:
	_banner_panel = PanelContainer.new()
	_banner_panel.visible = false
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("2D1E17", 0.95), UITheme.GOLD_ACCENT, 10, 2, 10))
	add_child(_banner_panel)

	_banner_lbl = Label.new()
	_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_lbl.add_theme_font_size_override("font_size", 17)
	_banner_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	_banner_panel.add_child(_banner_lbl)

func _speed_scale() -> float:
	var spd := float(Settings.get_value("anim_speed"))
	if spd <= 0.01:
		return 0.0
	return 1.0 / spd

func fly_chip(gem: String, from_global: Vector2, to_global: Vector2, delay: float = 0.0) -> void:
	var sc := _speed_scale()
	if sc <= 0.0:
		return
	var icon := TextureRect.new()
	icon.texture = UITheme.gem_icon(gem)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.global_position = from_global - Vector2(16, 16)
	icon.modulate.a = 0.0 if delay > 0.0 else 1.0
	add_child(icon)

	var dur := 0.38 * sc
	var mid := (from_global + to_global) * 0.5 + Vector2(0, -48.0)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay * sc)
		tw.tween_property(icon, "modulate:a", 1.0, 0.04)
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(icon):
			return
		var a := from_global.lerp(mid, t)
		var b := mid.lerp(to_global, t)
		icon.global_position = a.lerp(b, t) - Vector2(16, 16)
		var s := lerpf(1.15, 0.72, t)
		icon.scale = Vector2(s, s)
	, 0.0, 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(icon.queue_free)

func fly_card(from_global: Vector2, to_global: Vector2, bonus_gem: String) -> void:
	var sc := _speed_scale()
	if sc <= 0.0:
		return
	var card_fx := PanelContainer.new()
	card_fx.custom_minimum_size = Vector2(84, 118)
	card_fx.size = Vector2(84, 118)
	card_fx.pivot_offset = Vector2(42, 59)
	card_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = GemTypes.gem_color(bonus_gem).darkened(0.45)
	sb.border_color = UITheme.GOLD_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	card_fx.add_theme_stylebox_override("panel", sb)
	var icon := TextureRect.new()
	icon.texture = UITheme.gem_icon(bonus_gem)
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_fx.add_child(icon)

	card_fx.global_position = from_global - Vector2(42, 59)
	add_child(card_fx)

	var dur := 0.42 * sc
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card_fx, "global_position", to_global - Vector2(42, 59), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(card_fx, "scale", Vector2(0.35, 0.35), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(card_fx, "rotation_degrees", 12.0, dur)
	tw.tween_property(card_fx, "modulate:a", 0.2, dur).set_delay(dur * 0.55)
	tw.set_parallel(false)
	tw.tween_callback(card_fx.queue_free)

func float_text(text: String, at_global: Vector2, color: Color = UITheme.GOLD_ACCENT) -> void:
	var sc := _speed_scale()
	if sc <= 0.0:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.global_position = at_global - Vector2(40, 14)
	add_child(lbl)

	var dur := 0.75 * sc
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 42.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, dur).set_delay(dur * 0.4)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

func show_banner(text: String) -> void:
	var sc := _speed_scale()
	if sc <= 0.0:
		return
	if _banner_tween != null and _banner_tween.is_running():
		_banner_tween.kill()
	_banner_lbl.text = text
	_banner_panel.visible = true
	_banner_panel.reset_size()
	var vw := size.x if size.x > 0 else 1440.0
	var bw := maxf(320.0, _banner_panel.size.x)
	_banner_panel.position = Vector2((vw - bw) * 0.5, 58.0)
	_banner_panel.modulate.a = 0.0

	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_panel, "modulate:a", 1.0, 0.18 * sc)
	_banner_tween.tween_interval(1.4 * sc)
	_banner_tween.tween_property(_banner_panel, "modulate:a", 0.0, 0.3 * sc)
	_banner_tween.tween_callback(func() -> void: _banner_panel.visible = false)

func pulse_control(ctrl: Control) -> void:
	var sc := _speed_scale()
	if sc <= 0.0 or not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	ctrl.scale = Vector2(0.86, 0.86)
	var tw := create_tween()
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.24 * sc).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func burst_gold(at_global: Vector2, count: int = 18) -> void:
	var sc := _speed_scale()
	if sc <= 0.0:
		return
	var p := CPUParticles2D.new()
	p.global_position = at_global
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = count
	p.lifetime = 0.65 * sc
	p.spread = 180.0
	p.gravity = Vector2(0, 140)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 210.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.5
	p.color = UITheme.GOLD_ACCENT
	add_child(p)
	get_tree().create_timer(0.8 * sc).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)
