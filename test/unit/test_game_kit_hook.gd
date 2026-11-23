extends "res://test/helpers/game_case.gd"
## A hook's tool hangs on the hook's own wall, whichever cell the hook is moved to.


func _free_cell(want_facing: int, corner: bool) -> Vector2i:
	for c: Vector2i in game.kitchen.wall_cells:
		if game.highs.has(c) or not game.kitchen.can_hang(c, "hook"):
			continue
		var edges: Array = game.world._back_walls(c, game._glass)
		if int(game.wall_facing.get(c, 0)) == want_facing and (edges.size() > 1) == corner:
			return c
	return Vector2i(-99, -99)


func _move_hook(from: Vector2i, to: Vector2i) -> Station:
	var hook: Station = game.world.add_high("hook", from)
	game.clean_kit.on_built(hook, "sponge")
	game.arrivals.clear()
	game.step(0.1)
	game.session.open_build()
	assert_true(game.placing.pick_up(Grid.center(from), null, false, "high"), "the hook lifts")
	game.placing._put_down(game.player.hand, Vector3i(to.x, to.y, 0), 0)
	return hook


func _assert_tool_with_hook(hook: Station) -> void:
	var tool_node: Node3D = hook.get_node("kit_tool")
	var plate: Node3D = hook._vis
	assert_almost_eq(tool_node.rotation.y, plate.rotation.y, 0.001, "the sponge turns with its hook")


func test_a_sponge_follows_its_hook_to_a_corner():
	var back := _free_cell(0, false)
	var corner := _free_cell(1, true)
	assert_ne(back, Vector2i(-99, -99))
	assert_ne(corner, Vector2i(-99, -99))
	var hook := _move_hook(back, corner)
	assert_eq(hook.cell, corner)
	assert_eq(hook.facing, 1)
	_assert_tool_with_hook(hook)


func test_a_sponge_follows_its_hook_to_a_side_wall():
	var back := _free_cell(0, false)
	var side := _free_cell(1, false)
	assert_ne(side, Vector2i(-99, -99))
	var hook := _move_hook(back, side)
	assert_eq(hook.facing, 1)
	_assert_tool_with_hook(hook)
