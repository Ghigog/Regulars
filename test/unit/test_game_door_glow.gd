extends "res://test/helpers/game_case.gd"
## The CLOSED door card glows faintly at night while it can be flipped to OPEN.


func _glow_alpha() -> float:
	return (game.day._glow.mesh.material as StandardMaterial3D).albedo_color.a


func test_card_glows_at_night_when_it_can_open():
	_to_build()
	game.ledger.money = 1000
	assert_eq(game.menu_stock.open_block(), "", "set-up: the door can open")
	_run(0.2)
	await wait_seconds(0.8)   # the tween runs on real frames
	assert_true(game.day._glow.visible)
	assert_between(_glow_alpha(), 0.15, 0.4)


func test_glow_fades_when_the_card_flips_open_and_stays_off_through_the_day():
	_to_build()
	game.ledger.money = 1000
	_run(0.2)
	await wait_seconds(0.3)
	game.day.set_door(true)
	game.step(0.1)
	await wait_seconds(0.8)
	assert_false(game.day._glow.visible)
	game.day.start_day()
	_run(1.0)
	await wait_seconds(0.3)
	assert_false(game.day._glow.visible)


func test_no_glow_when_the_door_cannot_open():
	_to_build()
	game.ledger.money = 0
	assert_ne(game.menu_stock.open_block(), "", "set-up: the door is blocked")
	_run(1.0)
	assert_false(game.day._glow.visible)
