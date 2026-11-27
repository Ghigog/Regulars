extends "res://test/helpers/floor_mess_case.gd"


# ---------- 9.5: floor treatments ----------

func test_the_treatment_tree_and_its_prices_a_cell():
	assert_true(Treatments.is_root("cleaner"))
	var kids := Treatments.children("cleaner")
	kids.sort()
	assert_eq(kids, ["finish", "primer", "strong_cleaner"] as Array[String])
	assert_eq(Treatments.step("strong_cleaner"), Kitchen.EFFICIENT)
	assert_eq(Treatments.step("primer"), Kitchen.SPECIALIST_STEP)
	assert_eq(Treatments.parent("sealing_primer"), "primer")
	assert_eq(Treatments.parent("high_gloss"), "finish")
	for k: String in Treatments.ITEMS:
		assert_true(Catalog.ITEMS.has(Treatments.box_id(k)) and Catalog.ITEMS.has(Treatments.tool_id(k)), k)
		assert_eq(Treatments.key_of(Treatments.box_id(k)), k)
		assert_eq(Treatments.key_of(Treatments.tool_id(k)), k)
		assert_true(Kitchen.is_cleaning(Treatments.box_id(k)))
		assert_almost_eq(Catalog.joy_of(Treatments.tool_id(k)), Treatments.joy(k), 0.001, "the catalog's joy is the treatment's")
	assert_eq(Treatments.key_of("box_bun"), "")
	assert_false(Kitchen.is_cleaning("box_bun"))



func test_a_box_climbs_its_tree_like_any_piece():
	assert_eq(Upgrades.key_of("box_cleaner"), "box_cleaner")
	assert_true(Upgrades.has_tree("box_cleaner"))
	assert_eq(Upgrades.parent("box_sealing_primer"), "box_primer")
	assert_eq(Upgrades.step_price("box_primer"), 40)
	assert_eq(Upgrades.step_price("box_sealing_primer"), 50, "the new worth less the old")
	assert_true(Upgrades.can_buy("box_cleaner", "box_finish", 60, 1))
	assert_false(Upgrades.can_buy("box_cleaner", "box_high_gloss", 999, 9), "no skipping steps")
	var lay := Upgrades.layout("box_cleaner")
	assert_eq(lay.size(), 6)
	assert_eq(lay["box_strong_cleaner"], Vector2i(1, 0), "the efficient step runs on along the row")
	assert_true(Upgrades.blurb("box_primer").contains("$3 a night"), "its box's flat fee")
	var shop := Catalog.search("", "Pantry")
	assert_eq(shop.any(func(bp: Dictionary) -> bool: return bp.id == "box_cleaner"), Treatments.ON_SALE,
		"the cleaner's box is sold only while treatments are (parked: liquids are in the mop bucket)")
	for id: String in ["box_primer", "box_finish", "treat_cleaner"]:
		assert_false(shop.any(func(bp: Dictionary) -> bool: return bp.id == id) \
			or Catalog.search("", "Build").any(func(bp: Dictionary) -> bool: return bp.id == id), id + " is not in the catalog's list")



func test_a_nights_laying_costs_its_price_a_cell_while_on_and_boxed():
	var laid := {Vector2i(0, 0): "cleaner", Vector2i(1, 0): "cleaner", Vector2i(2, 0): "cleaner",
		Vector2i(0, 1): "primer", Vector2i(1, 1): "primer"}
	var boxed := {"cleaner": true, "primer": true}
	assert_eq(Treatments.night_cost(laid, {}, boxed), Treatments.fee_of("cleaner") + Treatments.fee_of("primer"),
		"each stocked box's flat fee, however many tiles")
	assert_eq(Treatments.night_cost(laid, {"primer": true}, boxed), Treatments.fee_of("cleaner"), "switched off: not restocked")
	assert_eq(Treatments.night_cost(laid, {}, {"cleaner": true}), Treatments.fee_of("cleaner"), "no box stored: not laid")
	var lines := Treatments.night_lines(laid, {}, {"cleaner": true})
	assert_eq(lines.primer, {"cells": 2, "fee": 0, "on": false})
	assert_eq(lines.cleaner, {"cells": 3, "fee": Treatments.fee_of("cleaner"), "on": true})
	assert_eq(Treatments.night_cost({}, {}, {"finish": true}), Treatments.fee_of("finish"), "a box stocked costs its fee with no tiles laid")
	var many := {}
	for x in 20:
		many[Vector2i(x, 0)] = "cleaner"
	assert_eq(Treatments.night_cost(many, {}, {"cleaner": true}), Treatments.fee_of("cleaner"), "twenty tiles cost the same")
	for k: String in Treatments.ITEMS:
		assert_between(Treatments.fee_of(k), 2, 8, k + ": in line with the food boxes")
	assert_eq(Treatments.active(laid, {"cleaner": true}, boxed).keys().size(), 2, "only the primer's cells tomorrow")



func test_a_primer_stops_some_new_dirt_but_not_dirt_tracked_in():
	var m := _room(5, 5, 3)
	var c := Vector2i(2, 2)
	m.treat[c] = "primer"
	var landed := 0
	for i in 200:
		if m.add_dirt(c) != null:
			landed += 1
		m.dirt.clear()
	assert_between(landed, 90, 150, "about three in five land (40%% stopped): %d" % landed)
	m.treat[c] = "sealing_primer"
	landed = 0
	for i in 200:
		if m.add_dirt(c) != null:
			landed += 1
		m.dirt.clear()
	assert_between(landed, 55, 110, "about two in five land (60%% stopped): %d" % landed)
	m.track_chance = 1.0
	m.add_dirt(Vector2i(1, 2), false)
	for i in 20:
		m.dirt[Vector2i(1, 2)] = 3
		m.dirt.erase(c)
		assert_true(m.track(Vector2i(1, 2), c))
		assert_eq(m.level(c), 1, "tracked dirt always lands")



func test_a_strong_cleaner_keeps_its_dirt_off_feet():
	var m := _room()
	var c := Vector2i(2, 2)
	m.track_chance = 1.0
	m.dirt[c] = 3
	m.treat[c] = "strong_cleaner"
	assert_false(m.track(c, Vector2i(3, 2)))
	assert_eq(m.level(c), 3)
	m.treat[c] = "cleaner"
	assert_true(m.track(c, Vector2i(3, 2)), "a plain cleaner does not stop it")



func test_a_finish_speeds_everyone_and_shows_its_dirt_more():
	var m := _room()
	var c := Vector2i(2, 2)
	m.treat[c] = "finish"
	assert_almost_eq(m.speed_at(c), 1.1, 0.001)
	m.add_dirt(c)
	m.add_dirt(c)
	assert_almost_eq(m.speed_at(c), FloorMess.speed_of(2) * 1.1, 0.001, "it offsets the slowing")
	assert_almost_eq(m.sight_disgust([c]), FloorMess.sight_disgust_of(2) * 1.25, 0.001, "dirt shows more on a shine")
	m.treat[c] = "high_gloss"
	assert_almost_eq(m.speed_at(c), FloorMess.speed_of(2) * 1.2, 0.001)
	assert_gt(Treatments.joy("high_gloss"), Treatments.joy("finish"))



func test_on_a_cleaner_a_mop_clears_the_whole_cell_in_one_press():
	var m := _room()
	var c := Vector2i(2, 2)
	for i in 4:
		m.add_dirt(c)
	m.treat[c] = "cleaner"
	var r := CleanTools.press(m, c, "mop", 0)
	assert_eq(r.did, "clean")
	assert_eq(m.level(c), 0)
	assert_eq(r.used, 1, "one press, one step dirtier")
	for i in 4:
		m.add_dirt(c)
	CleanTools.press(m, c, "spill_kit", 0)
	assert_eq(m.level(c), 2, "a spill kit still takes a covered cell to a puddle")



# ---------- 9.5: the cleaning trees ----------

func test_the_cleaning_and_hood_trees_are_the_prds():
	var want := {"mop_bucket": ["sponge", Kitchen.EFFICIENT, 35],
		"sponge_mop": ["mop_bucket", Kitchen.EFFICIENT, 50], "flat_mop": ["sponge_mop", Kitchen.EFFICIENT, 75],
		"scrubber": ["flat_mop", Kitchen.EFFICIENT, 195], "wringer_bucket": ["mop_bucket", Kitchen.SPECIALIST_STEP, 60],
		"cleaner_bucket": ["mop_bucket", Kitchen.SPECIALIST_STEP, 60], "strong_bucket": ["cleaner_bucket", Kitchen.EFFICIENT, 100],
		"robot_dock": ["wringer_bucket", Kitchen.SPECIALIST_STEP, 315], "scourer": ["sponge", Kitchen.EFFICIENT, 25],
		"grease_scraper": ["sponge", Kitchen.SPECIALIST_STEP, 40], "spill_kit": ["sponge", Kitchen.SPECIALIST_STEP, 30],
		"extractor": ["hood", Kitchen.EFFICIENT, 90]}
	for n: String in want:
		assert_eq(Kitchen.parent_of(n), want[n][0], n)
		assert_eq(Kitchen.step_of(n), want[n][1], n)
		assert_eq(Kitchen.price_of(n), want[n][2], n)
	assert_eq(Kitchen.price_of("mop_bucket"), Catalog.price_of("mop_bucket"))
	assert_eq(Kitchen.price_of("sponge"), Catalog.price_of("sponge"))
	for n: String in Kitchen.NODES:
		var t := Kitchen.tool_of(n)
		if t != "":
			assert_true(CleanTools.TOOLS.has(t), "%s keeps a real tool" % n)
			assert_eq(CleanTools.TOOLS[t].home, "bucket" if Kitchen.fit_of(n) == "floor" else "store", n)
	assert_eq(Kitchen.tool_of("robot_dock"), "", "the dock keeps the robot, not a hand tool")
	assert_true(Upgrades.has_tree("mop_bucket") and Upgrades.has_tree("sponge") and Upgrades.has_tree("hood"))
	assert_eq(Catalog.search("robot").size(), 0, "the robot is bought up the wringer bucket's tree")



func test_each_mop_up_the_tree_lasts_longer_or_does_more():
	assert_eq(CleanTools.dirty_after("sponge_mop"), 6)
	assert_eq(CleanTools.dirty_after("flat_mop"), 8)
	var m := _room()
	var c := Vector2i(2, 2)
	for i in 4:
		m.add_dirt(c)
	CleanTools.press(m, c, "flat_mop", 0)
	assert_eq(m.level(c), 0, "a flat mop clears a whole cell a press")
	for t: String in ["wringer_mop", "scrubber", "grease_scraper", "spill_kit"]:
		assert_true(CleanTools.never_dirty(t), t)
		assert_false(CleanTools.is_dirty(t, 99), t)
	assert_true(CleanTools.pushes("scrubber"))
	assert_lt(CleanTools.walk_speed("scrubber"), 1.0, "slow to walk")
	assert_eq(CleanTools.walk_speed("mop"), 1.0)
	assert_true(CleanTools.is_mop("scrubber") and not CleanTools.is_mop("spill_kit"))
	assert_eq(CleanTools.comes_with("sponge_mop"), "sponge_mop")
	assert_eq(CleanTools.comes_with("mop_bucket"), "mop")



func test_the_grease_scraper_clears_kitchen_grease_only():
	var m := _room()
	var g := Vector2i(1, 1)
	var guest := Vector2i(3, 3)
	m.rng.seed = 1
	while m.level(g) < 3:
		m.drop_grease("fry", "bad", [g])
	assert_true(m.is_grease(g), "prep grease is marked")
	m.add_dirt(guest)
	assert_false(m.is_grease(guest), "a guest's mess is not")
	var r := CleanTools.press(m, guest, "grease_scraper", 0)
	assert_eq(r.did, "refused")
	assert_true(r.why.contains("grease"))
	assert_eq(m.level(guest), 1)
	r = CleanTools.press(m, g, "grease_scraper", 0)
	assert_eq(r.did, "clean")
	assert_eq(m.level(g), 0, "a whole cell a press")
	assert_false(m.is_grease(g), "a clean cell holds no grease")
	m.track_chance = 1.0
	m.dirt[g] = 3
	m.add_dirt(g, true, true)
	m.dirt[g] = 3
	m.track(g, guest)
	assert_true(m.is_grease(guest), "grease tracked across stays grease")



func test_a_spill_kit_is_for_a_covered_cell_three_times_a_day():
	var m := _room()
	var c := Vector2i(2, 2)
	for i in 3:
		m.add_dirt(c)
	var r := CleanTools.press(m, c, "spill_kit", 0)
	assert_eq(r.did, "refused", "not for a level 3 puddle")
	var used := 0
	for k in 3:
		m.add_dirt(c)
		m.add_dirt(c)   # back up to 4
		r = CleanTools.press(m, c, "spill_kit", used)
		assert_eq(r.did, "clean")
		assert_eq(m.level(c), 2)
		used = r.used
	assert_true(CleanTools.used_up("spill_kit", used))
	m.add_dirt(c)
	m.add_dirt(c)
	assert_eq(CleanTools.press(m, c, "spill_kit", used).did, "refused", "used up for today")
	assert_lt(CleanTools.help_factor("spill_kit"), 1.0, "helps a fallen guest up faster")



func test_an_extractor_cuts_grease_more_than_a_hood_and_its_smell():
	assert_almost_eq(FloorMess.hood_factor("extractor"), 0.15, 0.001)
	assert_almost_eq(FloorMess.hood_factor("hood"), FloorMess.hood_factor(true), 0.001)
	assert_almost_eq(FloorMess.hood_factor(""), 1.0, 0.001)
	assert_lt(FloorMess.grease_chance("fry", "plain", 1.0, "extractor"), FloorMess.grease_chance("fry", "plain", 1.0, "hood"))
	var m := _room(9, 9)
	var g := Vector2i(4, 4)
	for i in 3:
		m.add_dirt(g, true, true)
	var far := g + Vector2i(FloorMess.SMELL_RADIUS, 0)
	assert_gt(m.smell_disgust(far), 0.0)
	m.extractor = true
	assert_eq(m.smell_disgust(far), 0.0, "kitchen grease smells a cell less far")
	assert_gt(m.smell_disgust(g + Vector2i(1, 0)), 0.0)



# ---------- 9.5: chemicals never with food ----------

func test_chemicals_and_food_never_share_a_cell_and_chemicals_stay_out_of_fridges():
	var k := Kitchen.new()
	k.set_cell(Vector2i(0, 0), "counter")
	k.set_cell(Vector2i(1, 0), "counter")
	k.set_cell(Vector2i(2, 0), "fridge")
	assert_true(k.store(Vector2i(0, 0), "box_bun"))
	assert_false(k.can_store(Vector2i(0, 0), "box_cleaner"))
	assert_true(k.store(Vector2i(1, 0), "box_cleaner"))
	assert_false(k.can_store(Vector2i(2, 0), "box_cleaner"), "never in a fridge")
	assert_eq(k.store_refusal(Vector2i(2, 0), "box_cleaner"), "No chemicals in a fridge")
	assert_true(k.holds_cleaning(Vector2i(1, 0)))
	assert_false(k.holds_food(Vector2i(1, 0)))
	k.unstore(Vector2i(0, 0), "box_bun")
	k.set_cell(Vector2i(0, 0), "double_counter")
	assert_true(k.store(Vector2i(0, 0), "box_bun"))
	assert_eq(k.store_refusal(Vector2i(0, 0), "box_primer"), "No chemicals with food", "not even in the other slot")
	k.set_cell(Vector2i(1, 0), "double_counter")
	assert_eq(k.store_refusal(Vector2i(1, 0), "box_bun"), "No food with chemicals")
	assert_true(k.store(Vector2i(1, 0), "box_primer"), "two chemicals share happily")
	assert_eq(k.store_refusal(Vector2i(1, 0), "box_primer"), "One of each a cell")



func test_a_treatment_box_is_stored_away_from_food_and_stocks_no_food():
	var game = _game()
	_night(game)
	var food: Vector2i = game.menu_stock.storage_of(game.world.fixed_main().bread).cell
	assert_true(game.placing.pick_catalog("box_cleaner"))
	assert_false(game.placing.can_place(Vector3i(food.x, food.y, 0)), "not in with the bread")
	game.player.demo_hover = Grid.center(food)
	assert_eq(game.room_edit.build_action(), "No chemicals with food")
	var c := _shelf_for(game)
	var before: int = game.menu_stock.kitchen_stock().size()
	assert_true(game.placing.place(Vector3i(c.x, c.y, 0)))
	assert_true(game.kitchen.stock(c).has("box_cleaner"))
	assert_eq(game.menu_stock.kitchen_stock().size(), before, "chemicals stock no food")
	assert_eq(game.menu_stock.treat_boxed(), {"cleaner": true})
	game.player.demo_hover = Vector3.INF
	_stand(game, c + Vector2i(0, 1), Vector2i(0, -1))
	assert_eq(game.cooking.use_station(game.stations[c], true), "", "nothing to take out of a box of chemicals")



func test_laid_at_night_a_treatment_is_paid_at_the_door_each_night_while_on():
	var game = _game()
	_night(game)
	var base: int = game.menu_stock.night_cost()
	assert_false(game.session.shop_items("", "Build").any(func(bp: Dictionary) -> bool: return bp.id == "treat_cleaner"),
		"no box stored: nothing to lay")
	game.kitchen.store(_shelf_for(game), "box_cleaner")
	assert_true(game.session.shop_items("", "Build").any(func(bp: Dictionary) -> bool: return bp.id == "treat_cleaner"))
	assert_true(game.placing.pick_catalog("treat_cleaner"))
	var money: int = game.ledger.money
	assert_eq(game.room_edit.finish_drag(Grid.center(Vector2i(4, 2)), Grid.center(Vector2i(5, 3)), false), 4)
	assert_eq(game.ledger.money, money, "laying is free")
	assert_eq(game.treat_laid.size(), 4)
	var fee := Treatments.fee_of("cleaner")
	assert_eq(game.menu_stock.night_cost(), base + fee, "the stocked box's flat fee: the tiles add nothing")
	assert_true(game.menu_stock.stock_lines().any(func(l: Dictionary) -> bool: return l.name == "Floor cleaner box, 4 tiles" and l.fee == fee))
	assert_eq(game.floor_dirt.sheen_cells().size(), 4, "a sheen where it is laid")
	game.placing.rotate_hand()
	assert_true(game.treat_off.has("cleaner"), "turning the tool switches it off")
	assert_eq(game.menu_stock.night_cost(), base, "switched off: the box is not restocked")
	assert_true(game.menu_stock.stock_lines().any(func(l: Dictionary) -> bool: return l.name == "Floor cleaner box, 4 tiles, off" and l.fee == 0))
	game.placing.rotate_hand()
	assert_eq(game.menu_stock.night_cost(), base + fee)
	assert_eq(game.room_edit.finish_drag(Grid.center(Vector2i(5, 3)), Grid.center(Vector2i(5, 3)), true), 1, "a right-drag lifts it")
	assert_eq(game.menu_stock.night_cost(), base + fee, "fewer tiles, the same fee")
	game.placing.cancel_hand()
	money = game.ledger.money
	game.day.start_day()
	assert_eq(game.ledger.money, money - base - fee)
	assert_eq(game.floor_dirt.mess.treat.size(), 3, "laid for the day")
	game.floor_dirt.mess.add_dirt(Vector2i(4, 2))
	game.floor_dirt.mess.add_dirt(Vector2i(4, 2))
	assert_true(game.floor_dirt.mess.one_press(Vector2i(4, 2)))
	game.day._end_day()
	assert_eq(game.floor_dirt.mess.treat.size(), 0, "it lasts one day of service")
	assert_eq(game.treat_laid.size(), 3, "and is re-laid tomorrow")



func test_without_its_box_a_treatment_is_not_relaid():
	var game = _game()
	_night(game)
	var base: int = game.menu_stock.night_cost()
	var c := _shelf_for(game)
	game.kitchen.store(c, "box_finish")
	game.treat_laid = {Vector2i(4, 2): "finish", Vector2i(4, 3): "finish"}
	assert_eq(game.menu_stock.night_cost(), base + Treatments.fee_of("finish"), "the finish box's flat fee")
	game.kitchen.unstore(c, "box_finish")
	assert_eq(game.menu_stock.night_cost(), base)
	assert_true(game.menu_stock.stock_lines().any(func(l: Dictionary) -> bool: return l.name.ends_with("no box")))
	game.day.start_day()
	assert_true(game.floor_dirt.mess.treat.is_empty())



func test_a_finish_in_force_cheers_guests_like_a_fine_floor():
	var game = _game()
	var seat := Vector2i(4, 2)
	var before: float = game.decor.decor_bonus(seat).joy
	game.floor_dirt.mess.treat = {seat: "high_gloss"}
	assert_gt(game.decor.decor_bonus(seat).joy, before)
	assert_eq(game.decor.decor_bonus(seat).best, "treat_high_gloss")



func test_a_box_picked_up_climbs_its_tree_and_the_laid_cells_follow():
	var game = _game()
	_night(game)
	var c := _shelf_for(game)
	game.kitchen.store(c, "box_cleaner")
	game.treat_laid = {Vector2i(4, 2): "cleaner"}
	assert_true(game.placing.pick_up(Grid.center(c)))
	assert_eq(game.player.hand.id, "box_cleaner")
	assert_eq(game.upgrades.hand_key(), "box_cleaner")
	assert_true(game.upgrades.strip_choices().any(func(c: Dictionary) -> bool: return c.get("key", "") == "box_primer"),
		"the strip along the bottom offers the box's next steps")
	var money: int = game.ledger.money
	assert_true(game.upgrades.buy_upgrade("box_primer"))
	assert_eq(game.ledger.money, money - 40)
	assert_eq(game.player.hand.id, "box_primer")
	assert_eq(game.treat_laid[Vector2i(4, 2)], "primer")
	game.session.close_shop()
	assert_true(game.placing.place(Vector3i(c.x, c.y, 0)))
	assert_true(game.kitchen.stock(c).has("box_primer"))



func test_a_mop_bucket_climbs_to_a_flat_mop_and_its_mop_comes_too():
	var game = _game()
	_night(game)
	var c := Vector2i(7, 2)
	var b := _bucket(game, c)
	assert_true(game.placing.pick_up(Grid.center(c)))
	game.session.open_shop()
	assert_true(game.upgrades.buy_upgrade("sponge_mop"))
	assert_true(game.upgrades.buy_upgrade("flat_mop"))
	var up: Station = game.player.hand.node
	assert_eq(up.node, "flat_mop")
	assert_eq(up.type, "mop_bucket", "still a bucket in the room")
	assert_eq(up.kit_tool, "flat_mop")
	assert_false(is_instance_valid(b) and not b.is_queued_for_deletion())
	game.session.close_shop()
	assert_true(game.placing.place(Vector3i(c.x, c.y, 0)))
	assert_eq((game.stations[c] as Station).kit_tool, "flat_mop")



func test_with_its_mop_out_the_bucket_upgrade_swaps_the_mop_in_hand():
	var game = _game()
	_night(game)
	var c := Vector2i(7, 2)
	var b := _bucket(game, c)
	game.clean_kit.keep(b, "", 0)
	var holder: Player = game.add_chef(Vector2i(4, 4))   # chef 2 has the mop out
	CleanKit.hold(holder, "mop", 3)
	assert_true(game.placing.pick_up(Grid.center(c)))
	game.session.open_shop()
	assert_true(game.upgrades.buy_upgrade("wringer_bucket"))
	assert_eq(CleanKit.held_tool(holder), "wringer_mop")



func test_the_wringer_bucket_grows_into_the_robot_sweepers_dock():
	var game = _game()
	_night(game)
	var c := Vector2i(7, 2)
	_bucket(game, c)
	assert_true(game.placing.pick_up(Grid.center(c)))
	game.session.open_shop()
	assert_true(game.upgrades.buy_upgrade("wringer_bucket"))
	assert_eq((game.player.hand.node as Station).kit_tool, "wringer_mop")
	assert_true(game.upgrades.buy_upgrade("robot_dock"))
	var dock: Station = game.player.hand.node
	assert_eq(dock.type, "robot_dock")
	assert_eq(dock.kit_tool, "")
	game.session.close_shop()
	assert_true(game.placing.place(Vector3i(c.x, c.y, 0)))
	game.step(0.01)
	assert_true(game.clean_kit.robots.has(game.stations[c]), "its robot is out")



func _open_tree_of_shelf(game, w: Vector2i) -> void:
	game.player.set_meta("reach", true)
	assert_true(game.card.open_storage(w))
	game.card.storage_upgrades()
	game.player.set_meta("reach", false)


func test_a_shelfs_tree_is_its_tools():
	var game = _game()
	_night(game)
	var w := _wall_cell(game)
	var h: Station = game.clean_kit.shelve(w, "sponge")
	_open_tree_of_shelf(game, w)
	assert_eq(game.upgrades.hand_key(), "sponge")
	assert_has(Upgrades.children(game.upgrades.hand_key()), "spill_kit")
	assert_true(game.upgrades.buy_upgrade("spill_kit"))
	assert_eq(h.kit_tool, "spill_kit")
	assert_eq(game.kitchen.tool_at(w), "spill_kit")
	assert_eq(game.upgrades.hand_key(), "spill_kit")
	assert_eq(game.highs[w], h, "the shelf stays")


func test_an_empty_shelf_offers_its_own_steps():
	var game = _game()
	_night(game)
	var w := _wall_cell(game)
	game.world.add_high("shelf", w)
	game.player.set_meta("reach", true)
	assert_true(game.card.open_storage(w))
	assert_eq(game.card.storage_tree(), "shelf")



func test_a_hood_upgraded_to_an_extractor_cuts_more_grease():
	var game = _game()
	_night(game)
	game.menu_stock.clear_walls()
	var w := _wall_cell(game)
	game.world.add_high("hood", w)
	assert_true(game.placing.pick_up(Grid.center(w)))
	game.session.open_shop()
	assert_true(game.upgrades.buy_upgrade("extractor"))
	game.session.close_shop()
	assert_true(game.placing.place(Vector3i(w.x, w.y, 0)))
	assert_eq(game.kitchen.hood_at(w), "extractor")
	assert_eq((game.highs[w] as Station).type, "hood", "it draws as a hood")
	game.day.start_day()
	assert_true(game.floor_dirt.mess.extractor)



func test_a_floor_scrubber_cleans_each_cell_it_is_pushed_over_slowly():
	var game = _game()
	var c := Vector2i(7, 2)
	_stand(game, c)
	_dirty(game, c, 3)
	var speed: float = game.player.speed()
	CleanKit.hold(game.player, "scrubber", 0)
	assert_lt(game.player.speed(), speed, "slow to push")
	game.clean_kit.tick(0.01)
	assert_eq(game.floor_dirt.mess.level(c), 0, "the cell it stands on, cleared")
	assert_eq(CleanKit.held_used(game.player), 0, "never dirty")



func test_the_scraper_on_guest_mess_says_why_and_a_spill_kit_refills_each_day():
	var game = _game()
	var front := _stand(game, Vector2i(7, 2))
	_dirty(game, front, 4)
	CleanKit.hold(game.player, "grease_scraper", 0)
	assert_eq(game.floor_dirt.mess.is_grease(front), false)
	assert_eq(game.clean_kit.press(game.player), "refused")
	assert_eq(game.floor_dirt.mess.level(front), 4)
	CleanKit.hold(game.player, "spill_kit", 3)
	assert_true(CleanTools.used_up("spill_kit", CleanKit.held_used(game.player)))
	game.clean_kit.start_day()
	assert_eq(CleanKit.held_used(game.player), 0, "three uses again")
	game.clean_kit.tick(1.0)
	assert_eq(game.clean_kit.press(game.player), "clean")
	assert_eq(game.floor_dirt.mess.level(front), 2)



func test_the_sponge_grows_into_a_mop_bucket_and_then_a_cleaner_in_its_pail():
	var game = _game()
	_night(game)
	game.ledger.money = 500
	var w := _wall_cell(game)
	var h: Station = game.clean_kit.shelve(w, "sponge")
	_open_tree_of_shelf(game, w)
	assert_has(Upgrades.children(game.upgrades.hand_key()), "mop_bucket", "the sponge's tree offers the mop bucket")
	assert_true(game.upgrades.buy_upgrade("mop_bucket"))
	game.session.close_shop()
	assert_eq(game.player.hand.id, "mop_bucket", "off the shelf: a bucket in hand")
	assert_eq(h.kit_tool, "", "the sponge left the shelf")
	assert_eq(game.highs[w], h, "and the shelf stays where it is")
	var spot := Vector2i(7, 2)
	assert_true(game.placing.place(Vector3i(spot.x, spot.y, 0)))
	assert_eq(game.ledger.money, 500 - Upgrades.step_price("mop_bucket"))
	assert_eq((game.stations[spot] as Station).kit_tool, "mop", "with its mop")
	game.placing.cancel_hand()
	assert_true(game.placing.pick_up(Grid.center(spot)))
	var keys: Array = game.upgrades.strip_choices().map(func(c: Dictionary) -> String: return str(c.get("key", "")))
	assert_has(keys, "sponge_mop", "better mops")
	assert_has(keys, "cleaner_bucket", "or a liquid in the pail")
	assert_true(game.upgrades.buy_upgrade("cleaner_bucket"))
	assert_eq((game.player.hand.node as Station).kit_tool, "cleaner_mop")
	assert_eq(int(CleanTools.TOOLS.cleaner_mop.levels), FloorMess.MAX_LEVEL, "a whole cell a press")
	assert_true(game.placing.place(Vector3i(spot.x, spot.y, 0)))
	assert_eq((game.stations[spot] as Station).kit_tool, "cleaner_mop")
