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
	var tr = game.clean_kit
	assert_false(tr.sponge_near(sink))
	sink.set_item("tool:sponge", 1.0)
	assert_true(tr.sponge_near(sink))
	sink.set_item("")
	var side: Station = game.world.add_station("counter", sink.cell + Vector2i(1, 0))
	side.set_item("tool:sponge", 1.0)
	assert_true(tr.sponge_near(sink))


func test_a_sponge_on_a_dirty_sink_does_not_block_the_chefs_wash():
	var sink: Station = game.world.find_station("sink")
	sink.set_item("tool:sponge", 1.0)
	sink.dirty = 2
	_chef_facing(sink)
	assert_eq(game.cooking.use_station(sink, true), "Wash")
	sink.dirty = 0
	assert_eq(game.cooking.use_station(sink, true), "Take sponge")


func test_the_starter_sponge_is_kept_on_the_jar_shelf_not_the_sink():
	var fresh = load("res://game/main.tscn").instantiate()
	fresh.get_script()._title_seen = false
	add_child_autofree(fresh)
	fresh.set_process(false)
	fresh.theme_path = THEME_TEST_PATH
	fresh.session.play()
	fresh.session.choose_theme("diner")
	var shelf: Station = fresh.highs.get(Vector2i(3, 2))
	var kept := shelf != null and shelf.kit_tool == "sponge"
	if not kept:
		for c: Vector2i in [Vector2i(0, 5), Vector2i(0, 6)]:
			kept = kept or (fresh.highs.has(c) and fresh.highs[c].kit_tool == "sponge")
	assert_true(kept, "kept on the shelf or a cabinet")
	assert_eq(fresh.world.find_station("sink").item, "")


func test_a_hand_tool_is_the_same_size_on_a_shelf_and_on_a_counter():
	var st: Station = _counter()
	st.set_item("tool:sponge", 1.0)
	var shelf: Station = game.world.add_high("shelf", Vector2i(5, 3))
	game.clean_kit.keep(shelf, "sponge", 0)
	st._item_node.scale = Vector3.ONE * BuildFood.SIZE   # past the pop-in
	var on_counter: Vector3 = st._item_node.get_child(0).global_transform.basis.get_scale()
	var on_shelf: Vector3 = shelf.get_node("kit_tool").get_child(0).global_transform.basis.get_scale()
	assert_almost_eq(on_counter.x, on_shelf.x, 0.001)


func test_the_put_down_prompt_is_the_same_at_a_shelf_and_a_counter():
	var wall := Vector2i(-99, -99)
	for c: Vector2i in game.kitchen.wall_cells:
		if not game.stations.has(c) and not game.highs.has(c) and game.kitchen.can_hang(c, "shelf"):
			wall = c
			break
	game.world.add_station("counter", wall)
	var shelf: Station = game.world.add_high("shelf", wall)
	var st: Station = _counter()
	CleanKit.hold(game.player, "sponge", 0)
	_chef_facing(st)
	assert_eq(game.cooking.use_station(st, true, game.player), "Put sponge down")
	game.player.look(Vector2i(-1, 0))
	game.player.set_meta("reach", true)
	var p: String = game.cooking.use_station(shelf, true, game.player)
	assert_eq(p, "Put sponge down")
	assert_false("back" in p)


func _wash_for(sink: Station, secs: float) -> void:
	sink.dirty = 2
	_chef_facing(sink)
	game.cooking.use_station(sink)
	var t := 0.0
	while t < secs:
		game.cooking._tick_wash(game.player, true, 0.1)
		t += 0.1


func test_a_sponge_on_the_sink_speeds_the_chefs_wash():
	var sink: Station = game.world.find_station("sink")
	sink.set_item("tool:sponge", 1.0)
	_wash_for(sink, game.cooking.WASH_HOLD * CleanTools.SPONGE_WASH + 0.1)
	assert_eq(game.player.held, "dishes")
	assert_eq(sink.dirty, 1)


func test_a_sponge_on_a_counter_beside_the_sink_speeds_the_chefs_wash():
	var sink: Station = game.world.find_station("sink")
	var side: Station = game.world.add_station("counter", sink.cell + Vector2i(1, 0))
	side.set_item("tool:sponge", 1.0)
	_wash_for(sink, game.cooking.WASH_HOLD * CleanTools.SPONGE_WASH + 0.1)
	assert_eq(game.player.held, "dishes")


func test_without_a_sponge_the_chefs_wash_takes_the_full_hold():
	var sink: Station = game.world.find_station("sink")
	_wash_for(sink, game.cooking.WASH_HOLD * CleanTools.SPONGE_WASH + 0.1)
	assert_ne(game.player.held, "dishes")
	assert_true(game.cooking.prompt_for(sink).begins_with("Washing "))
