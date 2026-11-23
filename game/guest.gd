class_name Guest
extends Node3D
## A named townsperson visiting the restaurant. Driven by main.gd's step().

const SPEED := 2.4
const QUEUE_PATIENCE := 50.0
const EAT_TIME := 5.0
const BAR_WIDTH := 0.6
const SEAT_HEIGHT := 0.33
const PERSONAL := 0.6     # another guest closer than this, straight ahead, is in the way
const GIVE_WAY := 1.0     # the longest a walker waits behind someone before carrying on

var game
var idx := 0
var info: Dictionary
var mood := GuestMood.new()
var state := "queue"  # queue, to_seat, ordering, waiting (for food), eating, company, browse, leaving,
## and paying (PRD 11): chatting (after the last bite), to_pay (seated, waiting for the
## bill), to_till (walking to pay at the till), at_till (queued in front of the pass)
const CHAT_TIME := 3.0    # tunable: seconds of chat after the meal before asking for the bill
var calling := false      # PRD 11: this guest has a hand up with the bill bubble
## browse: reading the menu at the door, having found no main; they walk on after.
const BROWSE_TIME := 2.2
var hint_tag := ""        # a liked tag the menu is full of, which they remarked on
var liked_meal := false   # their meal had something they like
## What they asked for once the chef took their order: {main, side, drink} (menu
## items, any of them {}) and "ticket", the ticket id (-1 if they ordered nothing).
## Empty until then. `planned` is what they will order, chosen at the door.
var order := {}
var planned := {}
var no_table := false   # no table in the room could ever seat their group: they turn away at the door
var orders_nothing := false   # found nothing on the menu at the door: no notepad, no ticket
var bill_base := 0       # the order's price: what the bill is before mood and deals
var _meal_tray: Tray
var path: Array[Vector2i] = []
var goal := Vector3.ZERO  # the exact spot to stop on once the path is walked
var heading := Vector3.ZERO   # which way they stepped last frame; zero when standing
var line_place := -1      # place in the queue at the door, 0 at the front
var _waited := 0.0
var hold := 0.0           # seconds to stand still before setting off
var cell := Vector2i.ZERO
var seat := Vector2i(-1, -1)
var seen := {}          # nasty thing -> seconds this guest has had it in view
var decor := 0.0        # the joy decor gave them when they sat down
var came_in := false    # stepped through the front doorway (the party's bell rings once)
var party: Array = []   # the guests who came in together, this one included
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
var _last_stage := 0
var _age := 0.0
var helping: Node3D       # someone down after a slip (9.3) this guest is helping up
var _gross_bubble: Node3D   # the disgust stage icon, up and to one side of `_order`
var _alarm_time := 0.0    # saw someone fall: a "!" in the bubble for a moment
const DOWN_TILT := -1.45   # lying on their back after a slip, face to the sky
const DOWN_LIFT := 0.24    # so the body lies on the floor, not through it


func setup(game_, idx_: int, start: Vector2i) -> void:
	game = game_
	idx = idx_
	info = game.town.people[idx]
	var hello: Dictionary = game.town.greeting(idx)
	mood.patience = hello.patience
	mood.tolerance = info.tolerance   # shared, so training (PRD 10) carries into later visits
	mood.wealth = int(info.get("wealth", 3))
	mood.delight(hello.joy, hello.thought)
	cell = start
	position = Grid.center(start)
	goal = position
	_body = Peg.guest(info.name)
	_body.rotation.y = -PI / 2
	add_child(Peg.rigged(_body))
	# A chunky patience meter under the thought bubble, facing the camera.
	_bar = Node3D.new()
	_bar.position = Vector3(0, 1.58 * Peg.SCALE, 0)
	_bar.basis = Build.CAM_BASIS
	add_child(_bar)
	Build.flat(_bar, Icons.rect(0, 0, BAR_WIDTH + 0.07, 0.15), Build.TRIM)
	Build.flat(_bar, Icons.rect(0, 0, BAR_WIDTH, 0.08), "#6b5647", 0.003)
	_fill = Build.flat(_bar, Icons.rect(0, 0, BAR_WIDTH, 0.08), "#ffffff", 0.006)
	Build.on_top(_bar, -_bar.position.z)
	_order = Fx.bubble()
	_order.position = Vector3(0, 2.0 * Peg.SCALE - 0.1, 0)
	add_child(_order)
	# Disgust has its own smaller bubble beside it, so the request stays readable.
	_gross_bubble = Fx.bubble()
	add_child(_gross_bubble)
	# A paper name tag.
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font = Hud.lettering()
	_label.font_size = 36
	_label.outline_size = 10
	_label.pixel_size = 0.006
	_label.modulate = Color(Build.TRIM)
	_label.outline_modulate = Color(Build.PAPER)
	_label.position = Vector3(0, 1.3 * Peg.SCALE, 0)
	_label.text = info.name
	add_child(_label)


## Walks the grid to `target`, then on to `at` (somewhere in or near that cell;
## its middle if not given).
func walk_to(target: Vector2i, at: Variant = null) -> void:
	path = game.grid.find_path(cell, target)
	goal = at if at != null else Grid.center(target)


func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() > 0.0001:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-12.0 * delta))


## Moves along the path, then onto the goal. Returns true once there is nowhere
## left to go. Someone just ahead going the same way is followed, not walked
## through; anyone else in the way is stepped round.
func _advance(delta: float) -> bool:
	if hold > 0.0:
		hold -= delta
		return false
	var target := goal if path.is_empty() else Grid.center(path[0])
	if path.is_empty() and position.distance_to(target) < 0.01:
		_stand()
		return true
	var dir := (target - position).normalized()
	var other: Guest = game.seating.guest_in_way(self, dir)
	var move := dir
	if other != null:
		_waited += delta
		if other.heading.normalized().dot(dir) > 0.3 and _waited < GIVE_WAY:
			heading = dir * 0.001   # still "going that way", so whoever is behind waits too
			_body.position.y = 0.0
			_face(dir, delta)
			return false
		var side := Vector3(dir.z, 0, -dir.x)
		if (other.position - position).dot(side) > 0.0:
			side = -side
		move = (dir * 0.6 + side * 0.8).normalized()
	else:
		_waited = 0.0
	_face(dir, delta)
	var was := position
	var speed: float = SPEED * game.seating.floor_speed(position)   # slowed by dirt underfoot
	if other != null:
		position += move * speed * delta
	else:
		position = position.move_toward(target, speed * delta)
	heading = (position - was).normalized()
	_body.position.y = absf(sin(_age * 11.0)) * 0.06
	# Stepping round someone counts as passing the cell they were heading for.
	if position.distance_to(target) < (0.35 if other != null and path.size() > 1 else 0.01):
		if path.is_empty():
			_stand()
			return true
		cell = path.pop_front()
	return false


## The first of a party to step through the doorway rings the shop bell for all of them.
func _ring_bell_at_door(was_x: float) -> void:
	if came_in or was_x < Game.DOORWAY.x or position.x >= Game.DOORWAY.x:
		return
	came_in = true
	for m: Guest in party:
		if m != self and m.came_in:
			return
	game.audio.door_bell()


func _stand() -> void:
	position = goal
	heading = Vector3.ZERO
	_waited = 0.0
	_body.position.y = 0.0
	var c := Grid.to_cell(goal)
	if game.grid.in_bounds(c):
		cell = c


## Waiting to pay (PRD 11), seated or at the till.
func paying() -> bool:
	return state == "to_pay" or state == "to_till" or state == "at_till"


## Sat down and waiting: to order, or for the food they ordered.
func seated_waiting() -> bool:
	return state == "ordering" or state == "waiting"


func _sit() -> void:
	state = "ordering"
	game.audio.sfx("sit")
	mood.patience = minf(1.0, mood.patience + 0.3)
	_body.create_tween().tween_property(_body, "position:y", SEAT_HEIGHT, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	game.seating.on_seated(self)


## The chef has written down what they want. Now they wait for the food, or,
## having found nothing they would eat, keep their friends company.
func take_order(what: Dictionary) -> void:
	order = what
	state = "company" if int(what.get("ticket", -1)) < 0 else "waiting"


## The menu items they ordered, main first.
func ordered_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in Menu.COURSES:
		if order.has(c) and not (order[c] as Dictionary).is_empty():
			out.append(order[c])
	return out


## What the bubble shows while they wait: the main, or the drink if that is all.
func want_icon() -> String:
	var items := ordered_items()
	return "food" if items.is_empty() else Icons.dish_id(items[0])


## How long this guest eats, once served: longer when they are comfortable.
var eat_time := EAT_TIME
var perfect_streak := 0   # their tray's place in a run of perfect ones: raises their tip


## Happiness is fixed here, as the food arrives and they take the first taste: it sets
## the stay and the bill (GuestMood.comfort). Returns the thought it prompts ("" for none).
func start_eating(quality: float, tray: Tray = null) -> String:
	mood.taste(quality)
	var said := mood.settle_comfort(idx)
	eat_time = EAT_TIME * GuestMood.stay_scale(mood.served_comfort)
	if quality > 0.95:
		_heart_time = 2.5
	state = "eating"
	timer = eat_time
	_meal_tray = tray
	_set_meal("tray", quality)
	var tw := _body.create_tween()
	tw.tween_property(_body, "position:y", SEAT_HEIGHT + 0.3, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position:y", SEAT_HEIGHT, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	return said


## The plates and cups served so far, set down in front of them while they wait for the rest.
func show_served(t: Tray) -> void:
	_meal_tray = t
	_set_meal("tray", 1.0)


## Takes what is in front of them off the table (they left, or finished).
func clear_meal() -> void:
	if _meal:
		_meal.queue_free()
		_meal = null


func _set_meal(kind: String, quality: float) -> void:
	if _meal:
		_meal.queue_free()
	_meal_kind = kind
	var to_table := (Grid.center(table.cell) - position).normalized()
	_meal = BuildFood.meal(_meal_tray, kind == "tray_bitten") if kind.begins_with("tray") else BuildFood.item(kind, quality)
	_meal.position = to_table * 0.5 + Vector3(0, 0.74, 0)
	_meal.rotation.y = atan2(to_table.x, to_table.z)
	add_child(_meal)


func stand_up() -> void:
	state = "leaving"
	if _meal:
		_meal.queue_free()
		_meal = null


## Slipped on the floor (9.3): down on the cell, dazed. FloorDirt keeps the time.
func fall() -> void:
	heading = Vector3.ZERO
	_body.create_tween().tween_property(_body, "rotation:x", DOWN_TILT, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_body.position = Vector3(0, DOWN_LIFT, 0)


func rise() -> void:
	_body.position = Vector3.ZERO
	_label.position = Vector3(0, _label.position.y, 0)
	_body.create_tween().tween_property(_body, "rotation:x", 0.0, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Saw someone slip within a cell: a smaller hit and a thought.
func witness_fall() -> void:
	mood.patience = maxf(0.0, mood.patience - FloorMess.WITNESS_PATIENCE)
	mood.delight(-FloorMess.WITNESS_JOY, FloorMess.WITNESS_THOUGHT)
	_alarm_time = 2.5


## Lying on the floor: no walking, waiting, eating or bars; just the dazed face.
func _lie(delta: float) -> void:
	_bar.visible = false
	_body.set_face("dazed")
	_body.pose = "idle"
	_body.position.x = 0.0
	Fx.set_bubble(_order, "")
	Fx.set_bubble(_gross_bubble, "")
	_label.position = FloorDirt.lying_dir(self) * 1.0 + Vector3(0, 1.75, 0)   # over the head
	_alarm_time -= delta


## Helping someone up: over to their side, then crouched with both hands out.
func _help(delta: float) -> void:
	var spot := FloorDirt.help_spot(helping)
	if position.distance_to(spot) > 0.02:
		position = position.move_toward(spot, SPEED * 0.5 * delta)
		_body.position.y = absf(sin(_age * 11.0)) * 0.04
	else:
		_body.position.y = 0.0
	var to := helping.position + FloorDirt.lying_dir(helping) * 0.55 - position
	to.y = 0.0
	_face(to, delta)
	_body.pose = "help"
	_body.rotation.x = lerpf(_body.rotation.x, 0.35, 1.0 - exp(-8.0 * delta))
	_bar.visible = false
	_alarm_time -= delta
	Fx.set_bubble(_order, "warning" if _alarm_time > 0.0 else "")
	Fx.set_bubble(_gross_bubble, "")
	_order.position.y = 2.72
	_label.position.y = 3.24 if _alarm_time > 0.0 else 2.1


func tick(delta: float) -> void:
	_age += delta
	if game.floor_dirt.is_down(self):
		_lie(delta)
		return
	if helping != null:
		if is_instance_valid(helping) and game.floor_dirt.is_down(helping):
			_help(delta)
			return
		helping = null
	match state:
		"queue":
			_advance(delta)
			mood.wait(delta, QUEUE_PATIENCE)
			if mood.walked_out():
				game.paying.walk_out(self)
		"to_seat":
			var was_x := position.x
			var done := _advance(delta)
			_ring_bell_at_door(was_x)
			if done:
				_sit()
		"ordering", "waiting":
			_face(Grid.center(table.cell) - position, delta)
			mood.wait(delta, game.day.table_patience() * (game.ORDER_PATIENCE_SCALE if state == "ordering" else 1.0))
			game.seating.apply_surroundings(self, delta)
			if mood.walked_out():
				game.paying.walk_out(self)
		"eating":
			timer -= delta
			# Lean in for a bite, and the burger shrinks as it is eaten.
			_body.rotation.x = maxf(0.0, sin(_age * 7.0)) * 0.22
			if timer < eat_time * 0.55 and _meal_kind == "tray":
				_set_meal("tray_bitten", mood.savour)
			game.seating.apply_surroundings(self, delta)
			if timer <= 0.0:
				game.serving.finish_meal(self)
		"chatting":   # the meal is done: a moment's chat (alone, they just sit back)
			_face(Grid.center(table.cell) - position, delta)
			timer -= delta
			game.seating.apply_surroundings(self, delta)
			if timer <= 0.0:
				state = "to_pay"
		"to_pay", "at_till":   # ready to pay: the party's patience runs once the table is ready
			if state == "to_pay":
				_face(Grid.center(table.cell) - position, delta)
				game.seating.apply_surroundings(self, delta)
			else:
				_advance(delta)
				_face(Grid.center(game.paying.till_cell()) - position, delta)
			if game.paying.ready_to_pay(table):
				mood.wait_to_pay(delta, game.day.table_patience(), state == "to_pay")
				if mood.skipped_bill:
					game.paying.leave_unpaid(table, self)
		"to_till":
			if _advance(delta):
				state = "at_till"
			if game.paying.ready_to_pay(table):
				mood.wait_to_pay(delta, game.day.table_patience(), false)
				if mood.skipped_bill:
					game.paying.leave_unpaid(table, self)
		"company":   # nothing to eat: they sit with friends and go when the friends go
			_face(Grid.center(table.cell) - position, delta)
			var staying := party.any(func(m) -> bool:
				return is_instance_valid(m) and m != self and m.state != "leaving" and m.state != "company")
			if not staying:
				game.paying.leave_with_friends(self)
		"browse":
			if _advance(delta):
				_face(Vector3(-1, 0, 0), delta)   # towards the window and the menu
				if timer == BROWSE_TIME:
					game.seating.read_board(self)
				timer -= delta
				if timer <= 0.0:
					game.paying.leave_with_friends(self)
		"leaving":
			if _advance(delta):
				game.paying.remove_guest(self)
				return
	_refresh(delta)


func _refresh(delta: float) -> void:
	var p := mood.patience
	var on_bill: bool = paying() and game.paying.ready_to_pay(table)
	if on_bill:
		p = game.paying.pay_patience(table)   # the party's lowest, so no bar reads full while one is about to snap
	_bar.visible = state == "queue" or seated_waiting() or state == "to_seat" or on_bill
	_fill.scale.x = maxf(p, 0.001)
	_fill.position.x = (p - 1.0) * BAR_WIDTH / 2.0
	var shade := snappedf(p, 0.1)  # few distinct colours, so materials stay cached
	var col := Color(Build.DANGER).lerp(Color(Build.WARN), clampf(shade * 2.0, 0, 1)).lerp(Color(Build.GOOD), clampf(shade * 2.0 - 1.0, 0, 1))
	_fill.material_override = Build.overlay_mat(col, 6)
	# Impatient guests shake a little.
	_body.position.x = sin(_age * 40.0) * 0.02 if (_bar.visible and p < 0.25) else 0.0
	_body.set_face(mood.expression(state == "eating", stormed))
	_body.pose = "eat" if state == "eating" else ("tap" if seated_waiting() and p < 0.35 else \
		("wave" if (calling and state == "to_pay") else "idle"))
	# Bored guests slump; guests about to snap lean in; disgust pitches them back.
	var lean := 0.0
	if seated_waiting():
		lean = -0.2 if mood.disgust_level() >= 2 else (0.14 if p < 0.25 else (0.07 if p < 0.5 else 0.0))
	elif state == "leaving" and stormed:
		lean = 0.3
	if state != "eating":
		_body.rotation.x = lerpf(_body.rotation.x, lean, 1.0 - exp(-8.0 * delta))
	# One bold icon says what is on their mind (sheet 13).
	# Disgust shows only once it has crossed a threshold: a stage icon pops up when
	# they reach a new stage, and comes back every few seconds while it lasts.
	_alarm_time -= delta
	var stage := mood.disgust_level()
	if stage > _last_stage:
		_gross_time = 3.0
	_last_stage = stage
	_gross_time -= delta
	_heart_time -= delta
	var want := ""
	if _alarm_time > 0.0:
		want = "warning"   # someone just fell beside them
	elif state == "ordering" and not orders_nothing:
		want = "order"   # a notepad: come and take my order (not from one who wants nothing)
	elif state == "waiting":
		want = want_icon()
	elif state == "at_till" or state == "to_till" or (state == "to_pay" and calling):
		want = "bill"   # PRD 11: the call; at the till it is up all the time
	elif state == "chatting" and party.size() > 1 and fmod(_age + idx * 0.7, 2.4) < 1.4:
		want = "chat"
	elif state == "browse" and no_table:
		want = "no_table"
	elif state == "queue" and p < 0.6:
		want = "zzz"
	elif _heart_time > 0.0:
		want = "heart"
	Fx.set_bubble(_order, want)
	_order.position.y = 2.72 + sin(_age * 3.0) * 0.03   # clear of the patience bar below it
	var gross := ""
	if stage > 0 and (seated_waiting() or state == "eating") and (_gross_time > 0.0 or fmod(_age, 7.0) < 2.0):
		gross = GuestMood.DISGUST_ICONS[stage]
	Fx.set_bubble(_gross_bubble, gross, 0.3 if want == "" else 0.2)
	# Beside the main bubble (up and to the camera's right), or in its place when that is empty.
	_gross_bubble.position = _order.position + (Build.CAM_BASIS.x * 0.62 + Build.CAM_BASIS.y * 0.3 if want != "" else Vector3.ZERO)
	if gross != "" and want == "":
		want = gross   # the name tag rides above whichever bubble is up
	_label.position.y = 3.24 if want != "" else (2.32 if _bar.visible else 2.1)
