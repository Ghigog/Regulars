class_name GameDemoScenes
extends RefCounted
## Screenshot demos, continued (see demos.gd for the dispatcher): building, the menu,
## paying, orders and tickets, the prep minigames, kind/comp offers, guest mood, effects.

var game: Game


func _init(game_: Game) -> void:
	game = game_


## EPIC 28: the room cleared of dining pieces, then a pair pushed together and a lone table
## (cards 4 and 2) and a run of three (a pair and a leftover: cards 4 and 2 again).
func _demo_seat_cards() -> void:
	for st: Station in game.paying.dining_tables():
		game.world._unregister(st)
		st.queue_free()
	for spot: Array in [[5, 5, 0], [5, 6, 0], [8, 5, 1], [5, 1, 1], [6, 1, 1], [7, 1, 1]]:   # pair, lone, run of three
		game.world.add_station("table", Vector2i(spot[0], spot[1]), 1, spot[2])
	game.player.position = Grid.center(Vector2i(3, 3))


func _demo_build(demo: String) -> void:
	game.session.open_build()
	if demo == "seat_cards":
		_demo_seat_cards()
		return
	if demo == "build_new":   # every PRD 7 piece placed for this theme (run once per theme)
		var show := "jukebox" if not Scenery.seaside() else "aquarium"
		var small := "gumball" if not Scenery.seaside() else "lantern"
		for spot: Array in [["dish_rack", 3, 3, 0], ["sink", 3, 6, 0], ["bin", 1, 6, 0],
				["floor_lamp", 5, 0, 0], [show, 7, 0, 0], [small, 8, 0, 0], ["flower_stand", 9, 2, 0],
				["coat_stand", 5, 6, 0], ["stool", 5, 3, 0]]:
			game.world.add_station(spot[0], Vector2i(spot[1], spot[2]), 1, spot[3])
		return
	for step: Array in [["counter", 2, 4, 0], ["screen", 8, 5, 0], ["screen", 9, 5, 0], ["table", 8, 6, 0], [GameWorld.fern(), 9, 2, 0]]:
		game.placing.pick_catalog(step[0])
		game.placing.place(Vector3i(step[1], step[2], step[3]))
	game.placing.cancel_hand()
	if demo == "door":  # at the doorway, about to flip the card
		game.player.position = Grid.center(Vector2i(Game.W - 1, Game.DOOR.y))
		game.player.look(Vector2i(1, 0))
	elif demo == "build_tools":   # the shop's Build tab: floors, walls and ways through
		game.session.open_shop()
		game.hud._set_category("Build")
	elif demo == "build" or demo == "build_find":  # the shop, three items along
		game.session.open_shop()
		if demo == "build_find":
			game.hud.set_search("o")
		for i in 3:
			game.get_tree().create_timer(0.3 + 0.25 * i).timeout.connect(game.hud.shop_ui.shop_move.bind(1))
	elif demo == "build_move":  # a table picked up and turned, ready to sell or put down
		game.placing.pick_up(Vector3(8.5, 0, 3.5))
		game.placing.rotate_hand()
		game._demo_hover = Vector3(7.5, 0, 2.5)
	elif demo == "build_room" or demo == "build_drag":
		# A back room behind the dining room through a door, the kitchen grown to the
		# left behind a new wall, and a door the bin stands in front of (greyed out).
		game.ledger.money = 2000
		game.placing.pick_catalog("floor_planks")
		game.room_edit.finish_drag(Vector3(4.5, 0, -1.5), Vector3(9.5, 0, -0.5), false)
		game.placing.pick_catalog("wall")
		game.room_edit.finish_drag(Vector3(4, 0, 0), Vector3(10, 0, 0), false)
		game.placing.pick_catalog("door")
		game.placing.place(Vector3i(7, 0, 0))
		game.placing.pick_catalog("floor_tile")
		game.room_edit.finish_drag(Vector3(-2.5, 0, 2.5), Vector3(-0.5, 0, 6.5), false)
		game.placing.pick_catalog("wall")
		game.room_edit.finish_drag(Vector3(0, 0, 2), Vector3(0, 0, 7), false)
		game.placing.pick_catalog("arch")
		game.placing.place(Vector3i(0, 5, 1))
		game.placing.pick_catalog("door")
		game.placing.place(Vector3i(1, 2, 0))
		game.placing.cancel_hand()
		if demo == "build_drag":   # more floor being dragged out, part of it off the lot
			game.placing.pick_catalog("floor_planks")
			game.player.drag = {"from": Vector3(-0.5, 0, -1.5), "remove": false}
			game._demo_hover = Vector3(3.5, 0, 1.5)
	elif demo == "build_dining" or demo == "build_dining_shop":  # a booth and a table for four, in the room or the shop
		for spot: Array in [[Vector3(6.5, 0, 1.5), "table4", Vector3i(6, 1, 0)], [Vector3(6.5, 0, 5.5), "booth", Vector3i(6, 5, 0)]]:
			game.placing.pick_up(spot[0])
			game.placing.sell_hand()
			game.placing.pick_catalog(spot[1], 1)
			game.placing.place(spot[2])
			game.placing.cancel_hand()   # a bought piece stays in hand for the next one
		if demo == "build_dining_shop":
			game.session.open_shop()
			game.hud._set_category("Dining")
			game.get_tree().create_timer(0.3).timeout.connect(game.hud.shop_ui.shop_move.bind(1))
	elif demo == "build_finish":   # parquet and marble, striped and rose paper, paint, and the rug moved
		game.ledger.money = 2000
		game.ledger.xp = 500
		for step: Array in [["floor_parquet", Vector3(4.5, 0, 0.5), Vector3(9.5, 0, 2.5)],
				["floor_marble", Vector3(4.5, 0, 4.5), Vector3(7.5, 0, 6.5)],
				["paper_stripe", Vector3(4, 0, 0), Vector3(7, 0, 0)],
				["paper_rose", Vector3(7, 0, 0), Vector3(10, 0, 0)],
				["paint", Vector3(0, 0, 2), Vector3(4, 0, 2)],
				["paint", Vector3(10, 0, 0), Vector3(10, 0, 4)]]:
			game.placing.pick_catalog(step[0])
			game.room_edit.finish_drag(step[1], step[2], false)
		game.placing.cancel_hand()
		game.placing.pick_up(Vector3(8.5, 0, 4.5))
		game.placing.place(Vector3i(6, 1, 0))
	elif demo == "build_range":  # a fern carried past the tables: its reach and the seats it touches
		game.placing.pick_catalog(GameWorld.fern(), 1)
		game._demo_hover = Vector3(6.5, 0, 3.5)
	elif demo == "build_range_floor":  # marble being dragged out under the tables: who sits on it
		game.ledger.xp = 500
		game.placing.pick_catalog("floor_marble")
		game.player.drag = {"from": Vector3(6.5, 0, 2.5), "remove": false}
		game._demo_hover = Vector3(9.5, 0, 4.5)
	elif demo == "build_range_rug":   # a new rug under the back table; one seat in view is full already
		game.ledger.xp = 500
		game.ledger.money = 500
		game.placing.pick_catalog("floor_marble")
		game.room_edit.finish_drag(Vector3(9.5, 0, 3.5), Vector3(9.5, 0, 3.5), false)   # marble and the old rug: (9, 3) is full
		game.placing.pick_catalog("rug")
		game._demo_hover = Vector3(6.5, 0, 1.5)
	elif demo == "build_range_paint":  # paint dragged along the back wall: the seats against it
		game.ledger.xp = 500
		game.placing.pick_catalog("paint")
		game.player.drag = {"from": Vector3(4, 0, 0), "remove": false}
		game._demo_hover = Vector3(10, 0, 0)
	elif demo == "build_till":  # the till lifted off the pass and held over the next counter down
		game.player.position = Grid.center(Vector2i(5, 2))
		game.player.look(Vector2i(-1, 0))
		game.card.open_card()
		game.card.card_act("till")
		game._demo_hover = Vector3(4.5, 0, 4.5)
	else:   # a stove from the shop, held over a good spot or (build_no, build_refused) a refused one
		game.placing.pick_catalog("stove", 2)
		game._demo_hover = Vector3(6.5, 0, 5.5) if demo in ["build_no", "build_refused"] else Vector3(3.5, 0, 5.5)
		if demo == "build_refused":   # E pressed over it: fail sound, cross wobble, the reason
			game.room_edit.build_interact()


## A fuller kitchen and menu: mains, sides (one with no onion to make it, greyed)
## and a drink, then the screen, an item being named, or the restock note.
func _demo_menu(demo: String) -> void:
	game.session.open_build()
	game.menu_stock.stock_box("cheese", Vector2i(1, 6), true)
	game.menu_stock.stock_box("potato", Vector2i(2, 6))
	game.world.add_station("fryer", Vector2i(3, 6))
	game.world.add_station("fountain", Vector2i(1, 2))
	var cheese := game.menu.add("main", ["bun", "patty", "cheese"], "Cheeseburger", "dear")
	game.menu.add("main", ["bun", "patty", "cheese", "patty", "cheese"], "Double Stack", "dear")
	game.menu.add("side", ["potato"], "Fries", "cheap")
	game.menu.add("side", ["potato", "cheese"], "Cheesy Fries")
	game.menu.add("side", ["onion"], "Onion Rings")
	game.menu.add("drink", ["soda"], "Soda", "cheap")
	game.menu_stock.menu_changed()
	if demo == "restock":
		game.hud.menu_notes.open = true
		game.player.position = Grid.center(Vector2i(1, 5))
		game.player.look(Vector2i(0, 1))
		game.hud.hints_ui.show_build()
		return
	game.menu_stock.open_menu()
	if demo == "menu_name":
		game.hud.menu.open_item(cheese)
		game.hud.menu.start_naming()


## PRD 11's demos. pay_call: a table ready to pay calling the chef in sight, a second
## behind a partition not calling (shoot at about 8). pay_till: two guests queued at the
## till (about 8). pay_bill: the bill screen open, two tables waiting, three items ticked
## (3). pay_hand: the chef handing a slip over, the bar half full (3). pay_wrong: a refused
## bill and its line on the guest card (4). pay_server: the server walking a slip to a
## table (about 10).
func _demo_pay(demo: String) -> void:
	game.arrivals.assign([{"time": 99999.0, "idx": 13}])
	var t1: Station = game.stations[Vector2i(6, 5)]
	var t2: Station = game.stations[Vector2i(8, 3)]
	var t3: Station = game.stations[Vector2i(6, 1)]
	match demo:
		"pay_call":
			# A partition shuts the far table off from the chef in the near corner.
			for x in range(5, 8):
				game.world.add_wall(Vector2i(x, 3), 0)
			for y in range(0, 3):
				game.world.add_wall(Vector2i(8, y), 1)
			_demo_paying_party([0, 1], t1)
			_demo_paying_party([2], t3)
			game.player.position = Grid.center(Vector2i(9, 5))
			game.player.look(Vector2i(-1, 0))
		"pay_till":
			var a := _demo_paying_party([0, 1], t1)
			var b := _demo_paying_party([2, 3], t2)
			game.player.position = Grid.center(Vector2i(1, 4))
			game.player.look(Vector2i(1, 0))
			game.get_tree().create_timer(1.0).timeout.connect(func() -> void:
				game.paying.send_to_till(a[0].table)
				game.paying.send_to_till(b[0].table))
		"pay_bill":
			# A fuller menu than the test kitchen's one main: bread as a side, and a drink.
			var bread: String = GameWorld.fixed_main().bread
			game.menu.add("side", [bread], Pantry.name_of(bread), "cheap")
			if Scenery.theme_id == "diner":
				game.world.add_station("fountain", Vector2i(1, 2))
				game.menu.add("drink", ["soda"], "Soda", "cheap")
			game.menu_stock.menu_changed()
			_demo_paying_party([0, 1], t1)
			_demo_paying_party([2], t2)
			var till := game.paying.till_station()
			game.player.position = Grid.center(till.cell + Vector2i(-1, 0))
			game.player.look(Vector2i(1, 0))
			game.get_tree().create_timer(1.0).timeout.connect(func() -> void:
				game.paying.open_bill(game.player)
				var items := game.menu_stock.tonight_menu()
				if items.is_empty():
					return
				game.hud.bill.bill.add(int(items[0].id), 2)
				game.hud.bill.bill.add(int(items[-1].id))
				game.hud.bill._sel_key = "item:%d" % int(items[0].id)
				game.hud.bill.render())
		"pay_hand":
			var party := _demo_paying_party([0, 1], t1)
			game.player.position = Grid.center(t1.cell + Vector2i(1, 0))
			game.player.look(Vector2i(-1, 0))
			game.player.set_held("bill")
			game.player.bill = game.paying.right_bill(party[0].table)
			game.player.demo_giving = 0.5
		"pay_wrong":
			var party := _demo_paying_party([0, 1], t1)
			game.player.position = Grid.center(t1.cell + Vector2i(1, 0))
			game.player.look(Vector2i(-1, 0))
			game.get_tree().create_timer(2.5).timeout.connect(func() -> void:
				var wrong := game.paying.right_bill(party[0].table)
				var items := game.menu_stock.tonight_menu()
				wrong.add(int(items[-1].id))   # one too many
				game.player.set_held("bill")
				game.player.bill = wrong
				game.paying.give_bill(game.player, party[0].table)
				game.hud.show_guest(party[0]))
		"pay_server":
			_demo_paying_party([0, 1], game.stations[Vector2i(8, 3)])
			game.player.position = Grid.center(Vector2i(1, 4))
			game.player.look(Vector2i(1, 0))
			game.crew.crew_demos.demo_hire(5, "Server", ["take_orders", "take_payment", "carry_trays", "clear_tables"], Vector2i(5, 5))


## Demos (PRD 11): a party sat straight down at `table`, served and done eating.
func _demo_paying_party(ids: Array, table: Station) -> Array[Guest]:
	for idx: int in ids:   # tastes are random: make sure each orders from the demo menu
		game.town.people[idx].dislikes = []
	var party := game.seating.spawn_group(ids)
	for i in party.size():
		var g := party[i]
		game.queue.erase(g)
		g.line_place = -1
		g.table = table
		g.seat = table.seats[i]
		game.seat_taken[g.seat] = g
		g.position = Grid.center(g.seat)
		g.cell = g.seat
		g.goal = g.position
		g.path.clear()
		g._sit()
	game.seating._reflow_queue()
	game.serving.take_orders(table)
	for g in party:
		if g.state == "waiting":
			game.serving.serve(g, game.serving.full_tray_for(g))
			game.serving.finish_meal(g)
			g.timer = 0.3 * party.find(g)
	return party


func _demo_order(take: bool) -> void:
	for g in game.guests:
		if g.state == "ordering":
			if take:
				game.cooking.use_station(g.table)
				return
			game.player.position = Grid.center(g.table.cell + Vector2i(0, 1))
			game.player.look(Vector2i(0, -1))
			game.hud.show_guest(g)
			return


## Takes the seated orders, then copies the first ticket until the column overflows.
func _demo_orders_long() -> void:
	for g in game.guests:
		if g.state == "ordering":
			game.serving.take_orders(g.table)
	if game.tickets.is_empty():
		return
	var first: Dictionary = game.tickets[0]
	for k in 8:
		var copy := first.duplicate()
		copy.id = int(first.id) + 1000 + k
		game.tickets.append(copy)
	game.hud.day_ui.refresh_tickets()


func _demo_ticket(full: bool) -> void:
	for g in game.guests:
		if g.state == "ordering":
			game.serving.take_orders(g.table)
	if game.tickets.is_empty():
		return
	var pass_st: Station = game.stations[Vector2i(4, 3)]
	if full:
		# Every dish of the first ticket, made and plated, carried on a tray.
		var ds: Array = []
		for it: Dictionary in game.tickets[0].items:
			var d := Dish.make(Tray.vessel_of(it))
			for ing: String in it.ingredients:
				d.add(Tray.kind("prep", ing), 1.0)
			ds.append(d)
		game.player.set_held("dishes", 1.0, ds, true)
		game.player.position = Grid.center(Vector2i(2, 5))
		game.player.look(Vector2i(0, 1))
	else:
		# A cooked patty with a bun on it, waiting for the plate in hand.
		var d := Dish.new()
		d.add("prep:" + GameWorld.fixed_main().grill, 1.0)
		d.add("prep:" + GameWorld.fixed_main().bread, Prep.PLAIN)
		pass_st.set_dish(d)
		game.world.find_station("stove").set_item("raw:" + GameWorld.fixed_main().grill)
		game.world.find_station("stove").cook = 3.0
		game.player.position = Grid.center(Vector2i(3, 3))
		game.player.look(Vector2i(1, 0))
		game.player.take_dish(Dish.make(Dish.PLATE))   # "Plate it"
	game.hud.day_ui.refresh_tickets()


## The chef at (1, 4) facing a tool at (2, 4) (and a second at (2, 5) where the
## tool has two looks), the minigame stopped part-way so a shot can catch it.
func _demo_prep(which: String) -> void:
	game.player.position = Grid.center(Vector2i(1, 4))
	game.player.look(Vector2i(1, 0))
	var at := Vector2i(2, 4)
	var use: Dictionary = Game.DEMO_PREP.get(Scenery.theme_id, Game.DEMO_PREP.diner)
	match which:
		"grill":
			var st := game.world.find_station("stove")
			st.set_item("raw:" + GameWorld.fixed_main().grill)
			st.cook = 5.0
			game.player.position = Grid.center(Vector2i(1, 3))
			game.player.look(Vector2i(-1, 0))
		"fry":
			game.world.add_station("fryer", at, 1, 1).set_item("raw:" + use.fry)
			game.stations[at].cook = 1.0
			var rack := game.world.add_station("fryer", at + Vector2i(0, 1), 1, 1)
			rack.lift_to_rack("prep:" + use.fry, Prep.GOOD, "good")
			rack.rest = Prep.FRY_REST * 0.6
		"boil":
			game.world.add_station("pot", at, 1, 1).set_item("raw:" + use.boil)
			game.stations[at].cook = 1.0
			game.world.add_station("pot", at + Vector2i(0, 1), 1, 1).set_item("prep:" + use.boil)
		"chop", "slice", "pour":
			var ing: String = use[which]
			var type: String = {"chop": "board", "slice": "slicer", "pour": "wine_barrel" if ing == "wine" else "fountain"}[which]
			game.prep_games.start_prep(0, game.world.add_station(type, at, 1, 1), which, ing)
			var s: Dictionary = game.preps[0]
			s.frozen = true
			match which:
				"chop":
					s.t = Prep.CHOP_SWEEP_TIME * 1.3
					s.hits = [true]
				"slice":
					s.t = Prep.SLICE_TIME * 0.45
					s.presses = 4
				"pour":
					s.fill = 0.72
			game.prep_games._show_prep(0)
		"grate", "saw", "juice", "blend", "steam":   # PRD 8.6
			var ing: String = Game.DEMO_PREP_NEW.get(Scenery.theme_id, Game.DEMO_PREP_NEW.diner)[which]
			var src := Pantry.source_of(ing)
			var held := Tray.kind("prep" if src != ing and not Pantry.needs_prep(src) else "raw", src)
			game.world.add_station("counter", at, 1, 1)
			var st := game.world.add_station(str(Pantry.TOOL_STATION[which]), at, 1, 1)
			game.prep_games.start_prep(0, st, which, ing, held)
			var s: Dictionary = game.preps[0]
			s.frozen = true
			match which:
				"grate":
					s.t = 1.4
					s.v = 0.6
					s.fill = 0.55
				"saw":
					s.t = s.sweep * 1.6
					s.hits = [true]
				"juice":
					s.t = 1.5
					s.fill = 0.55
					s.hits = [true]
				"blend":
					s.t = 1.2
					s.presses = 4
					s.w = 0.55
				"steam":
					s.t = Prep.steam_time(s.q) * 0.62
			game.prep_games._show_prep(0)
		"good", "bad":
			game.player.set_held("prep:" + use.chop, Prep.GOOD if which == "good" else Prep.BAD)
			game.world.add_station("board", at, 1, 1)
			game.player.look(Vector2i(0, 1))
			PrepWidget.pop(game.stations[at], Vector3(0, 2.0, 0), which)
			game.player.boost("burst" if which == "good" else "penalty")
			game.player.boost_left = 999.0


func _demo_kind(offer: bool) -> void:
	for g in game.guests:
		if g.seated_waiting():
			game.serving.take_orders(g.table)
			if offer:
				game.cooking.use_station(g.table)
				return
			g.mood.patience = 0.3
			game.player.position = Grid.center(g.table.cell + Vector2i(0, 1))
			game.player.look(Vector2i(0, -1))
			return


func _demo_comp(offer: bool) -> void:
	for g in game.guests:
		if g.seated_waiting():
			game.serving.take_orders(g.table)
			if offer:
				game.cooking.use_station(g.table)
				return
			game.town.people[g.idx].deals = Town.EXPECT_AT
			g.mood.offer_discount()
			g.mood.patience = 0.15
			g.mood.disgust = 0.5
			g.mood.think("Nobody has cleared that table")
			game.player.position = Grid.center(g.table.cell + Vector2i(0, 1))
			game.player.look(Vector2i(0, -1))
			game.hud.show_guest(g)
			return


func _demo_mood() -> void:
	var seated: Array[Guest] = []
	for g in game.guests:
		if g.seated_waiting():
			seated.append(g)
	if seated.size() < 2:
		return
	var feel := [[1.0, 1.0], [0.0, 0.1]]   # joy and patience: content, then fed up
	for i in 2:
		var g := seated[i]
		game.serving.take_orders(g.table)
		g.mood.joy = feel[i][0]
		g.mood.patience = feel[i][1]
		g.mood.disgust = 0.0
		game.serving.serve(g, game.serving.full_tray_for(g, 1.0 if i == 0 else 0.7))
	game.day.inspect(seated[0])


func _demo_fx() -> void:
	var seated: Array[Guest] = []
	for g in game.guests:
		if g.seated_waiting():
			seated.append(g)
		elif g.state == "queue":
			g.mood.patience = 0.5                 # Zzz bubble
	if seated.size() > 0:
		game.serving.serve(seated[0], game.serving.full_tray_for(seated[0]))   # stars, heart, chewing, a half-eaten tray
		seated[0].timer = 2.0                     # then the coin and a dirty plate
	if seated.size() > 1:
		seated[1].mood.patience = 0.0             # walkout: anger mark and a stamp
	if seated.size() > 2:
		seated[2]._gross_time = 6.0               # green cloud
	game.menu_stock.storage_of(GameWorld.fixed_main().grill).used()
	game.audio.burst(game.world.find_station("sink").position + Vector3(0, 1.15, 0), "bubbles", 0.4)


## night_clean demo: a loose plate on one counter and a patty on another, for the nightfall tidy to move.
func leftovers_on_counters() -> void:
	var n := 0
	for st: Station in game.stations.values():
		if st.type != "counter" or st.item != "" or st.has_node("till"):
			continue
		if n == 0:
			st.set_dish(Dish.make(Dish.PLATE))
		elif n == 1:
			st.set_item("raw:patty")
		else:
			break
		n += 1
