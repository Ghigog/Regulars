extends "res://test/helpers/game_case.gd"
## The sponge is a hand tool kept on a wall shelf or in a wall cabinet (PRD 9.4, 9.5): put
## back and taken with Reach+E, drawn centred and turned with its piece, never beside food.

var C := Vector2i(-99, -99)


func before_each():
	super.before_each()
	for c: Vector2i in game.kitchen.wall_cells:
		if not game.stations.has(c) and not game.highs.has(c) and game.kitchen.can_hang(c, "shelf"):
			C = c
			break


func _reach(on := true) -> void:
	game.player.set_meta("reach", on)


func _face_wall_cell() -> void:
	game.player.look(Vector2i(-1, 0))


func _counter() -> Station:
	return game.world.add_station("counter", C)


func test_the_sponge_is_put_back_on_a_shelf_centred_and_taken_with_its_wear():
	_counter()
	var shelf: Station = game.world.add_high("shelf", C)
	_face_wall_cell()
	_reach()
	CleanKit.hold(game.player, "sponge", 2)
	assert_eq(game.cooking.use_station(shelf, true, game.player), "Put sponge back")
	game.cooking.use_station(shelf, false, game.player)
	assert_eq(CleanKit.held_tool(game.player), "", "the hands are free")
	assert_eq(shelf.kit_tool, "sponge")
	assert_eq(shelf.kit_used, 2, "with its wear")
	var tool: Node3D = shelf.get_node("kit_tool").get_child(0)
	assert_eq(tool.position.x, 0.0, "centred across")
	assert_eq(tool.position.z, 0.0, "and front to back")
	assert_eq(game.cooking.use_station(shelf, true, game.player), "Take sponge")
	game.cooking.use_station(shelf, false, game.player)
	assert_eq(CleanKit.held_tool(game.player), "sponge")
	assert_eq(CleanKit.held_used(game.player), 2)


func test_a_cabinet_keeps_the_sponge_and_the_tool_turns_with_the_piece():
	_counter()
	var cab: Station = game.world.add_high("cabinet", C)
	_face_wall_cell()
	_reach()
	CleanKit.hold(game.player, "sponge", 0)
	game.cooking.use_station(cab, false, game.player)
	assert_eq(cab.kit_tool, "sponge")
	assert_almost_eq((cab.get_node("kit_tool") as Node3D).rotation.y, cab.facing * PI / 2, 0.001)


func test_a_shelf_over_stored_food_refuses_the_sponge():
	var counter := _counter()
	var shelf: Station = game.world.add_high("shelf", C)
	game.kitchen.store(C, "bun")
	_face_wall_cell()
	_reach()
	CleanKit.hold(game.player, "sponge", 0)
	assert_eq(game.cooking.use_station(shelf, true, game.player), "No chemicals with food")
	game.cooking.use_station(shelf, false, game.player)
	assert_eq(CleanKit.held_tool(game.player), "sponge", "the sponge stays in hand")
	assert_eq(shelf.kit_tool, "")
	assert_not_null(counter)


func test_food_is_refused_where_a_shelf_keeps_the_sponge():
	_counter()
	var shelf: Station = game.world.add_high("shelf", C)
	game.clean_kit.keep(shelf, "sponge", 0)
	assert_true(game.kitchen.holds_cleaning(C))
	assert_eq(game.kitchen.store_refusal(C, "bun"), "No food with chemicals")


func test_a_mop_is_not_kept_on_a_shelf():
	_counter()
	var shelf: Station = game.world.add_high("shelf", C)
	_face_wall_cell()
	_reach()
	CleanKit.hold(game.player, "mop", 0)
	assert_eq(game.cooking.use_station(shelf, true, game.player), "")


func test_an_old_hook_loads_as_a_wall_shelf_with_its_sponge_and_wear():
	var w := C
	var piece := {"type": "hook", "node": "hook", "cell": w, "high": true, "tier": 1, "facing": 0, "base": "",
		"pass_look": false, "stacked": false, "count": 0, "dirty": 0, "dirty_cups": 0, "dirty_age": 0.0, "tap": 0,
		"kit_tool": "sponge", "kit_used": 1}
	SaveGame._place(game, piece)
	var st: Station = game.highs[w]
	assert_eq(st.node, "shelf", "a wall shelf at the same cell")
	assert_eq(st.kit_tool, "sponge")
	assert_eq(st.kit_used, 1)
	SaveGame.restore_after(game, {"dirt": {}, "grease": {}})
	assert_eq(game.kitchen.tool_at(w), "sponge", "and the kitchen knows it keeps one")
