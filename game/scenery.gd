class_name Scenery
extends RefCounted
## The room itself, drawn from a Floorplan: floors, walls, the knee-high cutaway,
## windows, doors, wall art and lights (style guide, sheets 10 and 11); and the
## street outside. No gameplay lives here.

const WALL_H := 2.4
const WALL_T := 0.3
const CUT_H := 0.55
const KITCHEN_W := 4
const WIN_W := 1.3
const WIN_Y0 := 1.0
const WIN_Y1 := 2.0
const DOOR_X := 1.5    # the back doorway's centre line
const DOOR_R := 0.45
const KITCHEN_Z := 2   # the room is an L (sheet 1): the kitchen's back wall stands this many rows forward of the dining room's
const CAM_RISE := 14.0 / 15.0  # how far back along the ground one metre of height appears from the fixed camera
static var X0 := 3.0  # the near end of the street as drawn; set in _ground
## A theme is a re-skin of the same kit (sheet 16): grid, stations, heights and
## bevels never change; walls, windows, floors and wall art do.
const THEMES := {
	"diner": {
		"backdrop": "#d9cfc1", "wall": "#f6eedd", "wall_low": "#eadfcb", "cut": "#f07a63",
		"tile_a": "#236a74", "tile_b": "#f1e8cc", "planks": ["#b47d50", "#ad764a", "#ba8456"],
	},
	"seaside": {
		"backdrop": "#e4ebe0", "wall": "#f3f5ee", "wall_low": "#dde5dc", "cut": "#bfe0d2",
		"tile_a": "#a8dccb", "tile_b": "#f4efe0", "planks": ["#b9b1a4", "#aaa295", "#c6bfb2"],
	},
}
const SEAFOAM := "#bfe0d2"
const BRASS := "#d9a441"
const Z0 := -1.2
const PAPER_Y := -0.2
const BASE_M := 0.5   # how far the street runs past the floor on the right: flush with the wall
const Z1 := 12.5
const PAVE_Z := 9.9  # where the pavement (or pier) meets the road (or sea)

static var theme_id := "diner"


static func t() -> Dictionary:
	return THEMES[theme_id]


static func seaside() -> bool:
	return theme_id == "seaside"


## The street, the paper and what stands outside. Built once; returns the street lights.
static func build_ground(root: Node3D, w: int, h: int) -> Array[OmniLight3D]:
	var lights: Array[OmniLight3D] = []
	_ground(root, w, lights)
	_outside(root, w, h)
	return lights


## The room, drawn from the floorplan: floors, walls, windows, doors and the
## dressing on the walls. Rebuilt whenever the plan changes. Returns
## {"lights": Array[OmniLight3D], "openings": {edge: info}}, where each info can be
## redrawn with dress_opening to grey it out.
##
## Which walls stand tall follows sheet 1 and the fixed camera: a wall with the
## room in front and bare ground behind is a full-height back wall. Walls between
## two floors, and those on the street side, are cut down to knee height so
## nothing hides behind them. On the near side the floor simply ends.
static func build_room(root: Node3D, plan: Floorplan, door: Vector2i) -> Dictionary:
	var lights: Array[OmniLight3D] = []
	var openings := {}
	_floors(root, plan)
	var entrance := Vector3i(door.x, door.y, 1)
	for axis in 2:
		for run: Dictionary in _runs(plan, axis, "tall"):
			_tall_run(root, plan, run, lights, openings)
		for run: Dictionary in _runs(plan, axis, "low"):
			_low_run(root, plan, run, openings, entrance)
	_fixtures(root, plan, lights)
	return {"lights": lights, "openings": openings}


## How a wall edge is drawn: "tall", "low" or "" (not drawn).
static func wall_look(plan: Floorplan, e: Vector3i) -> String:
	if not plan.is_wall(e):
		return ""
	var s := Floorplan.sides(e)
	var front := plan.has_floor(s[0])
	var back := plan.has_floor(s[1])
	if front and not back:
		return "tall"
	if front and back:
		return "low"
	return "low" if e.z == 1 else ""


## Straight runs of one look along each grid line, as
## {axis, line, from, to}: edges from..to-1 along the line.
static func _runs(plan: Floorplan, axis: int, look: String) -> Array[Dictionary]:
	var by_line := {}
	for e in plan.walls():
		if e.z == axis and wall_look(plan, e) == look:
			var line := e.y if axis == 0 else e.x
			if not by_line.has(line):
				by_line[line] = []
			by_line[line].append(e.x if axis == 0 else e.y)
	var out: Array[Dictionary] = []
	for line: int in by_line:
		var at: Array = by_line[line]
		at.sort()
		var start: int = at[0]
		for i in at.size():
			if i == at.size() - 1 or at[i + 1] != at[i] + 1:
				out.append({"axis": axis, "line": line, "from": start, "to": at[i] + 1})
				if i < at.size() - 1:
					start = at[i + 1]
	return out


static func _edge(axis: int, line: int, k: int) -> Vector3i:
	return Vector3i(k, line, 0) if axis == 0 else Vector3i(line, k, 1)


## The cell on the room side of edge k of a run.
static func _room_cell(axis: int, line: int, k: int) -> Vector2i:
	return Vector2i(k, line) if axis == 0 else Vector2i(line, k)


## How far a tall run reaches past its end at lattice position k (before the
## first edge when `start`): into the corner where another tall wall meets it,
## half way into a knee-high one, and not at all where the room goes on round a
## corner. Returns [reach, cut]: `cut` when the end shows its painted cut face.
static func _end_reach(plan: Floorplan, axis: int, line: int, k: int, start: bool) -> Array:
	var beyond := _room_cell(axis, line, k - 1 if start else k)
	if plan.has_floor(beyond):
		return [0.0, false]
	var looks: Array[String] = []
	for e in [_edge(1 - axis, k, line - 1), _edge(1 - axis, k, line)]:
		looks.append(wall_look(plan, e))
	if looks.has("tall"):
		return [WALL_T, false]
	if looks.has("low"):
		return [WALL_T / 2, true]
	return [0.0, true]


## A holder for a run: local x runs along the wall, the room is toward +z and the
## wall's line is local z = 0. Returns [holder, sign]: local x = sign * world k.
static func _run_holder(root: Node3D, axis: int, line: int) -> Node3D:
	if axis == 0:
		var n := Node3D.new()
		n.position = Vector3(0, 0, line)
		root.add_child(n)
		return n
	return _turned(root, Vector3(line, 0, 0))


## Local x of world position k along a run (axis 1 runs are mirrored).
static func _lx(axis: int, k: float) -> float:
	return k if axis == 0 else -k


static func _tall_run(root: Node3D, plan: Floorplan, run: Dictionary, lights: Array[OmniLight3D], openings: Dictionary) -> void:
	var axis: int = run.axis
	var line: int = run.line
	var from: int = run.from
	var to: int = run.to
	var holder := _run_holder(root, axis, line)
	var r0 := _end_reach(plan, axis, line, from, true)
	var r1 := _end_reach(plan, axis, line, to, false)
	# Local extent: a < b whichever way the run is mirrored.
	var ends := [_lx(axis, from - float(r0[0])), _lx(axis, to + float(r1[0]))]
	var a: float = minf(ends[0], ends[1])
	var b: float = maxf(ends[0], ends[1])
	var top := WALL_H
	var bot := -0.2
	# Holes: doors and archways on their edges, then windows where there is room.
	var holes: Array = []   # [x0, x1, y0, y1]
	var planks := 0
	for k in range(from, to):
		var e := _edge(axis, line, k)
		var c := _lx(axis, k + 0.5)
		if plan.kind(_room_cell(axis, line, k)) != "tile":
			planks += 1
		match plan.openings.get(e, ""):
			"door":
				holes.append([c - 0.45, c + 0.45, bot, 2.0])
				openings[e] = {"holder": _opening_holder(holder, c), "kind": "door", "tall": true}
			"arch":
				holes.append([c - DOOR_R, c + DOOR_R, bot, 2.15])
				_arch_header(holder, c, DOOR_R, 1.55, 2.2, -WALL_T + 0.004, -0.004)
				openings[e] = {"holder": _opening_holder(holder, c), "kind": "arch", "tall": true}
	var dining := planks * 2 > to - from
	var windows: Array[float] = []
	var length := to - from
	if dining and length >= 3:
		var n := int((length + 0.2) / 3.0)
		for i in n:
			var c := _lx(axis, from + length * (i + 0.5) / n)
			var clear := true
			for hole: Array in holes:
				if c + WIN_W / 2 + 0.1 > hole[0] and c - WIN_W / 2 - 0.1 < hole[1]:
					clear = false
			if clear:
				windows.append(c)
				if not seaside():
					holes.append([c - WIN_W / 2, c + WIN_W / 2, WIN_Y0, WIN_Y1])
	# The wall itself: one slab per stretch between hole edges, overlapping a
	# little so the joins never show.
	var cuts: Array[float] = [a, b]
	for hole: Array in holes:
		cuts.append_array([clampf(hole[0], a, b), clampf(hole[1], a, b)])
	cuts.sort()
	for i in cuts.size() - 1:
		var u := cuts[i]
		var v := cuts[i + 1]
		if v - u < 0.001:
			continue
		var over: Array = []
		for hole: Array in holes:
			if (u + v) / 2 > hole[0] and (u + v) / 2 < hole[1]:
				over = hole
		if over.is_empty():
			_slab(holder, maxf(a, u - 0.05), minf(b, v + 0.05), bot, top, -WALL_T, 0, t().wall)
		else:
			if over[2] > bot:
				_slab(holder, u, v, bot, over[2], -WALL_T, 0, t().wall)
			_slab(holder, u, v, over[3], top, -WALL_T, 0, t().wall)
	# Where a tall wall is cut short, the cut face is painted (sheet 11).
	for side in 2:
		var r: Array = r0 if side == 0 else r1
		if r[1]:
			var at: float = _lx(axis, from - float(r0[0]) if side == 0 else to + float(r1[0]))
			_rb(holder, Vector3(at, (bot + top) / 2, -WALL_T / 2), Vector3(0.03, top - bot, WALL_T), t().cut, 0.012)
	# Paint and paper on the room face, above the wainscot where there is one.
	for k in range(from, to):
		var f: String = plan.finishes.get(_edge(axis, line, k), "")
		if f == "":
			continue
		var y0 := 0.83 if dining and dining_floor(plan.kind(_room_cell(axis, line, k))) else 0.0
		var u0 := minf(_lx(axis, k), _lx(axis, k + 1))
		var u1 := maxf(_lx(axis, k), _lx(axis, k + 1))
		var stops: Array[float] = [u0, u1]
		for hole: Array in holes:
			for x: float in [hole[0], hole[1]]:
				if x > u0 and x < u1:
					stops.append(x)
		stops.sort()
		for i in stops.size() - 1:
			var mid := (stops[i] + stops[i + 1]) / 2
			var spans := [[y0, top]]
			for hole: Array in holes:
				if mid > hole[0] and mid < hole[1]:
					spans = [[y0, minf(top, hole[2])], [maxf(y0, hole[3]), top]]
			for sp: Array in spans:
				_finish_panel(holder, f, stops[i], stops[i + 1], sp[0], sp[1], 0.006)
	if dining:
		_wainscot(holder, plan, axis, line, from, to)
		for c in windows:
			_window(holder, c)
		# Sconces near each end of a back wall, where nothing is in the way.
		for k: float in ([from + 0.5, to - 0.45] if length >= 3 and axis == 0 else []):
			var x := _lx(axis, k)
			var clear := true
			for hole: Array in holes:
				if x + 0.15 > hole[0] and x - 0.15 < hole[1]:
					clear = false
			if clear:
				_sconce(holder, Vector3(x, 1.75, 0), Vector3(0, 0, 1), lights)


## Painted lower wall along the dining stretches of a tall run, broken at openings.
static func _wainscot(holder: Node3D, plan: Floorplan, axis: int, line: int, from: int, to: int) -> void:
	var k := from
	while k < to:
		var j := k
		while j < to and dining_floor(plan.kind(_room_cell(axis, line, j))) and not plan.openings.has(_edge(axis, line, j)):
			j += 1
		if j == k:
			k += 1
			continue
		var x0 := _lx(axis, k)
		var x1 := _lx(axis, j)
		var mid := (x0 + x1) / 2
		var span := absf(x1 - x0)
		if seaside():   # painted clapboard: seafoam and white boards
			for i in 7:
				Build.box(holder, Vector3(mid, 0.16 + i * 0.3, 0.015), Vector3(span, 0.3, 0.04), SEAFOAM if i % 2 == 0 else "#f6f8f1")
		else:   # teal wainscoting with a wooden rail
			Build.box(holder, Vector3(mid, 0, 0.02), Vector3(span, 0.82, 0.05), Build.CABINET)
			Build.box(holder, Vector3(mid, 0.8, 0.03), Vector3(span, 0.06, 0.09), Build.WOOD, 0.0, Build.R_WOOD)
		k = j


## A knee-high run: painted face, cream cap, gaps for doors, archways and the entrance.
static func _low_run(root: Node3D, plan: Floorplan, run: Dictionary, openings: Dictionary, entrance: Vector3i) -> void:
	var axis: int = run.axis
	var line: int = run.line
	var from: int = run.from
	var to: int = run.to
	var holder := _run_holder(root, axis, line)
	var reach := []
	for side in 2:
		var k: int = from if side == 0 else to
		var any := false
		for e in [_edge(1 - axis, k, line - 1), _edge(1 - axis, k, line)]:
			any = any or wall_look(plan, e) != ""
		reach.append(WALL_T / 2 if any else 0.0)
	var gaps: Array = []
	for k in range(from, to):
		var e := _edge(axis, line, k)
		if e == entrance:
			gaps.append(k)
			continue
		var what: String = plan.openings.get(e, "")
		if what != "":
			gaps.append(k)
			openings[e] = {"holder": _opening_holder(holder, _lx(axis, k + 0.5)), "kind": what, "tall": false}
	var k0 := from - float(reach[0])
	var stops: Array = gaps.duplicate()
	stops.append(to)
	for g: int in stops:
		var k1: float = g if g != to else to + float(reach[1])
		if k1 - k0 > 0.01:
			var x0 := minf(_lx(axis, k0), _lx(axis, k1))
			_wall(holder, Vector3(x0, 0, -WALL_T / 2), Vector3(absf(k1 - k0), CUT_H, WALL_T), t().cut)
		k0 = g + 1
	for k in range(from, to):   # paint and paper on both faces
		var f: String = plan.finishes.get(_edge(axis, line, k), "")
		if f != "":
			var x0 := minf(_lx(axis, k), _lx(axis, k + 1))
			for z: float in [WALL_T / 2 + 0.004, -WALL_T / 2 - 0.004]:
				_finish_panel(holder, f, x0, x0 + 1.0, 0.0, CUT_H - 0.13, z)
	if gaps.has(entrance.y) and axis == 1 and line == entrance.x:
		_doorway(_turned(root, Vector3(entrance.x, 0, entrance.y + 1)), Vector2i.ZERO, 0)


## The node a door or archway's own pieces hang from, at the middle of its gap.
static func _opening_holder(holder: Node3D, x: float) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(x, 0, 0)
	holder.add_child(n)
	return n


## Draws (or redraws) a door or archway's frame, leaf and threshold. One that
## nobody can get through is greyed out under a little warning sign.
static func dress_opening(info: Dictionary, ok: bool) -> void:
	var n: Node3D = info.holder
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
	var grey := "#b9b1ab"
	var frame: String = Build.CORAL if ok else grey
	var leaf: String = Build.CABINET if ok else "#a39b95"
	var tall: bool = info.tall
	var z := -WALL_T / 2 if tall else 0.0
	Build.box(n, Vector3(0, 0.0, z), Vector3(0.88, 0.012, WALL_T), Build.WOOD if ok else grey, 0.0, Build.R_WOOD)
	if info.kind == "door":
		if tall:   # a coral frame round the opening and a teal door standing ajar
			for sx: float in [-0.45, 0.45]:
				_rb(n, Vector3(sx, 1.0, z), Vector3(0.12, 2.06, WALL_T + 0.08), frame, 0.04)
			_rb(n, Vector3(0, 2.03, z), Vector3(1.02, 0.12, WALL_T + 0.08), frame, 0.04)
			var hinge := Node3D.new()
			hinge.position = Vector3(-0.4, 0, 0.0)
			hinge.rotation.y = -0.9
			n.add_child(hinge)
			_rb(hinge, Vector3(0.4, 0.98, 0.03), Vector3(0.8, 1.9, 0.06), leaf, 0.02)
			_rb(hinge, Vector3(0.4, 1.35, 0.065), Vector3(0.5, 0.6, 0.02), Build._tint(leaf, 0.07), 0.01)
			Build.ball(hinge, Vector3(0.7, 0.95, 0.09), 0.04, BRASS if ok else grey)
		else:   # cafe doors on low posts
			for sx: float in [-0.5, 0.5]:
				_rb(n, Vector3(sx, (CUT_H + 0.3) / 2, 0), Vector3(0.12, CUT_H + 0.3, WALL_T + 0.04), frame, 0.04)
				var hinge := Node3D.new()
				hinge.position = Vector3(sx * 0.88, 0, 0)
				hinge.rotation.y = 0.35 * signf(sx)
				n.add_child(hinge)
				_rb(hinge, Vector3(-sx * 0.42, 0.5, 0), Vector3(0.4, 0.5, 0.05), leaf, 0.02)
	else:
		if tall:   # a rounded coral rim inside the arch
			for sx: float in [-DOOR_R - 0.04, DOOR_R + 0.04]:
				_rb(n, Vector3(sx, 0.78, z), Vector3(0.08, 1.56, WALL_T + 0.06), frame, 0.03)
		else:   # two cream posts with round caps
			for sx: float in [-0.5, 0.5]:
				_rb(n, Vector3(sx, (CUT_H + 0.18) / 2, 0), Vector3(0.14, CUT_H + 0.18, WALL_T + 0.04), t().wall if ok else grey, 0.05)
				Build.ball(n, Vector3(sx, CUT_H + 0.22, 0), 0.09, frame)
	if not ok:
		var sign := Fx.card(Icons.icon("warning"), 0.26)
		sign.position = Vector3(0, (2.45 if tall else 1.9), z + 0.2)
		n.add_child(sign)
		if n.is_inside_tree():   # face the camera whichever way the wall runs
			sign.basis = n.global_basis.inverse() * sign.basis
		var bob := sign.create_tween().set_loops()
		bob.tween_property(sign, "position:y", sign.position.y + 0.08, 0.6).set_trans(Tween.TRANS_SINE)
		bob.tween_property(sign, "position:y", sign.position.y, 0.6).set_trans(Tween.TRANS_SINE)


static func _floors(root: Node3D, plan: Floorplan) -> void:
	var deep := -0.03 - PAPER_Y
	var columns := {}   # x -> sorted list of plank cells' y, for the boards
	for c: Vector2i in plan.floors:
		var k := plan.kind(c)
		# Floors are thick slabs of their own material on the sheet of paper (sheet 1).
		var base: String = {"tile": t().tile_a, "planks": t().planks[0], "parquet": PARQUET[1], "marble": VEIN}[k]
		Build.box(root, Vector3(c.x + 0.5, PAPER_Y, c.y + 0.5), Vector3(1.0, deep, 1.0), base, 0.0, Build.R_GLOSS if k == "tile" or k == "marble" else Build.R_WOOD)
		if k == "parquet":
			_parquet(root, c)
		elif k == "marble":
			_marble(root, c)
		elif k == "tile":
			var col: String = t().tile_b if posmod(c.x + c.y, 2) else t().tile_a
			Build.box(root, Vector3(c.x + 0.5, -0.03, c.y + 0.5), Vector3(0.985, 0.03, 0.985), col, 0.0, Build.R_GLOSS)
		else:
			if not columns.has(c.x):
				columns[c.x] = []
			columns[c.x].append(c.y)
	# Long boards running front to back, one staggered joint each (sheet 1).
	var tones: Array = t().planks
	for x: int in columns:
		var ys: Array = columns[x]
		ys.sort()
		var start: int = ys[0]
		for i in ys.size():
			if i < ys.size() - 1 and ys[i + 1] == ys[i] + 1:
				continue
			var end: int = ys[i] + 1
			for half in 2:
				var g := (x - 4) * 2 + half
				var joint := start + 2.2 + fposmod(g * 1.7, 3.0)
				var parts: Array = [[float(start), joint], [joint, float(end)]] if joint < end - 0.3 else [[float(start), float(end)]]
				for p: Array in parts:
					var length: float = p[1] - p[0]
					var board := Build.box(root, Vector3(x + half * 0.5 + 0.25, -0.03, p[0] + length / 2), Vector3(length - 0.02, 0.03, 0.48), tones[posmod(g + (1 if p[0] > start else 0), 3)], 0.0, Build.R_WOOD)
					board.rotation.y = PI / 2
			if i < ys.size() - 1:
				start = ys[i + 1]
	# A flat wooden threshold hides the seam between any two floors.
	for c: Vector2i in plan.floors:
		for e: Vector3i in [Vector3i(c.x, c.y, 0), Vector3i(c.x, c.y, 1)]:
			var s := Floorplan.sides(e)
			if plan.has_floor(s[1]) and plan.kind(s[1]) != plan.kind(c) and not plan.is_wall(e):
				if e.z == 0:
					Build.box(root, Vector3(c.x + 0.5, -0.004, c.y), Vector3(1.0, 0.012, 0.1), Build.WOOD, 0.0, Build.R_WOOD)
				else:
					Build.box(root, Vector3(c.x, -0.004, c.y + 0.5), Vector3(0.1, 0.012, 1.0), Build.WOOD, 0.0, Build.R_WOOD)


## A wall block from its low corner: one thick, soft-edged cream slab (the
## anchor frame). `face` paints a knee-high cutaway wall and gives it a cream cap.
## A crisp wall slab between two corners.
static func _slab(root: Node3D, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, col: String) -> void:
	_rb(root, Vector3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3(x1 - x0, y1 - y0, z1 - z0), col, 0.025)


## The piece of wall over a round-topped opening: flat from the arc up to `y1`.
static func _arch_header(root: Node3D, cx: float, r: float, spring: float, y1: float, z0: float, z1: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	for k in n:
		var a0 := PI - PI * k / n
		var a1 := PI - PI * (k + 1) / n
		var a := Vector2(cx + r * cos(a0), spring + r * sin(a0))
		var b := Vector2(cx + r * cos(a1), spring + r * sin(a1))
		Build._poly(st, [Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z1), Vector3(b.x, y1, z1), Vector3(a.x, y1, z1)], Vector3(0, 0, 1))
		Build._poly(st, [Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, y1, z0), Vector3(a.x, y1, z0)], Vector3(0, 0, -1))
		var mid := (a + b) / 2
		Build._poly(st, [Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)], Vector3(cx - mid.x, spring - mid.y, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Build.mat(Color(t().wall), 0.0, Build.R_MATTE, false)
	root.add_child(mi)


## The knee-high entrance wall from its low corner: a painted face under a flat
## cream cap, both crisp.
static func _wall(root: Node3D, from: Vector3, size: Vector3, face := "") -> void:
	var c := from + Vector3(size.x / 2, 0, size.z / 2)
	Build._add(root, Build.bevel_mesh(Vector3(size.x, size.y + 0.08, size.z), 0.025), c + Vector3(0, size.y / 2 - 0.16, 0), Color(face), 0.0)
	Build._add(root, Build.bevel_mesh(Vector3(size.x + 0.03, 0.12, size.z + 0.03), 0.02), c + Vector3(0, size.y - 0.06, 0), Color(t().wall), 0.0)


## A holder a quarter turn round, so pieces drawn along the x axis run along z:
## local (x, z) lands at `at` + (z, -x).
static func _turned(root: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.rotation.y = PI / 2
	root.add_child(n)
	return n


static func _doorway(root: Node3D, door: Vector2i, h: int) -> void:
	# A coral frame stands full height in the cutaway, with the hanging burger sign.
	# Thick, flat-fronted and softly rounded (sheet 1).
	for dx: float in [-0.04, 1.04]:
		_rb(root, Vector3(door.x + dx, 1.05, h), Vector3(0.27, 2.3, 0.34), Build.CORAL, 0.05)
	_rb(root, Vector3(door.x + 0.5, 2.13, h), Vector3(1.35, 0.27, 0.34), Build.CORAL, 0.05)
	Build.box(root, Vector3(door.x + 0.5, 0.0, h), Vector3(0.9, 0.012, 0.34), Build.WOOD, 0.0, Build.R_WOOD)
	Build.box(root, Vector3(door.x + 0.5, 0.0, h + 0.45), Vector3(0.8, 0.02, 0.5), Build.CORAL_DARK)
	var sign_at := Vector3(door.x + 0.5, 2.3, h)
	Build.box(root, sign_at, Vector3(0.9, 0.62, 0.1), Build.WOOD, 0.0, Build.R_WOOD)
	for side: float in [-1.0, 1.0]:
		var z := sign_at.z + side * 0.06
		Build.box(root, Vector3(sign_at.x, sign_at.y + 0.12, z), Vector3(0.5, 0.09, 0.04), "#e6a542")
		Build.box(root, Vector3(sign_at.x, sign_at.y + 0.21, z), Vector3(0.56, 0.07, 0.04), "#7a3b22")
		Build.box(root, Vector3(sign_at.x, sign_at.y + 0.28, z), Vector3(0.6, 0.04, 0.04), "#6fbf5f")
		Build.box(root, Vector3(sign_at.x, sign_at.y + 0.32, z), Vector3(0.5, 0.17, 0.04), "#e6a542")


static func _sconce(root: Node3D, at: Vector3, out: Vector3, lights: Array[OmniLight3D]) -> void:
	Build.box(root, at + out * 0.04 - Vector3(0, 0.1, 0), Vector3(0.1, 0.2, 0.1), Build.WOOD, 0.0, Build.R_WOOD)
	Build.ball(root, at + out * 0.16, 0.07, "#ffe9bd", 2.5)
	Build.lathe(root, at + out * 0.16 - Vector3(0, 0.07, 0), [[0.15, 0.0], [0.16, 0.01], [0.09, 0.2], [0.07, 0.2]], Build.CORAL, 0.25)
	var light := OmniLight3D.new()
	light.position = at + out * 0.5
	light.light_color = Color("#ffd9a0")
	light.light_energy = 1.0
	light.set_meta("full", 1.0)
	light.omni_range = 4.5
	root.add_child(light)
	lights.append(light)


static func _window(root: Node3D, x: float) -> void:
	if seaside():  # a round brass porthole on the same wall socket
		var ring := Build.lathe(root, Vector3(x, 1.5, 0.02), [[0.36, 0.0], [0.5, 0.0], [0.52, 0.03], [0.5, 0.09], [0.36, 0.09]], BRASS, 0.0, Build.R_WOOD)
		ring.rotation.x = PI / 2
		var glass := Build.lathe(root, Vector3(x, 1.5, 0.02), [[0.0, 0.05], [0.37, 0.05], [0.0, 0.051]], "#bfe6ea", 0.15, Build.R_GLOSS)
		glass.rotation.x = PI / 2
		return
	# A rounded coral frame lining a real opening: no glass, no sill (sheet 1).
	var mid_y := (WIN_Y0 + WIN_Y1) / 2
	var zc := -WALL_T / 2 + 0.02
	for sy: float in [WIN_Y0, WIN_Y1]:
		_rb(root, Vector3(x, sy, zc), Vector3(WIN_W + 0.14, 0.14, WALL_T + 0.1), Build.CORAL, 0.05)
	for sx: float in [-WIN_W / 2, WIN_W / 2]:
		_rb(root, Vector3(x + sx, mid_y, zc), Vector3(0.14, WIN_Y1 - WIN_Y0 + 0.14, WALL_T + 0.1), Build.CORAL, 0.05)


## True when every one of these edges is still a plain tall wall: the fixed
## dressing on the first room's walls stays only while its wall does.
static func _plain_tall(plan: Floorplan, edges: Array) -> bool:
	for e: Vector3i in edges:
		if wall_look(plan, e) != "tall" or plan.openings.has(e):
			return false
	return true


## The first room's fixtures: the hood, cabinets and jar shelf in the kitchen
## (sheet 1) and, by the sea, a life ring and a paddle on the dining wall.
static func _fixtures(root: Node3D, plan: Floorplan, lights: Array[OmniLight3D]) -> void:
	if _plain_tall(plan, [Vector3i(0, 3, 1), Vector3i(0, 4, 1)]):
		# A sloped hood over the two stoves.
		var hood := "#7fa3a8"
		var canopy := Build._add(root, Build.lathe_mesh([[0.0, 0.0], [1.36, 0.0], [1.36, 0.1], [0.62, 0.52], [0.0, 0.52]], 4), Vector3(0.37, 1.5, 4.0), Color(hood), 0.0, Build.R_WOOD)
		canopy.rotation.y = PI / 4
		var hold := Node3D.new()  # squash the square canopy to a 0.74 m deep, 1.9 m long one
		root.add_child(hold)
		canopy.reparent(hold)
		hold.scale = Vector3(0.39, 1, 1)
		hold.position.x = 0.37 - 0.37 * 0.39
		_rb(root, Vector3(0.22, 2.2, 4.0), Vector3(0.44, 0.44, 0.7), hood, 0.04, Build.R_WOOD)
	if _plain_tall(plan, [Vector3i(0, 5, 1), Vector3i(0, 6, 1)]):
		# A run of tall wall cabinets, where they cannot hide a stove or a dial.
		var z0 := 5.08
		Build._add(root, Build.bevel_mesh(Vector3(0.42, 0.92, 1.9), 0.04), Vector3(0.21, 1.86, z0 + 0.93), Color(Build.CABINET), 0.0)
		for i in 3:
			Build._add(root, Build.bevel_mesh(Vector3(0.03, 0.8, 0.56), 0.012), Vector3(0.43, 1.86, z0 + 0.33 + i * 0.62), Color(Build._tint(Build.CABINET, 0.07)), 0.0)
			Build._add(root, Build.bevel_mesh(Vector3(0.03, 0.16, 0.04), 0.012), Vector3(0.455, 1.6, z0 + 0.33 + i * 0.62 + (0.2 if i % 2 == 0 else -0.2)), Color("#d9a441"), 0.0, Build.R_WOOD)
	var kz := float(KITCHEN_Z)
	if _plain_tall(plan, [Vector3i(2, KITCHEN_Z, 0), Vector3i(3, KITCHEN_Z, 0)]):
		# A shelf of jars over the worktop.
		Build.box(root, Vector3(3.2, 1.5, kz + 0.12), Vector3(1.1, 0.06, 0.24), Build.WOOD, 0.0, Build.R_WOOD)
		var jars := [Build.PAPER, Build.CORAL, Build.TILE_TEAL, Build.WARN]
		for i in jars.size():
			Build.cyl(root, Vector3(2.8 + i * 0.27, 1.56, kz + 0.12), 0.09, 0.18 + 0.05 * (i % 2), jars[i], 0.0, Build.R_GLOSS)
			Build.cyl(root, Vector3(2.8 + i * 0.27, 1.74 + 0.05 * (i % 2), kz + 0.12), 0.07, 0.04, Build.WOOD_DARK)
	if _plain_tall(plan, [Vector3i(0, KITCHEN_Z, 1)]):
		_sconce(root, Vector3(0, 2.0, kz + 0.5), Vector3(1, 0, 0), lights)
	if seaside() and _plain_tall(plan, [Vector3i(6, 0, 0), Vector3i(7, 0, 0)]):
		var mid := 7.0
		var ring := Build.lathe(root, Vector3(mid - 0.35, 1.5, 0.03), [[0.2, 0.0], [0.36, 0.0], [0.38, 0.04], [0.36, 0.09], [0.2, 0.09], [0.18, 0.04], [0.2, 0.0]], "#fbf7ee")
		ring.rotation.x = PI / 2
		for i in 4:
			var band := Build.box(root, Vector3(mid - 0.35, 1.5, 0.03) + Vector3(0.28, 0, 0).rotated(Vector3(0, 0, 1), PI / 4 + i * PI / 2) - Vector3(0, 0.06, -0.01), Vector3(0.22, 0.12, 0.12), Build.DANGER)
			band.rotation.z = PI / 4 + i * PI / 2
		var paddle := Node3D.new()
		paddle.position = Vector3(mid + 0.55, 1.5, 0.05)
		paddle.rotation.z = 0.5
		root.add_child(paddle)
		Build.box(paddle, Vector3(0, -0.5, 0), Vector3(0.06, 0.8, 0.05), Build.WOOD, 0.0, Build.R_WOOD)
		Build.box(paddle, Vector3(0, 0.25, 0), Vector3(0.22, 0.42, 0.05), Build.WOOD, 0.0, Build.R_WOOD)


## A woven rug, 1.5 cm thick, for a 3 by 2 cell footprint: the anchor cell's
## middle is the origin and the rug runs one row toward +z (see Main.rug_cells).
static func rug(n: Node3D) -> void:
	var mid := Vector3(0, 0, 0.5)
	Build.box(n, mid, Vector3(2.8, 0.015, 1.7), "#e9dcc0")
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		Build.box(n, mid + Vector3(side * 1.12, 0.003, 0), Vector3(0.18, 0.015, 1.7), Build.CORAL)
		Build.box(n, mid + Vector3(side * 0.87, 0.003, 0), Vector3(0.1, 0.015, 1.7), Build.CABINET)
		for j in 7:   # fringe
			Build.box(n, mid + Vector3(side * 1.44, 0, -0.72 + j * 0.24), Vector3(0.08, 0.008, 0.05), "#f6eedd")
	Build.box(n, mid + Vector3(0, 0.003, 0), Vector3(0.5, 0.015, 0.5), Build.CORAL).rotation.y = PI / 4


## Floors a dining room can have: wainscot and windows go on their back walls.
static func dining_floor(k: String) -> bool:
	return k != "" and k != "tile"


const PARQUET: Array[String] = ["#c99a5b", "#b8854a", "#d6aa6c"]
const MARBLE := "#dedbd2"
const MARBLE_B := "#9eb1ad"
const VEIN := "#7d8a88"
const SAGE := "#a8c6a0"
const STRIPE := ["#f7e6d6", "#e9a998"]
const ROSE := ["#7e3a4c", "#e3b25a"]


## Basket-weave parquet: four squares of three slats, turned alternately.
static func _parquet(root: Node3D, c: Vector2i) -> void:
	for i in 2:
		for j in 2:
			var turn := (i + j) % 2 == 1
			for s in 3:
				var off := -0.16 + s * 0.16
				var at := Vector3(c.x + 0.25 + i * 0.5 + (off if turn else 0.0), -0.03, c.y + 0.25 + j * 0.5 + (0.0 if turn else off))
				Build.box(root, at, Vector3(0.155 if turn else 0.48, 0.03, 0.48 if turn else 0.155), PARQUET[posmod(s + i * 2 + j + c.x + c.y, 3)], 0.0, Build.R_WOOD)


## A polished marble slab a cell across, with two grey veins.
static func _marble(root: Node3D, c: Vector2i) -> void:
	Build.box(root, Vector3(c.x + 0.5, -0.03, c.y + 0.5), Vector3(0.985, 0.03, 0.985), MARBLE if posmod(c.x + c.y, 2) == 0 else MARBLE_B, 0.0, Build.R_GLOSS)
	var h := posmod(c.x * 7 + c.y * 13, 5)
	for v in 2:
		var vein := Build.box(root, Vector3(c.x + 0.3 + 0.4 * v, -0.0005, c.y + 0.5), Vector3(0.022, 0.002, 0.7 - 0.1 * v), VEIN, 0.0, Build.R_GLOSS)
		vein.rotation.y = 0.5 + 0.35 * h - 1.1 * v


## Paint or wallpaper on a wall face from local x0 to x1 and y0 to y1, as a thin
## sheet centred on local z.
static func _finish_panel(holder: Node3D, f: String, x0: float, x1: float, y0: float, y1: float, z: float) -> void:
	if x1 - x0 < 0.01 or y1 - y0 < 0.01:
		return
	var w := x1 - x0
	var mid := Vector3((x0 + x1) / 2, y0, z)
	match f:
		"paint":
			Build.box(holder, mid, Vector3(w, y1 - y0, 0.008), SAGE)
		"paper_stripe":   # broad cream and coral-pink stripes
			Build.box(holder, mid, Vector3(w, y1 - y0, 0.008), STRIPE[0])
			var x := ceilf(x0 / 0.25) * 0.25 + 0.0625
			while x + 0.0625 <= x1 + 0.001:
				Build.box(holder, Vector3(x, y0, z), Vector3(0.1, y1 - y0, 0.012), STRIPE[1])
				x += 0.25
		"paper_rose":   # deep rose with small gold diamonds
			Build.box(holder, mid, Vector3(w, y1 - y0, 0.008), ROSE[0])
			var row := 0
			var y := ceilf((y0 + 0.1) / 0.3) * 0.3
			while y < y1 - 0.08:
				var x := ceilf(x0 / 0.3) * 0.3 + (0.15 if row % 2 else 0.0)
				while x < x1 - 0.06:
					if x > x0 + 0.06:
						Build.box(holder, Vector3(x, y - 0.035, z), Vector3(0.07, 0.07, 0.012), ROSE[1]).rotation.z = PI / 4
					x += 0.3
				y += 0.3
				row += 1


## A planter and the menu board outside, on the near side of the door.
static func _outside(root: Node3D, w: int, h: int) -> void:
	root = _turned(root, Vector3(w - h, 0, 9.5))
	for px: float in [3.2]:
		Build.box(root, Vector3(px, 0, h + 0.3), Vector3(1.2, 0.55, 0.34), Build.WOOD, 0.0, Build.R_WOOD)
		for i in 3:
			Build.ball(root, Vector3(px - 0.38 + i * 0.38, 0.6, h + 0.3), 0.2, Build.LEAF if i % 2 else Build.LEAF_2)
	for lean: float in [-1.0, 1.0]:
		var board := Build.box(root, Vector3(4.2, 0, h + 0.34 + lean * 0.09), Vector3(0.5, 0.78, 0.05), Build.WOOD, 0.0, Build.R_WOOD)
		board.rotation.x = -lean * 0.22
		var slate := Build.box(root, Vector3(4.2, 0.14, h + 0.34 + lean * 0.115), Vector3(0.4, 0.5, 0.03), "#3f4a45")
		slate.rotation.x = -lean * 0.22


## Little models of the build tools for the shop.
static func tool_preview(n: Node3D, id: String) -> void:
	var plan := Floorplan.new(Rect2i(-2, -2, 4, 4))
	match id:
		"floor_tile", "floor_planks", "floor_parquet", "floor_marble":
			plan.fill(Rect2i(-1, -1, 2, 2), id.trim_prefix("floor_"))
			_floors(n, plan)
			n.position.y = 0.25
		"paint", "paper_stripe", "paper_rose":   # a short stretch of tall wall
			_slab(n, -0.75, 0.75, 0.0, 1.4, -WALL_T, 0.0, t().wall)
			_finish_panel(n, id, -0.75, 0.75, 0.0, 1.4, 0.006)
			n.position.y = -0.3
		"wall":
			_wall(n, Vector3(-0.75, 0, -WALL_T / 2), Vector3(1.5, CUT_H, WALL_T), t().cut)
			n.position.y = 0.2
		_:
			_wall(n, Vector3(-1.0, 0, -WALL_T / 2), Vector3(0.5, CUT_H, WALL_T), t().cut)
			_wall(n, Vector3(0.5, 0, -WALL_T / 2), Vector3(0.5, CUT_H, WALL_T), t().cut)
			var o := Node3D.new()
			n.add_child(o)
			dress_opening({"holder": o, "kind": id, "tall": false}, true)
			n.position.y = 0.1


## The street and the sheet of paper everything rests on. Everything ends
## cleanly at its own edge: no fade.
static func _ground(root: Node3D, w: int, lights: Array[OmniLight3D]) -> void:
	# The street rule. The street runs the length of the entrance wall. Its near
	# end stops flush with the near edge of the floor. Its far end runs on past the
	# tall wall that heads toward the street, to the point where the street's edge
	# sits on the line of that wall's top edge as the camera sees it.
	X0 = w - 7.0
	var x1 := w + WALL_T + WALL_H * CAM_RISE
	var cx := (X0 + x1) / 2
	var span := x1 - X0
	# No base board: floors and paving are thick slabs of their own material that
	# rest straight on a sheet of paper, which catches every shadow (sheet 1).
	var paper := MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(400, 400)
	paper.mesh = sheet
	paper.position = Vector3(cx, PAPER_Y, (Z0 + Z1) / 2)
	var sheet_mat: ShaderMaterial = Build.mat(Color(t().backdrop).darkened(0.07), 0.0, Build.R_MATTE, false).duplicate()
	sheet_mat.set_shader_parameter("vignette", 0.16)  # the sheet darkens gently toward its corners
	sheet_mat.set_shader_parameter("vignette_centre", Vector2(w / 2.0 + 1.0, 3.5))
	paper.material_override = sheet_mat
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(paper)
	# The street is drawn along x and turned to run down the right-hand side.
	var street := _turned(root, Vector3(w - 7.0, 0, w))
	if seaside():
		_pier(street, w, x1)
	else:
		_street(street, w, x1, lights)


static func _street(root: Node3D, w: int, x1: float, lights: Array[OmniLight3D]) -> void:
	# Grey paving slabs, with a paler kerb row along the road.
	var x := X0
	var col_i := 0
	while x < x1 - 0.01:
		var wd := minf(1.5, x1 - x)  # big slabs; the last is cut to the street's end
		for row in 2:
			var depth := (PAVE_Z - 7.0) / 2
			Build.box(root, Vector3(x + wd / 2, PAPER_Y, 7.0 + row * depth + depth / 2), Vector3(wd - 0.02, -PAPER_Y, depth - 0.02), Build.PAVING if (col_i + row) % 2 else "#c4bcb4")
		x += 1.5
		col_i += 1
	# A two-lane road with white dashes, cut clean at the slab edge.
	Build.box(root, Vector3((X0 + x1) / 2, PAPER_Y, (PAVE_Z + Z1) / 2), Vector3(x1 - X0, 0.12, Z1 - PAVE_Z), Build.ROAD)
	x = X0 + 0.7
	while x < x1 - 1.0:
		Build.box(root, Vector3(x + 0.5, -0.085, (PAVE_Z + Z1) / 2), Vector3(1.0, 0.012, 0.13), "#f6efe2")
		x += 2.2
	# Street furniture sits on the kerb side only, never over the queue line.
	var kerb := PAVE_Z - 0.45
	# Tall things stand at the far end, where they hide nothing; low ones near.
	_tree(root, Vector3(x1 - 0.65, 0, kerb - 0.05))
	_lamp_post(root, Vector3(x1 - 2.4, 0, kerb), lights)
	_bench(root, Vector3(X0 + 2.0, 0, kerb))
	_street_bin(root, Vector3(X0 + 0.6, 0, kerb))
	_bike(root, Vector3(X0 + 4.0, 0, kerb))


## A soft-cornered block centred on `at`.
static func _rb(root: Node3D, at: Vector3, size: Vector3, col: String, bevel := 0.05, rough := Build.R_MATTE) -> MeshInstance3D:
	return Build._add(root, Build.bevel_mesh(size, bevel), at, Color(col), 0.0, rough)


## Sheet 12: a chunky trunk with two branch stubs under a crown of billowing
## lobes, in a stone surround with a square of grass.
static func _tree(root: Node3D, at: Vector3) -> void:
	var bark := "#a8703f"
	_rb(root, at + Vector3(0, 0.09, 0), Vector3(1.0, 0.18, 1.0), "#bdb5a8", 0.07)
	_rb(root, at + Vector3(0, 0.16, 0), Vector3(0.74, 0.1, 0.74), "#8fbf6a", 0.04)
	Build.lathe(root, at + Vector3(0, 0.18, 0), [[0.0, 0.0], [0.3, 0.0], [0.22, 0.14], [0.17, 0.45], [0.16, 0.9], [0.21, 1.2], [0.0, 1.2]], bark, 0.0, Build.R_WOOD)
	for side: float in [-1.0, 1.0]:
		var stub := Build.lathe(root, at + Vector3(side * 0.1, 1.0, 0.05 * side), [[0.0, 0.0], [0.1, 0.0], [0.085, 0.5], [0.0, 0.5]], bark, 0.0, Build.R_WOOD)
		stub.rotation.z = -side * 0.75
	var crown := at + Vector3(0, 2.0, 0)
	Build.ball(root, crown, 0.62, "#4f9a63")
	for i in 6:
		var a := TAU * i / 6.0
		Build.ball(root, crown + Vector3(cos(a) * 0.46, -0.2 + 0.14 * (i % 2), sin(a) * 0.46), 0.37, Build.LEAF if i % 2 else Build.LEAF_2)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		Build.ball(root, crown + Vector3(cos(a) * 0.27, 0.42, sin(a) * 0.27), 0.34, Build.LEAF_2 if i % 2 else Build.LEAF)
	Build.ball(root, crown + Vector3(0, 0.72, 0), 0.27, Build.LEAF_2)


## Sheet 12: thick rounded slats on dark, chunky legs; the back leans away.
static func _bench(root: Node3D, at: Vector3) -> void:
	var leg := "#5a3f2e"
	for i in 4:
		_rb(root, at + Vector3(0, 0.44, -0.2 + i * 0.15), Vector3(1.6, 0.075, 0.13), Build.WOOD, 0.03, Build.R_WOOD)
	for i in 3:
		_rb(root, at + Vector3(0, 0.63 + i * 0.17, 0.37 + i * 0.035), Vector3(1.6, 0.15, 0.065), Build.WOOD, 0.03, Build.R_WOOD).rotation.x = 0.2
	for sx: float in [-0.62, 0.62]:
		_rb(root, at + Vector3(sx, 0.2, -0.2), Vector3(0.12, 0.4, 0.13), leg, 0.045)
		_rb(root, at + Vector3(sx, 0.52, 0.33), Vector3(0.12, 1.04, 0.13), leg, 0.045).rotation.x = 0.2
		_rb(root, at + Vector3(sx, 0.37, 0.04), Vector3(0.12, 0.09, 0.6), leg, 0.04)


## Sheet 12: a teal drum with a thick dark rim.
static func _street_bin(root: Node3D, at: Vector3) -> void:
	Build.lathe(root, at, [[0.0, 0.0], [0.23, 0.0], [0.26, 0.04], [0.275, 0.32], [0.26, 0.62], [0.0, 0.62]], Build.CABINET)
	Build.lathe(root, at, [[0.2, 0.6], [0.29, 0.6], [0.315, 0.66], [0.29, 0.72], [0.2, 0.72], [0.2, 0.6]], "#4a372c")
	Build.cyl(root, at + Vector3(0, 0.63, 0), 0.2, 0.02, "#173f47")


## Sheet 12: a wooden balance bike. Wooden wheels with dark tyres, a chunky coral
## frame, a wooden saddle and handlebar, a steel fork.
static func _bike(root: Node3D, at: Vector3) -> void:
	var wood := "#dba865"
	var bike := Node3D.new()
	bike.position = at
	bike.rotation.y = 0.45
	root.add_child(bike)
	for sx: float in [-0.45, 0.45]:
		var wheel := Node3D.new()
		wheel.position = Vector3(sx, 0.3, 0)
		wheel.rotation.x = PI / 2
		bike.add_child(wheel)
		Build.lathe(wheel, Vector3.ZERO, [[0.0, -0.035], [0.22, -0.035], [0.22, 0.035], [0.0, 0.035]], wood, 0.0, Build.R_WOOD)
		Build.lathe(wheel, Vector3.ZERO, [[0.21, -0.05], [0.28, -0.05], [0.3, 0.0], [0.28, 0.05], [0.21, 0.05], [0.21, -0.05]], "#4a372c")
		Build.lathe(wheel, Vector3.ZERO, [[0.0, -0.06], [0.05, -0.06], [0.05, 0.06], [0.0, 0.06]], Build.CORAL)
	_rb(bike, Vector3(-0.05, 0.47, 0), Vector3(0.8, 0.14, 0.1), Build.CORAL, 0.05).rotation.z = 0.28
	_rb(bike, Vector3(-0.32, 0.52, 0), Vector3(0.1, 0.36, 0.1), Build.CORAL, 0.04)
	_rb(bike, Vector3(-0.32, 0.74, 0), Vector3(0.32, 0.1, 0.18), wood, 0.045, Build.R_WOOD)
	_rb(bike, Vector3(0.38, 0.58, 0), Vector3(0.08, 0.68, 0.08), "#9aa3a6", 0.035, Build.R_WOOD).rotation.z = 0.25
	_rb(bike, Vector3(0.3, 0.93, 0), Vector3(0.09, 0.09, 0.5), wood, 0.04, Build.R_WOOD)
	for sz: float in [-0.25, 0.25]:
		Build.ball(bike, Vector3(0.3, 0.93, sz), 0.065, Build.CORAL)


## Sheet 12: a stepped foot, a slim column and a four-sided lantern that widens
## upward under a peaked cap with a finial.
static func _lamp_post(root: Node3D, at: Vector3, lights: Array[OmniLight3D]) -> void:
	var iron := "#4a372c"
	Build.lathe(root, at, [[0.0, 0.0], [0.2, 0.0], [0.22, 0.05], [0.2, 0.1], [0.13, 0.14], [0.12, 0.3], [0.14, 0.36], [0.075, 0.46], [0.06, 0.6], [0.06, 2.0], [0.11, 2.05], [0.11, 2.12], [0.0, 2.12]], iron, 0.0, Build.R_WOOD)
	Build._add(root, Build.lathe_mesh([[0.0, 0.0], [0.12, 0.0], [0.19, 0.34], [0.0, 0.34]], 4), at + Vector3(0, 2.12, 0), Color("#ffe2a6"), 1.4).rotation.y = PI / 4
	Build._add(root, Build.lathe_mesh([[0.0, 0.0], [0.26, 0.0], [0.26, 0.05], [0.08, 0.17], [0.0, 0.17]], 4), at + Vector3(0, 2.46, 0), Color(iron), 0.0, Build.R_WOOD).rotation.y = PI / 4
	Build.ball(root, at + Vector3(0, 2.67, 0), 0.055, iron)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 2.3, 0)
	light.light_color = Color("#ffd9a0")
	light.set_meta("full", 0.8)
	light.omni_range = 4.0
	root.add_child(light)
	lights.append(light)


## Seaside: a weathered boardwalk with rope-and-post bollards, and a strip of
## turquoise sea with white foam in place of the road.
static func _pier(root: Node3D, w: int, x1: float) -> void:
	var tones := ["#b79a78", "#a98d6c", "#c2a684"]
	var i := 0
	var x := X0
	while x < x1 - 0.01:
		var wd := minf(0.5, x1 - x)
		Build.box(root, Vector3(x + wd / 2, PAPER_Y, (7.0 + PAVE_Z) / 2), Vector3(wd - 0.015, -PAPER_Y, PAVE_Z - 7.0), tones[i % 3], 0.0, Build.R_WOOD)
		x += 0.5
		i += 1
	Build.box(root, Vector3((X0 + x1) / 2, PAPER_Y, (PAVE_Z + Z1) / 2), Vector3(x1 - X0, 0.12, Z1 - PAVE_Z), "#4fc3c8", 0.0, 0.25)
	x = X0 + 0.3
	i = 0
	while x < x1:
		Build.ball(root, Vector3(x, -0.08, PAVE_Z + 0.12 + 0.1 * (i % 2)), 0.2 + 0.06 * (i % 3), "#ffffff").scale = Vector3(1.3, 0.25, 1)
		if i % 3 == 0:
			Build.ball(root, Vector3(x + 0.4, -0.085, PAVE_Z + 1.2 + 0.5 * (i % 2)), 0.3, "#8fdde0").scale = Vector3(1.8, 0.12, 0.5)
		x += 0.55
		i += 1
	var rail := PAVE_Z - 0.2
	x = X0 + 0.3
	while x < x1:
		Build.cyl(root, Vector3(x, 0, rail), 0.09, 0.62, Build.WOOD_DARK, 0.0, Build.R_WOOD)
		Build.ball(root, Vector3(x, 0.64, rail), 0.11, Build.WOOD_DARK)
		if x + 1.5 < x1:
			for k in 5:
				var u := (k + 0.5) / 5.0
				Build.ball(root, Vector3(x + u * 1.5, 0.5 - sin(u * PI) * 0.14, rail), 0.045, "#e8dcc0").scale = Vector3(4.0, 1, 1)
		x += 1.5
