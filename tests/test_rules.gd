extends SceneTree

func _init() -> void:
	var passed: int = 0
	var failed: int = 0

	# 1. Data integrity test
	var raw := RulesEngine.load_raw_data()
	var cards: Array = raw.get("cards", [])
	var masters: Array = raw.get("masters", [])
	if cards.size() == 90 and masters.size() == 10:
		passed += 1
		print("[PASS] Data loaded: 90 craft cards, 10 masters")
	else:
		failed += 1
		printerr("[FAIL] Expected 90 cards & 10 masters, got %d & %d" % [cards.size(), masters.size()])

	# 2. Setup 2P game & basic rules
	var state := RulesEngine.create_game([
		{"name": "甲", "is_ai": false},
		{"name": "乙", "is_ai": true, "ai_level": 1}
	], 15, 12345)

	if state.bank["jade"] == 4 and state.bank["gold"] == 5 and state.masters.size() == 3:
		passed += 1
		print("[PASS] 2P bank (4 base, 5 gold) & 3 masters")
	else:
		failed += 1
		printerr("[FAIL] 2P setup mismatch")

	# Take 3 different
	var r1 := RulesEngine.take_different(state, ["jade", "porcelain", "bamboo"])
	if bool(r1["ok"]) and state.players[0].chips["jade"] == 1 and state.bank["jade"] == 3:
		passed += 1
		print("[PASS] Take 3 different gems")
	else:
		failed += 1
		printerr("[FAIL] Take 3 different failed: ", r1)

	# Player 1 tries take 2 jade when bank has 3 (< 4) -> should fail
	var r2_bad := RulesEngine.take_two_same(state, "jade")
	if not bool(r2_bad["ok"]):
		passed += 1
		print("[PASS] Rejected take 2 same when bank < 4")
	else:
		failed += 1
		printerr("[FAIL] Should reject take 2 same when bank < 4")

	# Player 1 takes 2 cinnabar (bank has 4)
	var r2_ok := RulesEngine.take_two_same(state, "cinnabar")
	if bool(r2_ok["ok"]) and state.players[1].chips["cinnabar"] == 2 and state.bank["cinnabar"] == 2:
		passed += 1
		print("[PASS] Take 2 same when bank >= 4")
	else:
		failed += 1
		printerr("[FAIL] Take 2 same failed: ", r2_ok)

	# 3. Full AI vs AI simulation (4 players, hard AI)
	var sim_state := RulesEngine.create_game([
		{"name": "AI-1", "is_ai": true, "ai_level": 1},
		{"name": "AI-2", "is_ai": true, "ai_level": 1},
		{"name": "AI-3", "is_ai": true, "ai_level": 0},
		{"name": "AI-4", "is_ai": true, "ai_level": 1},
	], 15, 2026)

	var safety: int = 0
	while sim_state.phase != GameState.TurnPhase.GAME_OVER and safety < 600:
		AIAgent.take_turn_step(sim_state)
		safety += 1

	if sim_state.phase == GameState.TurnPhase.GAME_OVER and not sim_state.winner_indices.is_empty():
		passed += 1
		print("[PASS] 4P AI simulation finished in %d steps, round %d, winners: %s" % [
			safety, sim_state.round_number, str(sim_state.winner_indices)
		])
	else:
		failed += 1
		printerr("[FAIL] 4P AI simulation did not finish (phase=%d, steps=%d)" % [sim_state.phase, safety])

	# 4. SaveManager serialize/deserialize roundtrip
	var snap := SaveManager.serialize_state(state)
	var restored := SaveManager.deserialize_state(snap)
	if restored.players.size() == state.players.size() and restored.bank["jade"] == state.bank["jade"] and restored.masters.size() == state.masters.size():
		passed += 1
		print("[PASS] SaveManager serialize/deserialize roundtrip")
	else:
		failed += 1
		printerr("[FAIL] SaveManager roundtrip mismatch")

	print("=== Tests: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
