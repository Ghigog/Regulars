extends "res://test/helpers/game_case.gd"
## The aim mark: a faint spot on the cell Aim or Reach points at. It only draws; target_cell decides.

const C := Vector2i(0, 6)


func _stage() -> void:
	if not game.stations.has(C):
		game.world.add_station("counter", C)
	game.player.position = Grid.center(Vector2i(1, 6))
	game.player.look(Vector2i(-1, 0))


func _settle(ch: Player = null) -> void:
	for i in 30:
		game.aim_mark.update(ch if ch else game.player, 0.05)


func test_hidden_when_nothing_is_held():
	_stage()
	_settle()
	assert_false(game.player.aim_mark.visible)


func test_aim_shows_on_the_target_cell_at_floor_level():
	_stage()
	game.player.move(Vector2.ZERO, 0.016, true)
	_settle()
	var m: Node3D = game.player.aim_mark
	assert_true(m.visible)
	assert_eq(Grid.to_cell(m.position), game.player.target_cell())
	assert_lt(m.position.y, 0.2)


func test_reach_lifts_it_to_the_high_layer_and_aim_alone_lowers_it():
	_stage()
	game.player.set_meta("reach", true)
	_settle()
	assert_almost_eq(game.player.aim_mark.position.y, BuildStations.HIGH_Y0 + 0.2, 0.01)
	game.player.set_meta("reach", false)
	game.player.move(Vector2.ZERO, 0.016, true)
	_settle()
	assert_lt(game.player.aim_mark.position.y, 0.2)


func test_it_fades_out_when_released():
	_stage()
	game.player.move(Vector2.ZERO, 0.016, true)
	_settle()
	game.player.move(Vector2.ZERO, 0.016, false)
	game.aim_mark.update(game.player, 0.2)
	assert_false(game.player.aim_mark.visible)


func test_hidden_while_the_mouse_aims():
	_stage()
	game.player.move(Vector2.ZERO, 0.016, true)
	game.player.aim_mouse = true
	_settle()
	assert_false(game.player.aim_mark.visible)


func test_coop_each_chef_has_a_mark_in_their_trim_and_it_goes_when_they_leave():
	_stage()
	assert_eq(game.coop.join("pad:1"), 1)
	var two: Player = game.chefs[1]
	two.position = Grid.center(Vector2i(3, 3))
	two.look(Vector2i(0, -1))
	game.player.move(Vector2.ZERO, 0.016, true)
	two.move(Vector2.ZERO, 0.016, true)
	_settle()
	_settle(two)
	assert_true(game.player.aim_mark.visible)
	assert_true(two.aim_mark.visible)
	assert_eq(Grid.to_cell(two.aim_mark.position), two.target_cell())
	assert_ne(game.player.aim_mark.get_child(0).material_override.albedo_color, two.aim_mark.get_child(0).material_override.albedo_color)
	var mark := two.aim_mark
	game.coop.leave(1)
	await get_tree().process_frame
	assert_false(is_instance_valid(mark))
