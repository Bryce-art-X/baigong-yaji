extends SceneTree
## Rebuilds data/craft_data.json with our original, 5-way cyclically symmetric
## cost/prestige curve while preserving all 90 Chinese craft names and 10 Masters.
##
## Usage: godot --headless --path . --script res://tools/rebuild_craft_data.gd

const GEMS: Array[String] = ["jade", "porcelain", "bamboo", "cinnabar", "ink"]

# Classic Splendor 90-card distribution (exact 5-way cyclic symmetry).
# Offset 0 = same color as bonus, 1..4 = cyclic offsets.
const TIER1_TEMPLATES: Array = [
	[0, {1: 1, 2: 1, 3: 1, 4: 1}],  # 1,1,1,1
	[0, {1: 1, 2: 1, 3: 2, 4: 1}],  # 1,1,2,1
	[0, {1: 2, 2: 2}],              # 2,2
	[0, {1: 2, 4: 1}],              # 2,1
	[0, {1: 3}],                    # 3
	[0, {0: 1, 1: 3, 2: 1}],        # 1,3,1 (incl. own)
	[0, {3: 2, 4: 1}],              # 2,1
	[1, {2: 4}],                    # 4 (1pt)
]

const TIER2_TEMPLATES: Array = [
	[1, {1: 2, 2: 2, 3: 3}],        # 2,2,3 (1pt)
	[1, {0: 2, 2: 3, 4: 3}],        # 2,3,3 (1pt, incl. own)
	[2, {1: 1, 2: 4, 3: 2}],        # 1,4,2 (2pt)
	[2, {3: 3, 4: 5}],              # 3,5 (2pt)
	[2, {1: 5}],                    # 5 (2pt)
	[3, {0: 6}],                    # 6 own (3pt)
]

const TIER3_TEMPLATES: Array = [
	[3, {1: 3, 2: 3, 3: 5, 4: 3}],  # 3,3,5,3 (3pt)
	[4, {4: 7}],                    # 7 (4pt)
	[4, {0: 3, 3: 3, 4: 6}],        # 3,6,3 (4pt)
	[5, {0: 3, 4: 7}],              # 3,7 (5pt)
]

func _init() -> void:
	var raw := RulesEngine.load_raw_data()
	var old_cards: Array = raw.get("cards", [])
	var by_tier_bonus: Dictionary = {}
	for c in old_cards:
		var key := "%d_%s" % [int(c["tier"]), str(c["bonus"])]
		if not by_tier_bonus.has(key):
			by_tier_bonus[key] = []
		by_tier_bonus[key].append(str(c["name"]))

	var new_cards: Array = []
	var tier_specs := {1: TIER1_TEMPLATES, 2: TIER2_TEMPLATES, 3: TIER3_TEMPLATES}

	for tier in [1, 2, 3]:
		var templates: Array = tier_specs[tier]
		var idx_counter := 1
		for gi in range(GEMS.size()):
			var bonus := GEMS[gi]
			var names: Array = by_tier_bonus.get("%d_%s" % [tier, bonus], [])
			for ti in range(templates.size()):
				var tmpl: Array = templates[ti]
				var prestige := int(tmpl[0])
				var offsets: Dictionary = tmpl[1]
				var cost: Dictionary = {}
				for off in offsets.keys():
					var target_gem := GEMS[(gi + int(off)) % GEMS.size()]
					cost[target_gem] = int(offsets[off])
				var card_name := str(names[ti]) if ti < names.size() else "器物_%d_%d" % [tier, idx_counter]
				new_cards.append({
					"id": "t%d_%02d" % [tier, idx_counter],
					"tier": tier,
					"bonus": bonus,
					"prestige": prestige,
					"name": card_name,
					"cost": cost,
				})
				idx_counter += 1

	var out := {
		"cards": new_cards,
		"masters": raw.get("masters", []),
	}
	var f := FileAccess.open("res://data/craft_data.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ") + "\n")
	print("Rebuilt craft_data.json: %d cards, %d masters" % [new_cards.size(), out["masters"].size()])
	quit(0)
