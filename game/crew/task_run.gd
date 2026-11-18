class_name CrewTaskRun
extends RefCounted
## A helper's task walked step by step (HelperWork.steps): starting the next step, standing
## where it is done, opening, working and polling a station.

var crew: Crew


func _init(crew_: Crew) -> void:
	crew = crew_


# ---------------------------------------------------------------- walking the steps

func _run(h: Helper, delta: float) -> void:
	var s: Dictionary = h.steps[0]
	if not h.step_started:
		h.step_started = true
		if not _start(h, s):
			crew._fail(h)
			return
		s = h.steps[0]   # an assemble step has become its parts
	if h.work_left < 0.0:
		if not h.arrived():
			if h.path.is_empty() and h.cell() != h.stand and not h.go_to(h.stand):
				crew._fail(h)
			return
		if s.has("at"):
			h.face(s.at)
		var t := _work(h, s)
		if t < 0.0:
			crew._fail(h)
			return
		h.work_left = t
		s.total = t
	var poll := _poll(h, s)
	if poll == "fail":
		crew._fail(h)
		return
	if poll == "now":
		h.work_left = minf(h.work_left, HelperWork.HEAT_REACT)
	h.work_left -= delta
	if s.do == "give" and crew.game.world.station_at(s.at) != null:   # the hand-over bar, as a chef's (PRD 11)
		h.show_giving(crew.game.world.station_at(s.at), 1.0 - h.work_left / maxf(float(s.get("total", 1.0)), 0.01))
	if h.work_left > 0.0 or poll == "wait":
		return
	var more: Variant = crew.task_end._finish(h, s)
	h.work_left = -1.0
	h.step_started = false
	if more == null:
		crew._fail(h)
		return
	h.steps.pop_front()
	for i in range((more as Array).size() - 1, -1, -1):
		h.steps.push_front(more[i])
	if h.steps.is_empty() and not h.task.is_empty():
		crew._complete(h)


## A step begins: work out where it happens and set off. False when it cannot.
func _start(h: Helper, s: Dictionary) -> bool:
	match str(s.do):
		"deliver":
			var st: Station = crew.task_end._dish_needing(int(s.ticket), str(Tray.parse(h.held).get("id", ""))) \
				if s.get("assemble", false) else null
			if st != null:
				s.at = st.cell
				s.mode = "add"
			else:
				# A cook who also plates puts it by where plates are built (the pass).
				var plating: bool = s.get("assemble", false)
				var c: Variant = crew.room_view._free_surface(crew.room_view._assembly_cell() if plating else h.cell(), h, plating)
				if c == null:
					return false
				s.at = c
				s.mode = "put"
		"leave":
			# Raw food for a cook goes on the press tool itself, where it is worked in
			# place; else (a heat tool, or it is in use) on a worktop beside it.
			var tool: Station = crew.game.world.station_at(s.at)
			if not (tool != null and crew.room_view._free_tool_top(tool, h)):
				var c: Variant = crew.room_view._free_surface(s.get("at", h.cell()), h)
				if c == null:
					return false
				s.at = c
		"stash":
			var c: Variant = crew.room_view._free_surface(s.get("at", h.cell()), h, false, h.held == "dishes")
			if c == null:
				return false
			s.at = c
		"set_out":
			if h.held != "dishes":
				return false
			var c: Variant = crew.room_view._free_surface(crew.room_view._assembly_cell(), h, true, true)
			if c == null:
				return false
			s.at = c
		"get_cup":
			var tk: Dictionary = crew.game.serving.find_ticket(int(s.ticket))
			if tk.is_empty() or h.held != "":
				return false
			var st: Station = crew.task_end._dish_needing(int(s.ticket), str(s.kind))
			var step: Dictionary
			if st != null and st.dish.vessel == Dish.CUP:
				step = {"do": "pick_dish", "at": st.cell}
			else:
				var stack: Station = crew.game.world.find_station("cups")
				var line := -1
				for li: int in crew.task_end._unplated(tk):
					if (tk.order.lines[li].item.ingredients as Array).has(s.kind) and tk.order.lines[li].item.course == "drink":
						line = li
						break
				if stack == null or stack.count <= 0 or line < 0:
					return false
				step = {"do": "take_plate", "at": stack.cell, "ticket": int(s.ticket), "line": line, "vessel": Dish.CUP}
			h.steps.pop_front()
			h.steps.push_front(step)
			h.step_started = false
			return _start_next(h)
		"to_sink":
			var sink := crew.room_view._nearest("sink", h.cell())
			if sink == null:
				return false
			s.at = sink.cell
		"bin":
			var b := crew.room_view._nearest("bin", h.cell())
			if b == null:
				return false
			s.at = b.cell
		"restack":
			if h.held != "dishes":
				return false
			var stack := crew.room_view._nearest("cups" if h.dishes[0].vessel == Dish.CUP else "plates", h.cell())
			if stack == null:
				return false
			s.at = stack.cell
		"to_door":
			s.at = crew.game.ENTRANCE_CELL
			return h.go_to(crew.game.ENTRANCE_CELL)
		"drop":
			return h.go_to(h.cell())
		"set_plates":
			var steps: Variant = crew.task_end._plate_steps(h, int(s.ticket))
			if steps == null or (steps as Array).is_empty():
				return false
			h.steps.pop_front()
			for i in range((steps as Array).size() - 1, -1, -1):
				h.steps.push_front(steps[i])
			h.step_started = false
			return _start_next(h)
		"assemble":
			var steps: Variant = crew.task_end._assemble_steps(h, int(s.ticket))
			if steps == null:
				return false
			h.steps.pop_front()
			for i in range((steps as Array).size() - 1, -1, -1):
				h.steps.push_front(steps[i])
			h.step_started = false
			return true if not h.steps.is_empty() and _start_next(h) else false
		"add":
			var st: Station = crew.task_end._dish_needing(int(s.ticket), str(Tray.parse(h.held).get("id", "")))
			if st == null:
				return false
			s.at = st.cell
		"write":
			var till: Station = crew.game.paying.till_station()
			if till == null:
				return false
			s.at = till.cell
		"give":
			var table: Station = crew.game.paying.table_by_number(int(s.table))
			if table == null or not crew.game.paying.ready_to_pay(table):
				return false
			s.at = crew.room_view._bill_place(table).cell
	if Crew.STASH.has(str(s.do)) or s.get("mode", "") == "put" or s.do == "leave" or s.do == "set_out":
		if s.has("at") and crew.game.world.station_at(s.at) != null and s.do != "to_sink" and s.do != "bin":
			crew._claims[s.at] = h
	var stand: Variant = _stand_for(h, s)
	if stand == null:
		return false
	return h.go_to(stand)


func _start_next(h: Helper) -> bool:
	h.step_started = true
	return _start(h, h.steps[0])


## Where to stand for a step: on the dirt itself where it can be stood on, beside a
## seated guest at a table, else beside the piece.
func _stand_for(h: Helper, s: Dictionary) -> Variant:
	var at: Vector2i = s.at
	if s.do == "wipe" and _open(at):
		return at
	if s.do == "to_door":
		return at
	var targets: Array[Vector2i] = [at]
	var st: Station = crew.game.world.station_at(at)
	if st != null and Station.is_table(st.type):
		targets.append_array(st.seats)
	var best: Variant = null
	var best_d := INF
	for t: Vector2i in targets:
		for d: Vector2i in Grid.DIRS:
			var c := t + d
			if not _open(c) or not crew.game.grid.edge_open(c, t):
				continue
			var dist := float(absi(c.x - h.cell().x) + absi(c.y - h.cell().y))
			if dist < best_d and (c == h.cell() or not crew.game.grid.find_path(h.cell(), c).is_empty()):
				best_d = dist
				best = c
	return best


func _open(c: Vector2i) -> bool:
	return crew.game.grid.in_bounds(c) and not crew.game.grid.is_blocked(c)


## The work at the spot begins: its seconds, or -1 when it cannot be done.
func _work(h: Helper, s: Dictionary) -> float:
	var e: Dictionary = crew.game.staff.employee(h.person)
	var sat := float(e.get("satisfaction", 0.5))
	var st: Station = crew.game.world.station_at(s.at) if s.has("at") else null
	match str(s.do):
		"take":
			if h.held != "" or crew.room_view._box_with(s.at, s.kind, s.get("ready", false)) == "":
				return -1.0
			return HelperWork.task_seconds("take", h.rating, sat)
		"pick":
			if st == null or h.held != "" or st.item != CrewRoomView._pick_form(s) or st.prep_by >= 0 or st.draining():
				return -1.0
			return HelperWork.task_seconds("pick", h.rating, sat)
		"cook":
			if st == null:
				return -1.0
			var raw := str(s.get("hold", Tray.kind("raw", s.kind)))
			if s.get("in_place", false):
				if st.item != raw or st.prep_by >= 0:
					return -1.0
			elif h.held != raw or st.item != "" or st.prep_by >= 0:
				return -1.0
			if not s.get("in_place", false):
				st.set_item(raw)
				h.set_held("")
			h.punch()
			st.used()
			if st.is_heat_tool():
				return 999.0   # until it is done (`_poll`)
			st.prep_by = Crew.HELPER_PREP
			crew._using[h] = st
			return HelperWork.press_seconds(st.q(s.job), h.rating, sat)
		"pour":
			if st == null or crew.game.cooking._cup_in_hand(h, s.kind) == null or st.prep_by >= 0 or not crew.game.menu_stock.dispenser_drinks(st).has(s.kind):
				return -1.0
			st.prep_by = Crew.HELPER_PREP
			crew._using[h] = st
			h.punch()
			return HelperWork.task_seconds("pour", h.rating, sat) / clampf(st.q("pour"), 0.5, 2.0)
		"deliver", "leave", "stash", "set_out", "add":
			if st == null or st.prep_by >= 0:
				return -1.0
			return HelperWork.task_seconds("put", h.rating, sat)
		"take_plate":
			if st == null or st.count <= 0 or not h.has_room():
				return -1.0
			return HelperWork.task_seconds("pick", h.rating, sat)
		"pick_dish":
			if st == null or st.item != "dish" or st.dish == null or not h.has_room():
				return -1.0
			return HelperWork.task_seconds("pick", h.rating, sat)
		"serve":
			if st == null or h.held != "dishes" or crew.game.serving._dish_guests(st, h.dishes).is_empty():
				return -1.0
			return HelperWork.task_seconds("serve", h.rating, sat)
		"order":
			if st == null or h.held != "" or crew.game.seating._guests_to_order(st).is_empty():
				return -1.0
			return HelperWork.task_seconds("order", h.rating, sat)
		"write":
			var table: Station = crew.game.paying.table_by_number(int(s.table))
			if st == null or h.held != "" or table == null or not crew.game.paying.ready_to_pay(table) or crew.game.paying.slip_out(int(s.table)):
				return -1.0
			h.punch()
			return HelperWork.task_seconds("write", h.rating, sat)
		"give":
			var table: Station = crew.game.paying.table_by_number(int(s.table))
			if st == null or h.held != "bill" or table == null or not crew.game.paying.ready_to_pay(table):
				return -1.0
			return HelperWork.task_seconds("give", h.rating, sat)
		"clear":
			if st == null or not h.has_room(true) or st.dirty <= 0:
				return -1.0
			return HelperWork.task_seconds("clear", h.rating, sat)
		"to_sink", "bin", "restack":
			return HelperWork.task_seconds("put", h.rating, sat) if st != null else -1.0
		"wash":
			if st == null or st.dirty <= 0:
				return -1.0
			return HelperWork.task_seconds("wash", h.rating, sat)
		"empty_bin":
			if st == null or st.count <= 0 or h.held != "":
				return -1.0
			return HelperWork.task_seconds("empty_bin", h.rating, sat)
		"to_door", "drop":
			return 0.1
		"wipe":
			if crew.game.floor_dirt.mess.level(s.at) <= 0:
				return -1.0
			s.tool = crew.task_end._room_clean_tool(e.duties, s.at, str(s.tool))
			if CleanTools.TOOLS.has(str(s.tool)) and h.held == "":
				CleanKit.hold(h, s.tool, 0)
			return HelperWork.task_seconds("wipe", h.rating, sat)
		"help":
			if not crew.game.floor_dirt.help_up(h):
				return -1.0
			return 0.1
	return -1.0


## While working: "" to carry on, "now" to finish shortly, "wait" to hold on, "fail".
func _poll(h: Helper, s: Dictionary) -> String:
	match str(s.do):
		"cook":
			var st: Station = crew.game.world.station_at(s.at)
			var raw := str(s.get("hold", Tray.kind("raw", s.kind)))
			if st == null:
				return "fail"
			if st.is_heat_tool():
				if st.item == Tray.kind("prep", s.kind):
					return "now"
				return "" if st.item == raw else "fail"
			return "" if st.item == raw and st.prep_by == Crew.HELPER_PREP else "fail"
		"help":
			return "wait" if crew.game.floor_dirt.helping(h) != null else ""
	return ""
