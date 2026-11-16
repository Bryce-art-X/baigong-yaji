class_name GameState
extends RefCounted

enum TurnPhase {
	ACTION,        # Normal turn: take chips / reserve / buy
	DISCARD_CHIPS, # Player has > 10 chips, must return excess
	CHOOSE_MASTER, # Multiple masters eligible, player chooses 1
	GAME_OVER      # Game finished
}

const MAX_CHIPS: int = 10
const MAX_RESERVED: int = 3

var target_prestige: int = 15
var bank: Dictionary
var decks: Dictionary = {1: [], 2: [], 3: []} # tier -> Array[CraftCard]
var board: Dictionary = {1: [null, null, null, null], 2: [null, null, null, null], 3: [null, null, null, null]}
var masters: Array[CardData.MasterTile] = []

var players: Array[PlayerState] = []
var current_player_idx: int = 0
var round_number: int = 1
var final_round_triggered: bool = false
var phase: TurnPhase = TurnPhase.ACTION
var pending_masters: Array[CardData.MasterTile] = []
var winner_indices: Array[int] = []
var action_log: Array[String] = []

func current_player() -> PlayerState:
	return players[current_player_idx]

func log_event(msg: String) -> void:
	action_log.append(msg)
	if action_log.size() > 60:
		action_log.pop_front()
