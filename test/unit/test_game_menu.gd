extends "res://test/helpers/game_case.gd"


func test_door_card_will_not_flip_with_no_makeable_main():
	_to_build()
	game.menu.items.clear()
	_at_door()
	assert_false(game.day.use_door())
	assert_eq(game.phase, game.Phase.BUILD)
	assert_string_contains(game.hud.toast.text, "No main")
	game.menu.add("side", ["bun"], "Bread")
	assert_false(game.day.use_door(), "a side alone is not enough")
	game.menu_stock.write_test_menu()
	game.kitchen.unstore(Vector2i(0, 2), "box_patty")
	game.menu_stock.menu_changed()
	assert_false(game.day.use_door(), "the Burger is off: no patty stocked")
	game.menu_stock.stock_box("patty", Vector2i(0, 2))
	assert_true(game.day.use_door())
	assert_eq(game.phase, game.Phase.SERVICE)



func test_door_card_will_not_flip_when_the_stock_cannot_be_paid():
	_to_build()
	game.ledger.money = game.menu_stock.night_cost() - 1
	_at_door()
	assert_false(game.day.use_door())
	assert_eq(game.phase, game.Phase.BUILD)
	assert_string_contains(game.hud.toast.text, "stock costs $%d" % game.menu_stock.night_cost())
	assert_string_contains(game.hud.menu_notes._box.get_child(game.hud.menu_notes._box.get_child_count() - 1).text, "can't pay")
	game.ledger.money = game.menu_stock.night_cost()
	assert_true(game.day.use_door())
	assert_eq(game.ledger.money, 0, "the stock took it all")



func test_opening_charges_the_night_cost_as_a_stock_line():
	assert_eq(game.menu_stock.night_cost(), Pantry.fee_of("patty") + Pantry.fee_of("bun"))
	game.menu_stock.stock_box("cheese", Vector2i(1, 6), true)
	assert_eq(game.menu_stock.night_cost(), Pantry.fee_of("patty") + Pantry.fee_of("bun") + roundi(Pantry.fee_of("cheese") * 1.5),
		"ready-made at half as much again")
	_to_build()
	var before: int = game.ledger.money
	var cost: int = game.menu_stock.night_cost()
	_at_door()
	assert_true(game.day.use_door())
	assert_eq(game.ledger.money, before - cost)
	assert_eq(game.ledger.today.stock, cost)
	game.arrivals.clear()
	_run(0.2)
	assert_eq(game.last_day.stock, cost, "the receipt has a Stock line")



func test_picking_up_a_box_at_night_takes_it_off_the_menu_and_selling_it_stops_the_fee():
	_to_build()
	var fridge: Station = game.menu_stock.storage_of("patty")
	var full: int = game.menu_stock.night_cost()
	assert_true(game.placing.pick_up(Vector3(0.5, 0, 2.5)), "the box comes out before the fridge it is in")
	assert_eq(game.player.hand.id, "box_patty")
	assert_eq(game.stations[Vector2i(0, 2)], fridge, "the fridge stays")
	assert_true(fridge.boxes.is_empty(), "its tag goes")
	assert_eq(game.menu_stock.night_cost(), full - Pantry.fee_of("patty"), "out of its slot, it costs nothing")
	assert_true(game.menu_stock.tonight_menu().is_empty(), "the Burger is not offered")
	assert_eq(game.menu_stock.item_off_reason(game.menu.items[0]), "Patty: needs a box")
	assert_true(game.menu_board.names.is_empty(), "the board by the door follows")
	game.placing.cancel_hand()
	assert_eq(fridge.boxes, ["box_patty"], "put back where it came from")
	assert_eq(game.menu_board.names, ["Burger"])
	assert_true(game.placing.pick_up(Vector3(0.5, 0, 2.5)))
	var money: int = game.ledger.money
	assert_eq(game.placing.sell_block(), "")
	assert_true(game.placing.sell_hand())
	assert_eq(game.ledger.money, money, "a box is free, so selling it pays nothing back")
	assert_eq(game.menu_stock.night_cost(), full - Pantry.fee_of("patty"), "and its fee stops")
	assert_true(game.player.hand.is_empty())



func test_an_item_with_no_tool_is_off_the_menu():
	for c in [Vector2i(0, 3), Vector2i(0, 4)]:
		var st: Station = game.stations[c]
		game.world._unregister(st)
		st.queue_free()
	assert_eq(Menu.off_reason(game.menu.items[0], game.menu_stock.kitchen_stock(), game.menu_stock.kitchen_tools()), "No grill")
	assert_true(game.menu_stock.tonight_menu().is_empty())
	var g: Guest = game.seating.spawn_guest(0)
	assert_true(game.serving.order_for(g).main.is_empty(), "nothing is offered")



func test_an_empty_fridge_gives_nothing_in_service():
	game.kitchen.unstore(Vector2i(0, 2), "box_patty")
	game.cooking.use_station(game.stations[Vector2i(0, 2)])
	assert_eq(game.player.held, "")
	assert_eq(game.cooking.prompt_for(game.stations[Vector2i(0, 2)]), "")



func test_the_menu_screen_opens_at_night_only():
	assert_false(game.menu_stock.open_menu(), "locked during service")
	assert_false(game.hud.menu_open())
	_to_build()
	game.coop.act(0, "menu")
	assert_true(game.hud.menu_open())
	game.coop.act(0, "menu")
	assert_false(game.hud.menu_open())



func test_writing_an_item_on_the_menu_screen():
	_to_build()
	game.menu_stock.stock_box("cheese", Vector2i(1, 6))
	game.world.add_station("slicer", Vector2i(2, 6))
	assert_true(game.menu_stock.open_menu())
	var ms: MenuScreen = game.hud.menu
	ms.new_item("main")
	assert_eq(ms.selected(), "add:bun", "the highlight starts on the kitchen's first ingredient")
	game.coop.act(0, "use")
	ms.toggle("cheese")
	ms.toggle("patty")
	var it: Dictionary = ms.editing()
	assert_eq(it.ingredients, ["bun", "patty", "cheese"], "bun to patty to cheese whatever the order ticked")
	assert_eq(it.name, "Cheese Patty Bun", "a made-up name until it is named")
	assert_true(game.menu.items.has(it))
	assert_eq(ms.selected(), "add:patty", "the highlight stays on the chip pressed")
	ms.toggle("cheese")
	assert_eq(it.ingredients, ["bun", "patty"], "ticking cheese off takes it out")
	assert_eq(it.name, "Patty Bun")
	ms.toggle("cheese")
	ms._set_level("dear")
	assert_eq(Menu.price_of(it), roundi(10 * 1.25))
	ms.set_name_text("The Big One Burger Deluxe")
	assert_eq(it.name, "The Big One Burger", "18 characters at most")
	ms.toggle("bun")
	assert_eq(it.name, "The Big One Burger", "a name of the player's stays")
	ms._toggle_off()
	assert_eq(Menu.off_reason(it, game.menu_stock.kitchen_stock(), game.menu_stock.kitchen_tools()), "Off tonight")
	assert_false(game.menu_board.names.has(it.name))
	ms._toggle_off()
	assert_true(game.menu_board.names.has(it.name))
	ms._delete()
	assert_false(game.menu.items.has(it))
	assert_true(ms.editing().is_empty(), "back to the list")



func test_naming_with_the_pad_letter_grid():
	_to_build()
	game.menu_stock.open_menu()
	var ms: MenuScreen = game.hud.menu
	ms.open_item(game.menu.items[0])
	ms.start_naming("grid")
	assert_eq(ms.naming(), "grid")
	for k in 7:
		ms._rub_out()
	assert_true(ms.select("L:%d" % MenuScreen.LETTERS.find("D")))
	game.coop.act(0, "use")
	ms._type_letter("I")
	ms._type_letter("N")
	ms._type_letter("E")
	ms._type_letter("R")
	game.coop.act(0, "back")
	assert_eq(ms.naming(), "")
	assert_eq(game.menu.items[0].name, "Diner")



func test_keys_move_the_highlight_on_the_menu_screen():
	_to_build()
	game.menu_stock.open_menu()
	var ms: MenuScreen = game.hud.menu
	await get_tree().process_frame   # laid out
	assert_true(ms.select("add:main"))
	game.coop.act(0, "right")
	assert_eq(ms.selected(), "add:side")
	game.coop.act(0, "left")
	assert_eq(ms.selected(), "add:main")
	game.coop.act(0, "up")
	assert_eq(ms.selected(), "item:%d" % game.menu.items[0].id, "the Burger is above Add")
	game.coop.act(0, "use")
	assert_eq(ms.editing(), game.menu.items[0])
	game.coop.act(0, "back")
	assert_true(ms.editing().is_empty())
	game.coop.act(0, "back")
	assert_false(game.hud.menu_open())



func test_night_zero_hints_come_one_at_a_time():
	game.menu.items.clear()
	for c in [Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 6)]:
		var st: Station = game.stations[c]
		game.world._unregister(st)
		st.queue_free()
	_to_build()
	game.ledger.history.clear()   # as on the night before day 1
	assert_eq(game.menu_stock.night_hint(), game.NIGHT_HINTS[0])
	game.menu_stock.stock_box("bun", Vector2i(0, 6), 1, 1)
	assert_eq(game.menu_stock.night_hint(), game.NIGHT_HINTS[0], "a tool too")
	game.world.add_station("board", Vector2i(0, 3), 1, 1)
	assert_eq(game.menu_stock.night_hint(), "", "no menu note: the key over the board says it")
	game.menu.add("main", ["bun"], "Bread")
	assert_eq(game.menu_stock.night_hint(), game.NIGHT_HINTS[2])
	game.ledger.history.append({})
	assert_eq(game.menu_stock.night_hint(), "", "only on night zero")



# ---------------------------------------------------------------- seaside

## The seaside kitchen starts with a fish icebox and a bread basket, and its fixed
## Fish roll goes from ticket to paid bill like the Burger.
func test_seaside_fish_roll_from_ticket_to_bill():
	Scenery.theme_id = "seaside"
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	_neutral_tastes()
	game.menu_stock.test_kitchen()
	assert_null(game.menu_stock.storage_of("patty"), "no diner stations by the sea")
	var g := _ordered_guest()
	assert_eq(g.order.main.name, "Fish roll")
	game.cooking.use_station(game.menu_stock.storage_of("fish"))
	assert_eq(game.player.held, "raw:fish")
	_use("stove")
	_run(Station.COOK_TIME + 0.5)
	_use("stove")
	game.cooking.use_station(_the_pass())
	game.cooking.use_station(game.menu_stock.storage_of("roll"))
	game.cooking.use_station(_the_pass())
	_use("dish_rack")
	game.cooking.use_station(_the_pass())
	game.cooking.use_station(_the_pass())
	assert_true(game.player.dishes[0].is_ready(game.menu.items))
	game.cooking.use_station(g.table)
	_run(g.eat_time + 0.5)
	assert_eq(g.bill_base, 9, "the Fish roll: roll 2 and fish 7")



## Every ingredient has a model in each state it can be in, and a stacked layer.
func test_every_ingredient_has_a_model():
	for id: String in Pantry.ITEMS:
		for state in ["raw", "prep", "burnt"]:
			var n := Node3D.new()
			BuildFood.ingredient(n, id, state)
			assert_gt(n.get_child_count(), 0, "%s %s is drawn" % [id, state])
			n.free()
		var t := Node3D.new()
		assert_gt(BuildFood._layer(t, id, 0.0, true, true), 0.0, "%s stacks on a plate" % id)
		t.free()
	for look in ["raw", "nearly", "perfect", "dry", "burnt"]:
		var f := Node3D.new()
		BuildFood.fillet(f, look)
		assert_gt(f.get_child_count(), 0, "fish fillet looks %s" % look)
		f.free()



func test_a_roll_dish_icon_is_side_on_not_a_burger():
	var burger := Icons.icon("dish:bun,patty")
	var roll := Icons.icon("dish:roll,fish")
	assert_gt(roll.size(), 0)
	assert_ne(roll.size(), burger.size(), "a roll dish is drawn its own way")
	var tail := false
	for layer: Array in roll:
		if (layer[0] as PackedVector2Array).size() == 3 and layer[1] == Pantry.ITEMS.fish.prepped:
			tail = true
	assert_true(tail, "the fish in the roll has a tail")



# ---------------------------------------------------------------- PRD 7: catalog and themes

func test_play_offers_the_themes_and_back_returns_to_the_title():
	game.session.open_title()
	game.session.play()
	var t: Title = game.hud.options_ui.title
	assert_true(t.themes_open)
	assert_eq(t.theme_ids, ["diner", "seaside"] as Array[String])
	assert_eq(t.buttons.size(), 3, "a row a theme and Back")
	_tap(KEY_ESCAPE)
	assert_false(t.themes_open, "Back: the title again")
	assert_eq(t.buttons[0].text, "Play")
	assert_eq(game.phase, game.Phase.TITLE)



func test_the_picker_sets_the_theme_and_remembers_it():
	game.session.open_title()
	game.session.play()
	_tap(KEY_DOWN)
	assert_eq(game.hud.options_ui.title.theme_ids[game.hud.options_ui.title.sel], "seaside")
	_tap(KEY_ENTER)
	assert_eq(Scenery.theme_id, "seaside", "the theme holds for the run")
	assert_eq(game.phase, game.Phase.BUILD)
	assert_eq(game.session.remembered_theme(), "seaside")
	Scenery.theme_id = "diner"
	game.session.open_title()
	game.session.play()
	assert_eq(game.hud.options_ui.title.theme_ids[game.hud.options_ui.title.sel], "seaside", "last time's theme is chosen to start with")



func test_regulars_theme_skips_the_picker():
	OS.set_environment("REGULARS_THEME", "diner")
	game.session.open_title()
	game.session.play()
	OS.unset_environment("REGULARS_THEME")
	assert_false(game.hud.options_ui.title_open(), "straight to the night before day 1")
	assert_eq(game.phase, game.Phase.BUILD)



func test_starting_over_shows_the_theme_card_but_not_the_title():
	var script = game.get_script()
	script._title_seen = true
	script._theme_picked = false   # as restart() leaves it
	var fresh = load("res://game/main.tscn").instantiate()
	fresh.theme_path = THEME_TEST_PATH
	add_child_autofree(fresh)
	fresh.set_process(false)
	assert_true(fresh.hud.options_ui.title_open())
	assert_true(fresh.hud.options_ui.title.themes_open, "the theme card, the title skipped")
	fresh.session.choose_theme("diner")
	assert_eq(fresh.phase, fresh.Phase.BUILD)



func test_the_shop_lists_only_what_the_theme_sells():
	game.ledger.xp = 1000   # every level, so nothing is hidden
	var ids := func() -> Array:
		return game.session.shop_items().map(func(bp: Dictionary) -> String: return str(bp.id))
	var diner: Array = ids.call()
	assert_true(diner.has("jukebox") and diner.has("plant") and diner.has("floor_lamp"))
	assert_false(diner.has("aquarium") or diner.has("palm"))
	Scenery.theme_id = "seaside"
	var sea: Array = ids.call()
	assert_true(sea.has("aquarium") and sea.has("palm") and sea.has("floor_lamp"))
	assert_false(sea.has("jukebox") or sea.has("plant"))
	_to_build()
	game.ledger.money = 999
	game.ledger.xp = 9999
	assert_false(game.placing.pick_catalog("jukebox"), "not sold at the seaside")
	assert_true(game.placing.pick_catalog("aquarium"))



func test_every_catalog_piece_builds_a_model_in_both_themes():
	for theme: String in ["diner", "seaside"]:
		Scenery.theme_id = theme
		for id: String in Catalog.ITEMS:
			if Catalog.is_build_tool(id) or id in ["rug", "screen"]:
				continue
			if Catalog.ITEMS[id].get("seat", false) and not Catalog.SEAT_PIECES_ON_SALE:
				continue   # EPIC-85: the seat pieces get their models before they go on sale
			for tier in range(1, int(Catalog.ITEMS[id].tiers) + 1):
				var n := Node3D.new()
				BuildStations.station(n, id, tier)
				assert_gt(n.get_child_count(), 0, "%s %d has a model" % [id, tier])
				n.free()



func test_a_new_decor_piece_cheers_by_its_reach_and_shows_it_while_carried():
	_to_build()
	game.ledger.money = 999
	game.ledger.xp = 9999
	assert_eq(game.decor.range_of("jukebox", 1), 4)
	assert_eq(game.decor.range_of("flower_stand"), 1)
	var seat: Vector2i = game.stations[Vector2i(8, 3)].seats[0]
	var before := float(game.decor.decor_bonus(seat).joy)
	game.world.add_station("flower_stand", seat + Vector2i(0, -1))
	assert_almost_eq(float(game.decor.decor_bonus(seat).joy) - before, Catalog.joy_of("flower_stand") * Decor.BESIDE, 0.0001)
	var with_flowers := float(game.decor.decor_bonus(seat).joy)
	game.world.add_station("coat_stand", seat + Vector2i(0, -3))
	assert_eq(float(game.decor.decor_bonus(seat).joy), with_flowers, "three cells off: out of a coat stand's reach")
	assert_true(game.placing.pick_catalog("jukebox"))
	game.decor._update_range()
	assert_gt(game._range_marks.get_child_count(), 1, "the reach marks, like the fern's")
	game.placing.cancel_hand()



func test_a_dish_rack_beside_the_sink_takes_more_dishes():
	var sink: Station = game.world.find_station("sink")
	assert_true(sink.racked, "the starting rack is beside the sink")
	var start: Station = game.world.find_station("dish_rack")
	game.world._unregister(start)
	assert_false(sink.racked)
	sink.dirty = Station.SINK_PILED
	assert_true(sink.messy())
	var rack: Station = game.world.add_station("dish_rack", sink.cell + Vector2i(0, 1))
	assert_true(sink.racked)
	assert_eq(Station.piled_at(true), Station.SINK_PILED + Station.RACK_HOLDS)
	assert_false(sink.messy(), "the rack takes the overflow")
	sink.dirty = Station.SINK_PILED + Station.RACK_HOLDS
	assert_true(sink.messy(), "piled at SINK_PILED + RACK_HOLDS")
	game.world._unregister(rack)
	assert_false(sink.racked)



func test_the_dish_rack_is_an_essential():
	assert_true("dish_rack" in Game.ESSENTIALS)
	game.world._unregister(game.world.find_station("dish_rack"))
	assert_true(game.placing.missing("dish_rack"))


func test_a_second_sink_and_bin_each_have_their_own_mess():
	_to_build()
	var sink2: Station = game.world.add_station("sink", Vector2i(2, 4))
	var bin2: Station = game.world.add_station("bin", Vector2i(1, 5))
	game.world.find_station("sink").dirty = 1
	sink2.dirty = 1
	sink2.dirty = 0
	bin2.count = 2
	game.seating._collect_gross()
	var keys := {}
	for g: Dictionary in game._gross:
		if g.kind == "bin":
			keys[g.key] = true
	assert_eq(keys.size(), 2, "each bin its own sightline")
	game.ledger.money = 0
	assert_true(game.placing.pick_up(Grid.center(Vector2i(2, 4))))
	assert_true(game.placing.sell_hand(), "a second sink sells for half")
	assert_eq(game.ledger.money, Catalog.price_of("sink") / 2)
	game.world.find_station("sink").dirty = 0
	assert_true(game.placing.pick_up(Grid.center(game.world.find_station("sink").cell)))
	assert_eq(game.placing.sell_block(), "", "the last sink sells too; the door waits for another")
	game.placing.cancel_hand()
