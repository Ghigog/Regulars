extends GutTest
## EPIC-85: the chair's upgrade tree, and the seat pieces kept off sale.


func test_chair_children_are_chair_2_and_booth_seat_1():
	assert_eq(Upgrades.children("chair@1"), ["chair@2", "booth_seat@1"] as Array[String])


func test_booth_seat_parent_and_root():
	assert_eq(Upgrades.parent("booth_seat@1"), "chair@1")
	assert_eq(Upgrades.parent("booth_seat@2"), "booth_seat@1")
	assert_eq(Upgrades.children("booth_seat@1"), ["booth_seat@2"] as Array[String])
	for t in [1, 2, 3]:
		assert_eq(Upgrades.root("booth_seat@%d" % t), "chair@1")
	assert_eq(Upgrades.children("chair@2"), ["chair@3"] as Array[String])


func test_step_prices():
	assert_eq(Upgrades.price("chair@1"), 10)
	assert_eq(Upgrades.step_price("booth_seat@1"), 10)
	assert_eq(Upgrades.step_price("booth_seat@2"), 20)
	assert_eq(Upgrades.step_price("chair@2"), 10)


func test_layout_has_six_distinct_positions():
	var lay := Upgrades.layout("chair@1")
	assert_eq(lay.size(), 6)
	var seen := {}
	for k: String in lay:
		seen[lay[k]] = true
	assert_eq(seen.size(), 6)


func test_seat_pieces_are_not_listed_in_dining():
	var ids := []
	for bp in Catalog.search("", "Dining"):
		ids.append(bp.id)
	assert_false(ids.has("chair"))
	assert_false(ids.has("booth_seat"))


func test_booth_seat_is_never_sold_in_the_shop():
	assert_true(Catalog.ITEMS.booth_seat.tree_only)
	assert_false(Catalog.sold_in("booth_seat", ""))
