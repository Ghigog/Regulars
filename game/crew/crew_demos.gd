class_name CrewDemos
extends RefCounted
## The staff demos (helpers, breaks, slips) and the all-staff run (PRD 10.7, staff_only).

var crew: Crew


func _init(crew_: Crew) -> void:
	crew = crew_


# ---------------------------------------------------------------- demos

## REGULARS_DEMO=helpers: a grill cook, a server and a washer at work in a busy room, two
## desks along the front (shoot at about 12). helpers_break: the server and the washer on
## their break, chatting by the desks, while the cook works on (shoot at about 4).
## helpers_slip (PRD 10.8): the washer down on a level 4 cell, dazed, and the server, who
## has the help-up duty, crossing to lift them (shoot at about 3 and 5).
func demo(which: String) -> void:
	for c: Vector2i in [Vector2i(8, 6), Vector2i(9, 6)]:
		if not crew.game.stations.has(c):
			crew.game.world.add_station("desk", c)
	var on_break := which == "helpers_break"
	var slip := which == "helpers_slip"
	var hires := [[2, "Grill cook", ["fetch", "grill", "assemble"], 0, 0.85, Vector2i(1, 4)],
		[5, "Server", ["take_orders", "take_payment", "carry_trays", "clear_tables"] + (["help_up"] as Array if slip else []), 1 if on_break else 0, 0.7, Vector2i(7, 5) if on_break else Vector2i(5, 3)],
		[9, "Washer", ["wash_up", "empty_bin", "clear_tables", "mop"], 1 if on_break else 0, 0.35, Vector2i(8, 5) if on_break else Vector2i(3, 3)]]
	for row: Array in hires:
		var pid: int = crew.game.staff.add_post(row[1], row[2], row[3], 0, 99)
		var cv: Dictionary = crew.game.staff._make_cv(row[0], Staff.skills_from(crew.game.town.people[row[0]].tolerance),
			crew.game.town.rating(row[0]), 1.0, pid)
		crew.game.staff.cvs.append(cv)
		crew.game.staff.hire(cv.id, -1, crew.game.ledger.day)
		crew.game.staff.employee(row[0]).satisfaction = row[4]
		var helper := crew.add_helper(row[0], row[5])
		if slip and row[0] == 9:   # once the day is under way, as the guest slip demo does
			crew.game.get_tree().create_timer(1.0).timeout.connect(_demo_slip.bind(helper, Vector2i(6, 3)))
	crew.game.world.find_station("sink").dirty = 2
	if not slip:   # in the slip demo the server is free to help
		crew.game.stations[Vector2i(8, 3)].dirty = 1
		crew.game.stations[Vector2i(8, 3)].refresh()
	crew.game.world.find_station("sink").refresh()
	if on_break:
		crew.game.clock = Staff.break_starts(1, crew.game.day.day_length())[0] + 0.2
		crew.game.floor_dirt.mess.dirt[Vector2i(6, 3)] = 2
	var t: float = crew.game.clock
	crew.game.arrivals.assign([{"time": t + 0.5, "group": [0, 1]}, {"time": t + 2.0, "group": [4]}, {"time": t + 5.0, "group": [6, 7]}])


## REGULARS_DEMO=helpers_home (T-123): the day has just ended. A washer is still at the sink
## mid-wash (the ring on the sink); a server stands clear of the desks, turned side-on so the
## bag at their side reads, about to walk out. Shoot at about 2.
func demo_home() -> void:
	var g: Game = crew.game
	for c: Vector2i in [Vector2i(8, 6), Vector2i(9, 6)]:
		if not g.stations.has(c):
			g.world.add_station("desk", c)
	var sink: Station = g.world.find_station("sink")
	if g.world.find_station("dish_rack") == null:
		g.world.add_station("dish_rack", sink.cell + Vector2i(0, 1))
	var rack: Station = g.world.find_station("dish_rack")
	rack.count = 0   # room on the rack, or there is nowhere for a washed plate to go
	rack.refresh()
	sink.dirty = 4
	sink.refresh()
	g.arrivals.assign([{"time": 99999.0, "idx": 13}])
	var washer := demo_hire(9, "Washer", ["wash_up", "empty_bin", "clear_tables", "mop"], sink.cell + Vector2i(1, 0))
	var server := demo_hire(5, "Server", ["take_orders", "carry_trays"], Vector2i(8, 5))
	for i in 300:   # the washer is mid-wash at the sink before the day ends
		g.step(0.1)
		if not washer.steps.is_empty() and washer.steps[0].get("do") == "wash" and washer.work_left > 0.0:
			break
	g.arrivals.clear()
	g.day._end_day()
	g.session.open_build()   # past the receipt, into the night
	server.position = Grid.center(Vector2i(8, 4))   # a step back from the desk, so nothing hides the bag
	server.path.clear()
	server.stand = Vector2i(8, 4)
	server.aim = Vector3(0, 0, 1)   # turned to show their side, so the bag reads against the body
	server.home_stage = "collect"
	server.collect_left = 99.0
	server.take_bag()


## PRD 11.4's demo: one server hired with `duties`, standing at `at`.
func demo_hire(person: int, post: String, duties: Array, at: Vector2i) -> Helper:
	var pid: int = crew.game.staff.add_post(post, duties, 0, 0, 99)
	var cv: Dictionary = crew.game.staff._make_cv(person, Staff.skills_from(crew.game.town.people[person].tolerance),
		crew.game.town.rating(person), 1.0, pid)
	crew.game.staff.cvs.append(cv)
	crew.game.staff.hire(cv.id, -1, crew.game.ledger.day)
	crew.game.staff.employee(person).satisfaction = 0.9
	return crew.add_helper(person, at)


func _demo_slip(h: Helper, c: Vector2i) -> void:
	h.position = Grid.center(c)   # open floor between the tables, in plain view
	h.path.clear()
	for i in 4:
		crew.game.floor_dirt.mess.add_dirt(c)
	crew.game.floor_dirt.slip(h, c)


# ---------------------------------------------------------------- the all-staff run (PRD 10.7)

## A late-game kitchen with every tool, per theme: [cell, top ("" for none), base, boxes].
## The kitchen is grown back to the dining room's back wall, so (0..3, 0..1) is kitchen
## too and its back row opens round the top of the pass. The theme's fixed line (the
## grilled kind's fridge, a stove, the bread's box) is `Main.test_kitchen`'s; its second
## stove makes way for the slicer. Drinks (and the diner's freezer) are a bar by the door.
const STAFF_ROOM := {
	"diner": [
		[Vector2i(0, 1), "board", "long_counter", ["box_lettuce", "box_tomato", "ready_onion"]],
		[Vector2i(1, 0), "pot", "counter", []],
		[Vector2i(2, 0), "steamer", "counter", []],
		[Vector2i(3, 0), "fryer", "double_counter", ["box_potato", "box_corn"]],
		[Vector2i(0, 4), "slicer", "fridge", ["box_cheese"]],
		[Vector2i(2, 6), "grater", "fridge", ["box_cheese"]],
		[Vector2i(3, 6), "bread_knife", "double_counter", ["box_sourdough", "box_orange_juice"]],
		[Vector2i(4, 4), "juicer", "", []],
		[Vector2i(4, 5), "blender", "", []],
		[Vector2i(9, 1), "two_tap_fountain", "counter", []],
		[Vector2i(9, 2), "", "freezer", ["box_ice_cream"]],
	],
	"seaside": [
		[Vector2i(0, 1), "board", "double_counter", ["box_courgette", "ready_pepper"]],
		[Vector2i(1, 0), "pot", "double_counter", ["box_new_potato", "box_beans"]],
		[Vector2i(2, 0), "steamer", "fridge", ["box_mussels"]],
		[Vector2i(3, 0), "fryer", "fridge", ["box_calamari"]],
		[Vector2i(0, 4), "slicer", "counter", ["box_lemon"]],
		[Vector2i(2, 6), "grater", "double_counter", ["box_breadcrumbs"]],
		[Vector2i(3, 6), "bread_knife", "double_counter", ["box_crusty_loaf"]],
		[Vector2i(4, 4), "juicer", "", []],
		[Vector2i(4, 5), "blender", "", []],
		[Vector2i(9, 1), "wine_rack", "double_counter", ["box_fruit_smoothie"]],
	],
}


## Tonight's menu in the all-staff room: every kind of the theme in something.
const STAFF_MENU := {
	"diner": [["main", ["bun", "patty", "cheese", "lettuce", "onion"], "Burger"],
		["main", ["sourdough", "shredded_cheese", "tomato"], "Deli melt"],
		["side", ["fries"], "Fries"], ["side", ["steamed_corn"], "Steamed corn"],
		["side", ["corn"], "Corn cob"], ["side", ["ice_cream"], "Ice cream"],
		["drink", ["soda"], "Soda"], ["drink", ["cola"], "Cola"],
		["drink", ["orange_juice"], "Orange juice"], ["drink", ["milkshake"], "Milkshake"]],
	"seaside": [["main", ["roll", "fish", "lemon"], "Fish roll"],
		["main", ["crusty_loaf", "calamari", "pepper", "breadcrumbs"], "Calamari loaf"],
		["side", ["mussels"], "Mussels"], ["side", ["new_potato", "beans", "courgette"], "Garden plate"],
		["drink", ["wine"], "White wine"], ["drink", ["red_wine"], "Red wine"],
		["drink", ["lemonade"], "Lemonade"], ["drink", ["fruit_smoothie"], "Smoothie"]],
}


## The crew: [person, post, duties, breaks]. Between them every duty the room gives.
## Breaks fall evenly through the day and equal counts break together (PRD 10.2), so the
## cooks' two never meet the floor's one, and the drinks hand takes orders meanwhile.
const STAFF_CREW := [
	[2, "Line cook", ["fetch", "grill", "fryer", "pot", "assemble"], 2],
	[5, "Prep cook", ["fetch", "board", "slicer", "grater", "bread_knife", "steamer", "assemble"], 2],
	[7, "Drinks", ["fetch", "tap", "juicer", "blender", "assemble", "take_orders", "carry_trays"], 0],
	[9, "Server", ["take_orders", "take_payment", "carry_trays", "clear_tables", "help_up"], 1],
	[11, "Cleaner", ["wash_up", "empty_bin", "clear_tables", "mop", "sponge", "scraper", "spill_kit", "help_up"], 1],
]
const STAFF_TREAT := {"cleaner": Rect2i(5, 2, 3, 2), "primer": Rect2i(8, 5, 2, 2), "finish": Rect2i(5, 4, 1, 3)}


## Drinks go out in cups: a cup stack on the first free cell that leaves every piece
## in the room within reach.
func _place_cups() -> void:
	for x in range(crew.game.W):
		for z in range(crew.game.H):
			var c := Vector2i(x, z)
			if crew.game.stations.has(c) or not crew.game.plan.has_floor(c):
				continue
			var st: Station = crew.game.world.add_station("cups", c)
			if _all_reachable():
				return
			crew.game.world._unregister(st)
			st.queue_free()


func _all_reachable() -> bool:
	for st: Station in crew.game.stations.values():
		if st.type in ["fern", "desk"] or Station.is_table(st.type) or Station.is_seat(st.type):
			continue
		var ok := false
		for d: Vector2i in Grid.DIRS:
			var c: Vector2i = st.cell + d
			if crew.game.grid.in_bounds(c) and not crew.game.grid.is_blocked(c) and crew.game.grid.edge_open(c, st.cell) \
					and not crew.game.grid.find_path(crew.game.ENTRANCE_CELL, c).is_empty():
				ok = true
				break
		if not ok:
			return false
	return true


## The all-staff run (PRD 10.7): the room above, its menu, a crew hired at the desks, the
## floor treated, and the chef gone home: helpers run the whole day. The day is then
## started again so everything is in force (guests, the treatments, the crew).
func staff_only() -> void:
	var theme: String = Scenery.theme_id if STAFF_ROOM.has(Scenery.theme_id) else "diner"
	crew.game.menu_stock.test_kitchen()
	crew.game.menu_stock.clear_walls()
	crew.game.plan.fill(Rect2i(0, 0, Scenery.KITCHEN_W, Scenery.KITCHEN_Z), "tile")
	crew.game.world._sync_grid()
	crew.game.world._rebuild_room()
	var stove: Station = crew.game.stations.get(Vector2i(0, 4))
	if stove != null:
		crew.game.world._unregister(stove)
		stove.queue_free()
	for row: Array in STAFF_ROOM[theme]:
		var c: Vector2i = row[0]
		if not crew.game.stations.has(c):
			crew.game.world.add_station("counter", c, 1, 0, row[2])
		if row[1] != "":
			crew.game.world.add_station(row[1], c)
		for b: String in row[3]:
			crew.game.placing._store_box(c, b)
	for spot: Array in [["hood", Vector2i(0, 3)], ["extractor", Vector2i(1, 0)], ["hood", Vector2i(2, 0)],
			["hood", Vector2i(3, 0)], ["cabinet", Vector2i(0, 5)]]:
		if crew.game.kitchen.can_hang(spot[1], spot[0]):
			crew.game.world.add_high(spot[0], spot[1])
	# Chemicals apart from food: the cleaner over the bin, primer and finish by the door.
	crew.game.placing._store_box(Vector2i(0, 5), "box_cleaner")
	crew.game.world.add_station("counter", Vector2i(9, 6), 1, 0, "double_counter")
	crew.game.placing._store_box(Vector2i(9, 6), "box_primer")
	crew.game.placing._store_box(Vector2i(9, 6), "box_finish")
	for k: String in STAFF_TREAT:
		var r: Rect2i = STAFF_TREAT[k]
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				if crew.game.plan.has_floor(Vector2i(x, y)):
					crew.game.treat_laid[Vector2i(x, y)] = k
	# The cleaning trees: a flat mop's bucket; a scourer, a grease scraper and a spill kit on shelves and in a cabinet.
	var bucket: Station = crew.game.world.add_station("flat_mop", Vector2i(8, 6))
	crew.game.clean_kit.on_built(bucket, "flat_mop")
	var shelved := 0
	for c: Vector2i in crew.game.kitchen.wall_cells:
		if shelved < 3 and not crew.game.highs.has(c) and not crew.game.kitchen.holds_food(c) and crew.game.kitchen.can_hang(c, "shelf"):
			crew.game.clean_kit.shelve(c, ["scourer", "grease_scraper", "spill_kit"][shelved], "cabinet" if shelved == 2 else "shelf")
			shelved += 1
	for c: Vector2i in [Vector2i(5, 6), Vector2i(7, 6)]:
		if not crew.game.stations.has(c):
			crew.game.world.add_station("desk", c)
	_place_cups()
	crew.game.menu.items.clear()
	for it: Array in STAFF_MENU[theme]:
		crew.game.menu.add(it[0], it[1], it[2])
	for row: Array in STAFF_CREW:
		var pid: int = crew.game.staff.add_post(row[1], row[2], row[3], 0, 99)
		var person: int = row[0]
		var cv: Dictionary = crew.game.staff._make_cv(person, Staff.skills_from(crew.game.town.people[person].tolerance),
			crew.game.town.rating(person), 1.0, pid)
		crew.game.staff.cvs.append(cv)
		crew.game.staff.hire(cv.id, -1, crew.game.ledger.day)
	# Nobody cooks: the chef is not in today.
	for ch: Player in crew.game.chefs:
		ch.visible = false
		ch.position = Grid.center(crew.game.lot.bounds().position)
	crew.game.ledger.money = maxi(crew.game.ledger.money, 2000)
	crew.game.day.start_day()
