extends "res://test/helpers/game_case.gd"
## Food in hand is plated by taking a plate from the stack, loose stacks included.


## A loose bun-on-patty burger, picked up off the pass.
func _hold_loose_burger() -> void:
	game.player.set_held("prep:patty", 1.0)
	game.cooking.use_station(_the_pass())
	game.player.set_held("prep:bun", 1.0)
	game.cooking.use_station(_the_pass())
	game.player.set_held("")
	game.cooking.use_station(_the_pass())


func test_a_loose_stack_in_hand_is_plated_at_the_plate_stack():
	_ordered_guest()
	_hold_loose_burger()
	var plates: Station = game.world.find_station("dish_rack")
	var n := plates.count
	assert_eq(game.cooking.prompt_for(plates), "Plate it")
	assert_eq(game.cooking.use_station(plates), "Plate it")
	assert_eq(plates.count, n - 1)
	assert_eq(game.player.dishes.size(), 1)
	assert_eq(game.player.dishes[0].vessel, Dish.PLATE)
	assert_true(game.player.dishes[0].is_ready(game.menu.items))


func test_a_loose_stack_is_plated_with_full_hands():
	_ordered_guest()
	_hold_loose_burger()
	var full := Dish.make(Dish.PLATE)
	full.add("prep:bun", 1.0)
	game.player.take_dish(full)
	assert_false(game.player.has_room(), "hands full")
	_use("dish_rack")
	assert_eq(game.player.dishes.size(), 2, "still two dishes")
	assert_eq(game.player.dishes.filter(func(d: Dish) -> bool: return d.vessel == "").size(), 0)


func test_the_plated_burger_is_served():
	var g := _ordered_guest()
	_hold_loose_burger()
	_use("dish_rack")
	game.cooking.use_station(_the_pass())
	assert_eq(game.cooking.prompt_for(_the_pass()), "Pick up")
	game.cooking.use_station(_the_pass())
	assert_ne(game.cooking.use_station(g.table), "Put it on a plate first")
	assert_ne(g.state, "waiting")


func test_a_refused_stack_falls_through():
	var d := Dish.stack("prep:patty", 1.0, "prep:bun", 1.0)
	d.ings = ["patty", "cola"]
	d.qs = [1.0, 1.0]
	game.player.set_held("dishes", 1.0, [d] as Array[Dish])
	var plates: Station = game.world.find_station("dish_rack")
	assert_ne(game.cooking.prompt_for(plates), "Plate it")
	assert_eq(d.vessel, "")


func test_a_plate_in_hand_goes_under_a_loose_burger_on_the_pass():
	_ordered_guest()
	game.player.set_held("prep:patty", 1.0)
	game.cooking.use_station(_the_pass())
	game.player.set_held("prep:bun", 1.0)
	game.cooking.use_station(_the_pass())
	game.player.set_held("")
	_use("dish_rack")
	assert_eq(game.cooking.prompt_for(_the_pass()), "Plate it")
	assert_eq(game.cooking.use_station(_the_pass()), "Plate it")
	assert_eq(game.player.dishes.size(), 0)
	assert_eq(_the_pass().item, "dish")
	assert_eq(_the_pass().dish.vessel, Dish.PLATE)
	assert_true(_the_pass().dish.is_ready(game.menu.items))
	assert_eq(game.cooking.prompt_for(_the_pass()), "Pick up")


func test_a_plate_goes_under_a_single_prepped_item():
	game.player.set_held("prep:bun", 1.0)
	game.cooking.use_station(_the_pass())
	_use("dish_rack")
	assert_eq(game.cooking.use_station(_the_pass()), "Plate it")
	assert_eq(game.player.dishes.size(), 0)
	assert_eq(_the_pass().dish.vessel, Dish.PLATE)
	assert_eq(_the_pass().dish.ings.size(), 1)


func test_an_empty_cup_goes_under_a_loose_drink():
	game.world.add_station("fountain", Vector2i(2, 5))
	game.menu.add("drink", ["soda"], "Soda")
	var cup := Dish.make(Dish.CUP)
	var st := _the_pass()
	var drink := Dish.new()
	drink.add("prep:soda", 1.0)
	st.set_dish(drink)
	game.player.take_dish(cup)
	assert_eq(game.cooking.use_station(st), "Pour into cup")
	assert_eq(game.player.dishes.size(), 0)
	assert_eq(st.dish, cup)
	assert_false(cup.is_empty())


func test_a_second_plate_stays_in_hand():
	game.player.set_held("prep:bun", 1.0)
	game.cooking.use_station(_the_pass())
	var first := Dish.make(Dish.PLATE)
	var second := Dish.make(Dish.PLATE)
	game.player.take_dish(first)
	game.player.take_dish(second)
	game.cooking.use_station(_the_pass())
	assert_eq(_the_pass().dish, second, "the plate last taken goes down")
	assert_eq(game.player.dishes, [first] as Array[Dish])


func test_a_refused_stack_keeps_the_plate_in_hand():
	game.player.set_held("prep:patty", 1.0)
	game.cooking.use_station(_the_pass())
	game.player.take_dish(Dish.make(Dish.CUP))
	assert_eq(game.cooking.prompt_for(_the_pass()), "Only drinks go in a cup")
	game.cooking.use_station(_the_pass())
	assert_eq(game.player.dishes.size(), 1)
	assert_eq(_the_pass().item, "prep:patty")


## A plate in hand, empty, taken from the stack.
func _hold_plate() -> Dish:
	var plate := Dish.make(Dish.PLATE)
	game.player.take_dish(plate)
	return plate


func test_a_plate_is_not_put_down_on_the_till_counter():
	var till: Station = game.paying.till_station()
	var plate := _hold_plate()
	assert_eq(game.cooking.prompt_for(till), "Plates go on a clear counter")
	assert_eq(game.cooking.use_station(till), "Plates go on a clear counter")
	assert_eq(game.player.dishes, [plate] as Array[Dish])
	assert_eq(till.item, "")


func test_a_plate_is_not_put_down_on_a_tool():
	var slicer := _tool("slicer", Vector2i(2, 5), "crate_cheese")
	var plate := _hold_plate()
	game.cooking.use_station(slicer)
	assert_eq(game.player.dishes, [plate] as Array[Dish])
	assert_eq(slicer.item, "")


func test_a_plate_is_put_down_on_a_clear_counter_and_the_pass():
	_hold_plate()
	assert_eq(game.cooking.use_station(_the_pass()), "Put down")
	assert_eq(_the_pass().dish.vessel, Dish.PLATE)


func test_food_on_a_tool_goes_onto_the_plate_in_hand():
	var slicer := _tool("slicer", Vector2i(2, 5), "crate_cheese")
	slicer.set_item("prep:bun", 1.0)
	var plate := _hold_plate()
	assert_eq(game.cooking.use_station(slicer), "Plate it")
	assert_eq(game.player.dishes, [plate] as Array[Dish])
	assert_false(plate.is_empty())
	assert_eq(slicer.item, "")


func test_a_helper_never_sets_plates_out_under_the_till():
	var till: Station = game.paying.till_station()
	var rv: Variant = game.crew.room_view
	var h: Helper = Helper.new()
	var c: Variant = rv._free_surface(till.cell, h, false, true)
	assert_ne(c, till.cell)
	h.free()
