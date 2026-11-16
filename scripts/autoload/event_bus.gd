extends Node
## Global signal hub. UI, audio and (future) network layers subscribe here
## instead of holding direct references to each other.

## Emitted after any game action has been applied. `events` is the list of
## domain events produced by the rules engine (populated from P1 onwards).
signal game_events(events: Array)

## Emitted when a new game starts or a saved game is loaded.
signal game_started(state: Object)

## Emitted when the game reaches GAME_OVER.
signal game_over(state: Object)

## Emitted whenever a setting changes. key = setting name.
signal setting_changed(key: String, value: Variant)

## Request a toast/notification line in the UI.
signal toast_requested(text: String)
