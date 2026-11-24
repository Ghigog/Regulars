extends "res://test/helpers/kitchen_case.gd"


func test_a_tool_needs_a_counter_under_it():
	_game()
	var c := Vector2i(2, 5)
	assert_true(game.placing.pick_catalog("board"))
	assert_false(game.placing.can_place(Vector3i(2, 5, 0)), "no counter there")
	game.placing.cancel_hand()
	assert_true(game.placing.pick_catalog("counter"))
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	game.placing.cancel_hand()
	assert_true(game.placing.pick_catalog("board"))
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	game.placing.cancel_hand()
	var st: Station = game.stations[c]
	assert_eq(st.type, "board")
	assert_eq(st.base, "counter")
	assert_eq(game.kitchen.get_piece(c, "top"), "board")
	assert_eq(game.ledger.money, 500 - Catalog.price_of("counter") - Catalog.price_of("board"))
	assert_true(game.placing.pick_catalog("fountain"))
	assert_false(game.placing.can_place(Vector3i(2, 5, 0)), "one tool per counter")
	assert_false(game.placing.can_place(Vector3i(3, 2, 0)), "not on a sink")



func test_every_tool_starts_on_a_counter():
	_game()
	for st: Station in game.stations.values():
		if Kitchen.is_top(st.type):
			assert_eq(st.base, "counter", st.type)
			assert_eq(game.kitchen.get_piece(st.cell, "top"), Kitchen.node_of(st.type))



func test_lifting_a_tool_leaves_its_counter_and_both_sell():
	_game()
	var c := _board_on_counter()
	game.player.position = _at(2, 6)
	assert_true(game.placing.pick_up(_at(2, 5)))
	assert_eq(game.player.hand.id, "board", "the tool comes off first")
	assert_eq(game.stations[c].type, "counter")
	assert_eq(game.kitchen.get_piece(c, "top"), "")
	var before: int = game.ledger.money
	assert_true(game.placing.sell_hand())
	assert_eq(game.ledger.money, before + Catalog.price_of("board"), "bought tonight: back in full")
	assert_true(game.placing.pick_up(_at(2, 5)))
	assert_eq(game.player.hand.id, "counter")
	assert_true(game.placing.sell_hand(), "counters are for sale")
	assert_false(game.stations.has(c))
	assert_false(game.kitchen.cells.has(c))
	assert_false(game.grid.blocked.has(c))



func test_a_stove_lifts_and_sells_whole_with_its_counter():
	_game()
	var c := Vector2i(0, 3)
	assert_eq(game.stations[c].type, "stove")
	assert_true(game.placing.pick_up(_at(0, 3)))
	assert_eq(game.player.hand.id, "hood", "the hood over it first (PRD 8.5)")
	assert_true(game.placing.sell_hand())
	assert_true(game.placing.pick_up(_at(0, 3)))
	assert_eq(game.player.hand.id, "stove", "then the stove, its counter and all")
	assert_eq((game.player.hand.node as Station).base, "counter")
	assert_false(game.stations.has(c), "no bare counter left behind")
	var before: int = game.ledger.money
	assert_true(game.placing.sell_hand())
	assert_eq(game.ledger.money, before + (Kitchen.price_of("stove") + Kitchen.price_of("counter")) / 2)
	assert_false(game.kitchen.cells.has(c))



func test_a_moved_tool_goes_back_onto_its_counter():
	_game()
	var c := _board_on_counter()
	var board: Station = game.stations[c]
	assert_true(game.placing.pick_up(_at(2, 5)))
	game.placing.cancel_hand()
	assert_eq(game.stations[c], board)
	assert_true(board.visible)
	assert_eq(game.kitchen.get_piece(c, "top"), "board")
	assert_true(game.placing.pick_up(_at(2, 5)))
	assert_true(game.placing.place(Vector3i(4, 3, 0)), "onto the pass")
	assert_eq(game.stations[Vector2i(4, 3)], board)
	assert_true(board.pass_look, "it takes on the counter it stands on")
	assert_eq(game.stations[c].type, "counter")



func test_a_moved_stove_goes_on_the_floor_never_onto_a_counter():
	_game()
	var stove: Station = game.stations[Vector2i(0, 4)]
	game.highs.erase(Vector2i(0, 4))   # the hood over it is not this test's
	assert_true(game.placing.pick_up(_at(0, 4)))
	assert_eq(game.player.hand.get("node"), stove)
	assert_false(game.placing.can_place(Vector3i(4, 3, 0)), "not onto the pass: it is a counter itself")
	assert_true(game.placing.place(Vector3i(2, 5, 0)), "onto open floor")
	assert_eq(game.stations[Vector2i(2, 5)], stove)
	assert_eq(stove.base, "counter")
	assert_eq(game.kitchen.get_piece(Vector2i(2, 5), "top"), "stove")



func test_a_counter_on_a_counter_is_refused():
	_game()
	var c := Vector2i(2, 5)
	game.world.add_station("counter", c)
	var money: int = game.ledger.money
	assert_true(game.placing.pick_catalog("counter"))
	var spot := Vector3i(2, 5, 0)
	assert_false(game.placing.can_place(spot))
	assert_eq(game.placing.place_refusal(spot), GamePlacing.TAKEN)
	assert_false(game.placing.place(spot))
	assert_eq(game.ledger.money, money, "nothing spent")
	assert_eq(game.stations[c].base, "counter")
	assert_eq(game.kitchen.slots(c), 1)
	game.placing.cancel_hand()


func test_a_moved_counter_is_refused_on_a_counter_and_goes_on_the_floor():
	_game()
	game.world.add_station("counter", Vector2i(2, 5))
	game.world.add_station("counter", Vector2i(3, 5))
	assert_true(game.placing.pick_up(_at(2, 5)))
	assert_false(game.placing.can_place(Vector3i(3, 5, 0)))
	assert_eq(game.placing.place_refusal(Vector3i(3, 5, 0)), GamePlacing.TAKEN)
	assert_true(game.placing.place(Vector3i(6, 6, 0)), "open floor still works")


func test_a_tool_goes_on_a_tree_bought_double_counter():
	_game()
	var c := Vector2i(2, 5)
	game.world.add_station("counter", c, 1, 0, "double_counter")
	assert_eq(game.kitchen.slots(c), 2)
	assert_true(game.placing.pick_catalog("board"))
	assert_true(game.placing.place(Vector3i(2, 5, 0)), "a tool on a double counter")
	game.placing.cancel_hand()
	assert_eq(game.stations[c].base, "double_counter")


func test_the_starting_pass_is_counters_that_sell_and_take_tools():
	_game()
	for z in range(2, 6):
		var st: Station = game.stations[Vector2i(4, z)]
		assert_eq(st.type, "counter")
		assert_true(st.pass_look)
	assert_true(game.placing.pick_catalog("board"))
	assert_true(game.placing.place(Vector3i(4, 2, 0)))
	game.placing.cancel_hand()
	assert_not_null(game.stations[Vector2i(4, 2)].get_node_or_null("till"), "the till moves onto the tool")
	assert_true(game.placing.pick_up(_at(4, 5)))
	assert_true(game.placing.sell_hand(), "starting counters are for sale")



func test_a_tool_is_not_put_on_a_counter_with_something_on_it():
	_game()
	game.stations[Vector2i(4, 4)].set_item(Tray.kind("prep", "bun"))
	assert_true(game.placing.pick_catalog("board"))
	assert_false(game.placing.can_place(Vector3i(4, 4, 0)))



func test_a_tops_surface_holds_one_thing_and_empty_hands_take_it_first():
	_game()
	game.day.start_day()
	var board: Station = game.world.add_station("board", Vector2i(4, 4))
	assert_eq(board.base, "counter", "it went onto the pass counter")
	game.player.set_held(Tray.kind("prep", "bun"))
	assert_eq(game.cooking.use_station(board), "Put down")
	assert_eq(board.item, "prep:bun")
	assert_eq(game.cooking.use_station(board), "Pick up", "empty hands take the thing first")
	assert_eq(game.player.held, "prep:bun")
	var stove: Station = game.world.find_station("stove")
	game.player.set_held("dishes", 1.0, [Dish.make(Dish.PLATE)])
	assert_eq(game.cooking.use_station(stove), "Plates go on a clear counter", "no plate on a tool")
	assert_false(stove.is_cooking())
	assert_eq(game.player.dishes.size(), 1, "the plate stays in hand")



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
	for key: String in ["board", "stove", "counter", "fountain", "wine_barrel", "plant@1", "jukebox@2", "booth@1", "hood"]:
		assert_true(Upgrades.has_tree(key), key)   # the hood grows into an extractor (PRD 9.5)
	for key: String in ["", "cabinet"]:
		assert_false(Upgrades.has_tree(key), key + " has nowhere to go")
	assert_eq(Upgrades.catalog_id("jukebox@3"), "jukebox")
	assert_eq(Upgrades.children("plant@3"), [] as Array[String], "three tiers in all")



func test_efficient_steps_run_along_a_row_and_specialists_fork_below():
	var board := Upgrades.layout("board")
	assert_eq(board, {"board": Vector2i(0, 0), "sharp_knife": Vector2i(1, 0), "butcher_block": Vector2i(2, 0),
		"slicer": Vector2i(1, 1), "auto_slicer": Vector2i(2, 1), "grater": Vector2i(2, 2), "rotary_grater": Vector2i(3, 2),
		"bread_knife": Vector2i(1, 3), "juicer": Vector2i(2, 4), "blender": Vector2i(3, 5)}, "the whole cutting tree (PRD 8.6)")
	var stove := Upgrades.layout("stove")
	assert_eq(stove.range, Vector2i(1, 0))
	assert_eq(stove.two_hob_range, Vector2i(2, 0))
	assert_eq([stove.char_grill, stove.pot, stove.steamer, stove.fryer, stove.twin_fryer],
		[Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(1, 4), Vector2i(2, 4)])
	assert_eq(Upgrades.extent(stove), Vector2i(3, 5))
	var counter := Upgrades.layout("counter")
	assert_eq([counter.double_counter, counter.long_counter, counter.fridge, counter.tall_fridge, counter.glass_fridge],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 2)], "fridge nodes are in the counter's tree")
	assert_eq(Upgrades.layout("slicer").keys().size(), 4, "a tree is drawn from the held piece on")
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
	assert_has(ids, "board")
	for id: String in ["stove", "fryer", "pot", "slicer"]:
		assert_does_not_have(ids, id, id + " is a step up the counter's, stove's or board's tree")
	var nodes := Catalog.search("", "Kitchen", "diner").filter(func(bp: Dictionary) -> bool: return bp.has("tree"))
	assert_eq(nodes, [], "steps are bought on the lifted piece, not in the shop")



func test_a_stove_grows_from_a_bare_counter_for_its_whole_price():
	assert_true(Upgrades.children("counter").has("stove"), "a branch of the counter's tree")
	assert_eq(Upgrades.parent("stove"), "counter")
	assert_eq(Kitchen.parent_of("stove"), "", "still a root piece in the room: it lifts off its counter")
	assert_eq(Upgrades.step_price("stove"), Kitchen.price_of("stove"), "the counter stays, so the stove is paid in full")
	assert_eq(Upgrades.step_price("range"), Kitchen.price_of("range") - Kitchen.price_of("stove"))
	assert_true(Upgrades.can_buy("counter", "stove", 999, 1))
	assert_false(Upgrades.can_buy("double_counter", "stove", 999, 1))
	assert_true(Upgrades.layout("counter").has("fryer"), "the counter's tree shows the way to the fryer")



func test_a_full_fridge_says_it_is_full_not_that_it_needs_a_fridge():
	var k := Kitchen.new()
	var c := Vector2i(1, 1)
	k.set_cell(c, "counter")
	assert_true(k.store(c, "box_bun"))
	k.set_cell(c, "fridge")   # upgraded where it stands: the bun stays in its one slot
	assert_eq(k.store_refusal(c, "box_patty"), "The fridge is full. Take a box out first")
	k.set_cell(c, "counter")
	k.unstore(c, "box_bun")
	assert_eq(k.store_refusal(c, "box_patty"), "Needs a fridge")



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

func test_a_lifted_piece_shows_its_upgrades_along_the_bottom():
	_game()
	game.session.open_shop()
	assert_true(game.shopping and not game.upgrading, "empty hands: the shop")
	game.session.close_shop()
	game.world.add_station("counter", Vector2i(2, 5))
	game.world.add_station("board", Vector2i(2, 5))
	assert_true(game.placing.pick_up(_at(2, 5)))
	assert_eq(game.upgrades.hand_key(), "board")
	game.session.open_shop()
	assert_false(game.shopping, "Tab with a piece in hand: put it down to shop")
	var keys: Array = game.upgrades.strip_choices().map(func(c: Dictionary) -> String: return str(c.key))
	assert_eq(keys, Upgrades.children("board").filter(func(k: String) -> bool: return Upgrades.level(k) <= 1))
	assert_eq(str(game.upgrades.strip_chosen().key), keys[0])
	game.coop.act(0, "next")
	assert_eq(str(game.upgrades.strip_chosen().key), keys[1 % keys.size()], "X: the next")
	game.coop.act(0, "prev")
	game.coop.act(0, "prev")
	assert_eq(str(game.upgrades.strip_chosen().key), keys[-1], "Z from the first wraps to the last")
	assert_eq(game.upgrades.hand_key(), "board", "still in hand")



func test_a_piece_with_no_tree_does_not_open_the_shop():
	_game()
	assert_true(game.placing.pick_up(_at(2, 2)), "the tray stack")
	game.session.open_shop()
	assert_false(game.shopping)



func test_buying_a_step_turns_the_held_piece_into_it():
	_game()
	game.world.add_station("counter", Vector2i(2, 5))
	game.world.add_station("board", Vector2i(2, 5))
	assert_true(game.placing.pick_up(_at(2, 5)))
	assert_false(game.upgrades.buy_upgrade("auto_slicer"), "not before the slicer")
	assert_eq(game.ledger.money, 500)
	while str(game.upgrades.strip_chosen().key) != "slicer":
		game.coop.act(0, "next")
	game.coop.act(0, "buy")   # Space buys the slicer
	assert_eq(game.ledger.money, 500 - 35)
	assert_eq(game.upgrades.hand_key(), "slicer")
	assert_eq(game.hand.id, "slicer", "it works as a slicer now")
	assert_true(game.placing.place(Vector3i(2, 5, 0)), "back onto its counter")
	var st: Station = game.stations[Vector2i(2, 5)]
	assert_eq([st.type, st.node], ["slicer", "slicer"])
	assert_eq(game.kitchen.get_piece(Vector2i(2, 5), "top"), "slicer")
	assert_true(game.placing.pick_up(_at(2, 5)))
	game.ledger.day += 1   # a later night: no same-night return
	assert_eq(game.placing.sell_value(), Kitchen.price_of("slicer") / 2, "sold for its whole price, as before: half")



func test_an_upgraded_counter_becomes_a_fridge_and_does_not_stack():
	_game()
	game.world.add_station("counter", Vector2i(2, 5))
	game.world.add_station("counter", Vector2i(3, 5))
	assert_true(game.placing.pick_up(_at(2, 5)))
	game.session.open_shop()
	assert_true(game.upgrades.buy_upgrade("fridge"))
	game.session.close_shop()
	assert_eq((game.hand.node as Station).base, "fridge")
	assert_false(game.placing.can_place(Vector3i(3, 5, 0)), "a fridge is not a counter to stack")
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_eq(game.kitchen.get_piece(Vector2i(2, 5), "base"), "fridge")
	assert_eq(game.kitchen.chilled_slots(Vector2i(2, 5)), 1)
	game.world.add_station("stove", Vector2i(2, 5))
	assert_eq(game.stations[Vector2i(2, 5)].type, "stove", "a tool still goes on its top")
	assert_eq(game.stations[Vector2i(2, 5)].base, "fridge")



func test_a_tree_bought_double_counter_lifts_off_whole():
	_game()
	game.world.add_station("counter", Vector2i(2, 5))
	assert_true(game.placing.pick_up(_at(2, 5)))
	game.session.open_shop()
	assert_true(game.upgrades.buy_upgrade("double_counter"))
	game.session.close_shop()
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_true(game.placing.pick_up(_at(2, 5)))
	assert_eq((game.hand.node as Station).base, "double_counter")
	assert_false(game.stations.has(Vector2i(2, 5)), "nothing is left behind")



func test_a_fern_climbs_its_short_tree():
	_game()
	game.ledger.xp = 1000
	game.world.add_station("plant", Vector2i(5, 5))
	assert_true(game.placing.pick_up(_at(5, 5)))
	assert_eq(game.upgrades.hand_key(), "plant@1")
	assert_true(game.upgrades.buy_upgrade("plant@2"))
	assert_eq((game.hand.node as Station).tier, 2)
	assert_eq(int(game.hand.tier), 2)
	assert_eq(game.ledger.money, 500 - (Catalog.price_of("plant", 2) - Catalog.price_of("plant")))
	game.ledger.day += 1   # a later night: no same-night return
	assert_eq(game.placing.sell_value(), Catalog.price_of("plant", 2) / 2)



func test_the_board_slices_as_a_stand_in():
	_game(false)
	game.menu_stock.stock_box("cheese", Vector2i(2, 6))
	game.world.add_station("counter", Vector2i(2, 5))
	var board: Station = game.world.add_station("board", Vector2i(2, 5))
	assert_has(game.menu_stock.kitchen_tools(), "slice", "a menu can offer cheese with only a board")
	game.cooking.use_station(game.menu_stock.storage_of("cheese"))
	assert_eq(game.cooking.use_station(board), "Slice")
	assert_almost_eq(float(game.prep_games.prep_of(0).q), Kitchen.STAND_IN, 0.001)
	for k in Prep.SLICE_COUNT:
		game.coop.act(0, "use")
		game.step(0.05)
	for i in int(Prep.slice_time(Kitchen.STAND_IN) / 0.1) + 1:
		game.step(0.1)
	assert_eq(game.player.held, "prep:cheese")



func test_a_stove_fries_as_a_stand_in_with_a_narrower_window():
	_game(false)
	game.menu_stock.stock_box("potato", Vector2i(2, 6))
	game.world.add_station("counter", Vector2i(2, 5))
	var stove: Station = game.world.add_station("stove", Vector2i(2, 5))
	assert_has(game.menu_stock.kitchen_tools(), "fry")
	assert_has(game.menu_stock.kitchen_tools(), "boil")
	game.cooking.use_station(game.menu_stock.storage_of("potato"))
	assert_eq(game.cooking.use_station(stove), "Fry")
	assert_eq(stove.mode(), "fryer", "a stove frying works as a fryer")
	for i in int((Prep.FRY_GOOD + 0.5) / 0.1):
		game.step(0.1)
	assert_eq(game.cooking.use_station(stove), "Lift basket")
	for i in int((Prep.FRY_REST + 0.2) / 0.1):
		game.step(0.1)
	assert_eq(game.cooking.use_station(stove), "Pick up")
	assert_eq(game.player.held, "prep:potato")
	assert_eq(stove.heat, "", "an empty stove is a stove again")
	assert_eq(stove.mode(), "stove")



func test_an_auto_slicer_plays_itself():
	_game(false)
	game.menu_stock.stock_box("cheese", Vector2i(2, 6))
	game.world.add_station("counter", Vector2i(2, 5))
	var auto: Station = game.world.add_station("auto_slicer", Vector2i(2, 5))
	assert_eq([auto.type, auto.node], ["slicer", "auto_slicer"])
	game.cooking.use_station(game.menu_stock.storage_of("cheese"))
	assert_eq(game.cooking.use_station(auto), "Slice")
	for i in int(Prep.AUTO_TIME / 0.1) + 2:
		game.step(0.1)
	assert_eq(game.player.held, "prep:cheese")
	assert_eq(game.player.held_quality, Prep.GOOD)
	assert_almost_eq(game.player.speed(), Player.SPEED, 0.01, "no burst for a piece that plays itself")
