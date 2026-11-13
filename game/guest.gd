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
var _meal_kind := ""
var _label: Label3D
var _gross_time := 0.0
var _heart_time := 0.0
var _last_disgust := 0.0
var _age := 0.0


func setup(game_, idx_: int, start: Vector2i) -> void:
	game = game_
	idx = idx_
	info = game.town.people[idx]
	var hello: Dictionary = game.town.greeting(idx)
	mood.patience = hello.patience
	mood.delight(hello.joy, hello.thought)
	cell = start
	position = Grid.center(start)
	_body = Peg.guest(info.name)
	_body.rotation.y = -PI / 2
	add_child(_body)
	# A chunky patience meter under the thought bubble, facing the camera.
	_bar = Node3D.new()
	_bar.position = Vector3(0, 1.58, 0)
	_bar.basis = Build.CAM_BASIS
	add_child(_bar)
	Build.flat(_bar, Icons.rect(0, 0, BAR_WIDTH + 0.07, 0.15), Build.TRIM)
	Build.flat(_bar, Icons.rect(0, 0, BAR_WIDTH, 0.08), "#6b5647", 0.003)
	_fill = Build.flat(_bar, Icons.rect(0, 0, BAR_WIDTH, 0.08), "#ffffff", 0.006)
	_order = Fx.bubble()
	_order.position = Vector3(0, 2.0, 0)
	add_child(_order)
	# A paper name tag.
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 30
	_label.outline_size = 10
	_label.pixel_size = 0.006
	_label.modulate = Color(Build.TRIM)
	_label.outline_modulate = Color(Build.PAPER)
	_label.position = Vector3(0, 1.3, 0)
	_label.text = info.name
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
	if quality > 0.95:
		_heart_time = 2.5
	state = "eating"
	timer = EAT_TIME
	_set_meal("burger", quality)
	var tw := _body.create_tween()
	tw.tween_property(_body, "position:y", SEAT_HEIGHT + 0.3, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position:y", SEAT_HEIGHT, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _set_meal(kind: String, quality: float) -> void:
	if _meal:
		_meal.queue_free()
	_meal_kind = kind
	var to_table := (Grid.center(table.cell) - position).normalized()
	_meal = Build.item(kind, quality)
	_meal.position = to_table * 0.62 + Vector3(0, 0.58, 0)
	add_child(_meal)


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
			if timer < EAT_TIME * 0.55 and _meal_kind == "burger":
				_set_meal("burger_bitten", mood.savour)
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
	var shade := snappedf(p, 0.1)  # few distinct colours, so materials stay cached
	var col := Color(Build.DANGER).lerp(Color(Build.WARN), clampf(shade * 2.0, 0, 1)).lerp(Color(Build.GOOD), clampf(shade * 2.0 - 1.0, 0, 1))
	_fill.material_override = Build.flat_mat(col)
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
	# One bold icon says what is on their mind (sheet 13).
	if mood.disgust > _last_disgust + 0.0005:
		_gross_time = 2.5
	_last_disgust = mood.disgust
	_gross_time -= delta
	_heart_time -= delta
	var want := ""
	if _gross_time > 0.0 and (state == "waiting" or state == "eating"):
		want = "stink"
	elif state == "waiting":
		want = "burger"
	elif state == "queue" and p < 0.6:
		want = "zzz"
	elif _heart_time > 0.0:
		want = "heart"
	Fx.set_bubble(_order, want)
	_order.position.y = 2.2 + sin(_age * 3.0) * 0.03
	_label.position.y = 2.72 if want != "" else (1.84 if _bar.visible else 1.6)
