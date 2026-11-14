class_name Player
extends Node3D
## The chef you control directly. WASD to move; main.gd handles interaction.

const SPEED := 4.4
const RADIUS := 0.28
const REACH := 1.3   # how far from a station's centre (or a seated guest) the chef can use it
const GROSS_ITEMS: Array[String] = ["dirty_tray", "rubbish_bag"]   # and anything burnt

var game
var held := ""
var held_quality := 1.0
var tray: Tray                    # the tray in hand, when held is "tray"
var tray_tag := ""                # the colour of its ticket slip
var facing := Vector2i(0, 1)      # nearest grid direction to `aim`
var aim := Vector3(0, 0, 1)       # the way the chef is really looking (any of 8 ways)
var _velocity := Vector3.ZERO
var _held_node: Node3D
var _held_size := 1.0   # the carried item's size in the world; it pops in from 0.4
var _body: Peg
var _stride := 0.0
var boost_speed := 1.0   # times SPEED: a prep minigame's burst (1.5) or penalty (0.5)
var boost_left := 0.0    # seconds of it left
var _boost_fx: Node3D    # speed lines and a star, or a sweat drop
var _boost_age := 0.0
## What belongs to this chef's player rather than to the game (PRD 4): the build
## hand and its drag, where they aim, and the marks drawn for them in the room.
var trim := 0                     # which PLAYER_TRIM colour the chef wears
var hand := {}                    # build phase: the piece or tool in hand ({} for none)
var drag := {}                    # a mouse drag with a build tool: {"from": Vector3, "remove": bool}
var aim_mouse := false            # build phase: the mouse, not the chef, says where things go
var mouse_point := Vector3.INF
var last_paint := Vector3i(-999, -999, -1)   # the spot Use last built on while held
var demo_hover := Vector3.INF     # demos and tests: where the hand is held
var ghost: Node3D                 # the piece in hand, held over its spot
var ghost_key := ""
var tool_ghost: Node3D            # a build tool's tiles or bars
var tool_key := ""
var no_mark: Node3D               # the cross where the piece in hand cannot go
var range_marks: Node3D           # floor marks for the reach of the piece being carried
var range_key := ""
var cursor: Node3D                # the frame on the station this chef would use
var cursor_key := ""


func setup(game_, start: Vector2i, trim_ := 0) -> void:
	game = game_
	position = Grid.center(start)
	set_trim(trim_)


## Dresses the chef in a player's trim colour (a new body; what is carried stays).
func set_trim(t: int) -> void:
	trim = t
	var rig: Node3D = _body.get_parent() if _body else null
	_body = Peg.chef(t)
	if rig:
		var at := get_children().find(rig)
		_held_node = null   # it goes with the old body
		rig.queue_free()
		remove_child(rig)
		var fresh := Peg.rigged(_body)
		add_child(fresh)
		move_child(fresh, at)
		if held != "":
			set_held(held, held_quality, tray, tray_tag)
	else:
		add_child(Peg.rigged(_body))


func set_held(kind: String, quality := 1.0, tray_: Tray = null, tag := "") -> void:
	held = kind
	held_quality = quality
	tray = tray_ if kind == "tray" else null
	tray_tag = tag if kind == "tray" else ""
	if _held_node:
		_held_node.queue_free()
		_held_node = null
	_body.pose = "carry" if kind != "" else "idle"
	if kind != "":
		_held_node = Build.tray(tray, tray_tag) if kind == "tray" else Build.item(kind, quality)
		_held_node.position = Vector3(0, 0.42, 0.34)
		_body.add_child(_held_node)
		_held_size = 0.4
		_held_node.create_tween().tween_property(self, "_held_size", 1.0, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A prep minigame's reward ("burst") or penalty ("penalty"): faster or slower for
## a moment, shown on the chef by shape and motion (speed lines and a spinning star;
## a sweat drop and a wobble), not only colour.
func boost(kind: String) -> void:
	boost_speed = Prep.BURST_SPEED if kind == "burst" else Prep.PENALTY_SPEED
	boost_left = Prep.BOOST_TIME
	_boost_age = 0.0
	if _boost_fx:
		_boost_fx.queue_free()
	_boost_fx = Node3D.new()
	_boost_fx.basis = Build.CAM_BASIS
	add_child(_boost_fx)
	if kind == "burst":
		var star := Node3D.new()
		star.name = "star"
		star.position = Vector3(0.0, 1.95, 0.0)
		_boost_fx.add_child(star)
		Build.flat(star, Build.star_pts(0.13, 5, 0.48), Build.TRIM)
		Build.flat(star, Build.star_pts(0.095, 5, 0.48), "#f2b632", 0.004)
		var lines := Node3D.new()
		lines.name = "lines"
		_boost_fx.add_child(lines)
		for k in 3:
			Build.flat(lines, Icons.rect(0.0, 0.55 + k * 0.22, 0.34 - k * 0.06, 0.05), Build.PAPER, 0.002 * k)
	else:
		var drop := Node3D.new()
		drop.name = "drop"
		drop.position = Vector3(0.3, 1.6, 0.0)
		_boost_fx.add_child(drop)
		var pts := Build.disc_pts(0.07, Vector2.ZERO, 14)
		Build.flat(drop, pts, Build.TRIM)
		Build.flat(drop, PackedVector2Array([Vector2(-0.06, 0.03), Vector2(0.06, 0.03), Vector2(0, 0.15)]), Build.TRIM)
		Build.flat(drop, Build.disc_pts(0.05, Vector2.ZERO, 14), "#8fc6e8", 0.004)
		Build.flat(drop, PackedVector2Array([Vector2(-0.042, 0.02), Vector2(0.042, 0.02), Vector2(0, 0.12)]), "#8fc6e8", 0.004)
	Build.on_top(_boost_fx)


## Runs down a burst or penalty. Called every step of service.
func tick(delta: float) -> void:
	if boost_left <= 0.0:
		return
	boost_left -= delta
	_boost_age += delta
	if boost_left <= 0.0:
		boost_left = 0.0
		boost_speed = 1.0
		_body.rotation.z = 0.0
		if _boost_fx:
			_boost_fx.queue_free()
			_boost_fx = null
		return
	if _boost_fx == null:
		return
	if boost_speed > 1.0:
		_boost_fx.get_node("star").rotation.z = _boost_age * 6.0
		# The lines trail behind: to the side of the screen the chef is running from.
		var lines: Node3D = _boost_fx.get_node("lines")
		var side := -signf(aim.dot(Vector3(1, 0, -1)))
		lines.position.x = (0.42 if side >= 0.0 else -0.42)
	else:
		_body.rotation.z = sin(_boost_age * 22.0) * 0.12   # the wobble
		_boost_fx.get_node("drop").position.y = 1.6 - fmod(_boost_age * 0.3, 0.12)


func speed() -> float:
	return SPEED * boost_speed


## A quick squash and stretch whenever the chef does something.
func punch() -> void:
	_body.scale = Vector3(1.15, 0.85, 1.15)
	_body.create_tween().tween_property(_body, "scale", Vector3.ONE, 0.25) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Arms out while a piece of furniture is being carried in the build phase.
func carry(on: bool) -> void:
	if held == "":
		_body.pose = "carry" if on else "idle"


func carrying_something_gross() -> bool:
	return GROSS_ITEMS.has(held) or held.begins_with("burnt:")


func cell() -> Vector2i:
	return Grid.to_cell(position)


## The cell the chef would use right now, chosen by nearness: any station within
## REACH that has something to do, the closest winning, with a small nudge toward
## the one the chef faces. A table also counts as near when one of its seated
## guests is, so walking up to the guest is enough to serve them. With nothing
## useful in reach, the cell straight ahead.
func target_cell() -> Vector2i:
	var here := cell()
	var best := here + facing
	var best_score := -INF
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var n := here + Vector2i(dx, dy)
			if not game.stations.has(n):
				continue
			if absi(dx) + absi(dy) == 1 and not game.grid.edge_open(here, n):
				continue   # a partition is in the way
			var st: Station = game.stations[n]
			var to := Grid.center(n) - position
			to.y = 0.0
			var dist := to.length()
			for s in st.seats:
				if game.seat_taken.has(s):
					dist = minf(dist, (Grid.center(s) - position).length())
			var action: String = game.prompt_for(st, self)
			if dist > REACH or action == "":
				continue
			var score := -dist + 0.4 * to.normalized().dot(aim)
			if action.begins_with("Serve"):
				score += 0.5   # a waiting guest beats a counter to put the plate on
			if score > best_score:
				best_score = score
				best = n
	return best


## Turns the chef to look along a grid direction (used by tests and demos).
func look(dir: Vector2i) -> void:
	facing = dir
	aim = Vector3(dir.x, 0, dir.y).normalized()


func _can_stand(from: Vector3, to: Vector3) -> bool:
	var g: Grid = game.grid
	var c := Grid.to_cell(to)
	var c0 := Grid.to_cell(from)
	if g.is_blocked(c):
		return false
	if c != c0 and (absi(c.x - c0.x) + absi(c.y - c0.y) != 1 or not g.edge_open(c0, c)):
		return false
	for d in Grid.DIRS:
		var n := Grid.to_cell(to + Vector3(d.x, 0, d.y) * RADIUS)
		if n != c and (g.is_blocked(n) or not g.edge_open(c, n)):
			return false
	return true


## True when the chef overlaps something solid: a piece put down right beside
## them, or on top of them. From there every step would be refused.
func stuck() -> bool:
	return not _can_stand(position, position)


## Where a stuck chef should go: the middle of their own cell if it is clear
## (that is always a legal spot), or else of the nearest clear cell.
func _way_out() -> Vector3:
	var here := cell()
	var best := here
	var best_d := INF
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var c := here + Vector2i(dx, dy)
			var d := (Grid.center(c) - position).length()
			if d < best_d and not game.grid.is_blocked(c):
				best_d = d
				best = c
	return Grid.center(best)


## Moves by a screen-space input vector (x = right, y = up on screen).
func move(input: Vector2, delta: float) -> void:
	if stuck():   # slide out, through whatever is in the way, before anything else
		_velocity = Vector3.ZERO
		position = position.move_toward(_way_out(), SPEED * 1.2 * delta)
		return
	# The camera looks from +x/+z, so screen-up is (-1, -1) and screen-right is (1, -1).
	var dir := Vector3.ZERO
	if input != Vector2.ZERO:
		dir = (Vector3(1, 0, -1) * input.x + Vector3(-1, 0, -1) * input.y).normalized()
		aim = dir  # always turn to face the way we are going
		if absf(dir.x) > absf(dir.z) + 0.01:
			facing = Vector2i(signi(roundi(dir.x)), 0)
		elif absf(dir.z) > absf(dir.x) + 0.01:
			facing = Vector2i(0, signi(roundi(dir.z)))
		elif facing.x != signi(roundi(dir.x)) and facing.y != signi(roundi(dir.z)):
			facing = Vector2i(signi(roundi(dir.x)), 0)
	_velocity = _velocity.lerp(dir * speed(), 1.0 - exp(-16.0 * delta))
	var step := _velocity * delta
	var next := position + Vector3(step.x, 0, 0)
	if _can_stand(position, next):
		position = next
	else:
		_velocity.x = 0.0
	next = position + Vector3(0, 0, step.z)
	if _can_stand(position, next):
		position = next
	else:
		_velocity.z = 0.0
	var pace := minf(_velocity.length() / SPEED, 1.4)
	var before := floori(_stride / PI)
	_stride += delta * 13.0 * pace
	if floori(_stride / PI) != before and pace > 0.3:
		game.sfx("step", 0.15)
	_body.position.y = absf(sin(_stride)) * 0.07 * pace
	# Lean into a run, and tip whatever is carried so its top faces the camera.
	_body.rotation.x = lerpf(_body.rotation.x, 0.3 * pace, 1.0 - exp(-10.0 * delta))
	if _held_node:
		_held_node.global_basis = Basis(Vector3(1, 0, -1).normalized(), deg_to_rad(25.0)).scaled(Vector3.ONE * _held_size)
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(aim.x, aim.z), 1.0 - exp(-18.0 * delta))
