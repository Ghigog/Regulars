extends "res://test/helpers/game_case.gd"


func test_the_receipt_on_day_5_carries_a_clipping_and_day_4_does_not():
	assert_false(_start_day_with_only_the_critic(4), "no critic on day 4")
	_run_to_summary()
	assert_false(game.last_day.has("review"))
	assert_true(_start_day_with_only_the_critic(5), "the critic comes on day 5")
	_run(1.0)
	var c: Guest = game.critic_guest
	assert_not_null(c)
	assert_eq(c.idx, game.critic.critic_idx)
	assert_eq(c.party.size(), 1, "they come alone")
	game.paying.walk_out(c)
	_run_to_summary()
	assert_true(game.last_day.has("review"), "the review comes with the receipt")
	assert_lte(int(game.last_day.review.stars), Critic.WALKOUT_CAP, "a walkout caps the stars")
	assert_eq(int(game.last_day.review.ratings.speed), 1)
	assert_true(game.critic.known)



func test_the_critic_is_unmarked_until_the_first_review():
	game.ledger.day = 4
	var g: Guest = game.seating.spawn_guest(game.critic.critic_idx)
	game.day.inspect(g)
	assert_false(_card_says("Critic"), "nothing marks them before the reveal")
	game.day.inspect(null)
	game.critic.publish({"speed": 4, "clean": 4, "quality": 4, "variety": 4}, false, game.town, 5)
	game.ledger.day = 6
	game.day.inspect(g)
	assert_true(_card_says("Critic"), "marked after the reveal")
	game.hud.screens_ui.show_town()
	game.hud.receipt_ui.show_review()   # the last clipping can be read again from the town book



func test_closing_early_before_the_critic_comes_puts_them_off_a_day():
	game.ledger.day = 5
	game.day.start_day()
	game.day.close_early()   # before any step: the critic is still in the arrivals
	assert_false(game.critic.visits_on(5))
	assert_true(game.critic.visits_on(6), "they come tomorrow instead")



func test_the_critic_orders_even_when_nothing_suits_them():
	var p: Dictionary = game.town.people[game.critic.critic_idx]
	p.dislikes = ["patty"]
	_start_day_with_only_the_critic(5)
	_run(1.0)
	var c: Guest = game.critic_guest
	assert_not_null(c)
	assert_false(c.planned.main.is_empty(), "never turned away by the menu")
	assert_ne(c.state, "browse")



func test_a_storage_card_shows_boxes_first_and_dims_what_needs_a_fridge():
	_to_build()
	var c := _plain_counter()
	assert_ne(c, game.NO_CELL, "the start has a bare counter")
	assert_true(game.card.open_storage(c))
	assert_true(game.card.storing())
	assert_eq(game.hud._category, "Ingredients", "ingredients come first")
	assert_eq(game.hud.shop_tabs(), ["Ingredients", "Upgrades"])
	var acts: int = game.card.card_actions().size()
	assert_gt(acts, 0, "the card's Upgrades, Move, Turn and Sell come before the boxes")
	var items: Array[Dictionary] = game.session.shop_items("", "Ingredients").slice(acts)
	var patty := items.filter(func(bp: Dictionary) -> bool: return bp.id == "box_patty")
	assert_eq(patty.size(), 1, "a fridge-only kind is still listed, so the player learns of fridges")
	assert_eq(game.hud.shop_ui._storage_info(patty[0]).price, "Fridge $%d" % Upgrades.step_price("fridge"),
		"a fridge-only kind offers to make the counter a fridge in one press")
	assert_string_contains(game.hud.shop_ui._storage_info(patty[0]).blurb, "Needs a fridge")
	assert_true(game.kitchen.store_refusal(c, items[0].id) == "", "what fits comes first")
	assert_true(game.placing.buy({"id": "box_bun", "tier": 1}))
	assert_true(game.kitchen.stock(c).has("box_bun"), "put straight in, the card still open")
	assert_true(game.card.storing())
	acts = game.card.card_actions().size()   # a stored food box adds its tree to the actions
	assert_true(game.session.shop_items("", "Ingredients")[acts].get("stored", false), "what is stored is listed first")
	assert_true(game.placing.buy({"id": "box_bun", "tier": 1, "stored": true}))
	assert_false(game.kitchen.stock(c).has("box_bun"), "and taken out again")
	game.session.close_shop()
	assert_false(game.card.storing())



func test_the_upgrades_tab_upgrades_a_counter_where_it_stands():
	_to_build()
	game.ledger.money = 200
	var c := _plain_counter()
	game.card.open_storage(c)
	game.card.storage_upgrades()
	assert_true(game.upgrading)
	assert_true(game.upgrades.buy_upgrade("fridge"))
	assert_eq(game.stations[c].base, "fridge", "the counter is a fridge, still standing there")
	assert_eq(game.kitchen.get_piece(c, "base"), "fridge")
	assert_eq(game.ledger.money, 200 - Upgrades.step_price("fridge"))
	game.card.storage_ingredients()
	assert_false(game.upgrading)
	assert_true(game.card.storing(), "back on the card's ingredients")
	assert_true(game.placing.buy({"id": "box_patty", "tier": 1}), "a fridge takes patties")
	game.session.close_shop()
	assert_true(game.player.hand.is_empty(), "nothing was lifted")
	assert_eq(game.stations[c].cell, c)



func test_e_lifts_a_counter_and_its_strip_makes_it_a_fridge():
	_to_build()
	game.ledger.money = 200
	var c := _pass_counter_faced()
	assert_ne(c, game.NO_CELL, "the start has a bare length of pass")
	assert_eq(game.room_edit.build_action(), "Pick up")
	game.coop.act(0, "use")
	var st: Station = game.player.hand.get("node")
	assert_not_null(st, "E lifts the counter, no card")
	var keys: Array = game.upgrades.strip_choices().map(func(ch: Dictionary) -> String: return str(ch.get("key", "")))
	assert_has(keys, "fridge", "the strip along the bottom offers its upgrades")
	while str(game.upgrades.strip_chosen().get("key", "")) != "fridge":
		game.coop.act(0, "next")   # X
	assert_true(game.upgrades.strip_open(0))
	game.coop.act(0, "buy")   # Space
	assert_eq(game.ledger.money, 200 - Upgrades.step_price("fridge"))
	assert_eq(st.base, "fridge", "still in hand, a fridge now")
	game.coop.act(0, "turn")
	game.coop.act(0, "use")   # E: put down where it was
	assert_true(game.player.hand.is_empty())
	assert_eq(game.stations[c], st)
	assert_not_null(st._vis.get_node_or_null("door"), "drawn a fridge")



func test_a_fridge_on_the_pass_shows_its_door_in_front_of_the_pass():
	var plain := Node3D.new()
	var on_pass := Node3D.new()
	BuildStations.station(plain, "counter", 1, "fridge")
	BuildStations.station(on_pass, "counter", 1, "fridge", true)
	var front := func(n: Node3D) -> float: return (n.get_node("door") as Node3D).position.z
	assert_gt(front.call(on_pass), 0.54, "past the pass's front, so it is not hidden inside it")
	assert_lt(front.call(plain), 0.5, "a plain counter's door is where it was")
	plain.free()
	on_pass.free()



func test_the_shop_sells_roots_only():
	_to_build()
	var items: Array[Dictionary] = game.session.shop_items("", "Furniture") + game.session.shop_items("", "Tools")
	var ids: Array = items.map(func(bp: Dictionary) -> String: return str(bp.get("base", bp.id)))
	assert_does_not_have(ids, "fridge", "a fridge is a counter upgraded, lifted")
	assert_does_not_have(ids, "stove")
	assert_has(ids, "counter")
	assert_eq(items.filter(func(bp: Dictionary) -> bool: return bp.has("tree")).size(), 0, "no tree steps")



func test_a_counter_on_its_card_grows_a_stove_where_it_stands():
	_to_build()
	game.ledger.money = 200
	var c := _plain_counter()
	game.card.open_storage(c)
	game.card.storage_upgrades()
	assert_true(game.upgrades.buy_upgrade("stove"))
	assert_false(game.shopping, "the card shuts")
	assert_eq(game.stations[c].type, "stove", "a stove stands on the counter")
	assert_eq(game.stations[c].base, "counter", "the counter is still under it")
	assert_eq(game.kitchen.get_piece(c, "top"), "stove")
	assert_eq(game.ledger.money, 200 - Kitchen.price_of("stove"), "the tool's whole price")
	assert_true(game.player.hand.is_empty())



func test_a_stove_opens_like_a_counter_and_upgrades_where_it_stands():
	_to_build()
	game.ledger.money = 300
	var c := _plain_counter()
	game.card.open_storage(c)
	game.card.storage_upgrades()
	assert_true(game.upgrades.buy_upgrade("stove"))
	game.kitchen.store(c, "box_bun")
	assert_true(game.card.open_storage(c), "a stove keeps its counter's storage card")
	assert_eq(game.card.storage_tree(), "stove", "with the stove's tree on it")
	game.card.storage_upgrades()
	assert_true(game.upgrades.buy_upgrade("fryer"))
	var st: Station = game.stations[c]
	assert_eq(st.type, "fryer", "made a fryer where it stands")
	assert_eq(st.base, "counter")
	assert_true(game.kitchen.stock(c).has("box_bun"), "its boxes stay")
	assert_eq(game.ledger.money, 300 - Kitchen.price_of("fryer"))
	game.session.close_shop()
	assert_true(game.player.hand.is_empty())
	assert_eq(game.stations[c], st)



func test_a_lifted_counter_grows_a_stove_in_hand_and_is_put_down_as_one():
	_to_build()
	game.ledger.money = 400
	var c := Vector2i(3, 4)
	game.world.add_station("counter", c)
	assert_true(game.placing.pick_up(Grid.center(c), game.player, true))
	assert_true(game.upgrades.buy_upgrade("stove"))
	assert_eq(game.player.hand.id, "stove", "a stove in hand, on its counter")
	assert_eq(game.ledger.money, 400 - Upgrades.step_price("stove"))
	assert_true(game.placing.place(Vector3i(c.x, c.y, 0)))
	var st: Station = game.stations[c]
	assert_eq(st.type, "stove")
	assert_eq(st.base, "counter")
	assert_eq(game.kitchen.get_piece(c, "top"), "stove")



func test_the_shop_and_the_strip_leave_out_what_is_above_the_level():
	_to_build()
	assert_eq(game.ledger.level(), 1)
	var locked: Array = game.session.shop_items("", "").filter(func(bp: Dictionary) -> bool:
		return Catalog.ITEMS.has(bp.id) and Catalog.bp_level(bp) > 1 and not game.placing.missing(bp.id))
	assert_eq(locked, [], "nothing out of reach is listed")
	var c := Vector2i(3, 4)
	game.world.add_station("counter", c)
	assert_true(game.placing.pick_up(Grid.center(c), game.player, true))
	for ch: Dictionary in game.upgrades.strip_choices():
		if ch.kind == "up":
			assert_lte(Upgrades.level(ch.key), 1, ch.key)



func test_crates_stand_on_open_counters_and_closed_ones_keep_a_tag():
	_to_build()
	var c := _plain_counter()
	game.placing._store_box(c, "box_bun")
	var st: Station = game.stations[c]
	assert_true(st.shows_crates())
	assert_not_null(st.get_node_or_null("crates"), "the crate stands on the counter")
	assert_null(st.get_node_or_null("box_tags"))
	st.set_base("fridge")
	game.kitchen.set_cell(c, "fridge")
	game.world._show_boxes(c)
	assert_false(st.shows_crates())
	assert_not_null(st.get_node_or_null("box_tags"), "a fridge keeps its stock inside, a tag over it")
	assert_not_null(st._vis.get_node_or_null("door"), "with a door that swings open when used")



func test_a_day_ending_on_a_new_level_says_what_is_new_in_the_shop():
	var l := Ledger.new()
	assert_eq(int(l.end_day().get("level", 0)), 1)
	l.xp = Ledger.XP_PER_LEVEL
	var rec := l.end_day()
	assert_eq(int(rec.level), 2)
	assert_eq(int(rec.level_was), 1)
	var fresh := Catalog.unlocked_at(2, "diner").map(func(bp: Dictionary) -> String: return str(bp.id))
	assert_true(fresh.has("bin"), "the bin opens at level 2")
	assert_false(fresh.has("table"), "tables and chairs are there from level 1")
	assert_false(fresh.has("sink"), "the sink waits for level 3")



func test_a_piece_sold_the_night_it_was_bought_comes_back_at_full_price():
	_to_build()
	game.ledger.money = 200
	assert_true(game.placing.pick_catalog("counter"))
	assert_true(game.placing.place(Vector3i(3, 4, 0)))
	game.placing.cancel_hand()
	assert_eq(game.ledger.money, 185)
	assert_true(game.placing.pick_up(Grid.center(Vector2i(3, 4))))
	assert_eq(game.placing.sell_value(), 15, "a same-night return")
	assert_true(game.placing.sell_hand())
	assert_eq(game.ledger.money, 200)



func test_an_older_piece_sells_for_half_and_tonights_upgrade_comes_back_whole():
	_to_build()
	game.ledger.money = 200
	assert_true(game.placing.pick_catalog("counter"))
	assert_true(game.placing.place(Vector3i(3, 4, 0)))
	game.placing.cancel_hand()
	game.ledger.day += 1   # a night later: last night's counter is second-hand now
	var c := Vector2i(3, 4)
	game.card.open_storage(c)
	game.card.storage_upgrades()
	assert_true(game.upgrades.buy_upgrade("fridge"))
	game.session.close_shop()
	assert_true(game.placing.pick_up(Grid.center(c)))
	assert_eq(game.placing.sell_value(), Kitchen.price_of("counter") / 2 + Upgrades.step_price("fridge"),
		"half for the counter, all of tonight's fridge step")
