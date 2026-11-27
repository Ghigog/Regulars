extends GutTest
## EPIC-87: the chair and table trees branch into Fast and Comfortable.


func test_chair_1_branches_into_chair_2_and_fast_1():
	assert_eq(Upgrades.children("chair@1"), ["chair@2", "chair_fast@1"] as Array[String])


func test_the_comfortable_line_ends_in_the_booth_seat_and_the_fast_line_in_fast_2():
	assert_eq(Upgrades.children("chair@3"), ["booth_seat@1"] as Array[String])
	assert_eq(Upgrades.parent("booth_seat@1"), "chair@3")
	assert_eq(Upgrades.children("booth_seat@1"), [] as Array[String])
	assert_eq(Upgrades.children("chair_fast@1"), ["chair_fast@2"] as Array[String])
	assert_eq(Upgrades.parent("chair_fast@1"), "chair@1")
	assert_eq(Upgrades.root("chair_fast@2"), "chair@1")
	assert_eq(Upgrades.root("booth_seat@1"), "chair@1")


func test_table_1_branches_into_a_fast_and_a_comfortable_table():
	var kids := Upgrades.children("table@1")
	assert_eq(kids.size(), 2)
	assert_true(kids.has("table_fast@1") and kids.has("table_comfy@1"))
	for k in kids:
		assert_eq(Upgrades.parent(k), "table@1")
		assert_eq(Upgrades.children(k), [] as Array[String])


func test_seat_path_and_steps():
	assert_eq([Upgrades.seat_path("chair_fast@2"), Upgrades.seat_steps("chair_fast@2")], ["fast", 2])
	assert_eq([Upgrades.seat_path("booth_seat@1"), Upgrades.seat_steps("booth_seat@1")], ["comfortable", 3])
	assert_eq([Upgrades.seat_path("chair@1"), Upgrades.seat_steps("chair@1")], ["", 0])
	assert_eq([Upgrades.seat_path("chair@3"), Upgrades.seat_steps("chair@3")], ["comfortable", 2])
	assert_eq([Upgrades.seat_path("table_fast@1"), Upgrades.seat_steps("table_fast@1")], ["fast", 1])
	assert_eq([Upgrades.seat_path("table_comfy@1"), Upgrades.seat_steps("table_comfy@1")], ["comfortable", 1])
	assert_eq(Upgrades.seat_path("table@1"), "")


func test_chair_2_owned_cannot_buy_fast_1():
	assert_false(Upgrades.can_buy("chair@2", "chair_fast@1", 1000, 10))
	assert_true(Upgrades.can_buy("chair@1", "chair_fast@1", 1000, 10))


func test_step_prices():
	assert_eq(Upgrades.step_price("chair_fast@1"), 10)
	assert_eq(Upgrades.step_price("chair_fast@2"), 20)
	assert_eq(Upgrades.step_price("booth_seat@1"), 20)
	assert_gt(Upgrades.step_price("table_fast@1"), 0)
	assert_gt(Upgrades.step_price("table_comfy@1"), 0)


func test_blurbs_say_the_effect_in_plain_words():
	for k in ["chair_fast@1", "table_fast@1"]:
		assert_eq(Upgrades.blurb(k), "Guests order and eat faster, tip less, and mind mess and waiting more")
	for k in ["chair@2", "table_comfy@1"]:
		assert_string_contains(Upgrades.blurb(k), "eat more slowly, tip more, and mind mess and waiting less")
	assert_string_contains(Upgrades.blurb("booth_seat@1"), "cosiest")


func test_names():
	assert_eq(Upgrades.name_of("chair_fast@2"), "Fast 2")
	assert_eq(Upgrades.name_of("chair@3"), "Chair 3")
	assert_eq(Upgrades.name_of("booth_seat@1"), "Booth seat")


func test_layouts_place_every_node_apart():
	for root in ["chair@1", "table@1"]:
		var lay := Upgrades.layout(root)
		var seen := {}
		for k: String in lay:
			seen[lay[k]] = true
		assert_eq(seen.size(), lay.size())
	assert_eq(Upgrades.layout("chair@1").size(), 6)
	assert_eq(Upgrades.layout("table@1").size(), 3)
	assert_eq(Upgrades.extent(Upgrades.layout("chair@1")).x, 4)


func test_the_seating_branches_are_never_sold_in_the_shop():
	for id in ["chair_fast", "booth_seat", "table_fast", "table_comfy"]:
		assert_false(Catalog.sold_in(id, ""), id)
