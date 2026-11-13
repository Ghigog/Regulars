class_name Station
extends Node3D
## One piece of furniture occupying a grid cell.

const COOK_TIME := 4.0     # raw until here
const PERFECT_END := 7.5   # juicy until here, then it dries out
const BURN_TIME := 12.0
const NEARLY_TIME := 2.4   # the raw patty starts to colour
const DIAL_SWEEP := 150.0  # degrees either side of straight up

var type := ""
var cell := Vector2i.ZERO
var tier := 1
var facing := 0       # quarter turns; 0 puts the front toward +z
var lamp: OmniLight3D # a table's lamp light, owned by the game
var item := ""        # what is sitting on a counter or stove
var quality := 1.0    # how well cooked that item is (0..1)
var cook := 0.0       # seconds the stove's patty has been on the heat
var count := 0        # clean plates in a plate stack
var dirty := 0        # dirty plates left on a table
var dirty_age := 0.0  # seconds those plates have been sitting there
var seats: Array[Vector2i] = []
var _item_node: Node3D
var _stack: Node3D
var _bar: Node3D
var _needle: Node3D
var _ring: MeshInstance3D
var _shown_look := ""
var _vis: Node3D
var _fx := {}


static func quality_at(t: float) -> float:
	if t < COOK_TIME or t >= BURN_TIME:
		return 0.0
	if t <= PERFECT_END:
		return 1.0
	return lerpf(1.0, 0.4, (t - PERFECT_END) / (BURN_TIME - PERFECT_END))


static func stage_at(t: float) -> String:
	if t < COOK_TIME:
		return "raw_patty"
	return "cooked_patty" if t < BURN_TIME else "burnt_patty"


## Which of the five patty looks a patty has after `t` seconds on the heat.
static func patty_look(t: float) -> String:
	if t < NEARLY_TIME:
		return "raw"
	if t < COOK_TIME:
		return "nearly"
	if t <= PERFECT_END:
		return "perfect"
	return "dry" if t < BURN_TIME else "burnt"


## `facing` 0 puts the front toward +z; 1 turns it to face +x (for the left wall).
func setup(type_: String, cell_: Vector2i, tier_: int, facing := 0) -> void:
	type = type_
	cell = cell_
	tier = tier_
	_vis = Node3D.new()
	add_child(_vis)
	Build.station(_vis, type, tier)
	place_at(cell_, facing)
	if type == "plates":
		count = 4
	if type == "stove":
		_ring = _vis.get_node_or_null("ring")
		_make_cook_bar()
		_make_smoke()
	refresh()


func _show_item(kind: String) -> void:
	if _item_node:
		_item_node.queue_free()
		_item_node = null
	_shown_look = ""
	if kind != "":
		var on_heat := type == "stove" and kind.ends_with("patty")
		_shown_look = patty_look(cook) if on_heat else Build.look_for(kind, quality)
		_item_node = Build.item(kind, quality, _shown_look)
		_item_node.position = Vector3(Build.PAN.x, 0.93, Build.PAN.z) if type == "stove" else Vector3(0, 0.9, 0)
		add_child(_item_node)
		_item_node.scale = Vector3.ONE * 0.4
		_item_node.create_tween().tween_property(_item_node, "scale", Vector3.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_item(kind: String, q := 1.0) -> void:
	item = kind
	quality = q
	if type == "stove":
		cook = {"cooked_patty": PERFECT_END, "burnt_patty": BURN_TIME}.get(kind, 0.0)
	_show_item(kind)
	if type == "stove":
		_update_cooking_visuals()


## Quality of whatever is here right now; a stove reads it off the timer.
func current_quality() -> float:
	return quality_at(cook) if type == "stove" else quality


## Advances cooking. Returns the new stage name when the meat changes, else "".
func tick_cooking(delta: float) -> String:
	if type != "stove" or (item != "raw_patty" and item != "cooked_patty"):
		return ""
	cook += delta * tier
	_update_cooking_visuals()
	var stage := stage_at(cook)
	if stage == item:
		if patty_look(cook) != _shown_look:
			_show_item(item)
			_update_cooking_visuals()
		return ""
	item = stage
	_show_item(stage)
	_update_cooking_visuals()
	return stage


static func _dial_angle(t: float) -> float:
	return lerpf(-DIAL_SWEEP, DIAL_SWEEP, clampf(t / BURN_TIME, 0.0, 1.0))


## The doneness dial (sheet 9): a chunky ring gauge that faces the camera. Cream
## warm-up arc, green sweet spot with a star, then yellow shrinking into red.
func _make_cook_bar() -> void:
	_bar = Node3D.new()
	_bar.position = Vector3(0, 1.72, 0)
	_bar.basis = Build.CAM_BASIS
	add_child(_bar)
	Build.flat(_bar, Build.disc_pts(0.37, Vector2.ZERO, 32), Build.TRIM, 0.0)
	Build.flat(_bar, Build.disc_pts(0.335, Vector2.ZERO, 32), "#5a4636", 0.002)
	var a_cook := _dial_angle(COOK_TIME)
	var a_end := _dial_angle(PERFECT_END)
	var a_mid := _dial_angle((PERFECT_END + BURN_TIME) / 2.0)
	Build.flat(_bar, Build.arc_pts(0.2, 0.27, -DIAL_SWEEP, a_cook), Build.PAPER, 0.004)
	Build.flat(_bar, Build.arc_pts(0.17, 0.31, a_cook, a_end), Build.GOOD, 0.004)
	Build.flat(_bar, Build.arc_pts(0.17, 0.31, a_end, a_mid, 0.19, 0.28), Build.WARN, 0.004)
	Build.flat(_bar, Build.arc_pts(0.19, 0.28, a_mid, DIAL_SWEEP, 0.21, 0.25), Build.DANGER, 0.004)
	var a_star := deg_to_rad((a_cook + a_end) / 2.0)
	Build.flat(_bar, Build.star_pts(0.085, 5, 0.5, Vector2(sin(a_star), cos(a_star)) * 0.24), "#ffffff", 0.006)
	_needle = Node3D.new()
	_needle.position.z = 0.008
	_bar.add_child(_needle)
	Build.flat(_needle, PackedVector2Array([Vector2(-0.035, -0.05), Vector2(-0.022, 0.27), Vector2(0, 0.3), Vector2(0.022, 0.27), Vector2(0.035, -0.05)]), "#ffffff")
	Build.flat(_needle, Build.disc_pts(0.065), Build.TRIM, 0.002)
	Build.flat(_needle, Build.disc_pts(0.03), "#ffffff", 0.004)
	_bar.visible = false


## The heat ladder (sheet 13): off-white steam, warm grey smoke as the meat
## dries, charcoal smoke with red sparks and toy flames once it burns.
func _make_smoke() -> void:
	for id: String in ["steam", "spatter", "smoke", "burn", "flame"]:
		var at := Vector3(0, 1.0 if id == "spatter" or id == "flame" else 1.12, 0)
		var fx := Fx.play(self, id, at, 0.26 if id == "spatter" or id == "flame" else 0.34, true)
		fx.fps = 9.0 if id == "flame" or id == "spatter" else 5.0
		fx.visible = false
		_fx[id] = fx


func is_cooking() -> bool:
	return type == "stove" and (item == "raw_patty" or item == "cooked_patty")


func _update_cooking_visuals() -> void:
	_bar.visible = is_cooking()
	_needle.rotation.z = -deg_to_rad(_dial_angle(cook))
	if _ring:
		_ring.material_override = Build.mat(Color("#ff8a3c") if is_cooking() else Color(Build.STEEL_DARK), 1.6 if is_cooking() else 0.0)
	var look := _shown_look if item.ends_with("patty") else ""
	_fx.steam.visible = look == "raw" or look == "nearly" or look == "perfect"
	_fx.spatter.visible = look == "nearly" or look == "perfect"
	_fx.smoke.visible = look == "dry"
	_fx.burn.visible = look == "burnt"
	_fx.flame.visible = look == "burnt"


## Redraws plate stacks and dirty dishes.
## Where a piece's seats are: either side of a table, turning with it.
static func seats_for(type_: String, cell_: Vector2i, facing_: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if type_ == "table":
		var side := Vector2i(1, 0) if facing_ % 2 == 0 else Vector2i(0, 1)
		out = [cell_ - side, cell_ + side]
	return out


## Stands the piece on a cell, turned `facing_` quarter turns.
func place_at(cell_: Vector2i, facing_: int) -> void:
	cell = cell_
	facing = posmod(facing_, 4)
	position = Grid.center(cell)
	_vis.rotation.y = facing * PI / 2
	seats = seats_for(type, cell, facing)
	if lamp:
		lamp.position = position + Vector3(0, 1.0, 0)


func refresh() -> void:
	if _stack:
		_stack.queue_free()
	_stack = Node3D.new()
	add_child(_stack)
	if type == "plates":
		for i in count:
			var plate := Build.item("plate")
			plate.position = Vector3(0, 0.916 + i * 0.032, 0)
			_stack.add_child(plate)
	elif type == "table":
		for i in dirty:
			var d := Build.item("dirty_plate")
			d.position = Vector3(-0.25 + i * 0.5, 0.74, 0.3)
			_stack.add_child(d)


## A little show when the chef uses the station: the fridge door swings open.
func used() -> void:
	var door := _vis.get_node_or_null("door") as Node3D
	if door:
		var tw := door.create_tween()
		tw.tween_property(door, "rotation:y", -1.9, 0.16).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.35)
		tw.tween_property(door, "rotation:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
