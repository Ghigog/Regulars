extends "res://test/helpers/sim_case.gd"
## EPIC-132: every food box has a tree of two exclusive nodes, Prepared and Marinated.


func test_box_children_are_prepared_and_marinated():
	var kids := Upgrades.children("box_lettuce")
	assert_eq(kids, ["ready_lettuce", "marinated_lettuce"] as Array[String])
	for k in kids:
		assert_eq(Upgrades.level(k), 2)
		assert_eq(Upgrades.parent(k), "box_lettuce")
		assert_true(Upgrades.blurb(k).contains("$%d a night" % Pantry.box_fee(k)), "the blurb names the fee")
		assert_eq(Upgrades.jobs(k), {})
	assert_eq(Upgrades.step_price("ready_lettuce"), Pantry.PREPARED_PRICE)
	assert_eq(Upgrades.step_price("marinated_lettuce"), Pantry.MARINATE_PRICE)
	assert_true(Upgrades.has_tree("box_lettuce"))
	assert_eq(Upgrades.name_of("marinated_lettuce"), "Marinated lettuce")


func test_fees_and_exclusive_branches():
	assert_eq(Pantry.box_fee("box_cheese"), 3)
	assert_eq(Pantry.box_fee("ready_cheese"), roundi(3 * Pantry.READY_FEE))
	assert_eq(Pantry.box_fee("marinated_cheese"), roundi(3 * Pantry.MARINATE_FEE))
	assert_eq(Pantry.fee_of("cheese", true), Pantry.box_fee("ready_cheese"), "fee_of still works")
	assert_false(Upgrades.can_buy("ready_cheese", "marinated_cheese", 999, 9))
	assert_false(Upgrades.can_buy("marinated_cheese", "ready_cheese", 999, 9))
	assert_true(Upgrades.can_buy("box_cheese", "marinated_cheese", 999, 9))
	assert_eq(Pantry.station_ingredient("marinated_cheese"), {"id": "cheese", "ready": false, "marinated": true})


func test_marinate_bonus_is_clamped():
	assert_almost_eq(Prep.marinate(Prep.PLAIN), Prep.PLAIN + Pantry.MARINATE_BONUS, 0.0001)
	assert_eq(Prep.marinate(Prep.GOOD), 1.0)
	var d := Dish.make(Dish.PLATE)
	d.ings = ["patty", "cheese"] as Array[String]
	d.qs = [Prep.marinate(Prep.GOOD), Prep.marinate(Prep.GOOD)] as Array[float]
	assert_lte(d.quality(), 1.0)


func test_catalog_lists_nodes_not_tubs():
	var found := Catalog.search("", "Pantry", "diner")
	var ids: Array = found.map(func(bp: Dictionary) -> String: return bp.id)
	assert_true(ids.has("box_lettuce"))
	assert_true(ids.has("ready_lettuce") and ids.has("marinated_lettuce"))
	for bp in found:
		if Catalog.is_box_node(bp.id):
			assert_eq(bp.tree, bp.id)
			assert_eq(Catalog.bp_price(bp), Upgrades.price(bp.id))
	assert_eq(Upgrades.price("ready_lettuce"), Pantry.PREPARED_PRICE)
	assert_true(Catalog.ITEMS.has("ready_potato"), "potato has a chop step, so a Prepared node")
	for id in Pantry.ITEMS:
		if Pantry.is_drink(id) or Pantry.is_derived(id):
			assert_false(Catalog.ITEMS.has(Pantry.box_id(id, false, true)), "%s has no Marinated node" % id)
