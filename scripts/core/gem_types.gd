class_name GemTypes
extends RefCounted

const BASE_GEMS: Array[String] = ["jade", "porcelain", "bamboo", "cinnabar", "ink"]
const ALL_GEMS: Array[String] = ["jade", "porcelain", "bamboo", "cinnabar", "ink", "gold"]
const GOLD: String = "gold"

const NAMES_ZH: Dictionary = {
	"jade": "和田玉",
	"porcelain": "青瓷",
	"bamboo": "翠竹",
	"cinnabar": "朱砂",
	"ink": "松烟墨",
	"gold": "赤金",
}

const SHORT_ZH: Dictionary = {
	"jade": "玉",
	"porcelain": "瓷",
	"bamboo": "竹",
	"cinnabar": "砂",
	"ink": "墨",
	"gold": "金",
}

const COLORS: Dictionary = {
	"jade": Color("EAE2D0"),
	"porcelain": Color("2E6B9E"),
	"bamboo": Color("2F7E5B"),
	"cinnabar": Color("B33932"),
	"ink": Color("323036"),
	"gold": Color("D6A438"),
}

const TEXT_COLORS: Dictionary = {
	"jade": Color("241E1A"),
	"porcelain": Color("F7F3EB"),
	"bamboo": Color("F7F3EB"),
	"cinnabar": Color("F7F3EB"),
	"ink": Color("F7F3EB"),
	"gold": Color("241E1A"),
}

static func create_empty_pool(include_gold: bool = true) -> Dictionary:
	var pool: Dictionary = {}
	var keys := ALL_GEMS if include_gold else BASE_GEMS
	for g in keys:
		pool[g] = 0
	return pool

static func total_count(pool: Dictionary) -> int:
	var sum: int = 0
	for k in pool.keys():
		sum += int(pool[k])
	return sum

static func gem_name(gem: String) -> String:
	return str(NAMES_ZH.get(gem, gem))

static func gem_short(gem: String) -> String:
	return str(SHORT_ZH.get(gem, gem))

static func gem_color(gem: String) -> Color:
	return COLORS.get(gem, Color.GRAY)

static func gem_text_color(gem: String) -> Color:
	return TEXT_COLORS.get(gem, Color.WHITE)
