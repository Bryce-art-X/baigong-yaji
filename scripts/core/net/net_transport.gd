class_name NetTransport
extends RefCounted
## Network transport interface (placeholder for P7 online play).
##
## Design: lockstep action sync with host authority.
##   - Every client runs the same deterministic RulesEngine.
##   - A client sends its GameAction dict to the host.
##   - The host validates with RulesEngine.validate(), applies it, and
##     broadcasts it to all peers, which apply it in the same order.
##   - Game setup is shared as (rng_seed, config); late joiners / reconnects
##     receive (rng_seed, config, history) and call RulesEngine.replay().
##
## Concrete implementations to add later: ENetTransport (LAN / direct IP),
## SteamTransport (GodotSteam lobbies), WebSocketTransport (Web builds).

signal action_received(action_dict: Dictionary, from_peer: int)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

func is_host() -> bool:
	return true

func local_peer_id() -> int:
	return 1

func send_action(_action_dict: Dictionary) -> void:
	pass

func send_full_sync(_rng_seed: int, _config: Dictionary, _history: Array) -> void:
	pass

func close() -> void:
	pass
