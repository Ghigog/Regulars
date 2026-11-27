extends "res://test/helpers/sim_case.gd"


func test_outer_walls_follow_the_edge_of_the_floor():
	var p := _plan()
	assert_eq(p.walls().size(), 8, "a 2 x 2 floor has 8 lengths of wall round it")
	assert_false(p.is_wall(Vector3i(1, 0, 1)), "none inside")
	assert_true(p.is_wall(Vector3i(0, 0, 0)))
	var gone := p.lay(Vector2i(2, 0), "tile")
	assert_true(gone.is_empty())
	assert_false(p.is_wall(Vector3i(2, 0, 1)), "the wall between old and new floor comes down")
	assert_true(p.is_wall(Vector3i(3, 0, 1)), "and goes up round the new edge")



func test_floor_must_touch_the_room_and_stay_on_the_lot():
	var p := _plan()
	assert_false(p.can_lay(Vector2i(4, 4), "tile"), "not floating on its own")
	assert_true(p.can_lay(Vector2i(2, 1), "tile"))
	assert_false(p.can_lay(Vector2i(0, 0), "planks"), "already planks")
	assert_true(p.can_lay(Vector2i(0, 0), "tile"), "but can be re-laid as tile")
	assert_false(p.can_lay(Vector2i(-4, 0), "tile"), "off the lot")
	var order := p.lay_order(Floorplan.rect_cells(Vector2i(5, 0), Vector2i(2, 0)), "tile")
	assert_eq(order, [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)] as Array[Vector2i],
		"a dragged strip is laid outward from the room")



func test_built_walls_and_openings():
	var p := _plan()
	assert_true(p.can_build(Vector3i(1, 0, 1)), "between two floors")
	assert_false(p.can_build(Vector3i(0, 0, 0)), "not on the outline")
	p.build(Vector3i(1, 0, 1))
	assert_true(p.is_wall(Vector3i(1, 0, 1)))
	assert_true(p.can_open(Vector3i(1, 0, 1), "door"))
	assert_true(p.can_open(Vector3i(0, 0, 0), "arch"), "an outer wall can take one, for floor laid later")
	assert_false(p.can_open(Vector3i(1, 1, 1), "door"), "no wall there")
	p.openings[Vector3i(0, 0, 0)] = "arch"
	assert_false(p.opening_has_floor(Vector3i(0, 0, 0)), "bare ground behind it")
	p.openings[Vector3i(1, 0, 1)] = "arch"
	assert_true(p.opening_has_floor(Vector3i(1, 0, 1)))
	assert_eq(p.unbuild(Vector3i(1, 0, 1)), "arch", "taking the wall down takes its archway")
	p.openings[Vector3i(1, 0, 0)] = "door"
	assert_eq(p.lay(Vector2i(1, -1), "planks"), {Vector3i(1, 0, 0): "door"}, "a door in an outer wall goes when floor is laid past it")
	p.build(Vector3i(1, 0, 1))
	p.lift(Vector2i(0, 0))
	assert_false(p.built.has(Vector3i(1, 0, 1)), "a built wall goes with the floor beside it")
	assert_eq(Floorplan.line(Vector2i(0, 2), Vector2i(3, 2)), [Vector3i(0, 2, 0), Vector3i(1, 2, 0), Vector3i(2, 2, 0)] as Array[Vector3i])
	assert_eq(Floorplan.line(Vector2i(1, 3), Vector2i(1, 1)), [Vector3i(1, 1, 1), Vector3i(1, 2, 1)] as Array[Vector3i])



func test_doors_let_people_through_but_not_their_gaze():
	var g := Grid.new(3, 1, Vector2i(-1, 0))
	assert_true(g.in_bounds(Vector2i(-1, 0)), "a grid can start below zero")
	g.doors[Vector3i(0, 0, 1)] = true
	assert_true(g.reachable(Vector2i(-1, 0), Vector2i(1, 0)))
	assert_false(g.has_los(Vector2i(-1, 0), Vector2i(1, 0)))
	g.outside[Vector2i(0, 0)] = true
	assert_false(g.reachable(Vector2i(-1, 0), Vector2i(1, 0)), "nobody walks on bare ground")



func test_walls_take_one_finish_that_goes_with_the_wall():
	var p := _plan()
	var back := Vector3i(0, 0, 0)            # the north edge of the floor: an outer wall
	assert_true(p.can_finish(back, "paint"))
	assert_false(p.can_finish(Vector3i(1, 0, 1), "paint"), "no wall between two floors")
	assert_false(p.can_finish(back, "glitter"), "only real finishes")
	assert_eq(p.finish(back, "paint"), "")
	assert_false(p.can_finish(back, "paint"), "already painted")
	assert_eq(p.finish(back, "paper_rose"), "paint", "papering over paint hands the paint back")
	var gone := p.lay(Vector2i(0, -1), "planks")
	assert_eq(gone.get(back, ""), "paper_rose", "the wall came down, and its paper with it")
	assert_false(p.finishes.has(back))
	p.openings[Vector3i(0, 0, 1)] = "door"
	assert_false(p.can_finish(Vector3i(0, 0, 1), "paint"), "not across a doorway")
	p.finish(Vector3i(0, 1, 1), "paint")
	assert_eq(p.strip(Vector3i(0, 1, 1)), "paint")
	assert_eq(p.strip(Vector3i(0, 1, 1)), "")



func test_nicer_finishes_cost_more_need_a_level_and_give_more_joy():
	assert_true(Floorplan.KINDS.has("parquet") and Floorplan.KINDS.has("marble"))
	for id in Floorplan.FINISHES:
		assert_true(Catalog.is_finish(id) and Catalog.is_build_tool(id))
	assert_false(Catalog.is_finish("wall"))
	for pair: Array in [["floor_planks", "floor_parquet"], ["floor_parquet", "floor_marble"], ["paint", "paper_stripe"], ["paper_stripe", "paper_rose"]]:
		assert_lt(Catalog.price_of(pair[0]), Catalog.price_of(pair[1]))
		assert_lt(Catalog.level_of(pair[0]), Catalog.level_of(pair[1]))
		assert_lt(Catalog.joy_of(pair[0]), Catalog.joy_of(pair[1]))
	assert_eq(Catalog.joy_of("floor_tile"), 0.0, "plain floors do nothing")
	assert_almost_eq(Catalog.joy_of("plant", 3) - Catalog.joy_of("plant"), 2 * Catalog.TIER_JOY, 0.0001)



# ---------------------------------------------------------------- decor

func test_decor_gives_most_on_it_less_beside_and_least_in_view():
	assert_eq(Decor.band(0), Decor.ON)
	assert_eq(Decor.band(1), Decor.BESIDE)
	assert_eq(Decor.band(Decor.VIEW_RANGE), Decor.IN_VIEW)
	assert_eq(Decor.band(Decor.VIEW_RANGE + 1), 0.0, "out of sight range")
	var rug := Catalog.joy_of("rug")
	var on: float = Decor.bonus([{"id": "rug", "dist": 0}]).joy
	var beside: float = Decor.bonus([{"id": "rug", "dist": 1}]).joy
	var seen: float = Decor.bonus([{"id": "rug", "dist": 3}]).joy
	assert_almost_eq(on, rug, 0.0001)
	assert_almost_eq(beside, rug * Decor.BESIDE, 0.0001)
	assert_almost_eq(seen, rug * Decor.IN_VIEW, 0.0001)
	assert_gt(on, beside)
	assert_gt(beside, seen)
	assert_eq(Decor.bonus([]).joy, 0.0)
	assert_eq(Decor.bonus([]).best, "")



func test_decor_sight_is_the_nearest_cell_in_reach_and_view():
	var g := Grid.new(6, 3)
	var seat := Vector2i(0, 1)
	assert_eq(Decor.nearest(g, seat, [Vector2i(3, 1), Vector2i(2, 2)], 3), 2, "the nearest cell counts")
	assert_eq(Decor.nearest(g, seat, [Vector2i(4, 1)], 3), -1, "out of reach")
	assert_eq(Decor.nearest(g, seat, [seat], 3), 0, "under the seat")
	g.walls[Vector3i(1, 0, 1)] = true
	g.walls[Vector3i(1, 1, 1)] = true
	g.walls[Vector3i(1, 2, 1)] = true
	assert_eq(Decor.nearest(g, seat, [Vector2i(2, 1)], 3), -1, "a partition blocks it")
	assert_eq(Decor.share("floor_marble", 0), Decor.ON)
	assert_eq(Decor.share("paint", 0), Decor.BESIDE, "nobody sits on a wall")
	assert_eq(Decor.share("rug", 2), Decor.IN_VIEW)
	assert_eq(Decor.share("rug", -1), 0.0)
	assert_eq(Decor.share("plant", 4, 2), Decor.IN_VIEW, "a better fern is seen further")



func test_decor_marks_have_four_levels_and_a_full_flag():
	assert_eq(Decor.mark(Decor.ON), Decor.MARK_ON)
	assert_eq(Decor.mark(Decor.BESIDE), Decor.MARK_BESIDE)
	assert_eq(Decor.mark(Decor.IN_VIEW), Decor.MARK_VIEW)
	assert_eq(Decor.mark(0.0), Decor.MARK_NONE)
	assert_true(Decor.is_full([{"id": "rug", "dist": 0}, {"id": "floor_marble", "dist": 0}]), "0.15 + 0.2 is the cap")
	assert_false(Decor.is_full([{"id": "rug", "dist": 0}]))



func test_a_wall_finish_only_cheers_its_own_side():
	var p := Floorplan.new(Rect2i(0, 0, 5, 5))
	p.fill(Rect2i(0, 0, 5, 2), "tile")
	var outer := Vector3i(2, 0, 0)            # the north wall of (2, 0): only floor on one side
	assert_eq(Decor.finish_cells(p, [outer]), [Vector2i(2, 0)] as Array[Vector2i])
	var inner := Vector3i(2, 1, 0)            # between (2, 1) and (2, 0)
	assert_eq(Decor.finish_cells(p, [inner]).size(), 2)
	var g := Grid.new(5, 2)
	var seat := Vector2i(2, 1)
	assert_eq(Decor.share_from(g, seat, "paint", Decor.finish_cells(p, [outer])), Decor.BESIDE)
	for x in 5:
		g.walls[Vector3i(x, 1, 0)] = true      # a wall between the rows
	assert_eq(Decor.share_from(g, seat, "paint", Decor.finish_cells(p, [outer])), 0.0,
		"the far room's painted wall is not seen through the wall")



func test_decor_counts_each_kind_once_and_kinds_stack_to_a_cap():
	var two_rugs: float = Decor.bonus([{"id": "rug", "dist": 0}, {"id": "rug", "dist": 1}, {"id": "rug", "dist": 2}]).joy
	assert_almost_eq(two_rugs, Catalog.joy_of("rug"), 0.0001, "the best of a kind, not the sum")
	var b := Decor.bonus([{"id": "rug", "dist": 0}, {"id": "paint", "dist": 1}])
	assert_almost_eq(b.joy, Catalog.joy_of("rug") + Catalog.joy_of("paint") * Decor.BESIDE, 0.0001)
	assert_eq(b.best, "rug")
	var lavish := Decor.bonus([{"id": "rug", "dist": 0}, {"id": "floor_marble", "dist": 0},
		{"id": "paper_rose", "dist": 1}, {"id": "plant", "tier": 3, "dist": 1}])
	assert_eq(lavish.joy, Decor.CAP)
	assert_eq(Decor.thought(lavish.best), "What a fine floor")



func test_nobody_sits_on_a_wall_or_a_fern():
	assert_almost_eq(Decor.bonus([{"id": "paper_rose", "dist": 0}]).joy, Catalog.joy_of("paper_rose") * Decor.BESIDE, 0.0001)
	assert_almost_eq(Decor.bonus([{"id": "plant", "dist": 0}]).joy, Catalog.joy_of("plant") * Decor.BESIDE, 0.0001)



func test_a_better_fern_is_seen_from_further_and_gives_more():
	assert_eq(Decor.reach("plant", 1), 3)
	assert_eq(Decor.reach("plant", 3), 5)
	assert_eq(Decor.bonus([{"id": "plant", "tier": 1, "dist": 5}]).joy, 0.0)
	assert_gt(Decor.bonus([{"id": "plant", "tier": 3, "dist": 5}]).joy, 0.0)
	assert_gt(Decor.bonus([{"id": "plant", "tier": 2, "dist": 1}]).joy, Decor.bonus([{"id": "plant", "tier": 1, "dist": 1}]).joy)



func test_a_nicely_dressed_table_is_worth_what_a_fern_once_was():
	# A fern used to add 0.015 joy a second; a guest sits for some 20 seconds.
	var dressed: float = Decor.bonus([{"id": "rug", "dist": 0}, {"id": "floor_parquet", "dist": 0},
		{"id": "plant", "dist": 1}]).joy
	assert_between(dressed, 0.25, Decor.CAP)
	assert_lt(Decor.bonus([{"id": "plant", "dist": 3}, {"id": "paint", "dist": 3}]).joy, 0.1, "what is only seen adds a little")



func test_comfort_rises_with_joy_and_patience_and_falls_with_disgust():
	var m := GuestMood.new()
	m.joy = 0.0
	m.patience = 0.0
	assert_eq(m.comfort(), 0.0)
	m.joy = 1.0
	m.patience = 1.0
	m.savour = 1.0
	assert_almost_eq(m.comfort(), 1.0, 0.0001)
	m.savour = 0.0
	m.joy = 0.5
	var base := m.comfort()
	m.joy = 0.6
	assert_gt(m.comfort(), base)
	m.patience = 0.5
	assert_lt(m.comfort(), base + 0.1)
	var before := m.comfort()
	m.disgust = 0.5
	assert_lt(m.comfort(), before)
	m.disgust = 1.0
	assert_eq(m.comfort(), 0.0, "never below 0")
	m.disgust = 0.0
	var plain := m.comfort()
	m.savour = 1.0
	assert_gt(m.comfort(), plain, "one score: the dish counts too")
	assert_almost_eq(m.comfort(), m.satisfaction() / GuestMood.HAPPY_FULL, 0.0001)



func test_bill_and_stay_scales_hit_their_ends_and_only_rise():
	assert_almost_eq(GuestMood.bill_scale(0.0), GuestMood.BILL_LOW, 0.0001)
	assert_almost_eq(GuestMood.bill_scale(1.0), GuestMood.BILL_HIGH, 0.0001)
	assert_almost_eq(GuestMood.stay_scale(0.0), GuestMood.STAY_LOW, 0.0001)
	assert_almost_eq(GuestMood.stay_scale(1.0), GuestMood.STAY_HIGH, 0.0001)
	for i in 10:
		assert_lt(GuestMood.bill_scale(i / 10.0), GuestMood.bill_scale((i + 1) / 10.0))
		assert_lt(GuestMood.stay_scale(i / 10.0), GuestMood.stay_scale((i + 1) / 10.0))



func test_comfort_is_fixed_when_the_food_arrives():
	var m := GuestMood.new()
	m.joy = 1.0
	m.patience = 1.0
	m.savour = 1.0
	assert_eq(m.settle_comfort(), GuestMood.COSY_THOUGHTS[0])
	m.joy = 0.0
	m.patience = 0.0
	m.savour = 0.0
	assert_almost_eq(m.served_comfort, 1.0, 0.0001, "the bill and the stay agree")
	assert_eq(m.scaled_price(12), 15)
	assert_eq(m.settle_comfort(4), GuestMood.HURRIED_THOUGHTS[1])
	assert_eq(m.scaled_price(12), 11)
	assert_eq(m.scaled_price(1), 1, "never below 1")
	m.joy = 0.5
	m.patience = 0.5
	m.savour = 0.5
	assert_eq(m.settle_comfort(), "", "nothing to say in the middle")



func test_deals_apply_after_the_mood_scale():
	var m := GuestMood.new()
	m.joy = 1.0
	m.patience = 1.0
	m.savour = 1.0
	m.settle_comfort()
	assert_eq(m.pay_for(12), 15)
	assert_true(m.paid_full())
	m.discounted = true
	assert_eq(m.pay_for(12), 8, "half of 15, in the house's favour")
	assert_false(m.paid_full())
	m.comped = true
	assert_eq(m.pay_for(12), 0)
	assert_eq(m.tip_for(m.pay_for(12)), 0, "the tip is on the final bill")



func test_a_guest_who_expects_a_deal_is_let_down_even_when_the_bill_moved():
	var t := Town.new()
	t.people[0].deals = Town.EXPECT_AT
	var m := GuestMood.new()
	m.joy = 0.0
	m.patience = 0.2
	m.settle_comfort()
	assert_ne(m.pay_for(12), 12, "the scaled bill is not the base price")
	assert_true(m.paid_full(), "but it is still full price")
	assert_gt(t.paid_full_price(0) if m.paid_full() else 0.0, 0.0)



# ---------- Cleaning (night cleaning, PRD 5) ----------

func test_cleaning_knows_what_is_still_dirty():
	assert_true(Cleaning.needs_cleaning("table", 1, 0))
	assert_false(Cleaning.needs_cleaning("table", 0, 0))
	assert_true(Cleaning.needs_cleaning("sink", 1, 0), "one plate soaking still needs washing")
	assert_true(Cleaning.needs_cleaning("bin", 0, 1))
	assert_false(Cleaning.needs_cleaning("bin", 0, 0))
	assert_false(Cleaning.needs_cleaning("stove", 3, 3), "only tables, sinks and bins get dirty")



func test_cleaning_names_the_night_actions_and_nothing_else():
	assert_eq(Cleaning.night_action("Clear plates"), "Clear table")
	assert_eq(Cleaning.night_action("Wash"), "Wash up")
	assert_eq(Cleaning.night_action("Empty bin"), "Take the bag out")
	assert_eq(Cleaning.night_action("Put in sink"), "Put in sink")
	assert_eq(Cleaning.night_action("Take meat"), "", "no cooking at night")
	assert_eq(Cleaning.night_action("Scrape off"), "")



func test_cleaning_carried_mess_is_a_plate_or_the_bag():
	assert_true(Cleaning.carrying_mess("dirty_dishes"))
	assert_false(Cleaning.carrying_mess("dishes"))
	assert_true(Cleaning.carrying_mess("rubbish_bag"))
	assert_false(Cleaning.carrying_mess(""))
	assert_false(Cleaning.carrying_mess("plate"))



func test_mess_ages_in_service_only():
	assert_eq(Cleaning.aged(2.0, 1.0, true, true), 3.0)
	assert_eq(Cleaning.aged(2.0, 1.0, true, false), 2.0 if not Cleaning.AGES_AT_NIGHT else 3.0)
	assert_eq(Cleaning.aged(2.0, 1.0, false, true), 0.0, "clean is back to zero")
	assert_eq(Cleaning.aged(2.0, 1.0, false, false), 0.0)



func test_every_ingredient_has_its_fields():
	for id: String in Pantry.ITEMS:
		var it: Dictionary = Pantry.ITEMS[id]
		for key in ["name", "theme", "tool", "tags", "worth", "fee", "colour", "prepped", "shape"]:
			assert_true(it.has(key), "%s has %s" % [id, key])
		assert_true(Pantry.TOOLS.has(it.tool), "%s's tool is one of the twelve" % id)
		assert_true(Pantry.THEMES.has(it.theme))
		if it.tool == "pour":
			assert_true(Pantry.is_drink(id), "only drinks are poured")
		if Pantry.is_drink(id):
			assert_has(["pour", "juice", "blend"], it.tool, "a drink is poured, juiced or blended (PRD 8.6)")
	assert_eq(Pantry.TOOLS.size(), 12, "the seven, and grate, saw, juice, blend and steam (PRD 8.6)")



## The seaside list from the PRD: tool, tags, worth and fee as in the table.
func test_seaside_ingredients_are_complete():
	var table := {
		"roll": ["none", ["bread"], 2, 3], "fish": ["grill", ["fish"], 7, 9],
		"calamari": ["fry", ["fish", "fried"], 5, 6], "lemon": ["slice", ["fruit"], 1, 2],
		"courgette": ["chop", ["vegetable"], 2, 2], "pepper": ["chop", ["vegetable"], 2, 2],
		"new_potato": ["boil", ["vegetable"], 3, 3], "beans": ["boil", ["vegetable"], 2, 2],
		"wine": ["pour", ["drink"], 5, 5],
	}
	assert_eq(Pantry.for_theme("seaside").size(), table.size() + 7, "and the seven of PRD 8.6")
	for id: String in table:
		var row: Array = table[id]
		var it: Dictionary = Pantry.ITEMS[id]
		assert_eq(it.theme, "seaside")
		assert_eq(it.tool, row[0], "%s's tool" % id)
		assert_eq(it.tags, row[1], "%s's tags" % id)
		assert_eq(it.worth, row[2], "%s's worth" % id)
		assert_eq(it.fee, row[3], "%s's fee" % id)
		assert_true(Pantry.TOOLS.has(it.tool), "%s's tool is one of the seven" % id)
		if Pantry.needs_prep(id):
			var tool_station: String = Pantry.TOOL_STATION[it.tool]
			assert_true(Catalog.ITEMS.has(tool_station), "%s's tool is sold" % id)
			assert_eq(Catalog.tool_of(tool_station), it.tool)
			assert_false(Catalog.ITEMS[tool_station].has("theme"), "tools are sold to both themes")
		var crate := "wine_barrel" if Pantry.is_drink(id) else Pantry.box_id(id)
		assert_true(Catalog.ITEMS.has(crate), "%s has a station" % id)
		assert_eq(Catalog.ITEMS[crate].theme, "seaside")
		assert_eq(Catalog.ingredient_of(crate), id)
		assert_eq(Catalog.ITEMS.has(Pantry.box_id(id, true)), Pantry.can_be_ready(id),
			"%s is sold ready-made only if it is on the list" % id)
	assert_eq(Catalog.tool_of("wine_barrel"), "pour", "wine is poured at its own barrel")
	for id in ["courgette", "pepper"]:
		assert_eq(Catalog.ITEMS[Pantry.box_id(id, true)].theme, "seaside")
	assert_false(Pantry.can_be_ready("lemon"), "only the chopped ones and cheese come ready-made")



func test_every_theme_has_all_three_courses():
	for theme in Pantry.THEMES:
		var ings := Pantry.for_theme(theme)
		assert_true(ings.any(func(i: String) -> bool: return Pantry.is_drink(i)), "%s has a drink" % theme)
		assert_gt(ings.filter(func(i: String) -> bool: return not Pantry.is_drink(i)).size(), 3)



func test_price_is_worth_times_level():
	var burger := {"ingredients": ["bun", "patty", "cheese"], "price_level": "fair"}
	assert_almost_eq(float(Menu.price_of(burger)), 12.0, 2.0, "a plain cheeseburger is about the old 12")
	assert_eq(Menu.price_of(burger), 10)
	burger.price_level = "cheap"
	assert_eq(Menu.price_of(burger), 8)
	burger.price_level = "dear"
	assert_eq(Menu.price_of(burger), 13, "12.5 rounds up")
	assert_eq(Menu.price_of({"ingredients": ["lettuce"], "price_level": "cheap"}), 1, "never below 1")



func test_night_cost_sums_stocked_fees():
	assert_eq(Menu.night_cost(_stations(["bun", "patty"])), 11)
	assert_eq(Menu.night_cost(_stations(["bun", "patty"], [], ["patty"])), 3, "an unstocked station costs nothing")
	assert_eq(Menu.night_cost(_stations(["cheese"], ["cheese"])), 5, "ready-made at 1.5 times, rounded")
	assert_eq(Menu.night_cost([]), 0)



func test_item_off_menu_without_stock_or_tool():
	var item := {"ingredients": ["bun", "patty"], "off": false}
	assert_eq(Menu.off_reason(item, _stations(["bun", "patty"]), ["grill"]), "")
	assert_eq(Menu.off_reason(item, _stations(["bun", "patty"]), []), "No grill")
	assert_eq(Menu.off_reason(item, _stations(["bun"]), ["grill"]), "No patty")
	assert_eq(Menu.off_reason(item, _stations(["bun", "patty"], [], ["patty"]), ["grill"]), "Patty not stocked")
	var salad := {"ingredients": ["lettuce"], "off": false}
	assert_eq(Menu.off_reason(salad, _stations(["lettuce"]), []), "No chopping board")
	assert_eq(Menu.off_reason(salad, _stations(["lettuce"], ["lettuce"]), []), "", "ready-made needs no tool")
	item.off = true
	assert_eq(Menu.off_reason(item, _stations(["bun", "patty"]), ["grill"]), "Off tonight")



func test_course_rules():
	assert_ne(Menu.refusal("drink", ["soda", "lettuce"]), "", "a drink with a non-drink is refused")
	assert_ne(Menu.refusal("main", ["soda"]), "", "a drink is not a main")
	assert_eq(Menu.refusal("main", ["cheese"]), "", "a one-ingredient main is fine")
	assert_eq(Menu.refusal("main", ["bun", "patty", "patty", "cheese", "onion", "bun"]), "")
	assert_ne(Menu.refusal("main", ["bun", "patty", "patty", "cheese", "onion", "tomato", "bun"]), "", "more than 6 is refused")
	var m := Menu.new()
	assert_true(m.add("drink", ["soda", "bun"]).is_empty())
	assert_false(m.add("main", ["bun", "patty", "patty"]).is_empty(), "the same ingredient twice is a double")



func test_new_item_gets_a_default_name():
	var m := Menu.new()
	assert_eq(m.add("main", ["bun", "patty", "cheese"]).name, "Cheese Patty Bun")
	assert_eq(m.add("side", ["potato"]).name, "Fries")
	var it := m.add("main", ["patty"], "   ")
	assert_eq(it.name, "Patty")
	m.rename(it.id, "A very long name for a burger indeed")
	assert_eq(m.find(it.id).name.length(), Menu.MAX_NAME)



func test_tastes_obey_the_limits():
	for s in [1, 2, 7, 42, 1234]:
		for theme in Pantry.THEMES:
			var t := Town.new(s)
			t.make_tastes(theme)
			var ings := Pantry.for_theme(theme)
			var haters := {}
			for p in t.people:
				assert_lte((p.dislikes as Array).size(), floori(ings.size() / 3.0), "nobody dislikes over a third")
				var staple := false
				for ing: String in p.likes:
					assert_false((p.dislikes as Array).has(ing), "never likes and dislikes one thing")
					staple = staple or Pantry.tool_of(ing) == "grill" or Pantry.tags_of(ing).has("vegetable")
				assert_true(staple, "%s likes a grill ingredient or vegetable" % p.name)
				for ing: String in p.dislikes:
					haters[ing] = int(haters.get(ing, 0)) + 1
			for ing in haters:
				assert_lte(int(haters[ing]), floori(t.people.size() / 5.0), "%s disliked by at most a fifth" % ing)



func test_tastes_are_the_same_for_a_seed():
	var a := Town.new(9)
	var b := Town.new(9)
	for i in a.people.size():
		assert_eq(a.people[i].likes, b.people[i].likes)
		assert_eq(a.people[i].dislikes, b.people[i].dislikes)
	var c := Town.new(10)
	var same := true
	for i in a.people.size():
		same = same and a.people[i].likes == c.people[i].likes
	assert_false(same, "a different seed, different tastes")



func test_tastes_leave_visits_alone():
	var a := Town.new(3)
	a.make_tastes("seaside")
	var b := Town.new(3)
	assert_eq(a.roll_guests(1), b.roll_guests(1), "taste rolls do not use the town's own generator")



func test_order_never_has_a_disliked_ingredient():
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var items := _menu_items()
	for k in 200:
		var o := Menu.order(items, [], ["patty"], rng)
		assert_eq(o.main.ingredients, ["lettuce", "tomato"])
	assert_true(Menu.order(items, [], ["patty", "lettuce"], rng).main.is_empty(), "no acceptable main")



func test_side_and_drink_need_a_liked_ingredient():
	var rng := RandomNumberGenerator.new()
	var items := _menu_items()
	for k in 50:
		var o := Menu.order(items, [], [], rng)
		assert_true(o.side.is_empty() and o.drink.is_empty(), "neutral sides and drinks are not added")
	for k in 50:
		var o := Menu.order(items, ["potato", "soda"], [], rng)
		assert_eq(o.side.ingredients, ["potato"])
		assert_eq(o.drink.ingredients, ["soda"])



func test_cheap_is_ordered_more_than_dear():
	var m := Menu.new()
	var cheap := m.add("main", ["bun", "patty"], "Cheap", "cheap")
	m.add("main", ["bun", "patty"], "Dear", "dear")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := 0
	for k in 1000:
		if Menu.order(m.items, [], [], rng).main.id == cheap.id:
			n += 1
	assert_gt(n, 600, "1.5 against 0.6 is about 71%")



func test_group_walks_on_only_when_nobody_has_a_main():
	var rng := RandomNumberGenerator.new()
	var items := _menu_items()
	var picky := {"likes": [], "dislikes": ["patty", "lettuce"]}
	var easy := {"likes": [], "dislikes": []}
	var g := Menu.group_order(items, [picky, easy], rng)
	assert_false(g.walk, "the group stays")
	assert_eq(g.found_nothing, [0])
	assert_eq(g.orders[0].drink.ingredients, ["soda"], "the picky one just has a drink, even a neutral one")
	assert_true(g.orders[0].main.is_empty())
	var alone := Menu.group_order(items, [picky], rng)
	assert_true(alone.walk, "on their own they walk on")
	var no_soda := {"likes": [], "dislikes": ["patty", "lettuce", "soda"]}
	var g2 := Menu.group_order(items, [no_soda, easy], rng)
	assert_false(g2.walk)
	assert_true(g2.orders[0].drink.is_empty(), "sits with nothing")
	assert_true(Menu.group_order(items, [picky, picky], rng).walk)
	assert_eq(g.went_along, [], "a pair never goes along")


func test_a_picky_member_of_three_usually_goes_along():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var items := _menu_items()
	var picky := {"likes": [], "dislikes": ["patty", "lettuce"]}
	var easy := {"likes": [], "dislikes": []}
	var only_one := 0
	for i in 1000:
		var g := Menu.group_order(items, [easy, picky, picky], rng)
		assert_false(g.walk)
		var mains := 0
		for k in 3:
			if not g.orders[k].main.is_empty():
				mains += 1
		if mains == 1:
			only_one += 1
		for k: int in g.went_along:
			assert_false(g.found_nothing.has(k))
			var fewest := 99
			for it: Dictionary in items:
				if it.course == "main":
					fewest = mini(fewest, it.ingredients.filter(func(x): return picky.dislikes.has(x)).size())
			assert_eq(g.orders[k].main.ingredients.filter(func(x): return picky.dislikes.has(x)).size(), fewest)
	var limit := (1.0 - Menu.GO_ALONG_CHANCE) * (1.0 - Menu.GO_ALONG_CHANCE) + 0.05
	assert_lte(only_one / 1000.0, limit)
	assert_true(Menu.group_order(items, [picky, picky, picky], rng).walk, "all picky: still walks")


func test_nobody_goes_along_when_two_found_a_main():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var items := _menu_items()
	var picky := {"likes": [], "dislikes": ["patty", "lettuce"]}
	var easy := {"likes": [], "dislikes": []}
	for i in 50:
		var g := Menu.group_order(items, [easy, easy, picky], rng)
		assert_eq(g.went_along, [])
		assert_eq(g.found_nothing, [2])



func test_savour_is_average_plus_capped_liked_bonus():
	assert_almost_eq(Menu.savour([1.0, 0.5], ["bun", "patty"], []), 0.75, 0.001)
	assert_almost_eq(Menu.savour([0.75], ["patty"], ["patty"]), 0.85, 0.001)
	assert_almost_eq(Menu.savour([0.5, 0.5, 0.5, 0.5], ["bun", "patty", "cheese", "onion"],
		["bun", "patty", "cheese", "onion"]), 0.8, 0.001, "liked bonus caps at +0.3")



func test_order_counts_survive_a_rename():
	var t := Town.new(1)
	var m := Menu.new()
	var a := m.add("main", ["bun", "patty"], "Burger")
	var b := m.add("side", ["potato"], "Fries")
	t.record_order(0, a.id)
	t.record_order(0, b.id)
	t.record_order(0, a.id)
	m.rename(a.id, "Stupid Burger")
	assert_eq(t.order_summary(0, m), "Stupid Burger x2, Fries x1")
	m.remove(b.id)
	assert_eq(t.order_summary(0, m), "Stupid Burger x2, Fries x1", "a deleted item keeps its last name")



func test_taste_hints_never_name_an_ingredient():
	assert_eq(Menu.hint_thought("vegetable"), "So many things with vegetables. I love vegetables!")
	assert_eq(Town.praise_about(true, "vegetable"), "it was just how they like it")
	assert_eq(Town.praise_about(false, "vegetable"), "about all the things with vegetables")
	assert_eq(Town.praise_about(false, ""), "")
	var t := Town.new(1)
	var line := t.gossip_line(0, 0.2, Town.praise_about(true, ""))
	assert_true(line.ends_with("it was just how they like it."), line)
	assert_eq(t.gossip_line(0, t.record_found_nothing(0), "x"), "", "walking on is not news")



func test_finding_nothing_costs_a_little_and_friends_do_not_hear():
	var t := Town.new(1)
	var f: int = t.people[0].friends[0]
	t.record_found_nothing(0)
	assert_almost_eq(float(t.people[0].affinity), -Town.NOTHING_LIKED_DROP, 0.001)
	assert_eq(float(t.people[f].affinity), 0.0)
	assert_false(t.people[0].warning)
	assert_eq(t.people[0].grudges, 0, "not a walkout")



func test_stock_is_paid_only_when_affordable():
	var l := Ledger.new()
	l.money = 20
	assert_false(l.pay_stock(25))
	assert_eq(l.money, 20)
	assert_true(l.pay_stock(15))
	assert_eq(l.today.stock, 15)
	assert_eq(l.strikes(), 0)



func test_tag_hint_needs_three_items():
	var items := _menu_items()
	assert_eq(Menu.tag_hint(items, ["vegetable"]), "vegetable", "salad, fries and corn")
	assert_eq(Menu.tag_hint(items, ["meat"]), "")


func test_toggled_adds_in_pantry_order_and_removes_every_copy():
	assert_eq(Menu.toggled(["cheese", "bun"], "patty"), ["bun", "patty", "cheese"], "bottom of the stack first")
	assert_eq(Menu.toggled(["bun", "patty", "bun"], "bun"), ["patty"], "every copy out")
	assert_eq(Menu.toggled(["bun"], "bun"), [], "the last one out leaves nothing")
