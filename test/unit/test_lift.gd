extends GutTest
## E lifts a piece, its boxes with it (owner's review of night zero): R turns it, C sells
## it, Z and X choose an upgrade on the strip along the bottom and Space buys it. Boxes
## are bought in the shop and put in. Every piece can be sold.

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
	game.session.open_build()


func _face(at: Vector2i, dir: Vector2i) -> void:
	game.player.position = Grid.center(at)
	game.player.look(dir)


func test_a_hood_over_bare_floor_is_lifted_and_sold():
	_face(Vector2i(1, 3), Vector2i(-1, 0))
	assert_eq(game.room_edit.build_action(), "Pick up")
	game.room_edit.build_interact()
	assert_eq(game.player.hand.id, "hood", "E lifts it off the wall")
	var money: int = game.ledger.money
	game.coop.act(0, "sell")   # C
	assert_true(game.player.hand.is_empty())
	assert_gt(game.ledger.money, money)
	assert_false(game.highs.has(Vector2i(0, 3)))


func test_the_plate_stack_is_sold_and_the_door_waits_for_another():
	_face(Vector2i(2, 3), Vector2i(0, -1))
	game.room_edit.build_interact()
	game.coop.act(0, "sell")
	assert_null(game.world.find_station("plates"), "the plate stack is for sale")
	assert_true(game.menu_stock.open_block().contains("plate stack"))
	game.ledger.money = 100
	assert_true(game.session.shop_items("", "Tools").any(func(bp: Dictionary) -> bool: return bp.id == "plates"))


func test_the_last_sink_is_sold_and_sold_again_at_any_level():
	_face(Vector2i(3, 3), Vector2i(0, -1))
	assert_eq(game.card.lift_name(game.player), "wall shelf", "what hangs over the sink comes first")
	game.room_edit.build_interact()
	assert_eq(game.player.hand.id, "shelf")
	game.room_edit.build_interact()   # put back where it hung
	assert_true(game.highs.has(Vector2i(3, 2)))
	assert_eq(game.card.lift_name(game.player), "sink", "then E reaches the sink under it")
	game.room_edit.build_interact()
	game.coop.act(0, "sell")
	assert_null(game.world.find_station("sink"), "the last sink sells")
	assert_true(game.menu_stock.open_block().contains("sink"))
	game.ledger.money = 200
	assert_lt(game.ledger.level(), Catalog.level_of("sink", 1))
	assert_true(game.placing.pick_catalog("sink"), "a missing essential is sold at any level")


func test_a_box_from_the_shop_goes_into_a_counter():
	var c := Vector2i(4, 3)
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	game.session.open_shop()
	assert_true(game.session.shop_items("", "Ingredients").any(func(bp: Dictionary) -> bool: return bp.id == "box_bun"))
	assert_true(game.placing.buy({"id": "box_bun", "tier": 1}))
	assert_eq(game.player.hand.id, "box_bun", "the box is in hand")
	game.room_edit.build_interact()
	assert_true(game.kitchen.stock(c).has("box_bun"), "E puts it in")
	assert_true(game.player.hand.is_empty())


func test_e_lifts_a_box_before_its_counter_and_esc_puts_it_back():
	var c := Vector2i(4, 3)
	game.kitchen.store(c, "box_bun")
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	assert_eq(game.card.lift_name(game.player), game.placing.piece_name({"id": "box_bun", "tier": 1}).to_lower())
	game.room_edit.build_interact()
	assert_eq(game.player.hand.id, "box_bun", "the box comes up first")
	assert_true(game.stations.has(c), "the counter stays")
	assert_false(game.kitchen.stock(c).has("box_bun"))
	game.placing.cancel_hand(game.player)   # Esc
	assert_true(game.kitchen.stock(c).has("box_bun"), "back in its counter")
	game.room_edit.build_interact()   # E again lifts it; E on the same counter puts it back
	assert_eq(game.player.hand.id, "box_bun")
	game.room_edit.build_interact()
	assert_true(game.player.hand.is_empty())
	assert_true(game.kitchen.stock(c).has("box_bun"))
	game.kitchen.unstore(c, "box_bun")   # empty now: the counter itself
	game.room_edit.build_interact()
	assert_eq(game.player.hand.id, "counter")
	assert_false(game.stations.has(c))


func test_a_click_lifts_the_box_too():
	var c := Vector2i(4, 3)
	game.kitchen.store(c, "box_bun")
	game.placing.pick_up(Grid.center(c), game.player)
	assert_eq(game.player.hand.id, "box_bun")
	assert_true(game.stations.has(c))


func test_a_wall_piece_gives_up_its_boxes_then_itself_then_the_counters_boxes_then_the_counter():
	var c := Vector2i(0, 6)   # the starter cabinet hangs here
	if not game.stations.has(c):
		game.world.add_station("counter", c)
	if not game.highs.has(c):
		game.world.add_high("shelf", c)
	var cells: Dictionary = game.kitchen.cells[c]
	cells.stock.high.assign(["box_bun"])
	cells.stock.base.assign(["box_cheese"])
	_face(Vector2i(1, 6), Vector2i(-1, 0))
	var order: Array[String] = []
	for i in 6:
		game.room_edit.build_interact()
		if game.player.hand.is_empty():
			break
		order.append(game.player.hand.id)
		game.player.hand = {}   # set it aside: this test follows the order only
	assert_eq(order, ["box_bun", "cabinet", "box_cheese", "counter"])


func test_a_counter_lifted_whole_keeps_its_boxes_and_the_strip_takes_one_out():
	var c := Vector2i(4, 3)
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	game.room_edit.build_interact()
	assert_eq(game.player.hand.id, "counter")
	game.player.hand.stock = ["box_bun"]
	var last: Dictionary = game.upgrades.strip_choices()[-1]
	assert_eq(last, {"kind": "box", "id": "box_bun"}, "its boxes are on the strip after its upgrades")
	game.player.strip_pick = game.upgrades.strip_choices().size() - 1
	game.coop.act(0, "buy")
	assert_eq(game.player.hand.get("stock", []), [], "Space took it out")
	game.player.hand.stock = ["box_bun"]
	assert_true(game.placing.place(Vector3i(2, 5, 0)))
	assert_true(game.kitchen.stock(Vector2i(2, 5)).has("box_bun"), "the boxes moved with it")


func test_r_turns_a_lifted_counter():
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	var f: int = game.stations[Vector2i(4, 3)].facing
	game.room_edit.build_interact()
	game.coop.act(0, "turn")
	assert_eq(int(game.player.hand.facing), (f + 1) % 4)


func test_the_till_comes_off_its_counter_first():
	_face(Vector2i(5, 2), Vector2i(-1, 0))
	game.room_edit.build_interact()
	assert_eq(game.player.hand.id, "till")
	assert_null(game.paying.till_station(), "carried, there is no till")
	assert_true(game.menu_stock.open_block().contains("till"))
	assert_false(game.placing.can_place(Vector3i(6, 3, 0)), "not on the floor")
	assert_true(game.placing.place(Vector3i(4, 4, 0)))
	assert_eq(game.paying.till_cell(), Vector2i(4, 4), "it stands on another counter")


func test_the_till_is_sold_and_bought_again():
	_face(Vector2i(5, 2), Vector2i(-1, 0))
	game.room_edit.build_interact()
	var money: int = game.ledger.money
	assert_eq(game.placing.sell_block(), "")
	game.coop.act(0, "sell")
	assert_eq(game.ledger.money, money + Catalog.price_of("till") / 2)
	assert_null(game.paying.till_station())
	assert_true(game.session.shop_items("", "Tools").any(func(bp: Dictionary) -> bool: return bp.id == "till"))

