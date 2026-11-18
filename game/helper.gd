class_name Helper
extends Player
## A hired townsperson at work in the room (PRD 10.6). A chef's body and hands, so they
## carry, use pieces, slip and are helped up like a chef, but nobody steers them: the crew
## (game/crew.gd) gives them steps from the task board and they walk the grid to each.
## They wear their own look with a work apron, so they read as staff and as themselves.

const ARRIVE := 0.12   # metres from a cell's middle that counts as there

var person := -1
var rating := 3
var steps: Array = []        # what is left of the task in hand (HelperWork.steps)
var task := {}               # the board's task they are on, {} for none
var step_started := false    # the first step's walk or work has begun
var work_left := -1.0        # seconds left on the work at hand, or -1 while walking
var path: Array[Vector2i] = []
var stand := Vector2i(-999, -999)   # where they are walking to
var idle := 0.0              # seconds with nothing to do
var resting := false         # on a break (or with nothing to do and nowhere to wait)
var chatting := false
var bubble: Node3D


func setup_helper(game_, person_: int, start: Vector2i) -> void:
	game = game_
	person = person_
	position = Grid.center(start)
	name = "Helper%d" % person
	var info: Dictionary = game.town.people[person]
	_body = Peg.guest(str(info.name))
	_apron(_body)
	add_child(Peg.rigged(_body))
	bubble = Fx.bubble()
	bubble.position = Vector3(0, 2.0 * Peg.SCALE - 0.1, 0)
	add_child(bubble)


## A white work apron wrapped round the barrel with a coral waist tie, and its bib in
## front: staff at a glance from any side, over their own clothes.
static func _apron(peg: Peg) -> void:
	Peg._band_on(peg, 0.15, 0.248, 0.2, Build.CHEF_WHITE)
	Peg._band_on(peg, 0.33, 0.242, 0.04, Build.CORAL)
	var bib := Build.box(peg, Vector3(0, 0.42, 0.19), Vector3(0.2, 0.14, 0.04), Build.CHEF_WHITE)
	bib.rotation.x = -0.35


## A helper's own pace: their rating, slowed by the floor under them.
func speed() -> float:
	return HelperWork.walk_speed(rating) * game.seating.floor_speed(position)


## Slipping hurts their mood a little too (PRD 10, section 6).
func fall() -> void:
	super.fall()
	game.staff.nudge(person, -HelperWork.SLIP_HIT, "slip")


## Sets off for a cell. Returns false when there is no way there.
func go_to(c: Vector2i) -> bool:
	stand = c
	if c == cell():
		path.clear()
		return true
	path = game.grid.find_path(cell(), c)
	return not path.is_empty()


## Whether they stand on `stand`, settled near its middle.
func arrived() -> bool:
	if not path.is_empty():
		return false
	var d := Grid.center(stand) - position
	d.y = 0.0
	return d.length() < ARRIVE * 2.0


## One frame of walking along the path (or standing still), through `Player.move`.
func walk(delta: float) -> void:
	var input := Vector2.ZERO
	var target := Vector3.INF
	if not path.is_empty():
		target = Grid.center(path[0])
	elif stand.x > -999 and not arrived():
		target = Grid.center(stand)
	if target != Vector3.INF:
		var d := target - position
		d.y = 0.0
		if not path.is_empty() and d.length() < ARRIVE * 2.5:
			path.pop_front()
		elif d.length() > 0.02:
			var dir := d.normalized()
			# Player.move takes screen input: world (dx, dz) = (x - y, -x - y).
			input = Vector2((dir.x - dir.z) * 0.5, -(dir.x + dir.z) * 0.5).normalized()
			if path.is_empty() and d.length() < 0.35:
				input *= d.length() / 0.35   # ease onto the spot
	move(input, delta)


## Faces a cell (the piece they are using).
func face(c: Vector2i) -> void:
	look_at_cell(c)


func show_bubble(id: String) -> void:
	Fx.set_bubble(bubble, id)
