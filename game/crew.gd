class_name Crew
extends Node
## The hired helpers in the room (PRD 10, section 9; milestone 10.6). Everyone at work
## today walks in as the door opens and goes home as the day ends. Each fifth of a second
## the task board (`JobBoard`) is rebuilt from the room and free helpers take the task
## that suits them; each helper then walks the task's steps (`HelperWork.steps`) using the
## room's pieces much as a chef does, without the minigames: a result rolls from skill,
## the tool and satisfaction. Breaks, chat, slips and the day's wear on their mood are
## kept here too. Nothing here is steered: everything is set at the desks at night.

const REBUILD_EVERY := 0.2
const HELPER_PREP := 99        # `Station.prep_by` while a helper works a press tool or dispenser
const BIN_FULL := 3            # a bin with this many scraps is worth emptying (it overflows at 4)
const RETRY_AFTER := -1.0      # idle seconds set after a failed task, so they do not retry at once
const STASH: Array[String] = ["stash", "to_sink", "to_door", "bin", "drop"]

var game
var helpers: Array[Helper] = []
var board := JobBoard.new()
var _since := REBUILD_EVERY
var _using := {}     # Helper -> the Station they are working (a press tool, a dispenser)
var _claims := {}    # Vector2i -> Helper: a surface someone is on their way to put something on


func setup(game_) -> void:
	game = game_


# ---------------------------------------------------------------- the day

## The door opens: everyone at work today arrives, on the pavement by the door.
func start_day() -> void:
	clear()
	for person: int in game.staff.employees:
		if not game.staff.is_day_off(person, game.ledger.day):
			add_helper(person)


func add_helper(person: int, at: Vector2i = Vector2i(-999, -999)) -> Helper:
	var h := Helper.new()
	game.add_child(h)
	h.setup_helper(game, person, game.DOOR if at.x == -999 else at)
	h.rating = int(game.staff.employee(person).get("rating", 3))
	h.stand = h.cell()
	helpers.append(h)
	return h


## The day is over (or the run): everyone goes home and what they were working is let go.
func clear() -> void:
	for h in helpers:
		_let_go(h)
		if is_instance_valid(h):
			h.queue_free()
			if h.get_parent():
				h.get_parent().remove_child(h)
	helpers.clear()
	_using.clear()
	_claims.clear()
	board = JobBoard.new()
	_since = REBUILD_EVERY


func helper_of(person: int) -> Helper:
	for h in helpers:
		if h.person == person:
			return h
	return null


# ---------------------------------------------------------------- each step

func tick(delta: float) -> void:
	if helpers.is_empty():
		return
	_since += delta
	if _since >= REBUILD_EVERY:
		_since = 0.0
		board.rebuild(world())
		var free := []
		for h in helpers:
			if h.steps.is_empty() and not h.resting and not game.floor_dirt.is_down(h):
				free.append({"id": h.person, "cell": h.cell(), "idle": h.idle})
		var got := board.assign(game.staff, free, game.ledger.day, game.clock, game.day_length())
		for h in helpers:
			if got.has(h.person):
				_begin(h, got[h.person])
	for h in helpers:
		_tick_helper(h, delta)
	_chat(delta)


func _tick_helper(h: Helper, delta: float) -> void:
	var at_work := JobBoard.at_work(game.staff, h.person, game.ledger.day, game.clock, game.day_length())
	if not at_work and not h.resting and _on_the_heat(h):
		pass   # what is on the heat is seen to before the break (PRD 10.7): it would burn
	elif not at_work and not h.resting:
		h.resting = true
		if not h.task.is_empty() or _working(h):
			_drop(h)
	elif at_work and h.resting:
		h.resting = false
	if game.floor_dirt.is_down(h):
		h.walk(delta)   # on the floor: nothing until they are up
		return
	if h.steps.is_empty():
		h.idle += delta
		_wait_by_desk(h)
	else:
		h.idle = 0.0
		_run(h, delta)
	h.walk(delta)
	_wear(h, delta)


## Whether they are cooking something on a heat tool right now.
func _on_the_heat(h: Helper) -> bool:
	if h.steps.is_empty() or str(h.steps[0].do) != "cook" or not h.step_started or h.work_left < 0.0:
		return false
	var st: Station = game.station_at(h.steps[0].get("at", Vector2i(-999, -999)))
	return st != null and st.is_heat_tool()


## Whether they are in the middle of steps of their own (stashing counts).
func _working(h: Helper) -> bool:
	return not h.steps.is_empty()


func _begin(h: Helper, task: Dictionary) -> void:
	var e: Dictionary = game.staff.employee(h.person)
	var dest_duty := ""
	if task.type == "fetch" and not str(task.get("job", "")) in ["", "none"]:
		var st: Station = game.station_at(task.dest)
		dest_duty = Staff.duty_of_tool(st.node) if st != null else ""
	h.task = task
	h.steps = HelperWork.steps(task, e.duties, dest_duty)
	h.step_started = false
	h.work_left = -1.0
	h.chatting = false
	if h.steps.is_empty():
		board.release(h.person)
		h.task = {}


## The task is done: it leaves the board and the work trains them in its kind.
func _complete(h: Helper) -> void:
	var kind := str(HelperWork.TASK_KIND.get(str(h.task.get("type", "")), ""))
	board.done(h.person)
	if kind != "":
		var tol: float = game.staff.train(h.person, kind)
		game.town.people[h.person].tolerance[kind] = clampi(roundi(tol), Town.TOL_MIN, Town.TOL_MAX)
	h.task = {}


## The task cannot go on (a chef took it, the guest left, nothing free): let it go and put
## down what is in hand.
func _fail(h: Helper) -> void:
	var was: Dictionary = h.steps[0] if not h.steps.is_empty() else {}
	_let_go(h)
	board.release(h.person)
	h.task = {}
	h.steps.clear()
	h.step_started = false
	h.work_left = -1.0
	h.idle = RETRY_AFTER
	if STASH.has(str(was.get("do", ""))):
		h.set_held("")   # nowhere to put it: it goes
		return
	var how := HelperWork.stash_for(h.held)
	if how != "":
		h.steps = [{"do": how}]


## Drops the task for a break: what is in hand is put away first.
func _drop(h: Helper) -> void:
	if h.steps.is_empty() or not STASH.has(str(h.steps[0].get("do", ""))):
		_fail(h)
		h.idle = 0.0


## Frees the tool they were working and any surface they had in mind.
func _let_go(h: Helper) -> void:
	var st: Station = _using.get(h)
	if st != null and is_instance_valid(st):
		if st.prep_by == HELPER_PREP:
			st.prep_by = -1
			st.hide_widget()
			if Tray.parse(st.item).get("state", "") == "raw" and h.held == "":
				h.set_held(st.item)   # what was being worked comes back into their hands
				st.set_item("")
	_using.erase(h)
	for c in _claims.keys():
		if _claims[c] == h:
			_claims.erase(c)


# ---------------------------------------------------------------- walking the steps

func _run(h: Helper, delta: float) -> void:
	var s: Dictionary = h.steps[0]
	if not h.step_started:
		h.step_started = true
		if not _start(h, s):
			_fail(h)
			return
		s = h.steps[0]   # an assemble step has become its parts
	if h.work_left < 0.0:
		if not h.arrived():
			if h.path.is_empty() and h.cell() != h.stand and not h.go_to(h.stand):
				_fail(h)
			return
		if s.has("at"):
			h.face(s.at)
		var t := _work(h, s)
		if t < 0.0:
			_fail(h)
			return
		h.work_left = t
	var poll := _poll(h, s)
	if poll == "fail":
		_fail(h)
		return
	if poll == "now":
		h.work_left = minf(h.work_left, HelperWork.HEAT_REACT)
	h.work_left -= delta
	if h.work_left > 0.0 or poll == "wait":
		return
	var more: Variant = _finish(h, s)
	h.work_left = -1.0
	h.step_started = false
	if more == null:
		_fail(h)
		return
	h.steps.pop_front()
	for i in range((more as Array).size() - 1, -1, -1):
		h.steps.push_front(more[i])
	if h.steps.is_empty() and not h.task.is_empty():
		_complete(h)


## A step begins: work out where it happens and set off. False when it cannot.
func _start(h: Helper, s: Dictionary) -> bool:
	match str(s.do):
		"deliver":
			var tray: Tray = game.tray_for_ticket(int(s.ticket)) if s.get("assemble", false) else null
			var st: Station = game._station_with_tray(tray) if tray != null else null
			if st != null and tray.refusal(h.held) == "":
				s.at = st.cell
				s.mode = "add"
			else:
				# A cook who also plates puts it by where trays are built (the pass).
				var plating: bool = s.get("assemble", false)
				var c: Variant = _free_surface(_assembly_cell() if plating else h.cell(), h, plating)
				if c == null:
					return false
				s.at = c
				s.mode = "put"
		"leave":
			# Raw food for a cook goes on the press tool itself, where it is worked in
			# place; else (a heat tool, or it is in use) on a worktop beside it.
			var tool: Station = game.station_at(s.at)
			if not (tool != null and _free_tool_top(tool, h)):
				var c: Variant = _free_surface(s.get("at", h.cell()), h)
				if c == null:
					return false
				s.at = c
		"stash", "put_tray":
			var c: Variant = _free_surface(s.get("at", h.cell()), h, false, s.do == "put_tray" or h.held == "tray")
			if c == null:
				return false
			s.at = c
		"to_sink":
			var sink := _nearest("sink", h.cell())
			if sink == null:
				return false
			s.at = sink.cell
		"bin":
			var b := _nearest("bin", h.cell())
			if b == null:
				return false
			s.at = b.cell
		"to_door":
			s.at = game.ENTRANCE_CELL
			return h.go_to(game.ENTRANCE_CELL)
		"drop":
			return h.go_to(h.cell())
		"start_tray":
			var tk: Dictionary = game.find_ticket(int(s.ticket))
			var stack: Station = game.find_station("trays")
			if tk.is_empty() or h.held != "" or stack == null or stack.count <= 0 or game.tray_for_ticket(int(s.ticket)) != null:
				return false
			var spot: Variant = _free_surface(stack.cell, h, true, true)
			if spot == null:
				return false
			h.steps.pop_front()
			h.steps.push_front({"do": "put_tray", "at": spot})
			h.steps.push_front({"do": "take_tray", "at": stack.cell, "ticket": int(s.ticket)})
			h.step_started = false
			return _start_next(h)
		"assemble":
			var steps: Variant = _assemble_steps(h, int(s.ticket))
			if steps == null:
				return false
			h.steps.pop_front()
			for i in range((steps as Array).size() - 1, -1, -1):
				h.steps.push_front(steps[i])
			h.step_started = false
			return true if not h.steps.is_empty() and _start_next(h) else false
		"add":
			var tray: Tray = game.tray_for_ticket(int(s.ticket))
			var st: Station = game._station_with_tray(tray) if tray != null else null
			if st == null:
				return false
			s.at = st.cell
	if STASH.has(str(s.do)) or s.get("mode", "") == "put" or s.do == "leave" or s.do == "put_tray":
		if s.has("at") and game.station_at(s.at) != null and s.do != "to_sink" and s.do != "bin":
			_claims[s.at] = h
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
	var st: Station = game.station_at(at)
	if st != null and Station.is_table(st.type):
		targets.append_array(st.seats)
	var best: Variant = null
	var best_d := INF
	for t: Vector2i in targets:
		for d: Vector2i in Grid.DIRS:
			var c := t + d
			if not _open(c) or not game.grid.edge_open(c, t):
				continue
			var dist := float(absi(c.x - h.cell().x) + absi(c.y - h.cell().y))
			if dist < best_d and (c == h.cell() or not game.grid.find_path(h.cell(), c).is_empty()):
				best_d = dist
				best = c
	return best


func _open(c: Vector2i) -> bool:
	return game.grid.in_bounds(c) and not game.grid.is_blocked(c)


## The work at the spot begins: its seconds, or -1 when it cannot be done.
func _work(h: Helper, s: Dictionary) -> float:
	var e: Dictionary = game.staff.employee(h.person)
	var sat := float(e.get("satisfaction", 0.5))
	var st: Station = game.station_at(s.at) if s.has("at") else null
	match str(s.do):
		"take":
			if h.held != "" or _box_with(s.at, s.kind, s.get("ready", false)) == "":
				return -1.0
			return HelperWork.task_seconds("take", h.rating, sat)
		"pick":
			if st == null or h.held != "" or st.item != _pick_form(s) or st.prep_by >= 0 or st.draining():
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
			st.prep_by = HELPER_PREP
			_using[h] = st
			return HelperWork.press_seconds(st.q(s.job), h.rating, sat)
		"pour":
			if st == null or h.held != "" or st.prep_by >= 0 or not game.dispenser_drinks(st).has(s.kind):
				return -1.0
			st.prep_by = HELPER_PREP
			_using[h] = st
			h.punch()
			return HelperWork.task_seconds("pour", h.rating, sat) / clampf(st.q("pour"), 0.5, 2.0)
		"deliver", "leave", "stash", "put_tray", "add":
			if st == null or st.prep_by >= 0:
				return -1.0
			return HelperWork.task_seconds("put", h.rating, sat)
		"take_tray":
			if st == null or st.count <= 0 or h.held != "":
				return -1.0
			return HelperWork.task_seconds("pick", h.rating, sat)
		"pick_tray":
			if st == null or h.held != "" or st.item != "tray" or st.tray == null or st.tray.ticket != int(s.ticket) or not st.tray.is_complete():
				return -1.0
			return HelperWork.task_seconds("pick", h.rating, sat)
		"serve":
			if st == null or h.held != "tray" or game._guest_for_tray(st, h.tray) == null:
				return -1.0
			return HelperWork.task_seconds("serve", h.rating, sat)
		"order":
			if st == null or h.held != "" or game._guests_to_order(st).is_empty():
				return -1.0
			return HelperWork.task_seconds("order", h.rating, sat)
		"clear":
			if st == null or h.held != "" or st.dirty <= 0:
				return -1.0
			return HelperWork.task_seconds("clear", h.rating, sat)
		"to_sink", "bin":
			return HelperWork.task_seconds("put", h.rating, sat) if st != null else -1.0
		"wash":
			if st == null or st.dirty <= 0 or game.find_station("trays") == null:
				return -1.0
			return HelperWork.task_seconds("wash", h.rating, sat)
		"empty_bin":
			if st == null or st.count <= 0 or h.held != "":
				return -1.0
			return HelperWork.task_seconds("empty_bin", h.rating, sat)
		"to_door", "drop":
			return 0.1
		"wipe":
			if game.floor_dirt.mess.level(s.at) <= 0:
				return -1.0
			s.tool = _room_clean_tool(e.duties, s.at, str(s.tool))
			if CleanTools.TOOLS.has(str(s.tool)) and h.held == "":
				CleanKit.hold(h, s.tool, 0)
			return HelperWork.task_seconds("wipe", h.rating, sat)
		"help":
			if not game.floor_dirt.help_up(h):
				return -1.0
			return 0.1
	return -1.0


## While working: "" to carry on, "now" to finish shortly, "wait" to hold on, "fail".
func _poll(h: Helper, s: Dictionary) -> String:
	match str(s.do):
		"cook":
			var st: Station = game.station_at(s.at)
			var raw := str(s.get("hold", Tray.kind("raw", s.kind)))
			if st == null:
				return "fail"
			if st.is_heat_tool():
				if st.item == Tray.kind("prep", s.kind):
					return "now"
				return "" if st.item == raw else "fail"
			return "" if st.item == raw and st.prep_by == HELPER_PREP else "fail"
		"help":
			return "wait" if game.floor_dirt.helping(h) != null else ""
	return ""


## The work is done. Returns the steps to do next in its place ([] for none), or null
## when it went wrong in a way that ends the task.
func _finish(h: Helper, s: Dictionary) -> Variant:
	var st: Station = game.station_at(s.at) if s.has("at") else null
	match str(s.do):
		"take":
			var box := _box_with(s.at, s.kind, s.get("ready", false))
			if box == "":
				return null
			game._hold_from_box(h, box)
			game.sfx("pickup")
		"pick":
			h.set_held(st.item, st.current_quality())
			st.set_item("")
			game.sfx("pickup")
		"cook":
			var job := str(s.job)
			var q := st.q(job)
			var roll := JobBoard.roll_prep(game.staff, h.person, q if q > 0.0 else 1.0)
			_using.erase(h)
			st.prep_by = -1
			st.set_item("")
			h.set_held(Tray.kind("prep", s.kind), float(roll.quality))
			PrepWidget.pop(st, Vector3(0, 2.0, 0), str(roll.result))
			game.floor_dirt.prep_grease(job, str(roll.result), h.cell(), st)
			game.sfx("pickup")
		"pour":
			var roll := JobBoard.roll_prep(game.staff, h.person, st.q("pour"))
			_using.erase(h)
			st.prep_by = -1
			h.set_held(Tray.kind("prep", s.kind), float(roll.quality))
			PrepWidget.pop(st, Vector3(0, 2.0, 0), str(roll.result))
			game.sfx("pickup")
		"deliver", "add":
			_claims.erase(s.at)
			if st.item == "tray" and st.tray != null and st.tray.refusal(h.held) == "":
				game._use_surface(st, false, h)   # "Add ..."
				game.sfx("putdown")
			elif st.item == "" and s.do == "deliver":
				st.set_item(h.held, h.held_quality)
				h.set_held("")
				game.sfx("putdown")
			else:
				return null
		"leave", "stash":
			_claims.erase(s.at)
			if st.item != "":
				return null
			if h.held == "tray":
				game._use_surface(st, false, h)   # "Put tray down"
			else:
				st.set_item(h.held, h.held_quality)
				h.set_held("")
			game.sfx("putdown")
		"take_tray":
			st.count -= 1
			st.refresh()
			var t := Tray.new()
			var tk: Dictionary = game.find_ticket(int(s.ticket))
			if not tk.is_empty() and game.tray_for_ticket(int(s.ticket)) == null:
				t.assign(int(tk.id), tk.items)
			h.set_held("tray", 1.0, t, game.tray_tag(t))
			game.sfx("pickup")
		"put_tray":
			_claims.erase(s.at)
			if st.item != "":
				return null
			game._use_surface(st, false, h)
			game.sfx("putdown")
		"pick_tray":
			var t := st.tray
			h.set_held("tray", 1.0, t, game.tray_tag(t))
			st.set_item("")
			game.hud.refresh_tickets()
			game.sfx("pickup")
		"serve":
			var fed: Guest = game._guest_for_tray(st, h.tray)
			if fed == null:
				return [{"do": "stash"}]
			if not JobBoard.roll_task(game.staff, h.person).ok:
				# A dropped tray: the food on the floor, the tray back to be filled again.
				game.floor_dirt.mess.add_dirt(h.cell())
				h.tray.scrape()
				game._show_tray(h.tray)
				game.hud.refresh_tickets()
				game.sfx("fail")
				game.popup("Dropped it!", h.position + Vector3(0, 2.2, 0), Color(Build.WARN))
				return [{"do": "stash"}]
			var t := h.tray
			h.set_held("")
			game.serve(fed, t)
			var skill := float(game.staff.employee(h.person).skills.service)
			fed.mood.delight(HelperWork.serve_joy(skill))
		"order":
			game.take_orders(st)
			h.punch()
		"clear":
			st.dirty -= 1
			st.refresh()
			h.set_held("dirty_tray")
			game.sfx("pickup")
		"to_sink":
			st.dirty += 1
			st.refresh()
			h.set_held("")
			game.sfx("putdown")
		"bin":
			st.count += 1
			st.refresh()
			h.set_held("")
		"wash":
			if JobBoard.roll_task(game.staff, h.person).ok:
				st.dirty -= 1
				st.refresh()
				var stack: Station = game.find_station("trays")
				stack.count += 1
				stack.refresh()
				game.sfx("wash")
				game.burst(st.position + Vector3(0, 1.15, 0), "bubbles", 0.4)
			st.used()
			if st.dirty > 0:
				return [s.duplicate()]
		"empty_bin":
			st.count = 0
			st.refresh()
			h.set_held("rubbish_bag")
			game.sfx("pickup")
		"to_door":
			h.set_held("")
			game.sfx("putdown")
		"drop":
			h.set_held("")
		"wipe":
			var mess: FloorMess = game.floor_dirt.mess
			if JobBoard.roll_task(game.staff, h.person).ok:
				mess.clean(s.at, HelperWork.wipe_levels(float(game.staff.employee(h.person).skills.clean),
					str(s.tool), mess.one_press(s.at)))
			game.sfx("step", 0.2)
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
	var mess: FloorMess = game.floor_dirt.mess
	var best := ""
	for st: Station in game.stations.values() + game.highs.values():
		var t: String = st.kit_tool
		if t == "" or not duties.has(Staff.clean_duty(t)) or CleanTools.refusal(mess, cell, t, 0) != "":
			continue
		if best == "" or int(CleanTools.TOOLS[t].levels) > int(CleanTools.TOOLS[best].levels):
			best = t
	return best if best != "" else fallback


## A ticket's tray built from what is made: a tray from the stack put down first if it
## has none, then each made thing it still needs picked up and added. null for nothing to do.
func _assemble_steps(h: Helper, ticket: int) -> Variant:
	var tk: Dictionary = game.find_ticket(ticket)
	if tk.is_empty() or h.held != "":
		return null
	var tray: Tray = game.tray_for_ticket(ticket)
	var out := []
	var needs: Array = []
	var near := h.cell()
	if tray == null:
		var stack: Station = game.find_station("trays")
		if stack == null or stack.count <= 0:
			return null
		var spot: Variant = _free_surface(stack.cell, h, true, true)
		if spot == null:
			return null
		out.append({"do": "take_tray", "at": stack.cell, "ticket": ticket})
		out.append({"do": "put_tray", "at": spot})
		near = spot
		for it: Dictionary in tk.items:
			needs.append_array(it.ingredients)
	else:
		var st: Station = game._station_with_tray(tray)
		if st == null:
			return null
		near = st.cell
		needs = _tray_needs(tray)
	var taken := {}
	for kind: String in needs:
		var src: Variant = _made_at(kind, near, taken)
		if src == null:
			continue
		taken[src] = true
		out.append({"do": "pick", "at": src, "kind": kind, "state": "prep"})
		out.append({"do": "add", "ticket": ticket})
	var picks := out.filter(func(x: Dictionary) -> bool: return x.do == "pick")
	return out if not picks.is_empty() else null


# ---------------------------------------------------------------- idle

## With nothing to do, they wait by a desk.
func _wait_by_desk(h: Helper) -> void:
	if not h.path.is_empty():
		return
	var desks: Array = []
	for st: Station in game.stations.values():
		if st.type == "desk":
			desks.append(st.cell)
	var open := {}
	for d: Vector2i in desks:
		for side: Vector2i in Grid.DIRS:
			if _open(d + side):
				open[d + side] = true
	if open.has(h.stand) and h.stand != Vector2i(-999, -999):
		var mine := true
		for o in helpers:
			if o != h and o.stand == h.stand:
				mine = mine and helpers.find(o) > helpers.find(h)
		if mine:
			return
	var taken := {}
	for o in helpers:
		if o != h:
			taken[o.stand] = true
	var c: Variant = HelperWork.wait_cell(desks, open, taken, h.cell())
	if c != null and c != h.stand:
		h.go_to(c)


## Free helpers near each other chat: speech bubbles, and their satisfaction moves together.
func _chat(delta: float) -> void:
	var free := []
	for h in helpers:
		h.chatting = false
		if h.steps.is_empty() and (h.resting or h.idle >= HelperWork.IDLE_CHAT_AFTER) and h.arrived() \
				and not game.floor_dirt.is_down(h):
			free.append({"id": h.person, "cell": h.cell()})
	for pair: Array in HelperWork.chat_pairs(free):
		game.staff.chat(pair[0], pair[1], delta)
		var a := helper_of(pair[0])
		var b := helper_of(pair[1])
		a.chatting = true
		b.chatting = true
		a.look_at_cell(b.cell())
		b.look_at_cell(a.cell())
	for h in helpers:
		h.show_bubble("chat" if h.chatting else ("mug" if h.resting and h.steps.is_empty() else ""))


## Their own tolerances at work: a helper who minds dirt is worn down by a filthy floor.
func _wear(h: Helper, delta: float) -> void:
	var mess: FloorMess = game.floor_dirt.mess
	var lvl := mess.level(h.cell())
	for d: Vector2i in Grid.DIRS:
		lvl = maxi(lvl, mess.level(h.cell() + d))
	var drain := HelperWork.work_drain(game.staff.tolerance(h.person, "clean"), lvl, delta)
	if drain > 0.0:
		game.staff.nudge(h.person, -drain)


# ---------------------------------------------------------------- demos

## REGULARS_DEMO=helpers: a grill cook, a server and a washer at work in a busy room, two
## desks along the front (shoot at about 12). helpers_break: the server and the washer on
## their break, chatting by the desks, while the cook works on (shoot at about 4).
## helpers_slip (PRD 10.8): the washer down on a level 4 cell, dazed, and the server, who
## has the help-up duty, crossing to lift them (shoot at about 3 and 5).
func demo(which: String) -> void:
	for c: Vector2i in [Vector2i(8, 6), Vector2i(9, 6)]:
		if not game.stations.has(c):
			game.add_station("desk", c)
	var on_break := which == "helpers_break"
	var slip := which == "helpers_slip"
	var hires := [[2, "Grill cook", ["fetch", "grill", "assemble"], 0, 0.85, Vector2i(1, 4)],
		[5, "Server", ["take_orders", "carry_trays", "clear_tables"] + (["help_up"] as Array if slip else []), 1 if on_break else 0, 0.7, Vector2i(7, 5) if on_break else Vector2i(5, 3)],
		[9, "Washer", ["wash_up", "empty_bin", "clear_tables", "mop"], 1 if on_break else 0, 0.35, Vector2i(8, 5) if on_break else Vector2i(3, 3)]]
	for row: Array in hires:
		var pid: int = game.staff.add_post(row[1], row[2], row[3], 0, 99)
		var cv: Dictionary = game.staff._make_cv(row[0], Staff.skills_from(game.town.people[row[0]].tolerance),
			game.town.rating(row[0]), 1.0, pid)
		game.staff.cvs.append(cv)
		game.staff.hire(cv.id, -1, game.ledger.day)
		game.staff.employee(row[0]).satisfaction = row[4]
		var helper := add_helper(row[0], row[5])
		if slip and row[0] == 9:   # once the day is under way, as the guest slip demo does
			game.get_tree().create_timer(1.0).timeout.connect(_demo_slip.bind(helper, Vector2i(6, 3)))
	game.find_station("sink").dirty = 2
	if not slip:   # in the slip demo the server is free to help
		game.stations[Vector2i(8, 3)].dirty = 1
		game.stations[Vector2i(8, 3)].refresh()
	game.find_station("sink").refresh()
	if on_break:
		game.clock = Staff.break_starts(1, game.day_length())[0] + 0.2
		game.floor_dirt.mess.dirt[Vector2i(6, 3)] = 2
	var t: float = game.clock
	game.arrivals.assign([{"time": t + 0.5, "group": [0, 1]}, {"time": t + 2.0, "group": [4]}, {"time": t + 5.0, "group": [6, 7]}])


func _demo_slip(h: Helper, c: Vector2i) -> void:
	h.position = Grid.center(c)   # open floor between the tables, in plain view
	h.path.clear()
	for i in 4:
		game.floor_dirt.mess.add_dirt(c)
	game.floor_dirt.slip(h, c)


# ---------------------------------------------------------------- the all-staff run (PRD 10.7)

## A late-game kitchen with every tool, per theme: [cell, top ("" for none), base, boxes].
## The kitchen is grown back to the dining room's back wall, so (0..3, 0..1) is kitchen
## too and its back row opens round the top of the pass. The theme's fixed line (the
## grilled kind's fridge, a stove, the bread's box) is `Main.test_kitchen`'s; its second
## stove makes way for the slicer. Drinks (and the diner's freezer) are a bar by the door.
const STAFF_ROOM := {
	"diner": [
		[Vector2i(0, 1), "board", "long_counter", ["box_lettuce", "box_tomato", "ready_onion"]],
		[Vector2i(1, 0), "pot", "counter", []],
		[Vector2i(2, 0), "steamer", "counter", []],
		[Vector2i(3, 0), "fryer", "double_counter", ["box_potato", "box_corn"]],
		[Vector2i(0, 4), "slicer", "fridge", ["box_cheese"]],
		[Vector2i(2, 6), "grater", "fridge", ["box_shredded_cheese"]],
		[Vector2i(3, 6), "bread_knife", "double_counter", ["box_sourdough", "box_orange_juice"]],
		[Vector2i(4, 4), "juicer", "", []],
		[Vector2i(4, 5), "blender", "", []],
		[Vector2i(9, 1), "two_tap_fountain", "counter", []],
		[Vector2i(9, 2), "", "freezer", ["box_ice_cream"]],
	],
	"seaside": [
		[Vector2i(0, 1), "board", "double_counter", ["box_courgette", "ready_pepper"]],
		[Vector2i(1, 0), "pot", "double_counter", ["box_new_potato", "box_beans"]],
		[Vector2i(2, 0), "steamer", "fridge", ["box_mussels"]],
		[Vector2i(3, 0), "fryer", "fridge", ["box_calamari"]],
		[Vector2i(0, 4), "slicer", "counter", ["box_lemon"]],
		[Vector2i(2, 6), "grater", "double_counter", ["box_breadcrumbs"]],
		[Vector2i(3, 6), "bread_knife", "double_counter", ["box_crusty_loaf"]],
		[Vector2i(4, 4), "juicer", "", []],
		[Vector2i(4, 5), "blender", "", []],
		[Vector2i(9, 1), "wine_rack", "double_counter", ["box_fruit_smoothie"]],
	],
}
## Tonight's menu in the all-staff room: every kind of the theme in something.
const STAFF_MENU := {
	"diner": [["main", ["bun", "patty", "cheese", "lettuce", "onion"], "Burger"],
		["main", ["sourdough", "shredded_cheese", "tomato"], "Deli melt"],
		["side", ["potato"], "Fries"], ["side", ["steamed_corn"], "Steamed corn"],
		["side", ["corn"], "Corn cob"], ["side", ["ice_cream"], "Ice cream"],
		["drink", ["soda"], "Soda"], ["drink", ["cola"], "Cola"],
		["drink", ["orange_juice"], "Orange juice"], ["drink", ["milkshake"], "Milkshake"]],
	"seaside": [["main", ["roll", "fish", "lemon"], "Fish roll"],
		["main", ["crusty_loaf", "calamari", "pepper", "breadcrumbs"], "Calamari loaf"],
		["side", ["mussels"], "Mussels"], ["side", ["new_potato", "beans", "courgette"], "Garden plate"],
		["drink", ["wine"], "White wine"], ["drink", ["red_wine"], "Red wine"],
		["drink", ["lemonade"], "Lemonade"], ["drink", ["fruit_smoothie"], "Smoothie"]],
}
## The crew: [person, post, duties, breaks]. Between them every duty the room gives.
## Breaks fall evenly through the day and equal counts break together (PRD 10.2), so the
## cooks' two never meet the floor's one, and the drinks hand takes orders meanwhile.
const STAFF_CREW := [
	[2, "Line cook", ["fetch", "grill", "fryer", "pot", "assemble"], 2],
	[5, "Prep cook", ["fetch", "board", "slicer", "grater", "bread_knife", "steamer", "assemble"], 2],
	[7, "Drinks", ["fetch", "tap", "juicer", "blender", "assemble", "take_orders", "carry_trays"], 0],
	[9, "Server", ["take_orders", "carry_trays", "clear_tables", "help_up"], 1],
	[11, "Cleaner", ["wash_up", "empty_bin", "clear_tables", "mop", "sponge", "scraper", "spill_kit", "help_up"], 1],
]
const STAFF_TREAT := {"cleaner": Rect2i(5, 2, 3, 2), "primer": Rect2i(8, 5, 2, 2), "finish": Rect2i(5, 4, 1, 3)}


## The all-staff run (PRD 10.7): the room above, its menu, a crew hired at the desks, the
## floor treated, and the chef gone home: helpers run the whole day. The day is then
## started again so everything is in force (guests, the treatments, the crew).
func staff_only() -> void:
	var theme: String = Scenery.theme_id if STAFF_ROOM.has(Scenery.theme_id) else "diner"
	game.test_kitchen()
	game.clear_walls()
	game.plan.fill(Rect2i(0, 0, Scenery.KITCHEN_W, Scenery.KITCHEN_Z), "tile")
	game._sync_grid()
	game._rebuild_room()
	var stove: Station = game.stations.get(Vector2i(0, 4))
	if stove != null:
		game._unregister(stove)
		stove.queue_free()
	for row: Array in STAFF_ROOM[theme]:
		var c: Vector2i = row[0]
		if not game.stations.has(c):
			game.add_station("counter", c, 1, 0, row[2])
		if row[1] != "":
			game.add_station(row[1], c)
		for b: String in row[3]:
			game._store_box(c, b)
	for spot: Array in [["hood", Vector2i(0, 3)], ["extractor", Vector2i(1, 0)], ["hood", Vector2i(2, 0)],
			["hood", Vector2i(3, 0)], ["cabinet", Vector2i(0, 5)]]:
		if game.kitchen.can_hang(spot[1], spot[0]):
			game.add_high(spot[0], spot[1])
	# Chemicals apart from food: the cleaner over the bin, primer and finish by the door.
	game._store_box(Vector2i(0, 5), "box_cleaner")
	game.add_station("counter", Vector2i(9, 6), 1, 0, "double_counter")
	game._store_box(Vector2i(9, 6), "box_primer")
	game._store_box(Vector2i(9, 6), "box_finish")
	for k: String in STAFF_TREAT:
		var r: Rect2i = STAFF_TREAT[k]
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				if game.plan.has_floor(Vector2i(x, y)):
					game.treat_laid[Vector2i(x, y)] = k
	# The cleaning trees: a flat mop's bucket; a scourer, a grease scraper and a spill kit on hooks.
	var bucket: Station = game.add_station("flat_mop", Vector2i(8, 6))
	game.clean_kit.on_built(bucket, "flat_mop")
	var hooks := 0
	for c: Vector2i in game.kitchen.wall_cells:
		if hooks < 3 and not game.highs.has(c) and game.kitchen.can_hang(c, "hook"):
			game.clean_kit.keep(game.add_high("hook", c), ["scourer", "grease_scraper", "spill_kit"][hooks], 0)
			hooks += 1
	for c: Vector2i in [Vector2i(5, 6), Vector2i(7, 6)]:
		if not game.stations.has(c):
			game.add_station("desk", c)
	game.menu.items.clear()
	for it: Array in STAFF_MENU[theme]:
		game.menu.add(it[0], it[1], it[2])
	for row: Array in STAFF_CREW:
		var pid: int = game.staff.add_post(row[1], row[2], row[3], 0, 99)
		var person: int = row[0]
		var cv: Dictionary = game.staff._make_cv(person, Staff.skills_from(game.town.people[person].tolerance),
			game.town.rating(person), 1.0, pid)
		game.staff.cvs.append(cv)
		game.staff.hire(cv.id, -1, game.ledger.day)
	# Nobody cooks: the chef is not in today.
	for ch: Player in game.chefs:
		ch.visible = false
		ch.position = Grid.center(game.LOT.position)
	game.ledger.money = maxi(game.ledger.money, 2000)
	game.start_day()


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
	var trays := []
	var has_sink := false
	var stack: Station = game.find_station("trays")
	for st: Station in game.stations.values():
		var c: Vector2i = st.cell
		var jobs := Kitchen.jobs_of(st.node) if Kitchen.has_node(st.node) else {}
		var is_tool := false
		for j: String in jobs:
			is_tool = is_tool or (Staff.TOOL_DUTIES.has(j) and float(jobs[j]) > 0.0)
		if is_tool:
			var row := {"id": c, "cell": c, "tool": st.node, "busy": st.item != "" or st.prep_by >= 0}
			if jobs.has("pour"):
				var drinks: Array[String] = game.dispenser_drinks(st)
				if not drinks.is_empty():
					row.drinks = drinks
			tools.append(row)
		var kinds := []
		var ready := []
		for b: String in game.kitchen.stock(c):
			if Kitchen.is_cleaning(b):
				continue   # chemicals: nothing to cook (PRD 9.5)
			var si := Pantry.station_ingredient(b)
			(ready if si.ready else kinds).append(si.id)
		if not kinds.is_empty() or not ready.is_empty():
			storage.append({"cell": c, "kinds": kinds, "ready": ready})
		var p := Tray.parse(st.item)
		if not p.is_empty():
			# On a tool, what it is being made into: a lemon on a juicer is lemonade, a scoop
			# of ice cream in a blender a milkshake (PRD 8.6).
			var into: String = p.id
			if is_tool and p.state in ["raw", "prep"]:
				var pj: Array = game.press_job(st, p)
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
			var waiting: Array = game._guests_to_order(st)
			if not waiting.is_empty():
				tables.append({"id": tid, "cell": c, "state": "order", "wait": _wait_of(waiting[0])})
			if st.dirty > 0:
				tables.append({"id": tid, "cell": c, "state": "clear", "wait": st.dirty_age})
		match st.type:
			"sink":
				has_sink = true
				if stack != null:
					sinks.append({"cell": c, "dishes": st.dirty})
			"bin":
				bins.append({"cell": c, "full": st.count >= BIN_FULL})
		if st.item == "tray" and st.tray != null and st.tray.ticket >= 0 and st.tray.is_complete():
			var tk: Dictionary = game.find_ticket(st.tray.ticket)
			if not tk.is_empty() and tk.guest.state == "waiting" and tk.guest.table != null:
				trays.append({"id": int(tk.id), "cell": c, "table": tk.guest.table.cell, "wait": _wait_of(tk.guest)})
	if not has_sink:
		tables = tables.filter(func(t: Dictionary) -> bool: return t.state != "clear")
	for hand: Player in game.hands():
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
	for tk: Dictionary in game.tickets:
		var tray: Tray = game.tray_for_ticket(int(tk.id))
		var needs: Array = []
		if tray != null:
			needs = _tray_needs(tray)
		else:
			for it: Dictionary in tk.items:
				needs.append_array(it.ingredients)
		rows.append({"id": int(tk.id), "needs": needs})
	var lacks := HelperWork.ticket_lacks(rows, made)
	var burnt := []
	for st: Station in game.stations.values():
		var p := Tray.parse(st.item)
		if not p.is_empty() and p.state == "burnt" and Kitchen.has_node(st.node):
			burnt.append({"cell": st.cell, "kind": p.id, "duty": Staff.duty_of_tool(st.node)})
	var tickets := []
	for tk: Dictionary in game.tickets:
		var tray: Tray = game.tray_for_ticket(int(tk.id))
		var on: Station = game._station_with_tray(tray) if tray != null else null
		var cell: Vector2i = on.cell if on != null else _assembly_cell()
		# What a helper is carrying over to it is on its way: nobody else assembles it meanwhile.
		var coming := false
		for h in helpers:
			coming = coming or (Tray.parse(h.held).get("state", "") == "prep" and int(h.task.get("ticket", -1)) == int(tk.id))
		tickets.append({"id": int(tk.id), "cell": cell, "lacks": lacks[int(tk.id)], "wait": _wait_of(tk.guest),
			"assembled": (tray != null and (tray.is_complete() or on == null)) or coming, "tray": tray != null})
	var fallen := []
	var down: Dictionary = game.floor_dirt.down
	for who in down:
		if is_instance_valid(who) and not (down[who].helper is Player):
			fallen.append({"id": who.get_instance_id(), "cell": down[who].cell, "wait": float(down[who].t)})
	var dirt := {}
	var grease := {}
	var mess: FloorMess = game.floor_dirt.mess
	for c: Vector2i in mess.dirt:
		if mess.can_clean(c) and game.grid.in_bounds(c):
			dirt[c] = mess.dirt[c]
			if mess.is_grease(c):
				grease[c] = true
	return {"stations": tools, "storage": storage, "items": items, "tickets": tickets, "trays": trays,
		"tables": tables, "dirt": dirt, "grease": grease, "fallen": fallen, "sinks": sinks, "bins": bins,
		"burnt": burnt, "tray_room": _free_surfaces()}


static func _wait_of(g: Guest) -> float:
	return (1.0 - g.mood.patience) * 30.0 if g != null else 0.0


static func _tray_needs(tray: Tray) -> Array:
	var out: Array = []
	for l: Dictionary in tray.lines:
		for k in l.item.ingredients.size():
			if float(l.have[k]) < 0.0:
				out.append(l.item.ingredients[k])
	return out


## Where a tray for a ticket would be built: the pass nearest the tray stack, else the stack.
func _assembly_cell() -> Vector2i:
	var stack: Station = game.find_station("trays")
	var from: Vector2i = stack.cell if stack != null else Vector2i.ZERO
	var best := from
	var best_d := INF
	for st: Station in game.stations.values():
		if st.type == "pass" or st.pass_look:
			var d := float(absi(st.cell.x - from.x) + absi(st.cell.y - from.y))
			if d < best_d:
				best_d = d
				best = st.cell
	return best


## The box of `kind` stored at `cell` (a ready-made one with `ready`), or "". A treatment's
## box is chemicals, never food (PRD 9.5).
func _box_with(cell: Vector2i, kind: String, ready := false) -> String:
	for b: String in game.kitchen.stock(cell):
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
	return not (_claims.has(st.cell) and _claims[st.cell] != h)


## The nearest free worktop (a counter or the pass) to `near`: nothing on it, nobody
## else heading there. With `pass_first`, the pass wins where it is free. Food (not
## `for_tray`) never takes the last free worktop while a ticket waits for its tray to be
## started (PRD 10.7): one ticket's food lying about could otherwise fill every worktop
## and leave nowhere to build its tray.
func _free_surface(near: Vector2i, h: Helper, pass_first := false, for_tray := false) -> Variant:
	var best: Variant = null
	var best_d := INF
	for st: Station in game.stations.values():
		if not st.type in ["counter", "pass"] or st.item != "" or st.prep_by >= 0:
			continue
		if Kitchen.has_node(st.base) and Kitchen.fit_of(st.base) == "tall":
			continue   # a tall fridge or freezer has no worktop
		if game.kitchen.holds_cleaning(st.cell):
			continue   # no food set down on chemicals (PRD 9.5)
		if _claims.has(st.cell) and _claims[st.cell] != h:
			continue
		var d := float(absi(st.cell.x - near.x) + absi(st.cell.y - near.y))
		if pass_first and (st.type == "pass" or st.pass_look):
			d -= 100.0
		if d < best_d:
			best_d = d
			best = st.cell
	if best != null and not for_tray and _free_surfaces() <= 1 and _tray_wanted():
		return null
	return best


## Whether a ticket has no tray yet and the stack has one to start it with.
func _tray_wanted() -> bool:
	var stack: Station = game.find_station("trays")
	if stack == null or stack.count <= 0:
		return false
	for tk: Dictionary in game.tickets:
		if game.tray_for_ticket(int(tk.id)) == null:
			return true
	return false


## How many worktops are free for a tray, nobody on their way to them.
func _free_surfaces() -> int:
	var n := 0
	for st: Station in game.stations.values():
		if st.type in ["counter", "pass"] and st.item == "" and st.prep_by < 0 and not _claims.has(st.cell) \
				and not (Kitchen.has_node(st.base) and Kitchen.fit_of(st.base) == "tall") \
				and not game.kitchen.holds_cleaning(st.cell):
			n += 1
	return n


## The nearest piece holding the prepped `kind` loose (not on a tray), not in `taken`.
func _made_at(kind: String, near: Vector2i, taken: Dictionary) -> Variant:
	var want := Tray.kind("prep", kind)
	var best: Variant = null
	var best_d := INF
	for st: Station in game.stations.values():
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
	for st: Station in game.stations.values():
		if st.type != type:
			continue
		var d := float(absi(st.cell.x - near.x) + absi(st.cell.y - near.y))
		if d < best_d:
			best_d = d
			best = st
	return best
