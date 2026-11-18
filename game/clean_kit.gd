class_name CleanKit
extends Node3D
## Cleaning tools in the room (PRD 9.4): wires sim/clean_tools.gd into the scene. Tools
## live in homes (a mop bucket, a wall hook, a closet), are taken and put back with E, and
## while held fill the chef's hands. E at a dirty cell in front clears a level (held E
## repeats at the tool's pace); a dirty tool spreads instead until rinsed at the bucket or
## a sink. A tool put down anywhere else lies on the floor, in the way. The robot sweeper
## drifts from its dock to the nearest dirt, cleans it slowly and docks again. Works in
## service and at night alike; the rules live in CleanTools.

const PREFIX := "tool:"

var game
## Tools lying on the floor: Vector2i -> {"tool": String, "used": int, "node": Node3D}.
var lying := {}
## The robot of each dock: Station -> {"node": Node3D, "pos": Vector3, "path": Array,
## "t": seconds cleaning this level, "dir": Vector3}.
var robots := {}
var _wait := {}   # Player -> seconds before the next press of their tool
var _scrub := {}  # Player -> seconds scrubbed by hand on the cell in front (held E, no tool)


func setup(game_) -> void:
	game = game_


# ---------------------------------------------------------------- homes

## The piece at a cell that keeps a tool: a mop bucket standing there, a hook hung there,
## or the high shelf of a closet. Null for none.
func home_at(cell: Vector2i) -> Station:
	var st: Station = game.stations.get(cell)
	if st != null and CleanTools.home_kind(st.type) != "":
		return st
	var h: Station = game.highs.get(cell)
	if h != null and (CleanTools.home_kind(h.type) != "" or game.kitchen.is_closet(cell)):
		return h
	return null


## What kind of home a piece is: "bucket", "hook", or "closet" for a closet's high shelf.
func kind_of(home: Station) -> String:
	if home.high and game.kitchen.is_closet(home.cell):
		return CleanTools.CLOSET
	return CleanTools.home_kind(home.type)


## A newly bought piece: a mop bucket comes with its mop, a sponge on its hook.
func on_built(st: Station, bought: String) -> void:
	var tool := CleanTools.comes_with(bought)
	if st != null and tool != "":
		keep(st, tool, 0)


## A hook's tool bought up its tree (PRD 9.5): the new tool is kept there, clean. If the
## old one was out (in someone's hands, on the floor), that one is swapped instead.
func upgrade_tool(home: Station, tool: String) -> void:
	var was := home.kit_tool
	if was == "":
		was = CleanTools.comes_with(home.node) if home.node != "hook" else ""
	if home.kit_tool == "" and _swap_out(was, tool):
		return
	keep(home, tool, 0)


## A bucket bought up its tree is a new piece: its mop (now the new one) goes with it.
## A home that keeps no tool (the robot's dock) leaves the old mop wherever it is.
func upgrade_home(old: Station, up: Station, tool: String) -> void:
	if tool == "":
		return
	if old.kit_tool != "":
		keep(up, tool, 0)
	elif not _swap_out(CleanTools.comes_with(old.node), tool):
		keep(up, tool, 0)


## Swaps a tool of this kind that is out of its home (held, or lying) for the new one.
func _swap_out(was: String, tool: String) -> bool:
	if was == "":
		return false
	for ch: Player in game.chefs:
		if held_tool(ch) == was:
			hold(ch, tool, 0)
			return true
	for c: Vector2i in lying:
		if lying[c].tool == was:
			pick_up_lying(c)
			put_down(tool, 0, c)
			return true
	return false


## A new day: a spill kit has its three uses again, wherever it is.
func start_day() -> void:
	for home: Station in _homes():
		if CleanTools.uses_of(home.kit_tool) > 0:
			keep(home, home.kit_tool, 0)
	for ch: Player in game.chefs:
		if CleanTools.uses_of(held_tool(ch)) > 0:
			hold(ch, held_tool(ch), 0)
	for c: Vector2i in lying:
		if CleanTools.uses_of(lying[c].tool) > 0:
			lying[c].used = 0


func _homes() -> Array[Station]:
	var out: Array[Station] = []
	for st: Station in game.stations.values() + game.highs.values():
		if st.kit_tool != "":
			out.append(st)
	return out


## Puts a tool in a home (no checks) and draws it there.
func keep(home: Station, tool: String, used: int) -> void:
	home.kit_tool = tool
	home.kit_used = used
	show_home(home)


func show_home(home: Station) -> void:
	var old := home.get_node_or_null("kit_tool")
	if old != null:
		home.remove_child(old)
		old.queue_free()
	if home.kit_tool == "":
		return
	var n := Node3D.new()
	n.name = "kit_tool"
	n.rotation.y = home.facing * PI / 2   # turned with the piece: a hook on a side wall faces out
	home.add_child(n)
	var clean := CleanTools.cleanness(home.kit_tool, home.kit_used)
	match kind_of(home):
		"bucket":
			Build.bucket_mop(n, clean, home.kit_tool)
		"hook":
			Build.hand_tool(n, home.kit_tool, clean).position = Build.hook_spot(Build.HIGH_Y0)
		_:   # a closet: the mop stands in the corner, a sponge sits on the low shelf
			var mop := CleanTools.is_mop(home.kit_tool)
			var t: Node3D = Build.mop(n, clean, home.kit_tool) if mop else Build.hand_tool(n, home.kit_tool, clean)
			t.position = Vector3(0.28, 0.02, -0.28) if mop else Vector3(-0.2, 0.2, -0.28)


# ---------------------------------------------------------------- held tools

static func held_tool(ch: Player) -> String:
	return ch.held.trim_prefix(PREFIX) if ch.held.begins_with(PREFIX) else ""


static func holding(ch: Player) -> bool:
	return held_tool(ch) != ""


static func held_used(ch: Player) -> int:
	var t := held_tool(ch)
	return CleanTools.used_from(t, ch.held_quality) if t != "" else 0


## Puts a tool in the chef's hands: how clean it is rides on the held item's quality.
static func hold(ch: Player, tool: String, used: int) -> void:
	ch.set_held(PREFIX + tool, CleanTools.cleanness(tool, used))


# ---------------------------------------------------------------- E at a piece

## What E does at a piece for cleaning tools, by name ("" for nothing). Holding a tool:
## put it back in a home with room for it, else rinse it at a bucket or sink. With empty
## hands: take the tool kept here (a hook over another piece only when that piece has
## nothing to do). With dry_run nothing changes.
func station_use(st: Station, dry_run: bool, ch: Player) -> String:
	if st == null:
		return ""
	var home := home_at(st.cell)
	var tool := held_tool(ch)
	if tool != "":
		var used := held_used(ch)
		var nm := CleanTools.name_of(tool).to_lower()
		if home != null and home.kit_tool == "" and CleanTools.fits(kind_of(home), tool):
			if not dry_run:
				keep(home, tool, 0 if CleanTools.rinses(home.type) else used)
				ch.set_held("")
				_done(ch, home, "putdown")
			return "Put %s back" % nm
		if CleanTools.rinses(st.type) and used > 0:
			if not dry_run:
				hold(ch, tool, 0)
				_done(ch, st, "wash")
				game.audio.burst(st.position + Vector3(0, 1.0, 0), "bubbles", 0.4)
			return "Rinse %s" % nm
		return ""
	if ch.held != "" or home == null or home.kit_tool == "":
		return ""
	if home != st and not game.kitchen.is_closet(st.cell) and game.cooking._use_station(st, true, ch) != "":
		return ""   # a hook over a working piece: the piece comes first
	var what := CleanTools.name_of(home.kit_tool).to_lower()
	if not dry_run:
		hold(ch, home.kit_tool, home.kit_used)
		home.kit_tool = ""
		home.kit_used = 0
		show_home(home)
		_done(ch, home, "pickup")
	return "Take %s" % what


func _done(ch: Player, st: Station, sound: String) -> void:
	ch.punch()
	st.used()
	game.audio.sfx(sound)


# ---------------------------------------------------------------- E at the floor

## The cell a tool in hand would clean: the dirty cell in front, else the one underfoot.
## Null when neither has dirt that can be reached.
func clean_target(ch: Player) -> Variant:
	var m: FloorMess = game.floor_dirt.mess
	for c: Vector2i in [ch.cell() + ch.facing, ch.cell()]:
		if m.level(c) > 0 and m.can_clean(c) and (c == ch.cell() or game.grid.edge_open(ch.cell(), c)):
			return c
	return null


## Holding a tool with dirt straight ahead: cleaning it comes before any piece in reach
## (so mopping beside the bucket does not put the mop away).
func floor_first(ch: Player) -> bool:
	var c: Variant = clean_target(ch)
	return holding(ch) and c != null and c == ch.cell() + ch.facing


## Where a tool in hand would be put down: the free floor cell in front. Null for none.
func drop_target(ch: Player) -> Variant:
	var c: Vector2i = ch.cell() + ch.facing
	if game.plan.has_floor(c) and not game.grid.is_blocked(c) and not lying.has(c) \
			and game.grid.edge_open(ch.cell(), c) and not _robot_cells().has(c):
		return c
	return null


## A tool lying in front or underfoot, to pick up. Null for none.
func lying_target(ch: Player) -> Variant:
	for c: Vector2i in [ch.cell() + ch.facing, ch.cell()]:
		if lying.has(c):
			return c
	return null


## The cell the floor action is about (for the prompt), or null.
func floor_cell(ch: Player) -> Variant:
	if holding(ch):
		var c: Variant = clean_target(ch)
		return c if c != null else drop_target(ch)
	if ch.held != "":
		return null
	var l: Variant = lying_target(ch)
	return l if l != null else (clean_target(ch) if can_scrub(ch) else null)


## What E does on the floor, by name: "Mop", "Wipe" ("... spreads it" with a dirty tool),
## "Put mop down", "Pick up mop"; "" for nothing.
func floor_action(ch: Player) -> String:
	var tool := held_tool(ch)
	if tool != "":
		var nm := CleanTools.name_of(tool).to_lower()
		if clean_target(ch) != null:
			var verb := "Mop" if CleanTools.is_mop(tool) else ("Scrape" if tool == "grease_scraper" else "Wipe")
			return verb + (" (dirty: slow)" if CleanTools.is_dirty(tool, held_used(ch)) else "")
		if drop_target(ch) != null:
			return "Put %s down" % nm
		return ""
	if ch.held == "" and lying_target(ch) != null:
		return "Pick up %s" % CleanTools.name_of(lying[lying_target(ch)].tool).to_lower()
	if can_scrub(ch):
		return "Scrubbing %d%%" % int(scrub_share(ch) * 100) if _scrub.has(ch) else "Hold to scrub"
	return ""


## Bare hands with dirt in reach, and not at the door: holding E scrubs it (slower than any tool).
func can_scrub(ch: Player) -> bool:
	return ch.held == "" and ch.hand.is_empty() and clean_target(ch) != null and game.day.door_action(ch) == ""


## How far the scrub by hand on this chef's cell has got, 0 to 1 (0 when not scrubbing).
func scrub_share(ch: Player) -> float:
	return clampf(float(_scrub.get(ch, 0.0)) / CleanTools.HAND_TIME, 0.0, 1.0)


## E on the floor. Returns whether it did (or was waiting to do) something.
func floor_use(ch: Player) -> bool:
	var tool := held_tool(ch)
	if tool != "":
		if clean_target(ch) != null:
			if _wait.get(ch, 0.0) <= 0.0:
				press(ch)
			return true
		var at: Variant = drop_target(ch)
		if at == null:
			return false
		put_down(tool, held_used(ch), at)
		ch.set_held("")
		ch.punch()
		game.audio.sfx("putdown")
		return true
	var c: Variant = lying_target(ch)
	if c == null and can_scrub(ch):
		if not _scrub.has(ch):
			_scrub[ch] = 0.0   # starts the scrub; held E carries it on (hold_use)
			ch.punch()
		return true
	if ch.held != "" or c == null:
		return false
	var l: Dictionary = lying[c]
	pick_up_lying(c)
	hold(ch, l.tool, l.used)
	ch.punch()
	game.audio.sfx("pickup")
	return true


## One press of the held tool on the cell it aims at: clears a level, or spreads one if
## the tool is dirty. Starts the wait before the next press.
func press(ch: Player) -> String:
	var tool := held_tool(ch)
	var c: Variant = clean_target(ch)
	if tool == "" or c == null:
		return ""
	var used_before := held_used(ch)
	var r := CleanTools.press(game.floor_dirt.mess, c, tool, used_before)
	hold(ch, tool, r.used)
	if c != ch.cell():
		ch.look_at_cell(c)
	ch.punch()
	_wait[ch] = CleanTools.press_time(tool, held_used(ch))
	var at := Grid.center(c) + Vector3(0, 0.2, 0)
	if r.did == "clean":
		game.audio.sfx("wash", 0.1, 1.2)
		game.audio.burst(at, "bubbles", 0.3)
		if CleanTools.is_dirty(tool, r.used) and not CleanTools.is_dirty(tool, used_before):
			game.hud.say("The %s is dirty: it works slower until it is rinsed at the bucket or a sink." % CleanTools.name_of(tool).to_lower())
	elif r.did == "refused":   # the scraper on guest mess, a spill kit on a small spill (PRD 9.5)
		game.audio.sfx("fail")
		game.hud.say(r.why)
	if CleanTools.used_up(tool, r.used) and r.did == "clean":
		game.hud.say("The spill kit is used up for today.")
	game.floor_dirt.redraw()
	return r.did


## E held down: the tool presses again each time its wait runs out. By hand, a scrub
## started by E goes on while E is held and clears a level each HAND_TIME seconds;
## letting go, or turning off the dirt, stops it.
func hold_use(ch: Player, down: bool, delta := 0.0) -> void:
	if down and holding(ch) and _wait.get(ch, 0.0) <= 0.0 and clean_target(ch) != null:
		press(ch)
	if not _scrub.has(ch):
		return
	if not down or not can_scrub(ch):
		_scrub.erase(ch)
		return
	var before := float(_scrub[ch])
	_scrub[ch] = before + delta
	if int(before / 0.45) != int(_scrub[ch] / 0.45):
		ch.punch()   # the scrubbing arm
		var tc: Vector2i = clean_target(ch)
		game.audio.burst(Grid.center(tc) + Vector3(0, 0.15, 0), "bubbles", 0.18)
	if float(_scrub[ch]) >= CleanTools.HAND_TIME:
		var c: Vector2i = clean_target(ch)
		if c != ch.cell():
			ch.look_at_cell(c)
		CleanTools.hand_scrub(game.floor_dirt.mess, c)
		_scrub[ch] = 0.0
		game.audio.sfx("wash", 0.1, 1.0)
		game.audio.burst(Grid.center(c) + Vector3(0, 0.2, 0), "bubbles", 0.3)
		game.floor_dirt.redraw()
		if clean_target(ch) == null:
			_scrub.erase(ch)


## A tool left on the floor: drawn lying there, and in the way.
func put_down(tool: String, used: int, cell: Vector2i) -> void:
	var n := Node3D.new()
	add_child(n)
	var clean := CleanTools.cleanness(tool, used)
	var t: Node3D = Build.mop(n, clean, tool) if CleanTools.is_mop(tool) else Build.hand_tool(n, tool, clean)
	if CleanTools.is_mop(tool) and tool != "scrubber":   # a mop lies flat; the scrubber stands on its deck
		t.rotation = Vector3(0, 0, PI / 2 - 0.04)
		t.position = Vector3(0.6, 0.06, 0)
	n.position = Grid.center(cell)
	n.rotation.y = PI / 4
	lying[cell] = {"tool": tool, "used": used, "node": n}


func pick_up_lying(cell: Vector2i) -> void:
	var l: Dictionary = lying[cell]
	(l.node as Node3D).queue_free()
	lying.erase(cell)


# ---------------------------------------------------------------- the robot

func _robot_cells() -> Dictionary:
	var out := {}
	for dock: Station in robots:
		if robots[dock].node.visible:
			out[Grid.to_cell(robots[dock].pos)] = true
	return out


## Every frame, in every phase: tool waits run down, robots wake for their docks, drift
## and clean, and the cells with something in the way are handed to the floor.
func tick(delta: float) -> void:
	for ch: Player in _wait.keys():
		_wait[ch] = maxf(0.0, float(_wait[ch]) - delta)
	_push(delta)
	for st: Station in game.stations.values():
		if st.type == "robot_dock" and not robots.has(st):
			_add_robot(st)
	for dock: Station in robots.keys():
		var r: Dictionary = robots[dock]
		if not is_instance_valid(dock):
			(r.node as Node3D).queue_free()
			robots.erase(dock)
			continue
		var placed: bool = game.stations.get(dock.cell) == dock and dock.visible
		r.node.visible = placed
		if not placed:   # the dock is being carried: the robot rides along, home
			_send_home(dock)
			continue
		_robot_step(dock, r, delta)
	var way := _robot_cells()
	for dock: Station in robots:
		way.erase(dock.cell)   # docked: the dock is furniture already
	for c: Vector2i in lying:
		way[c] = true
	game.floor_dirt.in_way = way


func _add_robot(dock: Station) -> void:
	var n := Node3D.new()
	Build.robot(n)
	add_child(n)
	robots[dock] = {"node": n, "pos": Vector3.ZERO, "path": [], "t": 0.0, "dir": Vector3(0, 0, 1)}
	_send_home(dock)


func _send_home(dock: Station) -> void:
	var r: Dictionary = robots[dock]
	r.pos = Grid.center(dock.cell) + Vector3(0, 0.05, 0)
	r.path = []
	r.t = 0.0
	(r.node as Node3D).position = r.pos


## The day is over: every robot is back on its dock to charge.
func end_day() -> void:
	for dock: Station in robots:
		if is_instance_valid(dock):
			_send_home(dock)


func is_docked(dock: Station) -> bool:
	return robots.has(dock) and Grid.to_cell(robots[dock].pos) == dock.cell


## Where a robot can drive: floor with nothing standing on it.
func _walkable() -> Dictionary:
	var out := {}
	for c: Vector2i in game.plan.floors:
		if not game.grid.is_blocked(c):
			out[c] = true
	return out


func _robot_step(dock: Station, r: Dictionary, delta: float) -> void:
	var m: FloorMess = game.floor_dirt.mess
	var here := Grid.to_cell(r.pos)
	var brush: Node3D = r.node.get_node_or_null("brush")
	if (r.path as Array).is_empty():
		var at_center := Vector2(r.pos.x - Grid.center(here).x, r.pos.z - Grid.center(here).z).length() < 0.05
		if at_center and m.level(here) > 0 and m.can_clean(here):
			r.t += delta   # cleaning where it stands
			if brush:
				brush.rotation.y += delta * 9.0
			if r.t >= CleanTools.ROBOT_CLEAN_TIME:
				r.t = 0.0
				m.clean(here, 1)
				game.floor_dirt.redraw()
			return
		r.t = 0.0
		var open := func(a: Vector2i, b: Vector2i) -> bool: return game.grid.edge_open(a, b)
		var walk := _walkable()
		r.path = CleanTools.path_to_dirt(m, here, walk, open)
		if (r.path as Array).is_empty() and here != dock.cell:
			r.path = CleanTools.path_home(here, dock.cell, walk, open)
		if (r.path as Array).is_empty():
			return   # docked with nothing to do, or nowhere to go
	var to := Grid.center(r.path[0]) + Vector3(0, 0.05, 0)
	var d: Vector3 = to - r.pos
	var step := CleanTools.ROBOT_SPEED * delta
	if d.length() <= step:
		r.pos = to
		r.path.pop_front()
		r.path = []   # look again from each cell: the dirt or the room may have changed
	else:
		r.dir = d.normalized()
		r.pos += r.dir * step
	if brush:
		brush.rotation.y += delta * 6.0
	var n: Node3D = r.node
	n.position = r.pos
	n.rotation.y = atan2(r.dir.x, r.dir.z)


# ---------------------------------------------------------------- the floor scrubber

## A chef pushing a floor scrubber (PRD 9.5) clears every cell they walk over, a level at
## the scrubber's pace, as long as they hold it.
func _push(_delta: float) -> void:
	var m: FloorMess = game.floor_dirt.mess
	for ch: Player in game.chefs:
		var tool := held_tool(ch)
		if not CleanTools.pushes(tool) or _wait.get(ch, 0.0) > 0.0:
			continue
		var c := ch.cell()
		if m.level(c) > 0 and m.can_clean(c):
			m.clean(c, int(CleanTools.TOOLS[tool].levels))
			_wait[ch] = CleanTools.press_time(tool)
			game.audio.burst(Grid.center(c) + Vector3(0, 0.2, 0), "bubbles", 0.3)
			game.floor_dirt.redraw()


## How fast a chef walks with what they hold: a floor scrubber is slow to push.
static func walk_factor(ch: Player) -> float:
	return CleanTools.walk_speed(held_tool(ch))


## Clears everything for tests: tools on the floor and robots.
func clear() -> void:
	for c: Vector2i in lying.keys():
		pick_up_lying(c)
	for dock: Station in robots.keys():
		(robots[dock].node as Node3D).queue_free()
	robots.clear()
	_wait.clear()
	_scrub.clear()
