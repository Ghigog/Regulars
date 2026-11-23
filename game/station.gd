class_name Station
extends Node3D
## One piece of furniture occupying a grid cell.

const COOK_TIME := Prep.GRILL_DONE       # raw until here
const PERFECT_END := Prep.GRILL_PERFECT  # juicy until here, then it dries out
const BURN_TIME := Prep.GRILL_BURN
const NEARLY_TIME := Prep.GRILL_NEARLY   # the raw patty starts to colour
const PLATES := 8          # plates in a new plate stack
const CUPS := 6            # cups in a new cup stack
const TRAYS := 2           # trays in a tray stack
const DIAL_SWEEP := 150.0  # degrees either side of straight up
const SINK_PILED := 6      # this many dishes soaking and the washing-up shows (and bothers guests)
const RACK_HOLDS := 4      # a dish rack beside a sink: this many more dishes before it looks piled
const BIN_HOLDS := 4       # scraps a bin takes before it overflows

## A heat tool's behaviour for each heat job: a stove that fries works as a fryer.
const HEAT_MODE := {"grill": "stove", "fry": "fryer", "boil": "pot"}
const HEAT_TOOLS: Array[String] = ["stove", "fryer", "pot"]

var type := ""        # the catalog piece it behaves as (a range is a "stove")
var node := ""        # its node in the upgrade trees (Kitchen.NODES), or "" for none
var heat := ""        # a heat tool: the job of what is cooking ("grill", "fry", "boil")
var stacked := false  # a double counter made by stacking two counters: picking it up takes one
var cell := Vector2i.ZERO
var tier := 1
var facing := 0       # quarter turns; 0 puts the front toward +z
var base := ""        # the counter this piece is or stands on ("counter", "double_counter"); "" for the rest
var high := false     # hung in a wall cell's high layer (PRD 8.5): a cabinet, a high shelf, a hood
var pass_look := false  # a counter drawn as a length of the frame's long teal pass (the starting ones)
var lamp: OmniLight3D # a table's lamp light, owned by the game
var item := ""        # what is sitting on a counter or stove: an ingredient kind ("raw:patty") or "dish"
var quality := 1.0    # how well prepped that item is (0..1)
var dish: Dish        # the plate, cup or loose stack on a counter, when item is "dish"
var boxes: Array = []   # the boxes of stock in this cell's storage, as the kitchen holds them (PRD 8.4)
var cook := 0.0       # seconds the piece has been on the heat (stove, fryer, pot)
var rest := 0.0       # a fryer: seconds left draining on the rack before it can be picked up
var result := ""      # a fryer: how the piece on the rack came out (good, plain)
var prep_by := -1        # the player playing a press-based minigame here, or -1
var widget: PrepWidget   # the gauge over a pot or fryer rack, or a press-based minigame
var tap := 0          # a dispenser with several taps: the one it is turned to (PRD 8.6)
var count := 0        # clean plates, cups or trays in their stack; scraps in a bin
var dirty := 0        # dirty dishes left on a table, or soaking in a sink (cups among them)
var dirty_cups := 0   # how many of `dirty` are cups
var dirty_age := 0.0  # seconds this piece has been messy (see `messy`)
var seats: Array[Vector2i] = []
var kit_tool := ""    # a home's cleaning tool kept here ("mop", "sponge"; PRD 9.4), drawn by CleanKit
var kit_used := 0      # how many levels that tool has cleared since it was last rinsed
var racked := false   # a sink: a dish rack stands beside it (see piled_at)
var _item_node: Node3D
var _stack: Node3D
var _bar: Node3D
var _needle: Node3D
var _ring: MeshInstance3D
var _shown_look := ""
var _vis: Node3D
var _fx := {}
var _tags: Node3D
var _crates: Node3D   # the boxes of stock drawn standing on an open counter


static func quality_at(t: float) -> float:
	return float(Prep.grill(t).quality)


## How a piece on the heat shows after `t` seconds: raw, prepped or burnt.
static func stage_at(t: float) -> String:
	if t < COOK_TIME:
		return "raw"
	return "prep" if t < BURN_TIME else "burnt"


## The ingredient sitting here ("" if none or a dish).
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
## A tool (a top) and a bare counter always have a counter base; `base_` overrides it.
func setup(type_: String, cell_: Vector2i, tier_: int, facing := 0, base_ := "", pass_look_ := false, node_ := "") -> void:
	type = Kitchen.family_of(type_) if Kitchen.has_node(type_) and not Catalog.ITEMS.has(type_) else type_
	node = node_ if node_ != "" else Kitchen.node_of(type_)
	cell = cell_
	tier = tier_
	pass_look = pass_look_
	base = base_ if base_ != "" else ("counter" if Kitchen.is_top(type) or Kitchen.is_counter(type) else "")
	_vis = Node3D.new()
	add_child(_vis)
	_draw()
	place_at(cell_, facing)
	count = {"plates": PLATES, "cups": CUPS, "tray_stack": TRAYS}.get(type, count)
	if is_heat_tool():
		_ring = _vis.get_node_or_null("ring")
		_make_cook_bar()
		_make_smoke()
		_heat_widget()
	refresh()


## A stove, fryer or pot, or any piece in their trees.
func is_heat_tool() -> bool:
	return type in HEAT_TOOLS


## The job this piece does best (its own job): "grill" for a stove.
func main_job() -> String:
	return str(Catalog.ITEMS[type].get("tool_of", Catalog.tool_of(type))) if Catalog.ITEMS.has(type) else ""


## How well this piece does a job (PRD 8.3): its tree node's quality, 0.0 if it cannot.
## A piece outside the trees does its own job at 1.0.
func q(job: String) -> float:
	if node != "" and Kitchen.has_node(node):
		return Kitchen.quality(node, job)
	return 1.0 if job == main_job() else 0.0


## How a heat tool behaves right now: as the tool of what is cooking on it.
func mode() -> String:
	return str(HEAT_MODE[heat]) if heat != "" else type


## Shows the gauge the current heat job uses (a fryer's rack, a pot's ring), hidden.
func _heat_widget() -> void:
	var want: String = {"fryer": "rack", "pot": "boil"}.get(mode(), "")
	if want == "":
		if widget != null and widget.kind in ["rack", "boil"]:
			widget.visible = false
		return
	show_widget(want)
	widget.visible = false


## Changes the counter under (or of) this piece and redraws it: a counter stacked into
## a double counter, a tool moved onto another counter.
func set_base(base_: String, pass_look_ := pass_look) -> void:
	base = base_
	pass_look = pass_look_
	_draw()
	if _ring:
		_ring = _vis.get_node_or_null("ring")
		_update_cooking_visuals()


func _draw() -> void:
	for c in _vis.get_children():
		_vis.remove_child(c)
		c.queue_free()
	if high:
		BuildStations.wall_piece(_vis, node)
	else:
		BuildStations.station(_vis, type, tier, base, pass_look, node)


## Hangs this piece in the high layer, or stands it low, and redraws it (PRD 8.5).
func set_wall(high_: bool) -> void:
	if high == high_:
		return
	high = high_
	_draw()


func _show_item(kind: String) -> void:
	if _item_node:
		_item_node.queue_free()
		_item_node = null
	_shown_look = ""
	if kind == "dish" and dish != null:
		_item_node = BuildFood.dish(dish, BuildFood.menu_items())
		_item_node.position = Vector3(0, 0.9, 0)
		add_child(_item_node)
	elif kind != "":
		var on_heat := is_heat_tool() and mode() == "stove"
		_shown_look = _look(cook) if on_heat else BuildFood.look_for(kind, quality)
		_item_node = BuildFood.item(kind, quality, _shown_look)
		match mode():
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
	if kind != "dish":
		dish = null
	if is_heat_tool():
		var was := heat
		heat = _heat_for(kind)
		if heat != was:
			_make_cook_bar()
			_heat_widget()
		var state: String = Tray.parse(kind).get("state", "")
		cook = {"prep": _times()[2], "burnt": _times()[3]}.get(state, 0.0) if mode() != "pot" else (Prep.boil_time(q("boil")) if state == "prep" else 0.0)
		rest = 0.0
		result = ""
	_show_item(kind)
	if is_heat_tool():
		_update_cooking_visuals()


## The heat job an item here would cook by: its own tool where this piece can do it,
## else this piece's own job. "" when nothing (or a dish) is here.
func _heat_for(kind: String) -> String:
	var p := Tray.parse(kind)
	if p.is_empty():
		return ""
	var job := Pantry.tool_of(p.id)
	if HEAT_MODE.has(job) and q(job) > 0.0:
		return job
	return main_job()


## Puts a plate, cup or loose stack down here (a counter or the pass).
func set_dish(d: Dish) -> void:
	dish = d
	item = "dish"
	quality = 1.0
	_show_item("dish")


## Redraws the dish after something was added to it.
func show_dish() -> void:
	if item == "dish":
		_show_item("dish")


## Quality of whatever is here right now; a stove reads it off the timer.
func current_quality() -> float:
	if not is_heat_tool():
		return quality
	if mode() == "stove":
		return float(Prep.grill(cook, q("grill")).quality)
	if mode() == "pot":
		return float(Prep.boil(cook, q("boil")).quality)
	return quality


## [raw until, done from, good until, burnt at] for this heat tool and what is on it,
## stretched by the tool's quality at the job (PRD 8.3).
func _times() -> Array:
	var job := "fry" if mode() == "fryer" else "grill"
	return Prep.heat_times(job, q(job) if q(job) > 0.0 else 1.0)


## Which of the five looks a piece on this grill has after `t` seconds.
func _look(t: float) -> String:
	var tt := _times()
	if t < tt[0]:
		return "raw"
	if t < tt[1]:
		return "nearly"
	if t <= tt[2]:
		return "perfect"
	return "dry" if t < tt[3] else "burnt"


## A fryer's basket is lifted: the piece drains on the rack before it can be taken.
func lift_to_rack(kind: String, q: float, res: String) -> void:
	item = kind
	quality = q
	result = res
	rest = Prep.FRY_REST
	cook = 0.0
	_show_item(kind)
	_update_cooking_visuals()


## Food left on the piece when the day ends: an ingredient, or a plate, cup or tray with food on it.
## A clean empty plate is not food.
func has_leftover_food() -> bool:
	if item == "dish":
		return dish != null and not dish.is_empty()
	return not Tray.parse(item).is_empty()


## Throws the food away: the piece is left empty and cold.
func clear_food() -> void:
	item = ""
	dish = null
	cook = 0.0
	rest = 0.0
	result = ""
	refresh()


## Whether a fryer's piece has been lifted onto the drain rack.
func on_rack() -> bool:
	return is_heat_tool() and mode() == "fryer" and result != ""


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
	cook += delta
	if mode() == "pot":
		_update_cooking_visuals()
		if cook >= Prep.boil_time(q("boil")):
			item = Tray.kind("prep", Tray.parse(item).id)
			_show_item(item)
			return "prep"
		return ""
	_update_cooking_visuals()
	var p := Tray.parse(item)
	var tt := _times()
	var stage := "raw" if cook < tt[1] else ("prep" if cook < tt[3] else "burnt")
	if stage == p.state:
		if mode() == "stove" and _look(cook) != _shown_look:
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
	if _bar:
		_bar.queue_free()
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


## The loop this tool's cooking sounds like: a stove's by doneness (raw, cooking,
## done, then smoke as it dries out toward burnt), anything else the old sizzle.
func sizzle_stage() -> String:
	if not is_cooking():
		return ""
	if mode() != "stove":
		return "sizzle"
	var tt := _times()
	if cook < tt[0]:
		return "sizzle_raw"
	if cook < tt[1]:
		return "sizzle_cooking"
	if cook <= tt[2]:
		return "sizzle_done"
	return "smoke_warn"


func is_cooking() -> bool:
	if item == "" or item == "dish" or item.begins_with("burnt") or not is_heat_tool():
		return false
	match mode():
		"stove":
			return true
		"fryer":
			return not on_rack()
		"pot":
			return item.begins_with("raw")
	return false


## Shows a minigame gauge over this piece (replacing any other).
## `ing`: what is being made, for the colour of a drink, a heap or a jug (PRD 8.6).
func show_widget(kind: String, q_ := 1.0, ing := "") -> PrepWidget:
	if widget != null and widget.kind == kind and is_equal_approx(widget.quality, q_) and ing == "":
		widget.visible = true
		return widget
	if widget != null:
		widget.queue_free()
	if ing == "" and kind == "pour":
		ing = Catalog.ingredient_of(type)
	widget = PrepWidget.make(kind, str(Pantry.ITEMS[ing].prepped) if ing != "" and Pantry.has(ing) else "", q_)
	widget.position = Vector3(0, 1.72, 0)
	if kind in ["chop", "slice", "saw", "grate", "juice", "blend"]:
		widget.scale = Vector3.ONE * 1.4   # flat bars: as easy to read as the round dial
		widget.position.y = 1.85
	add_child(widget)
	return widget


func hide_widget() -> void:
	if widget != null and not (is_heat_tool() and widget.kind in ["rack", "boil"]):
		widget.queue_free()
		widget = null
	elif widget != null:
		widget.visible = false


func _update_cooking_visuals() -> void:
	if mode() == "pot":
		widget.visible = item != ""
		widget.show_state({"t": cook / Prep.boil_time(q("boil")), "done": item.begins_with("prep")})
		_bar.visible = false
		for fx in _fx.values():
			fx.visible = false
		if _ring:
			_ring.material_override = Build.mat(Color("#ff8a3c") if is_cooking() else Color(Build.STEEL_DARK), 1.6 if is_cooking() else 0.0)
		return
	if mode() == "fryer" and widget != null and widget.kind == "rack":
		widget.visible = rest > 0.0
		widget.show_state({"left": rest / Prep.FRY_REST})
	_bar.visible = is_cooking() or (mode() == "stove" and item.begins_with("prep"))
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
const TABLES: Array[String] = ["table", "booth", "table4", "stool"]


static func is_table(type_: String) -> bool:
	return type_ in TABLES


## Where a piece's seats are: either side of a table or booth, turning with it,
## all four sides of a table for four, or the one stool at a counter stool's
## little table (on its +x side, turning with it as the model does).
static func seats_for(type_: String, cell_: Vector2i, facing_: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if type_ == "table" or type_ == "booth":
		var side := Vector2i(1, 0) if facing_ % 2 == 0 else Vector2i(0, 1)
		out = [cell_ - side, cell_ + side]
	elif type_ == "stool":
		out = [cell_ + [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1)][posmod(facing_, 4)]]
	elif type_ == "table4":
		out = [cell_ + Vector2i(-1, 0), cell_ + Vector2i(1, 0), cell_ + Vector2i(0, -1), cell_ + Vector2i(0, 1)]
	return out


## Stands the piece on a cell, turned `facing_` quarter turns.
func place_at(cell_: Vector2i, facing_: int) -> void:
	cell = cell_
	facing = posmod(facing_, 4)
	position = Grid.center(cell)
	_vis.rotation.y = facing * PI / 2
	if _crates:
		_crates.rotation.y = _vis.rotation.y
	seats = seats_for(type, cell, facing)
	if lamp:
		lamp.position = position + Vector3(0, 1.0, 0)


## A table with plates on it, a sink piled with washing-up, an overflowing bin.
func messy() -> bool:
	match type:
		"table":
			return dirty > 0
		"sink":
			return dirty >= piled_at(racked)
		"bin":
			return overflowing()
	return false


## How many dishes soak in a sink before it looks piled: more with a dish rack beside it.
static func piled_at(rack: bool) -> int:
	return SINK_PILED + (RACK_HOLDS if rack else 0)


func overflowing() -> bool:
	return type == "bin" and count >= BIN_HOLDS


func refresh() -> void:
	if _stack:
		_stack.queue_free()
	_stack = Node3D.new()
	add_child(_stack)
	if type in ["plates", "cups", "tray_stack"]:
		BuildFood.stack_load(_stack, type, count)
	elif is_table(type):
		for i in dirty:
			var d := BuildFood.item("dirty_cup" if i >= dirty - dirty_cups else "dirty_plate")
			d.position = Vector3(-0.25 + (i % 2) * 0.5, 0.74, 0.3 - ((i / 2) % 2) * 0.6) + Vector3(0, (i / 4) * 0.03, 0)
			_stack.add_child(d)
	elif type == "sink":
		BuildStations.sink_load(_stack, dirty, messy())
	elif type == "bin":
		BuildStations.bin_load(_stack, count, BIN_HOLDS)
		if overflowing() and not _fx.has("wisps"):
			_fx.wisps = Fx.play(self, "wisps", Vector3(0, 1.25, 0), 0.32, true)
			_fx.wisps.fps = 3.0
		elif not overflowing() and _fx.has("wisps"):
			_fx.wisps.queue_free()
			_fx.erase("wisps")


## Shows which kinds this cell stores: a row of tags over it (PRD 8.4).
func set_boxes(b: Array, y := 1.6) -> void:
	boxes = b.duplicate()
	if _tags:
		_tags.queue_free()
		_tags = null
	if _crates:
		_crates.queue_free()
		_crates = null
	if boxes.is_empty():
		return
	if shows_crates():   # an open counter: the crates themselves stand on it
		_crates = Node3D.new()
		_crates.name = "crates"
		add_child(_crates)
		_crates.rotation.y = _vis.rotation.y
		var gap := 0.86 / boxes.size()
		for i in boxes.size():
			var cr := Node3D.new()
			cr.position = Vector3(-0.43 + gap * (i + 0.5), CRATE_Y, -0.2)
			cr.scale = Vector3.ONE * minf(CRATE_SCALE, gap * 0.95)
			_crates.add_child(cr)
			BuildStations.station(cr, str(boxes[i]), 1)
		return
	_tags = Node3D.new()
	_tags.name = "box_tags"
	add_child(_tags)
	BuildClean.box_tags(_tags, boxes, y)


const CRATE_Y := 0.9        # an open counter's worktop
const CRATE_SCALE := 0.72   # a crate on a worktop, big enough to read at 20 px


## Whether its stock is drawn as crates standing on it: a bare counter, double or long.
## A fridge or cabinet keeps its stock inside (the tag says what) and opens its door
## when used; a tool on a counter leaves no room, so it keeps the tag too.
func shows_crates() -> bool:
	return type == "counter" and base in ["counter", "double_counter", "long_counter"] and not high


## A little show when the chef uses the station: a door swings open.
func used() -> void:
	var door := _vis.get_node_or_null("door") as Node3D
	if door:
		var tw := door.create_tween()
		tw.tween_property(door, "rotation:y", -1.9, 0.16).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.35)
		tw.tween_property(door, "rotation:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
