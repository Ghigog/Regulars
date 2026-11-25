extends "res://test/helpers/game_case.gd"
## The sponge is a counter tool: never on the floor, kept on counters and sinks, and it
## speeds a helper's wash.


func _counter() -> Station:
	return game.world.add_station("counter", Vector2i(3, 3))


func _chef_facing(st: Station) -> void:
	game.player.position = Grid.center(st.cell + Vector2i(0, 1))
	game.player.look(Vector2i(0, -1))


func test_the_sponge_is_never_put_on_the_floor():
	CleanKit.hold(game.player, "sponge", 1)
	game.player.position = Grid.center(Vector2i(5, 3))
	game.player.look(Vector2i(0, 1))
	assert_null(game.clean_kit.drop_target(game.player))
	assert_eq(game.clean_kit.floor_action(game.player), "")
	assert_true(game.clean_kit.floor_use(game.player))
	assert_eq(CleanKit.held_tool(game.player), "sponge")
	assert_true(game.clean_kit.lying.is_empty())


func test_the_sponge_sits_on_a_counter_and_comes_back_with_its_wear():
	var st: Station = _counter()
	_chef_facing(st)
	CleanKit.hold(game.player, "sponge", 1)
	assert_eq(game.cooking.use_station(st, true), "Put sponge down")
	game.cooking.use_station(st)
	assert_eq(st.item, "tool:sponge")
	assert_eq(game.player.held, "")
	assert_eq(game.cooking.use_station(st, true), "Take sponge")
	game.cooking.use_station(st)
	assert_eq(CleanKit.held_tool(game.player), "sponge")
	assert_eq(CleanKit.held_used(game.player), 1)
	assert_eq(st.item, "")


func test_a_sponge_on_a_counter_is_not_food():
	var st: Station = _counter()
	st.set_item("tool:sponge", 1.0)
	assert_false(st.has_leftover_food())


func test_a_helper_washes_faster_with_a_sponge_beside_the_sink():
	var sink: Station = game.world.find_station("sink")
	var tr: CrewTaskRun = game.crew.task_run
	assert_false(tr._sponge_near(sink))
	sink.set_item("tool:sponge", 1.0)
	assert_true(tr._sponge_near(sink))
	sink.set_item("")
	var side: Station = game.world.add_station("counter", sink.cell + Vector2i(1, 0))
	side.set_item("tool:sponge", 1.0)
	assert_true(tr._sponge_near(sink))


func test_a_sponge_on_a_dirty_sink_does_not_block_the_chefs_wash():
	var sink: Station = game.world.find_station("sink")
	sink.set_item("tool:sponge", 1.0)
	sink.dirty = 2
	_chef_facing(sink)
	assert_eq(game.cooking.use_station(sink, true), "Wash")
	sink.dirty = 0
	assert_eq(game.cooking.use_station(sink, true), "Take sponge")
