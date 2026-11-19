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
	var plates: Station = game.world.find_station("plates")
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
	_use("plates")
	assert_eq(game.player.dishes.size(), 2, "still two dishes")
	assert_eq(game.player.dishes.filter(func(d: Dish) -> bool: return d.vessel == "").size(), 0)


func test_the_plated_burger_is_served():
	var g := _ordered_guest()
	_hold_loose_burger()
	_use("plates")
	assert_ne(game.cooking.use_station(g.table), "Put it on a plate first")
	assert_ne(g.state, "waiting")


func test_a_refused_stack_falls_through():
	var d := Dish.stack("prep:patty", 1.0, "prep:bun", 1.0)
	d.ings = ["patty", "cola"]
	d.qs = [1.0, 1.0]
	game.player.set_held("dishes", 1.0, [d] as Array[Dish])
	var plates: Station = game.world.find_station("plates")
	assert_ne(game.cooking.prompt_for(plates), "Plate it")
	assert_eq(d.vessel, "")
