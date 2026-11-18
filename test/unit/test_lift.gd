extends GutTest
## E opens every piece's one card where it stands, the start's included (review, item 4):
## what is in it, its upgrades, Move, Turn and Sell. Nothing is lifted just to stock it.
## Moving is the card's Move, or holding E. Every piece can be sold.

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


## The card's action card for `act`, chosen and pressed with E.
func _press(act: String) -> void:
	var items: Array[Dictionary] = game.hud._shop_items
	var k := -1
	for i in items.size():
		if items[i].get("act", "") == act:
			k = i
	assert_gt(k, -1, "the card has a %s card" % act)
	game.hud._shop_index = k
	game.shop_action("use")


func test_a_hood_over_bare_floor_opens_its_card_and_sells_from_it():
	_face(Vector2i(1, 3), Vector2i(-1, 0))
	assert_eq(game.build_action(), "Open")
	game.build_interact()
	assert_true(game.storing(), "its card, where it hangs")
	assert_true(game.player.hand.is_empty(), "nothing lifted")
	var money: int = game.ledger.money
	_press("sell")
	assert_false(game.shopping)
	assert_gt(game.ledger.money, money)
	assert_false(game.highs.has(Vector2i(0, 3)))


func test_the_plate_stack_is_sold_and_the_door_waits_for_another():
	_face(Vector2i(2, 3), Vector2i(0, -1))
	game.build_interact()
	_press("sell")
	assert_null(game.find_station("plates"), "the plate stack is for sale")
	assert_true(game.open_block().contains("plate stack"))
	game.ledger.money = 100
	assert_true(game.shop_items("", "Kitchen").any(func(bp: Dictionary) -> bool: return bp.id == "plates"))


func test_the_last_sink_is_sold_and_sold_again_at_any_level():
	_face(Vector2i(3, 3), Vector2i(0, -1))
	assert_eq(game._card_name(game.player), "wall shelf", "what hangs over the sink comes first")
	game.build_interact()
	assert_true(game.storing())
	assert_true(game.card_keeps_boxes(), "a shelf keeps boxes")
	game.shop_action("back")
	assert_false(game.shopping)
	assert_true(game.highs.has(Vector2i(3, 2)), "it never moved")
	assert_eq(game._card_name(game.player), "sink", "then E reaches the sink under it")
	game.build_interact()
	_press("sell")
	assert_null(game.find_station("sink"), "the last sink sells")
	assert_true(game.open_block().contains("sink"))
	game.ledger.money = 200
	assert_lt(game.ledger.level(), Catalog.level_of("sink", 1))
	assert_true(game.pick_catalog("sink"), "a missing essential is sold at any level")


func test_e_opens_a_counter_where_it_stands_and_stocks_it():
	var c := Vector2i(4, 3)
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	var y: float = game.stations[c].position.y
	game.build_interact()
	assert_true(game.storing())
	assert_true(game.player.hand.is_empty(), "nothing is lifted to stock it")
	assert_eq(game.stations[c].position.y, y, "it stays where it stands")
	assert_false(game.shop_items().is_empty())
	var first: Dictionary = game.hud.shop_selected()
	assert_false(first.has("act"), "the boxes come first")
	var bun: Array = game.hud._shop_items.filter(func(bp: Dictionary) -> bool: return bp.id == "box_bun")
	game.hud._shop_index = game.hud._shop_items.find(bun[0])
	game.shop_action("use")
	assert_true(game.shopping, "the card stays open for more")
	assert_true(game.kitchen.stock(c).has("box_bun"), "the chosen box went in")
	game.shop_action("back")
	assert_false(game.shopping, "E and Back are all it needs")


func test_move_on_the_card_carries_a_counter_with_its_boxes():
	var c := Vector2i(4, 3)
	game.kitchen.store(c, "box_bun")
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	game.build_interact()
	_press("move")
	assert_false(game.shopping)
	assert_eq(game.player.hand.id, "counter")
	assert_eq(game.player.hand.get("stock", []), ["box_bun"])
	assert_false(game.stations.has(c))
	assert_true(game.place(Vector3i(2, 5, 0)))
	assert_true(game.kitchen.stock(Vector2i(2, 5)).has("box_bun"), "the boxes moved with it")


func test_holding_e_moves_the_piece_with_the_fill_bar():
	var c := Vector2i(4, 3)
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	game.build_interact()
	assert_true(game.storing())
	game._tick_card_hold(game.player, true, game.HOLD_MOVE * 0.6)
	assert_true(game.storing(), "not yet")
	assert_true(game.player._give_bar.visible, "the hold bar fills")
	game._tick_card_hold(game.player, true, game.HOLD_MOVE * 0.6)
	assert_false(game.shopping, "held long enough: the card shuts")
	assert_eq(game.player.hand.id, "counter", "and the piece is in hand to move")
	assert_false(game.stations.has(c))


func test_turn_on_the_card_turns_it_where_it_stands():
	var c := Vector2i(4, 3)
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	var f: int = game.stations[c].facing
	game.build_interact()
	_press("turn")
	assert_true(game.storing(), "the card stays open")
	assert_eq(game.stations[c].facing, (f + 1) % 4)


func test_the_till_comes_off_its_counter_from_the_counters_card():
	_face(Vector2i(5, 2), Vector2i(-1, 0))
	game.build_interact()
	_press("till")
	assert_eq(game.player.hand.id, "till")
	assert_null(game.till_station(), "carried, there is no till")
	assert_true(game.open_block().contains("till"))
	assert_false(game.can_place(Vector3i(6, 3, 0)), "not on the floor")
	assert_true(game.place(Vector3i(4, 4, 0)))
	assert_eq(game.till_cell(), Vector2i(4, 4), "it stands on another counter")


func test_the_till_is_sold_and_bought_again():
	_face(Vector2i(5, 2), Vector2i(-1, 0))
	game.build_interact()
	_press("till")
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
