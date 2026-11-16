class_name GameAction
extends RefCounted
## A single player decision. Serializable to a plain Dictionary so it can be
## stored in history (undo / replay / daily challenge) or sent over the
## network later (see scripts/core/net/).

enum Type {
	TAKE_DIFFERENT, # gems: Array[String]
	TAKE_TWO,       # gem: String
	RESERVE_BOARD,  # tier: int, slot: int
	RESERVE_DECK,   # tier: int
	BUY_BOARD,      # tier: int, slot: int
	BUY_RESERVED,   # index: int
	DISCARD,        # chips: Dictionary gem -> int
	CHOOSE_MASTER,  # master_id: String
	PASS,           # only legal when no other action is possible
}

const TYPE_KEYS: Array[String] = [
	"take_different", "take_two", "reserve_board", "reserve_deck",
	"buy_board", "buy_reserved", "discard", "choose_master", "pass",
]

var type: Type
var player: int = -1 # filled in by RulesEngine when applied
var params: Dictionary = {}

func _init(p_type: Type = Type.PASS, p_params: Dictionary = {}) -> void:
	type = p_type
	params = p_params

func key() -> String:
	return TYPE_KEYS[type]

func to_dict() -> Dictionary:
	var d := params.duplicate(true)
	d["t"] = key()
	d["p"] = player
	return d

static func from_dict(d: Dictionary) -> GameAction:
	var idx := TYPE_KEYS.find(str(d.get("t", "pass")))
	var params := d.duplicate(true)
	params.erase("t")
	params.erase("p")
	# JSON turns ints into floats; normalise known int fields.
	for k in ["tier", "slot", "index"]:
		if params.has(k):
			params[k] = int(params[k])
	if params.has("chips"):
		var c: Dictionary = {}
		for g in params["chips"].keys():
			c[str(g)] = int(params["chips"][g])
		params["chips"] = c
	if params.has("gems"):
		var arr: Array[String] = []
		for g in params["gems"]:
			arr.append(str(g))
		params["gems"] = arr
	var a := GameAction.new(maxi(idx, 0) as Type, params)
	a.player = int(d.get("p", -1))
	return a

func describe() -> String:
	return "%s %s" % [key(), str(params)]

# --- Convenience constructors ------------------------------------------------

static func take_different(gems: Array) -> GameAction:
	var arr: Array[String] = []
	for g in gems:
		arr.append(str(g))
	return GameAction.new(Type.TAKE_DIFFERENT, {"gems": arr})

static func take_two(gem: String) -> GameAction:
	return GameAction.new(Type.TAKE_TWO, {"gem": gem})

static func reserve_board(tier: int, slot: int) -> GameAction:
	return GameAction.new(Type.RESERVE_BOARD, {"tier": tier, "slot": slot})

static func reserve_deck(tier: int) -> GameAction:
	return GameAction.new(Type.RESERVE_DECK, {"tier": tier})

static func buy_board(tier: int, slot: int) -> GameAction:
	return GameAction.new(Type.BUY_BOARD, {"tier": tier, "slot": slot})

static func buy_reserved(index: int) -> GameAction:
	return GameAction.new(Type.BUY_RESERVED, {"index": index})

static func discard(chips: Dictionary) -> GameAction:
	return GameAction.new(Type.DISCARD, {"chips": chips.duplicate()})

static func choose_master(master_id: String) -> GameAction:
	return GameAction.new(Type.CHOOSE_MASTER, {"master_id": master_id})

static func pass_turn() -> GameAction:
	return GameAction.new(Type.PASS, {})
