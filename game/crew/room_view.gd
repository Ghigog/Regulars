class_name CrewRoomView
extends RefCounted
## The room as the task board sees it (world()): leftovers, what is carried, the bill
## place, assembly cells, boxes, free tools and surfaces, plates, and the nearest of a kind.

var crew: Crew


func _init(crew_: Crew) -> void:
	crew = crew_


# ---------------------------------------------------------------- the room, for the board

## The room as the task board reads it (see the top of sim/jobs.gd).
func world() -> Dictionary:
	var tools := []
	var storage := []
	var items := []
	var made: Array = []
	var tables := []
	var sinks := []
	var bins := []
	var ready := []
	var has_sink := false
	var stack: Station = crew.game.world.find_station("plates")
	for st: Station in crew.game.stations.values():
		var c: Vector2i = st.cell
		var jobs := Kitchen.jobs_of(st.node) if Kitchen.has_node(st.node) else {}
		var is_tool := false
		for j: String in jobs:
			is_tool = is_tool or (Staff.TOOL_DUTIES.has(j) and float(jobs[j]) > 0.0)
		if is_tool:
			var row := {"id": c, "cell": c, "tool": st.node, "busy": st.item != "" or st.prep_by >= 0}
			if jobs.has("pour"):
				var drinks: Array[String] = crew.game.menu_stock.dispenser_drinks(st)
				if not drinks.is_empty():
					row.drinks = drinks
			tools.append(row)
		var kinds := []
		var boxed := []
		for b: String in crew.game.kitchen.stock(c):
			if Kitchen.is_cleaning(b):
				continue   # chemicals: nothing to cook (PRD 9.5)
			var si := Pantry.station_ingredient(b)
			(boxed if si.ready else kinds).append(si.id)
		if not kinds.is_empty() or not boxed.is_empty():
			storage.append({"cell": c, "kinds": kinds, "ready": boxed})
		var p := Tray.parse(st.item)
		if not p.is_empty():
			# On a tool, what it is being made into: a lemon on a juicer is lemonade, a scoop
			# of ice cream in a blender a milkshake (PRD 8.6).
			var into: String = p.id
			if is_tool and p.state in ["raw", "prep"]:
				var pj: Array = crew.game.cooking.press_job(st, p)
				if str(pj[1]) != "":
					into = str(pj[1])
			if p.state == "raw" or into != p.id:
				var cooking: bool = st.is_heat_tool() or st.prep_by >= 0
				var it := {"id": "c:%d,%d" % [c.x, c.y], "kind": into, "cell": c, "state": "cooking" if cooking else "raw"}
				if into != p.id or p.state != "raw":
					it.form = st.item
				if is_tool:
					it.station = c
				items.append(it)
			elif p.state == "prep":
				made.append(p.id)
		if Station.is_table(st.type):
			var tid := "%d,%d" % [c.x, c.y]
			var waiting: Array = crew.game.seating._guests_to_order(st)
			if not waiting.is_empty() and crew.game.tables.lead(st) == st:   # one order for the whole table
				tables.append({"id": tid, "cell": c, "state": "order", "wait": _wait_of(waiting[0])})
			if st.dirty > 0:
				tables.append({"id": tid, "cell": c, "state": "clear", "wait": st.dirty_age})
		match st.type:
			"sink":
				has_sink = true
				if stack != null:
					sinks.append({"cell": c, "dishes": st.dirty})
			"bin":
				bins.append({"cell": c, "full": st.count >= Crew.BIN_FULL})
		if st.item == "dish" and st.dish != null and st.dish.is_ready(crew.game.menu.items) and not crew._claims.has(c):
			ready.append(st)
	if not has_sink:
		tables = tables.filter(func(t: Dictionary) -> bool: return t.state != "clear")
	for hand: Player in crew.game.serving.hands():
		var p := Tray.parse(hand.held)
		if p.is_empty():
			continue
		# A helper fetching or working for a ticket holds what it will be made into.
		var task: Dictionary = (hand as Helper).task if hand is Helper else {}
		if str(task.get("type", "")) in ["fetch", "prep"] and task.has("kind") and str(task.get("job", "none")) != "none" \
				and hand.held == str(task.get("hold", HelperWork.hold_for(str(task.kind)))):
			items.append({"id": "h:%d" % hand.get_instance_id(), "kind": str(task.kind), "cell": hand.cell(), "state": "held"})
		elif p.state == "raw":
			items.append({"id": "h:%d" % hand.get_instance_id(), "kind": p.id, "cell": hand.cell(), "state": "held"})
		elif p.state == "prep":
			made.append(p.id)
	# Tickets: what each still needs, less what is made and lying about.
	var rows := []
	for tk: Dictionary in crew.game.tickets:
		rows.append({"id": int(tk.id), "needs": crew.task_end._ticket_needs(tk)})
	var lacks := HelperWork.ticket_lacks(rows, made)
	var burnt := []
	for st: Station in crew.game.stations.values():
		var p := Tray.parse(st.item)
		if not p.is_empty() and p.state == "burnt" and Kitchen.has_node(st.node):
			burnt.append({"cell": st.cell, "kind": p.id, "duty": Staff.duty_of_tool(st.node)})
	var tickets := []
	for tk: Dictionary in crew.game.tickets:
		var cell: Vector2i = _assembly_cell()
		for e: Dictionary in crew.task_end._tagged(int(tk.id)):
			if e.st != null:
				cell = e.st.cell
				break
		# What a helper is carrying over to it is on its way: nobody else assembles it meanwhile.
		var coming := false
		for h in crew.helpers:
			coming = coming or (Tray.parse(h.held).get("state", "") == "prep" and int(h.task.get("ticket", -1)) == int(tk.id))
		var unplated := crew.task_end._unplated(tk)
		var on_plates := unplated.is_empty() and crew.task_end._ticket_needs(tk).is_empty()
		tickets.append({"id": int(tk.id), "cell": cell, "lacks": lacks[int(tk.id)], "wait": _wait_of(tk.guest),
			"assembled": on_plates or coming, "plated": unplated.is_empty() or not _plates_left(tk, unplated),
			"started": unplated.size() < tk.order.lines.size() - tk.order.served_count(), "unplated": unplated.size()})
	var fallen := []
	var down: Dictionary = crew.game.floor_dirt.down
	for who in down:
		if is_instance_valid(who) and not (down[who].helper is Player):
			fallen.append({"id": who.get_instance_id(), "cell": down[who].cell, "wait": float(down[who].t)})
	var dirt := {}
	var grease := {}
	var mess: FloorMess = crew.game.floor_dirt.mess
	for c: Vector2i in mess.dirt:
		if mess.can_clean(c) and crew.game.grid.in_bounds(c):
			dirt[c] = mess.dirt[c]
			if mess.is_grease(c):
				grease[c] = true
	var bills := []   # PRD 11.4: tables ready to pay with no slip printed yet
	for st: Station in crew.game.paying.dining_tables():
		var n: int = crew.game.paying.table_number(st)
		if crew.game.paying.ready_to_pay(st) and not crew.game.paying.slip_out(n):
			var at: Station = _bill_place(st)
			bills.append({"id": n, "cell": at.cell, "wait": crew.game.clock - float(crew.game.paying.pay_since.get(st, crew.game.clock))})
	return {"stations": tools, "storage": storage, "items": items, "tickets": tickets, "dishes": _carries(ready),
		"leftovers": _leftovers(),
		"bills": bills, "tables": tables, "dirt": dirt, "grease": grease, "fallen": fallen, "sinks": sinks, "bins": bins,
		"burnt": burnt, "plate_room": _free_surfaces()}


## Plates and cups set out for an order that no longer needs them (its guest was served
## from elsewhere, or left): each goes to another ticket's item it can still become, else
## it is a leftover to clear away. A finished one somebody still wants is carried instead.
func _leftovers() -> Array:
	var wanted := {}
	for tk: Dictionary in crew.game.tickets:
		for l: Dictionary in tk.order.lines:
			if not tk.order._served(l):
				wanted[int(l.item.id)] = true
	var out := []
	for st: Station in crew.game.stations.values():
		if st.item != "dish" or st.dish == null or st.dish.ticket == -1 or crew._claims.has(st.cell):
			continue
		var d: Dish = st.dish
		var tk: Dictionary = crew.game.serving.find_ticket(d.ticket)
		if not tk.is_empty() and d.line >= 0 and d.line < tk.order.lines.size() and not tk.order._served(tk.order.lines[d.line]):
			continue
		d.ticket = -2   # orphaned: nobody's
		d.line = -1
		for other: Dictionary in crew.game.tickets:
			for li: int in crew.task_end._unplated(other):
				var it: Dictionary = other.order.lines[li].item
				if Dish.fits_vessel(d.vessel, it) and Dish.sub_of(d.ings, it):
					d.ticket = int(other.id)
					d.line = li
					break
			if d.ticket != -2:
				break
		if d.ticket != -2:
			continue
		var it := d.item_of(crew.game.menu.items)
		if not it.is_empty() and wanted.has(int(it.id)):
			continue
		out.append({"cell": st.cell})
	return out


## Finished plates and cups on worktops, matched to waiting guests who ordered them
## (a ticket's own first) and grouped two to a trip for the same table.
func _carries(ready: Array) -> Array:
	var promised := {}   # ticket id -> lines promised
	var by_table := {}   # table cell -> [{cell, wait}]
	for st: Station in ready:
		var it: Dictionary = st.dish.item_of(crew.game.menu.items)
		var best: Dictionary = {}
		for tk: Dictionary in crew.game.tickets:
			if tk.guest.state != "waiting" or tk.guest.table == null:
				continue
			var free := 0
			for l: Dictionary in tk.order.lines:
				if int(l.item.id) == int(it.id) and not tk.order._served(l):
					free += 1
			if free <= int(promised.get(int(tk.id), 0)):
				continue
			if best.is_empty() or int(tk.id) == st.dish.ticket:
				best = tk
			if int(tk.id) == st.dish.ticket:
				break
		if best.is_empty():
			continue
		promised[int(best.id)] = int(promised.get(int(best.id), 0)) + 1
		var tc: Vector2i = best.guest.table.cell
		if not by_table.has(tc):
			by_table[tc] = []
		by_table[tc].append({"cell": st.cell, "wait": _wait_of(best.guest)})
	var out := []
	for tc: Vector2i in by_table:
		var list: Array = by_table[tc]
		for i in range(0, list.size(), Player.HANDS):
			var group: Array = list.slice(i, i + Player.HANDS)
			var cells: Array = group.map(func(x: Dictionary) -> Vector2i: return x.cell)
			var id := "+".join(cells.map(func(c: Vector2i) -> String: return "%d,%d" % [c.x, c.y]))
			out.append({"id": id, "cell": cells[0], "cells": cells, "table": tc, "wait": group[0].wait})
	return out


## Where a table's bill is handed over: the till if one of them went to pay there.
func _bill_place(table: Station) -> Station:
	var till: Station = crew.game.paying.till_station()
	if till != null and crew.game.paying.party_at(table).any(func(g: Guest) -> bool: return g.state == "at_till" or g.state == "to_till"):
		return till
	return table


static func _wait_of(g: Guest) -> float:
	return (1.0 - g.mood.patience) * 30.0 if g != null else 0.0


## Where plates for a ticket are built: the pass nearest the plate stack, else the stack.
func _assembly_cell() -> Vector2i:
	var stack: Station = crew.game.world.find_station("plates")
	var from: Vector2i = stack.cell if stack != null else Vector2i.ZERO
	var best := from
	var best_d := INF
	for st: Station in crew.game.stations.values():
		if st.type == "pass" or st.pass_look:
			var d := float(absi(st.cell.x - from.x) + absi(st.cell.y - from.y))
			if d < best_d:
				best_d = d
				best = st.cell
	return best


## The box of `kind` stored at `cell` (a ready-made one with `ready`), or "". A treatment's
## box is chemicals, never food (PRD 9.5).
func _box_with(cell: Vector2i, kind: String, ready := false) -> String:
	for b: String in crew.game.kitchen.stock(cell):
		if Kitchen.is_cleaning(b):
			continue
		var si := Pantry.station_ingredient(b)
		if si.get("id", "") == kind and bool(si.get("ready", false)) == ready:
			return b
	return ""


## What a pick step expects to find: a made thing, or what is to be worked.
static func _pick_form(s: Dictionary) -> String:
	if s.has("hold") and str(s.get("state", "raw")) == "raw":
		return str(s.hold)
	return Tray.kind(str(s.get("state", "raw")), s.kind)


## Whether a press tool's own top is free for something to be worked on it (PRD 10.7):
## nothing on it, nobody working it or on their way to it.
func _free_tool_top(st: Station, h: Helper) -> bool:
	if not Kitchen.is_top(st.type) or st.is_heat_tool() or st.item != "" or st.prep_by >= 0:
		return false
	return not (crew._claims.has(st.cell) and crew._claims[st.cell] != h)


## The nearest free worktop (a counter or the pass) to `near`: nothing on it, nobody
## else heading there. With `pass_first`, the pass wins where it is free. Food (not
## `for_plate`) never takes the last free worktop while a ticket waits for its plates to
## be set out (PRD 10.7): one ticket's food lying about could otherwise fill every
## worktop and leave nowhere to plate it.
func _free_surface(near: Vector2i, h: Helper, pass_first := false, for_plate := false) -> Variant:
	var best: Variant = null
	var best_d := INF
	for st: Station in crew.game.stations.values():
		if not st.type in ["counter", "pass"] or st.item != "" or st.prep_by >= 0:
			continue
		if for_plate and st.has_node("till"):
			continue   # plates never go under the till
		if Kitchen.has_node(st.base) and Kitchen.fit_of(st.base) == "tall":
			continue   # a tall fridge or freezer has no worktop
		if crew.game.kitchen.holds_cleaning(st.cell):
			continue   # no food set down on chemicals (PRD 9.5)
		if crew._claims.has(st.cell) and crew._claims[st.cell] != h:
			continue
		var d := float(absi(st.cell.x - near.x) + absi(st.cell.y - near.y))
		if pass_first and (st.type == "pass" or st.pass_look):
			d -= 100.0
		if d < best_d:
			best_d = d
			best = st.cell
	if best != null and not for_plate and _free_surfaces() <= 1 and _plates_wanted():
		return null
	return best


## Whether the stacks hold a plate or cup for any of these lines of a ticket.
func _plates_left(tk: Dictionary, lines: Array) -> bool:
	for li: int in lines:
		var stack: Station = crew.game.world.find_station("cups" if tk.order.lines[li].item.course == "drink" else "plates")
		if stack != null and stack.count > 0:
			return true
	return false


## Whether a ticket has an item with no plate set out and the stack has one for it.
func _plates_wanted() -> bool:
	var stack: Station = crew.game.world.find_station("plates")
	if stack == null or stack.count <= 0:
		return false
	for tk: Dictionary in crew.game.tickets:
		if not crew.task_end._unplated(tk).is_empty():
			return true
	return false


## How many worktops are free for a plate, nobody on their way to them.
func _free_surfaces() -> int:
	var n := 0
	for st: Station in crew.game.stations.values():
		if st.type in ["counter", "pass"] and st.item == "" and st.prep_by < 0 and not crew._claims.has(st.cell) \
				and not st.has_node("till") \
				and not (Kitchen.has_node(st.base) and Kitchen.fit_of(st.base) == "tall") \
				and not crew.game.kitchen.holds_cleaning(st.cell):
			n += 1
	return n


## The nearest piece holding the prepped `kind` loose (on no plate), not in `taken`.
func _made_at(kind: String, near: Vector2i, taken: Dictionary) -> Variant:
	var want := Tray.kind("prep", kind)
	var best: Variant = null
	var best_d := INF
	for st: Station in crew.game.stations.values():
		if st.item != want or st.prep_by >= 0 or taken.has(st.cell) or st.draining():
			continue
		var d := float(absi(st.cell.x - near.x) + absi(st.cell.y - near.y))
		if d < best_d:
			best_d = d
			best = st.cell
	return best


func _nearest(type: String, near: Vector2i) -> Station:
	var best: Station = null
	var best_d := INF
	for st: Station in crew.game.stations.values():
		if st.type != type:
			continue
		var d := float(absi(st.cell.x - near.x) + absi(st.cell.y - near.y))
		if d < best_d:
			best_d = d
			best = st
	return best
