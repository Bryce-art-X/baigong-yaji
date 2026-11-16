class_name CardData
extends RefCounted

class CraftCard:
	var id: String
	var name: String
	var tier: int
	var bonus: String
	var prestige: int
	var cost: Dictionary

	func _init(p_id: String, p_name: String, p_tier: int, p_bonus: String, p_prestige: int, p_cost: Dictionary) -> void:
		id = p_id
		name = p_name
		tier = p_tier
		bonus = p_bonus
		prestige = p_prestige
		cost = {}
		for g in GemTypes.BASE_GEMS:
			var v := int(p_cost.get(g, 0))
			if v > 0:
				cost[g] = v

	static func from_dict(d: Dictionary) -> CraftCard:
		return CraftCard.new(
			str(d.get("id", "")),
			str(d.get("name", "")),
			int(d.get("tier", 1)),
			str(d.get("bonus", "jade")),
			int(d.get("prestige", 0)),
			d.get("cost", {})
		)

class MasterTile:
	var id: String
	var name: String
	var title: String
	var prestige: int
	var requirements: Dictionary

	func _init(p_id: String, p_name: String, p_title: String, p_prestige: int, p_req: Dictionary) -> void:
		id = p_id
		name = p_name
		title = p_title
		prestige = p_prestige
		requirements = {}
		for g in GemTypes.BASE_GEMS:
			var v := int(p_req.get(g, 0))
			if v > 0:
				requirements[g] = v

	static func from_dict(d: Dictionary) -> MasterTile:
		return MasterTile.new(
			str(d.get("id", "")),
			str(d.get("name", "")),
			str(d.get("title", "")),
			int(d.get("prestige", 3)),
			d.get("requirements", {})
		)
