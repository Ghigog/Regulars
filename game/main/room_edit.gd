class_name GameRoomEdit
extends RefCounted
## Building the room: floors, walls and doors laid and removed (also by drag), the build
## prompt and E at night, the placement ghost and the build-tool ghost, night cleaner, flyers.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- building the room

## One tile, wall, door or archway from the tool in hand, if it fits and can be
## paid for. Keeps the grid in step; the room is redrawn by the caller.
func _build_at(spot: Vector3i, ch: Player = null) -> bool:
	ch = game._me(ch)
	if not game.placing.can_place(spot, ch) or not game.ledger.spend(int(ch.hand.price)):
		return false
	var cell := Vector2i(spot.x, spot.y)
	match GamePlacing.tool_kind(ch.hand.id):
		"floor":
			var was := game.plan.kind(cell)
			if was != "":   # laying over another floor: the old one is taken up and paid back
				game.ledger.refund(Catalog.price_of("floor_" + was))
			for what: String in game.plan.lay(cell, GamePlacing.floor_kind(ch.hand.id)).values():
				game.ledger.refund(Catalog.price_of(what))
		"wall":
			game.plan.build(spot)
		"finish":
			var was := game.plan.finish(spot, ch.hand.id)
			if was != "":   # papering over paint: the old finish is paid back
				game.ledger.refund(Catalog.price_of(was))
		"door", "arch":
			var had := game.plan.strip(spot)
			if had != "":
				game.ledger.refund(Catalog.price_of(had))
			game.plan.openings[spot] = ch.hand.id
		"treat":   # laid free: its price is paid at the door each night it is re-laid
			game.treat_laid[cell] = Treatments.key_of(ch.hand.id)
			game.floor_dirt.redraw()
			game.menu_stock.menu_changed()
			return true
	game.world._sync_grid()
	return true


## Takes away the floor, built wall or opening at a spot, for the tool in hand,
## and pays back what it cost. Refused if it would cut anyone off.
func remove_at(spot: Vector3i, ch: Player = null) -> bool:
	ch = game._me(ch)
	if game.phase != Game.Phase.BUILD or ch.hand.is_empty() or not Catalog.is_build_tool(ch.hand.id):
		return false
	var cell := Vector2i(spot.x, spot.y)
	match GamePlacing.tool_kind(ch.hand.id):
		"treat":   # lifted: bare from tomorrow
			if not game.treat_laid.has(cell):
				return false
			game.treat_laid.erase(cell)
			game.floor_dirt.redraw()
			game.menu_stock.menu_changed()
			return true
		"floor":
			if not game.plan.has_floor(cell) or cell == Game.ENTRANCE_CELL or game.stations.has(cell) or game.highs.has(cell) \
					or game.grid.reserved.has(cell) or game.chefs.any(func(o: Player) -> bool: return o.cell() == cell) or game.placing.rug_at(cell) != null:
				return false
			for e in Floorplan.cell_edges(cell):
				if game.wall_nodes.has(e):
					return false
			game.grid.outside[cell] = true
			var ok := game.grid.layout_ok(Game.DOOR, game.placing._reach(), game.placing._touch())
			game.grid.outside.erase(cell)
			if not ok:
				return false
			game.ledger.refund(Catalog.price_of("floor_" + game.plan.kind(cell)))
			for e in Floorplan.cell_edges(cell):
				if game.plan.built.has(e):
					game.ledger.refund(Catalog.price_of("wall"))
			for what: String in game.plan.lift(cell).values():
				game.ledger.refund(Catalog.price_of(what))
		"wall":
			if not game.plan.built.has(spot):
				return false
			game.ledger.refund(Catalog.price_of("wall"))
			var paper := game.plan.strip(spot)
			if paper != "":
				game.ledger.refund(Catalog.price_of(paper))
			var had := game.plan.unbuild(spot)
			if had != "":
				game.ledger.refund(Catalog.price_of(had))
		"door", "arch":
			var what: String = game.plan.openings.get(spot, "")
			if what != "door" and what != "arch":
				return false
			game.grid.walls[spot] = true   # closing it up must not shut anyone in
			var ok := game.grid.layout_ok(Game.DOOR, game.placing._reach(), game.placing._touch())
			game.grid.walls.erase(spot)
			if not ok:
				return false
			game.plan.openings.erase(spot)
			game.ledger.refund(Catalog.price_of(what))
		"finish":
			if not game.plan.finishes.has(spot):
				return false
			game.ledger.refund(Catalog.price_of(game.plan.strip(spot)))
	game.world._sync_grid()
	return true


## After the plan changes: redraw the room and say so.
func _plan_changed() -> void:
	game.world._rebuild_room()
	game.hud.hints_ui.show_build()


## The spots a mouse drag covers, from where it started to `to`: a rectangle of
## cells for floors, a straight line of edges for walls, one spot otherwise.
func drag_spots(from: Vector3, to: Vector3, ch: Player = null) -> Array[Vector3i]:
	ch = game._me(ch)
	var out: Array[Vector3i] = []
	var id: String = ch.hand.get("id", "")
	if GamePlacing.floor_kind(id) != "":
		var cells := Floorplan.rect_cells(Grid.to_cell(from), Grid.to_cell(to))
		if not ch.drag.get("remove", false):
			cells = game.plan.lay_order(cells, GamePlacing.floor_kind(id))
		for c in cells:
			out.append(Vector3i(c.x, c.y, 0))
	elif Treatments.is_laying_tool(id):   # a treatment is laid over a rectangle of floor
		for c in Floorplan.rect_cells(Grid.to_cell(from), Grid.to_cell(to)):
			if game.plan.has_floor(c):
				out.append(Vector3i(c.x, c.y, 0))
	elif id == "wall" or Catalog.is_finish(id):
		var a := Vector2i(roundi(from.x), roundi(from.z))
		var b := Vector2i(roundi(to.x), roundi(to.z))
		if a == b:
			out.append(GamePlacing.snap_edge(to))
		else:
			out.assign(Floorplan.line(a, b))
	elif id != "":
		out.append(game.placing.snap(to, ch))
	return out


## Builds (or removes) along a whole drag, as far as the money goes.
func finish_drag(from: Vector3, to: Vector3, remove: bool, ch: Player = null) -> int:
	ch = game._me(ch)
	ch.drag = {"from": from, "remove": remove}
	var done := 0
	for spot in drag_spots(from, to, ch):
		if remove:
			done += int(remove_at(spot, ch))
		elif _build_at(spot, ch):
			done += 1
		elif not game.ledger.money >= int(ch.hand.price):
			break
	ch.drag = {}
	if done > 0:
		_plan_changed()
		game.audio.sfx("coin" if remove else "putdown")
		if not remove:
			game.placing._after_building(ch)
	else:
		game.audio.sfx("fail")
	return done


## What a drag in progress would do, for the prompt: "Lay 6 tiles  $30".
func drag_summary(ch: Player = null) -> String:
	ch = game._me(ch)
	if ch.drag.is_empty() or ch.hand.is_empty() or _hover_point(ch) == Vector3.INF:
		return ""
	var spots := drag_spots(ch.drag.from, _hover_point(ch), ch)
	if ch.drag.remove:
		return "Remove"
	var n := spots.size() if GamePlacing.floor_kind(ch.hand.id) != "" else spots.filter(func(sp: Vector3i) -> bool: return game.placing.can_place(sp, ch)).size()
	if Treatments.is_laying_tool(ch.hand.id):
		return "Lay %d tile%s  free" % [n, "" if n == 1 else "s"]
	var price := int(ch.hand.price)
	var noun: String = "tile" if GamePlacing.floor_kind(ch.hand.id) != "" else ("wall" if ch.hand.id == "wall" or Catalog.is_finish(ch.hand.id) else ch.hand.id)
	var verb := "Lay" if GamePlacing.floor_kind(ch.hand.id) != "" else ("Paint" if ch.hand.id == "paint" else ("Paper" if Catalog.is_finish(ch.hand.id) else "Build"))
	return "%s %d %s%s  $%d" % [verb, n, noun, "s" if n != 1 else "", n * price]


## A point on the floor in front of the chef: the middle of the next cell, or (for
## partitions) just inside the edge of the cell the chef stands in.
func _front_point(edge := false, ch: Player = null) -> Vector3:
	ch = game._me(ch)
	return Grid.center(ch.cell()) + Vector3(ch.facing.x, 0, ch.facing.y) * (0.45 if edge else 1.0)


## Where the piece in hand is held: over the spot in front of the chef.
func _hover_point(ch: Player = null) -> Vector3:
	ch = game._me(ch)
	if ch.demo_hover != Vector3.INF:
		return ch.demo_hover
	if ch.aim_mouse:
		return ch.mouse_point
	return _front_point(GamePlacing.on_edge(ch.hand.get("id", "")), ch)


## Where a point on the screen lands on the floor.
func floor_point(screen: Vector2) -> Vector3:
	var o := game.cam.project_ray_origin(screen)
	var d := game.cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector3.INF
	return o + d * (-o.y / d.y)


const WORKTOP_Y := 0.9   # the top of a counter (BuildStations._counter: a slab 0.13 thick at 0.77)
const AIM_STEP := 0.05


## Where the build-phase mouse points. Over a worktop (a bare counter, a counter base or a
## tool standing on one) it is that counter's cell, flattened to the floor, so the piece
## goes where the cursor looks; anywhere else it is the floor projection. Edge pieces and
## the build tools always aim at the floor.
func aim_point(screen: Vector2, ch: Player = null) -> Vector3:
	var floor_p := floor_point(screen)
	ch = game._me(ch)
	if not ch.hand.is_empty() and (GamePlacing.on_edge(ch.hand.id) or Catalog.is_build_tool(ch.hand.id)):
		return floor_p
	var o := game.cam.project_ray_origin(screen)
	var d := game.cam.project_ray_normal(screen)
	if d.y > -0.0001:
		return floor_p
	var y := WORKTOP_Y
	while y > 0.0:
		var p := o + d * ((y - o.y) / d.y)
		if _has_worktop(Grid.to_cell(p)):
			return Vector3(p.x, 0.0, p.z)
		y -= AIM_STEP
	return floor_p


func _has_worktop(cell: Vector2i) -> bool:
	var st: Station = game.stations.get(cell)
	return st != null and (game.world._bare_counter(cell) != null or Kitchen.is_counter(st.type) or Kitchen.is_top(st.type))


## A point on the piece the chef would pick up: the nearest within reach, the one they
## face winning a near tie (as in `Player.target_cell` by day). Candidates are a piece in
## a cell (the cell's middle) and a partition on a nearby edge (the edge's middle). The
## last pick is kept unless another beats it by a little, so the highlight does not flick
## between two pieces. Vector3.INF when there is nothing.
func _piece_in_front(ch: Player = null) -> Vector3:
	ch = game._me(ch)
	var here := ch.cell()
	var spots: Array[Vector3] = []
	var scores: Array[float] = []
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var n := here + Vector2i(dx, dy)
			if n == here or (game.world.station_at(n) == null and game.placing.rug_at(n) == null):
				continue
			var faced_aim: bool = ch.aiming and n == here + ch.facing
			if game.world.station_at(n) == null and game.placing.rug_at(n) == game.placing.rug_at(here) and not faced_aim:
				continue   # the rug underfoot is not offered: it only gets in the way of the door card
			if absi(dx) + absi(dy) == 1 and not game.grid.edge_open(here, n):
				continue   # a partition is in the way
			var spot := Grid.center(n)
			var to := spot - ch.position
			to.y = 0.0
			var dist := to.length()
			if dist > Player.REACH and not faced_aim:
				continue   # aiming picks the faced cell exactly, a diagonal one too
			spots.append(spot)
			scores.append(_pick_score(to, dist, ch))
	for e: Vector3i in game.wall_nodes:
		var mid := Vector3(e.x + (0.0 if e.z == 1 else 0.5), 0, e.y + (0.5 if e.z == 1 else 0.0))
		var to := mid - ch.position
		to.y = 0.0
		var dist := to.length()
		if dist > Player.REACH or not _edge_reachable(e, here):
			continue
		spots.append(mid + to.normalized() * -0.05)   # nudged to the chef's side, still on this edge
		scores.append(_pick_score(to, dist, ch) + 0.15)   # walls stay easy to grab
	var best := -1
	var kept := -1
	var last: Vector3 = ch.get_meta("pick_last", Vector3.INF)
	for i in spots.size():
		if best == -1 or scores[i] > scores[best]:
			best = i
		if last != Vector3.INF and _same_piece(spots[i], last):
			kept = i
	if best == -1:
		ch.set_meta("pick_last", Vector3.INF)
		return Vector3.INF
	if kept != -1 and scores[best] - scores[kept] < PICK_STICK:
		best = kept
	ch.set_meta("pick_last", spots[best])
	return spots[best]


const PICK_STICK := 0.15   # how much better another piece must score to take the highlight


func _pick_score(to: Vector3, dist: float, ch: Player) -> float:
	return -dist + (2.0 if ch.aiming else 0.4) * to.normalized().dot(ch.aim)


## Whether the same piece: the same cell, or the same partition edge.
func _same_piece(a: Vector3, b: Vector3) -> bool:
	var ea := game.wall_nodes.has(GamePlacing.snap_edge(a))
	if ea != game.wall_nodes.has(GamePlacing.snap_edge(b)):
		return false
	return GamePlacing.snap_edge(a) == GamePlacing.snap_edge(b) if ea else Grid.to_cell(a) == Grid.to_cell(b)


## A partition edge is in reach only from the chef's cell or a cell it can step into.
func _edge_reachable(e: Vector3i, here: Vector2i) -> bool:
	var sides := [Vector2i(e.x, e.y), Vector2i(e.x - 1, e.y)] if e.z == 1 else [Vector2i(e.x, e.y), Vector2i(e.x, e.y - 1)]
	for c: Vector2i in sides:
		if c == here:
			return true
		if absi(c.x - here.x) + absi(c.y - here.y) == 1 and game.grid.edge_open(here, c):
			return true
	return false


## What E would do in the build phase: "Put down", "Pick up", "Open up" or nothing.
func build_action(ch: Player = null) -> String:
	ch = game._me(ch)
	if game.phase != Game.Phase.BUILD or game.shopper == ch:
		return ""
	if not ch.hand.is_empty():
		if not ch.drag.is_empty():
			return drag_summary(ch)
		match GamePlacing.tool_kind(ch.hand.id):
			"floor":
				return "Lay floor"
			"finish":
				return "Paint wall" if ch.hand.id == "paint" else "Paper wall"
			"wall":
				return "Build wall"
			"door":
				return "Add door"
			"arch":
				return "Add archway"
			"treat":
				return "Lay %s" % Treatments.name_of(Treatments.key_of(ch.hand.id)).to_lower()
		if Catalog.is_box(ch.hand.id):   # where it will not go, why: chemicals and food (PRD 9.5)
			var c := Grid.to_cell(_hover_point(ch))
			var why := game.kitchen.store_refusal(c, ch.hand.id) if game.kitchen.slots(c) > 0 else ""
			return why if why != "" else "Put in"
		return "Hang" if game.world.hand_layer(ch) == "high" else "Put down"
	var kit := _kit_action(ch)
	if kit != "":
		return kit
	var clean := night_clean_action(game.world.station_at(ch.target_cell()), ch)
	if clean != "":
		return clean
	if game.desk.desk_in_front(ch) != null and not Cleaning.carrying_mess(ch.held):
		return "Use desk"
	if not Cleaning.carrying_mess(ch.held) and not CleanKit.holding(ch) and _piece_in_front(ch) != Vector3.INF:
		return "Pick up"
	return game.day.door_action(ch)


## The head prompt for a chef holding something at night: {text, extras}. A new piece
## carries its price on "put down" (a moved one none: its sell value is on the sell key),
## a box its nightly fee, a build tool its price each. A piece also gets turn and aim tags.
func held_prompt(ch: Player, action: String) -> Dictionary:
	var hand: Dictionary = ch.hand
	var text := action
	var extras := []
	if Treatments.is_laying_tool(hand.id):
		return {"text": text, "extras": extras}
	if Catalog.is_build_tool(hand.id):
		if ch.drag.is_empty():
			text = "%s $%d each" % [action, int(hand.price)]
	elif Treatments.is_box(hand.id):
		if action == "Put in":
			text = "%s %s" % [action, Treatments.fee_words(Treatments.key_of(hand.id))]
	elif Catalog.is_box(hand.id):
		var b := Pantry.station_ingredient(hand.id)
		if action == "Put in":
			text = "%s $%d a night" % [action, Pantry.fee_of(b.id, b.ready)]
	else:
		if not hand.get("moving", false) and action in ["Put down", "Hang"]:
			text = "%s $%d" % [action, int(hand.price)]
		extras = [["turn", "turn"], ["aim", "aim"]]
	return {"text": text, "extras": extras}


## What E does with cleaning tools at night (PRD 9.4): at a home or sink, else on the floor.
func _kit_action(ch: Player) -> String:
	if game.clean_kit.floor_first(ch):
		return game.clean_kit.floor_action(ch)
	var st: Station = game.world.station_at(ch.target_cell())
	var kit := game.clean_kit.station_use(st, true, ch) if st != null else ""
	if kit != "":
		return kit
	if not CleanKit.holding(ch) and (st != null or _piece_in_front(ch) != Vector3.INF):
		return ""   # by hand, a piece in front comes first (picking it up, its night clean)
	return game.clean_kit.floor_action(ch)


## The cleaning Use would do on this station at night, by its night name
## ("Clear table", "Wash up", "Take the bag out"); "" when there is none.
func night_clean_action(st: Station, ch: Player = null) -> String:
	ch = game._me(ch)
	if st == null or game.phase != Game.Phase.BUILD or game.shopper == ch or not ch.hand.is_empty():
		return ""
	if st.has_leftover_food():
		return "Clear food"
	return Cleaning.night_action(game.cooking.use_station(st, true, ch))


func needs_cleaning(st: Station) -> bool:
	return _mess_to_clean(st) or st.has_leftover_food()


func _mess_to_clean(st: Station) -> bool:
	return Cleaning.needs_cleaning("table" if Station.is_table(st.type) else st.type, st.dirty, st.count)


## The build-phase note on what is still dirty; "" when everything is clean.
func dirty_note() -> String:
	var tables := 0
	var sinks := 0
	var bins := 0
	var food := 0
	for st: Station in game.stations.values():
		if _mess_to_clean(st):
			tables += 1 if Station.is_table(st.type) else 0
			sinks += 1 if st.type == "sink" else 0
			bins += 1 if st.type == "bin" else 0
		elif st.has_leftover_food():
			food += 1
	var note := Cleaning.dirty_note(tables, sinks, bins, food)
	if note != "":   # or one press: the night cleaner (review, item 8)
		note += " Or hire the night cleaner in the shop's Extras ($%d)." % cleaner_price()
	return note


func build_interact(ch: Player = null) -> void:
	ch = game._me(ch)
	if ch.hand.is_empty() and _kit_action(ch) != "":   # a cleaning tool (PRD 9.4)
		var st: Station = game.world.station_at(ch.target_cell())
		if game.clean_kit.floor_first(ch) or st == null or game.clean_kit.station_use(st, false, ch) == "":
			game.clean_kit.floor_use(ch)
		return
	var action := build_action(ch)
	if not ch.hand.is_empty():
		action = "Put down"   # hung or stood, place() decides
	if action == "Clear food":
		var food_st: Station = game.world.station_at(ch.target_cell())
		food_st.clear_food()
		game.audio.sfx("putdown")
		game.hud.hints_ui.show_build()
		return
	if action in Cleaning.NIGHT_ACTIONS.values():
		game.cooking.use_station(game.world.station_at(ch.target_cell()), false, ch)
		game.hud.hints_ui.show_build()   # the dirty note counts down
		return
	match action:
		"Put down":
			ch.last_paint = game.placing.snap(_hover_point(ch), ch)
			if not game.placing.place(ch.last_paint, ch):
				refuse(ch.last_paint, ch)
		"Pick up":
			ch.strip_pick = 0
			if not game.placing.pick_up(_piece_in_front(ch), ch, true):
				game.audio.sfx("fail")
		"Use desk":
			game.desk.open_desk(ch)
		"Open up", "Take out rubbish":
			game.day.use_door(ch)
			game.hud.hints_ui.show_build()


## A put-down that did not happen: the soft fail sound, the cross wobbling and, when the
## spot has a reason, the line saying why. (A piece the chef cannot pay for says nothing here.)
func refuse(spot: Vector3i, ch: Player) -> void:
	game.audio.sfx("fail")
	var why := game.placing.place_refusal(spot, ch)
	if why != "":
		game.hud.day_ui.say(why)
	var mark := ch.no_mark
	if mark == null or not mark.visible:
		return
	var tw := (mark.get_meta("wobble") if mark.has_meta("wobble") else null) as Tween
	if tw != null:
		tw.kill()
	mark.rotation.y = 0.0
	tw = mark.create_tween()
	mark.set_meta("wobble", tw)
	for a: float in [0.2, -0.2, 0.12, -0.08, 0.0]:
		tw.tween_property(mark, "rotation:y", a, 0.05)


## The piece in hand is held over the spot in front of the chef; a cross marks
## spots where it cannot go.
func _update_ghost(ch: Player = null) -> void:
	ch = game._me(ch)
	_update_tool_ghost(ch)
	var key := "%s:%s:%s:%s" % [ch.hand.get("id", ""), ch.hand.get("tier", 0), game.upgrades.hand_key(ch), ch.hand.get("up", "")] if game.phase == Game.Phase.BUILD and not ch.hand.is_empty() and not Catalog.is_build_tool(ch.hand.id) and not ch.hand.get("in_place", false) else ""
	# A wall-layer piece (PRD 8.5) shows the layer it would take where it points.
	var hn := GameWorld.hand_node(ch.hand) if key != "" else ""
	var layer := ""
	var cell := Vector2i(-99, -99)
	var hover := _hover_point(ch)
	if (Kitchen.can_go_high(hn) or Kitchen.is_tall(hn)) and hover != Vector3.INF:
		var sp := game.placing.snap(hover, ch)
		cell = Vector2i(sp.x, sp.y)
		layer = game.world.layer_for(cell, hn) if Kitchen.can_go_high(hn) else "tall"
		key += ":%s:%d:%s" % [layer, int(game.wall_facing.get(cell, -1)), game.kitchen.get_piece(cell, "base")]
	if key != ch.ghost_key:
		ch.ghost_key = key
		if ch.ghost:
			ch.ghost.queue_free()
			ch.ghost = null
		if key != "":
			ch.ghost = Node3D.new()
			game.add_child(ch.ghost)
			if ch.hand.id == "screen":
				GameWorld._wall_visual(ch.ghost, 0.9 + 0.1 * int(ch.hand.tier))
			elif ch.hand.id == "rug":
				Scenery.rug(ch.ghost)
			elif ch.hand.id == "till":
				BuildStations.register(ch.ghost)
			elif layer == "high":
				var closet := hn.ends_with("shelf") and game.kitchen.is_closet_with(cell, hn)
				BuildStations.wall_piece(ch.ghost, hn, closet)
			elif ch.hand.get("node") is Station:
				var hs: Station = ch.hand.node
				BuildStations.station(ch.ghost, hs.type, hs.tier, hs.base if hs.type == "counter" or hs.type == "shelf" or Kitchen.grows_from_counter(hs.node) else "", false, hs.node)
			else:
				BuildStations.station(ch.ghost, ch.hand.id, int(ch.hand.tier), "counter" if ch.hand.get("counter", false) else ch.hand.get("base", ""), false, str(ch.hand.get("up", "")))
			if layer != "" and game.wall_facing.has(cell):
				_layer_band(ch.ghost, layer, 0 if layer == "high" else int(game.wall_facing[cell]) - int(ch.hand.facing), hn == "hook")
	var p := hover
	if ch.ghost == null or p == Vector3.INF:
		ch.no_mark.visible = false
		if ch.ghost:
			ch.ghost.visible = false
		return
	var spot := game.placing.snap(p, ch)
	var ok := game.placing.can_place(spot, ch)
	if GamePlacing.on_edge(ch.hand.id):
		GameWorld._place_on_edge(ch.ghost, spot)
	elif layer == "high":
		ch.ghost.position = Grid.center(Vector2i(spot.x, spot.y))
		ch.ghost.rotation.y = int(game.wall_facing.get(cell, 0)) * PI / 2
	else:
		ch.ghost.position = Grid.center(Vector2i(spot.x, spot.y))
		ch.ghost.rotation.y = int(ch.hand.facing) * PI / 2
	ch.ghost.position.y = 0.12 + 0.04 * sin(Time.get_ticks_msec() / 160.0)   # held just off the floor
	if Catalog.is_box(ch.hand.id):
		ch.ghost.position.y += 0.86   # a box is held over the counter it goes into
	ch.ghost.visible = ok
	ch.no_mark.visible = not ok
	ch.no_mark.position = Vector3(ch.ghost.position.x, 0, ch.ghost.position.z)


## A pale band on the wall behind a ghost marking the layer it takes (PRD 8.5): the
## high band for a hung piece, the low band for a shelf standing low, both for a tall
## piece. `turn` is the wall's facing in the ghost's own frame.
func _layer_band(ghost: Node3D, layer: String, turn: int, small := false) -> void:
	var band := Node3D.new()
	band.rotation.y = turn * PI / 2
	ghost.add_child(band)
	var y0 := BuildStations.HIGH_Y0 if layer == "high" else 0.0
	var y1 := 0.92 if layer == "base" else BuildStations.HIGH_Y1
	if small:   # a hook is a small thing low in the band: frame it, not the whole layer
		y0 = BuildStations.HIGH_Y0 - 0.2
		y1 = BuildStations.HIGH_Y0 + 0.5
	y0 -= 0.24   # a margin round the piece, so the band still shows as a frame behind it
	y1 += 0.24
	var plate := Build.box(band, Vector3(0, y0, -0.495), Vector3(1.0, y1 - y0, 0.01), Build.GOOD)
	plate.material_override = Build.overlay_mat(Color(Build.GOOD, 0.6), 2, true)   # behind the piece, on the wall
	for y: float in [y0, y1]:   # a darker rule top and bottom, so the band reads by shape too
		Build.box(band, Vector3(0, y - 0.015, -0.485), Vector3(1.0, 0.03, 0.02), Build.GOOD).material_override = Build.overlay_mat(Color(Build.GOOD, 0.85), 2, true)


## A build tool shows what it would do: pale squares for floor, bars along the
## edges for walls, the door or archway itself; green where it fits, coral
## where it does not, and coral everywhere a drag would remove.
func _update_tool_ghost(ch: Player = null) -> void:
	ch = game._me(ch)
	var p := _hover_point(ch)
	var tool := game.phase == Game.Phase.BUILD and not ch.hand.is_empty() and Catalog.is_build_tool(ch.hand.id) and game.shopper != ch and p != Vector3.INF
	var spots: Array[Vector3i] = []
	if tool:
		if ch.drag.is_empty():
			spots.append(game.placing.snap(p, ch))
		else:   # not a one-line `a if c else b`: that drops the array's type and fails at run time
			spots = drag_spots(ch.drag.from, p, ch)
	var key := "%s|%s|%s|%d" % [ch.hand.get("id", ""), spots, ch.drag.get("remove", false), game.ledger.money] if tool else ""
	if key == ch.tool_key:
		return
	ch.tool_key = key
	if ch.tool_ghost:
		ch.tool_ghost.queue_free()
		ch.tool_ghost = null
	if not tool:
		return
	ch.tool_ghost = Node3D.new()
	game.add_child(ch.tool_ghost)
	var removing: bool = ch.drag.get("remove", false)
	var dragging := not ch.drag.is_empty()
	for spot in spots:
		var ok := not removing and (dragging and (GamePlacing.floor_kind(ch.hand.id) != "" or Treatments.is_laying_tool(ch.hand.id)) or game.placing.can_place(spot, ch))
		var col := Color(Build.DANGER if removing or not ok else Build.GOOD, 0.55)
		if GamePlacing.floor_kind(ch.hand.id) != "" or Treatments.is_laying_tool(ch.hand.id):   # a treatment: its cells, flat (PRD 9.5)
			var tile := Build.box(ch.tool_ghost, Vector3(spot.x + 0.5, 0.02, spot.y + 0.5), Vector3(0.94, 0.03, 0.94), Build.GOOD)
			tile.material_override = Build.overlay_mat(col, 3)
		elif ch.hand.id == "wall" or Catalog.is_finish(ch.hand.id):
			var bar := Node3D.new()
			ch.tool_ghost.add_child(bar)
			GameWorld._place_on_edge(bar, spot)
			var tall := Scenery.CUT_H if ch.hand.id == "wall" else 1.2
			var thick := Scenery.WALL_T + (0.0 if ch.hand.id == "wall" else 0.08)
			Build.box(bar, Vector3(0, 0, 0), Vector3(1.0, tall, thick), Build.GOOD).material_override = Build.overlay_mat(col, 3)
		else:
			var n := Node3D.new()
			ch.tool_ghost.add_child(n)
			GameWorld._place_on_edge(n, spot)
			var inner := Node3D.new()
			n.add_child(inner)
			Scenery.dress_opening({"holder": inner, "kind": ch.hand.id, "tall": false}, true)
			if removing or not ok:
				Build.box(n, Vector3(0, 0, 0), Vector3(1.0, 0.9, Scenery.WALL_T + 0.1), Build.DANGER).material_override = Build.overlay_mat(col, 3)


## Flyers: bought from the shop's Extras at night for a bigger crowd tomorrow. One batch a night.
## What the night cleaner charges tonight: 0 when there is nothing to clean.
func cleaner_price() -> int:
	var pieces := 0
	for st: Station in game.stations.values():
		if needs_cleaning(st):
			pieces += 1
	return Cleaning.cleaner_price(pieces, game.floor_dirt.mess.total())


## The night cleaner: every table cleared and washed up, every bag out, the floor mopped,
## in one press (review, item 8). The plates and cups go back on their stacks.
func hire_cleaner() -> bool:
	var price := cleaner_price()
	if game.phase != Game.Phase.BUILD or price <= 0 or not game.ledger.spend(price):
		if price <= 0:
			game.hud.day_ui.say("Nothing to clean tonight.")
		return false
	for st: Station in game.stations.values():
		if Station.is_table(st.type) or st.type == "sink":
			while st.dirty > 0:
				game.cooking.wash_one(st)
		elif st.type == "bin" and st.count > 0:
			st.count = 0
			st.refresh()
		if st.has_leftover_food():
			st.clear_food()
	var m: FloorMess = game.floor_dirt.mess
	for c: Vector2i in m.dirt.keys():
		m.clean(c, FloorMess.MAX_LEVEL)
	game.floor_dirt.redraw()
	game.audio.sfx("wash")
	game.hud.day_ui.say("The cleaner came: everything is clean for tomorrow.")
	game.hud.hints_ui.show_build()
	return true


func buy_flyers() -> bool:
	if game.phase != Game.Phase.BUILD or game.flyers_out or not game.ledger.spend(Town.FLYER_PRICE):
		return false
	game.flyers_out = true
	game.audio.sfx("coin")
	game.hud.hints_ui.show_build()
	return true
