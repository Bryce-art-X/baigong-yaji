extends SceneTree

var passed: int = 0
var failed: int = 0

func _check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("[PASS] " + label)
	else:
		failed += 1
		printerr("[FAIL] %s%s" % [label, " — " + detail if detail != "" else ""])

func _init() -> void:
	# 1. Data integrity & 5-way symmetry
	var raw := RulesEngine.load_raw_data()
	var cards: Array = raw.get("cards", [])
	var masters: Array = raw.get("masters", [])
	_check(cards.size() == 90 and masters.size() == 10, "Data loaded: 90 craft cards, 10 masters")

	var bonus_counts := GemTypes.create_empty_pool(false)
	for c in cards:
		bonus_counts[str(c["bonus"])] += 1
	var sym_ok := true
	for g in GemTypes.BASE_GEMS:
		if int(bonus_counts[g]) != 18:
			sym_ok = false
	_check(sym_ok, "All 5 base materials have 18 cards each")

	# 2. Setup 2P game & basic rules
	var ctrl := GameController.new_game([
		{"name": "甲", "is_ai": false},
		{"name": "乙", "is_ai": true, "ai_level": 1}
	], 15, 12345)
	var state := ctrl.state
	_check(state.bank["jade"] == 4 and state.bank["gold"] == 5 and state.masters.size() == 3,
		"2P bank (4 base, 5 gold) & 3 masters")

	# Take 3 different
	var r1 := ctrl.apply(GameAction.take_different(["jade", "porcelain", "bamboo"]))
	_check(bool(r1["ok"]) and state.players[0].chips["jade"] == 1 and state.bank["jade"] == 3,
		"Take 3 different gems")
	_check(r1["events"].size() >= 2, "Take action emits domain events")

	# Negative: take 2 same when bank < 4
	var r2_bad := ctrl.apply(GameAction.take_two("jade"))
	_check(not bool(r2_bad["ok"]), "Rejected take 2 same when bank < 4")

	# Positive: take 2 same when bank >= 4
	var r2_ok := ctrl.apply(GameAction.take_two("cinnabar"))
	_check(bool(r2_ok["ok"]) and state.players[1].chips["cinnabar"] == 2 and state.bank["cinnabar"] == 2,
		"Take 2 same when bank >= 4")

	# Negative: cannot pass when legal moves exist
	_check(not bool(ctrl.apply(GameAction.pass_turn())["ok"]), "Rejected pass when legal moves exist")

	# Undo last human action
	_check(ctrl.undo_last_human_action() and ctrl.state.history.is_empty() and ctrl.state.players[0].chips["jade"] == 0,
		"GameController.undo_last_human_action rewinds cleanly")

	# 3. Edge cases: < 3 base gem types left in bank
	var edge_state := RulesEngine.create_game([
		{"name": "A", "is_ai": false},
		{"name": "B", "is_ai": false}
	], 15, 99)
	edge_state.bank["jade"] = 0
	edge_state.bank["porcelain"] = 0
	edge_state.bank["bamboo"] = 0
	var r_two_diff := RulesEngine.take_different(edge_state, ["cinnabar", "ink"])
	_check(bool(r_two_diff["ok"]), "Allowed taking 2 different when only 2 base types remain in bank")

	# 4. Discard > 10 chips validation (negative & positive)
	var disc_state := RulesEngine.create_game([
		{"name": "A", "is_ai": false},
		{"name": "B", "is_ai": false}
	], 15, 77)
	disc_state.players[0].chips["jade"] = 4
	disc_state.players[0].chips["porcelain"] = 4
	disc_state.players[0].chips["bamboo"] = 1 # total 9 -> take 3 -> 12 -> excess 2
	var r_over := RulesEngine.take_different(disc_state, ["jade", "cinnabar", "ink"])
	_check(bool(r_over["ok"]) and disc_state.phase == GameState.TurnPhase.DISCARD_CHIPS,
		"Exceeding 10 chips enters DISCARD_CHIPS phase")
	_check(not bool(RulesEngine.discard_chips(disc_state, {"jade": 1})["ok"]),
		"Rejected discarding wrong number of chips")
	_check(bool(RulesEngine.discard_chips(disc_state, {"jade": 1, "bamboo": 1})["ok"]) and disc_state.players[0].total_chips() == 10,
		"Accepted exact excess discard back to 10")

	# 5. Legal PASS when deadlocked (bank empty, reserved full, nothing affordable)
	var pass_state := RulesEngine.create_game([
		{"name": "A", "is_ai": false},
		{"name": "B", "is_ai": false}
	], 15, 55)
	for g in GemTypes.BASE_GEMS:
		pass_state.bank[g] = 0
	for _i in range(3):
		pass_state.players[0].reserved.append(pass_state.board[3][0])
	var legal := RulesEngine.legal_actions(pass_state)
	_check(legal.size() == 1 and legal[0].type == GameAction.Type.PASS,
		"legal_actions returns PASS when no other action is possible")
	_check(bool(RulesEngine.pass_turn(pass_state)["ok"]) and pass_state.current_player_idx == 1,
		"PASS advances turn cleanly")

	# 6. 4P AI simulation + replay determinism
	var sim_cfgs: Array = [
		{"name": "AI-1", "is_ai": true, "ai_level": 1},
		{"name": "AI-2", "is_ai": true, "ai_level": 1},
		{"name": "AI-3", "is_ai": true, "ai_level": 0},
		{"name": "AI-4", "is_ai": true, "ai_level": 1},
	]
	var sim_state := RulesEngine.create_game(sim_cfgs, 15, 2026)
	var safety: int = 0
	while sim_state.phase != GameState.TurnPhase.GAME_OVER and safety < 600:
		AIAgent.take_turn_step(sim_state)
		safety += 1
	_check(sim_state.phase == GameState.TurnPhase.GAME_OVER and not sim_state.winner_indices.is_empty(),
		"4P AI simulation finished in %d steps, round %d" % [safety, sim_state.round_number])

	var replayed := RulesEngine.replay(sim_state.rng_seed, sim_state.config, sim_state.history)
	_check(replayed.phase == GameState.TurnPhase.GAME_OVER and replayed.winner_indices == sim_state.winner_indices and replayed.round_number == sim_state.round_number,
		"RulesEngine.replay reproduces identical game outcome from seed + history")

	# 7. SaveManager serialize/deserialize roundtrip
	var snap := SaveManager.serialize_state(sim_state)
	var restored := SaveManager.deserialize_state(snap)
	_check(restored.rng_seed == sim_state.rng_seed and restored.history.size() == sim_state.history.size(),
		"SaveManager preserves rng_seed and full action history")

	print("=== Tests: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
