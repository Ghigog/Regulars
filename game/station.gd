class_name Station
extends Node3D
## One piece of furniture occupying a grid cell.

const COOK_TIME := Prep.GRILL_DONE       # raw until here
const PERFECT_END := Prep.GRILL_PERFECT  # juicy until here, then it dries out
const BURN_TIME := Prep.GRILL_BURN
const NEARLY_TIME := Prep.GRILL_NEARLY   # the raw patty starts to colour
const TRAYS := 4           # trays in a new tray stack
const DIAL_SWEEP := 150.0  # degrees either side of straight up
const SINK_PILED := 3      # this many plates soaking and the washing-up shows (and bothers guests)
const BIN_HOLDS := 4       # scraps a bin takes before it overflows

var type := ""
var cell := Vector2i.ZERO
var tier := 1
var facing := 0       # quarter turns; 0 puts the front toward +z
var lamp: OmniLight3D # a table's lamp light, owned by the game
var item := ""        # what is sitting on a counter or stove: an ingredient kind ("raw:patty") or "tray"
var quality := 1.0    # how well prepped that item is (0..1)
var tray: Tray        # the tray on a counter or the pass, when item is "tray"
var tray_tag := ""    # the colour of that tray's ticket slip ("" for none)
var stocked := true   # an ingredient station: stocked for tomorrow (switched at night)
var cook := 0.0       # seconds the piece has been on the heat (stove, fryer, pot)
var rest := 0.0       # a fryer: seconds left draining on the rack before it can be picked up
var result := ""      # a fryer: how the piece on the rack came out (good, plain)
var widget: PrepWidget   # the gauge over a pot or fryer rack, or a press-based minigame
var count := 0        # clean trays in a tray stack; scraps in a bin
var dirty := 0        # dirty trays left on a table, or soaking in a sink
var dirty_age := 0.0  # seconds this piece has been messy (see `messy`)
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
	return float(Prep.grill(t).quality)


## How a piece on the heat shows after `t` seconds: raw, prepped or burnt.
static func stage_at(t: float) -> String:
	if t < COOK_TIME:
		return "raw"
	return "prep" if t < BURN_TIME else "burnt"


## The ingredient sitting here ("" if none or a tray).
func ingredient() -> String:
	var p := Tray.parse(item)
	return p.id if not p.is_empty() else ""


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
	if type == "trays":
		count = TRAYS
	if type == "stove" or type == "fryer":
		_ring = _vis.get_node_or_null("ring")
		_make_cook_bar()
		_make_smoke()
	if type == "fryer" or type == "pot":
		show_widget("rack" if type == "fryer" else "boil")
		widget.visible = false
	refresh()


func _show_item(kind: String) -> void:
	if _item_node:
		_item_node.queue_free()
		_item_node = null
	_shown_look = ""
	if kind == "tray" and tray != null:
		_item_node = Build.tray(tray, tray_tag)
		_item_node.position = Vector3(0, 0.9, 0)
		add_child(_item_node)
	elif kind != "":
		var on_heat := type == "stove"
		_shown_look = patty_look(cook) if on_heat else Build.look_for(kind, quality)
		_item_node = Build.item(kind, quality, _shown_look)
		match type:
			"stove":
				_item_node.position = Vector3(Build.PAN.x, 0.93, Build.PAN.z)
			"fryer":
				_item_node.position = Vector3(0.28, 0.93, 0) if on_rack() else Vector3(-0.15, 0.86, 0)
			"pot":
				_item_node.position = Vector3(0, 1.05, 0)
			_:
				_item_node.position = Vector3(0, 0.9, 0)
		add_child(_item_node)
		_item_node.scale = Vector3.ONE * 0.4
		_item_node.create_tween().tween_property(_item_node, "scale", Vector3.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_item(kind: String, q := 1.0) -> void:
	item = kind
	quality = q
	if kind != "tray":
		tray = null
	if type == "stove" or type == "fryer" or type == "pot":
		var state: String = Tray.parse(kind).get("state", "")
		cook = {"prep": _times()[2], "burnt": _times()[3]}.get(state, 0.0) if type != "pot" else (Prep.BOIL_TIME if state == "prep" else 0.0)
		rest = 0.0
		result = ""
	_show_item(kind)
	if type == "stove" or type == "fryer" or type == "pot":
		_update_cooking_visuals()


## Puts a tray down here (a counter or the pass).
func set_tray(t: Tray, tag := "") -> void:
	tray = t
	tray_tag = tag
	item = "tray"
	_show_item("tray")


## Redraws the tray after something was added or it changed ticket.
func show_tray() -> void:
	if item == "tray":
		_show_item("tray")


## Quality of whatever is here right now; a stove reads it off the timer.
func current_quality() -> float:
	if type == "stove":
		return quality_at(cook)
	if type == "pot":
		return float(Prep.boil(cook).quality)
	return quality


## [raw until, done from, good until, burnt at] for this heat tool.
func _times() -> Array:
	if type == "fryer":
		return [Prep.FRY_MIN, Prep.FRY_GOOD, Prep.FRY_LATE, Prep.FRY_BURN]
	return [NEARLY_TIME, COOK_TIME, PERFECT_END, BURN_TIME]


## A fryer's basket is lifted: the piece drains on the rack before it can be taken.
func lift_to_rack(kind: String, q: float, res: String) -> void:
	item = kind
	quality = q
	result = res
	rest = Prep.FRY_REST
	cook = 0.0
	_show_item(kind)
	_update_cooking_visuals()


## Whether a fryer's piece has been lifted onto the drain rack.
func on_rack() -> bool:
	return type == "fryer" and result != ""


## Whether a fryer's piece is still draining on the rack.
func draining() -> bool:
	return on_rack() and rest > 0.0


## Advances cooking. Returns the new stage ("prep" or "burnt") when it changes,
## "rested" when fried food has drained, else "".
func tick_cooking(delta: float) -> String:
	if on_rack():
		if rest <= 0.0:
			return ""
		rest -= delta
		_update_cooking_visuals()
		return "rested" if rest <= 0.0 else ""
	if not is_cooking():
		return ""
	cook += delta * tier
	if type == "pot":
		_update_cooking_visuals()
		if cook >= Prep.BOIL_TIME:
			item = Tray.kind("prep", Tray.parse(item).id)
			_show_item(item)
			return "prep"
		return ""
	_update_cooking_visuals()
	var p := Tray.parse(item)
	var stage := stage_at(cook) if type == "stove" else ("raw" if cook < Prep.FRY_GOOD else ("prep" if cook < Prep.FRY_BURN else "burnt"))
	if stage == p.state:
		if patty_look(cook) != _shown_look:
			_show_item(item)
			_update_cooking_visuals()
		return ""
	item = Tray.kind(stage, p.id)
	_show_item(item)
	_update_cooking_visuals()
	return stage


func _dial_angle(t: float) -> float:
	return lerpf(-DIAL_SWEEP, DIAL_SWEEP, clampf(t / _times()[3], 0.0, 1.0))


## The doneness dial (sheet 9): a chunky ring gauge that faces the camera. Cream
## warm-up arc, green sweet spot with a star, then yellow shrinking into red.
func _make_cook_bar() -> void:
	_bar = Node3D.new()
	_bar.position = Vector3(0, 1.72, 0)
	_bar.basis = Build.CAM_BASIS
	add_child(_bar)
	Build.flat(_bar, Build.disc_pts(0.37, Vector2.ZERO, 32), Build.TRIM, 0.0)
	Build.flat(_bar, Build.disc_pts(0.335, Vector2.ZERO, 32), "#5a4636", 0.002)
	var tt := _times()
	var a_cook := _dial_angle(tt[1])
	var a_end := _dial_angle(tt[2])
	var a_mid := _dial_angle((tt[2] + tt[3]) / 2.0)
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
	Build.on_top(_bar, -_bar.position.z)  # never hidden behind the hood or a wall


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
	if item == "" or item == "tray" or item.begins_with("burnt"):
		return false
	match type:
		"stove":
			return true
		"fryer":
			return not on_rack()
		"pot":
			return item.begins_with("raw")
	return false


## Shows a minigame gauge over this piece (replacing any other).
func show_widget(kind: String) -> PrepWidget:
	if widget != null and widget.kind == kind:
		widget.visible = true
		return widget
	if widget != null:
		widget.queue_free()
	widget = PrepWidget.make(kind)
	widget.position = Vector3(0, 1.72, 0)
	add_child(widget)
	return widget


func hide_widget() -> void:
	if widget != null and type != "fryer" and type != "pot":
		widget.queue_free()
		widget = null
	elif widget != null:
		widget.visible = false


func _update_cooking_visuals() -> void:
	if type == "pot":
		widget.visible = item != ""
		widget.show_state({"t": cook / Prep.BOIL_TIME, "done": item.begins_with("prep")})
		return
	if type == "fryer":
		widget.visible = rest > 0.0
		widget.show_state({"left": rest / Prep.FRY_REST})
	_bar.visible = is_cooking() or (type == "stove" and item.begins_with("prep"))
	_needle.rotation.z = -deg_to_rad(_dial_angle(cook))
	if _ring:
		_ring.material_override = Build.mat(Color("#ff8a3c") if is_cooking() else Color(Build.STEEL_DARK), 1.6 if is_cooking() else 0.0)
	var look := _shown_look if item != "" else ""
	_fx.steam.visible = look == "raw" or look == "nearly" or look == "perfect"
	_fx.spatter.visible = look == "nearly" or look == "perfect"
	_fx.smoke.visible = look == "dry"
	_fx.burn.visible = look == "burnt"
	_fx.flame.visible = look == "burnt"


## Redraws plate stacks and dirty dishes.
## Pieces guests sit at: each has seats around it and takes dirty plates.
const TABLES: Array[String] = ["table", "booth", "table4"]


static func is_table(type_: String) -> bool:
	return type_ in TABLES


## Where a piece's seats are: either side of a table or booth, turning with it,
## or all four sides of a table for four.
static func seats_for(type_: String, cell_: Vector2i, facing_: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if type_ == "table" or type_ == "booth":
		var side := Vector2i(1, 0) if facing_ % 2 == 0 else Vector2i(0, 1)
		out = [cell_ - side, cell_ + side]
	elif type_ == "table4":
		out = [cell_ + Vector2i(-1, 0), cell_ + Vector2i(1, 0), cell_ + Vector2i(0, -1), cell_ + Vector2i(0, 1)]
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


## A table with plates on it, a sink piled with washing-up, an overflowing bin.
func messy() -> bool:
	match type:
		"table":
			return dirty > 0
		"sink":
			return dirty >= SINK_PILED
		"bin":
			return overflowing()
	return false


func overflowing() -> bool:
	return type == "bin" and count >= BIN_HOLDS


func refresh() -> void:
	if _stack:
		_stack.queue_free()
	_stack = Node3D.new()
	add_child(_stack)
	if type == "trays":
		for i in count:
			var t := Build.item("tray")
			t.position = Vector3(0, 0.916 + i * 0.04, 0)
			_stack.add_child(t)
	elif Catalog.ingredient_of(type) != "" and not stocked:
		Build.unstocked(_stack)
	elif is_table(type):
		for i in dirty:
			var d := Build.item("dirty_tray")
			d.position = Vector3(-0.25 + (i % 2) * 0.5, 0.74, 0.3 - (i / 2) * 0.6)
			_stack.add_child(d)
	elif type == "sink":
		Build.sink_load(_stack, dirty, dirty >= SINK_PILED)
	elif type == "bin":
		Build.bin_load(_stack, count, BIN_HOLDS)
		if overflowing() and not _fx.has("wisps"):
			_fx.wisps = Fx.play(self, "wisps", Vector3(0, 1.25, 0), 0.32, true)
			_fx.wisps.fps = 3.0
		elif not overflowing() and _fx.has("wisps"):
			_fx.wisps.queue_free()
			_fx.erase("wisps")


## A little show when the chef uses the station: a door swings open.
func used() -> void:
	var door := _vis.get_node_or_null("door") as Node3D
	if door:
		var tw := door.create_tween()
		tw.tween_property(door, "rotation:y", -1.9, 0.16).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.35)
		tw.tween_property(door, "rotation:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
