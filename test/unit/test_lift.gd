extends GutTest
## E picks up every piece, the start's included, and every piece can be sold. A piece
## that keeps boxes rises with its storage card open: choose a box, E puts it down.

var game


func before_each():
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"
	game.arrivals.clear()
	game.step(0.1)
	game.step(0.1)
	game.open_build()


func _face(at: Vector2i, dir: Vector2i) -> void:
	game.player.position = Grid.center(at)
	game.player.look(dir)


func test_a_hood_over_bare_floor_is_picked_up_and_sold():
	_face(Vector2i(1, 3), Vector2i(-1, 0))
	assert_eq(game.build_action(), "Pick up")
	assert_eq(game.lift_name(), "hood")
	game.build_interact()
	assert_eq(game.player.hand.id, "hood")
	var money: int = game.ledger.money
	assert_eq(game.sell_block(), "")
	assert_true(game.sell_hand())
	assert_gt(game.ledger.money, money)
	assert_false(game.highs.has(Vector2i(0, 3)))


func test_the_tray_stack_is_sold_and_the_door_waits_for_another():
	_face(Vector2i(2, 3), Vector2i(0, -1))
	game.build_interact()
	assert_eq(game.player.hand.id, "trays")
	assert_true(game.sell_hand(), "the tray stack is for sale")
	assert_true(game.open_block().contains("tray stack"))
	game.ledger.money = 100
	assert_true(game.shop_items("", "Kitchen").any(func(bp: Dictionary) -> bool: return bp.id == "trays"))


func test_the_last_sink_is_sold_and_sold_again_at_any_level():
	_face(Vector2i(3, 3), Vector2i(0, -1))
	assert_eq(game.lift_name(), "wall shelf", "what hangs over the sink comes first")
	game.build_interact()
	assert_true(game.storing(), "a shelf keeps boxes: it rises with its card open")
	game.storage_put_down()
	assert_false(game.shopping)
	assert_true(game.highs.has(Vector2i(3, 2)), "put back where it hung")
	assert_eq(game.lift_name(), "sink", "then E reaches the sink under it")
	game.build_interact()
	assert_eq(game.player.hand.id, "sink")
	assert_true(game.sell_hand(), "the last sink sells")
	assert_true(game.open_block().contains("sink"))
	game.ledger.money = 200
	assert_lt(game.ledger.level(), Catalog.level_of("sink", 1))
	assert_true(game.pick_catalog("sink"), "a missing essential is sold at any level")


func test_e_lifts_a_counter_and_puts_it_down_with_the_chosen_box_in():
	var c := Vector2i(4, 3)
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	var y: float = game.stations[c].position.y
	game.build_interact()
	assert_true(game.storing())
	assert_true(game.player.hand.get("carry", false))
	assert_gt(game.stations[c].position.y, y, "it rises where it stands")
	assert_false(game.hud.shop_tabs().has("Move"))
	var bun: Array = game.shop_items("", "Ingredients").filter(func(bp: Dictionary) -> bool: return bp.id == "box_bun")
	game.hud._shop_index = game.hud._shop_items.find(bun[0])
	game.shop_action("use")
	assert_false(game.shopping)
	assert_true(game.player.hand.is_empty())
	assert_true(game.kitchen.stock(c).has("box_bun"), "the chosen box went in")
	assert_eq(game.stations[c].position.y, y, "and it came back down")


func test_tab_keeps_a_lifted_counter_in_hand_with_its_boxes():
	var c := Vector2i(4, 3)
	game.kitchen.store(c, "box_bun")
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	game.build_interact()
	game.shop_action("shop")
	assert_false(game.shopping)
	assert_eq(game.player.hand.id, "counter")
	assert_eq(game.player.hand.get("stock", []), ["box_bun"])
	assert_false(game.stations.has(c))
	assert_true(game.place(Vector3i(2, 5, 0)))
	assert_true(game.kitchen.stock(Vector2i(2, 5)).has("box_bun"), "the boxes moved with it")


func test_the_till_comes_off_its_counter_first_and_moves_to_another():
	_face(Vector2i(5, 2), Vector2i(-1, 0))
	assert_eq(game.lift_name(), "till")
	game.build_interact()
	assert_eq(game.player.hand.id, "till")
	assert_false(game.shopping, "a till keeps no boxes: no card")
	assert_null(game.till_station(), "carried, there is no till")
	assert_true(game.open_block().contains("till"))
	assert_false(game.can_place(Vector3i(6, 3, 0)), "not on the floor")
	assert_true(game.place(Vector3i(4, 4, 0)))
	assert_eq(game.till_cell(), Vector2i(4, 4), "it stands on another counter")
	assert_eq(game.lift_name(), "counter", "the counter it left is a plain counter again")


func test_the_till_is_sold_and_bought_again():
	_face(Vector2i(5, 2), Vector2i(-1, 0))
	game.build_interact()
	var money: int = game.ledger.money
	assert_eq(game.sell_block(), "")
	assert_true(game.sell_hand())
	assert_eq(game.ledger.money, money + Catalog.price_of("till") / 2)
	assert_null(game.till_station())
	assert_true(game.shop_items("", "Kitchen").any(func(bp: Dictionary) -> bool: return bp.id == "till"))
	assert_true(game.pick_catalog("till"))
	assert_true(game.place(Vector3i(4, 5, 0)))
	assert_eq(game.till_cell(), Vector2i(4, 5))
	assert_true(game.player.hand.is_empty(), "one till: it does not stay in hand for another")
	assert_false(game.pick_catalog("till"), "and no second one")
