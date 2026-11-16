extends SceneTree
## Headless benchmark: Grandmaster AI (level 2) vs Artisan AI (level 1).
## Usage: godot --headless --path . --script res://tools/ai_benchmark.gd

const GAMES := 60

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var gm_wins := 0
	var mid_wins := 0
	var ties := 0

	for g in range(GAMES):
		var gm_first := (g % 2 == 0)
		var cfgs: Array = [
			{"name": "宗师", "is_ai": true, "ai_level": 2 if gm_first else 1, "ai_persona": "balanced"},
			{"name": "匠师", "is_ai": true, "ai_level": 1 if gm_first else 2, "ai_persona": "balanced"},
		]
		var s := RulesEngine.create_game(cfgs, 15, 50000 + g)
		var steps := 0
		while s.phase != GameState.TurnPhase.GAME_OVER and steps < 500:
			AIAgent.take_turn_step(s)
			steps += 1
		if s.phase == GameState.TurnPhase.GAME_OVER:
			var gm_idx := 0 if gm_first else 1
			var mid_idx := 1 if gm_first else 0
			if s.winner_indices.size() > 1:
				ties += 1
			elif s.winner_indices.has(gm_idx):
				gm_wins += 1
			elif s.winner_indices.has(mid_idx):
				mid_wins += 1

	var elapsed := float(Time.get_ticks_msec() - t0) / 1000.0
	var win_pct := 100.0 * float(gm_wins) / float(GAMES)
	print("Grandmaster (L2) vs Artisan (L1) over %d games: GM=%d (%.1f%%), Artisan=%d, Ties=%d (%.2fs)" % [
		GAMES, gm_wins, win_pct, mid_wins, ties, elapsed
	])
	quit(0 if win_pct >= 65.0 else 1)
