class_name SaveManager
extends RefCounted

const AUTOSAVE_PATH := "user://autosave.json"
const STATS_PATH := "user://stats.json"
const CODEX_PATH := "user://codex.json"
const DAILY_PATH := "user://daily.json"

static func _card_to_dict(c: CardData.CraftCard) -> Dictionary:
	if c == null:
		return {}
	return {
		"id": c.id,
		"name": c.name,
		"tier": c.tier,
		"bonus": c.bonus,
		"prestige": c.prestige,
		"cost": c.cost.duplicate(),
	}

static func _master_to_dict(m: CardData.MasterTile) -> Dictionary:
	return {
		"id": m.id,
		"name": m.name,
		"title": m.title,
		"prestige": m.prestige,
		"requirements": m.requirements.duplicate(),
	}

static func serialize_state(state: GameState) -> Dictionary:
	var decks_d: Dictionary = {}
	for t in [1, 2, 3]:
		var arr: Array = []
		for c in state.decks[t]:
			arr.append(_card_to_dict(c))
		decks_d[str(t)] = arr

	var board_d: Dictionary = {}
	for t in [1, 2, 3]:
		var arr: Array = []
		for c in state.board[t]:
			arr.append(_card_to_dict(c) if c != null else null)
		board_d[str(t)] = arr

	var masters_arr: Array = []
	for m in state.masters:
		masters_arr.append(_master_to_dict(m))

	var pending_arr: Array = []
	for m in state.pending_masters:
		pending_arr.append(_master_to_dict(m))

	var players_arr: Array = []
	for p in state.players:
		var pur: Array = []
		for c in p.purchased:
			pur.append(_card_to_dict(c))
		var res: Array = []
		for c in p.reserved:
			res.append(_card_to_dict(c))
		var ms: Array = []
		for m in p.masters:
			ms.append(_master_to_dict(m))
		players_arr.append({
			"index": p.index,
			"name": p.name,
			"is_ai": p.is_ai,
			"ai_level": p.ai_level,
			"ai_persona": p.ai_persona,
			"chips": p.chips.duplicate(),
			"discounts": p.discounts.duplicate(),
			"purchased": pur,
			"reserved": res,
			"masters": ms,
		})

	return {
		"version": 2,
		"rng_seed": state.rng_seed,
		"config": state.config.duplicate(true),
		"history": state.history.duplicate(true),
		"target_prestige": state.target_prestige,
		"bank": state.bank.duplicate(),
		"decks": decks_d,
		"board": board_d,
		"masters": masters_arr,
		"players": players_arr,
		"current_player_idx": state.current_player_idx,
		"round_number": state.round_number,
		"final_round_triggered": state.final_round_triggered,
		"phase": int(state.phase),
		"pending_masters": pending_arr,
		"winner_indices": state.winner_indices.duplicate(),
		"action_log": state.action_log.duplicate(),
	}

static func deserialize_state(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.rng_seed = int(d.get("rng_seed", 0))
	s.config = d.get("config", {}).duplicate(true)
	s.history = d.get("history", []).duplicate(true)
	s.target_prestige = int(d.get("target_prestige", 15))
	s.bank = d.get("bank", GemTypes.create_empty_pool(true)).duplicate()

	var decks_d: Dictionary = d.get("decks", {})
	for t in [1, 2, 3]:
		s.decks[t] = []
		for cd in decks_d.get(str(t), []):
			s.decks[t].append(CardData.CraftCard.from_dict(cd))

	var board_d: Dictionary = d.get("board", {})
	for t in [1, 2, 3]:
		s.board[t] = [null, null, null, null]
		var arr: Array = board_d.get(str(t), [])
		for i in range(mini(4, arr.size())):
			if typeof(arr[i]) == TYPE_DICTIONARY and not arr[i].is_empty():
				s.board[t][i] = CardData.CraftCard.from_dict(arr[i])

	for md in d.get("masters", []):
		s.masters.append(CardData.MasterTile.from_dict(md))
	for md in d.get("pending_masters", []):
		s.pending_masters.append(CardData.MasterTile.from_dict(md))

	for pd in d.get("players", []):
		var p := PlayerState.new(
			int(pd.get("index", 0)),
			str(pd.get("name", "玩家")),
			bool(pd.get("is_ai", false)),
			int(pd.get("ai_level", 1)),
			str(pd.get("ai_persona", "balanced"))
		)
		p.chips = pd.get("chips", GemTypes.create_empty_pool(true)).duplicate()
		p.discounts = pd.get("discounts", GemTypes.create_empty_pool(false)).duplicate()
		for cd in pd.get("purchased", []):
			p.purchased.append(CardData.CraftCard.from_dict(cd))
		for cd in pd.get("reserved", []):
			p.reserved.append(CardData.CraftCard.from_dict(cd))
		for md in pd.get("masters", []):
			p.masters.append(CardData.MasterTile.from_dict(md))
		s.players.append(p)

	s.current_player_idx = int(d.get("current_player_idx", 0))
	s.round_number = int(d.get("round_number", 1))
	s.final_round_triggered = bool(d.get("final_round_triggered", false))
	s.phase = int(d.get("phase", 0)) as GameState.TurnPhase
	for w in d.get("winner_indices", []):
		s.winner_indices.append(int(w))
	for lg in d.get("action_log", []):
		s.action_log.append(str(lg))
	return s

static func save_autosave(state: GameState) -> void:
	if state == null or state.phase == GameState.TurnPhase.GAME_OVER:
		clear_autosave()
		return
	var f := FileAccess.open(AUTOSAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(serialize_state(state)))

static func has_autosave() -> bool:
	return FileAccess.file_exists(AUTOSAVE_PATH)

static func load_autosave() -> GameState:
	if not has_autosave():
		return null
	var f := FileAccess.open(AUTOSAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return deserialize_state(parsed)

static func clear_autosave() -> void:
	if FileAccess.file_exists(AUTOSAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTOSAVE_PATH))

static func load_stats() -> Dictionary:
	var defaults := {"games_played": 0, "wins": 0, "best_score": 0, "fastest_win_round": 0}
	if not FileAccess.file_exists(STATS_PATH):
		return defaults
	var f := FileAccess.open(STATS_PATH, FileAccess.READ)
	if f == null:
		return defaults
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return defaults
	for k in defaults.keys():
		if not parsed.has(k):
			parsed[k] = defaults[k]
	return parsed

static func record_game_result(state: GameState) -> void:
	var stats := load_stats()
	stats["games_played"] = int(stats["games_played"]) + 1
	var human_won := false
	var human_best := 0
	for p in state.players:
		if not p.is_ai:
			human_best = maxi(human_best, p.get_score())
			if state.winner_indices.has(p.index):
				human_won = true
	if human_won:
		stats["wins"] = int(stats["wins"]) + 1
		var prev_fast := int(stats["fastest_win_round"])
		if prev_fast == 0 or state.round_number < prev_fast:
			stats["fastest_win_round"] = state.round_number
	stats["best_score"] = maxi(int(stats["best_score"]), human_best)

	var f := FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(stats))

static func load_codex() -> Dictionary:
	var defaults := {"cards": [], "masters": []}
	if not FileAccess.file_exists(CODEX_PATH):
		return defaults
	var f := FileAccess.open(CODEX_PATH, FileAccess.READ)
	if f == null:
		return defaults
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return defaults
	if not parsed.has("cards"):
		parsed["cards"] = []
	if not parsed.has("masters"):
		parsed["masters"] = []
	return parsed

static func unlock_codex_entry(kind: String, entry_id: String) -> void:
	if entry_id.is_empty():
		return
	var codex := load_codex()
	var arr: Array = codex.get(kind, [])
	if not arr.has(entry_id):
		arr.append(entry_id)
		codex[kind] = arr
		var f := FileAccess.open(CODEX_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(codex))

static func today_date_key() -> String:
	var dt := Time.get_date_dict_from_system()
	return "%04d%02d%02d" % [int(dt["year"]), int(dt["month"]), int(dt["day"])]

static func today_seed() -> int:
	return int(today_date_key())

static func is_today_daily_won() -> bool:
	if not FileAccess.file_exists(DAILY_PATH):
		return false
	var f := FileAccess.open(DAILY_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	return bool(parsed.get(today_date_key(), {}).get("won", false))

static func record_daily_result(won: bool, score: int, rounds: int) -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(DAILY_PATH):
		var f := FileAccess.open(DAILY_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				data = parsed
	var key := today_date_key()
	var prev: Dictionary = data.get(key, {})
	var prev_won := bool(prev.get("won", false))
	data[key] = {
		"won": prev_won or won,
		"best_score": maxi(int(prev.get("best_score", 0)), score),
		"best_rounds": rounds if (won and (int(prev.get("best_rounds", 999)) > rounds)) else int(prev.get("best_rounds", rounds)),
	}
	var fw := FileAccess.open(DAILY_PATH, FileAccess.WRITE)
	if fw != null:
		fw.store_string(JSON.stringify(data))
