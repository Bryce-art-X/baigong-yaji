class_name CodexModal
extends ColorRect

const MASTER_LORE: Dictionary = {
	"m_01": "唐代茶圣，著《茶经》三卷，奠定中国茶道体系。",
	"m_02": "东晋画家，提出“以形写神”，《洛神赋图》传世。",
	"m_03": "春秋战国工匠鼻祖，木工百艺与器械发明之宗。",
	"m_04": "春秋琴师，擅鼓琴，与钟子期成“高山流水”知音典故。",
	"m_05": "春秋铸剑宗师，曾铸湛卢、龙渊、泰阿等名剑。",
	"m_06": "东晋书圣，兰亭雅集挥毫成《兰亭集序》天下第一行书。",
	"m_07": "北宋文豪，诗画茶禅俱精，常邀友西园雅集。",
	"m_08": "宋代词宗兼金石学者，著《金石录》收编三代钟鼎彝器。",
	"m_09": "明代科学家，撰《天工开物》详述百工造物之法。",
	"m_10": "宋代书画名家，嗜奇石如命，世称“米癫拜石”。",
}

const TIER_LORE: Dictionary = {
	1: "市井雅物 · 匠心初成之小品",
	2: "名匠精制 · 历代名窑巧工之器",
	3: "传世重器 · 镇馆典藏之瑰宝",
}

var _filter: String = "all" # all / t1 / t2 / t3 / masters
var _progress_lbl: Label
var _grid: GridContainer
var _tab_btns: Dictionary = {}

func _ready() -> void:
	color = Color(0, 0, 0, 0.78)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 620)
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.PANEL_BG, UITheme.GOLD_ACCENT, 12, 2))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	vbox.add_child(hdr)

	var title := Label.new()
	title.text = "《百工谱》图鉴"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UITheme.GOLD_ACCENT)
	hdr.add_child(title)

	_progress_lbl = Label.new()
	_progress_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_lbl.add_theme_font_size_override("font_size", 14)
	_progress_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	hdr.add_child(_progress_lbl)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(88, 36)
	UITheme.style_button(close_btn, Color("472422"), UITheme.SEAL_RED)
	close_btn.pressed.connect(func() -> void:
		SfxManager.play_click()
		visible = false
	)
	hdr.add_child(close_btn)

	# Filter tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs)

	for pair in [["all", "全部器物 (90)"], ["t1", "一阶 (40)"], ["t2", "二阶 (30)"], ["t3", "三阶 (20)"], ["masters", "名士雅客 (10)"]]:
		var key: String = pair[0]
		var b := Button.new()
		b.text = pair[1]
		b.custom_minimum_size = Vector2(110, 34)
		b.pressed.connect(func() -> void:
			_filter = key
			SfxManager.play_click()
			_refresh()
		)
		tabs.add_child(b)
		_tab_btns[key] = b

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)

func open_codex() -> void:
	visible = true
	_refresh()

func _refresh() -> void:
	for k in _tab_btns.keys():
		var active: bool = (k == _filter)
		UITheme.style_button(_tab_btns[k], Color("4F3B22") if active else Color("2A211C"), UITheme.GOLD_ACCENT if active else UITheme.GOLD_DIM)

	for c in _grid.get_children():
		c.queue_free()

	var codex := SaveManager.load_codex()
	var unlocked_cards: Array = codex.get("cards", [])
	var unlocked_masters: Array = codex.get("masters", [])
	_progress_lbl.text = "已收录器物 %d/90 · 结交名士 %d/10" % [unlocked_cards.size(), unlocked_masters.size()]

	var raw := RulesEngine.load_raw_data()
	if _filter == "masters":
		for m in raw.get("masters", []):
			var mid := str(m["id"])
			var got := unlocked_masters.has(mid)
			_add_entry_card(
				"%s·%s" % [str(m["name"]), str(m["title"])],
				"+%d 声望" % int(m["prestige"]),
				MASTER_LORE.get(mid, "历代风雅名士。"),
				got,
				UITheme.master_icon()
			)
		return

	var target_tier := 0
	if _filter == "t1": target_tier = 1
	elif _filter == "t2": target_tier = 2
	elif _filter == "t3": target_tier = 3

	for c in raw.get("cards", []):
		var tier := int(c["tier"])
		if target_tier > 0 and tier != target_tier:
			continue
		var cid := str(c["id"])
		var got := unlocked_cards.has(cid)
		var bonus := str(c["bonus"])
		var pt := int(c["prestige"])
		var sub := "%s · %s%s" % [["", "一阶", "二阶", "三阶"][tier], GemTypes.gem_name(bonus), (" · %d 声望" % pt) if pt > 0 else ""]
		_add_entry_card(str(c["name"]), sub, TIER_LORE.get(tier, ""), got, UITheme.gem_icon(bonus))

func _add_entry_card(title_text: String, sub_text: String, desc_text: String, unlocked: bool, tex: Texture2D) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color("2B211C") if unlocked else Color("1B1512"),
		UITheme.GOLD_ACCENT if unlocked else Color("42362E"),
		8, 1, 2
	))
	_grid.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color.WHITE if unlocked else Color(0.5, 0.5, 0.5, 0.45)
	hbox.add_child(icon)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	hbox.add_child(v)

	var t_lbl := Label.new()
	t_lbl.text = title_text + ("" if unlocked else "（未收录）")
	t_lbl.add_theme_font_size_override("font_size", 14)
	t_lbl.add_theme_color_override("font_color", UITheme.TEXT_MAIN if unlocked else UITheme.TEXT_MUTED)
	v.add_child(t_lbl)

	var s_lbl := Label.new()
	s_lbl.text = sub_text
	s_lbl.add_theme_font_size_override("font_size", 11)
	s_lbl.add_theme_color_override("font_color", UITheme.GOLD_ACCENT if unlocked else Color("6B5D51"))
	v.add_child(s_lbl)

	var d_lbl := Label.new()
	d_lbl.text = desc_text
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	d_lbl.add_theme_font_size_override("font_size", 11)
	d_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	v.add_child(d_lbl)
