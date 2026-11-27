extends GutTest
## EPIC-85: the chair's upgrade tree, and the seat pieces kept off sale (branches: test_seat_trees).


func test_chair_children_are_chair_2_and_fast_1():
	assert_eq(Upgrades.children("chair@1"), ["chair@2", "chair_fast@1"] as Array[String])


func test_chair_step_prices():
	assert_eq(Upgrades.price("chair@1"), 10)
	assert_eq(Upgrades.step_price("chair@2"), 10)


func test_chair_is_listed_in_dining_and_the_booth_seat_is_not():
	var ids := []
	for bp in Catalog.search("", "Dining"):
		ids.append(bp.id)
	assert_true(ids.has("chair"))
	assert_false(ids.has("booth_seat"))


func test_booth_seat_is_never_sold_in_the_shop():
	assert_true(Catalog.ITEMS.booth_seat.tree_only)
	assert_false(Catalog.sold_in("booth_seat", ""))
