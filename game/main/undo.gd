class_name GameUndo
extends RefCounted
## Undo in the build phase: one stack of steps for the room, shared by every chef. A step
## is what it takes to reverse one committed change (a piece placed, moved or sold, or a
## stroke of floor, wall, door or finish) and the exact money that changed hands. Undo
## reuses the placing code to reverse it, and does nothing at all if it cannot finish.
## The stack is cleared when the build phase ends or a game starts; it is never saved.

const MAX_STEPS := 60

var game: Game
var steps: Array[Dictionary] = []


func _init(game_: Game) -> void:
	game = game_


## Whether there is anything to undo.
func has_steps() -> bool:
	return not steps.is_empty()


## Forgets every step; a sold piece kept for its undo is thrown away for good.
func clear() -> void:
	for s in steps:
		_forget(s)
	steps.clear()


func _forget(s: Dictionary) -> void:
	if s.kind == "sell" and s.hand.get("node") != null:
		_free_node(s.hand.node)


static func _free_node(n: Node3D) -> void:
	if is_instance_valid(n):
		n.queue_free()


func _push(s: Dictionary) -> void:
	steps.append(s)
	if steps.size() > MAX_STEPS:
		_forget(steps.pop_front())
	game.hud.buttons_ui.update()


# ---------------------------------------------------------------- recording

## A new piece or box was bought and put down: `node` is what stands there now (null for a box).
func record_placed(spot: Vector3i, id: String, node: Object, paid: int) -> void:
	_push({"kind": "place", "spot": spot, "id": id, "node": node, "paid": paid})


## A carried piece (`h`, the hand it was carried in) was put down at `spot` facing `facing`.
func record_moved(h: Dictionary, spot: Vector3i, facing: int) -> void:
	if spot == h.from and facing == int(h.from_facing):
		return   # put back where it was: nothing changed
	_push({"kind": "move", "spot": spot, "id": h.id, "node": h.get("node"), "from": h.from,
		"from_facing": int(h.from_facing), "layer": h.get("layer", "")})


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
		"finishes": p.finishes.duplicate(), "treat": game.treat_laid.duplicate(), "money": game.ledger.money}


## A change to the plan (one tool press, or one whole drag) was made since `before`.
func record_plan(before: Dictionary) -> void:
	before["paid"] = before.money - game.ledger.money   # negative when it paid out
	before["kind"] = "plan"
	_push(before)


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
	var why := ""
	match s.kind:
		"place": why = _undo_placed(s, ch)
		"move": why = _undo_moved(s, ch)
		"sell": why = _undo_sold(s, ch)
		"plan": why = _undo_plan(s, ch)
	if why != "":
		return _refuse(why)
	steps.pop_back()
	game.audio.sfx("putdown")
	game.hud.hints_ui.show_build()
	game.hud.buttons_ui.update()
	return true


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


func _undo_plan(s: Dictionary, ch: Player) -> String:
	var paid := int(s.paid)
	if paid < 0 and game.ledger.money < -paid:
		return "Not enough to put that back"
	for c in game.chefs:
		if not (s.floors as Dictionary).has(c.cell()) and game.plan.has_floor(c.cell()):
			return "Someone is standing there"
	if paid >= 0:
		game.ledger.refund(paid)
	else:
		game.ledger.spend(-paid)
	var p: Floorplan = game.plan
	p.floors = s.floors
	p.built = s.built
	p.openings = s.openings
	p.finishes = s.finishes
	game.treat_laid = s.treat
	game.world._sync_grid()
	game.floor_dirt.redraw()
	game.menu_stock.menu_changed()
	game.room_edit._plan_changed()
	return ""


## Picks the piece of step `s` up off its spot into the chef's hand; or says why it cannot.
## A hand that is not the very piece (a box in its way, a changed room) is put back.
func _lift(s: Dictionary, ch: Player) -> String:
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
	if not game.placing.pick_up(Grid.center(cell), ch, false, layer):
		return "It has changed since"
	if (node == null and ch.hand.id != s.id) or (node != null and ch.hand.get("node") != node):
		var box := Catalog.is_box(ch.hand.get("id", ""))
		game.placing.cancel_hand(ch)
		return "Empty it first" if box else "It has changed since"
	return ""
