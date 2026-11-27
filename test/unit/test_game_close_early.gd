extends "res://test/helpers/game_case.gd"
## Closing early on a real day: started through the door, played past halfway, so the
## arrivals list may already be empty (few groups on the early days).


func _play_to_halfway() -> void:
	_to_build()
	_at_door()
	assert_true(game.day.use_door(), "set-up: open up")
	assert_eq(game.phase, game.Phase.SERVICE)
	var guard := 0
	while game.day.day_progress() < Game.CLOSE_EARLY_FROM and guard < 20000:
		game.step(0.1)
		guard += 1
	game.player.position = Game.DOORWAY
	game.player.hand.clear()
	game.player.set_held("")


func test_real_day_one_offers_close_early_even_with_every_guest_in():
	game.ledger.history.clear()
	_play_to_halfway()
	game.arrivals.clear()
	assert_eq(game.day.door_action(), "Close early")
	game._update_cursor()
	assert_eq(game.hud.last_action, "Close early")


func test_real_busier_day_offers_close_early_and_flips_the_card():
	game.ledger.history.clear()
	for i in 4:
		game.ledger.history.append({})
	_play_to_halfway()
	assert_eq(game.day.door_action(), "Close early")
	assert_true(game.day.use_door())
	assert_false(game.door_open)
	assert_true(game.arrivals.is_empty())
	assert_eq(game.day.door_action(), "", "already closed")


func test_no_close_early_before_halfway():
	_to_build()
	_at_door()
	game.day.use_door()
	game.player.position = Game.DOORWAY
	assert_eq(game.day.door_action(), "")
