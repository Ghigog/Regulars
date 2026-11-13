class_name Player
extends Node3D
## The chef you control directly. WASD to move; main.gd handles interaction.

const SPEED := 4.4
const RADIUS := 0.28
const REACH := 1.3   # how far from a station's centre (or a seated guest) the chef can use it
const GROSS_ITEMS: Array[String] = ["dirty_plate", "burnt_patty"]

var game
var held := ""
var held_quality := 1.0
var facing := Vector2i(0, 1)      # nearest grid direction to `aim`
var aim := Vector3(0, 0, 1)       # the way the chef is really looking (any of 8 ways)
var _velocity := Vector3.ZERO
var _held_node: Node3D
var _body: Peg
var _stride := 0.0


func setup(game_, start: Vector2i) -> void:
	game = game_
	position = Grid.center(start)
	_body = Peg.chef(0)
	add_child(Peg.rigged(_body))


func set_held(kind: String, quality := 1.0) -> void:
	held = kind
	held_quality = quality
	if _held_node:
		_held_node.queue_free()
		_held_node = null
	_body.pose = "carry" if kind != "" else "idle"
	if kind != "":
		_held_node = Build.item(kind, quality)
		_held_node.position = Vector3(0, 0.42, 0.34)
		_body.add_child(_held_node)
		_held_node.scale = Vector3.ONE * 0.4
		_held_node.create_tween().tween_property(_held_node, "scale", Vector3.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	return GROSS_ITEMS.has(held)


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
			var action: String = game.prompt_for(st)
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
	_velocity = _velocity.lerp(dir * SPEED, 1.0 - exp(-16.0 * delta))
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
	var pace := _velocity.length() / SPEED
	var before := floori(_stride / PI)
	_stride += delta * 13.0 * pace
	if floori(_stride / PI) != before and pace > 0.3:
		game.sfx("step", 0.15)
	_body.position.y = absf(sin(_stride)) * 0.07 * pace
	# Lean into a run, and tip whatever is carried so its top faces the camera.
	_body.rotation.x = lerpf(_body.rotation.x, 0.3 * pace, 1.0 - exp(-10.0 * delta))
	if _held_node:
		_held_node.global_basis = Basis(Vector3(1, 0, -1).normalized(), deg_to_rad(25.0)).scaled(_held_node.scale)
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(aim.x, aim.z), 1.0 - exp(-18.0 * delta))
