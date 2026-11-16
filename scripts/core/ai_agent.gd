class_name AIAgent
extends RefCounted

static func take_turn_step(state: GameState) -> void:
	match state.phase:
		GameState.TurnPhase.ACTION:
			_do_action(state)
		GameState.TurnPhase.DISCARD_CHIPS:
			_do_discard(state)
		GameState.TurnPhase.CHOOSE_MASTER:
			_do_choose_master(state)

static func _do_action(state: GameState) -> void:
	var p := state.current_player()

	# 1. Evaluate all buyable cards (board + reserved)
	var best_buy: Dictionary = {"score": -9999.0, "type": "", "tier": 0, "slot": -1, "res_idx": -1}

	for i in range(p.reserved.size()):
		var card := p.reserved[i]
		if p.can_afford(card):
			var sc := _score_buy(state, p, card) + 0.35 # slight bonus for freeing reserve slot
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

	# 2. If hard AI and has < 3 reserved and sees a high-value almost-affordable card (or rival threat), consider reserving
	if p.ai_level >= 1 and p.reserved.size() < GameState.MAX_RESERVED and p.total_chips() <= 9:
		var reserve_target := _pick_reserve_target(state, p)
		if not reserve_target.is_empty():
			RulesEngine.reserve_board(state, int(reserve_target["tier"]), int(reserve_target["slot"]))
			return

	# 3. Take chips toward best target cards
	var gem_weights := _compute_gem_weights(state, p)
	var avail := RulesEngine.available_base_gem_types(state)

	# Consider taking 2 same if one gem is heavily needed and bank >= 4
	if p.total_chips() <= 8:
		var best_two_gem := ""
		var best_two_w: float = -1.0
		for g in avail:
			if int(state.bank[g]) >= 4 and float(gem_weights[g]) > best_two_w:
				best_two_w = float(gem_weights[g])
				best_two_gem = g
		# Only take 2 same if it's notably better than spreading 3
		if best_two_gem != "" and (avail.size() < 3 or best_two_w >= 2.6):
			var res := RulesEngine.take_two_same(state, best_two_gem)
			if bool(res["ok"]):
				return

	# Otherwise take up to 3 different base gems sorted by weight
	if not avail.is_empty():
		var sorted_avail := avail.duplicate()
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

	# 4. Fallback: reserve any board card or deck if bank empty
	if p.reserved.size() < GameState.MAX_RESERVED:
		for tier in [2, 1, 3]:
			for slot in range(4):
				if state.board[tier][slot] != null:
					RulesEngine.reserve_board(state, tier, slot)
					return
			if not state.decks[tier].is_empty():
				RulesEngine.reserve_deck(state, tier)
				return

static func _score_buy(state: GameState, p: PlayerState, card: CardData.CraftCard) -> float:
	var pay_info := p.compute_payment(card)
	var gold_spent := int(pay_info["payment"][GemTypes.GOLD])
	var master_syn := _master_synergy(state, p, card.bonus)
	if p.ai_level == 0:
		return card.prestige * 2.5 + 1.0 - gold_spent * 0.2
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

	# Look at reserved cards first, then board tier 1 & 2
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

	# Build a list of individual chips owned, sorted from least useful to most useful
	var pool_list: Array[String] = []
	for g in GemTypes.BASE_GEMS:
		for _i in range(int(p.chips[g])):
			pool_list.append(g)
	pool_list.sort_custom(func(a: String, b: String) -> bool:
		return float(weights[a]) < float(weights[b])
	)
	for _i in range(int(p.chips[GemTypes.GOLD])):
		pool_list.append(GemTypes.GOLD) # discard gold only as absolute last resort

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
