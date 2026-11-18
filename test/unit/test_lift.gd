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
	game.open_build()


func _face(at: Vector2i, dir: Vector2i) -> void:
	game.player.position = Grid.center(at)
	game.player.look(dir)


func test_a_hood_over_bare_floor_is_lifted_and_sold():
	_face(Vector2i(1, 3), Vector2i(-1, 0))
	assert_eq(game.build_action(), "Pick up")
	game.build_interact()
	assert_eq(game.player.hand.id, "hood", "E lifts it off the wall")
	var money: int = game.ledger.money
	game.act(0, "sell")   # C
	assert_true(game.player.hand.is_empty())
	assert_gt(game.ledger.money, money)
	assert_false(game.highs.has(Vector2i(0, 3)))


func test_the_plate_stack_is_sold_and_the_door_waits_for_another():
	_face(Vector2i(2, 3), Vector2i(0, -1))
	game.build_interact()
	game.act(0, "sell")
	assert_null(game.find_station("plates"), "the plate stack is for sale")
	assert_true(game.open_block().contains("plate stack"))
	game.ledger.money = 100
	assert_true(game.shop_items("", "Tools").any(func(bp: Dictionary) -> bool: return bp.id == "plates"))


func test_the_last_sink_is_sold_and_sold_again_at_any_level():
	_face(Vector2i(3, 3), Vector2i(0, -1))
	assert_eq(game.lift_name(game.player), "wall shelf", "what hangs over the sink comes first")
	game.build_interact()
	assert_eq(game.player.hand.id, "shelf")
	game.build_interact()   # put back where it hung
	assert_true(game.highs.has(Vector2i(3, 2)))
	assert_eq(game.lift_name(game.player), "sink", "then E reaches the sink under it")
	game.build_interact()
	game.act(0, "sell")
	assert_null(game.find_station("sink"), "the last sink sells")
	assert_true(game.open_block().contains("sink"))
	game.ledger.money = 200
	assert_lt(game.ledger.level(), Catalog.level_of("sink", 1))
	assert_true(game.pick_catalog("sink"), "a missing essential is sold at any level")


func test_a_box_from_the_shop_goes_into_a_counter():
	var c := Vector2i(4, 3)
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	game.open_shop()
	assert_true(game.shop_items("", "Ingredients").any(func(bp: Dictionary) -> bool: return bp.id == "box_bun"))
	assert_true(game.buy({"id": "box_bun", "tier": 1}))
	assert_eq(game.player.hand.id, "box_bun", "the box is in hand")
	game.build_interact()
	assert_true(game.kitchen.stock(c).has("box_bun"), "E puts it in")
	assert_true(game.player.hand.is_empty())


func test_e_carries_a_counter_with_its_boxes_and_the_strip_takes_one_out():
	var c := Vector2i(4, 3)
	game.kitchen.store(c, "box_bun")
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	game.build_interact()
	assert_eq(game.player.hand.id, "counter")
	assert_eq(game.player.hand.get("stock", []), ["box_bun"])
	assert_false(game.stations.has(c))
	var last: Dictionary = game.strip_choices()[-1]
	assert_eq(last, {"kind": "box", "id": "box_bun"}, "its boxes are on the strip after its upgrades")
	game.player.strip_pick = game.strip_choices().size() - 1
	game.act(0, "buy")
	assert_eq(game.player.hand.get("stock", []), [], "Space took it out")
	game.player.hand.stock = ["box_bun"]
	assert_true(game.place(Vector3i(2, 5, 0)))
	assert_true(game.kitchen.stock(Vector2i(2, 5)).has("box_bun"), "the boxes moved with it")


func test_r_turns_a_lifted_counter():
	_face(Vector2i(5, 3), Vector2i(-1, 0))
	var f: int = game.stations[Vector2i(4, 3)].facing
	game.build_interact()
	game.act(0, "turn")
	assert_eq(int(game.player.hand.facing), (f + 1) % 4)


func test_the_till_comes_off_its_counter_first():
	_face(Vector2i(5, 2), Vector2i(-1, 0))
	game.build_interact()
	assert_eq(game.player.hand.id, "till")
	assert_null(game.till_station(), "carried, there is no till")
	assert_true(game.open_block().contains("till"))
	assert_false(game.can_place(Vector3i(6, 3, 0)), "not on the floor")
	assert_true(game.place(Vector3i(4, 4, 0)))
	assert_eq(game.till_cell(), Vector2i(4, 4), "it stands on another counter")


func test_the_till_is_sold_and_bought_again():
	_face(Vector2i(5, 2), Vector2i(-1, 0))
	game.build_interact()
	var money: int = game.ledger.money
	assert_eq(game.sell_block(), "")
	game.act(0, "sell")
	assert_eq(game.ledger.money, money + Catalog.price_of("till") / 2)
	assert_null(game.till_station())
	assert_true(game.shop_items("", "Tools").any(func(bp: Dictionary) -> bool: return bp.id == "till"))

