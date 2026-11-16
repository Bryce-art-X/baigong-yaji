class_name GameState
extends RefCounted

enum TurnPhase {
	ACTION,        # Normal turn: take chips / reserve / buy / pass
	DISCARD_CHIPS, # Player has > 10 chips, must return excess
	CHOOSE_MASTER, # Multiple masters eligible, player chooses 1
	GAME_OVER      # Game finished
}

const MAX_CHIPS: int = 10
const MAX_RESERVED: int = 3

## Setup inputs. Together with `history` they fully reproduce a game.
var rng_seed: int = 0
var config: Dictionary = {}   # {"players": [...], "target": int}

var target_prestige: int = 15
var bank: Dictionary
var decks: Dictionary = {1: [], 2: [], 3: []} # tier -> Array[CraftCard]; draw = pop_back
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

## Every successfully applied action, as GameAction dictionaries.
var history: Array = []

## Transient: domain events produced by the action currently being applied.
## Not serialized. Read & cleared by GameController / RulesEngine.apply_action.
var events: Array = []

func current_player() -> PlayerState:
	return players[current_player_idx]

func log_event(msg: String) -> void:
	action_log.append(msg)
	if action_log.size() > 60:
		action_log.pop_front()

func emit(type: String, data: Dictionary = {}) -> void:
	var e := data.duplicate()
	e["type"] = type
	events.append(e)
