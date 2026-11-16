class_name RulesEngine
extends RefCounted

const DATA_PATH: String = "res://data/craft_data.json"

static func load_raw_data(path: String = DATA_PATH) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to open craft data: " + path)
		return {}
	var text := f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON in craft data: " + path)
		return {}
	return parsed

static func create_game(player_configs: Array, target_prestige: int = 15, rng_seed: int = -1) -> GameState:
	var state := GameState.new()
	state.target_prestige = target_prestige

	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	var p_count: int = clampi(player_configs.size(), 2, 4)
	for i in range(p_count):
		var cfg: Dictionary = player_configs[i]
		var p := PlayerState.new(
			i,
			str(cfg.get("name", "玩家 %d" % (i + 1))),
			bool(cfg.get("is_ai", false)),
			int(cfg.get("ai_level", 1))
		)
		state.players.append(p)

	# Bank setup: 2P -> 4, 3P -> 5, 4P -> 7; gold -> 5
	var base_count: int = 4 if p_count == 2 else (5 if p_count == 3 else 7)
	state.bank = GemTypes.create_empty_pool(true)
	for g in GemTypes.BASE_GEMS:
		state.bank[g] = base_count
	state.bank[GemTypes.GOLD] = 5

	# Load cards & masters
	var raw := load_raw_data()
	var all_cards: Array = raw.get("cards", [])
	for c_dict in all_cards:
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

	var master_count: int = p_count + 1
	for i in range(mini(master_count, all_masters.size())):
		state.masters.append(all_masters[i])

	state.log_event("雅集开启：%d 人局，目标声望 %d 分。" % [p_count, target_prestige])
	return state

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

static func available_base_gem_types(state: GameState) -> Array[String]:
	var res: Array[String] = []
	for g in GemTypes.BASE_GEMS:
		if int(state.bank.get(g, 0)) > 0:
			res.append(g)
	return res

static func can_take_different(state: GameState, gems: Array[String]) -> Dictionary:
	if state.phase != GameState.TurnPhase.ACTION:
		return {"ok": false, "reason": "当前非行动阶段"}
	var avail := available_base_gem_types(state)
	var max_take := mini(3, avail.size())
	if max_take == 0:
		return {"ok": false, "reason": "库房已无基础材料"}
	if gems.size() != max_take:
		return {"ok": false, "reason": "需选择 %d 种不同材料" % max_take}

	var seen: Dictionary = {}
	for g in gems:
		if not GemTypes.BASE_GEMS.has(g):
			return {"ok": false, "reason": "不可直接拿取赤金"}
		if seen.has(g):
			return {"ok": false, "reason": "不可重复选择同种材料"}
		if int(state.bank.get(g, 0)) <= 0:
			return {"ok": false, "reason": "%s 余量不足" % GemTypes.gem_name(g)}
		seen[g] = true
	return {"ok": true}

static func take_different(state: GameState, gems: Array[String]) -> Dictionary:
	var chk := can_take_different(state, gems)
	if not bool(chk["ok"]):
		return chk
	var p := state.current_player()
	var names: Array[String] = []
	for g in gems:
		state.bank[g] -= 1
		p.chips[g] += 1
		names.append(GemTypes.gem_name(g))
	state.log_event("%s 采集了 %s" % [p.name, "、".join(names)])
	_after_action(state)
	return {"ok": true}

static func can_take_two_same(state: GameState, gem: String) -> Dictionary:
	if state.phase != GameState.TurnPhase.ACTION:
		return {"ok": false, "reason": "当前非行动阶段"}
	if not GemTypes.BASE_GEMS.has(gem):
		return {"ok": false, "reason": "赤金不可直接拿取"}
	if int(state.bank.get(gem, 0)) < 4:
		return {"ok": false, "reason": "%s 存量不足 4 枚，不可双取" % GemTypes.gem_name(gem)}
	return {"ok": true}

static func take_two_same(state: GameState, gem: String) -> Dictionary:
	var chk := can_take_two_same(state, gem)
	if not bool(chk["ok"]):
		return chk
	var p := state.current_player()
	state.bank[gem] -= 2
	p.chips[gem] += 2
	state.log_event("%s 双取了 2 枚%s" % [p.name, GemTypes.gem_name(gem)])
	_after_action(state)
	return {"ok": true}

static func can_reserve_board(state: GameState, tier: int, slot: int) -> Dictionary:
	if state.phase != GameState.TurnPhase.ACTION:
		return {"ok": false, "reason": "当前非行动阶段"}
	var p := state.current_player()
	if p.reserved.size() >= GameState.MAX_RESERVED:
		return {"ok": false, "reason": "最多只能留存 3 张图谱"}
	if not state.board.has(tier) or slot < 0 or slot >= 4:
		return {"ok": false, "reason": "无效的展示位"}
	if state.board[tier][slot] == null:
		return {"ok": false, "reason": "该位置已空"}
	return {"ok": true}

static func reserve_board(state: GameState, tier: int, slot: int) -> Dictionary:
	var chk := can_reserve_board(state, tier, slot)
	if not bool(chk["ok"]):
		return chk
	var p := state.current_player()
	var card: CardData.CraftCard = state.board[tier][slot]
	p.reserved.append(card)
	state.board[tier][slot] = _draw_from_deck(state, tier)
	var got_gold := false
	if int(state.bank.get(GemTypes.GOLD, 0)) > 0:
		state.bank[GemTypes.GOLD] -= 1
		p.chips[GemTypes.GOLD] += 1
		got_gold = true
	state.log_event("%s 留存了「%s」%s" % [p.name, card.name, "（并获 1 枚赤金）" if got_gold else ""])
	_after_action(state)
	return {"ok": true}

static func can_reserve_deck(state: GameState, tier: int) -> Dictionary:
	if state.phase != GameState.TurnPhase.ACTION:
		return {"ok": false, "reason": "当前非行动阶段"}
	var p := state.current_player()
	if p.reserved.size() >= GameState.MAX_RESERVED:
		return {"ok": false, "reason": "最多只能留存 3 张图谱"}
	if not state.decks.has(tier) or state.decks[tier].is_empty():
		return {"ok": false, "reason": "该阶牌库已空"}
	return {"ok": true}

static func reserve_deck(state: GameState, tier: int) -> Dictionary:
	var chk := can_reserve_deck(state, tier)
	if not bool(chk["ok"]):
		return chk
	var p := state.current_player()
	var card := _draw_from_deck(state, tier)
	p.reserved.append(card)
	var got_gold := false
	if int(state.bank.get(GemTypes.GOLD, 0)) > 0:
		state.bank[GemTypes.GOLD] -= 1
		p.chips[GemTypes.GOLD] += 1
		got_gold = true
	state.log_event("%s 暗抽留存了 %d 阶图谱%s" % [p.name, tier, "（并获 1 枚赤金）" if got_gold else ""])
	_after_action(state)
	return {"ok": true}

static func can_buy_board(state: GameState, tier: int, slot: int) -> Dictionary:
	if state.phase != GameState.TurnPhase.ACTION:
		return {"ok": false, "reason": "当前非行动阶段"}
	if not state.board.has(tier) or slot < 0 or slot >= 4:
		return {"ok": false, "reason": "无效的展示位"}
	var card: CardData.CraftCard = state.board[tier][slot]
	if card == null:
		return {"ok": false, "reason": "该位置已空"}
	var p := state.current_player()
	if not p.can_afford(card):
		return {"ok": false, "reason": "材料不足，无法打造「%s」" % card.name}
	return {"ok": true}

static func buy_board(state: GameState, tier: int, slot: int) -> Dictionary:
	var chk := can_buy_board(state, tier, slot)
	if not bool(chk["ok"]):
		return chk
	var p := state.current_player()
	var card: CardData.CraftCard = state.board[tier][slot]
	_execute_purchase(state, p, card)
	state.board[tier][slot] = _draw_from_deck(state, tier)
	_after_action(state)
	return {"ok": true}

static func can_buy_reserved(state: GameState, reserved_idx: int) -> Dictionary:
	if state.phase != GameState.TurnPhase.ACTION:
		return {"ok": false, "reason": "当前非行动阶段"}
	var p := state.current_player()
	if reserved_idx < 0 or reserved_idx >= p.reserved.size():
		return {"ok": false, "reason": "无效的留存位"}
	var card: CardData.CraftCard = p.reserved[reserved_idx]
	if not p.can_afford(card):
		return {"ok": false, "reason": "材料不足，无法打造「%s」" % card.name}
	return {"ok": true}

static func buy_reserved(state: GameState, reserved_idx: int) -> Dictionary:
	var chk := can_buy_reserved(state, reserved_idx)
	if not bool(chk["ok"]):
		return chk
	var p := state.current_player()
	var card: CardData.CraftCard = p.reserved[reserved_idx]
	p.reserved.remove_at(reserved_idx)
	_execute_purchase(state, p, card)
	_after_action(state)
	return {"ok": true}

static func _execute_purchase(state: GameState, p: PlayerState, card: CardData.CraftCard) -> void:
	var pay_info := p.compute_payment(card)
	var payment: Dictionary = pay_info["payment"]
	for g in GemTypes.ALL_GEMS:
		var amt := int(payment.get(g, 0))
		if amt > 0:
			p.chips[g] -= amt
			state.bank[g] += amt
	p.purchased.append(card)
	p.discounts[card.bonus] += 1
	var pts_str := " (+%d声望)" % card.prestige if card.prestige > 0 else ""
	state.log_event("%s 制成了「%s」%s" % [p.name, card.name, pts_str])

static func can_discard_chips(state: GameState, to_return: Dictionary) -> Dictionary:
	if state.phase != GameState.TurnPhase.DISCARD_CHIPS:
		return {"ok": false, "reason": "当前无需弃置材料"}
	var p := state.current_player()
	var excess := p.total_chips() - GameState.MAX_CHIPS
	var return_sum: int = 0
	for g in GemTypes.ALL_GEMS:
		var amt := int(to_return.get(g, 0))
		if amt < 0:
			return {"ok": false, "reason": "弃置数量不能为负"}
		if amt > int(p.chips.get(g, 0)):
			return {"ok": false, "reason": "%s 持有不足" % GemTypes.gem_name(g)}
		return_sum += amt
	if return_sum != excess:
		return {"ok": false, "reason": "需刚好归还 %d 枚材料" % excess}
	return {"ok": true}

static func discard_chips(state: GameState, to_return: Dictionary) -> Dictionary:
	var chk := can_discard_chips(state, to_return)
	if not bool(chk["ok"]):
		return chk
	var p := state.current_player()
	for g in GemTypes.ALL_GEMS:
		var amt := int(to_return.get(g, 0))
		if amt > 0:
			p.chips[g] -= amt
			state.bank[g] += amt
	state.log_event("%s 归还了多余材料" % p.name)
	_check_masters_or_finish(state)
	return {"ok": true}

static func choose_master(state: GameState, master_id: String) -> Dictionary:
	if state.phase != GameState.TurnPhase.CHOOSE_MASTER:
		return {"ok": false, "reason": "当前无需选择名士"}
	var chosen: CardData.MasterTile = null
	for m in state.pending_masters:
		if m.id == master_id:
			chosen = m
			break
	if chosen == null:
		return {"ok": false, "reason": "无效的名士选择"}
	var p := state.current_player()
	state.masters.erase(chosen)
	p.masters.append(chosen)
	state.pending_masters.clear()
	state.log_event("名士「%s·%s」亲临 %s 的雅集 (+%d声望)" % [chosen.name, chosen.title, p.name, chosen.prestige])
	_finish_turn(state)
	return {"ok": true}

static func _after_action(state: GameState) -> void:
	var p := state.current_player()
	if p.total_chips() > GameState.MAX_CHIPS:
		state.phase = GameState.TurnPhase.DISCARD_CHIPS
		return
	_check_masters_or_finish(state)

static func _check_masters_or_finish(state: GameState) -> void:
	var p := state.current_player()
	var eligible: Array[CardData.MasterTile] = []
	for m in state.masters:
		if p.meets_master(m):
			eligible.append(m)
	if eligible.size() == 1:
		var m := eligible[0]
		state.masters.erase(m)
		p.masters.append(m)
		state.log_event("名士「%s·%s」亲临 %s 的雅集 (+%d声望)" % [m.name, m.title, p.name, m.prestige])
		_finish_turn(state)
	elif eligible.size() > 1:
		state.pending_masters = eligible
		state.phase = GameState.TurnPhase.CHOOSE_MASTER
	else:
		_finish_turn(state)

static func _finish_turn(state: GameState) -> void:
	var p := state.current_player()
	if p.get_score() >= state.target_prestige and not state.final_round_triggered:
		state.final_round_triggered = true
		state.log_event("【终局钟鸣】%s 率先达到 %d 声望，本轮结束后结算！" % [p.name, p.get_score()])

	state.current_player_idx = (state.current_player_idx + 1) % state.players.size()
	if state.current_player_idx == 0:
		if state.final_round_triggered:
			_resolve_winners(state)
			state.phase = GameState.TurnPhase.GAME_OVER
			return
		state.round_number += 1

	state.phase = GameState.TurnPhase.ACTION

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
