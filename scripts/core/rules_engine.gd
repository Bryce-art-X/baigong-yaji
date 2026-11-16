class_name RulesEngine
extends RefCounted
## Pure game rules. No nodes, no UI.
##
## Single mutation entry point: `apply_action(state, action)`.
## The named helpers (take_different, buy_board, ...) are thin wrappers kept
## for convenience; they all route through apply_action, so every change is
## validated, recorded in `state.history`, and produces domain events.

const DATA_PATH: String = "res://data/craft_data.json"

static var _raw_cache: Dictionary = {}

# =============================================================================
# Setup
# =============================================================================

static func load_raw_data(path: String = DATA_PATH) -> Dictionary:
	if path == DATA_PATH and not _raw_cache.is_empty():
		return _raw_cache
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to open craft data: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON in craft data: " + path)
		return {}
	if path == DATA_PATH:
		_raw_cache = parsed
	return parsed

static func clear_data_cache() -> void:
	_raw_cache = {}

## player_configs: [{name, is_ai, ai_level}], 2..4 entries.
## rng_seed < 0 picks a random seed; the chosen seed is stored in state.rng_seed.
static func create_game(player_configs: Array, target_prestige: int = 15, rng_seed: int = -1) -> GameState:
	var state := GameState.new()
	state.target_prestige = target_prestige
	if rng_seed < 0:
		rng_seed = randi() & 0x7fffffff
	state.rng_seed = rng_seed
	state.config = {"players": player_configs.duplicate(true), "target": target_prestige}

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var p_count: int = clampi(player_configs.size(), 2, 4)
	for i in range(p_count):
		var cfg: Dictionary = player_configs[i]
		state.players.append(PlayerState.new(
			i,
			str(cfg.get("name", "玩家 %d" % (i + 1))),
			bool(cfg.get("is_ai", false)),
			int(cfg.get("ai_level", 1)),
			str(cfg.get("ai_persona", "balanced"))
		))

	# Bank: 2P -> 4, 3P -> 5, 4P -> 7 of each base material; gold always 5.
	var base_count: int = 4 if p_count == 2 else (5 if p_count == 3 else 7)
	state.bank = GemTypes.create_empty_pool(true)
	for g in GemTypes.BASE_GEMS:
		state.bank[g] = base_count
	state.bank[GemTypes.GOLD] = 5

	var raw := load_raw_data()
	for c_dict in raw.get("cards", []):
		var card := CardData.CraftCard.from_dict(c_dict)
		state.decks[card.tier].append(card)

	for tier in [1, 2, 3]:
		_shuffle_array(state.decks[tier], rng)
		for slot in range(4):
			state.board[tier][slot] = _draw_from_deck(state, tier)

	var all_masters: Array[CardData.MasterTile] = []
	for m_dict in raw.get("masters", []):
		all_masters.append(CardData.MasterTile.from_dict(m_dict))
	_shuffle_array(all_masters, rng)
	for i in range(mini(p_count + 1, all_masters.size())):
		state.masters.append(all_masters[i])

	state.log_event("雅集开启：%d 人局，目标声望 %d 分。" % [p_count, target_prestige])
	return state

## Rebuild a game from its seed + config + action history (replay / verification).
static func replay(rng_seed: int, config: Dictionary, history: Array) -> GameState:
	var s := create_game(config.get("players", []), int(config.get("target", 15)), rng_seed)
	for d in history:
		var res := apply_action(s, GameAction.from_dict(d))
		if not bool(res["ok"]):
			push_error("Replay diverged at action %s: %s" % [str(d), res["reason"]])
			break
	return s

static func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _draw_from_deck(state: GameState, tier: int) -> CardData.CraftCard:
	var deck: Array = state.decks[tier]
	if deck.is_empty():
		return null
	return deck.pop_back()

# =============================================================================
# Central entry point
# =============================================================================

static func _ok() -> Dictionary:
	return {"ok": true, "reason": ""}

static func _err(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

## Validate without mutating.
static func validate(state: GameState, action: GameAction) -> Dictionary:
	if state.phase == GameState.TurnPhase.GAME_OVER:
		return _err("对局已结束")
	var p := action.params
	match action.type:
		GameAction.Type.TAKE_DIFFERENT:
			return _check_take_different(state, p.get("gems", []))
		GameAction.Type.TAKE_TWO:
			return _check_take_two(state, str(p.get("gem", "")))
		GameAction.Type.RESERVE_BOARD:
			return _check_reserve_board(state, int(p.get("tier", 0)), int(p.get("slot", -1)))
		GameAction.Type.RESERVE_DECK:
			return _check_reserve_deck(state, int(p.get("tier", 0)))
		GameAction.Type.BUY_BOARD:
			return _check_buy_board(state, int(p.get("tier", 0)), int(p.get("slot", -1)))
		GameAction.Type.BUY_RESERVED:
			return _check_buy_reserved(state, int(p.get("index", -1)))
		GameAction.Type.DISCARD:
			return _check_discard(state, p.get("chips", {}))
		GameAction.Type.CHOOSE_MASTER:
			return _check_choose_master(state, str(p.get("master_id", "")))
		GameAction.Type.PASS:
			return _check_pass(state)
	return _err("未知动作")

## Validate, mutate, record history, return {ok, reason, events}.
static func apply_action(state: GameState, action: GameAction) -> Dictionary:
	var chk := validate(state, action)
	if not bool(chk["ok"]):
		return {"ok": false, "reason": chk["reason"], "events": []}

	state.events = []
	action.player = state.current_player_idx
	var p := action.params
	match action.type:
		GameAction.Type.TAKE_DIFFERENT:
			_do_take_different(state, p["gems"])
		GameAction.Type.TAKE_TWO:
			_do_take_two(state, str(p["gem"]))
		GameAction.Type.RESERVE_BOARD:
			_do_reserve_board(state, int(p["tier"]), int(p["slot"]))
		GameAction.Type.RESERVE_DECK:
			_do_reserve_deck(state, int(p["tier"]))
		GameAction.Type.BUY_BOARD:
			_do_buy_board(state, int(p["tier"]), int(p["slot"]))
		GameAction.Type.BUY_RESERVED:
			_do_buy_reserved(state, int(p["index"]))
		GameAction.Type.DISCARD:
			_do_discard(state, p["chips"])
		GameAction.Type.CHOOSE_MASTER:
			_do_choose_master(state, str(p["master_id"]))
		GameAction.Type.PASS:
			_do_pass(state)

	state.history.append(action.to_dict())
	var evs := state.events
	state.events = []
	return {"ok": true, "reason": "", "events": evs}

# =============================================================================
# Legal move enumeration (AI, pass detection, future network validation)
# =============================================================================

static func legal_actions(state: GameState) -> Array[GameAction]:
	var out: Array[GameAction] = []
	match state.phase:
		GameState.TurnPhase.ACTION:
			out = _legal_main_actions(state)
			if out.is_empty():
				out.append(GameAction.pass_turn())
		GameState.TurnPhase.CHOOSE_MASTER:
			for m in state.pending_masters:
				out.append(GameAction.choose_master(m.id))
		GameState.TurnPhase.DISCARD_CHIPS:
			pass # combinatorial; callers construct a DISCARD action directly
	return out

static func _legal_main_actions(state: GameState) -> Array[GameAction]:
	var out: Array[GameAction] = []
	var p := state.current_player()
	var avail := available_base_gem_types(state)

	# Take different: all combinations of size min(3, avail)
	var k := mini(3, avail.size())
	if k > 0:
		for combo in _combinations(avail, k):
			out.append(GameAction.take_different(combo))
	# Take two
	for g in GemTypes.BASE_GEMS:
		if int(state.bank[g]) >= 4:
			out.append(GameAction.take_two(g))
	# Buy
	for tier in [1, 2, 3]:
		for slot in range(4):
			var c: CardData.CraftCard = state.board[tier][slot]
			if c != null and p.can_afford(c):
				out.append(GameAction.buy_board(tier, slot))
	for i in range(p.reserved.size()):
		if p.can_afford(p.reserved[i]):
			out.append(GameAction.buy_reserved(i))
	# Reserve
	if p.reserved.size() < GameState.MAX_RESERVED:
		for tier in [1, 2, 3]:
			for slot in range(4):
				if state.board[tier][slot] != null:
					out.append(GameAction.reserve_board(tier, slot))
			if not state.decks[tier].is_empty():
				out.append(GameAction.reserve_deck(tier))
	return out

static func _combinations(items: Array, k: int) -> Array:
	var res: Array = []
	_combo_rec(items, k, 0, [], res)
	return res

static func _combo_rec(items: Array, k: int, start: int, cur: Array, res: Array) -> void:
	if cur.size() == k:
		res.append(cur.duplicate())
		return
	for i in range(start, items.size()):
		cur.append(items[i])
		_combo_rec(items, k, i + 1, cur, res)
		cur.pop_back()

static func available_base_gem_types(state: GameState) -> Array[String]:
	var res: Array[String] = []
	for g in GemTypes.BASE_GEMS:
		if int(state.bank.get(g, 0)) > 0:
			res.append(g)
	return res

# =============================================================================
# Validation helpers
# =============================================================================

static func _in_action_phase(state: GameState) -> bool:
	return state.phase == GameState.TurnPhase.ACTION

static func _check_take_different(state: GameState, gems: Array) -> Dictionary:
	if not _in_action_phase(state):
		return _err("当前非行动阶段")
	var avail := available_base_gem_types(state)
	var need := mini(3, avail.size())
	if need == 0:
		return _err("库房已无基础材料")
	if gems.size() != need:
		return _err("需选择 %d 种不同材料" % need)
	var seen: Dictionary = {}
	for g in gems:
		var gs := str(g)
		if not GemTypes.BASE_GEMS.has(gs):
			return _err("不可直接拿取赤金")
		if seen.has(gs):
			return _err("不可重复选择同种材料")
		if int(state.bank.get(gs, 0)) <= 0:
			return _err("%s 余量不足" % GemTypes.gem_name(gs))
		seen[gs] = true
	return _ok()

static func _check_take_two(state: GameState, gem: String) -> Dictionary:
	if not _in_action_phase(state):
		return _err("当前非行动阶段")
	if not GemTypes.BASE_GEMS.has(gem):
		return _err("赤金不可直接拿取")
	if int(state.bank.get(gem, 0)) < 4:
		return _err("%s 存量不足 4 枚，不可双取" % GemTypes.gem_name(gem))
	return _ok()

static func _valid_slot(state: GameState, tier: int, slot: int) -> bool:
	return state.board.has(tier) and slot >= 0 and slot < 4

static func _check_reserve_board(state: GameState, tier: int, slot: int) -> Dictionary:
	if not _in_action_phase(state):
		return _err("当前非行动阶段")
	if state.current_player().reserved.size() >= GameState.MAX_RESERVED:
		return _err("最多只能留存 3 张图谱")
	if not _valid_slot(state, tier, slot):
		return _err("无效的展示位")
	if state.board[tier][slot] == null:
		return _err("该位置已空")
	return _ok()

static func _check_reserve_deck(state: GameState, tier: int) -> Dictionary:
	if not _in_action_phase(state):
		return _err("当前非行动阶段")
	if state.current_player().reserved.size() >= GameState.MAX_RESERVED:
		return _err("最多只能留存 3 张图谱")
	if not state.decks.has(tier) or state.decks[tier].is_empty():
		return _err("该阶牌库已空")
	return _ok()

static func _check_buy_board(state: GameState, tier: int, slot: int) -> Dictionary:
	if not _in_action_phase(state):
		return _err("当前非行动阶段")
	if not _valid_slot(state, tier, slot):
		return _err("无效的展示位")
	var card: CardData.CraftCard = state.board[tier][slot]
	if card == null:
		return _err("该位置已空")
	if not state.current_player().can_afford(card):
		return _err("材料不足，无法打造「%s」" % card.name)
	return _ok()

static func _check_buy_reserved(state: GameState, idx: int) -> Dictionary:
	if not _in_action_phase(state):
		return _err("当前非行动阶段")
	var p := state.current_player()
	if idx < 0 or idx >= p.reserved.size():
		return _err("无效的留存位")
	if not p.can_afford(p.reserved[idx]):
		return _err("材料不足，无法打造「%s」" % p.reserved[idx].name)
	return _ok()

static func _check_discard(state: GameState, to_return: Dictionary) -> Dictionary:
	if state.phase != GameState.TurnPhase.DISCARD_CHIPS:
		return _err("当前无需弃置材料")
	var p := state.current_player()
	var excess := p.total_chips() - GameState.MAX_CHIPS
	var sum: int = 0
	for g in to_return.keys():
		if not GemTypes.ALL_GEMS.has(str(g)):
			return _err("未知材料")
		var amt := int(to_return[g])
		if amt < 0:
			return _err("弃置数量不能为负")
		if amt > int(p.chips.get(str(g), 0)):
			return _err("%s 持有不足" % GemTypes.gem_name(str(g)))
		sum += amt
	if sum != excess:
		return _err("需刚好归还 %d 枚材料" % excess)
	return _ok()

static func _check_choose_master(state: GameState, master_id: String) -> Dictionary:
	if state.phase != GameState.TurnPhase.CHOOSE_MASTER:
		return _err("当前无需选择名士")
	for m in state.pending_masters:
		if m.id == master_id:
			return _ok()
	return _err("无效的名士选择")

static func _check_pass(state: GameState) -> Dictionary:
	if not _in_action_phase(state):
		return _err("当前非行动阶段")
	if not _legal_main_actions(state).is_empty():
		return _err("仍有可执行的动作，不能跳过")
	return _ok()

# =============================================================================
# Mutations (assume validated)
# =============================================================================

static func _do_take_different(state: GameState, gems: Array) -> void:
	var p := state.current_player()
	var names: Array[String] = []
	var taken: Dictionary = {}
	for g in gems:
		var gs := str(g)
		state.bank[gs] -= 1
		p.chips[gs] += 1
		taken[gs] = 1
		names.append(GemTypes.gem_name(gs))
	state.emit("take", {"player": p.index, "gems": taken})
	state.log_event("%s 采集了 %s" % [p.name, "、".join(names)])
	_after_action(state)

static func _do_take_two(state: GameState, gem: String) -> void:
	var p := state.current_player()
	state.bank[gem] -= 2
	p.chips[gem] += 2
	state.emit("take", {"player": p.index, "gems": {gem: 2}})
	state.log_event("%s 双取了 2 枚%s" % [p.name, GemTypes.gem_name(gem)])
	_after_action(state)

static func _grant_gold_for_reserve(state: GameState, p: PlayerState) -> bool:
	if int(state.bank.get(GemTypes.GOLD, 0)) > 0:
		state.bank[GemTypes.GOLD] -= 1
		p.chips[GemTypes.GOLD] += 1
		return true
	return false

static func _refill(state: GameState, tier: int, slot: int) -> void:
	var nc := _draw_from_deck(state, tier)
	state.board[tier][slot] = nc
	state.emit("refill", {"tier": tier, "slot": slot, "card_id": nc.id if nc != null else ""})

static func _do_reserve_board(state: GameState, tier: int, slot: int) -> void:
	var p := state.current_player()
	var card: CardData.CraftCard = state.board[tier][slot]
	p.reserved.append(card)
	var got_gold := _grant_gold_for_reserve(state, p)
	state.emit("reserve", {"player": p.index, "card_id": card.id, "from": "board", "tier": tier, "slot": slot, "gold": got_gold})
	_refill(state, tier, slot)
	state.log_event("%s 留存了「%s」%s" % [p.name, card.name, "（并获 1 枚赤金）" if got_gold else ""])
	_after_action(state)

static func _do_reserve_deck(state: GameState, tier: int) -> void:
	var p := state.current_player()
	var card := _draw_from_deck(state, tier)
	p.reserved.append(card)
	var got_gold := _grant_gold_for_reserve(state, p)
	state.emit("reserve", {"player": p.index, "card_id": card.id, "from": "deck", "tier": tier, "slot": -1, "gold": got_gold})
	state.log_event("%s 暗抽留存了 %d 阶图谱%s" % [p.name, tier, "（并获 1 枚赤金）" if got_gold else ""])
	_after_action(state)

static func _pay_for(state: GameState, p: PlayerState, card: CardData.CraftCard) -> Dictionary:
	var payment: Dictionary = p.compute_payment(card)["payment"]
	for g in GemTypes.ALL_GEMS:
		var amt := int(payment.get(g, 0))
		if amt > 0:
			p.chips[g] -= amt
			state.bank[g] += amt
	p.purchased.append(card)
	p.discounts[card.bonus] += 1
	return payment

static func _do_buy_board(state: GameState, tier: int, slot: int) -> void:
	var p := state.current_player()
	var card: CardData.CraftCard = state.board[tier][slot]
	var payment := _pay_for(state, p, card)
	state.emit("buy", {"player": p.index, "card_id": card.id, "from": "board", "tier": tier, "slot": slot, "payment": payment, "prestige": card.prestige})
	_refill(state, tier, slot)
	_log_buy(state, p, card)
	_after_action(state)

static func _do_buy_reserved(state: GameState, idx: int) -> void:
	var p := state.current_player()
	var card: CardData.CraftCard = p.reserved[idx]
	p.reserved.remove_at(idx)
	var payment := _pay_for(state, p, card)
	state.emit("buy", {"player": p.index, "card_id": card.id, "from": "reserved", "index": idx, "payment": payment, "prestige": card.prestige})
	_log_buy(state, p, card)
	_after_action(state)

static func _log_buy(state: GameState, p: PlayerState, card: CardData.CraftCard) -> void:
	var pts := " (+%d声望)" % card.prestige if card.prestige > 0 else ""
	state.log_event("%s 制成了「%s」%s" % [p.name, card.name, pts])

static func _do_discard(state: GameState, to_return: Dictionary) -> void:
	var p := state.current_player()
	var returned: Dictionary = {}
	for g in to_return.keys():
		var gs := str(g)
		var amt := int(to_return[g])
		if amt > 0:
			p.chips[gs] -= amt
			state.bank[gs] += amt
			returned[gs] = amt
	state.emit("discard", {"player": p.index, "chips": returned})
	state.log_event("%s 归还了多余材料" % p.name)
	_check_masters_or_finish(state)

static func _do_choose_master(state: GameState, master_id: String) -> void:
	var chosen: CardData.MasterTile = null
	for m in state.pending_masters:
		if m.id == master_id:
			chosen = m
	state.pending_masters.clear()
	_grant_master(state, state.current_player(), chosen)
	_finish_turn(state)

static func _do_pass(state: GameState) -> void:
	var p := state.current_player()
	state.emit("pass", {"player": p.index})
	state.log_event("%s 无可行之事，静坐一轮" % p.name)
	_finish_turn(state)

static func _grant_master(state: GameState, p: PlayerState, m: CardData.MasterTile) -> void:
	state.masters.erase(m)
	p.masters.append(m)
	state.emit("master", {"player": p.index, "master_id": m.id, "prestige": m.prestige})
	state.log_event("名士「%s·%s」亲临 %s 的雅集 (+%d声望)" % [m.name, m.title, p.name, m.prestige])

static func _after_action(state: GameState) -> void:
	if state.current_player().total_chips() > GameState.MAX_CHIPS:
		state.phase = GameState.TurnPhase.DISCARD_CHIPS
		state.emit("phase", {"phase": "discard", "player": state.current_player_idx,
			"excess": state.current_player().total_chips() - GameState.MAX_CHIPS})
		return
	_check_masters_or_finish(state)

static func _check_masters_or_finish(state: GameState) -> void:
	var p := state.current_player()
	var eligible: Array[CardData.MasterTile] = []
	for m in state.masters:
		if p.meets_master(m):
			eligible.append(m)
	if eligible.size() == 1:
		_grant_master(state, p, eligible[0])
		_finish_turn(state)
	elif eligible.size() > 1:
		state.pending_masters = eligible
		state.phase = GameState.TurnPhase.CHOOSE_MASTER
		var ids: Array = []
		for m in eligible:
			ids.append(m.id)
		state.emit("phase", {"phase": "choose_master", "player": p.index, "options": ids})
	else:
		_finish_turn(state)

static func _finish_turn(state: GameState) -> void:
	var p := state.current_player()
	if p.get_score() >= state.target_prestige and not state.final_round_triggered:
		state.final_round_triggered = true
		state.emit("final_round", {"player": p.index, "score": p.get_score()})
		state.log_event("【终局钟鸣】%s 率先达到 %d 声望，本轮结束后结算！" % [p.name, p.get_score()])

	state.current_player_idx = (state.current_player_idx + 1) % state.players.size()
	if state.current_player_idx == 0:
		if state.final_round_triggered:
			_resolve_winners(state)
			state.phase = GameState.TurnPhase.GAME_OVER
			state.emit("game_over", {"winners": state.winner_indices.duplicate()})
			return
		state.round_number += 1
	state.phase = GameState.TurnPhase.ACTION
	state.emit("turn", {"player": state.current_player_idx, "round": state.round_number})

static func _resolve_winners(state: GameState) -> void:
	var best_score: int = -1
	var best_cards: int = 999999
	var winners: Array[int] = []
	for p in state.players:
		var sc := p.get_score()
		var cc := p.purchased.size()
		if sc > best_score or (sc == best_score and cc < best_cards):
			best_score = sc
			best_cards = cc
			winners = [p.index]
		elif sc == best_score and cc == best_cards:
			winners.append(p.index)
	state.winner_indices = winners
	var names: Array[String] = []
	for idx in winners:
		names.append(state.players[idx].name)
	state.log_event("雅集落幕！胜者：%s（%d 声望）" % ["、".join(names), best_score])

# =============================================================================
# Convenience wrappers (UI / AI / tests). All go through apply_action.
# =============================================================================

static func can_take_different(state: GameState, gems: Array) -> Dictionary:
	return _check_take_different(state, gems)

static func take_different(state: GameState, gems: Array) -> Dictionary:
	return apply_action(state, GameAction.take_different(gems))

static func can_take_two_same(state: GameState, gem: String) -> Dictionary:
	return _check_take_two(state, gem)

static func take_two_same(state: GameState, gem: String) -> Dictionary:
	return apply_action(state, GameAction.take_two(gem))

static func can_reserve_board(state: GameState, tier: int, slot: int) -> Dictionary:
	return _check_reserve_board(state, tier, slot)

static func reserve_board(state: GameState, tier: int, slot: int) -> Dictionary:
	return apply_action(state, GameAction.reserve_board(tier, slot))

static func can_reserve_deck(state: GameState, tier: int) -> Dictionary:
	return _check_reserve_deck(state, tier)

static func reserve_deck(state: GameState, tier: int) -> Dictionary:
	return apply_action(state, GameAction.reserve_deck(tier))

static func can_buy_board(state: GameState, tier: int, slot: int) -> Dictionary:
	return _check_buy_board(state, tier, slot)

static func buy_board(state: GameState, tier: int, slot: int) -> Dictionary:
	return apply_action(state, GameAction.buy_board(tier, slot))

static func can_buy_reserved(state: GameState, idx: int) -> Dictionary:
	return _check_buy_reserved(state, idx)

static func buy_reserved(state: GameState, idx: int) -> Dictionary:
	return apply_action(state, GameAction.buy_reserved(idx))

static func can_discard_chips(state: GameState, to_return: Dictionary) -> Dictionary:
	return _check_discard(state, to_return)

static func discard_chips(state: GameState, to_return: Dictionary) -> Dictionary:
	return apply_action(state, GameAction.discard(to_return))

static func choose_master(state: GameState, master_id: String) -> Dictionary:
	return apply_action(state, GameAction.choose_master(master_id))

static func can_pass(state: GameState) -> Dictionary:
	return _check_pass(state)

static func pass_turn(state: GameState) -> Dictionary:
	return apply_action(state, GameAction.pass_turn())
