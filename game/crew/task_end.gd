class_name CrewTaskEnd
extends RefCounted
## A step finished (_finish) and what follows from it, the clean tools in the room, and the
## plating and assembly steps built for a ticket.

var crew: Crew


func _init(crew_: Crew) -> void:
	crew = crew_


## The work is done. Returns the steps to do next in its place ([] for none), or null
## when it went wrong in a way that ends the task.
func _finish(h: Helper, s: Dictionary) -> Variant:
	var st: Station = crew.game.world.station_at(s.at) if s.has("at") else null
	match str(s.do):
		"take":
			var box := crew.room_view._box_with(s.at, s.kind, s.get("ready", false))
			if box == "":
				return null
			crew.game.cooking._hold_from_box(h, box)
			crew.game.audio.sfx("pickup")
		"pick":
			h.set_held(st.item, st.current_quality())
			st.set_item("")
			crew.game.audio.sfx("pickup")
		"cook":
			var job := str(s.job)
			var q := st.q(job)
			var roll := JobBoard.roll_prep(crew.game.staff, h.person, q if q > 0.0 else 1.0)
			crew._using.erase(h)
			st.prep_by = -1
			st.set_item("")
			h.set_held(Tray.kind("prep", s.kind), float(roll.quality))
			PrepWidget.pop(st, Vector3(0, 2.0, 0), str(roll.result))
			crew.game.floor_dirt.prep_grease(job, str(roll.result), h.cell(), st)
			crew.game.audio.sfx("pickup")
		"pour":
			var roll := JobBoard.roll_prep(crew.game.staff, h.person, st.q("pour"))
			crew._using.erase(h)
			st.prep_by = -1
			var cup: Dish = crew.game.cooking._cup_in_hand(h, s.kind)
			if cup == null:
				return null
			cup.add(Tray.kind("prep", s.kind), float(roll.quality))
			h.show_held()
			PrepWidget.pop(st, Vector3(0, 2.0, 0), str(roll.result))
			crew.game.audio.sfx("pickup")
		"deliver", "add":
			crew._claims.erase(s.at)
			if st.item == "dish" and st.dish != null and st.dish.refusal(h.held, crew.game.menu.items) == "":
				crew.game.cooking._use_surface(st, false, h)   # "Add ..."
				crew.game.audio.sfx("putdown")
			elif st.item == "" and s.do == "deliver":
				st.set_item(h.held, h.held_quality)
				h.set_held("")
				crew.game.audio.sfx("putdown")
			else:
				return null
		"leave", "stash", "set_out":
			crew._claims.erase(s.at)
			if st.item != "":
				return null
			if h.held == "dishes":
				var d: Dish = h.dishes.back()
				h.drop_dish(d)
				st.set_dish(d)
				crew.game.audio.sfx("putdown")
				if h.held == "dishes" and s.do == "stash":
					return [{"do": "stash"}]   # one at a time
			elif h.held == "tray":
				h.set_held("")
			else:
				st.set_item(h.held, h.held_quality)
				h.set_held("")
				crew.game.audio.sfx("putdown")
		"take_plate":
			st.count -= 1
			st.refresh()
			var d := Dish.make(str(s.get("vessel", Dish.PLATE)))
			d.ticket = int(s.get("ticket", -1))
			d.line = int(s.get("line", -1))
			h.take_dish(d)
			crew.game.audio.sfx("pickup")
		"pick_dish":
			if st.item != "dish" or st.dish == null or not h.has_room():
				return null   # someone else took it meanwhile
			var d: Dish = st.dish
			st.set_item("")
			h.take_dish(d)
			crew.game.audio.sfx("pickup")
		"serve":
			var fed: Array[Guest] = crew.game.serving._dish_guests(st, h.dishes)
			if fed.is_empty():
				return [{"do": "stash"}]
			if not JobBoard.roll_task(crew.game.staff, h.person).ok:
				# A dropped plate: the food on the floor, the plates back to be filled again.
				crew.game.floor_dirt.mess.add_dirt(h.cell())
				for d: Dish in h.dishes:
					d.scrape()
				h.show_held()
				crew.game.hud.day_ui.refresh_tickets()
				crew.game.audio.sfx("fail")
				crew.game.audio.popup("Dropped it!", h.position + Vector3(0, 2.2, 0), Color(Build.WARN))
				return [{"do": "stash"}]
			crew.game.serving.serve_dishes(h, st)
			var skill := float(crew.game.staff.employee(h.person).skills.service)
			for g: Guest in fed:
				g.mood.delight(HelperWork.serve_joy(skill))
			if h.held == "dishes":
				return [{"do": "stash"}]
		"order":
			crew.game.serving.take_orders(st)
			h.punch()
		"write":   # always right
			h.set_held("bill")
			h.bill = crew.game.paying.right_bill(crew.game.paying.table_by_number(int(s.table)))
			crew.game.audio.sfx("page")
		"give":
			h.punch()
			if not crew.game.paying.give_bill(h, st):
				return null
		"clear":
			while st.dirty > 0 and h.has_room(true):
				crew.game.cooking.clear_one(st, h)
			crew.game.audio.sfx("pickup")
		"to_sink":
			st.dirty += h.dishes.size()
			st.dirty_cups += h.dishes.filter(func(d: Dish) -> bool: return d.vessel == Dish.CUP).size()
			st.refresh()
			h.set_held("")
			crew.game.audio.sfx("putdown")
		"bin":
			st.count += 1
			st.refresh()
			if h.held == "dishes":   # food scraped off, the plates and cups kept
				var keep: Array = h.dishes.filter(func(d: Dish) -> bool: return d.vessel != "")
				for d: Dish in keep:
					d.scrape()
				h.set_held("dishes", 1.0, keep, h.on_tray)
			else:
				h.set_held("")
		"restack":
			var d: Dish = h.dishes[0]
			h.drop_dish(d)
			st.count += 1
			st.refresh()
			crew.game.audio.sfx("putdown")
			if h.held == "dishes":
				return [{"do": "restack"}]
		"wash":
			var rack := crew.room_view.rack_near(st.cell)
			if rack == null:
				return null   # nowhere to put a clean dish: the step ends
			if rack.count >= Station.RACK_CAPACITY:
				crew.game.tidy.put_away(rack)   # a full rack is emptied back onto the stacks
			if JobBoard.roll_task(crew.game.staff, h.person).ok:
				var d: Dish = crew.game.cooking.wash_one(st)
				rack.count += 1
				if d.vessel == Dish.CUP:
					rack.rack_cups += 1
				rack.refresh()
				crew.game.audio.sfx("wash")
				crew.game.audio.burst(st.position + Vector3(0, 1.15, 0), "bubbles", 0.4)
				if st.dirty == 0:
					crew.game.tidy.put_away(rack)   # the last dish: the washer puts the clean ones away
			st.used()
			if st.dirty > 0:
				return [s.duplicate()]
		"empty_bin":
			st.count = 0
			st.refresh()
			h.set_held("rubbish_bag")
			crew.game.audio.sfx("pickup")
		"to_outside_bin":
			h.set_held("")
			crew.game.audio.sfx("putdown")
			Scenery.flip_bin_lid()
		"drop":
			h.set_held("")
		"wipe":
			var mess: FloorMess = crew.game.floor_dirt.mess
			if JobBoard.roll_task(crew.game.staff, h.person).ok:
				mess.clean(s.at, HelperWork.wipe_levels(float(crew.game.staff.employee(h.person).skills.clean),
					str(s.tool), mess.one_press(s.at)))
			crew.game.audio.sfx("step", 0.2)
			if mess.level(s.at) > 0:
				return [s.duplicate()]
			if h.held.begins_with(CleanKit.PREFIX):
				h.set_held("")
		"help":
			pass
	h.punch()
	return []


## The room's cleaning tool a helper wipes `cell` with: of the tools kept in homes here
## (the mop line in a bucket, the sponge line on a hook, PRD 9.5) one their duties cover
## that works on this dirt, the one clearing most a press; else `fallback`.
func _room_clean_tool(duties: Array, cell: Vector2i, fallback: String) -> String:
	var mess: FloorMess = crew.game.floor_dirt.mess
	var best := ""
	for st: Station in crew.game.stations.values() + crew.game.highs.values():
		var t: String = st.kit_tool
		if t == "" or not duties.has(Staff.clean_duty(t)) or CleanTools.refusal(mess, cell, t, 0) != "":
			continue
		if best == "" or int(CleanTools.TOOLS[t].levels) > int(CleanTools.TOOLS[best].levels):
			best = t
	return best if best != "" else fallback


## The plates and cups set out for a ticket: [{dish, st}], `st` the worktop it is on
## (null: in someone's hands).
func _tagged(ticket: int) -> Array:
	var out := []
	for st: Station in crew.game.stations.values():
		if st.item == "dish" and st.dish != null and st.dish.ticket == ticket:
			out.append({"dish": st.dish, "st": st})
	for hand: Player in crew.game.serving.hands():
		for d: Dish in hand.dishes:
			if d.ticket == ticket:
				out.append({"dish": d, "st": null})
	return out


## A ticket's lines not yet served with no plate or cup set out for them.
func _unplated(tk: Dictionary) -> Array[int]:
	var order: Tray = tk.order
	var with := {}
	for e: Dictionary in _tagged(int(tk.id)):
		with[e.dish.line] = true
	var out: Array[int] = []
	for li in order.lines.size():
		if not order._served(order.lines[li]) and not with.has(li):
			out.append(li)
	return out


## What a ticket still needs on its plates and in its cups: ingredient ids, a kind twice
## for two. A line with nothing set out needs all of it.
func _ticket_needs(tk: Dictionary) -> Array:
	var order: Tray = tk.order
	var by_line := {}
	for e: Dictionary in _tagged(int(tk.id)):
		by_line[e.dish.line] = e.dish
	var out: Array = []
	for li in order.lines.size():
		var l: Dictionary = order.lines[li]
		if order._served(l):
			continue
		if by_line.has(li):
			out.append_array((by_line[li] as Dish).needs_for(l.item))
		else:
			out.append_array(l.item.ingredients)
	return out


## The worktop holding a ticket's plate or cup that still needs `kind`, or null.
func _dish_needing(ticket: int, kind: String) -> Station:
	var tk: Dictionary = crew.game.serving.find_ticket(ticket)
	if tk.is_empty() or kind == "":
		return null
	for e: Dictionary in _tagged(ticket):
		if e.st == null:
			continue
		var d: Dish = e.dish
		if d.line >= 0 and d.line < tk.order.lines.size() and d.needs_for(tk.order.lines[d.line].item).has(kind):
			return e.st
	return null


## Setting out a plate (or a cup) for each of a ticket's items that has none yet. null
## when there is nothing to set out or nothing to set it out with.
func _plate_steps(h: Helper, ticket: int) -> Variant:
	var tk: Dictionary = crew.game.serving.find_ticket(ticket)
	if tk.is_empty() or h.held != "":
		return null
	var out := []
	var left := {"plates": 0, "cups": 0}
	var room := crew.room_view._free_surfaces()
	for li: int in _unplated(tk):
		if room <= 0:
			break
		var it: Dictionary = tk.order.lines[li].item
		var type := "cups" if it.course == "drink" else "plates"
		var stack: Station = crew.game.world.find_station(type)
		if stack == null or stack.count - int(left[type]) <= 0:
			continue
		left[type] = int(left[type]) + 1
		room -= 1
		out.append({"do": "take_plate", "at": stack.cell, "ticket": ticket, "line": li, "vessel": Tray.vessel_of(it)})
		out.append({"do": "set_out", "ticket": ticket})
	return out if not out.is_empty() else null


## A ticket's plates built from what is made: its plates and cups set out first where it
## has none, then each made thing it still needs picked up and added. null for nothing to do.
func _assemble_steps(h: Helper, ticket: int) -> Variant:
	var tk: Dictionary = crew.game.serving.find_ticket(ticket)
	if tk.is_empty() or h.held != "":
		return null
	var out := []
	var plates: Variant = _plate_steps(h, ticket)
	if plates != null:
		out.append_array(plates)
	var near := crew.room_view._assembly_cell()
	var taken := {}
	var picks := 0
	for kind: String in _ticket_needs(tk):
		var src: Variant = crew.room_view._made_at(kind, near, taken)
		if src == null:
			continue
		taken[src] = true
		picks += 1
		out.append({"do": "pick", "at": src, "kind": kind, "state": "prep"})
		out.append({"do": "add", "ticket": ticket})
	return out if picks > 0 or plates != null else null
