extends "res://test/helpers/game_case.gd"
## A food box's Prepared / Marinated tree (EPIC-132): the card, the buy, undo, the shop,
## the restock note and the save.

const CELL := Vector2i(8, 5)


func _stocked(box := "box_lettuce") -> void:
	_to_build()
	game.ledger.money = 900
	game.ledger.xp = 100000
	game.world.add_station("counter", CELL, 1, 0, "fridge")
	if box != "":
		assert_true(game.kitchen.store(CELL, box))


func _lift() -> void:
	assert_true(game.placing.pick_up(Grid.center(CELL), game.player))


func test_a_lifted_box_is_its_own_tree_key():
	_stocked()
	_lift()
	assert_eq(game.upgrades.hand_key(game.player), "box_lettuce")
	assert_eq(game.upgrades.strip_choices(game.player).size(), 2, "Prepared and Marinated")


func test_buying_prepared_remakes_the_box_in_its_slot_and_undo_restores_it():
	_stocked()
	var money: int = game.ledger.money
	game.shopper = game.player
	game.storing_cell = CELL
	game.card_layer = "base"
	game.card.card_act("box_tree", {"box": "box_lettuce"})
	assert_eq(game.upgrades.hand_key(game.player), "box_lettuce")
	assert_true(game.upgrades.buy_upgrade("ready_lettuce", game.player))
	assert_eq(game.player.hand.id, "ready_lettuce")
	assert_eq(game.ledger.money, money - Pantry.PREPARED_PRICE)
	assert_has(game.kitchen.stock(CELL), "ready_lettuce")
	assert_does_not_have(game.kitchen.stock(CELL), "box_lettuce")
	assert_false(game.upgrades.buy_upgrade("marinated_lettuce", game.player), "not from Prepared")
	game.player.hand = {}
	game.shopper = null
	assert_true(game.undo.undo(game.player))
	assert_has(game.kitchen.stock(CELL), "box_lettuce")
	assert_eq(game.ledger.money, money)


func test_buying_from_the_card_opens_the_tree_on_the_box():
	_stocked()
	game.shopper = game.player
	game.storing_cell = CELL
	game.card_layer = "base"
	var acts: Array = game.card.card_actions().filter(func(a: Dictionary) -> bool: return a.act == "box_tree")
	assert_eq(acts.size(), 1)
	assert_eq(Upgrades.children("box_lettuce"), ["ready_lettuce", "marinated_lettuce"])
	assert_gt(Pantry.box_fee("marinated_lettuce"), Pantry.box_fee("box_lettuce"))


func test_the_restock_note_names_the_node_and_its_fee():
	_stocked("marinated_patty")
	assert_has(game.kitchen.stock(CELL), "marinated_patty")
	var lines: Array = game.menu_stock.stock_lines().filter(func(l: Dictionary) -> bool: return l.name.contains("marinated"))
	assert_eq(lines.size(), 1)
	assert_eq(lines[0].fee, Pantry.box_fee("marinated_patty"))


func test_a_node_bought_outright_in_the_storage_card_is_stored_and_paid():
	_stocked("")
	game.shopper = game.player
	game.storing_cell = CELL
	game.card_layer = "base"
	var money: int = game.ledger.money
	assert_true(game.card._storage_buy(Catalog.tree_blueprint("ready_lettuce")))
	assert_has(game.kitchen.stock(CELL), "ready_lettuce")
	assert_eq(game.ledger.money, money - Upgrades.price("ready_lettuce"))


func test_saved_boxes_round_trip_in_their_slot():
	_stocked("ready_onion")
	assert_not_null(game.menu_stock.stock_box("patty", Vector2i(9, 5), false, 0, true))
	var data := SaveGame.capture(game)
	var other = load("res://game/main.tscn").instantiate()
	other._resume_data = data
	add_child_autofree(other)
	other.set_process(false)
	assert_has(other.kitchen.stock(CELL), "ready_onion")
	assert_has(other.kitchen.stock(Vector2i(9, 5)), "marinated_patty")
	assert_eq(Upgrades.parent("ready_onion"), "box_onion", "a Prepared node, bought")
	assert_eq(Upgrades.root(Pantry.box_id("onion", true)), "box_onion")


func test_the_tree_screen_draws_the_box_with_its_two_nodes():
	_stocked()
	game.shopper = game.player
	game.storing_cell = CELL
	game.card_layer = "base"
	assert_true(game.card.card_act("box_tree", {"box": "box_lettuce"}))
	var screen = game.hud._tree
	assert_not_null(screen)
	assert_eq(screen.cards.keys().size(), 3)
	assert_eq(screen.state_of("ready_lettuce"), "next")
	assert_eq(screen.state_of("marinated_lettuce"), "next")
