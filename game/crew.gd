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
const COLLECT := 1.0           # seconds at the desk collecting their things before they leave
const STASH: Array[String] = ["stash", "to_sink", "to_outside_bin", "bin", "drop"]

var game
var helpers: Array[Helper] = []
var board := JobBoard.new()
var _since := REBUILD_EVERY
var _using := {}     # Helper -> the Station they are working (a press tool, a dispenser)
var _claims := {}    # Vector2i -> Helper: a surface someone is on their way to put something on
var task_run := CrewTaskRun.new(self)   # walking a task's steps: start, open, work, poll
var task_end := CrewTaskEnd.new(self)   # finishing a step, and the plating and assembly steps
var crew_demos := CrewDemos.new(self)   # the staff demos and the all-staff run
var room_view := CrewRoomView.new(self)   # what the room offers a helper: the board's world, free surfaces, stock


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


## The day is over: nobody takes a new task and breaks end. Cleaning in hand is finished;
## anything else (food, orders, bills, carrying) is let go. Then each goes by the desk and home.
func end_day() -> void:
	for h in helpers:
		h.going_home = true
		h.resting = false
		h.chatting = false
		if not h.task.is_empty() and not _finishes_at_night(h):
			_fail(h)


## Mess tasks are seen through at night: cleaning, and clearing a table's dirty plates.
func _finishes_at_night(h: Helper) -> bool:
	var type := str(h.task.get("type", ""))
	return HelperWork.TASK_KIND.get(type, "") == "clean" or type == "clear"


## Whether a helper's post includes `duty`.
func has_duty(h: Helper, duty: String) -> bool:
	var e: Dictionary = game.staff.employee(h.person)
	return not e.is_empty() and (e.get("duties", []) as Array).has(duty)


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
	board.cool(delta)
	if _since >= REBUILD_EVERY:
		_since = 0.0
		board.rebuild(room_view.world())
		var free := []
		for h in helpers:
			if h.steps.is_empty() and not h.going_home and not h.resting and not game.floor_dirt.is_down(h):
				free.append({"id": h.person, "cell": h.cell(), "idle": h.idle})
		var got := board.assign(game.staff, free, game.ledger.day, game.clock, game.day.day_length())
		for h in helpers:
			if got.has(h.person):
				_begin(h, got[h.person])
	for h in helpers.duplicate():
		_tick_helper(h, delta)
	_chat(delta)


func _tick_helper(h: Helper, delta: float) -> void:
	if h.going_home:
		_tick_home(h, delta)
		return
	var at_work := JobBoard.at_work(game.staff, h.person, game.ledger.day, game.clock, game.day.day_length())
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
		task_run._run(h, delta)
	h.walk(delta)
	_wear(h, delta)


## Whether they are cooking something on a heat tool right now.
func _on_the_heat(h: Helper) -> bool:
	if h.steps.is_empty() or str(h.steps[0].do) != "cook" or not h.step_started or h.work_left < 0.0:
		return false
	var st: Station = game.world.station_at(h.steps[0].get("at", Vector2i(-999, -999)))
	return st != null and st.is_heat_tool()


## Whether they are in the middle of steps of their own (stashing counts).
func _working(h: Helper) -> bool:
	return not h.steps.is_empty()


func _begin(h: Helper, task: Dictionary) -> void:
	var e: Dictionary = game.staff.employee(h.person)
	var dest_duty := ""
	if task.type == "fetch" and not str(task.get("job", "")) in ["", "none"]:
		var st: Station = game.world.station_at(task.dest)
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
	if h.task.has("key"):
		board.fail(h.person, h.task.key)
	board.release(h.person)
	h.task = {}
	h.steps.clear()
	h.step_started = false
	h.work_left = -1.0
	h.idle = RETRY_AFTER
	if STASH.has(str(was.get("do", ""))):
		_back_to_stacks(h)
		h.set_held("")   # nowhere to put it: it goes
		return
	var how := HelperWork.stash_for(h.held)
	if how != "":
		h.steps = [{"do": how}]


## Plates and cups that must be let go of go back on their stacks, food and all lost.
func _back_to_stacks(h: Helper) -> void:
	for d: Dish in h.dishes:
		var stack: Station = null
		if d.vessel != "" and not d.dirty:
			stack = game.world.find_station("cups") if d.vessel == Dish.CUP else room_view.rack_near(h.cell(), true)
		if stack != null:
			stack.count += 1
			stack.refresh()


## Drops the task for a break: what is in hand is put away first.
func _drop(h: Helper) -> void:
	if h.steps.is_empty() or not STASH.has(str(h.steps[0].get("do", ""))):
		_fail(h)
		h.idle = 0.0


## Frees the tool they were working and any surface they had in mind.
func _let_go(h: Helper) -> void:
	if h.held == "bill":
		h.set_held("")   # a slip is thrown away, not put down
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


# ---------------------------------------------------------------- going home

## A helper going home: any steps left are run to the end, then the desk, the bag, the door.
func _tick_home(h: Helper, delta: float) -> void:
	if game.floor_dirt.is_down(h):
		h.walk(delta)
		return
	if not h.steps.is_empty():
		h.idle = 0.0
		task_run._run(h, delta)
		h.walk(delta)
		return
	match h.home_stage:
		"":
			var c: Variant = _desk_spot(h)
			if c == null:
				_head_out(h)
			elif h.go_to(c):
				h.home_stage = "to_desk"
			else:
				_head_out(h)
		"to_desk":
			if h.arrived():
				h.desk = _desk_beside(h.cell())
				h.look_at_cell(h.desk)
				h.collect_left = COLLECT
				h.home_stage = "collect"
		"collect":
			h.collect_left -= delta
			if h.collect_left <= 0.0:
				h.take_bag()
				_head_out(h)
		"out":
			if h.arrived():
				_leave_for_good(h)
				return
	h.walk(delta)


## Out of the door and down the pavement, the way guests leave.
func _head_out(h: Helper) -> void:
	var exit: Vector2i = game.exit_cell()
	h.home_stage = "out"
	h.path.assign(game.grid.find_path(h.cell(), game.DOOR) + game.grid.find_path(game.DOOR, exit))
	h.stand = exit
	if h.path.is_empty() and h.cell() != exit:
		_leave_for_good(h)   # no way out at all


func _leave_for_good(h: Helper) -> void:
	_let_go(h)
	helpers.erase(h)
	h.queue_free()
	if h.get_parent():
		h.get_parent().remove_child(h)


## The desk beside a cell, or the cell itself when none is.
func _desk_beside(c: Vector2i) -> Vector2i:
	for side: Vector2i in Grid.DIRS:
		var st: Station = game.world.station_at(c + side)
		if st != null and st.type == "desk":
			return c + side
	return c


# ---------------------------------------------------------------- idle

## With nothing to do, they wait by a desk.
func _wait_by_desk(h: Helper) -> void:
	if not h.path.is_empty():
		return
	var c: Variant = _desk_spot(h)
	if c != null and c != h.stand:
		h.go_to(c)


## The open cell beside the nearest desk for this helper to stand on: the one they hold if
## they are first for it, else the closest free one. Null with no desk or no room.
func _desk_spot(h: Helper) -> Variant:
	var desks: Array = []
	for st: Station in game.stations.values():
		if st.type == "desk":
			desks.append(st.cell)
	var open := {}
	for d: Vector2i in desks:
		for side: Vector2i in Grid.DIRS:
			if task_run._open(d + side):
				open[d + side] = true
	if open.has(h.stand) and h.stand != Vector2i(-999, -999):
		var mine := true
		for o in helpers:
			if o != h and o.stand == h.stand:
				mine = mine and helpers.find(o) > helpers.find(h)
		if mine:
			return h.stand
	var taken := {}
	for o in helpers:
		if o != h:
			taken[o.stand] = true
	return HelperWork.wait_cell(desks, open, taken, h.cell())


## Free helpers near each other chat: speech bubbles. It no longer moves their
## satisfaction (review, item 11: one fewer hidden lever).
func _chat(delta: float) -> void:
	var free := []
	for h in helpers:
		h.chatting = false
		if h.steps.is_empty() and not h.going_home and (h.resting or h.idle >= HelperWork.IDLE_CHAT_AFTER) and h.arrived() \
				and not game.floor_dirt.is_down(h):
			free.append({"id": h.person, "cell": h.cell()})
	for pair: Array in HelperWork.chat_pairs(free):
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
		game.staff.nudge(h.person, -drain, "mess")


