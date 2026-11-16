class_name GameController
extends RefCounted
## Owns a GameState and is the only object the UI / AI / network layers should
## talk to when changing the game. Emits `events_applied` with the domain events
## of each action so presentation layers can animate them in order.

signal events_applied(action: GameAction, events: Array)

var state: GameState
var transport: NetTransport = null # null = local game

func _init(p_state: GameState = null) -> void:
	state = p_state

static func new_game(player_configs: Array, target: int = 15, rng_seed: int = -1) -> GameController:
	return GameController.new(RulesEngine.create_game(player_configs, target, rng_seed))

func apply(action: GameAction) -> Dictionary:
	var res := RulesEngine.apply_action(state, action)
	if bool(res["ok"]):
		if transport != null:
			transport.send_action(action.to_dict())
		events_applied.emit(action, res["events"])
	return res

func legal_actions() -> Array[GameAction]:
	return RulesEngine.legal_actions(state)

func is_over() -> bool:
	return state.phase == GameState.TurnPhase.GAME_OVER

## Rebuild state from seed + the first `n` actions of history.
func rewind_to(n: int) -> void:
	var hist := state.history.slice(0, clampi(n, 0, state.history.size()))
	state = RulesEngine.replay(state.rng_seed, state.config, hist)

## Undo back to just before the most recent action taken by a human player.
## Returns false if there is nothing to undo.
func undo_last_human_action() -> bool:
	for i in range(state.history.size() - 1, -1, -1):
		var d: Dictionary = state.history[i]
		var pi := int(d.get("p", -1))
		if pi >= 0 and pi < state.players.size() and not state.players[pi].is_ai:
			# Rewind to the start of that human's turn (skip back over any
			# discard / choose-master follow-ups that belong to the same turn).
			var start := i
			while start > 0 and int(state.history[start - 1].get("p", -1)) == pi \
					and str(state.history[start].get("t", "")) in ["discard", "choose_master"]:
				start -= 1
			rewind_to(start)
			return true
	return false
