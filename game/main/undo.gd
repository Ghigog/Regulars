class_name GameUndo
extends RefCounted
## Undo in the build phase: one stack of steps for the room, shared by every chef. A step
## is what it takes to reverse one committed change (a piece placed, moved or sold, or a
## stroke of floor, wall, door or finish) and the exact money that changed hands. Undo
## reuses the placing code to reverse it, and does nothing at all if it cannot finish.
## Redo is a second stack: an undone step waits there, and redo does it again through the
## same code a player uses (which pays and records the step afresh). Any new action of the
## player empties it. Both stacks are cleared when the build phase ends or a game starts;
## neither is ever saved.

const MAX_STEPS := 60

var game: Game
var steps: Array[Dictionary] = []
var redo_steps: Array[Dictionary] = []
var _replaying := false           # a redo is acting: what it records must not empty the redo stack
var _opposite: Dictionary = {}    # the step that would redo (or undo) what was just done


func _init(game_: Game) -> void:
	game = game_


## Whether there is anything to undo.
func has_steps() -> bool:
	return not steps.is_empty()


## Whether there is anything to redo.
func has_redo() -> bool:
	return not redo_steps.is_empty()


## Forgets every step; a sold piece kept for its undo is thrown away for good.
func clear() -> void:
	for s in steps:
		_forget(s)
	steps.clear()
	redo_steps.clear()   # nothing here is kept off the floor: a redo acts on what stands
	if game.hud != null:
		game.hud.buttons_ui.update()


func _forget(s: Dictionary) -> void:
	if s.kind == "sell" and s.hand.get("node") != null:
		_free_node(s.hand.node)


static func _free_node(n: Node3D) -> void:
	if is_instance_valid(n):
		n.queue_free()


func _push(s: Dictionary) -> void:
	if not _replaying:
		redo_steps.clear()
	steps.append(s)
	if steps.size() > MAX_STEPS:
		_forget(steps.pop_front())
	game.hud.buttons_ui.update()


# ---------------------------------------------------------------- recording

## A new piece or box was bought and put down: `node` is what stands there now (null for a box).
## `hand` is the hand it was bought in, for a redo.
func record_placed(spot: Vector3i, id: String, node: Object, paid: int, hand := {}) -> void:
	_push({"kind": "place", "spot": spot, "id": id, "node": node, "paid": paid, "hand": hand.duplicate()})


## A carried piece (`h`, the hand it was carried in) was put down at `spot` facing `facing`.
func record_moved(h: Dictionary, spot: Vector3i, facing: int) -> void:
	if spot == h.from and facing == int(h.from_facing):
		return   # put back where it was: nothing changed
	_push({"kind": "move", "spot": spot, "id": h.id, "node": h.get("node"), "from": h.from,
		"from_facing": int(h.from_facing), "layer": h.get("layer", ""), "facing": facing})


## The piece in `h` was sold for `refund`; its node is kept, hidden, until the step is dropped.
func record_sold(h: Dictionary, refund: int) -> void:
	var node: Node3D = h.get("node")
	if node is Station and (node as Station).lamp != null:
		var lamp: OmniLight3D = (node as Station).lamp
		lamp.visible = false
		game._sconces.erase(lamp)
	_push({"kind": "sell", "hand": h.duplicate(), "refund": refund})


## What the plan was before a change, for `record_plan`.
func plan_snapshot() -> Dictionary:
	var p: Floorplan = game.plan
	return {"floors": p.floors.duplicate(), "built": p.built.duplicate(), "openings": p.openings.duplicate(),
		"finishes": p.finishes.duplicate(), "windows": p.windows.duplicate(), "treat": game.treat_laid.duplicate(), "money": game.ledger.money}


## A change to the plan (one tool press, or one whole drag) was made since `before`.
func record_plan(before: Dictionary) -> void:
	before["paid"] = before.money - game.ledger.money   # negative when it paid out
	before["kind"] = "plan"
	_push(before)


## A lot block was bought for `price`.
func record_lot(block: Vector2i, price: int) -> void:
	_push({"kind": "lot", "block": block, "paid": price})


## A batch of flyers was bought.
func record_flyers() -> void:
	_push({"kind": "flyers", "paid": Town.FLYER_PRICE})


## A sponge was bought into `chef`'s hands.
func record_sponge(chef: Player, price: int) -> void:
	_push({"kind": "sponge", "chef": chef, "paid": price})


## An upgrade of a piece (or a treatment's box, whose `node` is null and which is at `spot`)
## from tree key `from` to `to` was bought for `price`; `node` is the piece after it.
func record_upgraded(node: Node3D, from: String, to: String, price: int, spot: Vector3i) -> void:
	_push({"kind": "upgrade", "node": node, "from": from, "to": to, "paid": price, "spot": spot})


# ---------------------------------------------------------------- undoing

## Whether undo can act for this chef now: the build phase, the room free and nothing in hand.
func can_undo(ch: Player) -> bool:
	return game.phase == Game.Phase.BUILD and ch != null and ch.hand.is_empty() and game.shopper != ch


## Reverses the last step. Returns false (with the refusal feedback) when it cannot.
func undo(ch: Player = null) -> bool:
	ch = game._me(ch)
	if not can_undo(ch):
		return false
	if steps.is_empty():
		return _refuse("Nothing to undo")
	var s: Dictionary = steps.back()
	_opposite = s
	var why := ""
	match s.kind:
		"place": why = _undo_placed(s, ch)
		"move": why = _undo_moved(s, ch)
		"sell": why = _undo_sold(s, ch)
		"plan": why = _undo_plan(s, ch)
		"lot": why = _undo_lot(s)
		"flyers": why = _undo_flyers(s)
		"sponge": why = _undo_sponge(s)
		"upgrade": why = _undo_upgraded(s)
	if why != "":
		return _refuse(why)
	steps.pop_back()
	redo_steps.append(_opposite)
	return _done()


func _done() -> bool:
	game.audio.sfx("putdown")
	game.hud.hints_ui.show_build()
	game.hud.buttons_ui.update()
	return true


## Whether redo can act for this chef now: the same conditions as undo.
func can_redo(ch: Player) -> bool:
	return can_undo(ch)


## Does the last undone step again, paying what it paid. Returns false (with the refusal
## feedback, nothing changed) when it cannot.
func redo(ch: Player = null) -> bool:
	ch = game._me(ch)
	if not can_redo(ch):
		return false
	if redo_steps.is_empty():
		return _refuse("Nothing to redo")
	var s: Dictionary = redo_steps.back()
	_opposite = s
	_replaying = true   # what the action records goes on the undo stack, and the redo stack stays
	var why := ""
	match s.kind:
		"place": why = _redo_placed(s, ch)
		"move": why = _redo_moved(s, ch)
		"sell": why = _redo_sold(s, ch)
		"plan": why = _undo_plan(s, ch, true)
		"lot": why = _redo_lot(s)
		"flyers": why = _redo_flyers(s)
		"sponge": why = _redo_sponge(s, ch)
		"upgrade": why = _redo_upgraded(s, ch)
	_replaying = false
	if why != "":
		return _refuse(why)
	redo_steps.pop_back()
	if s.kind == "plan":
		steps.append(_opposite)   # the plan's own step, with the snapshot from just before
	return _done()


func _refuse(why: String) -> bool:
	game.audio.sfx("fail")
	game.hud.day_ui.say(why)
	return false


func _undo_placed(s: Dictionary, ch: Player) -> String:
	var why := _lift(s, ch)
	if why != "":
		return why
	var n: Variant = ch.hand.get("node")
	if n is Node3D:
		if n is Station and (n as Station).lamp != null:
			game._sconces.erase((n as Station).lamp)
			(n as Station).lamp.queue_free()
		(n as Node3D).queue_free()
	ch.hand = {}
	game.ledger.refund(int(s.paid))
	return ""


func _undo_moved(s: Dictionary, ch: Player) -> String:
	var why := _lift(s, ch)
	if why != "":
		return why
	var h: Dictionary = ch.hand.duplicate()
	h.from = s.from
	h.from_facing = s.from_facing
	h.layer = s.layer
	return _put_back(h, ch)


func _undo_sold(s: Dictionary, ch: Player) -> String:
	var refund := int(s.refund)
	if game.ledger.money < refund:
		return "Not enough to buy it back"
	var why := _put_back(s.hand, ch, refund)
	var node: Variant = s.hand.get("node")
	if why == "" and node is Station and (node as Station).lamp != null:
		(node as Station).lamp.visible = true
		game._sconces.append((node as Station).lamp)
	return why


## Stands the carried piece `h` back on its `from` spot, paying `cost` for it; or says why not.
## On a refusal the hand is back where it was before the call and nothing has changed.
func _put_back(h: Dictionary, ch: Player, cost := 0) -> String:
	var picked: Dictionary = ch.hand
	ch.hand = h
	var why := game.placing.place_refusal(h.from, ch, true)
	if why != "":
		ch.hand = picked
		game.placing.cancel_hand(ch)
		return why
	game.ledger.spend(cost)
	game.placing._put_down(h, h.from, int(h.from_facing))
	ch.hand = {}
	return ""


## Swaps the plan for the one in step `s` and gives back what it paid (taking it again when
## `again`: a redo). The step that swaps it back is left in `_opposite`.
func _undo_plan(s: Dictionary, ch: Player, again := false) -> String:
	var paid := -int(s.paid) if again else int(s.paid)   # money given back; negative takes it
	if paid < 0 and game.ledger.money < -paid:
		return "Not enough to put that back" if not again else "Not enough to do that again"
	for c in game.chefs:
		if not (s.floors as Dictionary).has(c.cell()) and game.plan.has_floor(c.cell()):
			return "Someone is standing there"
	var now := plan_snapshot()
	now["kind"] = "plan"
	now["paid"] = s.paid
	_opposite = now
	if paid >= 0:
		game.ledger.refund(paid)
	else:
		game.ledger.spend(-paid)
	var p: Floorplan = game.plan
	p.floors = s.floors
	p.built = s.built
	p.openings = s.openings
	p.finishes = s.finishes
	p.windows = s.windows
	game.treat_laid = s.treat
	game.world._sync_grid()
	game.floor_dirt.redraw()
	game.menu_stock.menu_changed()
	game.room_edit._plan_changed()
	return ""


func _undo_lot(s: Dictionary) -> String:
	var b: Vector2i = s.block
	var r := Lot.block_rect(b)
	for c in game.chefs:
		if r.has_point(c.cell()):
			return "Someone is standing there"
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if game.plan.has_floor(Vector2i(x, y)) or game.stations.has(Vector2i(x, y)):
				return "It has changed since"
	if not game.lot.unbuy(b):
		return "It has changed since"
	game.ledger.refund(int(s.paid))
	game.world._sync_grid()
	game.room_edit._plan_changed()
	return ""


func _redo_lot(s: Dictionary) -> String:
	if not game.lot.buyable().has(s.block):
		return "It has changed since"
	if game.ledger.money < game.lot.next_price():
		return "A new lot costs $%d. You have $%d." % [game.lot.next_price(), game.ledger.money]
	return "" if game.lot_view.buy(s.block) else "It has changed since"


func _undo_flyers(s: Dictionary) -> String:
	if not game.flyers_out:
		return "It has changed since"
	game.flyers_out = false
	game.ledger.refund(int(s.paid))
	return ""


func _redo_flyers(s: Dictionary) -> String:
	if game.flyers_out:
		return "It has changed since"
	if game.ledger.money < int(s.paid):
		return "Flyers cost $%d" % int(s.paid)
	return "" if game.room_edit.buy_flyers() else "It has changed since"


## The sponge is refunded only while that very sponge, still clean, is in the chef's hands.
func _undo_sponge(s: Dictionary) -> String:
	var chef: Player = s.chef
	if not is_instance_valid(chef) or CleanKit.held_tool(chef) != "sponge" or CleanKit.held_used(chef) != 0:
		return "It has changed since"
	chef.set_held("")
	game.ledger.refund(int(s.paid))
	return ""


func _redo_sponge(s: Dictionary, ch: Player) -> String:
	if ch.held != "":
		return "Hands full: put that down first."
	if game.ledger.money < int(s.paid):
		return "A sponge costs $%d" % int(s.paid)
	return "" if game.placing.pick_catalog("sponge", 1, ch) else "It has changed since"


## Whether `n` is a piece standing in the room (on its cell, or hung over it).
func _stands(n: Variant) -> bool:
	return n is Station and is_instance_valid(n) and not (n as Station).is_queued_for_deletion() \
			and (game.stations.get((n as Station).cell) == n or game.highs.get((n as Station).cell) == n)


## Turns the upgraded piece back into what it was, where it stands, and refunds the step.
func _undo_upgraded(s: Dictionary) -> String:
	var from: String = s.from
	var to: String = s.to
	var price := int(s.paid)
	var cell := Vector2i(s.spot.x, s.spot.y)
	var up: Station = null
	if Upgrades.is_treatment(to):   # a box in its slot
		if not game.kitchen.unstore(cell, to):
			return "It has changed since"
		game.kitchen.store(cell, from)
		game.upgrades._swap_treatment(Treatments.key_of(to), Treatments.key_of(from))
	else:
		if not _stands(s.node):
			return "It has changed since"
		var st: Station = s.node
		cell = st.cell
		s.high = st.high
		var placing := game.placing
		if Upgrades.is_link(to):   # a stove grown on a counter: the top comes off, the counter stays
			var spent := placing.spent_tonight(st)
			game.world._off_counter(st)
			st.queue_free()
			placing.set_spent_tonight(game.stations[cell], spent - price)
		elif (Station.is_seat(st.type) or Station.is_table(st.type)) and Upgrades.catalog_id(from) != st.type:
			up = game.upgrades._remake_seat(st, from, true, -price)
		else:
			if Upgrades.is_tiered(from):
				st.tier = Upgrades.tier_of(from)
				st.set_base(st.base)
			elif game.upgrades.keeps_tool(st) and Kitchen.tool_of(to) != "":
				game.clean_kit.upgrade_tool(st, Kitchen.tool_of(from))
			elif st.high:
				up = Station.new()
				game.add_child(up)
				up.setup(from, st.cell, st.tier, st.facing, st.base, st.pass_look)
				game.highs.erase(st.cell)
				game.kitchen.cells[st.cell].high = ""
				game.world._hang(up, st.cell)
				placing.set_spent_tonight(up, placing.spent_tonight(st))
				st.queue_free()
			elif st.type == "counter" or (Kitchen.slots_of(from) > 0 and not Kitchen.is_top(st.type)):
				st.set_base(from)
				game.kitchen.set_cell(st.cell, from)
			else:
				up = game.upgrades._remake_in_place(st, from)
			var piece: Station = up if up != null else st
			placing.set_spent_tonight(piece, placing.spent_tonight(piece) - price)
	s.cell = cell
	game.ledger.refund(price)
	game.world._show_boxes(cell)
	game.menu_stock.menu_changed()
	return ""


## Buys the upgrade again where the piece (or box) stands, from its card, as a player does.
func _redo_upgraded(s: Dictionary, ch: Player) -> String:
	var cell: Vector2i = s.cell
	var to: String = s.to
	if game.ledger.money < int(s.paid):
		return "Not enough to buy that again"
	if Upgrades.is_treatment(to):
		ch.hand = {"id": s.from, "tier": 1, "price": 0, "facing": 0, "moving": true, "in_place": true,
			"from": Vector3i(cell.x, cell.y, 0), "from_facing": 0}
	else:
		var st: Station = (game.highs if s.get("high", false) else game.stations).get(cell)
		if st == null:
			return "It has changed since"
		ch.hand = {"id": st.type, "tier": st.tier, "price": 0, "facing": st.facing, "moving": true,
			"node": st, "in_place": true, "layer": "high" if st.high else "base",
			"from": Vector3i(cell.x, cell.y, 0), "from_facing": st.facing}
	var ok: bool = game.upgrades.hand_key(ch) == s.from and game.upgrades.buy_upgrade(to, ch)
	ch.hand = {}
	return "" if ok else "It has changed since"


## Places a bought piece again, from the hand it was bought in.
func _redo_placed(s: Dictionary, ch: Player) -> String:
	var h: Dictionary = s.hand.duplicate()
	if game.ledger.money < int(h.price):
		return "Not enough to buy it again"
	ch.hand = h
	var why := game.placing.place_refusal(s.spot, ch)
	if why == "" and not game.placing.place(s.spot, ch):
		why = "It has changed since"
	ch.hand = {}
	return why


## Lifts what stands where step `s` left it (`spot`) and puts it back down the way it went.
func _redo_moved(s: Dictionary, ch: Player) -> String:
	var why := _lift({"spot": s.from, "id": s.id, "node": null}, ch, true)   # whatever stands there: a redone piece is a new node
	if why != "":
		return why
	ch.hand.facing = int(s.facing)
	why = game.placing.place_refusal(s.spot, ch)
	if why == "" and not game.placing.place(s.spot, ch):
		why = "It has changed since"
	if why != "":
		game.placing.cancel_hand(ch)
	ch.hand = {}
	return why


func _redo_sold(s: Dictionary, ch: Player) -> String:
	var h: Dictionary = s.hand
	var why := _lift({"spot": h.from, "id": h.id, "node": null}, ch, true)
	if why != "":
		return why
	why = game.placing.sell_block(ch)
	if why != "" or not game.placing.sell_hand(ch):
		game.placing.cancel_hand(ch)
		return why if why != "" else "It has changed since"
	return ""


## Picks the piece of step `s` up off its spot into the chef's hand; or says why it cannot.
## A hand that is not the very piece (a box in its way, a changed room) is put back.
func _lift(s: Dictionary, ch: Player, whole := false) -> String:
	var spot: Vector3i = s.spot
	var cell := Vector2i(spot.x, spot.y)
	var node: Variant = s.node
	if s.id == "screen":
		if game.wall_nodes.get(spot) != node:
			return "It has changed since"
		game.wall_nodes.erase(spot)
		game.grid.walls.erase(spot)
		var n: Node3D = node
		n.visible = false
		ch.hand = {"id": "screen", "tier": int(n.get_meta("tier", 1)), "price": 0, "facing": 0, "moving": true,
			"node": n, "from": spot, "from_facing": 0}
		return ""
	var layer := ""
	if node is Station:
		layer = "high" if (node as Station).high else "base"
	elif s.id == "till":
		layer = "till"
	if not game.placing.pick_up(Grid.center(cell), ch, whole, layer):
		return "It has changed since"
	if (node == null and ch.hand.id != s.id) or (node != null and ch.hand.get("node") != node):
		var box := Catalog.is_box(ch.hand.get("id", ""))
		game.placing.cancel_hand(ch)
		return "Empty it first" if box else "It has changed since"
	return ""
