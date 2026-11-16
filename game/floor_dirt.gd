class_name FloorDirt
extends Node3D
## Floor dirt in the room (PRD 9.2): wires sim/floor_mess.gd into the scene. Keeps its
## floor and covered cells in step with the room, tracks dirt under everyone's feet,
## drops grease from preps and mess from meals, puts guests off by sight and smell, and
## draws each dirty cell by level and shape (a few drops, a puddle, a big puddle, the
## whole cell) with footprints where dirt was tracked in. The rules live in FloorMess.

const Y := 0.02           # just over the floor slabs and thresholds
const GRIME := "#5a4129"   # greasy brown: dark on cream tile, darker than the planks
const RIM := "#3a2c22"     # the ink rim round puddles (Build.TRIM)
const SHEEN := "#c9a66d"   # the wet glint on big puddles
const PRINT_DARK := "#3a2c22"
const PRINT_PALE := "#d9c094"   # footprints over a big puddle show pale
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var game
var mess := FloorMess.new()
var drops := true   # false: preps and meals drop no dirt (tests of other systems turn it off)
var prints := {}   # Vector2i -> Vector2i: the way someone walked onto a cell they tracked dirt onto
var _last := {}    # instance id -> Vector2i: the cell each walker stood on last step
## Who is down after a slip (9.3): Node (Guest or Player) -> {"cell": Vector2i, "t": seconds
## down, "helper": the Node helping them up or null, "help": seconds of help left, "mark":
## the dizzy stars and help bar over them}.
var down := {}
var _drawn := {}   # Vector2i -> the look key drawn there
var _nodes := {}   # Vector2i -> Node3D
static var _meshes := {}   # outline -> its flat mesh


func setup(game_) -> void:
	game = game_
	mess.rng.randomize()


## Floors and furniture as the room has them now. Dirt on floor that was lifted goes.
func sync_room() -> void:
	mess.set_floor(game.plan.floors.keys())
	mess.set_covered(game.grid.blocked.keys())
	for c: Vector2i in mess.dirt.keys():
		if not mess.is_floor(c):
			mess.dirt.erase(c)
	for c: Vector2i in prints.keys():
		if mess.level(c) <= 0:
			prints.erase(c)


## How fast anyone moves standing at `p`.
func speed_at(p: Vector3) -> float:
	return mess.speed_at(Grid.to_cell(p))


## One step of feet: each walker is [node, cell]. Stepping off a dirty cell onto the next
## carries a level with them, and leaves footprints where it lands. With `slips` (during
## service), stepping onto a level 4 cell may put them down (9.3). Anyone down tracks nothing.
func step_feet(walkers: Array, slips := false) -> void:
	var here := {}
	for w: Array in walkers:
		if down.has(w[0]):
			continue   # on the floor: no steps, and none counted from here on getting up
		var id: int = w[0].get_instance_id()
		var c: Vector2i = w[1]
		here[id] = true
		var was: Variant = _last.get(id)
		_last[id] = c
		if was == null or was == c:
			continue
		var d: Vector2i = c - (was as Vector2i)
		if maxi(absi(d.x), absi(d.y)) > 1:
			continue   # not a step: moved some other way
		var onto := mess.level(c)
		if mess.track(was, c) and mess.level(c) > 0:
			prints[c] = d
		if slips and onto >= FloorMess.SLIP_LEVEL and mess.rolls_slip(c, w[0] is Player):
			slip(w[0], c)
	for id: int in _last.keys():
		if not here.has(id):
			_last.erase(id)


## The tool's `mess` factor and whether a hood is over it. PRD 8's trees and hood light
## these up (8.3, 8.5); until then every tool is 1.0 and there is no hood.
func grease_factors(_st: Station) -> Dictionary:
	return {"mess": 1.0, "hood": false}


## A prep finished: grease may drop on the chef's cell or a free floor cell beside the
## station. Returns the cell that grew, or null.
func prep_grease(tool: String, result: String, chef_cell: Vector2i, st: Station) -> Variant:
	if not drops:
		return null
	var cells := []
	if mess.is_floor(chef_cell) and not mess.is_covered(chef_cell):
		cells.append(chef_cell)
	for d in SIDES:
		var c := st.cell + d
		if c != chef_cell and mess.is_floor(c) and not mess.is_covered(c):
			cells.append(c)
	var f := grease_factors(st)
	return mess.drop_grease(tool, result, cells, f.mess, f.hood)


## A guest finished eating: a chance of mess near their seat, more if they were annoyed
## or ate something greasy (fried or meat).
func meal_mess(g: Guest) -> Variant:
	if not drops:
		return null
	return mess.drop_guest_mess(g.seat, annoyance(g), false, greasy(g._meal_tray))


## How fed up a guest is, 0 to 1.
static func annoyance(g: Guest) -> float:
	return clampf(1.0 - g.mood.satisfaction(), 0.0, 1.0)


static func greasy(t: Tray) -> bool:
	if t == null:
		return false
	for id: String in t.ingredients():
		var tags := Pantry.tags_of(id)
		if tags.has("meat") or tags.has("fried") or Pantry.tool_of(id) == "fry":
			return true
	return false


## The dirty cells a guest at `cell` can see.
func seen_from(cell: Vector2i, reach: int) -> Array:
	var out := []
	for c: Vector2i in mess.dirt:
		if absi(c.x - cell.x) <= reach and absi(c.y - cell.y) <= reach and game.grid.has_los(cell, c):
			out.append(c)
	return out


## Floor dirt in a seated guest's view, and from level 3 its smell. Returns whether they
## noticed it.
func disgust(g: Guest, delta: float, reach: int) -> bool:
	if mess.dirt.is_empty():
		return false
	var noticed := false
	var sight := mess.sight_disgust(seen_from(g.cell, reach))
	var smell := mess.smell_disgust(g.cell)
	if sight > 0.0:
		g.mood.see_gross(sight, delta, "Look at the state of the floor")
		noticed = sight >= GuestMood.NOTICE
	if smell > 0.0:
		g.mood.see_gross(smell, delta, "What is that smell?")
		noticed = noticed or smell >= GuestMood.NOTICE
	if noticed and g == game.critic_guest:
		g.mood.think(Critic.thought("gross"))
	return noticed


# ---------------------------------------------------------------- slipping (9.3)

func is_down(who: Node) -> bool:
	return down.has(who)


## `who` slips on `cell` and goes down. A guest's mood drops a lot, and every guest within
## one cell who saw it is put off a little.
func slip(who: Node3D, cell: Vector2i) -> void:
	if down.has(who):
		return
	down[who] = {"cell": cell, "t": 0.0, "helper": null, "help": 0.0, "mark": _down_mark(who)}
	who.fall()
	game.sfx("slide", 0.08)
	game.sfx("thump", 0.08)
	if who is Guest:
		var g: Guest = who
		g.mood.patience = maxf(0.0, g.mood.patience - FloorMess.SLIP_PATIENCE)
		g.mood.delight(-FloorMess.SLIP_JOY, FloorMess.SLIP_THOUGHT)
		for o: Guest in game.guests:
			if o != g and not down.has(o) and FloorMess.within_witness(Grid.to_cell(o.position), cell):
				o.witness_fall()


## The fallen person a chef standing here could help up: the nearest within one cell,
## not already being helped by a chef. Null for none.
func help_target(ch: Player) -> Node3D:
	if down.has(ch) or helping(ch) != null:
		return null
	var best: Node3D = null
	var best_d := INF
	for who: Node3D in down:
		if who == ch or not is_instance_valid(who):
			continue
		var h = down[who].helper
		if h is Player:
			continue
		var d := ch.position.distance_to(who.position)
		if FloorMess.within_witness(ch.cell(), down[who].cell) and d < best_d:
			best = who
			best_d = d
	return best


## Whom `helper` is helping up, or null.
func helping(helper: Node) -> Node3D:
	for who: Node3D in down:
		if down[who].helper == helper:
			return who
	return null


## A chef presses E beside someone down: they help them up (HELP_UP_CHEF), taking over
## from a guest who was helping. Returns whether they did.
func help_up(ch: Player) -> bool:
	var who := help_target(ch)
	if who == null:
		return false
	_start_help(who, ch, FloorMess.help_time(true))
	ch.look_at_cell(down[who].cell)
	game.sfx("lift", 0.08)
	return true


func _start_help(who: Node3D, helper: Node3D, seconds: float) -> void:
	var was = down[who].helper
	if was is Guest and is_instance_valid(was):
		was.helping = null
	down[who].helper = helper
	down[who].help = seconds
	if helper is Guest:
		helper.helping = who


## The way someone down lies from their feet to their head: they fall on their back.
static func lying_dir(who: Node3D) -> Vector3:
	var yaw: float = who._body.rotation.y
	return -Vector3(sin(yaw), 0, cos(yaw))


## Where a guest helping stands: beside the middle of the body, on the side away from the
## camera, so the one on the floor stays in view.
static func help_spot(who: Node3D) -> Vector3:
	var along := lying_dir(who)
	var mid := who.position + along * 0.55
	var side := Vector3(along.z, 0, -along.x)
	if side.dot(Vector3(1, 0, 1)) > 0.0:
		side = -side
	return mid + side * 0.7


## A guest within one cell who is not seated and not busy, who could walk over and help.
func _guest_helper_for(who: Node3D, cell: Vector2i) -> Guest:
	for o: Guest in game.guests:
		if o == who or down.has(o) or o.helping != null:
			continue
		if not (o.state in ["queue", "to_seat", "browse", "leaving"]):
			continue
		if FloorMess.within_witness(Grid.to_cell(o.position), cell):
			return o
	return null


## Runs every step: help counts down, nearby guests come over to help a fallen guest, and
## anyone left alone long enough gets up by themselves.
func tick_slips(delta: float) -> void:
	for who: Node3D in down.keys():
		if not is_instance_valid(who):
			_drop(who)
			continue
		var d: Dictionary = down[who]
		d.t += delta
		var h = d.helper
		if h != null and not is_instance_valid(h):
			d.helper = null
			h = null
		if h == null and who is Guest:
			var o := _guest_helper_for(who, d.cell)
			if o != null:
				_start_help(who, o, FloorMess.help_time(false))
				h = o
		if h != null:
			d.help -= delta
			_show_help(d, 1.0 - d.help / FloorMess.help_time(h is Player))
			if d.help <= 0.0:
				get_up(who, false)
		elif d.t >= FloorMess.get_up_alone_time(who is Player):
			get_up(who, true)


## `who` gets up, helped or `alone`. A guest left alone is angrier; then, unless already
## on the way out, they may walk out, the chance set by how they felt about the place.
func get_up(who: Node3D, alone: bool) -> void:
	if not down.has(who):
		return
	_drop(who)
	who.rise()
	if not (who is Guest):
		return
	var g: Guest = who
	if alone:
		g.mood.patience = maxf(0.0, g.mood.patience - FloorMess.ALONE_PATIENCE)
		g.mood.delight(-FloorMess.ALONE_JOY, FloorMess.ALONE_THOUGHT)
	else:
		g.mood.think(FloorMess.HELPED_THOUGHT)
	if g.state in ["leaving", "browse"]:
		return
	if mess.rolls_slip_walkout(opinion(g)):
		game.walk_out(g)


## A guest's opinion of the place right now, 0 to 1 (FloorMess.slip_opinion).
func opinion(g: Guest) -> float:
	return FloorMess.slip_opinion(float(game.town.people[g.idx].affinity), g.mood.satisfaction())


func _drop(who) -> void:
	var d: Dictionary = down[who]
	var h = d.helper
	if h is Guest and is_instance_valid(h):
		h.helping = null
	if is_instance_valid(d.mark):
		d.mark.queue_free()
	down.erase(who)


## Everyone gets up at once (a new day, a restart).
func clear_slips() -> void:
	for who in down.keys():
		if is_instance_valid(who):
			_drop(who)
			who.rise()
		else:
			_drop(who)


## Over someone down: dizzy stars going round, and a help bar that fills while someone
## helps them up (hidden until then).
func _down_mark(who: Node3D) -> Node3D:
	var mark := Node3D.new()
	mark.name = "down_mark"
	mark.position = lying_dir(who) * 1.0 + Vector3(0, 0.75, 0)   # over the head
	who.add_child(mark)
	var stars := Fx.play(mark, "dizzy", Vector3.ZERO, 0.42, true)
	stars.fps = 8.0
	var bar := Node3D.new()
	bar.name = "bar"
	bar.position = Vector3(0, 0.55, 0)
	bar.basis = Build.CAM_BASIS
	bar.visible = false
	mark.add_child(bar)
	Build.flat(bar, Icons.rect(0, 0, 0.67, 0.17), Build.TRIM)
	Build.flat(bar, Icons.rect(0, 0, 0.6, 0.1), "#6b5647", 0.003)
	var fill := Build.flat(bar, Icons.rect(0, 0, 0.6, 0.1), Build.GOOD, 0.006)
	fill.name = "fill"
	Build.on_top(bar, -bar.position.z)
	return mark


func _show_help(d: Dictionary, share: float) -> void:
	if not is_instance_valid(d.mark):
		return
	var bar: Node3D = d.mark.get_node("bar")
	bar.visible = true
	var fill: Node3D = bar.get_node("fill")
	var k := clampf(share, 0.001, 1.0)
	fill.scale.x = k
	fill.position.x = (k - 1.0) * 0.3


# ---------------------------------------------------------------- drawing

## Redraws the cells whose dirt or footprints changed.
func redraw() -> void:
	for c: Vector2i in _drawn.keys():
		if mess.level(c) <= 0:
			_nodes[c].queue_free()
			_nodes.erase(c)
			_drawn.erase(c)
	for c: Vector2i in mess.dirt:
		var key := "%d|%s" % [mess.level(c), prints.get(c, Vector2i.ZERO)]
		if _drawn.get(c, "") == key:
			continue
		if _nodes.has(c):
			_nodes[c].queue_free()
		var n := cell_look(c, mess.level(c), prints.get(c, Vector2i.ZERO))
		add_child(n)
		_nodes[c] = n
		_drawn[c] = key


## One cell's dirt, lying flat. Each level is its own shape so it reads without colour:
## 1 a few round drops, 2 one puddle with a rim, 3 a big lobed puddle with a glint,
## 4 the whole cell covered, rim to rim, with a long glint. Footprints go on top.
static func cell_look(c: Vector2i, lvl: int, walked: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "dirt_%d_%d" % [c.x, c.y]
	root.position = Grid.center(c) + Vector3(0, Y, 0)
	var flat := Node3D.new()
	flat.rotation.x = -PI / 2   # cards face +z; this lays them on the floor, facing up
	root.add_child(flat)
	var r := RandomNumberGenerator.new()
	r.seed = hash(c)
	var turn := r.randf() * TAU
	var blobs: Array = []   # [radius, Vector2 centre]
	match lvl:
		1:
			for i in 3:
				blobs.append([r.randf_range(0.05, 0.075), Vector2(r.randf_range(-0.3, 0.3), r.randf_range(-0.3, 0.3))])
		2:
			blobs = [[0.17, Vector2.ZERO], [0.12, Vector2(0.14, 0.06)], [0.1, Vector2(-0.1, 0.11)],
				[0.05, Vector2(-0.27, -0.16)]]
		3:
			blobs = [[0.27, Vector2.ZERO], [0.2, Vector2(0.18, -0.12)], [0.19, Vector2(-0.17, 0.14)],
				[0.16, Vector2(0.12, 0.21)], [0.06, Vector2(-0.33, -0.25)], [0.05, Vector2(0.36, 0.3)]]
	if lvl >= 4:
		_card(flat, _rounded_square(0.49, 0.1), RIM, 0.0)
		_card(flat, _rounded_square(0.46, 0.08), GRIME, 0.002)
		_card(flat, _rot(_ellipse(0.3, 0.05, Vector2(-0.05, 0.12)), turn), SHEEN, 0.004)
		_card(flat, _rot(_ellipse(0.08, 0.035, Vector2(0.22, -0.02)), turn), SHEEN, 0.004)
	else:
		if lvl >= 2:   # an ink rim under the puddle, so its outline reads on any floor
			for b: Array in blobs:
				_card(flat, Build.disc_pts(b[0] + 0.025, _turned(b[1], turn), 20), RIM, 0.0)
		for b: Array in blobs:
			_card(flat, Build.disc_pts(b[0], _turned(b[1], turn), 20), GRIME, 0.002)
		if lvl == 3:
			_card(flat, _rot(_ellipse(0.13, 0.035, Vector2(-0.04, 0.08)), turn), SHEEN, 0.004)
	if walked != Vector2i.ZERO:
		_footprints(flat, walked, PRINT_PALE if lvl >= 3 else PRINT_DARK)
	return root


## Two pairs of shoe prints heading the way they walked onto the cell.
static func _footprints(flat: Node3D, walked: Vector2i, col: String) -> void:
	# World +x is card +x; world +z is card -y (the card is laid face up).
	var ahead := Vector2(walked.x, -walked.y).normalized()
	var side := Vector2(-ahead.y, ahead.x)
	var ang := ahead.angle()
	for k in 2:
		for foot in 2:
			var at := ahead * (-0.2 + 0.36 * k + 0.18 * foot) + side * (0.09 if foot == 0 else -0.09)
			var sole := _rot(_ellipse(0.075, 0.04, Vector2.ZERO), ang)
			var heel := _rot(_ellipse(0.035, 0.032, Vector2(-0.1, 0)), ang)
			var moved := PackedVector2Array()
			for p in sole:
				moved.append(p + at)
			_card(flat, moved, col, 0.006)
			moved = PackedVector2Array()
			for p in heel:
				moved.append(p + at)
			_card(flat, moved, col, 0.006)


## A flat shape on the card's plane, shaded like everything solid. Each triangle is wound
## clockwise seen from +z, the way Godot draws front faces, so it shows from above.
static func _card(parent: Node3D, pts: PackedVector2Array, col: String, z: float) -> void:
	var key := "dirt|%s" % [pts]
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tris := Geometry2D.triangulate_polygon(pts)
		for i in range(0, tris.size(), 3):
			var a := pts[tris[i]]
			var b := pts[tris[i + 1]]
			var c := pts[tris[i + 2]]
			if (b - a).cross(c - a) > 0.0:
				var t := b
				b = c
				c = t
			for p in [a, b, c]:
				st.set_normal(Vector3(0, 0, 1))
				st.add_vertex(Vector3(p.x, p.y, 0))
		_meshes[key] = st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.position.z = z
	mi.material_override = Build.mat(Color(col), 0.0, Build.R_GLOSS, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _turned(p: Vector2, a: float) -> Vector2:
	return p.rotated(a)


static func _rot(pts: PackedVector2Array, a: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p.rotated(a))
	return out


static func _ellipse(rx: float, ry: float, at: Vector2, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(at + Vector2(cos(TAU * i / n) * rx, sin(TAU * i / n) * ry))
	return pts


static func _rounded_square(h: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for q in 4:
		var corner := Vector2(h - r, h - r).rotated(PI / 2 * q)
		for i in 5:
			var a := PI / 2 * q + PI / 2 * i / 4.0
			pts.append(corner + Vector2(cos(a), sin(a)) * r)
	return pts
