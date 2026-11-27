extends "res://test/helpers/game_case.gd"
## Loose items in play are drawn BuildFood.SIZE times their modelled size (T-87).


func test_patty_on_a_counter_settles_at_food_size() -> void:
	var st: Station = game.world.find_station("counter")
	st.set_item("raw:patty")
	_step_tweens(0.4)
	assert_almost_eq(st._item_node.scale.x, BuildFood.SIZE, 0.001)


func test_held_item_settles_at_food_size() -> void:
	game.player.set_held("raw:patty")
	_step_tweens(0.4)
	assert_almost_eq(game.player._held_size, BuildFood.SIZE, 0.001)


func test_meal_on_a_table_is_food_size() -> void:
	var g: Guest = game.seating.spawn_guest(0)
	_run(12.0)
	g._set_meal("raw:patty", 1.0)
	assert_almost_eq(g._meal.scale.x, BuildFood.SIZE, 0.001)
