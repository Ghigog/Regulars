class_name GamePlacing
extends RefCounted
## Pieces in the build phase: buying from the catalog, the hand, picking up and putting
## down, restocking boxes, turning and selling, snapping, rugs and can_place/place.

var game: Game


const WONT_GO := "That won't go here"
const TAKEN := "Something's already there"
const KEEP_CLEAR := "Keep that clear for the queue"
const NEEDS_COUNTER := "Tools go on a counter"
const NEEDS_FRIDGE := "That box needs a fridge"
const NO_SEATS: Array[Vector2i] = []   # the extra cells a piece needs beside its own: none now
const NEEDS_FREEZER := "That box needs a freezer"
const BOX_NEEDS_COUNTER := "That box needs a counter"
const NO_WALL := "Nothing to hang it on here"


func _init(game_: Game) -> void:
	game = game_


## Buys what the shop is showing. Flyers are paid for at once; a piece goes into
## the hands of the chef whose player is shopping, and the shop shuts, so it can
## be carried to its place.
func buy(bp: Dictionary) -> bool:
	if game.card.storing():
		return game.card.card_act(bp.act, bp) if bp.has("act") else game.card._storage_buy(bp)
	if bp.id == Game.FLYERS.id:
		if game.room_edit.buy_flyers():
			return true
	elif bp.get("locked", false):
		game.hud.day_ui.say("The %s needs level %d." % [Catalog.label(bp), Catalog.bp_level(bp)])
	elif game.upgrades.pick_tree(bp, game.shopper) if bp.has("tree") else pick_catalog(bp.id, int(bp.tier), game.shopper, bp.get("base", "")):
		game.audio.sfx("pickup")
		game.session.close_shop()
		return true
	game.audio.sfx("fail")
	return false


## Picks a piece from the catalog to place. Nothing is paid until it is placed.
## `base` is a tree node the shop sells outright (a counter already a fridge).
func pick_catalog(id: String, tier := 1, ch: Player = null, base := "") -> bool:
	ch = game._me(ch)
	var bp := Catalog.node_blueprint(base) if base != "" else {"id": id, "tier": tier}
	if game.phase != Game.Phase.BUILD or Cleaning.carrying_mess(ch.held) or not game.catalog.can_buy(id, game.ledger.money, buy_level(id), tier) \
			or game.ledger.money < Catalog.bp_price(bp) or not Catalog.sold_in(id, Scenery.theme_id):
		return false
	if id == "sponge":   # a tool, not a piece: bought at once, into the hands
		return _buy_sponge(ch, bp)
	if id == "till" and game.paying.till_station() != null:
		game.hud.day_ui.say("One till is enough. Pick it up with E to move it.")
		return false
	if ch.hand.get("moving", false):
		cancel_hand(ch)
	ch.hand = {"id": id, "tier": tier, "price": Catalog.bp_price(bp), "facing": 0}
	if base != "":
		ch.hand.base = base
	ch.paint_wait = floor_kind(id) != "" and game.controls.holding(game.chefs.find(ch), "use")
	game.hud.hints_ui.show_build()
	return true


## The sponge is a hand tool (PRD 9.4): paid for at once and put in the chef's hands,
## clean. Hands that already carry something refuse it.
func _buy_sponge(ch: Player, bp: Dictionary) -> bool:
	if ch.held != "":
		game.hud.day_ui.say("Hands full: put that down first.")
		return false
	if ch.hand.get("moving", false):
		cancel_hand(ch)
	if not ch.hand.is_empty() or not game.ledger.spend(Catalog.bp_price(bp)):
		return false
	CleanKit.hold(ch, "sponge", 0)
	game.undo.record_sponge(ch, Catalog.bp_price(bp))
	game.hud.hints_ui.show_build()
	return true


## Puts down whatever is in hand: a new piece is dropped, a moved one goes back.
func cancel_hand(ch: Player = null) -> void:
	ch = game._me(ch)
	ch.drag = {}
	if ch.hand.get("moving", false):
		_put_down(ch.hand, ch.hand.from, int(ch.hand.from_facing))
	ch.hand = {}
	if game.phase == Game.Phase.BUILD:
		game.hud.hints_ui.show_build()


## The level the shop sells a piece at: any, while the kitchen has none of an essential.
func buy_level(id: String) -> int:
	return 999 if missing(id) else game.ledger.level()


## Whether the kitchen is without one of its essentials (a sink, a bin, a dish rack).
func missing(id: String) -> bool:
	if id == "till":
		return game.paying.till_station() == null
	return id in Game.ESSENTIALS and game.world.find_station(id) == null


static func piece_name(bp: Dictionary) -> String:
	return Catalog.label(bp) if Catalog.ITEMS.has(bp.id) else str(Game.PIECE_NAMES.get(bp.id, bp.id))


## The box E would lift off a layer ("base" or "high") of a cell, last in first; "" if none.
func lift_box(c: Vector2i, layer: String) -> String:
	if layer not in ["base", "high"]:
		return ""
	var boxes: Array = game.kitchen.take_stock(c).get(layer, [])
	return "" if boxes.is_empty() else str(boxes.back())


## Picks up the piece standing at a point on the floor, to move, turn or sell it.
## `whole`: a piece that keeps boxes is lifted with them, rather than its boxes one by one.
## `layer` names the piece to lift on a cell ("high" or "base"); by default `_lift_layer`.
func pick_up(p: Vector3, ch: Player = null, whole := false, layer := "") -> bool:
	ch = game._me(ch)
	if game.phase == Game.Phase.BUILD and ch.hand.is_empty() and ch.held == "dishes":
		game.audio.sfx("fail")
		game.hud.day_ui.say(Cleaning.RACK_FIRST)
		return false
	if game.phase != Game.Phase.BUILD or not ch.hand.is_empty() or Cleaning.hands_busy(ch.held) or CleanKit.holding(ch):
		return false   # hands full: a bag, a plate, a mop (PRD 9.4)
	var c := Grid.to_cell(p)
	var edge := snap_edge(p)
	if layer == "":
		layer = game.card._lift_layer(c, ch)
	var carried: Array = []
	if layer == "till" and game.stations.has(c) and game.stations[c].has_node("till"):
		var till: Node3D = game.stations[c].get_node("till")
		till.reparent(game, false)   # off its counter: while carried, there is no till
		till.visible = false
		var tf := int(till.get_meta("facing", 0))
		ch.hand = {"id": "till", "tier": 1, "price": 0, "facing": tf, "moving": true, "node": till,
			"from": Vector3i(c.x, c.y, 0), "from_facing": tf}
		game.audio.sfx("pickup")
		game.hud.hints_ui.show_build()
		_warn_shut_in()
		return true
	if game.stations.has(c) and game.room_edit.needs_cleaning(game.stations[c]):
		game.audio.sfx("fail")   # a messy piece is not moved or sold until it is clean
		game.hud.day_ui.say(Cleaning.CLEAN_FIRST)
		return false
	if game.stations.has(c) or game.highs.has(c):
		var st: Station = game.stations.get(c)
		if st != null and Kitchen.is_top(st.type) and not Kitchen.grows_from_counter(st.node):
			game.world._off_counter(st)   # the tool comes off first; its counter stays
		elif not whole and lift_box(c, layer) != "":
			# The boxes of the piece being lifted come first, last in first; the piece
			# only once it is empty (PRD 8.4).
			var box := lift_box(c, layer)
			game.kitchen.unstore(c, box, layer)
			game.world._show_boxes(c)
			ch.hand = {"id": box, "tier": 1, "price": 0, "facing": 0, "moving": true,
				"from": Vector3i(c.x, c.y, 0), "from_facing": 0}
			game.audio.sfx("pickup")
			game.menu_stock.menu_changed()
			return true
		elif game.highs.has(c) and layer == "high":
			# Then what hangs on the wall (PRD 8.5), before what stands under it.
			st = game.highs[c]
			game.highs.erase(c)
			carried = game.kitchen.remove(c, "high").get("stock", [])
			game.world._show_boxes(c)
		elif Kitchen.unstacked(st.base) != "" and st.stacked:
			# One counter comes off a double counter; the other stays with what is on it.
			st.set_base(Kitchen.unstacked(st.base))
			st.stacked = false
			game.kitchen.set_cell(c, st.base)
			var moved := mini(spent_tonight(game.stations[c]), Kitchen.price_of("counter"))   # tonight's counter comes off first
			if moved > 0:
				game.stations[c].set_meta("fresh", spent_tonight(game.stations[c]) - moved)
			st = Station.new()
			game.add_child(st)
			st.setup("counter", c, 1, game.stations[c].facing)
			_bought_tonight(st, moved)
		else:
			if whole and st.base != "":
				carried = (game.kitchen.take_stock(c).get("base", []) as Array).duplicate()
			game.world._unregister(st)
		st.visible = false
		ch.hand = {"id": st.type, "tier": st.tier, "price": 0, "facing": st.facing, "moving": true,
			"node": st, "from": Vector3i(c.x, c.y, 0), "from_facing": st.facing, "layer": "high" if st.high else ""}
		if not carried.is_empty():
			ch.hand.stock = carried
			game.menu_stock.menu_changed()
	elif game.wall_nodes.has(edge):
		var n: Node3D = game.wall_nodes[edge]
		game.wall_nodes.erase(edge)
		game.grid.walls.erase(edge)
		n.visible = false
		ch.hand = {"id": "screen", "tier": int(n.get_meta("tier", 1)), "price": 0, "facing": 0, "moving": true,
			"node": n, "from": edge, "from_facing": 0}
	elif rug_at(c) != null:   # a rug is picked up last: whatever stands on it comes first
		var n := rug_at(c)
		var anchor: Vector2i = game.rugs.find_key(n)
		game.rugs.erase(anchor)
		n.visible = false
		var f := int(n.get_meta("facing", 0))
		ch.hand = {"id": "rug", "tier": 1, "price": 0, "facing": f, "moving": true,
			"node": n, "from": Vector3i(anchor.x, anchor.y, 0), "from_facing": f}
	else:
		return false
	game.audio.sfx("pickup")
	game.hud.hints_ui.show_build()
	_warn_shut_in()
	return true


## On a lift: say so when the room already shuts someone in, so a refused spot is no surprise.
func _warn_shut_in() -> void:
	var line := shut_in_line()
	if line != "":
		game.hud.day_ui.say(line)


## Stands the carried piece on a spot. No checks: callers have made them.
func _put_down(h: Dictionary, spot: Vector3i, facing: int) -> void:
	if Catalog.is_box(h.id):
		_store_box(Vector2i(spot.x, spot.y), h.id)
		return
	var n: Node3D = h.node
	n.visible = true
	var cell := Vector2i(spot.x, spot.y)
	if h.id == "till":
		n.reparent(game.paying._till_host(cell), false)
		BuildStations.face_till(n, facing)
		return
	var hn := GameWorld.hand_node(h)
	if n is Station and Kitchen.can_go_high(hn):
		var layer := game.world.layer_for(cell, hn)
		if h.get("from", Vector3i(0, 0, -1)) == spot and h.get("layer", "") == "high" and game.kitchen.can_hang(cell, hn):
			layer = "high"   # put back where it hung
		if layer == "high":
			game.world._hang(n, cell)
			_restock(h, cell)
			return
	if h.id == "screen":
		game.grid.walls[spot] = true
		game.wall_nodes[spot] = n
		GameWorld._place_on_edge(n, spot)
	elif h.id == "rug":
		_lay_rug(n, Vector2i(spot.x, spot.y), facing)
	elif game.world._bare_counter(Vector2i(spot.x, spot.y)) != null and Kitchen.is_top(h.id):
		game.world._onto_counter(n, Vector2i(spot.x, spot.y), facing)
	elif game.world._bare_counter(Vector2i(spot.x, spot.y)) != null and Kitchen.is_counter(h.id):
		_restack(Vector2i(spot.x, spot.y))   # only the own spot of a lifted hand-stacked counter gets here
		n.queue_free()
	else:
		(n as Station).place_at(Vector2i(spot.x, spot.y), facing)
		game.world._register(n)
	_restock(h, cell)


## The boxes a piece was carried with go into its new place; any that will not fit
## there are left out, and the player is told which.
func _restock(h: Dictionary, cell: Vector2i) -> void:
	var boxes: Array = h.get("stock", [])
	if boxes.is_empty():
		return
	var left: Array[String] = []
	for box: String in boxes:
		if not game.kitchen.store(cell, box):
			left.append(Catalog.label({"id": box, "tier": 1}))
	game.world._show_boxes(cell)
	game.menu_stock.menu_changed()
	if not left.is_empty():
		game.hud.day_ui.say("No room here for %s: left out." % ", ".join(left))


## Puts a box of stock in a cell's storage: that kind is stocked from tonight (PRD 8.4).
func _store_box(cell: Vector2i, box: String) -> bool:
	if not game.kitchen.store(cell, box):
		return false
	game.world._show_boxes(cell)
	game.menu_stock.menu_changed()
	return true


## A counter put back on the spot it was lifted from, where the other half still stands:
## the old hand-stacked double counter is whole again.
func _restack(cell: Vector2i) -> void:
	var under := game.world._bare_counter(cell)
	under.set_base("double_counter")
	game.kitchen.set_cell(cell, under.base)
	under.stacked = true


## Turns the piece in hand a quarter turn. Partitions turn by where you point.
func rotate_hand(ch: Player = null) -> void:
	ch = game._me(ch)
	if Treatments.is_laying_tool(ch.hand.get("id", "")):   # a treatment's laying tool: turn switches it off or on
		var k := Treatments.key_of(ch.hand.id)
		game.menu_stock.switch_treatment(k, game.treat_off.has(k))
		game.audio.sfx("pickup")
		game.hud.hints_ui.show_build()
		return
	if not ch.hand.is_empty() and not on_edge(ch.hand.id) and not Catalog.is_build_tool(ch.hand.id) \
			and not Kitchen.is_high_only(GameWorld.hand_node(ch.hand)):   # a hung piece faces off its wall
		ch.hand.facing = (int(ch.hand.facing) + 1) % 4
		if ch.hand.get("in_place", false) and ch.hand.get("node") is Station:   # on its card: turn it where it stands
			var st: Station = ch.hand.node
			st.place_at(st.cell, int(ch.hand.facing))
		game.audio.sfx("pickup")


## What selling the carried piece pays: half its catalog price, or 0 if not for sale.
func sell_value(ch: Player = null) -> int:
	ch = game._me(ch)
	if not ch.hand.get("moving", false) or not Catalog.ITEMS.has(ch.hand.id):
		return 0
	var key := game.upgrades.hand_key(ch)
	var whole := Upgrades.price(key) if key != "" else Catalog.price_of(ch.hand.id, int(ch.hand.tier))   # upgrades and all
	var hs: Variant = ch.hand.get("node")
	if hs is Station and Kitchen.grows_from_counter((hs as Station).node):
		whole += Kitchen.price_of((hs as Station).base)   # a stove sells with the counter it grew from
	var fresh := mini(spent_tonight(ch.hand.get("node")), whole)
	return (whole - fresh) / 2 + fresh   # half back, but what was bought tonight comes back whole


## Same-night returns: what was paid tonight for a piece (bought or upgraded since the
## last day ended) is paid back in full if it is sold before the door opens.
func _bought_tonight(n: Object, amount: int) -> void:
	if n == null or amount <= 0:
		return
	n.set_meta("fresh", spent_tonight(n) + amount)
	n.set_meta("fresh_night", game.ledger.day)


## Sets what was spent on a piece tonight (an undone upgrade takes its price off).
func set_spent_tonight(n: Object, amount: int) -> void:
	if amount > 0:
		n.set_meta("fresh", amount)
		n.set_meta("fresh_night", game.ledger.day)
	elif n.has_meta("fresh"):
		n.remove_meta("fresh")


func spent_tonight(n: Variant) -> int:
	if not (n is Object) or n == null or int(n.get_meta("fresh_night", -1)) != game.ledger.day:
		return 0
	return int(n.get_meta("fresh", 0))


## Why the carried piece cannot be sold; empty when it can.
func sell_block(ch: Player = null) -> String:
	ch = game._me(ch)
	if not ch.hand.get("moving", false):
		return "Nothing picked up"
	if not Catalog.ITEMS.has(ch.hand.id):
		return "The %s is not for sale" % piece_name(ch.hand).to_lower()
	if ch.hand.id == "desk" and not game.staff.can_sell_desk(game.desk.desk_count() + 1):
		return "Every desk has a post or a hire"
	return ""


func sell_hand(ch: Player = null) -> bool:
	ch = game._me(ch)
	if game.phase != Game.Phase.BUILD or sell_block(ch) != "":
		return false
	var value := sell_value(ch)
	game.ledger.refund(value)
	game.undo.record_sold(ch.hand, value)
	if Catalog.is_box(ch.hand.id):   # a box sold: its kind is no longer stocked
		ch.hand = {}
		game.audio.sfx("coin")
		game.menu_stock.menu_changed()
		game.hud.hints_ui.show_build()
		return true
	# The piece is kept, hidden, so that undo can stand it back; the undo stack frees it.
	var had_boxes := not (ch.hand.get("stock", []) as Array).is_empty()
	ch.hand = {}
	if had_boxes:
		game.menu_stock.menu_changed()
	game.audio.sfx("coin")
	game.hud.hints_ui.show_build()
	return true


## The cell edge nearest a point on the floor: (x, y, axis).
static func snap_edge(p: Vector3) -> Vector3i:
	var c := Grid.to_cell(p)
	var fx := p.x - c.x
	var fz := p.z - c.y
	if minf(fz, 1.0 - fz) < minf(fx, 1.0 - fx):
		return Vector3i(c.x, c.y + (1 if fz > 0.5 else 0), 0)
	return Vector3i(c.x + (1 if fx > 0.5 else 0), c.y, 1)


## Where the piece in hand would go for a point on the floor: (x, y, axis).
## Furniture snaps to the cell (axis 0); a partition snaps to the nearest cell edge.
func snap(p: Vector3, ch: Player = null) -> Vector3i:
	ch = game._me(ch)
	if on_edge(ch.hand.get("id", "")):
		return snap_edge(p)
	var c := Grid.to_cell(p)
	return Vector3i(c.x, c.y, 0)


## Pieces that sit on a cell edge rather than in a cell.
static func on_edge(id: String) -> bool:
	return id == "screen" or id == "wall" or id == "door" or id == "arch" or id == "window" or Catalog.is_finish(id)


## Groups the build tools: "floor" for every floor, "finish" for paint and paper,
## else the id itself.
static func tool_kind(id: String) -> String:
	if floor_kind(id) != "":
		return "floor"
	if Treatments.is_laying_tool(id):
		return "treat"   # a floor treatment (PRD 9.5)
	return "finish" if Catalog.is_finish(id) else id


## The six cells a rug covers: three across the anchor cell and three more one
## row on, toward `facing` (0 is +z, 1 is +x, 2 is -z, 3 is -x).
static func rug_cells(anchor: Vector2i, facing: int) -> Array[Vector2i]:
	var d: Vector2i = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)][posmod(facing, 4)]
	var across := Vector2i(absi(d.y), absi(d.x))
	var out: Array[Vector2i] = []
	for j in 2:
		for i in range(-1, 2):
			out.append(anchor + across * i + d * j)
	return out


## The rug lying on a cell, or null.
func rug_at(c: Vector2i) -> Node3D:
	for a: Vector2i in game.rugs:
		if rug_cells(a, int(game.rugs[a].get_meta("facing", 0))).has(c):
			return game.rugs[a]
	return null


func add_rug(anchor: Vector2i, facing := 0) -> Node3D:
	var n := Node3D.new()
	game.add_child(n)
	Scenery.rug(n)
	_lay_rug(n, anchor, facing)
	return n


func _lay_rug(n: Node3D, anchor: Vector2i, facing: int) -> void:
	n.set_meta("facing", facing)
	n.position = Grid.center(anchor)
	n.rotation.y = facing * PI / 2
	game.rugs[anchor] = n


## A rug fits where all six cells have floor, no other rug and no wall between them.
func can_lay_rug(anchor: Vector2i, facing: int) -> bool:
	var cells := rug_cells(anchor, facing)
	for c in cells:
		if not game.plan.has_floor(c) or rug_at(c) != null:
			return false
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if cells.has(c + d):
				var e := Grid.edge_between(c, c + d)
				if game.plan.is_wall(e) or game.wall_nodes.has(e):
					return false
	return true


## The floor kind a floor tool lays, or "".
static func floor_kind(id: String) -> String:
	return id.trim_prefix("floor_") if id.begins_with("floor_") else ""


## Everyone who must still be able to get about after a change: the chef, every
## seat (must_reach) and a side of every station (must_touch).
func _reach() -> Array[Vector2i]:
	var reach: Array[Vector2i] = []
	for ch in game.chefs:   # every chef must still be able to get about
		reach.append(ch.cell())
	reach.assign(reach + game.grid.reserved.keys())
	return reach


func _touch() -> Array[Vector2i]:
	var touch: Array[Vector2i] = []
	touch.assign(game.stations.keys())
	return touch


## Would the piece in hand fit at this spot without making the room worse?
func can_place(spot: Vector3i, ch: Player = null) -> bool:
	return place_refusal(spot, ch) == ""


## The line for a box put down where nothing stores: names what that box really needs.
static func _no_storage_refusal(box: String) -> String:
	if Kitchen.is_frozen(box):
		return NEEDS_FREEZER
	return NEEDS_FRIDGE if Kitchen.is_chilled(box) else BOX_NEEDS_COUNTER


## Why the piece in hand cannot go at this spot, in a line for the player; "" when it fits.
## A moving piece always fits the spot it came from (`place` turns it back if it must), unless
## `strict`, which judges that spot like any other (for trying a turn there).
func place_refusal(spot: Vector3i, ch: Player = null, strict := false) -> String:
	ch = game._me(ch)
	if ch.hand.is_empty():
		return WONT_GO
	if not strict and _is_own_spot(spot, ch):
		return ""
	var cell := Vector2i(spot.x, spot.y)
	if Catalog.is_box(ch.hand.id):   # a box goes into a free storage slot that takes it
		var why := game.kitchen.store_refusal(cell, ch.hand.id)
		return "" if why == "" else (why if game.kitchen.slots(cell) > 0 else _no_storage_refusal(ch.hand.id))
	var reach := _reach()
	var touch := _touch()
	match tool_kind(ch.hand.id):
		"floor":   # floor laid behind a wall takes the wall away: not from under a hung piece
			var ok: bool = game.plan.can_lay(cell, floor_kind(ch.hand.id)) \
				and (game.plan.has_floor(cell) or not game.world._strands_high(Floorplan.cell_edges(cell)))
			return "" if ok else WONT_GO
		"finish":
			return "" if game.plan.can_finish(spot, ch.hand.id) else "Paint and paper go on a wall"
		"treat":   # any floor, one treatment a cell: a new one replaces the old
			var ok: bool = game.plan.has_floor(cell) and game.treat_laid.get(cell, "") != Treatments.key_of(ch.hand.id)
			return "" if ok else WONT_GO
		"rug":
			return "" if can_lay_rug(cell, int(ch.hand.facing)) else WONT_GO
		"wall":
			if not game.plan.can_build(spot):
				return WONT_GO
			return _grid_words(game.grid.wall_refusal(spot, game.lot, Game.DOOR, reach, touch))
		"window":
			var ok: bool = game.plan.can_glaze(spot) and not game.world._strands_high([spot])
			return "" if ok else WONT_GO
		"door", "arch":
			var ok: bool = game.plan.can_open(spot, ch.hand.id) and not game.world._strands_high([spot])
			return "" if ok else WONT_GO
	if ch.hand.id == "screen":
		var why := _grid_words(game.grid.wall_refusal(spot, game.lot, Game.DOOR, reach, touch))
		return why if why != "" else (TAKEN if game.plan.is_wall(spot) else "")
	if ch.hand.id == "till":   # on a counter, or a tool standing on one
		return "" if game.paying._till_host(cell) != null else NEEDS_COUNTER
	var hn := GameWorld.hand_node(ch.hand)
	if Kitchen.can_go_high(hn):   # the wall layer (PRD 8.5): it hangs on a wall or not at all
		return "" if game.world.layer_for(cell, hn) == "high" else NO_WALL
	elif Kitchen.is_tall(hn) and game.kitchen.get_piece(cell, "high") != "":
		return TAKEN   # a tall piece fills both wall layers
	if Kitchen.grows_from_counter(hn):   # a stove is its counter upgraded: the floor only
		if game.stations.has(cell) or game.kitchen.layer_for(cell, "counter") != "base":
			return "A stove stands on the floor"
		return _grid_words(game.grid.block_refusal(cell, NO_SEATS, game.lot, Game.DOOR, reach, touch))
	if game.stations.has(cell) or Kitchen.is_top(ch.hand.id):
		if game.world._stacks_on(cell, ch.hand):   # a tool needs a counter under it
			return ""
		return NEEDS_COUNTER if Kitchen.is_top(ch.hand.id) and not game.stations.has(cell) else TAKEN
	var seats := NO_SEATS   # a seat piece's own cell is its seat; a table tile has none of its own
	if _is_street_piece(ch.hand.id) and not game.lot.has_point(cell):
		return _street_refusal(cell, seats, reach, touch)
	return _grid_words(game.grid.block_refusal(cell, seats, game.lot, Game.DOOR, reach, touch))


## Tables, chairs and decor may stand out on the pavement; nothing else does.
static func _is_street_piece(id: String) -> bool:
	return Catalog.ITEMS.has(id) and str(Catalog.ITEMS[id].get("category", "")) in ["Dining", "Decor"]


## The queue line: the pavement column by the wall from the doorway up to the street end.
func _on_queue_line(c: Vector2i) -> bool:
	return c.x == Game.W and c.y >= game.lot.bounds().position.y and c.y <= Game.DOOR.y


## A table, chair or decor piece on the pavement: the two open rows, off the queue line,
## the doorway and the board, and never where it would cut a street end off from the door.
func _street_refusal(cell: Vector2i, seats: Array[Vector2i], reach: Array[Vector2i], touch: Array[Vector2i]) -> String:
	var cells: Array[Vector2i] = [cell]
	cells.append_array(seats)
	for c in cells:
		if not game.pavement().has_point(c):   # the back tile, the road, or the room's own side
			return "That's off the lot"
		if c == Game.DOOR or c == Game.BOARD_CELL or _on_queue_line(c):
			return KEEP_CLEAR
	reach.append(game.spawn_cell())
	reach.append(game.exit_cell())
	reach.append(Game.DOOR)
	for y in range(game.lot.bounds().position.y, Game.DOOR.y + 1):
		reach.append(Vector2i(Game.W, y))
	var area := game.lot.bounds().merge(game.pavement())
	return _grid_words(game.grid.block_refusal(cell, seats, area, Game.DOOR, reach, touch))


## The player's words for a Grid refusal code.
static func _grid_words(code: String) -> String:
	match code:
		"off_lot": return "That's off the lot"
		"taken": return TAKEN
		"shut_in": return "That would shut someone in"
	return ""


## Whether `spot` is where the piece in hand was lifted from, on the layer it was lifted from.
func _is_own_spot(spot: Vector3i, ch: Player) -> bool:
	if not ch.hand.get("moving", false) or spot != ch.hand.from:
		return false
	var hn := GameWorld.hand_node(ch.hand)
	return (game.world.layer_for(Vector2i(spot.x, spot.y), hn) == "high") == (ch.hand.get("layer", "") == "high")


## What is shut in, in a line, when the room already breaks the rule; "" when it does not.
func shut_in_line() -> String:
	var cut := game.grid.cut_off(Game.DOOR, _reach(), _touch())
	if cut.is_empty():
		return ""
	var c := cut[0]
	if game.stations.has(c):
		var st: Station = game.stations[c]
		if Station.is_seat(st.type):
			return "A %s's seat can't be reached" % piece_name({"id": st.type, "tier": st.tier}).to_lower()
		var name := str(Kitchen.NODES[st.node].name) if Kitchen.has_node(st.node) \
			else piece_name({"id": st.type, "tier": st.tier})
		return "The %s can't be reached" % name.to_lower()
	for st: Station in game.stations.values():
		if st.seats.has(c):
			return "A %s's seat can't be reached" % piece_name({"id": st.type, "tier": st.tier}).to_lower()
	return "You're shut in"


## Builds the piece in hand and pays for it, so cancelling before this is free.
## A new piece stays in hand for another while there is money for it; a moved
## piece is put down for nothing.
func place(spot: Vector3i, ch: Player = null) -> bool:
	ch = game._me(ch)
	if game.phase != Game.Phase.BUILD or not can_place(spot, ch):
		return false
	if Catalog.is_build_tool(ch.hand.id):
		var before := game.undo.plan_snapshot()
		if not game.room_edit._build_at(spot, ch):
			return false
		game.undo.record_plan(before)
		game.room_edit._plan_changed()
		game.audio.sfx("putdown")
		_after_building(ch)
		return true
	var cell := Vector2i(spot.x, spot.y)
	if ch.hand.get("moving", false):
		var back: bool = spot == ch.hand.from and place_refusal(spot, ch, true) != ""
		var facing := int(ch.hand.from_facing) if back else _seat_facing(ch.hand.id, cell, int(ch.hand.facing))
		_put_down(ch.hand, spot, facing)
		game.undo.record_moved(ch.hand, spot, facing)
		ch.hand = {}
		game.audio.sfx("putdown")
		game.hud.hints_ui.show_build()
		return true
	if not game.ledger.spend(int(ch.hand.price)):
		return false
	if Catalog.is_box(ch.hand.id):
		_store_box(cell, ch.hand.id)
		game.undo.record_placed(spot, ch.hand.id, null, int(ch.hand.price), ch.hand)
		ch.hand = {}   # one box a kind: hands are free again
		game.audio.sfx("putdown")
		game.hud.hints_ui.show_build()
		return true
	var paid := int(ch.hand.price)
	var built: Object
	if ch.hand.id == "screen":
		var n := game.world.add_wall(cell, spot.z, 0.9 + 0.1 * int(ch.hand.tier))
		n.set_meta("tier", int(ch.hand.tier))
		game.wall_nodes[spot] = n
		_bought_tonight(n, paid)
		built = n
	elif ch.hand.id == "rug":
		built = add_rug(cell, int(ch.hand.facing))
		_bought_tonight(built, paid)
	elif ch.hand.id == "till":
		BuildStations.register(game.paying._till_host(cell), int(ch.hand.facing))
		built = game.stations[cell].get_node("till")
		_bought_tonight(built, paid)
	elif game.world.layer_for(cell, GameWorld.hand_node(ch.hand)) == "high":
		var hung := game.world.add_high(str(ch.hand.get("up", ch.hand.id)), cell)
		_bought_tonight(hung, paid)
		game.clean_kit.on_built(hung, ch.hand.id)
		built = hung
	else:
		var st := game.world.add_station(str(ch.hand.get("up", ch.hand.id)), cell, int(ch.hand.tier), _seat_facing(ch.hand.id, cell, int(ch.hand.facing)), ch.hand.get("base", ""))
		_bought_tonight(st, paid)
		game.clean_kit.on_built(st, ch.hand.id)
		built = st
	game.undo.record_placed(spot, ch.hand.id, built, paid, ch.hand)
	game.audio.burst(Grid.center(cell) + Vector3(0, 1.0, 0), "stars", 0.4)
	game.audio.sfx("putdown")
	_after_building(ch)
	return true


## A seat set down beside a Table tile turns to face it (unless it already does); any other
## piece, or a seat with no tile beside it, keeps the way it was turned.
func _seat_facing(id: String, cell: Vector2i, facing: int) -> int:
	if not Station.is_seat(id):
		return facing
	var tiles: Array = []
	for st: Station in game.paying.dining_tables():
		tiles.append(st.cell)
	if (cell + TableJoins.FACE[facing % 4]) in tiles:
		return facing
	var f := TableJoins.face_toward(cell, tiles)
	return facing if f < 0 else f


## A new piece or tool stays in hand while there is money for another.
func _after_building(ch: Player = null) -> void:
	ch = game._me(ch)
	if ch.hand.get("id", "") == "till" or not game.catalog.can_buy(ch.hand.id, game.ledger.money, buy_level(ch.hand.id), int(ch.hand.tier)) or game.ledger.money < int(ch.hand.price):
		ch.hand = {}
	game.hud.hints_ui.show_build()
