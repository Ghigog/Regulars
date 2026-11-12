class_name Guest
extends Node3D
## A named townsperson visiting the restaurant. Driven by main.gd's step().

const SPEED := 2.4
const QUEUE_PATIENCE := 40.0
const EAT_TIME := 5.0
const BAR_WIDTH := 0.6
const SEAT_HEIGHT := 0.2

var game
var idx := 0
var info: Dictionary
var mood := GuestMood.new()
var state := "queue"  # queue, to_seat, waiting, eating, leaving
var path: Array[Vector2i] = []
var cell := Vector2i.ZERO
var seat := Vector2i(-1, -1)
var table: Station
var timer := 0.0
var _body: Peg
var stormed := false
var _bar: Node3D
var _fill: MeshInstance3D
var _order: Node3D
var _meal: Node3D
var _label: Label3D
var _thought_time := 0.0
var _shown_thoughts := 0
var _age := 0.0


func setup(game_, idx_: int, start: Vector2i) -> void:
	game = game_
	idx = idx_
	info = game.town.people[idx]
	cell = start
	position = Grid.center(start)
	_body = Peg.guest(info.name)
	_body.rotation.y = -PI / 2
	add_child(_body)
	_bar = Node3D.new()
	_bar.position = Vector3(0, 1.5, 0)
	_bar.rotation.y = PI / 4  # face the fixed camera
	add_child(_bar)
	Build.box(_bar, Vector3(0, -0.02, -0.02), Vector3(BAR_WIDTH + 0.06, 0.14, 0.02), "#3a2c22")
	_fill = Build.box(_bar, Vector3.ZERO, Vector3(BAR_WIDTH, 0.1, 0.02), "#ffffff")
	_order = Build.item("burger")
	_order.position = Vector3(0, 1.85, 0)
	_order.visible = false
	add_child(_order)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 36
	_label.outline_size = 10
	_label.pixel_size = 0.006
	_label.position = Vector3(0, 2.3, 0)
	add_child(_label)


func walk_to(target: Vector2i) -> void:
	path = game.grid.find_path(cell, target)


func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() > 0.0001:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-12.0 * delta))


## Moves along the path. Returns true once there is nowhere left to go.
func _advance(delta: float) -> bool:
	if path.is_empty():
		_body.position.y = 0.0
		return true
	var target := Grid.center(path[0])
	_face(target - position, delta)
	position = position.move_toward(target, SPEED * delta)
	_body.position.y = absf(sin(_age * 11.0)) * 0.06
	if position.distance_to(target) < 0.01:
		cell = path.pop_front()
	return path.is_empty()


func _sit() -> void:
	state = "waiting"
	mood.patience = minf(1.0, mood.patience + 0.3)
	_body.create_tween().tween_property(_body, "position:y", SEAT_HEIGHT, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	game.on_seated(self)


func start_eating(quality: float) -> void:
	mood.taste(quality)
	state = "eating"
	timer = EAT_TIME
	var to_table := (Grid.center(table.cell) - position).normalized()
	_meal = Build.item("burger")
	_meal.position = to_table * 0.6 + Vector3(0, 0.7, 0)
	add_child(_meal)
	var tw := _body.create_tween()
	tw.tween_property(_body, "position:y", SEAT_HEIGHT + 0.3, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position:y", SEAT_HEIGHT, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func stand_up() -> void:
	state = "leaving"
	if _meal:
		_meal.queue_free()
		_meal = null


func tick(delta: float) -> void:
	_age += delta
	match state:
		"queue":
			_advance(delta)
			mood.wait(delta, QUEUE_PATIENCE)
			if mood.walked_out():
				game.walk_out(self)
		"to_seat":
			if _advance(delta):
				_sit()
		"waiting":
			_face(Grid.center(table.cell) - position, delta)
			mood.wait(delta, game.table_patience())
			game.apply_surroundings(self, delta)
			if mood.walked_out():
				game.walk_out(self)
		"eating":
			timer -= delta
			# Lean in for a bite, and the burger shrinks as it is eaten.
			_body.rotation.x = maxf(0.0, sin(_age * 7.0)) * 0.22
			_meal.scale = Vector3.ONE * lerpf(0.35, 1.0, clampf(timer / EAT_TIME, 0.0, 1.0))
			game.apply_surroundings(self, delta)
			if timer <= 0.0:
				game.finish_meal(self)
		"leaving":
			if _advance(delta):
				game.remove_guest(self)
				return
	_refresh(delta)


func _refresh(delta: float) -> void:
	var p := mood.patience
	_bar.visible = state == "queue" or state == "waiting" or state == "to_seat"
	_fill.scale.x = maxf(p, 0.001)
	_fill.position.x = (p - 1.0) * BAR_WIDTH / 2.0
	var shade := snappedf(p, 0.05)  # few distinct colours, so materials stay cached
	var col := Color("#ff6b5e").lerp(Color("#ffd34e"), clampf(shade * 2.0, 0, 1)).lerp(Color("#5fd38d"), clampf(shade * 2.0 - 1.0, 0, 1))
	_fill.material_override = Build.mat(col, 0.5)
	# Impatient guests shake a little.
	_body.position.x = sin(_age * 40.0) * 0.02 if (_bar.visible and p < 0.25) else 0.0
	_body.set_face(mood.expression(state == "eating", stormed))
	_body.pose = "eat" if state == "eating" else ("tap" if state == "waiting" and p < 0.35 else "idle")
	# Bored guests slump; guests about to snap lean in; disgust pitches them back.
	var lean := 0.0
	if state == "waiting":
		lean = -0.2 if mood.disgust > 0.5 else (0.14 if p < 0.25 else (0.07 if p < 0.5 else 0.0))
	elif state == "leaving" and stormed:
		lean = 0.3
	if state != "eating":
		_body.rotation.x = lerpf(_body.rotation.x, lean, 1.0 - exp(-8.0 * delta))
	_order.visible = state == "waiting"
	_order.position.y = 1.85 + sin(_age * 3.0) * 0.04
	if mood.thoughts.size() > _shown_thoughts:
		_shown_thoughts = mood.thoughts.size()
		_thought_time = 4.0
	_thought_time -= delta
	var text: String = info.name
	if _thought_time > 0.0:
		text += "\n“%s”" % mood.latest_thought()
	_label.text = text
