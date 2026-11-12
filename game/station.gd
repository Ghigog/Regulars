class_name Station
extends Node3D
## One piece of furniture occupying a grid cell.

const COOK_TIME := 4.0     # raw until here
const PERFECT_END := 7.5   # juicy until here, then it dries out
const BURN_TIME := 12.0
const BAR_WIDTH := 0.9

var type := ""
var cell := Vector2i.ZERO
var tier := 1
var item := ""        # what is sitting on a counter or stove
var quality := 1.0    # how well cooked that item is (0..1)
var cook := 0.0       # seconds the stove's patty has been on the heat
var count := 0        # clean plates in a plate stack
var dirty := 0        # dirty plates left on a table
var seats: Array[Vector2i] = []
var _item_node: Node3D
var _stack: Node3D
var _bar: Node3D
var _needle: MeshInstance3D
var _smoke: CPUParticles3D
var _smoke_mat: StandardMaterial3D


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


func setup(type_: String, cell_: Vector2i, tier_: int) -> void:
	type = type_
	cell = cell_
	tier = tier_
	position = Grid.center(cell)
	Build.station(self, type, tier)
	if type == "table":
		seats = [cell + Vector2i(-1, 0), cell + Vector2i(1, 0)]
	if type == "plates":
		count = 4
	if type == "stove":
		_make_cook_bar()
		_make_smoke()
	refresh()


func _show_item(kind: String) -> void:
	if _item_node:
		_item_node.queue_free()
		_item_node = null
	if kind != "":
		_item_node = Build.item(kind)
		_item_node.position = Vector3(0, 0.9, 0)
		add_child(_item_node)
		_item_node.scale = Vector3.ONE * 0.4
		_item_node.create_tween().tween_property(_item_node, "scale", Vector3.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_item(kind: String, q := 1.0) -> void:
	item = kind
	quality = q
	_show_item(kind)
	if type == "stove":
		cook = {"cooked_patty": PERFECT_END, "burnt_patty": BURN_TIME}.get(kind, 0.0)
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
		return ""
	item = stage
	_show_item(stage)
	return stage


func _make_cook_bar() -> void:
	_bar = Node3D.new()
	_bar.position = Vector3(0, 1.75, 0)
	_bar.rotation.y = PI / 4  # face the fixed camera
	_bar.scale = Vector3.ONE * 1.25
	add_child(_bar)
	Build.box(_bar, Vector3(0, -0.03, -0.02), Vector3(BAR_WIDTH + 0.08, 0.2, 0.02), "#3a2c22")
	var spans := [[0.0, COOK_TIME, "#e58a8a"], [COOK_TIME, PERFECT_END, "#5fd38d"], [PERFECT_END, BURN_TIME, "#e9a23b"]]
	for s: Array in spans:
		var w: float = (s[1] - s[0]) / BURN_TIME * BAR_WIDTH
		var x: float = ((s[0] + s[1]) / 2.0 / BURN_TIME - 0.5) * BAR_WIDTH
		Build.box(_bar, Vector3(x, 0, 0), Vector3(w, 0.14, 0.02), s[2], 0.4)
	_needle = Build.box(_bar, Vector3(0, -0.05, 0.02), Vector3(0.05, 0.24, 0.03), "#ffffff", 1.0)
	_bar.visible = false


func _make_smoke() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.position = Vector3(0, 1.0, 0)
	_smoke.amount = 10
	_smoke.lifetime = 1.1
	_smoke.direction = Vector3.UP
	_smoke.spread = 18.0
	_smoke.gravity = Vector3(0, 0.5, 0)
	_smoke.initial_velocity_min = 0.3
	_smoke.initial_velocity_max = 0.6
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.5
	var puff := SphereMesh.new()
	puff.radius = 0.07
	puff.height = 0.14
	_smoke_mat = StandardMaterial3D.new()
	_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = _smoke_mat
	_smoke.mesh = puff
	_smoke.emitting = false
	add_child(_smoke)


func is_cooking() -> bool:
	return type == "stove" and (item == "raw_patty" or item == "cooked_patty")


func _update_cooking_visuals() -> void:
	_bar.visible = is_cooking()
	_needle.position.x = (clampf(cook / BURN_TIME, 0.0, 1.0) - 0.5) * BAR_WIDTH
	_smoke.emitting = item != "" and item.ends_with("patty")
	var danger := clampf((cook - PERFECT_END) / (BURN_TIME - PERFECT_END), 0.0, 1.0)
	_smoke_mat.albedo_color = Color(1, 1, 1, 0.45).lerp(Color(0.12, 0.1, 0.1, 0.8), danger)


## Redraws plate stacks and dirty dishes.
func refresh() -> void:
	if _stack:
		_stack.queue_free()
	_stack = Node3D.new()
	add_child(_stack)
	if type == "plates":
		for i in count:
			Build.cyl(_stack, Vector3(0, 0.88 + i * 0.04, 0), 0.2, 0.03, "#ffffff")
	elif type == "table":
		for i in dirty:
			var d := Build.item("dirty_plate")
			d.position = Vector3(-0.25 + i * 0.25, 0.7, 0.25)
			_stack.add_child(d)
