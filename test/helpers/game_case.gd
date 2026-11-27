extends GutTest
## Shared setup and helpers for the test_game* test files.


## Drives the real game scene headlessly through its public methods.

var game

const THEME_TEST_PATH := "user://regulars_theme_test.cfg"
const OPTIONS_TEST_PATH := "user://regulars_options_test.cfg"



func before_each():
	HudOptions.options_path = OPTIONS_TEST_PATH   # never the player's real settings
	DirAccess.remove_absolute(OPTIONS_TEST_PATH)
	game = load("res://game/main.tscn").instantiate()
	game.first_night = false   # straight into day 1
	add_child_autofree(game)
	game.set_process(false)
	game.best_path = "user://regulars_best_test.json"
	game.theme_path = THEME_TEST_PATH
	DirAccess.remove_absolute(THEME_TEST_PATH)   # no theme remembered: the card starts on the diner
	# One guest far in the future keeps the day open while a test works.
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	game.menu_stock.test_kitchen()   # the old burger line and a one-Burger menu; a run starts empty
	_neutral_tastes()
	_neutral_tolerance_and_dirt()
	game.menu_stock.clear_walls()   # the start's hood, cabinets and shelf (PRD 8.5) are tested in test_kitchen.gd



## Nobody dislikes anything, so every guest orders from the test menu.
## Tolerances (PRD 10) and floor dirt (PRD 9) are random; tests of other systems
## start every guest middling and with no dirt dropped. Their own tests live in
## test_staff.gd and test_floor_mess.gd.
func _neutral_tolerance_and_dirt() -> void:
	for p in game.town.people:
		p.tolerance = {"food": 3, "service": 3, "clean": 3}
	game.floor_dirt.drops = false



func _neutral_tastes() -> void:
	for p in game.town.people:
		p.likes = []
		p.dislikes = []



func _run(seconds: float) -> void:
	for i in int(seconds / 0.1):
		game.step(0.1)



## A served guest eats, chats, and is handed the right bill (PRD 11).
func _eat_and_pay(g: Guest) -> void:
	_run(g.eat_time + Guest.CHAT_TIME + 0.5)
	game.paying.pay_bill(g.table)



func _use(type: String) -> void:
	game.cooking.use_station(game.world.find_station(type))



func _the_pass() -> Station:
	return game.stations[Vector2i(4, 4)]



## Makes a Burger on the pass, grilling the patty for `grill` seconds: the patty goes
## down, the bun on it, then a plate from the stack goes under it and is picked up. The chef holds it plated.
func _cook_burger(grill := Station.COOK_TIME + 0.5) -> void:
	game.cooking.use_station(game.menu_stock.storage_of("patty"))
	_use("stove")
	_run(grill)
	_use("stove")
	game.cooking.use_station(_the_pass())        # the patty down
	game.cooking.use_station(game.menu_stock.storage_of("bun"))
	game.cooking.use_station(_the_pass())        # the bun on it
	_use("dish_rack")                       # a plate in hand
	game.cooking.use_station(_the_pass())        # plated, the plate under it
	game.cooking.use_station(_the_pass())        # picked up



## A guest sat at a table with their order taken.
func _ordered_guest(idx := 0) -> Guest:
	var g: Guest = game.seating.spawn_guest(idx)
	_run(12.0)
	_order(g)
	return g



func _use_says(type: String) -> String:
	return game.cooking.use_station(game.world.find_station(type))



## The chef takes the order at the guest's table.
func _order(g: Guest) -> void:
	assert_string_contains(game.cooking.prompt_for(g.table), "Take")
	game.cooking.use_station(g.table)



## A deal at a table: E, then held to the end of the bar.
func _deal(g: Guest) -> void:
	game.player.position = Grid.center(g.table.cell + Vector2i(0, 1)) if game.world.station_at(game.player.target_cell()) != g.table else game.player.position
	game.cooking.use_station(g.table)
	if game.world.station_at(game.player.target_cell()) != g.table:   # the test stands wherever: point the hold at the table
		game.serving._deal_hold[game.player] = {"g": g, "kind": game.serving._deal_hold.get(game.player, {}).get("kind", "half" if not g.mood.discounted else "comp"), "t": game.serving.DEAL_HOLD}
		if game.serving._deal_hold[game.player].kind == "half":
			game.serving.offer_discount(g)
		else:
			game.serving.offer_comp(g)
		game.serving._deal_hold.erase(game.player)
		return
	game.serving._tick_deal(game.player, true, game.serving.DEAL_HOLD + 0.01)



func _to_build() -> void:
	game.arrivals.clear()
	_run(0.2)
	game.session.open_build()



func _gross_kinds() -> Array:
	game.seating._collect_gross()
	return game._gross.map(func(s): return s.kind)



func _seat_at(table_cell: Vector2i, left: bool) -> Guest:
	# Fill tables with pairs until a guest lands on the wanted seat.
	var want := table_cell + Vector2i(-1 if left else 1, 0)
	for i in 3:
		var pair: Array[Guest] = game.seating.spawn_group([i * 2, i * 2 + 1])
		_run(12.0)
		for g in pair:
			if g.cell == want and g.seated_waiting():
				return g
	return null



func _mouse(at: Vector3, button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = game.cam.unproject_position(at)
	game._unhandled_input(e)



# ---------------------------------------------------------------- input per player

## A controller button, delivered straight to Controls (no fake keys, no frames).
func _pad(button: int, pressed: bool, device := 0) -> void:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = pressed
	game.controls._input(e)



func _tap_pad(button: int, device := 0) -> void:
	_pad(button, true, device)
	_pad(button, false, device)



func _axis(axis: int, value: float, device := 0) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = axis
	e.axis_value = value
	game.controls._input(e)



## Takes every Table tile and seat piece out of the room.
func _clear_dining() -> void:
	for st: Station in game.stations.values().duplicate():
		if Station.is_table(st.type) or Station.is_seat(st.type):
			game.world._unregister(st)
			st.queue_free()


## Puts one table of Table tiles at `cells` with a chair on each of `chairs`, turned to face
## the tile beside it. Returns the tiles.
func _add_table(cells: Array, chairs: Array) -> Array[Station]:
	var out: Array[Station] = []
	for c: Vector2i in cells:
		out.append(game.world.add_station("table", c))
	for c: Vector2i in chairs:
		game.world.add_station("chair", c, 1, TableJoins.face_toward(c, cells))
	return out



## The share of `id` a seat really gets, from decor_near once a piece is placed.
func _placed_share(seat: Vector2i, id: String) -> float:
	var best := 0.0
	for n: Dictionary in game.decor.decor_near(seat):
		if n.id == id:
			best = maxf(best, Decor.share(id, int(n.dist), int(n.get("tier", 1))))
	return best



## Checks every seat's mark against what it gets once placed; returns the marks seen.
func _marks_tell_the_truth(marks: Dictionary, id: String) -> Dictionary:
	var seen := {}
	for s: Vector2i in marks:
		assert_eq(marks[s].share, _placed_share(s, id), "%s at %s" % [id, s])
		seen[marks[s].mark] = true
	return seen



# ---------------------------------------------------------------- options screen

func after_each():
	get_tree().paused = false   # a failed options test must not freeze the rest
	Scenery.theme_id = "diner"   # a seaside test must not leak its theme



## A key press as the keyboard sends it, delivered at once rather than on the
## next frame.
func _key(key: Key, pressed := true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.keycode = key
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()



func _tap(key: Key) -> void:
	_key(key)
	_key(key, false)



func _closest_pair(list: Array) -> float:
	var worst := 99.0
	for i in list.size():
		for j in range(i + 1, list.size()):
			var d: Vector3 = list[i].position - list[j].position
			worst = minf(worst, Vector2(d.x, d.z).length())
	return worst



func _serve_one(idx: int, joy: float, patience: float, disgust := 0.0) -> Guest:
	var g: Guest = game.seating.spawn_guest(idx)
	_run(12.0)
	_order(g)
	_cook_burger()
	g.mood.joy = joy
	g.mood.patience = patience
	g.mood.disgust = disgust
	game.cooking.use_station(g.table)
	return g



# ---------- Night cleaning (PRD 5) ----------

func _face(cell: Vector2i, dir: Vector2i) -> void:
	game.player.position = Grid.center(cell)
	game.player.look(dir)



func _face_station(st: Station) -> void:
	var c := game.stations.find_key(st) as Vector2i
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		_face(c + d, -d)
		if game.world.station_at(game.player.target_cell()) == st:
			return


func _face_table() -> void:
	_face(Vector2i(8, 2), Vector2i(0, 1))   # the table at (8, 3)



func _face_sink() -> void:
	_face(Vector2i(3, 3), Vector2i(0, -1))  # the sink at (3, 2)



func _dirty_table(plates := 1) -> Station:
	var t: Station = game.stations[Vector2i(8, 3)]
	t.dirty = plates
	t.refresh()
	return t



# ---------- Prep minigames (PRD 1, milestone 3) ----------

## Holds Use at a drink station until the cup is `fill` full, then lets go.
func _pour(st: Station, fill: float) -> void:
	var who: PlayerInput = game.controls.players[0]
	assert_eq(game.cooking.use_station(st), "Pour %s" % Pantry.name_of(Catalog.ingredient_of(st.type)).to_lower())
	who.hold("test", "a", "use", true)
	while game.prep_games.prep_of(0).get("fill", 9.0) < fill:
		game.step(0.02)
	who.hold("test", "a", "use", false)
	game.step(0.02)



## Plays the chop minigame, pressing Use on the notch for the first `hits` sweeps.
func _chop(hits: int) -> void:
	for k in Prep.CHOP_SWEEPS:
		var notch := (k + 0.5) * Prep.CHOP_SWEEP_TIME
		while float(game.prep_games.prep_of(0).get("t", 99.0)) < notch:
			game.step(0.01)
		if k < hits:
			game.coop.act(0, "use")
	_run(Prep.CHOP_SWEEP_TIME)



func _tool(type: String, cell: Vector2i, crate: String) -> Station:
	game.menu_stock.stock_box(crate.trim_prefix("crate_"), cell + Vector2i(0, 1))
	return game.world.add_station(type, cell)



# ---------- The menu screen, stock and the door card (PRD 1, milestone 4) ----------

func _at_door() -> void:
	game.player.position = Grid.center(Vector2i(9, 4))
	game.player.look(Vector2i(1, 0))



# ---------- The critic (PRD 2) ----------

func _card_says(text: String) -> bool:
	if game.hud.guest_card == null:
		return false
	for n in game.hud.guest_card.find_children("*", "Label", true, false):
		if (n as Label).text == text:
			return true
	return false



## Starts `day` and leaves only the critic's arrival (if any), due at once.
func _start_day_with_only_the_critic(day: int) -> bool:
	game.ledger.day = day
	game.day.start_day()
	var booked: Array = game.arrivals.filter(func(a: Dictionary) -> bool: return a.get("critic", false))
	for a in booked:
		a.time = 0.2
	game.arrivals.assign(booked)
	return not booked.is_empty()



func _run_to_summary() -> void:
	for i in 600:
		if game.phase == game.Phase.SUMMARY:
			return
		game.step(0.1)



func _plain_counter() -> Vector2i:
	for c: Vector2i in game.stations:
		var st: Station = game.stations[c]
		if st.type == "counter" and st.base == "counter" and game.kitchen.stock(c).is_empty():
			return c
	return game.NO_CELL



## A length of the pass, bare, with open floor on its kitchen side; the chef faces it.
func _pass_counter_faced() -> Vector2i:
	for c: Vector2i in game.stations:
		var st: Station = game.stations[c]
		if st.type == "counter" and st.pass_look and st.base == "counter" and not st.has_node("till") \
				and game.kitchen.stock(c).is_empty() and not game.stations.has(c + Vector2i(0, 1)):
			game.player.position = Grid.center(c + Vector2i(0, 1))
			game.player.facing = Vector2i(0, -1)
			return c
	return game.NO_CELL



# ---------- Paying the bill (PRD 11) ----------

## A guest served straight from a full tray, then run on until their table is ready to pay.
func _ready_to_pay(idx := 0) -> Guest:
	var g := _ordered_guest(idx)
	game.serving.serve(g, game.serving.full_tray_for(g))
	_run(g.eat_time + Guest.CHAT_TIME + 0.5)
	return g



func _walls_round(c: Vector2i) -> void:
	for d: Vector2i in Grid.DIRS:
		game.grid.walls[Grid.edge_between(c, c + d)] = true
