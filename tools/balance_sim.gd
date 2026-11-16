extends SceneTree
## Headless balance simulator. Runs N AI-vs-AI games for 2P, 3P and 4P and
## prints summary statistics (round length, seat win rates, gem balance, tier mix).
##
## Usage: godot --headless --path . --script res://tools/balance_sim.gd

const GAMES_PER_COUNT := 200

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var report: Array[String] = []
	report.append("# 《百工雅集》数值平衡模拟报告\n")
	report.append("- 模拟样本：2 人 / 3 人 / 4 人局各 %d 场（共 %d 场）" % [GAMES_PER_COUNT, GAMES_PER_COUNT * 3])
	report.append("- 胜负目标：15 声望，全员使用匠师 AI（进阶）\n")

	for p_count in [2, 3, 4]:
		var stats := _simulate_batch(p_count, GAMES_PER_COUNT)
		report.append("## %d 人局统计" % p_count)
		report.append("- 平均局长：**%.1f 轮**（范围 %d ~ %d 轮）" % [stats["avg_rounds"], stats["min_rounds"], stats["max_rounds"]])
		report.append("- 完赛率：%d / %d（平局/多人并列 %d 场）" % [stats["finished"], GAMES_PER_COUNT, stats["ties"]])

		var seat_parts: Array[String] = []
		var expected := 100.0 / float(p_count)
		var max_dev: float = 0.0
		for i in range(p_count):
			var pct := 100.0 * float(stats["seat_wins"][i]) / float(maxi(1, stats["finished"]))
			max_dev = maxf(max_dev, absf(pct - expected))
			seat_parts.append("席位 %d: %.1f%%" % [i + 1, pct])
		report.append("- 席位胜率：%s（理论均值 %.1f%%，最大偏差 %.1f%%）" % [" | ".join(seat_parts), expected, max_dev])

		var tier_tot: int = stats["tier_buys"][1] + stats["tier_buys"][2] + stats["tier_buys"][3]
		report.append("- 器物打造阶位分布：一阶 %.1f%% · 二阶 %.1f%% · 三阶 %.1f%%" % [
			100.0 * float(stats["tier_buys"][1]) / float(maxi(1, tier_tot)),
			100.0 * float(stats["tier_buys"][2]) / float(maxi(1, tier_tot)),
			100.0 * float(stats["tier_buys"][3]) / float(maxi(1, tier_tot)),
		])
		report.append("- 场均名士亲临：**%.2f 位/局**" % (float(stats["master_visits"]) / float(maxi(1, stats["finished"]))))

		var gem_parts: Array[String] = []
		var gem_tot: int = 0
		for g in GemTypes.BASE_GEMS:
			gem_tot += int(stats["gem_buys"][g])
		for g in GemTypes.BASE_GEMS:
			gem_parts.append("%s %.1f%%" % [GemTypes.gem_name(g), 100.0 * float(stats["gem_buys"][g]) / float(maxi(1, gem_tot))])
		report.append("- 五材打造占比：%s\n" % " · ".join(gem_parts))

	var elapsed := float(Time.get_ticks_msec() - t0) / 1000.0
	report.append("---\n*耗时：%.2f 秒*" % elapsed)

	var text := "\n".join(report)
	print(text)

	var f := FileAccess.open("res://docs/BALANCE_REPORT.md", FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
	quit(0)

func _simulate_batch(p_count: int, n_games: int) -> Dictionary:
	var cfgs: Array = []
	for i in range(p_count):
		cfgs.append({"name": "AI-%d" % (i + 1), "is_ai": true, "ai_level": 1})

	var seat_wins: Array[int] = []
	seat_wins.resize(p_count)
	var total_rounds: int = 0
	var min_rounds: int = 999
	var max_rounds: int = 0
	var finished: int = 0
	var ties: int = 0
	var tier_buys: Dictionary = {1: 0, 2: 0, 3: 0}
	var gem_buys: Dictionary = GemTypes.create_empty_pool(false)
	var master_visits: int = 0

	for g in range(n_games):
		var s := RulesEngine.create_game(cfgs, 15, 10000 + p_count * 1000 + g)
		var steps: int = 0
		while s.phase != GameState.TurnPhase.GAME_OVER and steps < 600:
			AIAgent.take_turn_step(s)
			steps += 1
		if s.phase == GameState.TurnPhase.GAME_OVER:
			finished += 1
			total_rounds += s.round_number
			min_rounds = mini(min_rounds, s.round_number)
			max_rounds = maxi(max_rounds, s.round_number)
			if s.winner_indices.size() > 1:
				ties += 1
			for w in s.winner_indices:
				seat_wins[w] += 1
			for p in s.players:
				master_visits += p.masters.size()
				for c in p.purchased:
					tier_buys[c.tier] += 1
					gem_buys[c.bonus] += 1

	return {
		"finished": finished,
		"ties": ties,
		"avg_rounds": float(total_rounds) / float(maxi(1, finished)),
		"min_rounds": min_rounds,
		"max_rounds": max_rounds,
		"seat_wins": seat_wins,
		"tier_buys": tier_buys,
		"gem_buys": gem_buys,
		"master_visits": master_visits,
	}
