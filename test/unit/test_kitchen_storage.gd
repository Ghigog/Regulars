extends "res://test/helpers/kitchen_case.gd"


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
			if Pantry.is_poured(kind):
				assert_false(pantry.has(Pantry.box_id(kind)), kind + ": a dispenser holds its own")
				continue
			if Pantry.is_derived(kind):
				assert_false(pantry.has(Pantry.box_id(kind)), kind + ": made from another kind's box")
				assert_has(pantry, Pantry.box_id(Pantry.source_of(kind)), kind + "'s source has one")
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
	assert_true(game.placing.pick_catalog("box_fish" if Scenery.theme_id == "seaside" else "box_patty"))
	var box: String = game.hand.id
	game.world.add_station("counter", Vector2i(2, 6))
	assert_false(game.placing.can_place(Vector3i(2, 6, 0)), "a chilled box does not go in a plain counter")
	game.placing.cancel_hand()
	game.player.position = _at(2, 5)
	assert_true(game.placing.pick_up(_at(2, 6)))
	assert_true(game.upgrades.strip_choices().any(func(c: Dictionary) -> bool: return c.get("key", "") == "fridge"))
	assert_true(game.upgrades.buy_upgrade("fridge"))
	assert_true(game.placing.place(Vector3i(2, 6, 0)))
	assert_eq(game.stations[Vector2i(2, 6)].base, "fridge")
	game.kitchen.unstore(Vector2i(0, 2), box)   # the test kitchen's own box goes, so the fee shows
	var cost: int = game.menu_stock.night_cost()
	assert_true(game.placing.pick_catalog(box))
	assert_true(game.placing.place(Vector3i(2, 6, 0)))
	assert_true(game.hand.is_empty(), "one box a kind: hands are free again")
	assert_eq(game.menu_stock.night_cost(), cost + Pantry.fee_of(Pantry.kind_of(box)), "its fee starts")
	assert_eq(game.stations[Vector2i(2, 6)].boxes, [box], "a tag over the cell names it")



func test_the_box_comes_out_before_the_counter_and_a_tool_keeps_the_boxes_below():
	_game()
	game.menu_stock.stock_box("lettuce", Vector2i(2, 6))
	game.player.position = _at(2, 5)
	assert_true(game.placing.pick_catalog("board"))
	assert_true(game.placing.place(Vector3i(2, 6, 0)), "a tool goes on top of a counter with a box in it")
	game.placing.cancel_hand()
	assert_eq(game.kitchen.stock(Vector2i(2, 6)), ["box_lettuce"])
	assert_eq(game.stations[Vector2i(2, 6)].boxes, ["box_lettuce"])
	assert_true(game.placing.pick_up(_at(2, 6)))
	assert_eq(game.hand.id, "board", "the tool comes off first")
	game.placing.cancel_hand()
	game.placing.sell_hand()
	assert_true(game.placing.pick_up(_at(2, 6)))
	assert_eq(game.hand.id, "board")
	assert_true(game.placing.sell_hand())
	assert_eq(game.kitchen.stock(Vector2i(2, 6)), ["box_lettuce"], "the box stays when the tool goes")
	assert_true(game.placing.pick_up(_at(2, 6)))
	assert_eq(game.hand.id, "box_lettuce", "then the box")
	assert_true(game.placing.sell_hand())
	assert_true(game.placing.pick_up(_at(2, 6)))
	assert_eq(game.hand.id, "counter", "and last the counter")



func test_e_takes_the_top_first_then_storage_and_swaps_through_the_kinds():
	_game(false)
	var cell := Vector2i(2, 6)
	game.world.add_station("counter", cell)
	game.stations[cell].set_base("double_counter")   # a double counter: two kinds
	game.kitchen.set_cell(cell, "double_counter")
	game.menu_stock.stock_box("bun", cell)
	game.menu_stock.stock_box("lettuce", cell)
	var st: Station = game.stations[cell]
	st.set_item("prep:tomato", Prep.PLAIN)
	assert_eq(game.cooking.use_station(st), "Pick up", "what is on the top first")
	game.player.set_held("")
	assert_eq(game.cooking.prompt_for(st), "Take bun")
	game.cooking.use_station(st)
	assert_eq(game.player.held, "prep:bun")
	assert_eq(game.cooking.use_station(st), "Swap for lettuce")
	assert_eq(game.player.held, "raw:lettuce")
	assert_eq(game.cooking.use_station(st), "Swap for bun", "round again")
	assert_eq(game.player.held, "prep:bun")
	game.kitchen.unstore(cell, "box_lettuce")
	assert_eq(game.cooking.use_station(st), "Put back", "one kind: it goes back")
	assert_eq(game.player.held, "")



func test_a_stove_on_a_fridge_cooks_first_then_hands_out_the_box():
	_game(false)
	var fm: Dictionary = game.world.fixed_main()
	var cell := Vector2i(2, 6)
	game.menu_stock.stock_box(fm.grill, cell)
	var stove: Station = game.world.add_station("stove", cell)
	assert_eq(stove.boxes, [Pantry.box_id(fm.grill)], "the box stays under the stove")
	assert_eq(game.cooking.use_station(stove), "Take %s" % Pantry.name_of(fm.grill).to_lower())
	assert_eq(game.cooking.use_station(stove), "Grill", "the tool wins for what it can cook")
	assert_eq(game.cooking.prompt_for(stove), "Take off the heat", "empty hands: what is on the top first")
	game.player.set_held(Tray.kind("raw", fm.grill))
	assert_eq(game.cooking.prompt_for(stove), "Put back", "the stove is busy, so a second one goes back")



func test_a_dispenser_is_its_own_storage_and_a_kind_is_charged_once():
	_game()
	var cost: int = game.menu_stock.night_cost()
	var drink: String = "wine" if Scenery.theme_id == "seaside" else "soda"
	var piece: String = "wine_barrel" if drink == "wine" else "fountain"
	game.world.add_station(piece, Vector2i(2, 6))
	game.world.add_station(piece, Vector2i(1, 6))
	assert_eq(game.menu_stock.night_cost(), cost + Pantry.fee_of(drink), "two dispensers, one fee")
	game.menu_stock.stock_box(game.world.fixed_main().bread, Vector2i(3, 6))
	assert_eq(game.menu_stock.night_cost(), cost + Pantry.fee_of(drink), "a second box of a kind adds nothing")
	var names: Array = game.menu_stock.stock_lines().map(func(l: Dictionary) -> String: return l.name)
	assert_has(names, Pantry.name_of(drink))
	assert_eq(names.count(Pantry.name_of(game.world.fixed_main().bread)), 1, "the restock note reads the slots, a line a kind")



func test_the_menu_says_a_chilled_kind_needs_a_fridge():
	_game()
	var grill: String = game.world.fixed_main().grill
	game.kitchen.unstore(Vector2i(0, 2), Pantry.box_id(grill))
	game.menu_stock.menu_changed()
	assert_eq(game.menu_stock.item_off_reason(game.menu.items[0]), "%s: needs a box" % Pantry.name_of(grill), "a fridge stands empty")
	var fridge: Station = game.stations[Vector2i(0, 2)]
	game.world._unregister(fridge)
	fridge.queue_free()
	assert_eq(game.menu_stock.item_off_reason(game.menu.items[0]), "%s: needs a fridge" % Pantry.name_of(grill))
	assert_false(game.kitchen.has_fridge())



func test_night_zero_starts_with_a_stove_a_fridge_and_the_starting_mains_boxes():
	for theme in Pantry.THEMES:
		_night_zero(theme)
		assert_eq(game.phase, game.Phase.BUILD, theme)
		assert_eq(game.ledger.money, 150)
		var fm: Dictionary = game.world.fixed_main()
		assert_eq(game.stations[Vector2i(0, 3)].type, "stove", theme + ": a stove under the hood")
		assert_eq(game.stations[Vector2i(0, 2)].base, "fridge", theme + ": a fridge in the corner")
		for kind: String in [fm.grill, fm.bread]:
			assert_not_null(game.menu_stock.storage_of(kind), theme + ": " + kind + " is stocked")
		assert_not_null(game.world.find_station("cups"), theme + ": a cup stack by the plates")
		assert_eq(game.menu_stock.night_hint(), "", "first, a menu: the key over the board says it")
		assert_eq(game.menu_stock.open_block(), GameMenuStock.NO_MAIN_YET)
		game.menu_stock.write_test_menu()
		game.menu_stock.menu_changed()
		assert_eq(game.menu_stock.night_hint(), game.NIGHT_HINTS[2])
		assert_eq(game.menu_stock.open_block(), "", theme + ": the door card will flip")
		assert_gte(game.ledger.money, game.menu_stock.night_cost(), theme + ": with money for the stock")
		game.queue_free()



# ---------- The wall layer (PRD 8.5) ----------

func test_freezer_is_the_tall_fridges_specialist():
	assert_eq(Kitchen.parent_of("freezer"), "tall_fridge")
	assert_eq(Kitchen.step_of("freezer"), Kitchen.SPECIALIST_STEP)
	assert_eq(Kitchen.slots_of("freezer"), 2)
	assert_true(Kitchen.freezes("freezer"))
	assert_false(Kitchen.freezes("tall_fridge"))
	assert_true(Kitchen.is_tall("freezer"))
	assert_eq(Kitchen.children_of("tall_fridge"), ["glass_fridge", "freezer"] as Array[String])



func test_ice_cream_is_the_one_frozen_kind_and_a_freezer_also_stores_like_a_fridge():
	for kind: String in Pantry.ITEMS:
		assert_eq(Kitchen.is_frozen(kind), kind == "ice_cream", kind)
	var f := _kitchen()
	f.place(W, "tall_fridge")
	assert_false(f.can_store(W, "box_ice_cream"), "a fridge does not keep ice cream")
	var k := _kitchen()
	k.place(W, "freezer")
	assert_true(k.store(W, "box_ice_cream"), "a freezer does")
	assert_true(k.store(W, "patty"), "chilled kinds keep in a freezer")
	assert_false(k.store(W, "bun"), "two kinds and it is full")
	assert_false(k.can_place(W, "cabinet"), "a freezer fills both wall layers")



func test_wall_pieces_hang_over_anything_but_a_tall_piece():
	var k := _kitchen()
	assert_true(k.can_hang(W, "cabinet"), "over bare floor")
	assert_true(k.can_hang(W, "shelf"))
	assert_false(k.can_hang(W, "counter"), "a counter does not hang")
	assert_false(k.can_hang(C, "hood"), "only on a wall cell")
	assert_true(k.hang(W, "hood"))
	assert_false(k.can_hang(W, "cabinet"), "one high piece a cell")
	assert_eq(k.high_cells(), {W: "hood"})
	var t := _kitchen()
	t.place(W, "tall_fridge")
	assert_false(t.can_hang(W, "cabinet"))
	assert_true(Kitchen.is_high_only("cabinet") and Kitchen.is_high_only("hood"))
	assert_true(Kitchen.is_high_only("shelf") and Kitchen.is_high_only("wide_shelf"), "a shelf only hangs")



func test_lifting_the_base_leaves_the_wall_piece_and_its_stock():
	var k := _kitchen()
	k.set_cell(W, "counter")
	k.hang(W, "cabinet")
	assert_true(k.store(W, "bun"))
	assert_true(k.store(W, "lettuce"))
	assert_eq(k.cells[W].stock, {"base": ["bun"], "high": ["lettuce"]})
	k.set_cell(W, "")
	assert_eq(k.get_piece(W, "high"), "cabinet")
	assert_eq(k.stock(W), ["lettuce"], "the cabinet's box stays")
	assert_eq(k.remove(W, "high"), {"id": "cabinet", "stock": ["lettuce"]})
	assert_false(k.cells.has(W), "an empty cell is forgotten")



func test_first_room_hangs_its_fixtures_as_pieces_in_both_themes():
	for theme in Pantry.THEMES:
		_night_zero(theme)
		for at: Vector2i in [Vector2i(0, 3), Vector2i(0, 4)]:
			assert_true(game.kitchen.has_hood(at), theme + ": a hood where the stoves go")
		for at: Vector2i in [Vector2i(0, 5), Vector2i(0, 6)]:
			assert_eq(game.kitchen.get_piece(at, "high"), "cabinet", theme)
		assert_eq(game.kitchen.get_piece(Vector2i(3, 2), "high"), "shelf", theme + ": the jar shelf over the sink")
		assert_eq(game.highs.size(), 5, "and no wall hook")
		assert_eq(game.highs.values().filter(func(h: Station) -> bool: return h.node == "hook").size(), 0)
		var sponges: Array = game.stations.values().filter(func(st: Station) -> bool: return st.item == "tool:sponge")
		assert_eq(sponges.size(), 1, theme + ": a sponge to wipe the first spills with")
		assert_true((sponges[0] as Station).type in ["sink", "counter", "pass"], "set on the sink or a counter beside it")
		assert_eq(game.highs[Vector2i(0, 3)].facing, 1, "faces off the left wall")
		assert_eq(game.highs[Vector2i(3, 2)].facing, 0, "faces off the back wall")
		assert_true(game.placing.pick_up(_at(0, 4), game.player, true, "high"), "the hood over the starter's bread counter")
		assert_eq(game.player.hand.id, "hood")
		assert_eq(game.placing.sell_block(), "", theme + ": sellable")
		var money: int = game.ledger.money
		assert_true(game.placing.sell_hand())
		assert_eq(game.ledger.money, money + Catalog.price_of("hood") / 2)
		assert_false(game.kitchen.has_hood(Vector2i(0, 4)))
		game.queue_free()



func test_wall_cells_are_back_wall_cells_without_a_window():
	_game()
	assert_true(game.kitchen.is_wall(Vector2i(0, 4)), "the kitchen's left wall")
	assert_true(game.kitchen.is_wall(Vector2i(2, 2)), "the kitchen's back wall")
	assert_false(game.kitchen.is_wall(Vector2i(2, 4)), "the middle of the floor")
	assert_false(game.kitchen.is_wall(Vector2i(9, 4)), "the street side is cut low")
	var glass := 0
	for x in range(4, 10):
		glass += 0 if game.kitchen.is_wall(Vector2i(x, 0)) else 1
	assert_gt(glass, 0, "the dining room's windows take no wall piece")



func test_a_cabinet_hangs_over_a_piece_and_comes_off_before_it():
	_game()
	var c := Vector2i(2, 2)   # the dish rack, against the back wall
	assert_true(game.placing.pick_catalog("cabinet"))
	assert_false(game.placing.can_place(Vector3i(2, 4, 0)), "not away from a wall")
	assert_true(game.placing.can_place(Vector3i(2, 2, 0)))
	game._demo_hover = _at(2, 2)
	assert_eq(game.room_edit.build_action(), "Hang")
	assert_true(game.placing.place(Vector3i(2, 2, 0)))
	game.placing.cancel_hand()
	assert_eq(game.ledger.money, 500 - Catalog.price_of("cabinet"))
	var cab: Station = game.highs[c]
	assert_true(cab.high)
	assert_eq(game.stations[c].type, "dish_rack", "the dish rack still stands below")
	assert_false(game.grid.blocked.has(Vector2i(2, 3)))
	assert_true(game.placing.pick_catalog("hood"))
	assert_false(game.placing.can_place(Vector3i(2, 2, 0)), "one high piece a cell")
	game.placing.cancel_hand()
	game.player.set_meta("reach", true)
	assert_true(game.placing.pick_up(_at(2, 2)))
	assert_eq(game.player.hand.node, cab, "Reach takes the wall piece")
	game.placing.cancel_hand()
	assert_eq(game.highs[c], cab, "cancel hangs it back")
	assert_true(cab.visible)
	game.player.set_meta("reach", false)
	assert_true(game.placing.pick_up(_at(2, 2)))
	assert_eq(game.player.hand.id, "dish_rack", "plain E takes what stands under it")
	game.placing.cancel_hand()
	game.player.set_meta("reach", true)
	assert_true(game.placing.pick_up(_at(2, 2)))
	assert_true(game.placing.place(Vector3i(1, 2, 0)), "moved along the wall")
	assert_eq(game.kitchen.get_piece(Vector2i(1, 2), "high"), "cabinet")
	assert_eq(game.kitchen.get_piece(c, "high"), "")
	assert_false(game.stations.has(Vector2i(1, 2)), "it hangs over bare floor")



func test_a_shelf_in_hand_only_hangs_on_a_wall():
	_game()
	var c := Vector2i(4, 4)
	for x in range(3, 8):   # bare floor away from a wall
		if not game.kitchen.is_wall(Vector2i(x, 4)) and not game.stations.has(Vector2i(x, 4)):
			c = Vector2i(x, 4)
			break
	assert_false(game.stations.has(c), "the test needs bare floor away from a wall")
	assert_true(game.placing.pick_catalog("shelf"))
	game._demo_hover = _at(c.x, c.y)
	assert_eq(game.world.hand_layer(), "", "bare floor away from a wall takes no shelf")
	assert_false(game.placing.can_place(Vector3i(c.x, c.y, 0)))
	assert_eq(game.placing.place_refusal(Vector3i(c.x, c.y, 0)), GamePlacing.NO_WALL)
	assert_false(game.placing.place(Vector3i(c.x, c.y, 0)))
	assert_false(game.stations.has(c), "no low box is built")
	assert_false(game.player.hand.is_empty(), "it stays in hand")
	game.placing.cancel_hand()
	assert_true(game.placing.pick_up(_at(2, 2)), "the tray stack makes room")
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_true(game.placing.pick_catalog("shelf"))
	var w := Vector2i(2, 2)
	game._demo_hover = _at(w.x, w.y)
	assert_eq(game.world.hand_layer(), "high")
	assert_true(game.placing.place(Vector3i(w.x, w.y, 0)))
	assert_eq(game.kitchen.get_piece(w, "high"), "shelf")
	assert_false(game.stations.has(w), "hung, not standing")



func test_a_tall_fridge_will_not_go_under_a_wall_piece():
	_game()
	game.world.add_station("counter", Vector2i(2, 5))
	assert_true(game.placing.pick_up(_at(2, 5)))
	game.session.open_shop()
	assert_true(game.upgrades.buy_upgrade("fridge"))
	assert_true(game.upgrades.buy_upgrade("tall_fridge"))
	game.session.close_shop()
	assert_false(game.placing.can_place(Vector3i(0, 5, 0)), "a cabinet hangs there")
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_eq(game.kitchen.get_piece(Vector2i(2, 5), "base"), "tall_fridge")
	assert_true(game.placing.pick_up(_at(2, 2)), "the tray stack, off the back wall")
	assert_true(game.placing.place(Vector3i(3, 5, 0)))
	assert_true(game.placing.pick_up(_at(2, 5)))
	assert_true(game.placing.place(Vector3i(2, 2, 0)), "a tall fridge against the wall")
	assert_true(game.placing.pick_catalog("cabinet"))
	assert_false(game.placing.can_place(Vector3i(2, 2, 0)), "nothing above a tall fridge")



func test_tall_fridge_tree_reaches_the_freezer_and_glass_door():
	_game()
	game.world.add_station("counter", Vector2i(2, 5))
	assert_true(game.placing.pick_up(_at(2, 5)))
	game.session.open_shop()
	assert_true(game.upgrades.buy_upgrade("fridge"))
	assert_true(game.upgrades.buy_upgrade("tall_fridge"))
	assert_true(game.upgrades.buy_upgrade("freezer"))
	assert_eq(game.upgrades.hand_key(), "freezer")
	game.session.close_shop()
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_true(game.kitchen.chilled_slots(Vector2i(2, 5)) == 2)



func test_boxes_go_into_a_cabinet_and_come_out_from_below():
	_game()
	var c := Vector2i(1, 2)
	assert_true(game.placing.pick_catalog("cabinet"))
	assert_true(game.placing.place(Vector3i(1, 2, 0)))
	game.placing.cancel_hand()
	assert_true(game.placing.pick_catalog("box_lettuce" if Scenery.theme_id != "seaside" else "box_courgette"))
	assert_true(game.placing.can_place(Vector3i(1, 2, 0)), "a hung cabinet is a storage slot like any other")
	assert_true(game.placing.place(Vector3i(1, 2, 0)))
	assert_eq(game.kitchen.cells[c].stock.high.size(), 1)
	assert_eq(game.world.station_at(c), game.highs[c], "reached over bare floor")
	assert_true(game.menu_stock.kitchen_stock().size() > 0)
	game.day.start_day()
	game.player.position = _at(1, 3)
	game.player.look(Vector2i(0, -1))
	assert_eq(game.player.target_cell(), c)
	assert_true(game.cooking.use_station(game.world.station_at(c)).begins_with("Take"))
	assert_true(game.placing.pick_up(_at(1, 2)) == false, "nothing is moved by day")



func test_no_floor_or_door_takes_the_wall_from_a_hung_piece():
	_game()
	game.placing.pick_catalog("floor_tile")
	assert_false(game.placing.can_place(Vector3i(-1, 4, 0)), "floor behind the hood would take its wall away")
	assert_true(game.placing.can_place(Vector3i(-1, 2, 0)) or not game.plan.can_lay(Vector2i(-1, 2), "tile"), "beside it is fine")
	game.placing.cancel_hand()
	game.placing.pick_catalog("door")
	assert_false(game.placing.can_place(Vector3i(0, 5, 1)), "not through a cabinet's wall")
	game.placing.cancel_hand()
	game.player.set_meta("reach", true)
	assert_true(game.placing.pick_up(_at(0, 5)))
	assert_true(game.placing.sell_hand())
	game.placing.pick_catalog("door")
	assert_true(game.placing.can_place(Vector3i(0, 5, 1)))



func test_a_hood_over_a_stove_is_the_grease_flag():
	_game()
	var stove: Station = game.stations[Vector2i(0, 3)]
	assert_eq(game.floor_dirt.grease_factors(stove).hood, "hood")
	game.world.add_station("counter", Vector2i(2, 5))
	game.world.add_station("stove", Vector2i(2, 5))
	assert_eq(game.floor_dirt.grease_factors(game.stations[Vector2i(2, 5)]).hood, "")



# ---------- 8.6: new jobs and ingredients ----------

func test_the_new_jobs_sit_in_the_trees_as_the_prd_sketches_them():
	var want := {"grater": ["slicer", Kitchen.SPECIALIST_STEP], "rotary_grater": ["grater", Kitchen.EFFICIENT],
		"bread_knife": ["board", Kitchen.SPECIALIST_STEP], "juicer": ["bread_knife", Kitchen.SPECIALIST_STEP],
		"blender": ["juicer", Kitchen.SPECIALIST_STEP], "steamer": ["pot", Kitchen.SPECIALIST_STEP],
		"char_grill": ["stove", Kitchen.SPECIALIST_STEP], "two_tap_fountain": ["fountain", Kitchen.EFFICIENT],
		"coffee_machine": ["fountain", Kitchen.SPECIALIST_STEP], "wine_rack": ["wine_barrel", Kitchen.EFFICIENT],
		"beer_tap": ["wine_barrel", Kitchen.SPECIALIST_STEP]}
	for id: String in want:
		assert_eq([Kitchen.parent_of(id), Kitchen.step_of(id)], want[id], id)
		assert_eq(Kitchen.fit_of(id), "top", id + " stands on a counter")
		assert_false(Catalog.search(Kitchen.NODES[id].name).any(func(bp: Dictionary) -> bool: return bp.id == id and not bp.has("tree")),
			id + " is a step up its tree (sold outright as one)")
	assert_eq(Kitchen.jobs_of("grater"), {"grate": Kitchen.SPECIALIST, "slice": Kitchen.STAND_IN})
	assert_almost_eq(Kitchen.quality("rotary_grater", "grate"), 1.8, 0.001)
	assert_eq(Kitchen.jobs_of("bread_knife"), {"saw": Kitchen.SPECIALIST, "chop": Kitchen.STAND_IN})
	assert_eq(Kitchen.jobs_of("juicer"), {"juice": Kitchen.SPECIALIST}, "a specialist loses its stand-ins")
	assert_eq(Kitchen.jobs_of("blender"), {"blend": Kitchen.SPECIALIST, "juice": Kitchen.STAND_IN})
	assert_eq(Kitchen.jobs_of("steamer"), {"steam": Kitchen.SPECIALIST})
	assert_eq(Kitchen.NODES.coffee_machine.drinks, ["coffee"])
	assert_eq(Kitchen.NODES.beer_tap.drinks, ["ale"])
	for job in ["grate", "saw", "juice", "blend", "steam"]:
		assert_has(Kitchen.jobs_known(), job)
		var tool: String = Pantry.TOOL_STATION[job]
		assert_eq(Catalog.tool_of(tool), job, tool)
		assert_eq(Kitchen.family_of(tool), tool, tool + " is its own piece in the room")
		assert_has(Upgrades.JOB_WORDS, job)
	assert_eq(Kitchen.family_of("rotary_grater"), "grater")
	assert_eq(Upgrades.step_price("juicer"), 45)
	assert_eq(Upgrades.step_price("blender"), 60)
	assert_eq(Upgrades.step_price("steamer"), 40)
	assert_true(Upgrades.blurb("juicer").contains("Much better at juicing"))



func test_the_new_kinds_follow_the_table_and_the_balance():
	var want := {
		"shredded_cheese": ["diner", "grate"], "sourdough": ["diner", "saw"], "orange_juice": ["diner", "juice"],
		"milkshake": ["diner", "blend"], "ice_cream": ["diner", "none"], "steamed_corn": ["diner", "steam"],
		"cola": ["diner", "pour"], "coffee": ["diner", "pour"], "breadcrumbs": ["seaside", "grate"],
		"crusty_loaf": ["seaside", "saw"], "lemonade": ["seaside", "juice"], "fruit_smoothie": ["seaside", "blend"],
		"mussels": ["seaside", "steam"], "red_wine": ["seaside", "pour"], "ale": ["seaside", "pour"]}
	for id: String in want:
		assert_eq([Pantry.ITEMS[id].theme, Pantry.tool_of(id)], want[id], id)
		var worth: int = Pantry.ITEMS[id].worth
		assert_between(worth, 1, 7, id + "'s worth sits with the others")
		if not Pantry.is_derived(id):
			assert_between(int(Pantry.ITEMS[id].fee), 2, 9, id + "'s fee")
	var chilled: Array = Pantry.ITEMS.keys().filter(func(k: String) -> bool: return Kitchen.is_chilled(k))
	chilled.sort()
	assert_eq(chilled, ["calamari", "cheese", "fish", "mussels", "patty", "shredded_cheese"], "the PRD's chilled list")
	assert_eq([Pantry.source_of("lemonade"), Pantry.source_of("milkshake"), Pantry.source_of("steamed_corn")],
		["lemon", "ice_cream", "corn"], "made from another kind's box")
	assert_eq(Pantry.made_from("lemon"), ["lemonade"])
	for d in ["lemonade", "milkshake", "steamed_corn"]:
		assert_eq(Pantry.fee_of(d), 0, d + " costs nothing: its source's box pays")
		assert_true(Pantry.needs_prep(d))
	assert_gt(int(Pantry.ITEMS.steamed_corn.worth), int(Pantry.ITEMS.corn.worth), "steamed is better than boiled")
	assert_true(Pantry.is_drink("orange_juice") and Pantry.is_drink("milkshake") and Pantry.is_drink("ale"))
	assert_false(Pantry.is_bread("breadcrumbs"), "a coating never wraps a stack")
	assert_true(Pantry.is_bread("sourdough"), "a main's base instead of a bun")
	assert_eq(Menu.default_name(["fish", "breadcrumbs"]), "Breaded fillet")
	assert_eq(Menu.default_name(["fish", "breadcrumbs", "lemon"]), "Breaded fillet", "trimmed to fit, as any name")
	assert_eq(Tray.verb("grate"), "grating")



func test_cheese_grates_at_a_grater_and_slices_at_a_slicer():
	_game(false)
	game.menu_stock.stock_box("cheese", Vector2i(2, 6))
	var grater := _tool_on("grater", Vector2i(2, 5))
	var slicer := _tool_on("slicer", Vector2i(3, 5))
	assert_eq([grater.type, grater.main_job()], ["grater", "grate"])
	assert_has(game.menu_stock.kitchen_tools(), "grate")
	assert_true(game.cooking.use_station(game.menu_stock.storage_of("cheese")).begins_with("Take"))
	assert_eq(game.player.held, "raw:cheese")
	assert_eq(game.cooking.use_station(slicer, true), "Slice", "the slicer slices the same raw cheese")
	assert_eq(game.cooking.use_station(grater), "Grate", "the grater's own job wins over its slicing stand-in")
	assert_eq(game.cooking.prompt_for(grater), "Hold to grate, keep it green")
	_grate()
	assert_eq(game.player.held, "prep:shredded_cheese")
	assert_eq(game.player.held_quality, Prep.GOOD)
	assert_almost_eq(game.player.speed(), Player.SPEED * Prep.BURST_SPEED, 0.01, "a good grate gives a burst")


func test_raw_lemon_still_slices_at_a_grater():
	_game(false)
	var grater := _tool_on("grater", Vector2i(2, 5))
	assert_eq(GameCooking.press_job(grater, {"id": "lemon", "state": "raw"}), ["slice", "lemon"])


func test_each_food_has_one_box_per_theme():
	for theme: String in ["diner", "seaside"]:
		var boxed: Array = Pantry.ITEMS.keys().filter(func(k: String) -> bool:
			return Pantry.ITEMS[k].theme == theme and Pantry.has_box(k))
		assert_eq(boxed.count("cheese") if theme == "diner" else 0, 1 if theme == "diner" else 0)
		assert_false(boxed.has("shredded_cheese"), "grated cheese comes from the cheese box")
	assert_false(Catalog.ITEMS.has("box_shredded_cheese"))
	assert_eq(Pantry.source_of("shredded_cheese"), "cheese")


func test_grating_too_fast_scrapes_a_knuckle():
	_game(false)
	game.menu_stock.stock_box("cheese", Vector2i(2, 6))
	var grater := _tool_on("grater", Vector2i(2, 5))
	game.cooking.use_station(game.menu_stock.storage_of("cheese"))
	game.cooking.use_station(grater)
	var who: PlayerInput = game.controls.players[0]
	who.hold("test", "a", "use", true)
	for i in 200:
		if game.prep_games.prep_of(0).is_empty():
			break
		game.step(0.05)
	who.hold("test", "a", "use", false)
	assert_eq(game.player.held_quality, Prep.BAD)



func test_a_loaf_saws_at_the_bread_knife_on_each_strokes_end():
	_game(false)
	game.menu_stock.stock_box("sourdough", Vector2i(2, 6))
	var knife := _tool_on("bread_knife", Vector2i(2, 5))
	game.cooking.use_station(game.menu_stock.storage_of("sourdough"))
	assert_eq(game.cooking.use_station(knife), "Saw")
	var stroke := Prep.saw_stroke(Kitchen.SPECIALIST)
	for k in Prep.SAW_STROKES:
		while float(game.prep_games.prep_of(0).t) < (k + 0.95) * stroke:
			game.step(0.01)
		game.coop.act(0, "use")
	for i in 20:
		game.step(0.05)
	assert_eq(game.player.held, "prep:sourdough")
	assert_eq(game.player.held_quality, Prep.GOOD)



func test_a_lemon_juices_into_lemonade_and_back_gives_the_lemon_back():
	_game(false)
	game.menu_stock.stock_box("lemon", Vector2i(2, 6))
	var juicer := _tool_on("juicer", Vector2i(2, 5))
	var have: Array = game.menu_stock.kitchen_stock().map(func(s: Dictionary) -> String: return s.ingredient)
	assert_has(have, "lemonade", "a lemon box stocks lemonade too")
	assert_false(game.menu_stock.stock_lines().any(func(l: Dictionary) -> bool: return l.name == "Lemonade"), "and costs no line of its own")
	game.cooking.use_station(game.menu_stock.storage_of("lemon"))
	assert_eq(game.cooking.use_station(juicer), "Juice")
	assert_eq(juicer.item, "raw:lemon", "the lemon sits on the juicer")
	game.prep_games.cancel_prep(0)
	assert_eq(game.player.held, "raw:lemon")
	assert_eq(game.cooking.use_station(juicer), "Juice")
	var who: PlayerInput = game.controls.players[0]
	var band := Vector2(Prep.juice_good(Kitchen.SPECIALIST), Prep.JUICE_TOP)
	for k in Prep.JUICE_HALVES:
		who.hold("test", "a", "use", true)
		while float(game.prep_games.prep_of(0).fill) < (band.x + band.y) / 2.0:
			game.step(0.01)
		who.hold("test", "a", "use", false)
		game.step(0.01)
	assert_eq(game.player.held, "prep:lemonade")
	assert_eq(game.player.held_quality, Prep.GOOD)



func test_ice_cream_from_the_freezer_blends_into_a_milkshake():
	_game(false)
	assert_not_null(game.menu_stock.stock_box("ice_cream", Vector2i(3, 6)), "ice cream goes in a freezer")
	assert_eq(game.kitchen.get_piece(Vector2i(3, 6), "base"), "freezer")
	var blender := _tool_on("blender", Vector2i(2, 5))
	assert_has(game.menu_stock.kitchen_tools(), "juice", "a blender juices at a pinch")
	game.cooking.use_station(game.menu_stock.storage_of("ice_cream"))
	assert_eq(game.player.held, "prep:ice_cream", "ice cream needs no prep of its own")
	assert_eq(game.cooking.use_station(blender), "Blend")
	for k in Prep.BLEND_PULSES:
		game.coop.act(0, "use")
		for i in 6:
			game.step(0.05)
	for i in 10:
		game.step(0.05)
	assert_eq(game.player.held, "prep:milkshake")
	assert_eq(game.player.held_quality, Prep.GOOD)



func test_pulsing_too_hard_spills_the_blender():
	_game(false)
	game.menu_stock.stock_box("fruit_smoothie", Vector2i(2, 6))
	var blender := _tool_on("blender", Vector2i(2, 5))
	game.cooking.use_station(game.menu_stock.storage_of("fruit_smoothie"))
	game.cooking.use_station(blender)
	for k in Prep.BLEND_PULSES:
		game.coop.act(0, "use")
	game.step(0.02)
	assert_eq(game.player.held, "prep:fruit_smoothie")
	assert_eq(game.player.held_quality, Prep.BAD)



func test_corn_steams_or_boils_and_steamed_is_its_own_kind():
	_game(false)
	game.menu_stock.stock_box("corn", Vector2i(2, 6))
	var steamer := _tool_on("steamer", Vector2i(2, 5))
	assert_false(steamer.is_heat_tool(), "the steamer is a press tool, not a heat one")
	game.cooking.use_station(game.menu_stock.storage_of("corn"))
	assert_eq(game.cooking.use_station(steamer), "Steam")
	var t := Prep.steam_time(Kitchen.SPECIALIST) * (Prep.steam_band(Kitchen.SPECIALIST).x + 0.05)
	while float(game.prep_games.prep_of(0).t) < t:
		game.step(0.02)
	game.coop.act(0, "use")
	game.step(0.02)
	assert_eq(game.player.held, "prep:steamed_corn")
	assert_eq(game.player.held_quality, Prep.GOOD)
	game.player.set_held("raw:mussels")
	assert_eq(game.cooking.use_station(steamer), "Steam")
	for i in 200:
		if game.prep_games.prep_of(0).is_empty():
			break
		game.step(0.05)
	assert_eq(game.player.held, "prep:mussels")
	assert_eq(game.player.held_quality, Prep.BAD, "left too long: mushy")



func test_a_two_tap_fountain_pours_what_the_rail_wants_and_turns_with_empty_hands():
	_game(false)
	for d in ["soda", "cola", "coffee"]:
		game.menu.add("drink", [d], d)
	var two: Station = _tool_on("two_tap_fountain", Vector2i(2, 5))
	assert_eq(game.menu_stock.dispenser_drinks(two), ["soda", "cola"])
	game.player.set_held("dishes", 1.0, [Dish.make(Dish.CUP)])
	assert_eq(game.cooking.use_station(two, true), "Pour soda")
	game.tickets.append({"id": 99, "guest": null, "items": [{"course": "drink", "ingredients": ["cola"]}]})
	assert_eq(game.cooking.use_station(two, true), "Pour cola", "a ticket wants cola")
	game.tickets.clear()
	game.player.set_held("")
	assert_eq(game.cooking.use_station(two), "Turn to cola")
	game.player.set_held("dishes", 1.0, [Dish.make(Dish.CUP)])
	assert_eq(game.cooking.use_station(two, true), "Pour cola", "turned to the next tap")
	var coffee: Station = _tool_on("coffee_machine", Vector2i(3, 5))
	assert_eq(game.cooking.use_station(coffee, true), "Pour coffee")
	var have: Array = game.menu_stock.kitchen_stock().map(func(s: Dictionary) -> String: return s.ingredient)
	for d in ["soda", "cola", "coffee"]:
		assert_has(have, d)



func test_turned_fridge_keeps_its_turn_when_put_down():
	_game()
	game.session.open_build()
	game.ledger.money = 500
	var f: Station = game.world.add_station("fridge", Vector2i(2, 5), 1, 0, "fridge")
	assert_true(game.placing.pick_up(_at(2, 5), null, true))
	game.placing.rotate_hand()
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_eq(f.facing, 1, "picked up whole, turned, put back")



func test_turned_fridge_lifted_with_its_card_keeps_its_turn():
	_game()
	game.session.open_build()
	var f: Station = game.world.add_station("fridge", Vector2i(2, 5), 1, 0, "fridge")
	var ch: Player = game.player
	ch.hand = {"id": f.type, "tier": f.tier, "price": 0, "facing": f.facing, "moving": true, "node": f,
		"in_place": true, "carry": true, "layer": "base", "y": f.position.y,
		"from": Vector3i(2, 5, 0), "from_facing": f.facing}
	assert_true(game.card.open_storage(Vector2i(2, 5)))
	game.session.close_shop()
	assert_false(ch.hand.is_empty(), "kept in hand")
	game.placing.rotate_hand()
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_eq(f.facing, 1)


# ---------- a tool kept on a shelf or in a cabinet (PRD 9.5) ----------

func test_a_kept_tool_makes_the_cell_hold_chemicals_and_food_is_refused():
	var k := _kitchen()
	k.set_cell(W, "counter")
	k.hang(W, "shelf")
	assert_false(k.holds_cleaning(W))
	assert_true(k.keep_tool(W, "sponge"))
	assert_true(k.holds_cleaning(W))
	assert_eq(k.tool_at(W), "sponge")
	assert_eq(k.store_refusal(W, "bun"), "No food with chemicals")
	assert_false(k.store(W, "bun"))


func test_a_tool_is_refused_in_a_cell_that_stores_food():
	var k := _kitchen()
	k.set_cell(W, "counter")
	k.hang(W, "shelf")
	assert_true(k.store(W, "bun"), "food on the counter below")
	assert_eq(k.tool_refusal(W), "No chemicals with food")
	assert_false(k.keep_tool(W, "sponge"))


func test_a_tool_takes_one_slot_so_a_wide_shelf_keeps_it_and_one_treatment_box():
	var k := _kitchen()
	k.hang(W, "wide_shelf")
	assert_true(k.keep_tool(W, "sponge"))
	assert_true(k.store(W, Treatments.box_id("cleaner")), "a chemical box shares the cell")
	assert_false(k.store(W, Treatments.box_id("finish")), "the wide shelf's two slots are full")
	var one := _kitchen()
	one.hang(W, "shelf")
	assert_true(one.keep_tool(W, "sponge"))
	assert_false(one.store(W, Treatments.box_id("cleaner")), "a one-slot shelf is full with its tool")


func test_a_cabinet_keeps_a_tool_and_a_fridge_or_counter_never_does():
	var k := _kitchen()
	k.set_cell(W, "fridge")
	k.hang(W, "cabinet")
	assert_true(k.keep_tool(W, "scourer"))
	assert_eq(k.tool_refusal(W), "No free slot", "one tool a cell")
	var bare := _kitchen()
	bare.set_cell(W, "fridge")
	assert_ne(bare.tool_refusal(W), "", "a fridge takes no tool")
	assert_eq(k.take_tool(W), "scourer")
	assert_false(k.holds_cleaning(W))


func test_lifting_the_shelf_forgets_its_tool():
	var k := _kitchen()
	k.hang(W, "shelf")
	k.keep_tool(W, "sponge")
	k.remove(W, "high")
	assert_eq(k.tool_at(W), "")
