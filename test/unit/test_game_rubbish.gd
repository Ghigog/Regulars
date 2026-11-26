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


func _sheet_near(target: Vector3) -> void:
	var sheet = game.hud._prompts[0].sheet
	assert_true(sheet.visible)
	var c: Vector2 = sheet.global_position + Vector2(sheet.size.x / 2.0, sheet.size.y)   # the bubble's foot
	var at: Vector2 = game.cam.unproject_position(target)
	var door: Vector2 = game.cam.unproject_position(Game.DOORWAY + Vector3(0, 2.9, 0))
	assert_lt(c.distance_to(at), c.distance_to(door), "nearer the bin than the door")


func test_take_out_rubbish_prompt_sits_over_the_bin_in_service():
	game.player.set_held("rubbish_bag")
	game.player.position = _beside_bin()
	game._update_cursor()
	await wait_frames(2)
	_sheet_near(Scenery.outside_bin_at())


func test_take_out_rubbish_prompt_sits_over_the_bin_at_night():
	_to_build()
	game.player.set_held("rubbish_bag")
	game.player.position = _beside_bin()
	game._update_cursor()
	await wait_frames(2)
	_sheet_near(Scenery.outside_bin_at())


func test_no_prompt_with_the_bag_away_from_the_bin():
	_to_build()
	game.player.set_held("rubbish_bag")
	game.player.position = Grid.center(Vector2i(3, 3))
	game._update_cursor()
	assert_false(game.hud._prompts[0].sheet.visible)
