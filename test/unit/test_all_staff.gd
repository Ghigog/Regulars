extends GutTest
## PRD 10.7: the all-staff run. Hired helpers run a whole day with no chef, in a room
## with every tool, every cleaning tree, ready-made boxes and the floor treated. Any task
## nobody can do shows up here as a stuck ticket, an unserved table or dirt left lying.
## Guests are kept patient, so slowness is never mistaken for a task nobody does.

const STEP := 0.1
const MAX_SECONDS := 900.0   # a whole day with the slowest crew is well under this
const STUCK_AFTER := 120.0   # a ticket (or a table waiting to order) unchanged this long is stuck
const SEEDS := [11, 2026, 4242]

var game


func after_each():
	Scenery.theme_id = "diner"


func _start(theme: String, seed_value: int, day := 1) -> void:
	Scenery.theme_id = theme
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = "user://regulars_theme_test.cfg"
	game.town = Town.new(seed_value)
	game.town.make_tastes(theme)
	var all: Array = Pantry.for_theme(theme)
	for p in game.town.people:   # everyone eats, and orders sides and drinks (a liked kind in them)
		p.likes = all.duplicate()
		p.dislikes = []
	game.staff = Staff.new(seed_value)
	game.critic = Critic.new(seed_value, game.town.people.size())
	game.order_rng.seed = seed_value
	game.floor_dirt.mess.rng.seed = seed_value
	game.ledger.day = day
	game.flyers_out = day > 1   # a busy day: a long line at the door
	assert_not_null(game.crew, "the game loaded")
	if game.crew != null:
		game.crew.crew_demos.staff_only()


## Runs the day out. Returns what went wrong: stuck tickets, tables nobody served.
func _run_day() -> Dictionary:
	var first := {}      # ticket id -> [when it last changed, how it stood then]
	var sat := {}        # guest -> when they sat down to order
	var stuck := []
	var ordered := {}    # kinds on tickets
	var chores := {}     # an open chore -> when it was first seen
	var t := 0.0
	while game.phase == game.Phase.SERVICE and t < MAX_SECONDS:
		game.step(STEP)
		t += STEP
		for g: Guest in game.guests:
			g.mood.patience = 1.0
			if g.state == "ordering" and not sat.has(g):
				sat[g] = t
			elif g.state != "ordering":
				sat.erase(g)
		for tk: Dictionary in game.tickets:
			var now := _state_of(tk)
			if not first.has(tk.id):
				first[tk.id] = [t, now]
				for it: Dictionary in tk.items:
					for k: String in it.ingredients:
						ordered[k] = true
			elif first[tk.id][1] != now:
				first[tk.id] = [t, now]
			elif t - float(first[tk.id][0]) > STUCK_AFTER:
				stuck.append(_why(tk))
				first[tk.id] = [INF, now]
		var open := _chores()
		for k: String in chores.keys():
			if not open.has(k):
				chores.erase(k)
		for k: String in open:
			if not chores.has(k):
				chores[k] = t
			elif t - float(chores[k]) > STUCK_AFTER * 1.6:   # floor dirt waits behind tickets on a rush
				stuck.append("%s left undone" % k)
				chores[k] = INF
		for g: Guest in sat:
			if t - float(sat[g]) > STUCK_AFTER:
				stuck.append("a table nobody took the order of at %s" % str(g.table.cell))
				sat[g] = INF
	return {"stuck": stuck, "ordered": ordered, "t": t}


## The chores open now, each one a task on the board for someone: dirt worth cleaning,
## a dirty table, dishes in the sink, a full bin, burnt food on a tool.
func _chores() -> Dictionary:
	var out := {}
	var mess: FloorMess = game.floor_dirt.mess
	for c: Vector2i in mess.dirt:
		if mess.level(c) >= 1 and mess.can_clean(c) and game.grid.in_bounds(c):
			out["dirt at %s" % str(c)] = true
	for st: Station in game.stations.values():
		if Station.is_table(st.type) and st.dirty > 0:
			out["a dirty table at %s" % str(st.cell)] = true
		elif st.type == "sink" and st.dirty > 0:
			out["the washing up"] = true
		elif st.type == "bin" and st.count >= Crew.BIN_FULL:
			out["the full bin"] = true
		if st.item.begins_with("burnt:"):
			out["burnt food on the %s" % st.type] = true
	return out


## How a ticket stands: what its plates still need, where they are, who holds them.
## Any change is progress.
func _state_of(tk: Dictionary) -> String:
	var parts := []
	for e: Dictionary in game.crew.task_end._tagged(int(tk.id)):
		var d: Dish = e.dish
		parts.append("%d:%s@%s" % [d.line, str(d.ings), str(e.st.cell) if e.st != null else "hand"])
	return "%s needs %s served %d" % [str(parts), str(game.crew.task_end._ticket_needs(tk)), tk.order.served_count()]


func _why(tk: Dictionary) -> String:
	var tasks := []
	for task: Dictionary in game.crew.board.tasks.values():
		if task.get("ticket", null) == int(tk.id):
			tasks.append("%s by %s" % [task.type, str(task.duties)])
	var tops := []
	for st: Station in game.stations.values():
		if st.type in ["counter", "pass"] and st.item != "":
			tops.append("%s:%s" % [str(st.cell), st.item if st.item != "dish" else "dish" + str(st.dish.ings) + "t" + str(st.dish.ticket)])
	return "ticket %d (%s) stuck: %s; board %s; tops %s; cups %d plates %d" % [tk.id, str(tk.items.map(func(i: Dictionary) -> String: return i.name)),
		_state_of(tk), str(tasks), str(tops), game.world.find_station("cups").count if game.world.find_station("cups") else -1,
		game.world.find_station("dish_rack").count]


func _check(theme: String, seed_value: int, day := 1) -> Dictionary:
	_start(theme, seed_value, day)
	if is_failing():
		return {}
	assert_eq(game.crew.helpers.size(), CrewDemos.STAFF_CREW.size(), "the whole crew came in")
	var r := _run_day()
	var tag := "%s seed %d day %d" % [theme, seed_value, day]
	for line: String in r.stuck:
		gut.p(line)
	assert_eq(r.stuck, [], "%s: nothing stuck" % tag)
	assert_eq(game.phase, game.Phase.SUMMARY, "%s: the day ended (%.0f s)" % [tag, r.t])
	var rec: Dictionary = game.last_day
	assert_gt(int(rec.get("served", 0)), 0, "%s: guests were served" % tag)
	assert_eq(int(rec.get("walkouts", 0)), 0, "%s: nobody walked out" % tag)
	gut.p("%s: served %d in %.0f s, ordered %s" % [tag, int(rec.get("served", 0)), r.t, str(r.ordered.keys())])
	return r.ordered


func test_helpers_run_a_whole_diner_day_with_no_chef():
	var seen := {}
	for s: int in SEEDS:
		seen.merge(_check("diner", s))
		if is_failing():
			return
	_every_kind_ordered("diner", seen)


func test_helpers_run_a_whole_seaside_day_with_no_chef():
	var seen := {}
	for s: int in SEEDS:
		seen.merge(_check("seaside", s))
		if is_failing():
			return
	_every_kind_ordered("seaside", seen)


func _every_kind_ordered(theme: String, seen: Dictionary) -> void:
	for it: Array in CrewDemos.STAFF_MENU[theme]:
		for k: String in it[1]:
			assert_true(seen.has(k), "%s: %s was ordered and made on some day" % [theme, k])


## Every tool, box and home in the room has a free side someone can walk to.
func test_every_piece_in_the_all_staff_room_can_be_reached():
	for theme in ["diner", "seaside"]:
		_start(theme, 1)
		if is_failing():
			return
		for st: Station in game.stations.values():
			if st.type in ["table", "fern", "desk"] or Station.is_table(st.type):
				continue
			var ok := false
			for d: Vector2i in Grid.DIRS:
				var c: Vector2i = st.cell + d
				if game.grid.in_bounds(c) and not game.grid.is_blocked(c) and game.grid.edge_open(c, st.cell) \
						and not game.grid.find_path(game.ENTRANCE_CELL, c).is_empty():
					ok = true
			assert_true(ok, "%s: the %s at %s can be reached" % [theme, st.type, str(st.cell)])


## A rush on a later day, with flyers out: many tickets at once is where worktops run
## short and trays have nowhere to go.
func test_helpers_run_a_busy_day_in_both_themes():
	for theme in ["diner", "seaside"]:
		for s: int in [7, 99]:
			_check(theme, s, 8)
			if is_failing():
				return


## The crew's duties are the room's: none greyed out for want of a tool, and every duty
## the desk offers for this room is somebody's. The treatments are in force.
func test_the_crew_covers_every_duty_the_room_gives():
	for theme in ["diner", "seaside"]:
		_start(theme, 1)
		if is_failing():
			return
		var room: Dictionary = game.desk.room_duties()
		var offered := []
		for k: String in room:
			offered.append_array(room[k])
		var held := []
		for row: Array in CrewDemos.STAFF_CREW:
			held.append_array(row[2])
			assert_eq(Staff.missing_duties(row[2], room), [] as Array[String], "%s: %s has every tool" % [theme, row[1]])
		for d: String in offered:
			assert_true(held.has(d), "%s: someone has %s" % [theme, d])
		for d: String in ["mop", "sponge", "scraper", "spill_kit"]:
			assert_true(offered.has(d), "%s: the cleaning trees give %s" % [theme, d])
		assert_eq(game.floor_dirt.mess.treat.size(), game.treat_laid.size(), "%s: every laid cell treated today" % theme)
		assert_eq(game.menu_stock.treat_boxed().size(), 3, "%s: cleaner, primer and finish boxed apart from food" % theme)


## A group of four at two tables pushed together: the helpers take one order, serve all four,
## bring one bill and clear the plates on both halves.
func test_helpers_serve_bill_and_clear_a_combined_table():
	_start("diner", 11)
	if is_failing():
		return
	for st: Station in game.paying.dining_tables():
		game.world._unregister(st)
		st.queue_free()
	var halves: Array[Station] = [game.world.add_station("table", Vector2i(6, 1)), game.world.add_station("table", Vector2i(6, 2))]
	game.phase = game.Phase.SERVICE
	game.door_open = true
	var party: Array[Guest] = game.seating.spawn_group([0, 1, 2, 3])
	var t := 0.0
	var paid := false
	var ordered := false
	while t < 400.0 and not paid:
		game.step(STEP)
		t += STEP
		for g: Guest in game.guests:
			g.mood.patience = 1.0
		ordered = ordered or party.any(func(g: Guest) -> bool: return int(g.order.get("ticket", -1)) >= 0 or g.state == "waiting")
		paid = ordered and party.all(func(g: Guest) -> bool: return g.state == "leaving" or not is_instance_valid(g))
	assert_true(ordered, "the helpers took the order")
	assert_true(paid, "all four were served, billed and left (%.0f s)" % t)
	assert_eq(game.tickets.size(), 0, "no ticket left on the rail")
	for g: Guest in party:
		assert_false(game.seat_taken.get(g.seat) == g, "the party gave up its chairs on both halves")
	var open := t
	while t < open + 120.0 and (halves[0].dirty > 0 or halves[1].dirty > 0):
		game.step(STEP)
		t += STEP
	assert_eq(halves[0].dirty, 0, "the lead half was cleared")
	assert_eq(halves[1].dirty, 0, "and the other half too")
