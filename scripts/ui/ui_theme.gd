class_name UITheme
extends RefCounted

const BG_DARK := Color("140F0D")
const PANEL_BG := Color("201814")
const CARD_BG := Color("2B201B")
const CARD_HOVER := Color("3A2B23")
const GOLD_ACCENT := Color("DFB14B")
const GOLD_DIM := Color("7D622B")
const TEXT_MAIN := Color("F5ECD9")
const TEXT_MUTED := Color("B3A28E")
const SEAL_RED := Color("A6302E")
const AFFORD_GREEN := Color("4EC076")

static var _icon_cache: Dictionary = {}

static func gem_icon(gem: String) -> Texture2D:
	if _icon_cache.has(gem):
		return _icon_cache[gem]
	var path := "res://assets/svg/gem_%s.svg" % gem
	var tex: Texture2D = load(path)
	_icon_cache[gem] = tex
	return tex

static func master_icon() -> Texture2D:
	if _icon_cache.has("_master"):
		return _icon_cache["_master"]
	var tex: Texture2D = load("res://assets/svg/master_seal.svg")
	_icon_cache["_master"] = tex
	return tex

static func tier_bg_color(tier: int) -> Color:
	match tier:
		1: return Color("2B221C")
		2: return Color("22292A")
		3: return Color("2C1F26")
		_: return CARD_BG

static func make_panel_style(bg: Color = PANEL_BG, border: Color = GOLD_DIM, radius: int = 10, border_w: int = 2, shadow: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func make_button_style(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb

static func make_chip_style(gem: String, radius: int = 999, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GemTypes.gem_color(gem)
	sb.border_color = GOLD_ACCENT if gem == GemTypes.GOLD else Color("E8DEC8", 0.65)
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb

static func style_button(btn: Button, bg: Color = Color("382B23"), border: Color = GOLD_DIM) -> void:
	btn.add_theme_stylebox_override("normal", make_button_style(bg, border))
	btn.add_theme_stylebox_override("hover", make_button_style(bg.lightened(0.14), GOLD_ACCENT))
	btn.add_theme_stylebox_override("pressed", make_button_style(bg.darkened(0.15), GOLD_ACCENT))
	btn.add_theme_stylebox_override("disabled", make_button_style(Color("1E1815"), Color("42372F")))
	btn.add_theme_color_override("font_color", TEXT_MAIN)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color("6E6055"))
