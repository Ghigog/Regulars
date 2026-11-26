class_name GameTidy
extends RefCounted
## Nightfall tidy: when the day ends the kitchen puts its clean plates, cups and trays
## back on their stacks and sends every piece of food (plated or not) into the nearest
## bin as scrap. The state changes at once (`tidy_up`); the build phase opening plays
## what moved (`play`): plates slide back one by one, food hops into the bin.

const GAP := 0.15      # seconds between one move and the next
const FLIGHT := 0.4    # seconds a plate or bit of food is in the air

var game: Game
var _moves: Array[Dictionary] = []   # {kind: "plate" or "food", look: Node3D kind, from: Vector3, to: Station}


func _init(game_: Game) -> void:
	game = game_


## Tidies every station and every chef's hands. Dirty plates stay: they are night-cleaning mess.
func tidy_up() -> void:
	_moves.clear()
	for st: Station in game.stations.values():
		if st.item == "dish":
			if st.dish == null or st.dish.dirty:
				continue
			_tidy_dish(st.dish, st.global_position)
			st.clear_food()
		elif st.has_leftover_food():
			_to_bin(st.global_position, st.item)
			st.clear_food()
	for ch: Player in game.chefs:
		if ch.held == "dishes":
			for d: Dish in ch.dishes:
				_tidy_dish(d, ch.global_position)
			if ch.on_tray:
				_to_stack("tray_stack", ch.global_position)
			ch.set_held("")
		elif ch.held == "tray":
			_to_stack("tray_stack", ch.global_position)
			ch.set_held("")
		elif not Tray.parse(ch.held).is_empty():
			_to_bin(ch.global_position, ch.held)
			ch.set_held("")


func _tidy_dish(d: Dish, from: Vector3) -> void:
	if not d.is_empty():
		_to_bin(from, "dish")
	if d.vessel == Dish.PLATE:
		_to_stack("dish_rack", from)
	elif d.vessel == Dish.CUP:
		_to_stack("cups", from)


func _nearest(type: String, from: Vector3) -> Station:
	var best: Station = null
	for st: Station in game.menu_stock.stations_of(type):
		if type == "dish_rack" and st.count >= Station.RACK_CAPACITY:
			continue   # a full rack takes no more
		if best == null or st.global_position.distance_squared_to(from) < best.global_position.distance_squared_to(from):
			best = st
	return best


func _to_stack(type: String, from: Vector3) -> void:
	var st := _nearest(type, from)
	if st == null:
		return
	st.count += 1
	st.refresh()
	_moves.append({"kind": "plate" if type == "dish_rack" else type, "from": from, "to": st})


func _to_bin(from: Vector3, look: String) -> void:
	var bin := _nearest("bin", from)
	if bin == null:
		return   # no bin in the room: the food is simply cleared
	bin.count += 1   # may overflow past the limit
	bin.refresh()
	_moves.append({"kind": "food", "look": look, "from": from, "to": bin})


## Plays what `tidy_up` moved. Every tween belongs to the flying piece or the bin, not to this part.
func play() -> void:
	var i := 0
	for m: Dictionary in _moves:
		var to: Station = m.to
		if is_instance_valid(to):
			_fly(m, to, i * GAP)
		i += 1
	_moves.clear()


func _fly(m: Dictionary, to: Station, delay: float) -> void:
	var food: bool = m.kind == "food"
	var piece: Node3D
	if food:
		piece = BuildFood.item("raw:patty") if m.look == "dish" else BuildFood.item(str(m.look))
	else:
		piece = BuildFood.carried([Dish.make(Dish.CUP if m.kind == "cups" else Dish.PLATE)], false)
	piece.top_level = true
	piece.visible = false
	game.add_child(piece)
	var from: Vector3 = m.from + Vector3(0, 0.9, 0)
	var land: Vector3 = to.global_position + Vector3(0, 0.9 if food else 0.7, 0)
	piece.global_position = from
	var tw := piece.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: piece.visible = true)
	tw.tween_method(func(t: float) -> void:
		var p := from.lerp(land, t)
		if food:
			p.y += sin(t * PI) * 0.9   # the hop
		piece.global_position = p, 0.0, 1.0, FLIGHT) \
		.set_trans(Tween.TRANS_SINE if food else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		piece.queue_free()
		if is_instance_valid(game):
			game.audio.sfx("putdown" if food else "pickup")
		if food and is_instance_valid(to):
			_bounce_lid(to))


func _bounce_lid(bin: Station) -> void:
	var tw := bin.create_tween()
	tw.tween_property(bin, "scale", Vector3(1.0, 0.88, 1.0), 0.07)
	tw.tween_property(bin, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
