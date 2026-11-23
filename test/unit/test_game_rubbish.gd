extends "res://test/helpers/game_case.gd"
## The rubbish bag goes out only at the outside bin (EPIC-20 T4).


func _beside_bin() -> Vector3:
	return Grid.center(Scenery.outside_bin_cell() - Vector2i(1, 0))


func test_no_drop_at_the_front_door():
	game.player.set_held("rubbish_bag")
	game.player.position = Game.DOORWAY
	assert_eq(game.day.door_action(), "")
	assert_false(game.day.use_door())
	assert_eq(game.player.held, "rubbish_bag")


func test_no_prompt_over_the_doorway_with_the_bag():
	game.player.set_held("rubbish_bag")
	game.player.position = Game.DOORWAY
	game._update_cursor()
	assert_false(game.hud._prompts[0].sheet.visible)


func test_the_bag_goes_into_the_outside_bin_in_service():
	game.player.set_held("rubbish_bag")
	game.player.position = _beside_bin()
	assert_eq(game.day.door_action(), "Take out rubbish")
	assert_true(game.day.use_door())
	assert_eq(game.player.held, "")


func test_the_bag_goes_into_the_outside_bin_at_night():
	_to_build()
	game.player.set_held("rubbish_bag")
	game.player.position = _beside_bin()
	assert_eq(game.room_edit.build_action(), "Take out rubbish")
	game.room_edit.build_interact()
	assert_eq(game.player.held, "")


func test_the_bag_is_not_taken_out_empty_handed():
	game.player.position = _beside_bin()
	assert_eq(game.day.door_action(), "")
