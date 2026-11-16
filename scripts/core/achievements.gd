class_name Achievements
extends RefCounted

const PATH := "user://achievements.json"

const DEFINITIONS: Array[Dictionary] = [
	{"id": "first_win", "name": "初露锋芒", "desc": "赢得第 1 场雅集对局"},
	{"id": "beat_gm", "name": "宗师之敌", "desc": "在一场对局中击败「宗师 AI」"},
	{"id": "fast_win", "name": "神速巧工", "desc": "在 22 轮内赢得 15 声望标准对局"},
	{"id": "tier3_craft", "name": "传世瑰宝", "desc": "亲手打造 1 件三阶传世器物"},
	{"id": "multi_masters", "name": "群贤毕至", "desc": "单局吸引 2 位及以上名士亲临"},
	{"id": "high_score_18", "name": "名扬四海", "desc": "单局结算达到 18 点及以上声望"},
	{"id": "daily_win", "name": "日课精进", "desc": "在「每日雅集」中获胜"},
	{"id": "collector_20", "name": "小有所成", "desc": "《百工谱》收录达到 20 件器物"},
	{"id": "collector_50", "name": "博古通今", "desc": "《百工谱》收录达到 50 件器物"},
	{"id": "play_10", "name": "雅集常客", "desc": "累计完赛 10 场对局"},
]

static func load_unlocked() -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(PATH):
		return out
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		for item in parsed:
			out.append(str(item))
	return out

static func unlock(ach_id: String) -> bool:
	var unlocked := load_unlocked()
	if unlocked.has(ach_id):
		return false
	unlocked.append(ach_id)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(unlocked))
	return true

static func get_title(ach_id: String) -> String:
	for d in DEFINITIONS:
		if d["id"] == ach_id:
			return str(d["name"])
	return ach_id

static func evaluate_game_over(state: GameState, is_daily: bool = false) -> Array[String]:
	var newly: Array[String] = []
	var has_gm := false
	for p in state.players:
		if p.is_ai and p.ai_level >= 2:
			has_gm = true

	for p in state.players:
		if p.is_ai:
			continue
		var won := state.winner_indices.has(p.index)
		if won:
			if unlock("first_win"): newly.append("first_win")
			if has_gm and unlock("beat_gm"): newly.append("beat_gm")
			if state.target_prestige >= 15 and state.round_number <= 22 and unlock("fast_win"):
				newly.append("fast_win")
			if is_daily and unlock("daily_win"):
				newly.append("daily_win")
		if p.masters.size() >= 2 and unlock("multi_masters"):
			newly.append("multi_masters")
		if p.get_score() >= 18 and unlock("high_score_18"):
			newly.append("high_score_18")
		for c in p.purchased:
			if c.tier == 3 and unlock("tier3_craft"):
				newly.append("tier3_craft")
				break

	var stats := SaveManager.load_stats()
	if int(stats.get("games_played", 0)) >= 10 and unlock("play_10"):
		newly.append("play_10")

	var codex := SaveManager.load_codex()
	var c_cnt: int = codex.get("cards", []).size()
	if c_cnt >= 20 and unlock("collector_20"):
		newly.append("collector_20")
	if c_cnt >= 50 and unlock("collector_50"):
		newly.append("collector_50")

	return newly
