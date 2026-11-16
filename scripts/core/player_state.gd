class_name PlayerState
extends RefCounted

var index: int
var name: String
var is_ai: bool
var ai_level: int = 1 # 0 = 书童(易), 1 = 匠师(中), 2 = 宗师(难)
var ai_persona: String = "balanced" # balanced / artisan / collector / scholar / interceptor

var chips: Dictionary
var discounts: Dictionary
var purchased: Array[CardData.CraftCard] = []
var reserved: Array[CardData.CraftCard] = []
var masters: Array[CardData.MasterTile] = []

func _init(p_index: int, p_name: String, p_is_ai: bool = false, p_ai_level: int = 1, p_persona: String = "balanced") -> void:
	index = p_index
	name = p_name
	is_ai = p_is_ai
	ai_level = p_ai_level
	ai_persona = p_persona
	chips = GemTypes.create_empty_pool(true)
	discounts = GemTypes.create_empty_pool(false)

func total_chips() -> int:
	return GemTypes.total_count(chips)

func get_score() -> int:
	var total: int = 0
	for card in purchased:
		total += card.prestige
	for m in masters:
		total += m.prestige
	return total

func compute_payment(card: CardData.CraftCard) -> Dictionary:
	var payment: Dictionary = GemTypes.create_empty_pool(true)
	var shortfall: Dictionary = GemTypes.create_empty_pool(false)
	var gold_needed: int = 0

	for g in GemTypes.BASE_GEMS:
		var raw_cost: int = int(card.cost.get(g, 0))
		var disc: int = int(discounts.get(g, 0))
		var after_disc: int = maxi(0, raw_cost - disc)
		var owned: int = int(chips.get(g, 0))
		var paid_gem: int = mini(after_disc, owned)
		payment[g] = paid_gem
		var rem: int = after_disc - paid_gem
		if rem > 0:
			shortfall[g] = rem
			gold_needed += rem

	var gold_owned: int = int(chips.get(GemTypes.GOLD, 0))
	var valid: bool = gold_needed <= gold_owned
	payment[GemTypes.GOLD] = gold_needed if valid else gold_owned

	return {
		"valid": valid,
		"payment": payment,
		"shortfall": shortfall,
		"gold_needed": gold_needed,
		"gold_shortage": maxi(0, gold_needed - gold_owned),
	}

func can_afford(card: CardData.CraftCard) -> bool:
	return bool(compute_payment(card)["valid"])

func meets_master(master: CardData.MasterTile) -> bool:
	for g in master.requirements.keys():
		if int(discounts.get(g, 0)) < int(master.requirements[g]):
			return false
	return true
