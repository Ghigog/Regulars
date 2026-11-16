extends GutTest
## Unit tests for PRD 8's kitchen: cells and layers, storage slots, chilled kinds, trees,
## and (8.3) the upgrade trees: buying steps, quality in the minigames, the tree screen.

const C := Vector2i(1, 1)
const W := Vector2i(0, 0)


func _kitchen() -> Kitchen:
	var k := Kitchen.new()
	k.set_wall(W)
	return k


# ---------- Tree data ----------

func test_every_parent_exists_and_trees_have_no_loops():
	for id: String in Kitchen.NODES:
		if not Kitchen.is_root(id):
			assert_true(Kitchen.has_node(Kitchen.parent_of(id)), id + " has a real parent")
			assert_true(Kitchen.step_of(id) in [Kitchen.EFFICIENT, Kitchen.SPECIALIST_STEP], id + " step")
		assert_true(Kitchen.is_root(Kitchen.root_of(id)), id + " reaches a root")
		assert_true(Kitchen.FITS.has(Kitchen.fit_of(id)), id + " fit")


func test_child_keeps_its_parents_fit_except_tall_fridge():
	for id: String in Kitchen.NODES:
		if Kitchen.is_root(id):
			continue
		var same := Kitchen.fit_of(id) == Kitchen.fit_of(Kitchen.parent_of(id))
		assert_true(same or id == "tall_fridge", id + " fits where its parent did")


func test_roots_are_the_shop_pieces():
	for id in ["board", "stove", "fountain", "wine_barrel", "counter", "shelf", "cabinet", "hood"]:
		assert_true(Kitchen.is_root(id), id)
	for id in ["slicer", "fryer", "pot", "fridge", "tall_fridge"]:
		assert_false(Kitchen.is_root(id), id + " is only bought in a tree")


func test_step_price_is_new_less_old():
	assert_eq(Kitchen.step_price("board"), 25)
	assert_eq(Kitchen.step_price("sharp_knife"), 15)
	assert_eq(Kitchen.step_price("butcher_block"), 25)
	assert_eq(Kitchen.step_price("tall_fridge"), 60)
	for id: String in Kitchen.NODES:
		assert_gt(Kitchen.step_price(id), 0, id + " costs something to reach")


func test_children_and_upgrades_only_from_the_parent():
	var kids := Kitchen.children_of("stove")
	for id in ["range", "char_grill", "pot", "fryer"]:
		assert_true(kids.has(id), id)
	assert_true(Kitchen.can_upgrade("board", "slicer"))
	assert_true(Kitchen.can_upgrade("slicer", "auto_slicer"))
	assert_false(Kitchen.can_upgrade("board", "auto_slicer"), "no skipping steps")
	assert_false(Kitchen.can_upgrade("counter", "tall_fridge"))
	assert_eq(Kitchen.root_of("glass_fridge"), "counter")


func test_base_tools_and_stand_ins():
	assert_eq(Kitchen.quality("board", "chop"), Kitchen.BASE)
	assert_eq(Kitchen.quality("board", "slice"), Kitchen.STAND_IN)
	assert_eq(Kitchen.quality("stove", "boil"), Kitchen.STAND_IN)
	assert_eq(Kitchen.quality("board", "grill"), 0.0, "cannot do it at all")


func test_efficient_step_lifts_every_job_including_stand_ins():
	for id: String in Kitchen.NODES:
		if Kitchen.step_of(id) != Kitchen.EFFICIENT or Kitchen.NODES[id].has("jobs"):
			continue
		var up := Kitchen.jobs_of(Kitchen.parent_of(id))
		var mine := Kitchen.jobs_of(id)
		assert_eq(mine.keys().size(), up.keys().size(), id + " keeps the same jobs")
		for job: String in up:
			assert_almost_eq(mine[job], up[job] + Kitchen.EFFICIENT_STEP, 0.0001, id + " " + job)
	assert_almost_eq(Kitchen.quality("butcher_block", "chop"), 1.3, 0.0001)
	assert_almost_eq(Kitchen.quality("butcher_block", "slice"), 0.9, 0.0001)


func test_specialist_is_much_better_at_one_job_and_loses_stand_ins():
	for id in ["slicer", "char_grill", "pot", "fryer"]:
		var jobs := Kitchen.jobs_of(id)
		var parent := Kitchen.jobs_of(Kitchen.parent_of(id))
		var best := 0.0
		for job: String in jobs:
			best = maxf(best, jobs[job])
		assert_eq(best, Kitchen.SPECIALIST, id)
		for job: String in parent:
			assert_true(jobs.get(job, 0.0) <= parent[job] or jobs[job] == Kitchen.SPECIALIST,
				id + " is no better at its stand-ins")
	assert_eq(Kitchen.quality("char_grill", "boil"), 0.0)
	assert_eq(Kitchen.quality("auto_slicer", "chop"), 0.0, "no chop")
	assert_true(Kitchen.NODES.auto_slicer.auto)


func test_mess_factor_defaults_to_one():
	for id: String in Kitchen.NODES:
		assert_eq(Kitchen.mess_of(id), 1.0, id)


func test_existing_jobs_each_have_a_root_tool():
	for job in ["chop", "slice", "grill", "boil", "fry", "pour"]:
		var found := false
		for id: String in Kitchen.NODES:
			if Kitchen.quality(id, job) > 0.0:
				found = true
		assert_true(found, job)


# ---------- Cells and layers ----------

func test_tool_only_goes_on_a_counter():
	var k := _kitchen()
	assert_false(k.can_place(C, "board"), "no counter yet")
	assert_eq(k.place(C, "counter"), "base")
	assert_eq(k.place(C, "board"), "top")
	assert_false(k.can_place(C, "stove"), "one tool per counter")
	assert_false(k.can_place(C, "counter"), "base is taken")


func test_under_counter_fridge_keeps_its_top_free():
	var k := _kitchen()
	k.place(C, "fridge")
	assert_eq(k.place(C, "stove"), "top")


func test_shelf_has_no_top_and_goes_high_on_a_wall():
	var k := _kitchen()
	assert_eq(k.place(C, "shelf"), "base")
	assert_false(k.can_place(C, "board"))
	assert_false(k.can_place(C, "shelf"), "no high layer away from a wall")
	assert_eq(k.place(W, "shelf"), "base")
	assert_eq(k.place(W, "wide_shelf"), "high")
	assert_true(k.is_closet(W))
	assert_false(k.is_closet(C))


func test_high_layer_only_on_wall_cells():
	var k := _kitchen()
	assert_false(k.can_place(C, "cabinet"))
	assert_false(k.can_place(C, "hood"))
	assert_eq(k.place(W, "hood"), "high")
	assert_true(k.has_hood(W))
	assert_false(k.has_hood(C))


func test_tall_fridge_fills_both_wall_layers():
	var k := _kitchen()
	assert_eq(k.place(W, "tall_fridge"), "base")
	assert_false(k.can_place(W, "cabinet"), "nothing above a tall piece")
	assert_false(k.can_place(W, "board"), "no top")
	var k2 := _kitchen()
	k2.place(W, "cabinet")
	assert_false(k2.can_place(W, "tall_fridge"), "the high layer is taken")


func test_remove_takes_the_tool_before_the_counter():
	var k := _kitchen()
	k.place(C, "counter")
	k.place(C, "board")
	assert_eq(k.remove(C, "base"), {}, "tool still on it")
	assert_eq(k.remove(C, "top").id, "board")
	assert_eq(k.remove(C, "base").id, "counter")
	assert_eq(k.remove(C, "base"), {})


# ---------- Storage ----------

func test_slot_counts_per_piece():
	var expect := {"counter": 1, "double_counter": 2, "shelf": 1, "cabinet": 1, "fridge": 1, "tall_fridge": 2}
	for id: String in expect:
		var k := _kitchen()
		k.place(W, id)
		assert_eq(k.slots(W), expect[id], id)
	var k := _kitchen()
	k.place(W, "counter")
	k.place(W, "cabinet")
	k.place(W, "board")
	assert_eq(k.slots(W), 2, "low and high both count; a tool adds none")


func test_chilled_flag_on_pantry():
	for id in ["patty", "cheese", "fish", "calamari"]:
		assert_true(Kitchen.is_chilled(id), id)
	for id in ["bun", "lettuce", "roll", "wine", "soda"]:
		assert_false(Kitchen.is_chilled(id), id)


func test_chilled_kinds_only_in_fridge_slots():
	var k := _kitchen()
	k.place(C, "counter")
	assert_false(k.store(C, "patty"), "a counter does not chill")
	assert_true(k.store(C, "bun"))
	assert_false(k.store(C, "lettuce"), "one slot, full")
	var f := _kitchen()
	f.place(C, "fridge")
	assert_true(f.store(C, "patty"))
	assert_eq(f.chilled_slots(C), 1)


func test_fridge_takes_any_kind():
	var k := _kitchen()
	k.place(C, "tall_fridge")
	assert_true(k.store(C, "lettuce"))
	assert_true(k.store(C, "cheese"))
	assert_false(k.store(C, "patty"), "two kinds, full")
	assert_eq(k.stock(C), ["lettuce", "cheese"])


func test_unchilled_kind_leaves_the_fridge_free():
	var k := _kitchen()
	k.place(W, "fridge")
	k.place(W, "cabinet")
	assert_true(k.store(W, "bun"))
	assert_eq(k.cells[W].stock.high, ["bun"], "the cabinet took it")
	assert_true(k.store(W, "fish"))


func test_a_kind_is_stored_once_per_cell():
	var k := _kitchen()
	k.place(C, "double_counter")
	assert_true(k.store(C, "bun"))
	assert_false(k.store(C, "bun"))


func test_unstore_and_stocked_and_remove_returns_stock():
	var k := _kitchen()
	k.place(C, "double_counter")
	k.place(W, "fridge")
	k.store(C, "bun")
	k.store(C, "onion")
	k.store(W, "patty")
	var all := k.stocked()
	all.sort()
	assert_eq(all, ["bun", "onion", "patty"])
	assert_true(k.unstore(C, "onion"))
	assert_false(k.unstore(C, "onion"))
	var off := k.remove(C, "base")
	assert_eq(off.stock, ["bun"])
	assert_eq(k.stocked(), ["patty"])


func test_best_quality_reads_tools_on_counters():
	var k := _kitchen()
	assert_eq(k.best_quality("chop"), 0.0)
	k.place(C, "counter")
	k.place(C, "slicer")
	k.place(W, "counter")
	k.place(W, "board")
	assert_eq(k.best_quality("slice"), Kitchen.SPECIALIST)
	assert_eq(k.best_quality("chop"), Kitchen.BASE)


# ---------- Counters and tops (8.2) ----------

func test_a_counter_on_a_bare_counter_makes_a_double_counter():
	var k := _kitchen()
	k.place(C, "counter")
	assert_eq(k.place(C, "counter"), "base")
	assert_eq(k.get_piece(C, "base"), "double_counter")
	assert_eq(k.slots(C), 2)
	assert_false(k.can_place(C, "counter"), "a double counter takes no third")
	var k2 := _kitchen()
	k2.place(C, "counter")
	k2.place(C, "board")
	assert_false(k2.can_place(C, "counter"), "not under a tool")
	assert_eq(Kitchen.stacked("counter", "counter"), "double_counter")
	assert_eq(Kitchen.unstacked("double_counter"), "counter")
	assert_eq(Kitchen.unstacked("counter"), "")


func test_catalog_pieces_map_to_tops_and_counters():
	for id in ["stove", "fryer", "pot", "board", "slicer", "fountain", "wine_barrel"]:
		assert_true(Kitchen.is_top(id), id + " is a top")
		assert_true(Catalog.ITEMS.has(id), id + " is sold")
	assert_eq(Kitchen.node_of("fountain"), "fountain")
	assert_eq(Kitchen.node_of("wine_barrel"), "wine_barrel")
	assert_eq(Kitchen.node_of("box_bun"), "", "a box of stock is not a kitchen piece")
	assert_false(Kitchen.is_top("counter"))
	assert_true(Kitchen.is_counter("counter"))
	assert_false(Kitchen.is_counter("sink"))


func test_set_cell_keeps_stock_and_clears():
	var k := _kitchen()
	k.set_cell(C, "double_counter", "stove")
	k.store(C, "bun")
	k.set_cell(C, "double_counter")
	assert_eq(k.get_piece(C, "top"), "")
	assert_eq(k.stock(C), ["bun"])
	k.set_cell(C, "")
	assert_false(k.cells.has(C))


# ---------- In the game ----------

var game


## The test kitchen at night, in the build phase; `night` false keeps it open for
## service, where cooking and the minigames run.
func _game(night := true) -> void:
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	game.test_kitchen()
	if night:
		game.arrivals.clear()   # the day ends at once, into the night
	for i in 2:
		game.step(0.1)
	if night:
		game.open_build()
	game.ledger.money = 500
	for person in game.town.people:   # no new random rules in these tests
		person.tolerance = {"food": 3, "service": 3, "clean": 3}
	game.floor_dirt.drops = false


func _at(x: int, z: int) -> Vector3:
	return Grid.center(Vector2i(x, z))


func test_a_tool_needs_a_counter_under_it():
	_game()
	var c := Vector2i(2, 5)
	assert_true(game.pick_catalog("stove"))
	assert_false(game.can_place(Vector3i(2, 5, 0)), "no counter there")
	game.cancel_hand()
	assert_true(game.pick_catalog("counter"))
	assert_true(game.place(Vector3i(2, 5, 0)))
	game.cancel_hand()
	assert_true(game.pick_catalog("stove"))
	assert_true(game.place(Vector3i(2, 5, 0)))
	game.cancel_hand()
	var st: Station = game.stations[c]
	assert_eq(st.type, "stove")
	assert_eq(st.base, "counter")
	assert_eq(game.kitchen.get_piece(c, "top"), "stove")
	assert_eq(game.ledger.money, 500 - Catalog.price_of("counter") - Catalog.price_of("stove"))
	assert_true(game.pick_catalog("board"))
	assert_false(game.can_place(Vector3i(2, 5, 0)), "one tool per counter")
	assert_false(game.can_place(Vector3i(3, 2, 0)), "not on a sink")


func test_every_tool_starts_on_a_counter():
	_game()
	for st: Station in game.stations.values():
		if Kitchen.is_top(st.type):
			assert_eq(st.base, "counter", st.type)
			assert_eq(game.kitchen.get_piece(st.cell, "top"), Kitchen.node_of(st.type))


func test_lifting_a_tool_leaves_its_counter_and_both_sell():
	_game()
	var c := Vector2i(0, 3)
	assert_eq(game.stations[c].type, "stove")
	assert_true(game.pick_up(_at(0, 3)))
	assert_eq(game.player.hand.id, "stove", "the tool comes off first")
	assert_eq(game.stations[c].type, "counter")
	assert_eq(game.kitchen.get_piece(c, "top"), "")
	assert_true(game.sell_hand())
	assert_eq(game.ledger.money, 500 + Catalog.price_of("stove") / 2)
	assert_true(game.pick_up(_at(0, 3)))
	assert_eq(game.player.hand.id, "counter")
	assert_true(game.sell_hand(), "counters are for sale")
	assert_false(game.stations.has(c))
	assert_false(game.kitchen.cells.has(c))
	assert_false(game.grid.blocked.has(c))


func test_a_moved_tool_goes_back_onto_its_counter():
	_game()
	var stove: Station = game.stations[Vector2i(0, 3)]
	assert_true(game.pick_up(_at(0, 3)))
	game.cancel_hand()
	assert_eq(game.stations[Vector2i(0, 3)], stove)
	assert_true(stove.visible)
	assert_eq(game.kitchen.get_piece(Vector2i(0, 3), "top"), "stove")
	assert_true(game.pick_up(_at(0, 3)))
	assert_true(game.place(Vector3i(4, 3, 0)), "onto the pass")
	assert_eq(game.stations[Vector2i(4, 3)], stove)
	assert_true(stove.pass_look, "it takes on the counter it stands on")
	assert_eq(game.stations[Vector2i(0, 3)].type, "counter")


func test_a_counter_on_a_counter_makes_a_double_and_lifts_off_again():
	_game()
	var c := Vector2i(2, 5)
	for i in 2:
		assert_true(game.pick_catalog("counter"))
		assert_true(game.place(Vector3i(2, 5, 0)))
		game.cancel_hand()
	assert_eq(game.stations[c].base, "double_counter")
	assert_eq(game.kitchen.slots(c), 2)
	assert_true(game.pick_catalog("counter"))
	assert_false(game.can_place(Vector3i(2, 5, 0)), "no triple")
	game.cancel_hand()
	assert_true(game.pick_catalog("board"))
	assert_true(game.place(Vector3i(2, 5, 0)), "a tool on a double counter")
	game.cancel_hand()
	assert_eq(game.stations[c].base, "double_counter")
	assert_true(game.pick_up(_at(2, 5)))
	assert_eq(game.player.hand.id, "board")
	game.sell_hand()
	assert_true(game.pick_up(_at(2, 5)))
	assert_eq(game.player.hand.id, "counter", "one counter comes off")
	assert_eq(game.stations[c].base, "counter", "the other stays")
	game.cancel_hand()
	assert_eq(game.stations[c].base, "double_counter", "and goes back on")


func test_the_starting_pass_is_counters_that_sell_and_take_tools():
	_game()
	for z in range(2, 6):
		var st: Station = game.stations[Vector2i(4, z)]
		assert_eq(st.type, "counter")
		assert_true(st.pass_look)
	assert_true(game.pick_catalog("board"))
	assert_true(game.place(Vector3i(4, 2, 0)))
	game.cancel_hand()
	assert_not_null(game.stations[Vector2i(4, 2)].get_node_or_null("till"), "the till moves onto the tool")
	assert_true(game.pick_up(_at(4, 5)))
	assert_true(game.sell_hand(), "starting counters are for sale")


func test_a_tool_is_not_put_on_a_counter_with_something_on_it():
	_game()
	game.stations[Vector2i(4, 4)].set_item(Tray.kind("prep", "bun"))
	assert_true(game.pick_catalog("board"))
	assert_false(game.can_place(Vector3i(4, 4, 0)))


func test_a_tops_surface_holds_one_thing_and_empty_hands_take_it_first():
	_game()
	game.start_day()
	var board: Station = game.add_station("board", Vector2i(4, 4))
	assert_eq(board.base, "counter", "it went onto the pass counter")
	game.player.set_held(Tray.kind("prep", "bun"))
	assert_eq(game.use_station(board), "Put down")
	assert_eq(board.item, "prep:bun")
	assert_eq(game.use_station(board), "Pick up", "empty hands take the thing first")
	assert_eq(game.player.held, "prep:bun")
	var stove: Station = game.find_station("stove")
	game.player.set_held("tray", 1.0, Tray.new())
	assert_eq(game.use_station(stove), "Put tray down", "a tray rests on a stove")
	assert_false(stove.is_cooking())
	assert_eq(game.use_station(stove), "Pick up tray")


# ---------- 8.3: upgrade trees (sim) ----------

func test_a_node_behaves_as_the_catalog_piece_it_grew_from():
	for pair: Array in [["range", "stove"], ["two_hob_range", "stove"], ["char_grill", "stove"], ["fryer", "fryer"],
			["twin_fryer", "fryer"], ["sharp_knife", "board"], ["auto_slicer", "slicer"], ["two_tap_fountain", "fountain"],
			["wine_rack", "wine_barrel"], ["fridge", "counter"], ["long_counter", "counter"]]:
		assert_eq(Kitchen.family_of(pair[0]), pair[1], pair[0])


func test_tree_keys_for_kitchen_pieces_and_tiered_pieces():
	assert_eq(Upgrades.key_of("stove"), "stove")
	assert_eq(Upgrades.key_of("fountain"), "fountain")
	assert_eq(Upgrades.key_of("stove", 1, "range"), "range", "a station's own node wins")
	assert_eq(Upgrades.key_of("plant", 2), "plant@2")
	assert_eq(Upgrades.key_of("table"), "table@1")
	assert_eq(Upgrades.key_of("bin"), "", "a bin has no tree")
	for key: String in ["board", "stove", "counter", "fountain", "wine_barrel", "plant@1", "jukebox@2", "booth@1"]:
		assert_true(Upgrades.has_tree(key), key)
	for key: String in ["", "cabinet", "hood"]:
		assert_false(Upgrades.has_tree(key), key + " has nowhere to go")
	assert_eq(Upgrades.catalog_id("jukebox@3"), "jukebox")
	assert_eq(Upgrades.children("plant@3"), [] as Array[String], "three tiers in all")


func test_efficient_steps_run_along_a_row_and_specialists_fork_below():
	var board := Upgrades.layout("board")
	assert_eq(board, {"board": Vector2i(0, 0), "sharp_knife": Vector2i(1, 0), "butcher_block": Vector2i(2, 0),
		"slicer": Vector2i(1, 1), "auto_slicer": Vector2i(2, 1)})
	var stove := Upgrades.layout("stove")
	assert_eq(stove.range, Vector2i(1, 0))
	assert_eq(stove.two_hob_range, Vector2i(2, 0))
	assert_eq([stove.char_grill, stove.pot, stove.fryer, stove.twin_fryer], [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)])
	assert_eq(Upgrades.extent(stove), Vector2i(3, 4))
	var counter := Upgrades.layout("counter")
	assert_eq([counter.double_counter, counter.long_counter, counter.fridge, counter.tall_fridge, counter.glass_fridge],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 2)], "fridge nodes are in the counter's tree")
	assert_eq(Upgrades.layout("slicer").keys().size(), 2, "a tree is drawn from the held piece on")
	assert_eq(Upgrades.layout("plant@1"), {"plant@1": Vector2i(0, 0), "plant@2": Vector2i(1, 0), "plant@3": Vector2i(2, 0)})


func test_a_step_costs_the_new_price_less_the_old_and_only_from_its_parent():
	assert_eq(Upgrades.step_price("slicer"), 35)
	assert_eq(Upgrades.step_price("auto_slicer"), 60)
	assert_eq(Upgrades.step_price("fridge"), 35)
	assert_eq(Upgrades.step_price("plant@2"), Catalog.price_of("plant", 2) - Catalog.price_of("plant"))
	assert_true(Upgrades.can_buy("board", "slicer", 35, 1))
	assert_false(Upgrades.can_buy("board", "slicer", 34, 1), "not enough money")
	assert_false(Upgrades.can_buy("board", "auto_slicer", 999, 9), "no skipping steps")
	assert_false(Upgrades.can_buy("slicer", "sharp_knife", 999, 9), "no going sideways")
	assert_false(Upgrades.can_buy("plant@1", "plant@2", 999, 1), "a tier still needs its level")
	assert_true(Upgrades.can_buy("plant@1", "plant@2", 999, 2))
	assert_eq(Upgrades.price("butcher_block"), 65, "a piece's whole price, for selling")


func test_tools_lose_their_catalog_tiers_and_later_nodes_leave_the_shop():
	for id: String in ["stove", "fryer", "pot", "board", "slicer"]:
		assert_eq(int(Catalog.ITEMS[id].tiers), 1, id)
	var ids := Catalog.search("", "Kitchen", "diner").map(func(bp: Dictionary) -> String: return bp.id)
	assert_has(ids, "stove")
	assert_has(ids, "board")
	for id: String in ["fryer", "pot", "slicer"]:
		assert_does_not_have(ids, id, id + " is reached through the stove or board")


func test_quality_is_the_minigames_difficulty():
	assert_lt(Prep.chop_notch(Kitchen.STAND_IN), Prep.CHOP_NOTCH, "a stand-in's notch is narrower")
	assert_gt(Prep.chop_notch(Kitchen.SPECIALIST), Prep.CHOP_NOTCH)
	assert_lt(Prep.chop_sweep(Kitchen.STAND_IN), Prep.CHOP_SWEEP_TIME, "and its marker faster")
	assert_lt(Prep.slice_time(Kitchen.STAND_IN), Prep.SLICE_TIME)
	assert_gt(Prep.slice_time(Kitchen.SPECIALIST), Prep.SLICE_TIME)
	assert_eq(Prep.slice_slack(1.0), Prep.SLICE_SLACK)
	assert_lt(Prep.pour_good(Kitchen.SPECIALIST), Prep.POUR_GOOD, "a better tap leaves a wider good band")
	assert_eq(Prep.heat_times("grill"), [Prep.GRILL_NEARLY, Prep.GRILL_DONE, Prep.GRILL_PERFECT, Prep.GRILL_BURN], "1.0 is the old timing")
	var narrow := Prep.heat_times("fry", Kitchen.STAND_IN)
	var wide := Prep.heat_times("fry", Kitchen.SPECIALIST)
	assert_lt(narrow[2] - narrow[1], Prep.FRY_LATE - Prep.FRY_GOOD)
	assert_gt(wide[2] - wide[1], Prep.FRY_LATE - Prep.FRY_GOOD)
	assert_eq(Prep.fry(Prep.FRY_GOOD + 1.5, Kitchen.STAND_IN).result, "plain", "late for a stand-in")
	assert_eq(Prep.fry(Prep.FRY_GOOD + 1.5).result, "good")
	assert_lt(Prep.boil_time(Kitchen.SPECIALIST), Prep.BOIL_TIME)
	assert_eq(Prep.reward("slice", "good", true), "", "a piece that plays itself gives no burst")


# ---------- 8.3: upgrade trees (in the game) ----------

func test_the_shop_with_a_piece_in_hand_opens_its_tree():
	_game()
	game.open_shop()
	assert_true(game.shopping and not game.upgrading, "empty hands: the shop")
	game.close_shop()
	game.add_station("counter", Vector2i(2, 5))
	game.add_station("board", Vector2i(2, 5))
	assert_true(game.pick_up(_at(2, 5)))
	assert_eq(game.hand_key(), "board")
	game.open_shop()
	assert_true(game.upgrading)
	assert_true(game.hud.tree_open())
	assert_false(game.hud._shop != null, "not the shop")
	assert_eq(game.hud._tree.root_key, "board", "the held piece on the left")
	assert_eq(game.hud.tree_selected(), "sharp_knife", "the straight-on step first")
	game.act(0, "down")
	assert_eq(game.hud.tree_selected(), "slicer", "down to the fork")
	game.act(0, "right")
	assert_eq(game.hud.tree_selected(), "auto_slicer")
	game.act(0, "back")
	assert_false(game.shopping)
	assert_false(game.hud.tree_open())
	assert_eq(game.hand_key(), "board", "still in hand")


func test_a_piece_with_no_tree_does_not_open_the_shop():
	_game()
	assert_true(game.pick_up(_at(3, 2)), "the sink")
	game.open_shop()
	assert_false(game.shopping)


func test_buying_a_step_turns_the_held_piece_into_it():
	_game()
	game.add_station("counter", Vector2i(2, 5))
	game.add_station("board", Vector2i(2, 5))
	assert_true(game.pick_up(_at(2, 5)))
	game.open_shop()
	assert_false(game.buy_upgrade("auto_slicer"), "not before the slicer")
	assert_eq(game.ledger.money, 500)
	game.act(0, "down")
	game.act(0, "use")   # buys the slicer
	assert_eq(game.ledger.money, 500 - 35)
	assert_eq(game.hand_key(), "slicer")
	assert_eq(game.hand.id, "slicer", "it works as a slicer now")
	assert_eq(game.hud._tree.root_key, "slicer", "the tree is drawn on from it")
	assert_eq(game.hud.tree_selected(), "auto_slicer")
	game.close_shop()
	assert_true(game.place(Vector3i(2, 5, 0)), "back onto its counter")
	var st: Station = game.stations[Vector2i(2, 5)]
	assert_eq([st.type, st.node], ["slicer", "slicer"])
	assert_eq(game.kitchen.get_piece(Vector2i(2, 5), "top"), "slicer")
	assert_true(game.pick_up(_at(2, 5)))
	assert_eq(game.sell_value(), Kitchen.price_of("slicer") / 2, "sold for its whole price, as before: half")


func test_an_upgraded_counter_becomes_a_fridge_and_does_not_stack():
	_game()
	game.add_station("counter", Vector2i(2, 5))
	game.add_station("counter", Vector2i(3, 5))
	assert_true(game.pick_up(_at(2, 5)))
	game.open_shop()
	assert_true(game.buy_upgrade("fridge"))
	game.close_shop()
	assert_eq((game.hand.node as Station).base, "fridge")
	assert_false(game.can_place(Vector3i(3, 5, 0)), "a fridge is not a counter to stack")
	assert_true(game.place(Vector3i(2, 5, 0)))
	assert_eq(game.kitchen.get_piece(Vector2i(2, 5), "base"), "fridge")
	assert_eq(game.kitchen.chilled_slots(Vector2i(2, 5)), 1)
	game.add_station("stove", Vector2i(2, 5))
	assert_eq(game.stations[Vector2i(2, 5)].type, "stove", "a tool still goes on its top")
	assert_eq(game.stations[Vector2i(2, 5)].base, "fridge")


func test_a_tree_bought_double_counter_lifts_off_whole():
	_game()
	game.add_station("counter", Vector2i(2, 5))
	assert_true(game.pick_up(_at(2, 5)))
	game.open_shop()
	assert_true(game.buy_upgrade("double_counter"))
	game.close_shop()
	assert_true(game.place(Vector3i(2, 5, 0)))
	assert_true(game.pick_up(_at(2, 5)))
	assert_eq((game.hand.node as Station).base, "double_counter")
	assert_false(game.stations.has(Vector2i(2, 5)), "nothing is left behind")


func test_a_fern_climbs_its_short_tree():
	_game()
	game.ledger.xp = 1000
	game.add_station("plant", Vector2i(5, 5))
	assert_true(game.pick_up(_at(5, 5)))
	game.open_shop()
	assert_eq(game.hud._tree.root_key, "plant@1")
	assert_true(game.buy_upgrade("plant@2"))
	assert_eq((game.hand.node as Station).tier, 2)
	assert_eq(int(game.hand.tier), 2)
	assert_eq(game.ledger.money, 500 - (Catalog.price_of("plant", 2) - Catalog.price_of("plant")))
	assert_eq(game.sell_value(), Catalog.price_of("plant", 2) / 2)


func test_the_board_slices_as_a_stand_in():
	_game(false)
	game.stock_box("cheese", Vector2i(2, 6))
	game.add_station("counter", Vector2i(2, 5))
	var board: Station = game.add_station("board", Vector2i(2, 5))
	assert_has(game.kitchen_tools(), "slice", "a menu can offer cheese with only a board")
	game.use_station(game.storage_of("cheese"))
	assert_eq(game.use_station(board), "Slice")
	assert_almost_eq(float(game.prep_of(0).q), Kitchen.STAND_IN, 0.001)
	for k in Prep.SLICE_COUNT:
		game.act(0, "use")
		game.step(0.05)
	for i in int(Prep.slice_time(Kitchen.STAND_IN) / 0.1) + 1:
		game.step(0.1)
	assert_eq(game.player.held, "prep:cheese")


func test_a_stove_fries_as_a_stand_in_with_a_narrower_window():
	_game(false)
	game.stock_box("potato", Vector2i(2, 6))
	game.add_station("counter", Vector2i(2, 5))
	var stove: Station = game.add_station("stove", Vector2i(2, 5))
	assert_has(game.kitchen_tools(), "fry")
	assert_has(game.kitchen_tools(), "boil")
	game.use_station(game.storage_of("potato"))
	assert_eq(game.use_station(stove), "Fry")
	assert_eq(stove.mode(), "fryer", "a stove frying works as a fryer")
	for i in int((Prep.FRY_GOOD + 0.5) / 0.1):
		game.step(0.1)
	assert_eq(game.use_station(stove), "Lift basket")
	for i in int((Prep.FRY_REST + 0.2) / 0.1):
		game.step(0.1)
	assert_eq(game.use_station(stove), "Pick up")
	assert_eq(game.player.held, "prep:potato")
	assert_eq(stove.heat, "", "an empty stove is a stove again")
	assert_eq(stove.mode(), "stove")


func test_an_auto_slicer_plays_itself():
	_game(false)
	game.stock_box("cheese", Vector2i(2, 6))
	game.add_station("counter", Vector2i(2, 5))
	var auto: Station = game.add_station("auto_slicer", Vector2i(2, 5))
	assert_eq([auto.type, auto.node], ["slicer", "auto_slicer"])
	game.use_station(game.storage_of("cheese"))
	assert_eq(game.use_station(auto), "Slice")
	for i in int(Prep.AUTO_TIME / 0.1) + 2:
		game.step(0.1)
	assert_eq(game.player.held, "prep:cheese")
	assert_eq(game.player.held_quality, Prep.GOOD)
	assert_almost_eq(game.player.speed(), Player.SPEED, 0.01, "no burst for a piece that plays itself")


# ---------- 8.4: storage ----------

func test_box_ids_name_a_kind_and_whether_it_is_ready():
	assert_eq(Pantry.box_id("patty"), "box_patty")
	assert_eq(Pantry.box_id("cheese", true), "ready_cheese")
	assert_eq(Pantry.station_ingredient("ready_cheese"), {"id": "cheese", "ready": true})
	assert_eq(Pantry.station_ingredient("box_fish"), {"id": "fish", "ready": false})
	assert_eq(Pantry.kind_of("patty"), "patty", "a plain kind is its own box")
	assert_eq(Pantry.kind_of("box_nothing"), "")


func test_every_food_kind_has_a_box_in_its_themes_pantry_and_the_crates_are_gone():
	for theme in Pantry.THEMES:
		var pantry: Array = Catalog.search("", "Pantry", theme).map(func(bp: Dictionary) -> String: return bp.id)
		for kind: String in Pantry.for_theme(theme):
			if Pantry.is_drink(kind):
				assert_false(pantry.has(Pantry.box_id(kind)), kind + ": a dispenser holds its own")
				continue
			assert_has(pantry, Pantry.box_id(kind), kind)
			assert_eq(Catalog.ingredient_of(Pantry.box_id(kind)), kind)
			assert_eq(Catalog.price_of(Pantry.box_id(kind)), 0, "a box is free; its kind costs a fee a night")
	for id: String in Catalog.ITEMS:
		assert_false(id.begins_with("crate_"), id + ": the crates went in 8.4")
	assert_true(Catalog.is_box("ready_lettuce"))
	assert_false(Catalog.is_box("fountain"))
	assert_eq(Catalog.level_of("ready_lettuce"), 2, "ready-made still needs level 2")


func test_ready_boxes_keep_the_chill_of_their_ingredient():
	assert_true(Kitchen.is_chilled("box_patty"))
	assert_true(Kitchen.is_chilled("ready_cheese"))
	assert_false(Kitchen.is_chilled("ready_lettuce"))
	var k := _kitchen()
	k.place(C, "counter")
	assert_false(k.can_store(C, "ready_cheese"), "ready cheese still needs a fridge")
	assert_true(k.can_store(C, "ready_lettuce"))
	k.place(W, "fridge")
	assert_true(k.store(W, "ready_cheese"))
	assert_true(k.has_fridge())


func test_a_cell_holds_one_box_of_a_kind_ready_or_not():
	var k := _kitchen()
	k.place(C, "double_counter")
	assert_true(k.store(C, "box_lettuce"))
	assert_false(k.store(C, "ready_lettuce"), "one lettuce a cell")
	assert_true(k.store(C, "box_bun"))
	assert_false(k.store(C, "box_onion"), "a double counter holds two kinds")
	assert_eq(k.cells_with("box_bun"), [C])
	var held := k.take_stock(C)
	k.set_cell(C, "")
	k.set_cell(C, "double_counter", "board")
	k.give_stock(C, held)
	assert_eq(k.stock(C), ["box_lettuce", "box_bun"], "stock carried over a swap of pieces")


func test_a_fridge_is_needed_for_a_chilled_box_and_is_reached_through_the_counters_tree():
	_game()
	assert_true(game.pick_catalog("box_fish" if Scenery.theme_id == "seaside" else "box_patty"))
	var box: String = game.hand.id
	game.add_station("counter", Vector2i(2, 6))
	assert_false(game.can_place(Vector3i(2, 6, 0)), "a chilled box does not go in a plain counter")
	game.cancel_hand()
	game.player.position = _at(2, 5)
	assert_true(game.pick_up(_at(2, 6)))
	game.open_shop()
	assert_true(game.upgrading)
	assert_true(game.buy_upgrade("fridge"))
	game.close_shop()
	assert_true(game.place(Vector3i(2, 6, 0)))
	assert_eq(game.stations[Vector2i(2, 6)].base, "fridge")
	game.kitchen.unstore(Vector2i(0, 2), box)   # the test kitchen's own box goes, so the fee shows
	var cost: int = game.night_cost()
	assert_true(game.pick_catalog(box))
	assert_true(game.place(Vector3i(2, 6, 0)))
	assert_true(game.hand.is_empty(), "one box a kind: hands are free again")
	assert_eq(game.night_cost(), cost + Pantry.fee_of(Pantry.kind_of(box)), "its fee starts")
	assert_eq(game.stations[Vector2i(2, 6)].boxes, [box], "a tag over the cell names it")


func test_the_box_comes_out_before_the_counter_and_a_tool_keeps_the_boxes_below():
	_game()
	game.stock_box("lettuce", Vector2i(2, 6))
	game.player.position = _at(2, 5)
	assert_true(game.pick_catalog("board"))
	assert_true(game.place(Vector3i(2, 6, 0)), "a tool goes on top of a counter with a box in it")
	game.cancel_hand()
	assert_eq(game.kitchen.stock(Vector2i(2, 6)), ["box_lettuce"])
	assert_eq(game.stations[Vector2i(2, 6)].boxes, ["box_lettuce"])
	assert_true(game.pick_up(_at(2, 6)))
	assert_eq(game.hand.id, "board", "the tool comes off first")
	game.cancel_hand()
	game.sell_hand()
	assert_true(game.pick_up(_at(2, 6)))
	assert_eq(game.hand.id, "board")
	assert_true(game.sell_hand())
	assert_eq(game.kitchen.stock(Vector2i(2, 6)), ["box_lettuce"], "the box stays when the tool goes")
	assert_true(game.pick_up(_at(2, 6)))
	assert_eq(game.hand.id, "box_lettuce", "then the box")
	assert_true(game.sell_hand())
	assert_true(game.pick_up(_at(2, 6)))
	assert_eq(game.hand.id, "counter", "and last the counter")


func test_e_takes_the_top_first_then_storage_and_swaps_through_the_kinds():
	_game(false)
	var cell := Vector2i(2, 6)
	game.add_station("counter", cell)
	game.kitchen.place(cell, "counter")   # a double counter: two kinds
	game.stations[cell].set_base("double_counter")
	game.stock_box("bun", cell)
	game.stock_box("lettuce", cell)
	var st: Station = game.stations[cell]
	st.set_item("prep:tomato", Prep.PLAIN)
	assert_eq(game.use_station(st), "Pick up", "what is on the top first")
	game.player.set_held("")
	assert_eq(game.prompt_for(st), "Take bun")
	game.use_station(st)
	assert_eq(game.player.held, "prep:bun")
	assert_eq(game.use_station(st), "Swap for lettuce")
	assert_eq(game.player.held, "raw:lettuce")
	assert_eq(game.use_station(st), "Swap for bun", "round again")
	assert_eq(game.player.held, "prep:bun")
	game.kitchen.unstore(cell, "box_lettuce")
	assert_eq(game.use_station(st), "Put back", "one kind: it goes back")
	assert_eq(game.player.held, "")


func test_a_stove_on_a_fridge_cooks_first_then_hands_out_the_box():
	_game(false)
	var fm: Dictionary = game.fixed_main()
	var cell := Vector2i(2, 6)
	game.stock_box(fm.grill, cell)
	var stove: Station = game.add_station("stove", cell)
	assert_eq(stove.boxes, [Pantry.box_id(fm.grill)], "the box stays under the stove")
	assert_eq(game.use_station(stove), "Take %s" % Pantry.name_of(fm.grill).to_lower())
	assert_eq(game.use_station(stove), "Grill", "the tool wins for what it can cook")
	assert_eq(game.prompt_for(stove), "Take off the heat", "empty hands: what is on the top first")
	game.player.set_held(Tray.kind("raw", fm.grill))
	assert_eq(game.prompt_for(stove), "Put back", "the stove is busy, so a second one goes back")


func test_a_dispenser_is_its_own_storage_and_a_kind_is_charged_once():
	_game()
	var cost: int = game.night_cost()
	var drink: String = "wine" if Scenery.theme_id == "seaside" else "soda"
	var piece: String = "wine_barrel" if drink == "wine" else "fountain"
	game.add_station(piece, Vector2i(2, 6))
	game.add_station(piece, Vector2i(1, 6))
	assert_eq(game.night_cost(), cost + Pantry.fee_of(drink), "two dispensers, one fee")
	game.stock_box(game.fixed_main().bread, Vector2i(3, 6))
	assert_eq(game.night_cost(), cost + Pantry.fee_of(drink), "a second box of a kind adds nothing")
	var names: Array = game.stock_lines().map(func(l: Dictionary) -> String: return l.name)
	assert_has(names, Pantry.name_of(drink))
	assert_eq(names.count(Pantry.name_of(game.fixed_main().bread)), 1, "the restock note reads the slots, a line a kind")


func test_the_menu_says_a_chilled_kind_needs_a_fridge():
	_game()
	var grill: String = game.fixed_main().grill
	game.kitchen.unstore(Vector2i(0, 2), Pantry.box_id(grill))
	game.menu_changed()
	assert_eq(game.item_off_reason(game.menu.items[0]), "%s: needs a box" % Pantry.name_of(grill), "a fridge stands empty")
	var fridge: Station = game.stations[Vector2i(0, 2)]
	game._unregister(fridge)
	fridge.queue_free()
	assert_eq(game.item_off_reason(game.menu.items[0]), "%s: needs a fridge" % Pantry.name_of(grill))
	assert_false(game.kitchen.has_fridge())


func _night_zero(theme: String) -> void:
	game = load("res://game/main.tscn").instantiate()
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"
	game.play()
	game.choose_theme(theme)


func test_night_zero_is_winnable_with_counters_a_fridge_and_boxes():
	for theme in Pantry.THEMES:
		_night_zero(theme)
		assert_eq(game.phase, game.Phase.BUILD, theme)
		assert_eq(game.ledger.money, 150)
		assert_eq(game.night_hint(), game.NIGHT_HINTS[0])
		var fm: Dictionary = game.fixed_main()
		game.player.position = _at(3, 4)
		assert_true(game.pick_catalog("stove"))
		assert_true(game.place(Vector3i(4, 4, 0)), theme + ": a stove on the pass")
		game.cancel_hand()
		assert_true(game.pick_up(_at(4, 5)), "a pass counter")
		game.open_shop()
		assert_true(game.buy_upgrade("fridge"), theme + ": the counter's tree reaches a fridge")
		game.close_shop()
		assert_true(game.place(Vector3i(4, 5, 0)))
		for kind: String in [fm.grill, fm.bread]:
			assert_true(game.pick_catalog(Pantry.box_id(kind)), kind)
			var at := Vector3i(4, 5, 0) if Kitchen.is_chilled(kind) else Vector3i(4, 3, 0)
			assert_true(game.place(at), theme + ": " + kind)
		assert_eq(game.night_hint(), game.NIGHT_HINTS[1], "next, a menu")
		game.write_test_menu()
		game.menu_changed()
		assert_eq(game.night_hint(), game.NIGHT_HINTS[2])
		assert_eq(game.open_block(), "", theme + ": the door card will flip")
		assert_gte(game.ledger.money, game.night_cost(), theme + ": with money for the stock")
		game.queue_free()
