class_name GameCard
extends RefCounted
## The storage card (review item 4): E on a piece at night opens its card, with its actions
## (upgrade, move, turn, sell), its boxes and the fridge offer; hold E to move it.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- the storage card

## Whether the tray open is a storage card rather than the shop.
func storing() -> bool:
	return game.shopping and game.storing_cell != Game.NO_CELL


## The piece a card would open for on a cell: what hangs on the wall, else what stands
## there (a tool on a counter before the counter). Once a wall piece's card has been
## shut, the next E there takes what stands under it, so a sink under a shelf is reached.
func _card_layer_at(c: Vector2i, ch: Player) -> String:
	var st: Station = game.stations.get(c)
	if game.highs.has(c) and (st == null or ch.get_meta("low_next", Game.NO_CELL) != c):
		return "high"
	if st == null:
		return ""
	return "top" if Kitchen.is_top(st.type) and not Kitchen.grows_from_counter(st.node) else "base"


## Whether E in front of a chef opens a card (a station, or a piece on the wall). A rug
## or a partition has neither contents nor upgrades: E just picks it up.
func _card_in_front(ch: Player) -> bool:
	var p := game.room_edit._piece_in_front(ch)
	if p == Vector3.INF or game.wall_nodes.has(GamePlacing.snap_edge(p)):
		return false
	return _card_layer_at(Grid.to_cell(p), ch) != ""


## E on a piece at night (review, item 4): its one card opens where it stands, nothing
## lifted: what is in it, its upgrades, and Move, Turn and Sell. Holding E moves it.
## `at`: a point on the piece (a mouse click); by default the one in front of the chef.
func open_card(ch: Player = null, at := Vector3.INF) -> bool:
	ch = game._me(ch)
	var p := game.room_edit._piece_in_front(ch) if at == Vector3.INF else at
	if p == Vector3.INF or game.shopping or game.hud.card_open() or not ch.hand.is_empty():
		return false
	var c := Grid.to_cell(p)
	var layer := _card_layer_at(c, ch)
	if game.wall_nodes.has(GamePlacing.snap_edge(p)) or layer == "":
		return game.placing.pick_up(p, ch, true)   # a partition or a rug: nothing to show, so it is just picked up
	if game.stations.has(c) and game.room_edit.needs_cleaning(game.stations[c]) and layer != "high":
		game.audio.sfx("fail")
		game.hud.day_ui.say(Cleaning.CLEAN_FIRST)
		return false
	return _open_card_at(c, layer, ch)


func _open_card_at(c: Vector2i, layer: String, ch: Player) -> bool:
	if game.phase != Game.Phase.BUILD or game.shopping or c == Game.NO_CELL or game.hud.card_open():
		return false
	game.shopper = ch
	game.storing_cell = c
	game.card_layer = layer
	game._card_hold.erase(ch)
	ch.set_meta("low_next", c if layer == "high" else Game.NO_CELL)   # a wall piece's card shut: next E, what is under it
	game.audio.sfx("slide")
	game.hud.shop_ui.show_shop()
	return true


## Opens the card on a cell for the piece E would take there. For tests and demos.
func open_storage(cell: Vector2i, ch: Player = null) -> bool:
	ch = game._me(ch)
	if cell == Game.NO_CELL:
		return false
	var layer := _card_layer_at(cell, ch)
	return layer != "" and _open_card_at(cell, layer, ch)


## The piece the open card is for.
func card_station() -> Station:
	if not storing():
		return null
	return game.highs.get(game.storing_cell) if game.card_layer == "high" else game.stations.get(game.storing_cell)


## Whether the open card's piece keeps boxes (a counter, shelf, cabinet or fridge, or a
## stove, which keeps its counter's). A tool on a counter does not: that is the counter's.
func card_keeps_boxes() -> bool:
	var st := card_station()
	if st == null or game.card_layer == "top":
		return false
	return Kitchen.slots_of(game.kitchen.get_piece(st.cell, "high" if game.card_layer == "high" else "base")) > 0


## The card's action cards, in the row before any boxes: Upgrades (when the piece has a
## tree), the upgrade of each stored treatment box, Move, Turn and Sell, and the till's
## Move when the till stands here. Each is {id, tier, ..., act}, drawn as the piece itself.
func card_actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var st := card_station()
	if st == null:
		return out
	var look := {"id": st.type, "tier": st.tier, "node": st.node,
		"base": st.base if st.type == "counter" else "", "counter": Kitchen.grows_from_counter(st.node)}
	if storage_tree() != "":
		out.append(look.merged({"act": "upgrades"}))
	if card_keeps_boxes():
		for box: String in game.kitchen.stock(game.storing_cell):
			if Treatments.is_box(box) and Upgrades.has_tree(box):
				out.append({"id": box, "tier": 1, "act": "box_tree", "box": box})
	out.append(look.merged({"act": "move"}))
	if game.card_layer != "high":
		out.append(look.merged({"act": "turn"}))
	out.append(look.merged({"act": "sell"}))
	if st.has_node("till"):
		out.append({"id": "till", "tier": 1, "act": "till"})
	return out


func _probe_of(st: Station) -> Player:
	var probe := Player.new()
	probe.hand = {"id": st.type, "tier": st.tier, "moving": true, "node": st}
	return probe


## What the card's Sell would pay, worked out as if the piece were in hand; -1 when it
## cannot be sold (`card_sell_block` says why).
func card_sell_value() -> int:
	var st := card_station()
	if st == null:
		return -1
	var probe := _probe_of(st)
	var v := game.placing.sell_value(probe) if game.placing.sell_block(probe) == "" else -1
	probe.free()
	return v


func card_sell_block() -> String:
	var st := card_station()
	if st == null:
		return "Nothing here"
	var probe := _probe_of(st)
	var why := game.placing.sell_block(probe)
	probe.free()
	return why


## Does what an action card on the open card says. The card shuts for Move, Sell and the
## till; Turn turns the piece where it stands and the card stays open.
func card_act(act: String, bp := {}) -> bool:
	if not storing():
		return false
	var ch := game.shopper
	var c := game.storing_cell
	var layer := game.card_layer
	match act:
		"upgrades":
			storage_upgrades()
			return true
		"box_tree":
			ch.hand = {"id": bp.box, "tier": 1, "price": 0, "facing": 0, "moving": true, "in_place": true,
				"from": Vector3i(c.x, c.y, 0), "from_facing": 0}
			game.hud.shop_ui.hide_shop()
			game.upgrading = true
			game.audio.sfx("tab", 0.08)
			game.hud.screens_ui.show_tree(bp.box)
			return true
		"move":
			game.session.close_shop()
			return game.placing.pick_up(Grid.center(c), ch, true, layer)
		"till":
			game.session.close_shop()
			return game.placing.pick_up(Grid.center(c), ch, true, "till")
		"sell":
			var why := card_sell_block()
			if why != "":
				game.hud.day_ui.say(why + ".")
				game.audio.sfx("fail")
				return false
			game.session.close_shop()
			if not game.placing.pick_up(Grid.center(c), ch, true, layer):
				return false
			return game.placing.sell_hand(ch)
		"turn":
			return _card_turn(ch, c, layer)
	return false


## Turns the card's piece a quarter where it stands. A piece that keeps boxes turns on
## the spot; anything else is taken up, turned and put back if it fits that way round.
func _card_turn(ch: Player, c: Vector2i, layer: String) -> bool:
	var st := card_station()
	if st == null:
		return false
	if card_keeps_boxes() or st.type == "counter" or Kitchen.grows_from_counter(st.node):
		st.place_at(st.cell, (st.facing + 1) % 4)
		game.audio.sfx("pickup")
		return true
	if not game.placing.pick_up(Grid.center(c), ch, true, layer):
		return false
	var from_facing := int(ch.hand.from_facing)
	game.placing.rotate_hand(ch)
	var spot: Vector3i = ch.hand.from
	if int(ch.hand.facing) != from_facing and game.placing.place_refusal(spot, ch, true) == "":
		var h: Dictionary = ch.hand
		game.placing._put_down(h, spot, int(h.facing))
	else:
		game.audio.sfx("fail")
		game.hud.day_ui.say("It will not fit that way round here.")
		game.placing._put_down(ch.hand, spot, from_facing)
	ch.hand = {}
	return true


## The tree key of the open card's piece ("" when it has no tree).
func storage_tree() -> String:
	var st := card_station()
	if st == null:
		return ""
	var key := ""
	if st.type == "hook" and Kitchen.has_node(st.kit_tool):
		key = st.kit_tool   # a hook's tree is its tool's: sponge, scourer and on (PRD 9.5)
	else:
		key = Upgrades.key_of(st.type, st.tier, st.base if st.type == "counter" else st.node)
	return key if Upgrades.has_tree(key) else ""


## The card's Upgrades: the tree of the piece where it stands, nothing lifted.
func storage_upgrades() -> void:
	var key := storage_tree()
	if key == "" or not storing():
		game.audio.sfx("fail")
		return
	var ch := game.shopper
	var st := card_station()
	ch.hand = {"id": st.type, "tier": st.tier, "price": 0, "facing": st.facing, "moving": true,
		"node": st, "in_place": true, "layer": game.card_layer, "from": Vector3i(st.cell.x, st.cell.y, 0), "from_facing": st.facing}
	game.hud.shop_ui.hide_shop()
	game.upgrading = true
	game.audio.sfx("tab", 0.08)
	game.hud.screens_ui.show_tree(key)


## Back from the tree to the card.
func storage_ingredients() -> void:
	if not game.upgrading:
		return
	game.shopper.hand = {}
	game.upgrading = false
	game.hud.screens_ui.hide_tree()
	game.audio.sfx("tab", 0.08)
	game.hud.shop_ui.show_shop()


## Held E after it opened a card (review, item 4): once held HOLD_MOVE, the card shuts
## and the piece is picked up to move. The same fill bar as every hold shows it.
func _tick_card_hold(ch: Player, held: bool, delta: float) -> void:
	if not game._card_hold.has(ch):
		return
	if not held or game.shopper != ch or not storing() or game.upgrading:
		game._card_hold.erase(ch)
		ch.stop_giving()
		return
	game._card_hold[ch] = float(game._card_hold[ch]) + delta
	var st := card_station()
	if st != null:
		ch.show_hold(st.global_position, float(game._card_hold[ch]) / Game.HOLD_MOVE, "move")
	if float(game._card_hold[ch]) >= Game.HOLD_MOVE:
		game._card_hold.erase(ch)
		ch.stop_giving()
		card_act("move")


## Whether the piece E would lift there keeps boxes itself (a double counter being split
## does not: its boxes stay with the counter left standing).
func _keeps_boxes(st: Station, layer: String) -> bool:
	if layer == "base" and Kitchen.unstacked(st.base) != "" and st.stacked:
		return false
	return layer in ["base", "high"] and Kitchen.slots_of(game.kitchen.get_piece(st.cell, layer)) > 0


## Which piece on a cell E picks up: a tool off its counter, else what hangs on the wall,
## else what stands on the floor. Once a wall piece is put back where it was, the next E
## there takes what stands under it, so a sink under a shelf can be reached.
func _lift_layer(c: Vector2i, ch: Player) -> String:
	var st: Station = game.stations.get(c)
	if st != null and st.has_node("till"):
		return "till"   # the till comes off before what it stands on
	if st != null and Kitchen.is_top(st.type) and not Kitchen.grows_from_counter(st.node):
		return "top"   # a stove is its counter upgraded: it lifts whole
	if game.highs.has(c) and (st == null or ch.get_meta("low_next", Game.NO_CELL) != c):
		return "high"
	return "base" if st != null else ""


## The name of what E would pick up, for the prompt ("Pick up sink").
func lift_name(ch: Player = null) -> String:
	ch = game._me(ch)
	var p := game.room_edit._piece_in_front(ch)
	if p == Vector3.INF:
		return ""
	if game.wall_nodes.has(GamePlacing.snap_edge(p)):
		return GamePlacing.piece_name({"id": "screen", "tier": 1}).to_lower()
	var c := Grid.to_cell(p)
	if _lift_layer(c, ch) == "till":
		return "till"
	var st: Station = game.highs.get(c) if _lift_layer(c, ch) == "high" else game.stations.get(c)
	if st == null:
		return "rug"
	return GamePlacing.piece_name({"id": st.type, "tier": st.tier}).to_lower()


## The name of the piece E would open a card for ("sink", "wall shelf").
func _card_name(ch: Player) -> String:
	var c := Grid.to_cell(game.room_edit._piece_in_front(ch))
	var layer := _card_layer_at(c, ch)
	var st: Station = game.highs.get(c) if layer == "high" else game.stations.get(c)
	return "" if st == null else GamePlacing.piece_name({"id": st.type, "tier": st.tier}).to_lower()


## A piece lifted for its card comes down where it stood, nothing moved.
func _settle(ch: Player) -> void:
	var n: Variant = ch.hand.get("node")
	if n is Node3D and is_instance_valid(n):
		(n as Node3D).position.y = float(ch.hand.get("y", (n as Node3D).position.y))
	if ch.hand.get("layer", "") == "high":
		ch.set_meta("low_next", Vector2i(ch.hand.from.x, ch.hand.from.y))
	ch.hand = {}


## Ranks a box on the card: stored here, then ones that fit, then ones that do not.
func _storage_rank(bp: Dictionary) -> int:
	if bp.get("stored", false):
		return 0
	return 1 if game.kitchen.store_refusal(game.storing_cell, bp.id) == "" else 2


## What making the open card's counter a fridge would cost, when that is all that keeps
## box `id` out of it (review, item 11); 0 when it is not on offer.
func fridge_offer(id: String) -> int:
	var st := card_station()
	if st == null or game.card_layer != "base" or st.type != "counter" or st.item != "":
		return 0
	var why := game.kitchen.store_refusal(game.storing_cell, id)
	if why != "Needs a fridge":
		return 0
	var key := storage_tree()
	if key == "" or not Upgrades.can_buy(key, "fridge", 999999, game.ledger.level()):
		return 0
	return Upgrades.step_price("fridge")


## Takes a box out of the open card's cell, or puts one in. The card stays open. A box
## that needs a fridge, on a counter that can become one, makes it one first.
func _storage_buy(bp: Dictionary) -> bool:
	var ok := false
	if not bp.get("stored", false) and fridge_offer(bp.id) > 0:
		var ch := game.shopper
		var st := card_station()
		ch.hand = {"id": st.type, "tier": st.tier, "price": 0, "facing": st.facing, "moving": true,
			"node": st, "in_place": true, "layer": "base", "from": Vector3i(st.cell.x, st.cell.y, 0), "from_facing": st.facing}
		var made := game.upgrades.buy_upgrade("fridge", ch)
		ch.hand = {}
		if not made:
			return false
	if bp.get("stored", false):
		ok = game.kitchen.unstore(game.storing_cell, bp.id)
	else:
		ok = game.placing._store_box(game.storing_cell, bp.id)
	if not ok:
		game.audio.sfx("fail")
		return false
	game.world._show_boxes(game.storing_cell)
	var st := game.world.station_at(game.storing_cell)
	if st:
		st.used()   # a fridge or cabinet swings its door open
	game.menu_stock.menu_changed()
	game.audio.sfx("putdown")
	game.hud.shop_ui._refresh_catalog()
	return true
