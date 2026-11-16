class_name AIAgent
extends RefCounted

const PERSONA_NAMES: Dictionary = {
	"balanced": "均衡",
	"artisan": "巧匠",
	"collector": "藏家",
	"scholar": "名士",
	"interceptor": "博弈",
}

static func persona_label(p: String) -> String:
	return str(PERSONA_NAMES.get(p, "均衡"))

static func take_turn_step(state: GameState) -> void:
	match state.phase:
		GameState.TurnPhase.ACTION:
			var p := state.current_player()
			if p.ai_level >= 2:
				_do_master_ai_action(state)
			else:
				_do_action(state)
		GameState.TurnPhase.DISCARD_CHIPS:
			_do_discard(state)
		GameState.TurnPhase.CHOOSE_MASTER:
			_do_choose_master(state)

# =============================================================================
# Level 2: Grandmaster AI (Lookahead + Threat Evaluation + Persona)
# =============================================================================

static func _do_master_ai_action(state: GameState) -> void:
	var my_idx := state.current_player_idx
	var p := state.current_player()
	var actions := RulesEngine.legal_actions(state)
	if actions.is_empty():
		RulesEngine.pass_turn(state)
		return

	# Filter out blind deck reserves unless no other reserves/good moves exist (keeps branching tight)
	var candidates: Array[GameAction] = []
	for a in actions:
		if a.type == GameAction.Type.RESERVE_DECK and actions.size() > 4:
			continue
		candidates.append(a)
	if candidates.is_empty():
		candidates = actions

	var best_act: GameAction = candidates[0]
	var best_val: float = -999999.0

	for act in candidates:
		var sim := _clone_state_fast(state)
		var res := RulesEngine.apply_action(sim, act)
		if not bool(res["ok"]):
			continue
		# Auto-resolve follow-up phases in simulation for accurate evaluation
		if sim.phase == GameState.TurnPhase.DISCARD_CHIPS and sim.current_player_idx == my_idx:
			_do_discard(sim)
		if sim.phase == GameState.TurnPhase.CHOOSE_MASTER and sim.current_player_idx == my_idx:
			_do_choose_master(sim)

		var val := _evaluate_state(sim, my_idx, p.ai_persona)
		# Small tie-breaker favoring buying > taking > reserving
		if act.type == GameAction.Type.BUY_BOARD or act.type == GameAction.Type.BUY_RESERVED:
			val += 0.45
		elif act.type == GameAction.Type.TAKE_DIFFERENT or act.type == GameAction.Type.TAKE_TWO:
			val += 0.10
		if val > best_val:
			best_val = val
			best_act = act

	RulesEngine.apply_action(state, best_act)

static func _evaluate_state(state: GameState, my_idx: int, persona: String) -> float:
	var me := state.players[my_idx]
	var my_score := me.get_score()
	var target := state.target_prestige

	# Persona multipliers
	var w_discount := 1.35 if persona == "artisan" else 1.0
	var w_prestige := 1.25 if persona == "collector" else 1.0
	var w_master := 1.45 if persona == "scholar" else 1.0
	var w_threat := 1.50 if persona == "interceptor" else 1.0

	var score_val := float(my_score) * 32.0 * w_prestige
	if my_score >= target:
		score_val += 2000.0 - float(me.purchased.size()) * 2.0
	if state.phase == GameState.TurnPhase.GAME_OVER:
		if state.winner_indices.has(my_idx):
			return 5000.0 + float(my_score)
		return -2000.0 + float(my_score)

	# Permanent discounts are much more valuable than temporary chips
	var late_factor := clampf(1.0 - float(my_score) / float(maxi(1, target)) * 0.55, 0.45, 1.0)
	var disc_total := 0
	for g in GemTypes.BASE_GEMS:
		disc_total += int(me.discounts[g])
	var engine_val := float(disc_total) * 18.5 * late_factor * w_discount

	# Master proximity
	var master_val := float(me.masters.size()) * 24.0
	for m in state.masters:
		var missing := 0
		for g in m.requirements.keys():
			missing += maxi(0, int(m.requirements[g]) - int(me.discounts.get(g, 0)))
		if missing == 0:
			master_val += 36.0 * w_master
		elif missing == 1:
			master_val += 14.0 * w_master
		elif missing == 2:
			master_val += 5.0 * w_master

	# Next-turn buyability (focus on best 2 targets)
	var card_pot := 0.0
	var best_cards: Array[float] = []
	for c in me.reserved:
		var pay := me.compute_payment(c)
		var sh := int(pay["gold_shortage"])
		var v := (12.0 + float(c.prestige) * 7.5) / float(maxi(1, sh + 1))
		if sh == 0:
			v += 14.0
		best_cards.append(v)

	for tier in [3, 2, 1]:
		for slot in range(4):
			var c: CardData.CraftCard = state.board[tier][slot]
			if c == null:
				continue
			var pay := me.compute_payment(c)
			var sh := int(pay["gold_shortage"])
			if sh > 4:
				continue
			var v := (10.0 + float(c.prestige) * 7.0) / float(maxi(1, sh + 1))
			if sh == 0:
				v += 12.0
			best_cards.append(v)

	best_cards.sort()
	best_cards.reverse()
	for i in range(mini(2, best_cards.size())):
		card_pot += best_cards[i] * (1.0 if i == 0 else 0.4)

	# Temporary chips: modest value, discourage hoarding near cap
	var chip_tot := me.total_chips()
	var gold_cnt := int(me.chips.get(GemTypes.GOLD, 0))
	var chip_val := float(chip_tot) * 0.9 + float(gold_cnt) * 1.4
	if chip_tot >= 9:
		chip_val -= float(chip_tot - 8) * 2.8
	# Slight penalty for holding reserved cards unless close to buying them
	var res_pen := float(me.reserved.size()) * 2.5

	# Rival threat penalty: penalize leaving high-value cards buyable by a leading rival
	var threat_pen := 0.0
	for opp in state.players:
		if opp.index == my_idx:
			continue
		var opp_score := opp.get_score()
		if opp_score < target - 6:
			continue
		for tier in [3, 2]:
			for slot in range(4):
				var c: CardData.CraftCard = state.board[tier][slot]
				if c != null and c.prestige >= 2 and opp.can_afford(c):
					var win_threat := 35.0 if (opp_score + c.prestige >= target) else 6.0
					threat_pen += (float(c.prestige) * 2.5 + win_threat) * 0.45 * w_threat

	return score_val + engine_val + master_val + card_pot + chip_val - res_pen - threat_pen

static func _clone_state_fast(src: GameState) -> GameState:
	var dst := GameState.new()
	dst.rng_seed = src.rng_seed
	dst.target_prestige = src.target_prestige
	dst.bank = src.bank.duplicate()
	for t in [1, 2, 3]:
		dst.decks[t] = src.decks[t].duplicate()
		dst.board[t] = src.board[t].duplicate()
	dst.masters = src.masters.duplicate()
	dst.pending_masters = src.pending_masters.duplicate()
	dst.current_player_idx = src.current_player_idx
	dst.round_number = src.round_number
	dst.final_round_triggered = src.final_round_triggered
	dst.phase = src.phase
	dst.winner_indices = src.winner_indices.duplicate()
	for p in src.players:
		var np := PlayerState.new(p.index, p.name, p.is_ai, p.ai_level, p.ai_persona)
		np.chips = p.chips.duplicate()
		np.discounts = p.discounts.duplicate()
		np.purchased = p.purchased.duplicate()
		np.reserved = p.reserved.duplicate()
		np.masters = p.masters.duplicate()
		dst.players.append(np)
	return dst

# =============================================================================
# Level 0 (Easy) & Level 1 (Normal) Heuristic AI
# =============================================================================

static func _do_action(state: GameState) -> void:
	var p := state.current_player()

	var best_buy: Dictionary = {"score": -9999.0, "type": "", "tier": 0, "slot": -1, "res_idx": -1}

	for i in range(p.reserved.size()):
		var card := p.reserved[i]
		if p.can_afford(card):
			var sc := _score_buy(state, p, card) + 0.35
			if sc > float(best_buy["score"]):
				best_buy = {"score": sc, "type": "reserved", "res_idx": i}

	for tier in [3, 2, 1]:
		for slot in range(4):
			var card: CardData.CraftCard = state.board[tier][slot]
			if card != null and p.can_afford(card):
				var sc := _score_buy(state, p, card)
				if sc > float(best_buy["score"]):
					best_buy = {"score": sc, "type": "board", "tier": tier, "slot": slot}

	if best_buy["type"] == "reserved":
		RulesEngine.buy_reserved(state, int(best_buy["res_idx"]))
		return
	elif best_buy["type"] == "board":
		RulesEngine.buy_board(state, int(best_buy["tier"]), int(best_buy["slot"]))
		return

	if p.ai_level >= 1 and p.reserved.size() < GameState.MAX_RESERVED and p.total_chips() <= 9:
		var reserve_target := _pick_reserve_target(state, p)
		if not reserve_target.is_empty():
			RulesEngine.reserve_board(state, int(reserve_target["tier"]), int(reserve_target["slot"]))
			return

	var gem_weights := _compute_gem_weights(state, p)
	var avail := RulesEngine.available_base_gem_types(state)

	if p.ai_level >= 1 and p.total_chips() <= 8:
		var best_two_gem := ""
		var best_two_w: float = -1.0
		for g in avail:
			if int(state.bank[g]) >= 4 and float(gem_weights[g]) > best_two_w:
				best_two_w = float(gem_weights[g])
				best_two_gem = g
		if best_two_gem != "" and (avail.size() < 3 or best_two_w >= 2.6):
			var res := RulesEngine.take_two_same(state, best_two_gem)
			if bool(res["ok"]):
				return

	if not avail.is_empty():
		var sorted_avail := avail.duplicate()
		if p.ai_level == 0:
			sorted_avail.shuffle() # Easy AI picks less optimally
		else:
			sorted_avail.sort_custom(func(a: String, b: String) -> bool:
				return float(gem_weights[a]) > float(gem_weights[b])
			)
		var take_n := mini(3, sorted_avail.size())
		var chosen: Array[String] = []
		for i in range(take_n):
			chosen.append(sorted_avail[i])
		var res := RulesEngine.take_different(state, chosen)
		if bool(res["ok"]):
			return

	if p.reserved.size() < GameState.MAX_RESERVED:
		for tier in [2, 1, 3]:
			for slot in range(4):
				if state.board[tier][slot] != null:
					RulesEngine.reserve_board(state, tier, slot)
					return
			if not state.decks[tier].is_empty():
				RulesEngine.reserve_deck(state, tier)
				return

	RulesEngine.pass_turn(state)

static func _score_buy(state: GameState, p: PlayerState, card: CardData.CraftCard) -> float:
	var pay_info := p.compute_payment(card)
	var gold_spent := int(pay_info["payment"][GemTypes.GOLD])
	var master_syn := _master_synergy(state, p, card.bonus)
	if p.ai_level == 0:
		return card.prestige * 1.8 + 0.5 - gold_spent * 0.1
	return card.prestige * 3.2 + master_syn * 2.0 + 1.3 - gold_spent * 0.35 + (0.2 if p.get_score() + card.prestige >= state.target_prestige else 0.0)

static func _master_synergy(state: GameState, p: PlayerState, bonus: String) -> float:
	var syn: float = 0.0
	for m in state.masters:
		var req := int(m.requirements.get(bonus, 0))
		if req > 0 and int(p.discounts[bonus]) < req:
			syn += 1.0 / float(maxi(1, req - int(p.discounts[bonus])))
	return syn

static func _pick_reserve_target(state: GameState, p: PlayerState) -> Dictionary:
	var best_tier := -1
	var best_slot := -1
	var best_val: float = 0.0
	for tier in [3, 2]:
		for slot in range(4):
			var card: CardData.CraftCard = state.board[tier][slot]
			if card == null or card.prestige < 2:
				continue
			var pay := p.compute_payment(card)
			var shortage := int(pay["gold_shortage"])
			if shortage <= 2:
				var val := float(card.prestige) * 1.5 - float(shortage) * 1.1 + _master_synergy(state, p, card.bonus)
				if val > best_val and int(state.bank[GemTypes.GOLD]) > 0:
					best_val = val
					best_tier = tier
					best_slot = slot
	if best_tier != -1 and best_val >= 2.8:
		return {"tier": best_tier, "slot": best_slot}
	return {}

static func _compute_gem_weights(state: GameState, p: PlayerState) -> Dictionary:
	var w: Dictionary = {}
	for g in GemTypes.BASE_GEMS:
		w[g] = 0.1 + float(int(state.bank[g])) * 0.02

	var candidates: Array[CardData.CraftCard] = []
	for c in p.reserved:
		candidates.append(c)
	for tier in [1, 2, 3]:
		for slot in range(4):
			var c: CardData.CraftCard = state.board[tier][slot]
			if c != null:
				candidates.append(c)

	for c in candidates:
		var pay := p.compute_payment(c)
		var shortage_total := int(pay["gold_shortage"])
		if shortage_total > 5 and c.tier == 3:
			continue
		var priority := (1.0 / float(maxi(1, shortage_total))) * (1.2 + float(c.prestige) * 0.6)
		if p.reserved.has(c):
			priority *= 1.8
		var sf: Dictionary = pay["shortfall"]
		for g in GemTypes.BASE_GEMS:
			if int(sf[g]) > 0:
				w[g] += priority * float(mini(2, int(sf[g])))
	return w

static func _do_discard(state: GameState) -> void:
	var p := state.current_player()
	var excess := p.total_chips() - GameState.MAX_CHIPS
	var weights := _compute_gem_weights(state, p)
	var to_return := GemTypes.create_empty_pool(true)

	var pool_list: Array[String] = []
	for g in GemTypes.BASE_GEMS:
		for _i in range(int(p.chips[g])):
			pool_list.append(g)
	pool_list.sort_custom(func(a: String, b: String) -> bool:
		return float(weights[a]) < float(weights[b])
	)
	for _i in range(int(p.chips[GemTypes.GOLD])):
		pool_list.append(GemTypes.GOLD)

	for i in range(mini(excess, pool_list.size())):
		var g := pool_list[i]
		to_return[g] += 1

	RulesEngine.discard_chips(state, to_return)

static func _do_choose_master(state: GameState) -> void:
	if state.pending_masters.is_empty():
		return
	var best_m := state.pending_masters[0]
	for m in state.pending_masters:
		if m.prestige > best_m.prestige:
			best_m = m
	RulesEngine.choose_master(state, best_m.id)
