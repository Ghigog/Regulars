class_name GameDemos
extends RefCounted
## Screenshot demos: _apply_demo reads REGULARS_DEMO and sets the moment up.
## This file has the dispatcher and the kitchen, storage, wall, tree, cleaning and staff scenes;
## demo_scenes.gd has building, menu, paying, orders, prep and guest-mood scenes.

var game: Game


func _init(game_: Game) -> void:
	game = game_


## The slip demo: the first guest inside goes down on a level 4 cell, the friend beside them.
func _demo_slip() -> void:
	var party: Array = game.guests.filter(func(o: Guest) -> bool: return o.state == "to_seat")
	if party.is_empty():
		return
	var c := Vector2i(7, 4)   # open floor between the tables, in plain view
	for d in [Vector2i.ZERO, Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		if not game.grid.is_blocked(c + d) and game.plan.floors.has(c + d):
			c += d
			break
	for i in 4:
		game.floor_dirt.mess.add_dirt(c)
	var g: Guest = party[0]
	g.position = Grid.center(c) + Vector3(-0.3, 0, 0.3)
	g.cell = c
	g._body.rotation.y = -PI / 4   # so they fall across the screen, the puddle in front of them
	if party.size() > 1:   # the friend a step behind, who saw it
		var o: Guest = party[1]
		o.position = Grid.center(c) + Vector3(-0.6, 0, -1.0)   # behind, on the side they help from
		o.cell = Grid.to_cell(o.position)
	game.floor_dirt.slip(g, c)


## The cleaning demos (PRD 9.4). "mop": in service, a mop bucket and a sponge on its hook,
## the chef mid-clean along a trail of dirt with a mop gone dirty (shoot at 3). "robot":
## the robot sweeper drifting from its dock to a puddle (shoot at about 4).
## "mop_night": at night a table moved off the dirt under it, the chef mopping it (shoot at 3).
func _demo_mop(demo: String) -> void:
	game.arrivals.assign([{"time": 99999.0, "idx": 0}])   # keeps the day open, nobody comes
	game.floor_dirt.drops = false
	game.floor_dirt.sync_room()
	var m := game.floor_dirt.mess
	var at := Vector2i(1, 6)
	for c: Vector2i in [Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(1, 5), Vector2i(3, 5)]:
		if not game.stations.has(c) and game.grid.can_place_block(c, [], Game.LOT, Game.DOOR, game.placing._reach(), game.placing._touch()):
			at = c   # out of everyone's way
			break
	var bucket := game.world.add_station("mop_bucket", at)
	game.clean_kit.on_built(bucket, "mop_bucket")
	for c: Vector2i in game.kitchen.wall_cells:
		if not game.stations.has(c) and game.kitchen.can_hang(c, "hook"):
			game.clean_kit.on_built(game.world.add_high("hook", c), "sponge")
			break
	match demo:
		"mop":
			for d: Array in [[Vector2i(5, 3), 1], [Vector2i(5, 4), 3], [Vector2i(6, 4), 2], [Vector2i(7, 4), 4]]:
				for i in d[1]:
					m.add_dirt(d[0])
			game.player.position = Grid.center(Vector2i(5, 3)) + Vector3(0.1, 0, -0.1)
			game.player.look(Vector2i(0, 1))
			game.clean_kit.keep(bucket, "", 0)   # the mop is out, in the chef's hands
			CleanKit.hold(game.player, "mop", CleanTools.dirty_after("mop"))
			game.clean_kit.put_down("sponge", 1, Vector2i(6, 3))   # left lying about, in the way
		"robot":
			game.world.add_station("robot_dock", Vector2i(5, 6))
			for i in 3:
				m.add_dirt(Vector2i(7, 4))
			game.player.position = Grid.center(Vector2i(2, 4))
		"mop_night":
			game.ledger.record_sale(Game.DEMO_BILL, 5)
			for i in 3:
				m.add_dirt(Vector2i(6, 5))   # under the table by the door: out of reach in service
			m.add_dirt(Vector2i(6, 4))
			game.arrivals.clear()
			game.get_tree().create_timer(1.0).timeout.connect(func() -> void:
				game.session.open_build()
				game.placing.pick_up(Grid.center(Vector2i(6, 5)))
				var spots: Array = game.plan.floors.keys().filter(func(c: Vector2i) -> bool: return c.x >= 5 and c != Vector2i(6, 5))
				spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
					return (a - Vector2i(6, 5)).length_squared() > (b - Vector2i(6, 5)).length_squared())   # well away
				for c: Vector2i in spots:
					if game.placing.place(Vector3i(c.x, c.y, 0)):
						break   # moved aside: the dirt under it can be reached
				game.player.position = Grid.center(Vector2i(6, 4)) + Vector3(0, 0, -0.2)
				game.player.look(Vector2i(0, 1))
				game.clean_kit.keep(bucket, "", 0)
				CleanKit.hold(game.player, "mop", 1)
				game.hud.hints_ui.show_build())


## PRD 9.6: the mop bucket's tree in a row along the front, each with its own mop (plain,
## sponge-head, flat, wringer, the scrubber parked by its pail, a little dirty where it
## shows), the robot's dock; the small tools on hooks; a hood beside an extractor over the
## stoves; the chef pushing a scrubber through a trail of dirt (shoot at 3).
func _demo_mop_line() -> void:
	game.arrivals.assign([{"time": 99999.0, "idx": 0}])   # keeps the day open, nobody comes
	game.floor_dirt.drops = false
	game.floor_dirt.sync_room()
	var line: Array = [["mop_bucket", 2], ["sponge_mop", 3], ["flat_mop", 2], ["wringer_bucket", 0], ["cleaner_bucket", 0], ["strong_bucket", 0], ["scrubber", 0]]
	var x := 4
	for b: Array in line:
		var c := Vector2i(x, 6)
		x += 1
		if game.stations.has(c) or not game.plan.floors.has(c):
			continue
		var st := game.world.add_station(b[0], c)
		game.clean_kit.on_built(st, b[0])
		game.clean_kit.keep(st, st.kit_tool, b[1])
	if not game.stations.has(Vector2i(x, 6)) and game.plan.floors.has(Vector2i(x, 6)):
		game.world.add_station("robot_dock", Vector2i(x, 6))
	var hooks := 0
	for c: Vector2i in game.kitchen.wall_cells:
		if hooks >= 4 or game.stations.has(c) or game.highs.has(c) or not game.kitchen.can_hang(c, "hook"):
			continue
		game.clean_kit.keep(game.world.add_high("hook", c), ["sponge", "scourer", "grease_scraper", "spill_kit"][hooks], 0)
		hooks += 1
	var hood := Vector2i(0, 4)
	if game.highs.has(hood) and game.kitchen.hood_at(hood) == "hood":   # the second hood, up its tree
		game.kitchen.remove(hood, "high")
		(game.highs[hood] as Station).queue_free()
		game.highs.erase(hood)
		game.world.add_high("extractor", hood)
	for d: Array in [[Vector2i(7, 4), 2], [Vector2i(7, 3), 3], [Vector2i(7, 2), 4]]:
		for i in d[1]:
			game.floor_dirt.mess.add_dirt(d[0])
	game.player.position = Grid.center(Vector2i(7, 5))
	game.player.look(Vector2i(1, 0))
	CleanKit.hold(game.player, "scrubber", 0)
	game.floor_dirt.redraw()


## Dev aid for screenshots: REGULARS_DEMO=cook or =summary jumps to that moment.
func _apply_demo(demo: String) -> void:
	if demo == "cook":   # a patty on the grill, the chef with a plate for it
		game.world.find_station("stove").set_item("raw:" + GameWorld.fixed_main().grill)
		game.world.find_station("stove").cook = -8.2
		game.player.position = Grid.center(Vector2i(1, 3))
		game.player.look(Vector2i(-1, 0))
		game.player.take_dish(Dish.make(Dish.PLATE))
		for a in game.arrivals:
			a.time = 1.0
	elif demo in ["helpers", "helpers_break", "helpers_slip"]:   # PRD 10.6/10.8: staff at work; see Crew.crew_demos.demo
		game.crew.crew_demos.demo(demo)
	elif demo.begins_with("pay_"):   # PRD 11: paying the bill; see _demo_pay
		game.demo_scenes._demo_pay(demo)
	elif demo == "staff_only":   # PRD 10.7: a busy day run by helpers alone; see Crew.crew_demos.staff_only
		game.ledger.day = 8
		game.flyers_out = true
		game.crew.crew_demos.staff_only()
	elif demo == "dirt":  # every level of floor dirt, footprints, guests slowed tracking it in; shoot at about 7
		game.floor_dirt.sync_room()
		var m := game.floor_dirt.mess
		for lvl in range(1, 5):   # a few drops, a puddle, a big puddle, the whole cell, along the front
			for i in lvl:
				m.add_dirt(Vector2i(4 + lvl, 6))
		for i in 4:
			m.add_dirt(Game.ENTRANCE_CELL)   # the whole cell inside the door: guests track it in, slowed
		for i in 2:
			m.add_dirt(Vector2i(2, 3))   # grease by the stove
		game.floor_dirt.prints[Vector2i(2, 3)] = Vector2i(0, 1)
		game.arrivals.resize(mini(game.arrivals.size(), 2))
		for a in game.arrivals:
			a.time = 0.5
	elif demo in ["mop", "robot", "mop_night"]:  # PRD 9.4: see _demo_mop
		_demo_mop(demo)
	elif demo == "mop_line":  # PRD 9.6: see _demo_mop_line
		_demo_mop_line()
	elif demo in ["treat", "treat_day", "tree_box", "tree_bucket", "tree_sponge"]:  # PRD 9.5: see _demo_treat
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.arrivals.clear()
		game.get_tree().create_timer(1.0).timeout.connect(_demo_treat.bind(demo))
	elif demo == "slip":  # a guest down on a level 4 cell, dizzy, a friend who saw it helping them up; shoot at about 7.5
		game.arrivals.clear()
		game.arrivals.append({"time": 0.2, "group": [0, 1]})
		game.get_tree().create_timer(5.5).timeout.connect(_demo_slip)
	elif demo == "messy":  # a sink piled with washing-up and an overflowing bin; shoot at about 10
		var sink := game.world.find_station("sink")
		sink.dirty = 4
		sink.refresh()
		game.world.find_station("plates").count = 0
		game.world.find_station("plates").refresh()
		var bin := game.world.find_station("bin")
		bin.count = Station.BIN_HOLDS
		bin.refresh()
		game.player.position = Grid.center(Vector2i(2, 4))
		game.player.set_held("rubbish_bag")
		for a in game.arrivals:
			a.time = 0.5
	elif demo == "lineup":  # every townsperson and every face, close up
		game.arrivals.clear()
		game.phase = Game.Phase.SUMMARY
		game.cam.size = 6.5
		game.cam.position += Vector3(3.4, 0, -1.5)
		var names: Array = Peg.LOOKS.keys()
		for i in names.size():
			var p := Peg.guest(names[i])
			p.position = Vector3(10.6 + (i / 7) * 1.1 - (i % 7) * 0.25, 0, 7.4 - (i % 7) * 1.0 - (i / 7) * 0.5)
			p.rotation.y = PI / 4
			p.pose = ["idle", "carry", "tap", "wave"][i % 4]
			game.add_child(p)
		for i in Peg.FACES.size():
			var p := Peg.guest(names[i + 3])
			p.set_face(Peg.FACES[i])
			p.position = Vector3(13.2 - i * 0.3, 0, 7.2 - i * 0.95)
			p.rotation.y = PI / 4
			game.add_child(p)
		for i in 4:
			var c := Peg.chef(i)
			c.position = Vector3(15.0 - i * 0.6, 0, 3.4 - i)
			c.rotation.y = PI / 4 + i * PI / 2
			game.add_child(c)
	elif demo == "fx":  # fires every effect in turn; shoot at about 6.5 and 8.4
		for a in game.arrivals:
			a.time = 0.2
		while game.arrivals.size() < 8:
			game.arrivals.append({"time": 0.2, "idx": game.arrivals.size()})
		game.get_tree().create_timer(6.0).timeout.connect(game.demo_scenes._demo_fx)
	elif demo == "order":  # a table waiting to order, then the chef taking it; shoot at about 9 and 10.5
		for a in game.arrivals:
			a.time = 0.2
		game.get_tree().create_timer(8.0).timeout.connect(game.demo_scenes._demo_order.bind(false))
		game.get_tree().create_timer(9.5).timeout.connect(game.demo_scenes._demo_order.bind(true))
	elif demo == "ticket" or demo == "tray":  # two tickets on the rail and a bun on a patty waiting for a plate; or a whole order carried on a tray. Shoot at 10
		for a in game.arrivals:
			a.time = 0.2
		game.get_tree().create_timer(8.0).timeout.connect(game.demo_scenes._demo_ticket.bind(demo == "tray"))
	elif demo.begins_with("prep_"):  # a minigame mid-play at the chef's tool (frozen there); shoot at 2
		game.demo_scenes._demo_prep(demo.trim_prefix("prep_"))
	elif demo == "kind":  # an impatient guest and the half-price prompt; shoot at about 9 and 10.5
		for a in game.arrivals:
			a.time = 0.2
		game.get_tree().create_timer(8.0).timeout.connect(game.demo_scenes._demo_kind.bind(false))
		game.get_tree().create_timer(9.5).timeout.connect(game.demo_scenes._demo_kind.bind(true))
	elif demo == "comp":  # a fed-up guest who expects deals, then the free meal; shoot at about 9 and 10.5
		for a in game.arrivals:
			a.time = 0.2
		game.get_tree().create_timer(8.0).timeout.connect(game.demo_scenes._demo_comp.bind(false))
		game.get_tree().create_timer(9.5).timeout.connect(game.demo_scenes._demo_comp.bind(true))
	elif demo == "mood":  # a content and a fed-up guest, both served at 8 with the content one's card open;
		# shoot at 9 (card), 12.4 (the fed-up guest pays less) and 15.7 (the content one pays more)
		for a in game.arrivals:
			a.time = 0.2
		game.get_tree().create_timer(8.0).timeout.connect(game.demo_scenes._demo_mood)
	elif demo == "inspect":  # a seated guest with a few thoughts and their card open; shoot at 10
		for a in game.arrivals:
			a.time = 0.2
		game.get_tree().create_timer(9.0).timeout.connect(func() -> void:
			for g in game.guests:
				if g.seated_waiting():
					g.mood.patience = 0.4
					g.mood.disgust = 0.25
					g.mood.think("Nobody has cleared that table")
					game.day.inspect(g)
					return)
	elif demo == "tolerance":  # a seated guest who hates to wait and doesn't mind a mess, card open; shoot at 10
		for a in game.arrivals:
			a.time = 0.2
		game.get_tree().create_timer(9.0).timeout.connect(func() -> void:
			for g in game.guests:
				if g.seated_waiting():
					g.mood.tolerance = {"food": 3, "service": 1, "clean": 5}
					g.mood.patience = 1.0
					g.mood.wait(0.5 * Guest.QUEUE_PATIENCE, Guest.QUEUE_PATIENCE)   # a long wait, felt hard
					g.mood.see_gross(0.05, 0.5, "Nobody has cleared that table")   # shrugged off
					game.day.inspect(g)
					return)
	elif demo == "walkon":  # a pair who find nothing they like turn away at the door; shoot at about 7
		for i in [0, 1]:
			(game.town.people[i].dislikes as Array).append("patty")
		game.arrivals.clear()
		game.arrivals.append({"time": 0.2, "group": [0, 1]})
		game.arrivals.append({"time": 2.5, "idx": 2})
		(game.town.people[2].dislikes as Array).erase("patty")
		(game.town.people[2].dislikes as Array).erase("bun")
	elif demo == "orders_card":  # a seated guest's card with their orders so far, one item renamed; shoot at 10
		for a in game.arrivals:
			a.time = 0.2
		game.get_tree().create_timer(9.0).timeout.connect(func() -> void:
			for g in game.guests:
				if g.seated_waiting():
					var burger: int = game.menu.items[0].id
					var fries := game.menu.add("side", ["potato"], "Fries")
					for k in 3:
						game.town.record_order(g.idx, burger)
					game.town.record_order(g.idx, int(fries.id))
					game.town.record_order(g.idx, int(fries.id))
					game.menu.rename(burger, "Stupid Burger")   # the counts follow the rename
					game.menu.remove(int(fries.id))             # and a deleted item keeps its last name
					g.mood.think(Menu.LIKED_THOUGHT)
					game.day.inspect(g)
					return)
	elif demo == "pause":  # the pause menu over the room
		game.hud.options_ui.toggle_pause()
		game.get_tree().paused = false   # so the screenshot timer still runs
	elif demo == "options" or demo == "options_gfx":  # the options screen, on either tab
		game.hud.options_ui._options_tab = "graphics" if demo == "options_gfx" else "audio"
		game.hud.options_ui.toggle_options()
		game.hud.options_ui.options_action("down")   # the highlight on the first slider (keys and pad)
		game.get_tree().paused = false   # so the screenshot timer still runs
	elif demo in ["menu", "menu_name", "restock"]:  # the menu screen; naming an item; the restock note open
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.arrivals.clear()
		game.get_tree().create_timer(1.0).timeout.connect(game.demo_scenes._demo_menu.bind(demo))
	elif demo == "closed":
		game.best_path = "user://regulars_best_demo.json"
		game.ledger.reputation = 0.0   # the meter at the bottom: closed down
	elif demo in ["critic", "critic_bad", "critic_known", "critic_town"]:
		_demo_critic(demo)
	elif demo == "summary" or demo == "town":
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.ledger.record_sale(Game.DEMO_BILL, 3)
		game.ledger.record_unpaid_bill()   # PRD 11: the LEFT UNPAID line and its open-purse stamp
		game.ledger.record_found_nothing(3)
		game.arrivals.clear()
		if demo == "town":  # a spread of opinions, then the town book over the receipt
			for i in game.town.people.size():
				game.town.record_visit(i, [0.9, 0.9, 0.3, -0.5, 0.6][i % 5])
				if i == 0 or i == 5:
					game.town.record_visit(i, 0.9)
					game.town.record_visit(i, 0.9)
				if i == 3:
					game.town.record_walkout(i, 1)
				if i % 2 == 0:
					game.town.record_visit(i, [0.9, -0.5, 0.9][i % 3])
			game.get_tree().create_timer(1.5).timeout.connect(game.hud.screens_ui.show_town)
	elif demo.begins_with("coop"):  # PRD 4: coop (service), coop_build (two ghosts at night), coop_ready (the receipt, one ready)
		var two := game.chefs[game.coop.join("pad:1")]
		game.hud.coop_hint_time = 9999.0
		if demo == "coop":   # two chefs, two bubbles, two hint lines; shoot at about 8
			game.world.find_station("stove").set_item("raw:" + GameWorld.fixed_main().grill)
			game.world.find_station("stove").cook = -8.2
			game.player.position = Grid.center(Vector2i(1, 2))
			game.player.look(Vector2i(-1, 0))   # at the patty fridge, hands free
			two.position = Grid.center(Vector2i(3, 3))
			two.look(Vector2i(1, 0))
			two.set_held(Tray.kind("raw", GameWorld.fixed_main().bread))
			for a in game.arrivals:
				a.time = 1.0
		elif demo == "coop_build":   # shoot at about 3
			game.ledger.money = 300
			game.ledger.xp = 250
			game.arrivals.clear()
			game.get_tree().create_timer(1.0).timeout.connect(_demo_coop_build.bind(two))
		elif demo == "coop_door":   # night: chef 1 has used the door card, chef 2 has not; shoot at about 3
			game.ledger.money = 300
			game.arrivals.clear()
			game.get_tree().create_timer(1.0).timeout.connect(func() -> void:
				game.session.open_build()
				game.player.position = Game.DOORWAY + Vector3(-0.6, 0, -0.3)
				game.player.look(Vector2i(1, 0))
				two.position = Game.DOORWAY + Vector3(-1.2, 0, 0.6)
				two.look(Vector2i(1, 0))
				game.day.use_door(game.player))
		else:   # coop_ready: the receipt, player one ready; shoot at about 4
			game.ledger.record_sale(Game.DEMO_BILL, 5)
			game.ledger.record_sale(Game.DEMO_BILL, 3)
			game.arrivals.clear()
			game.get_tree().create_timer(1.5).timeout.connect(game.coop.confirm_receipt.bind(0))
	elif demo in ["tree", "tree_stove", "tree_counter", "tree_fern", "upgraded", "tree_cut", "jobs"]:   # PRD 8.3 upgrade trees; shoot at 3
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.arrivals.clear()
		game.get_tree().create_timer(1.0).timeout.connect(_demo_tree.bind(demo))
	elif demo == "desk_wages":   # PRD 10.4: the receipt with a STAFF line, one wage unpaid; shoot at 3
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.arrivals.clear()
		_demo_hires()
		game.ledger.money = 40
		game.desk.pay_staff()
	elif demo.begins_with("desk_"):   # PRD 10.3/10.4: desk_line, desk_post, desk_cvs, desk_haggle, desk_staff, desk_raise, desk_restock, desk_fire; shoot at 3
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.arrivals.clear()
		game.get_tree().create_timer(1.0).timeout.connect(_demo_desk.bind(demo))
	elif demo in ["pantry", "storage", "storage_card", "storage_card_up", "storage_fridge", "boxes_open"]:   # PRD 8.4: boxes in counters and a fridge; a counter's storage card; shoot at 3
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.ledger.money = 300
		game.arrivals.clear()
		game.get_tree().create_timer(1.0).timeout.connect(_demo_storage.bind(demo))
	elif demo in ["wall", "wall_build"]:   # PRD 8.5: hoods, cabinets, a closet, a tall fridge; a cabinet's ghost on the wall; shoot at 3
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.ledger.money = 300
		game.arrivals.clear()
		game.get_tree().create_timer(1.0).timeout.connect(_demo_wall.bind(demo))
	elif demo == "counters":   # PRD 8: a double counter, a board on a double counter, a stove on the pass; shoot at 3
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.ledger.money = 300
		game.arrivals.clear()
		game.get_tree().create_timer(1.0).timeout.connect(_demo_counters)
	elif demo.begins_with("build") or demo == "door":  # build (the shop), build_find (a search), build_no (refused spot), build_refused (E pressed on it; shoot at 1.4), build_move, door
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.ledger.money = 300
		game.ledger.xp = 250
		game.arrivals.clear()
		game.get_tree().create_timer(1.0).timeout.connect(game.demo_scenes._demo_build.bind(demo))
	elif demo == "night_clean":  # a messy day carried into the night, the chef with a plate; shoot at 4 and 6
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.arrivals.clear()
		for c: Vector2i in [Vector2i(6, 5), Vector2i(8, 3)]:
			game.stations[c].dirty = 2
			game.stations[c].refresh()
		var sink := game.world.find_station("sink")
		sink.dirty = Station.SINK_PILED
		sink.refresh()
		var bin := game.world.find_station("bin")
		bin.count = Station.BIN_HOLDS
		bin.refresh()
		game.get_tree().create_timer(1.0).timeout.connect(func() -> void:
			game.session.open_build()
			game.player.position = Grid.center(Vector2i(6, 4))
			game.player.look(Vector2i(0, 1))   # at the table by the door: "Clear table"
			game.hud.hints_ui.show_build())
		game.get_tree().create_timer(5.0).timeout.connect(func() -> void:
			game.room_edit.build_interact()              # a plate in hand, carried to the sink
			game.player.position = Grid.center(Vector2i(3, 3))
			game.player.look(Vector2i(0, -1)))
	elif demo == "newday":  # the receipt, then building, then the next day turning over
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.arrivals.clear()
		game.get_tree().create_timer(3.0).timeout.connect(game.session.open_build)
		game.get_tree().create_timer(5.0).timeout.connect(func() -> void:
			game.player.position = Grid.center(Vector2i(Game.W - 1, Game.DOOR.y))
			game.day.use_door())
	elif demo == "close":  # the door card flipped to CLOSED late in the day; shoot at about 3
		for a in game.arrivals:
			a.time = 400.0
		game.seating.spawn_guest(0)
		game.clock = game.day.day_length() * 0.6
		game.player.position = Grid.center(Vector2i(Game.W - 1, Game.DOOR.y))
		game.player.look(Vector2i(1, 0))
		game.get_tree().create_timer(2.0).timeout.connect(game.day.use_door)
	elif demo == "crowd":  # a rush: every table taken and a dozen in line at the door; shoot at about 12
		game.arrivals.clear()
		var n := mini(game.town.people.size(), 20)
		var at := 0.3
		var i := 0
		while i < n:
			var size: int = [2, 1, 3, 1, 2, 4][game.arrivals.size() % 6]
			game.arrivals.append({"time": at, "group": range(i, mini(i + size, n))})
			i += size
			at += 0.9
	elif demo == "walkout":  # one walkout stamped on the card
		for a in game.arrivals:
			a.time = 30.0
		game.get_tree().create_timer(2.0).timeout.connect(game.ledger.record_walkout)
	elif demo == "flyers":
		game.ledger.record_sale(Game.DEMO_BILL, 5)
		game.arrivals.clear()
		game.get_tree().create_timer(1.5).timeout.connect(func() -> void:
			game.session.open_build()
			game.session.open_shop()
			game.hud._set_category("Extras")
			game.placing.buy(Game.FLYERS))


## critic: the receipt of day 5 with a good review that contradicts the town;
## critic_bad: a walkout's review; critic_known: the named critic seated, card open
## (shoot at 10); critic_town: the town book with the critic marked.
func _demo_critic(demo: String) -> void:
	game.ledger.day = 5
	game.ledger.record_sale(Game.DEMO_BILL, 5)
	game.ledger.record_sale(Game.DEMO_BILL, 3)
	for i in game.town.people.size():   # the town thinks the place is dirty and slow
		if i % 3 == 0:
			game.town.record_disgust(i, 2)
		game.town.record_visit(i, 0.5, {"speed": -0.1, "clean": 0.0, "quality": 0.25, "variety": 0.0})
	if demo in ["critic", "critic_bad"]:
		game.arrivals.clear()
		var walked := demo == "critic_bad"
		game._critic_rated = {"walked": walked, "ratings": {"speed": 5, "clean": 5, "quality": 4, "variety": 3}
			if not walked else {"speed": 1, "clean": 2, "quality": 1, "variety": 2}}
		if walked:
			game.ledger.record_walkout()
		return
	game.critic.publish({"speed": 4, "clean": 5, "quality": 4, "variety": 3}, false, game.town, 5)
	game.ledger.end_day()
	if demo == "critic_town":
		game.arrivals.clear()
		game.get_tree().create_timer(1.5).timeout.connect(game.hud.screens_ui.show_town)
		return
	game.arrivals.assign([{"time": 0.2, "group": [game.critic.critic_idx]}])
	game.get_tree().create_timer(9.0).timeout.connect(func() -> void:
		for g in game.guests:
			if game.day.is_critic(g):
				g.mood.think(Critic.thought("gross"))
				game.day.inspect(g)
				return)


## Two chefs at night, each with a piece: chef 1's fits, chef 2's (over a table) does not.
func _demo_coop_build(two: Player) -> void:
	game.session.open_build()
	game.player.position = Grid.center(Vector2i(5, 3))
	game.player.look(Vector2i(1, 0))
	game.placing.pick_catalog(GameWorld.fern(), 1, game.player)
	game.player.demo_hover = Vector3(6.5, 0, 3.5)
	two.position = Grid.center(Vector2i(7, 2))
	two.look(Vector2i(-1, 0))
	game.placing.pick_catalog("counter", 1, two)
	two.demo_hover = Vector3(6.5, 0, 1.5)


## Tools on counters (PRD 8.2), placed through the build flow at night.
func _demo_counters() -> void:
	game.session.open_build()
	for step: Array in [["counter", 2, 5], ["counter", 2, 5], ["board", 2, 5],
			["counter", 3, 4], ["counter", 3, 4]]:
		game.placing.pick_catalog(step[0])
		game.placing.place(Vector3i(step[1], step[2], 0))
		game.placing.cancel_hand()
	game.card.open_storage(Vector2i(4, 3))   # a length of the pass made a stove on its card
	game.card.storage_upgrades()
	game.upgrades.buy_upgrade("stove")
	game.world.find_station("board").set_item(Tray.kind("prep", "lemon" if Scenery.seaside() else "tomato"))   # a tool's surface still holds a thing
	game.player.position = Grid.center(Vector2i(2, 4))
	game.player.look(Vector2i(1, 0))


## Storage (PRD 8.4): "storage" a double counter with two boxes and a board on it, two
## under-counter fridges with the chilled kinds, ready-made in a
## pass counter, and a box held over a counter (its tags show what each cell holds);
## "storage_card" (or "pantry") a plain counter's storage card on Ingredients, the chilled
## kinds dimmed "Needs a fridge"; "storage_card_up" the same card on Upgrades;
## "storage_fridge" the counter upgraded to a fridge while lifted, back on Ingredients.
func _demo_storage(demo: String) -> void:
	game.session.open_build()
	if demo in ["pantry", "storage_card", "storage_card_up", "storage_fridge"]:
		var plain := Game.NO_CELL
		var side := Vector2i(0, 1) if demo == "storage_fridge" else Vector2i(1, 0)   # the fridge's door in view
		for c: Vector2i in game.stations:
			if game.stations[c].type == "counter" and game.stations[c].base == "counter" and not game.stations[c].has_node("till") \
					and not game.stations.has(c + side) and plain == Game.NO_CELL:
				plain = c
		game.player.position = Grid.center(plain + side)
		game.player.look(-side)
		game.card.open_card()   # E: the counter's card opens where it stands
		if demo == "storage_card_up":
			game.card.storage_upgrades()
		elif demo == "storage_fridge":   # upgraded to a fridge on its card, back on its boxes
			game.card.storage_upgrades()
			game.upgrades.buy_upgrade("fridge")
			game.card.storage_ingredients()
			game.card.card_act("turn")   # turned on its card, the door toward the camera
		else:
			game.get_tree().create_timer(0.3).timeout.connect(game.hud.shop_ui.shop_move.bind(1))
		return
	var sea := Scenery.seaside()
	for step: Array in [["counter", 2, 5], ["counter", 2, 5]]:
		game.placing.pick_catalog(step[0])
		game.placing.place(Vector3i(step[1], step[2], 0))
		game.placing.cancel_hand()
	game.menu_stock.stock_box("roll" if sea else "bun", Vector2i(2, 5))
	game.menu_stock.stock_box("courgette" if sea else "lettuce", Vector2i(2, 5))
	game.world.add_station("board", Vector2i(2, 5))
	game.menu_stock.stock_box("calamari" if sea else "cheese", Vector2i(1, 6))   # a second under-counter fridge
	game.menu_stock.stock_box("pepper" if sea else "tomato", Vector2i(4, 5), true)
	if demo == "boxes_open":   # the crates on the counter, and a fridge door caught open at 3
		game.get_tree().create_timer(1.8).timeout.connect(func() -> void: game.world.station_at(Vector2i(1, 6)).used())
		game.get_tree().create_timer(1.8).timeout.connect(func() -> void: game.world.station_at(Vector2i(0, 5)).used())
	else:
		game.placing.pick_catalog("box_lemon" if sea else "box_onion")
	game.player.position = Grid.center(Vector2i(3, 3))
	game.player.look(Vector2i(1, 0))
	game._demo_hover = Vector3(4.5, 0, 3.5)


## The wall layer (PRD 8.5) at night. "wall": the start's hoods over the stoves and
## cabinets by the back door (one holding a box), a low and a high shelf as one closet,
## and the grill fridge turned into a tall fridge. "wall_build": a wall cabinet in hand,
## its ghost hung over the plate stack with the high band lit behind it.
func _demo_wall(demo: String) -> void:
	game.session.open_build()
	var sea := Scenery.seaside()
	var corner := Vector2i(0, 2)
	var fridge: Station = game.stations[corner]
	fridge.set_base("tall_fridge")
	game.kitchen.set_cell(corner, "tall_fridge")
	game.menu_stock.stock_box("cheese" if not sea else "calamari", corner)
	game.world._show_boxes(corner)
	game.world.add_station("shelf", Vector2i(1, 2))
	game.world.add_high("shelf", Vector2i(1, 2))
	game.menu_stock.stock_box("onion" if not sea else "lemon", Vector2i(1, 2))
	game.menu_stock.stock_box("lettuce" if not sea else "courgette", Vector2i(1, 2))
	game.placing._store_box(Vector2i(0, 5), Pantry.box_id("tomato" if not sea else "pepper"))   # into the cabinet over the bin
	game.player.position = Grid.center(Vector2i(2, 4))
	game.player.look(Vector2i(-1, 0))
	if demo == "wall_build":
		game.placing.pick_catalog("cabinet")
		game._demo_hover = Vector3(2.5, 0, 2.5)
	game.hud.hints_ui.show_build()


## The upgrade trees (PRD 8.3): a piece picked up at night and the shop opened.
## "tree" a board in hand; "tree_stove" a stove, the choice scrolled down to the fryer;
## "tree_counter" a counter (its fridge line); "tree_fern" a fern's short tree;
## "upgraded" a row of upgraded pieces standing in the kitchen.
func _demo_tree(demo: String) -> void:
	game.session.open_build()
	game.ledger.money = 300
	game.ledger.xp = 500
	var c := Vector2i(2, 5)
	if demo == "jobs":   # PRD 8.6: the new tools in a row, and the new food on the counters before them
		_demo_jobs()
		game.player.position = Grid.center(Vector2i(4, 6))   # off the row, so no prompt hides a tool
		game.player.look(Vector2i(0, 1))
		game._frame = [Vector3(5.0, 0, 3.2), 6.8, Vector3(5.0, 0, 3.2), 6.8]   # close up, held
		return
	if demo == "upgraded":
		var row := [["counter", "long_counter", Vector2i(1, 5)], ["butcher_block", "counter", Vector2i(2, 5)],
			["auto_slicer", "counter", Vector2i(3, 5)], ["char_grill", "fridge", Vector2i(2, 4)],
			["two_hob_range", "counter", Vector2i(3, 4)], ["twin_fryer", "counter", Vector2i(4, 5)]]
		for spot: Array in row:
			game.world.add_station("counter", spot[2], 1, 0, spot[1])
			if spot[0] != "counter":
				game.world.add_station(spot[0], spot[2])
		game.player.position = Grid.center(Vector2i(2, 6))
		game.player.look(Vector2i(0, -1))
		return
	var piece: String = {"tree": "board", "tree_cut": "board", "tree_stove": "stove", "tree_counter": "", "tree_fern": GameWorld.fern()}[demo]
	if demo == "tree_fern":
		game.world.add_station(piece, c)
	else:
		game.world.add_station("counter", c)
		if piece != "":
			game.world.add_station(piece, c)
	game.player.position = Grid.center(c + Vector2i(0, 1))
	game.player.look(Vector2i(0, -1))
	game.placing.pick_up(Grid.center(c))
	game.session.open_shop()
	if demo == "tree_stove":
		for i in 3:
			game.get_tree().create_timer(0.4 + 0.3 * i).timeout.connect(game.hud.screens_ui.tree_move.bind("down"))
	if demo == "tree_cut":   # PRD 8.6: the whole cutting tree, scrolled down to the bread knife's line
		for i in 2:
			game.get_tree().create_timer(0.4 + 0.2 * i).timeout.connect(game.hud.screens_ui.tree_move.bind("down"))


## The floor treatment and cleaning tree demos (PRD 9.5). "treat": at night, a strip of
## each treatment's sheen, a little dirt on some, the boxes on a counter by the wall with
## their chemical tags, the small tools on their hooks, the chef laying primer (shoot at 3).
## "treat_day": the same laid for service, the sheens in force (shoot at 3). "tree_box",
## "tree_bucket", "tree_sponge": the tree of a cleaner's box, a mop bucket, a sponge's hook.
func _demo_treat(demo: String) -> void:
	game.session.open_build()
	game.ledger.money = 600
	game.ledger.xp = 500
	game.floor_dirt.drops = false
	var shelf := Vector2i(2, 5)
	game.world.add_station("counter", shelf, 1, 0, "double_counter")
	var keys: Array = Treatments.ITEMS.keys()
	for k: String in ["cleaner", "finish"]:
		game.placing._store_box(shelf, Treatments.box_id(k))
	var hooks := 0
	for c: Vector2i in game.kitchen.wall_cells:
		if hooks >= 4 or game.stations.has(c) or game.highs.has(c) or not game.kitchen.can_hang(c, "hook"):
			continue
		game.clean_kit.keep(game.world.add_high("hook", c), ["sponge", "scourer", "grease_scraper", "spill_kit"][hooks], 0)
		hooks += 1
	if demo.begins_with("tree_"):
		var at := Vector2i(5, 4)
		game.player.position = Grid.center(at + Vector2i(0, 1))
		game.player.look(Vector2i(0, -1))
		match demo:
			"tree_box":
				game.kitchen.unstore(shelf, "box_finish")
				game.placing.pick_up(Grid.center(shelf))   # the cleaner's box
				game.placing._store_box(shelf, "box_finish")
			"tree_bucket":
				game.clean_kit.on_built(game.world.add_station("mop_bucket", at), "mop_bucket")
				game.placing.pick_up(Grid.center(at))
			"tree_sponge":
				var w: Vector2i = game.highs.keys().filter(func(c: Vector2i) -> bool: return (game.highs[c] as Station).kit_tool == "sponge")[0]
				game.placing.pick_up(Grid.center(w))
		game.session.open_shop()
		return
	var row: Array = game.plan.floors.keys().filter(func(c: Vector2i) -> bool:
		return c.x >= 7 and c.y >= 4 and not game.grid.is_blocked(c) and not game.grid.reserved.has(c))
	row.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for i in mini(keys.size(), row.size()):
		game.treat_laid[row[i]] = keys[i]
		if i % 2 == 1:   # a puddle on every other one: dirt shows more on a shine
			game.floor_dirt.mess.add_dirt(row[i])
			game.floor_dirt.mess.add_dirt(row[i])
	game.treat_off["sealing_primer"] = true   # dimmed: switched off
	game.player.position = Grid.center(Vector2i(3, 3))
	game.player.look(Vector2i(1, 0))
	game.placing.pick_catalog("treat_cleaner")
	game.player.drag = {"from": Grid.center(Vector2i(3, 2)), "remove": false}
	game.player.demo_hover = Grid.center(Vector2i(4, 2))
	if demo == "treat_day":
		for k: String in keys:
			if not game.kitchen.stocked().has(Treatments.box_id(k)):
				var c := Vector2i(1, 5) if k.contains("primer") else Vector2i(3, 5)
				if not game.stations.has(c):
					game.world.add_station("counter", c, 1, 0, "double_counter")
				game.placing._store_box(c, Treatments.box_id(k))
		game.treat_off.clear()
		game.placing.cancel_hand()
		game.player.demo_hover = Vector3.INF
		game.day.start_day()
		game.arrivals.assign([{"time": 99999.0, "idx": 0}])   # keeps the day open, nobody comes
	game.floor_dirt.redraw()


## PRD 8.6: the new jobs' tools along the back (cutting, heat and pour lines), and
## counters in front holding each new kind, raw and made, so their models can be checked.
func _demo_jobs() -> void:
	var diner := Scenery.theme_id != "seaside"
	var tools := ["grater", "rotary_grater", "bread_knife", "juicer", "blender", "steamer",
		"coffee_machine" if diner else "beer_tap", "two_tap_fountain" if diner else "wine_rack"]
	var spots := [Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2), Vector2i(5, 3), Vector2i(6, 3),
		Vector2i(7, 3), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 2)].filter(func(c: Vector2i) -> bool: return not game.stations.has(c))
	for i in tools.size():
		game.world.add_station("counter", spots[i])
		game.world.add_station(tools[i], spots[i])
	var shown: Array[String] = []   # each new kind made, then each source raw
	for k: String in Pantry.for_theme(Scenery.theme_id):
		if Pantry.tool_of(k) in Game.DEMO_PREP_NEW.diner or k in ["cola", "coffee", "red_wine", "ale", "ice_cream"]:
			shown.append(Tray.kind("prep", k))
	for k: String in Pantry.for_theme(Scenery.theme_id):
		if Pantry.tool_of(k) in Game.DEMO_PREP_NEW.diner and Pantry.needs_prep(Pantry.source_of(k)):
			var raw := Tray.kind("raw", Pantry.source_of(k))
			if not shown.has(raw):
				shown.append(raw)
	var free := []
	for z in range(3, 7):
		for x in range(1, 4):
			if not game.stations.has(Vector2i(x, z)):
				free.append(Vector2i(x, z))
	for i in mini(shown.size(), free.size()):
		game.world.add_station("counter", free[i])
		game.stations[free[i]].set_item(shown[i])
	game.player.position = Grid.center(Vector2i(6, 5))
	game.player.look(Vector2i(0, -1))


## PRD 10.3. Two desks along the front wall and a grill cook's post up; the town warmed
## up so applicants come. desk_line: the room, the line outside, the pile on the desk and
## the chef at the desk. desk_post: writing a post. desk_cvs: the pile, the top CV half
## dragged right. desk_haggle: a low offer refused.
func _demo_desk(demo: String) -> void:
	for c: Vector2i in [Vector2i(8, 6), Vector2i(9, 6)]:
		game.world.add_station("desk", c)
	if demo in ["desk_staff", "desk_raise", "desk_restock", "desk_fire"]:   # PRD 10.4: three hires, the week of days 6 to 10
		for c: Vector2i in [Vector2i(7, 6), Vector2i(6, 6)]:
			game.world.add_station("desk", c)
		_demo_hires()
		game.ledger.day = 6   # a new week: everyone picks their days off as the build phase opens
		game.session.open_build()
		if demo == "desk_restock":
			game.hud.menu_notes.open = true
			game.player.position = Grid.center(Vector2i(1, 5))
			game.player.look(Vector2i(0, 1))
			game.hud.hints_ui.show_build()
			return
		game.desk.open_desk()
		game.hud.desk.show_tab("staff")
		if demo == "desk_raise":
			var person: int = game.staff.employees.keys()[0]
			game.hud.desk.staff_ui.open_person(person)
			var e: Dictionary = game.staff.employee(person)
			e.pending = {"duty": "wash_up", "raise": 3, "haggle": game.staff._new_haggle(int(e.wage) + 3)}
			game.hud.desk.pages.render()
		elif demo == "desk_fire":   # PRD 10.8: the fed-up washer opened, both fire buttons out
			game.hud.desk.staff_ui.open_person(game.staff.employees.keys()[2])
			game.hud.desk.staff_ui._set_firing(true)
		return
	game.staff.add_post("Grill cook", ["grill", "fetch", "assemble"], 1, 1, game.desk.desk_count())
	for p in game.town.people:
		p.affinity = 0.5
	game.session.open_build()
	if demo == "desk_line":
		game.player.position = Grid.center(Vector2i(7, 6))
		game.player.look(Vector2i(1, 0))
		return
	game.desk.open_desk()
	if demo == "desk_post":
		game.hud.desk.draft_post("Dish washer", ["wash_up", "empty_bin", "clear_tables"], 2, 1)
		game.hud.desk.select("duty:take_orders")
	elif demo == "desk_cvs":
		game.hud.desk.show_tab("cvs")
		game.get_tree().create_timer(0.6).timeout.connect(game.hud.desk.drag_to.bind(120.0))
	elif demo == "desk_haggle":
		game.hud.desk.show_tab("cvs")
		game.hud.desk.start_haggle()
		game.staff.rng.seed = 3
		game.hud.desk.posting.make_offer(maxi(1, int(game.staff.cvs[0].ask) / 2))


## Three hires for the staff demos: a happy grill cook, a so-so server and a fed-up
## washer two nights from quitting.
func _demo_hires() -> void:
	for h: Array in [[2, "Grill cook", ["grill", "fetch", "assemble"], 1, 1, 0.85, 0],
			[5, "Server", ["take_orders", "take_payment", "carry_trays", "clear_tables"], 2, 2, 0.5, 0],
			[9, "Washer", ["wash_up", "empty_bin"], 0, 1, 0.12, 2]]:
		var pid := game.staff.add_post(h[1], h[2], h[3], h[4], 99)
		var cv := game.staff._make_cv(h[0], Staff.skills_from(game.town.people[h[0]].tolerance), game.town.rating(h[0]), 1.0, pid)
		game.staff.cvs.append(cv)
		game.staff.hire(cv.id, -1, 1)
		game.staff.employee(h[0]).satisfaction = h[5]
		game.staff.employee(h[0]).bottom_nights = h[6]
