extends "res://test/helpers/kitchen_case.gd"


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
		assert_true(same or id in ["tall_fridge", "mop_bucket"], id + " fits where its parent did (the sponge's bucket stands on the floor)")



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
	assert_eq(Kitchen.quality("stove", "boil"), Kitchen.BASE, "a hob boils at base")
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
	assert_false(k.can_place(C, "board"))
	assert_eq(k.layer_for(C, "shelf"), "", "never on the floor: no wall, no shelf")
	assert_eq(k.layer_for(C, "wide_shelf"), "")
	assert_false(k.can_place(C, "shelf"), "no high layer away from a wall")
	assert_eq(k.layer_for(W, "shelf"), "high", "a wall cell with free floor below still hangs it")
	assert_eq(k.place(W, "shelf"), "high")
	assert_eq(k.layer_for(W, "wide_shelf"), "", "one high piece a cell")
	assert_eq(k.get_piece(W, "base"), "")



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

func test_a_counter_cannot_go_on_a_counter():
	var k := _kitchen()
	k.place(C, "counter")
	assert_false(k.can_place(C, "counter"))
	assert_eq(k.place(C, "counter"), "")
	assert_eq(k.get_piece(C, "base"), "counter")
	assert_eq(k.slots(C), 1)
	k.set_cell(C, "double_counter")
	assert_false(k.can_place(C, "counter"), "nor on a double counter")
	assert_eq(Kitchen.unstacked("double_counter"), "counter", "an old hand-stacked one still comes apart")
	assert_eq(Kitchen.unstacked("counter"), "")


func test_two_fridges_stack_into_a_tall_fridge_that_does_not_unstack():
	assert_eq(Kitchen.stacks_into("fridge"), "tall_fridge")
	assert_eq(Kitchen.stacks_into("counter"), "")
	assert_eq(Kitchen.stacks_into("tall_fridge"), "")
	assert_eq(Kitchen.unstacked("tall_fridge"), "", "a tall fridge never comes apart")



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


func test_a_hob_does_every_heat_job_at_base():
	for job in ["grill", "fry", "boil"]:
		assert_eq(Kitchen.quality("stove", job), Kitchen.BASE)
	assert_eq(Kitchen.quality("range", "fry"), Kitchen.BASE + Kitchen.EFFICIENT_STEP)
	assert_eq(Kitchen.NODES.stove.name, "Hob")


func test_specialists_do_only_their_one_job():
	assert_eq(Kitchen.jobs_of("char_grill"), {"grill": Kitchen.SPECIALIST})
	assert_eq(Kitchen.jobs_of("fryer"), {"fry": Kitchen.SPECIALIST})
	assert_eq(Kitchen.jobs_of("pot"), {"boil": Kitchen.SPECIALIST})
