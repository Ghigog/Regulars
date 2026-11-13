class_name Scenery
extends RefCounted
## The room itself: floors, walls, the knee-high cutaway, windows, wall art and
## lights (style guide, sheets 10 and 11). No gameplay lives here.

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


## Builds the room and returns its practical lights so the day can dim them.
static func build(root: Node3D, w: int, h: int, door: Vector2i) -> Array[OmniLight3D]:
	var lights: Array[OmniLight3D] = []
	_ground(root, w, lights)
	_floors(root, w, h)
	# Tall walls: each run is a union of overlapping slabs, so corners and the
	# pieces round an opening join without a seam. Crisp 2.5 cm edges, flat tops.
	var top := WALL_H
	var bot := -0.2
	var xa := KITCHEN_W - WALL_T
	var xb := w + WALL_T / 2
	if seaside():  # portholes sit on a solid wall
		_slab(root, xa, xb, bot, top, -WALL_T, 0, t().wall)
	else:  # two real window openings (sheet 1)
		_slab(root, xa, xb, bot, WIN_Y0 + 0.05, -WALL_T, 0, t().wall)
		_slab(root, xa, xb, WIN_Y1 - 0.05, top, -WALL_T, 0, t().wall)
		var edges: Array[float] = [xa]
		for c: float in [KITCHEN_W + 1.55, w - 1.55]:
			edges.append_array([c - WIN_W / 2, c + WIN_W / 2])
		edges.append(xb)
		for i in range(0, edges.size(), 2):
			_slab(root, edges[i], edges[i + 1], WIN_Y0 - 0.05, WIN_Y1 + 0.05, -WALL_T, 0, t().wall)
	_slab(root, xa, KITCHEN_W, bot, top, -WALL_T, KITCHEN_Z, t().wall)                  # the jog
	_slab(root, -WALL_T, 0, bot, top, KITCHEN_Z - WALL_T, h, t().wall)                  # kitchen, left
	# Kitchen, back: a round-topped way through to the back room.
	var zk := float(KITCHEN_Z)
	_slab(root, -WALL_T, DOOR_X - DOOR_R, bot, top, zk - WALL_T, zk, t().wall)
	_slab(root, DOOR_X + DOOR_R, KITCHEN_W, bot, top, zk - WALL_T, zk, t().wall)
	_slab(root, DOOR_X - DOOR_R - 0.1, DOOR_X + DOOR_R + 0.1, 2.15, top, zk - WALL_T, zk, t().wall)
	_arch_header(root, DOOR_X, DOOR_R, 1.55, 2.2, zk - WALL_T + 0.004, zk - 0.004)
	for i in 4:  # the back room's floor, seen through the opening
		Build.box(root, Vector3(DOOR_X - 0.25 + (i % 2) * 0.5, -0.03, zk - WALL_T - 0.25 - (i / 2) * 0.5), Vector3(0.49, 0.03, 0.49), t().tile_b if (i + i / 2) % 2 else t().tile_a, 0.0, Build.R_GLOSS)
	Build.box(root, Vector3(DOOR_X, PAPER_Y, zk - WALL_T - 0.5), Vector3(1.0, -0.03 - PAPER_Y, 1.0), t().tile_a)
	# Where a tall wall is cut short, the cut face is painted (sheet 11).
	_rb(root, Vector3(xb, (bot + top) / 2, -WALL_T / 2), Vector3(0.03, top - bot, WALL_T), t().cut, 0.012)
	_rb(root, Vector3(-WALL_T / 2, (bot + top) / 2, h), Vector3(WALL_T, top - bot, 0.03), t().cut, 0.012)
	# The entrance wall, on the right, drops to a knee-high cutaway with the
	# doorway in it. The near-left side has no wall at all: the floor simply ends
	# (sheet 1). No transparency.
	_wall(root, Vector3(w - WALL_T / 2, 0, -0.05), Vector3(WALL_T, CUT_H, door.y + 0.05), t().cut)
	_wall(root, Vector3(w - WALL_T / 2, 0, door.y + 1), Vector3(WALL_T, CUT_H, h - door.y - 1), t().cut)
	_doorway(_turned(root, Vector3(w, 0, door.y + 1)), Vector2i.ZERO, 0)
	_dining_wall(root, w, lights)
	_kitchen_wall(root, h, lights)
	_dressing(root, w, h)
	return lights


static func _floors(root: Node3D, w: int, h: int) -> void:
	for x in KITCHEN_W:
		for y in range(KITCHEN_Z, h):
			var col: String = t().tile_b if (x + y) % 2 else t().tile_a
			Build.box(root, Vector3(x + 0.5, -0.03, y + 0.5), Vector3(0.985, 0.03, 0.985), col, 0.0, Build.R_GLOSS)
	# Dining: long boards running front to back, one staggered joint each (sheet 1).
	var tones: Array = t().planks
	for i in (w - KITCHEN_W) * 2:
		var joint := 2.2 + fmod(i * 1.7, 3.0)
		for part: Array in [[0.0, joint], [joint, float(h)]]:
			var length: float = part[1] - part[0]
			var board := Build.box(root, Vector3(KITCHEN_W + i * 0.5 + 0.25, -0.03, part[0] + length / 2), Vector3(length - 0.02, 0.03, 0.48), tones[(i + (1 if part[0] > 0.0 else 0)) % 3], 0.0, Build.R_WOOD)
			board.rotation.y = PI / 2
	# A flat wooden threshold hides the seam between any two floors.
	Build.box(root, Vector3(KITCHEN_W, -0.004, (KITCHEN_Z + h) / 2.0), Vector3(0.1, 0.012, h - KITCHEN_Z), Build.WOOD, 0.0, Build.R_WOOD)


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


static func _dining_wall(root: Node3D, w: int, lights: Array[OmniLight3D]) -> void:
	var span := float(w - KITCHEN_W)
	var mid := KITCHEN_W + span / 2
	if seaside():
		# Painted clapboard: seafoam and white boards the length of the wall.
		for i in 7:
			Build.box(root, Vector3(mid, 0.16 + i * 0.3, 0.015), Vector3(span, 0.3, 0.04), SEAFOAM if i % 2 == 0 else "#f6f8f1")
		# A life ring and a wooden paddle.
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
	else:
		# Teal wainscoting with a wooden rail.
		Build.box(root, Vector3(mid, 0, 0.02), Vector3(span, 0.82, 0.05), Build.CABINET)
		Build.box(root, Vector3(mid, 0.8, 0.03), Vector3(span, 0.06, 0.09), Build.WOOD, 0.0, Build.R_WOOD)
	_window(root, KITCHEN_W + 1.55)
	_window(root, w - 1.55)
	_sconce(root, Vector3(KITCHEN_W + 0.5, 1.75, 0), Vector3(0, 0, 1), lights)
	_sconce(root, Vector3(w - 0.45, 1.75, 0), Vector3(0, 0, 1), lights)


static func _kitchen_wall(root: Node3D, h: int, lights: Array[OmniLight3D]) -> void:
	# Wall cabinets over the sink side, where they cannot hide a stove or a dial.
	# Sheet 1: a sloped hood over the two stoves and a run of tall wall cabinets.
	var hood := "#7fa3a8"
	var canopy := Build._add(root, Build.lathe_mesh([[0.0, 0.0], [1.36, 0.0], [1.36, 0.1], [0.62, 0.52], [0.0, 0.52]], 4), Vector3(0.37, 1.5, 4.0), Color(hood), 0.0, Build.R_WOOD)
	canopy.rotation.y = PI / 4
	canopy.scale = Vector3(1, 1, 1)
	var hold := Node3D.new()  # squash the square canopy to a 0.74 m deep, 1.9 m long one
	root.add_child(hold)
	canopy.reparent(hold)
	hold.scale = Vector3(0.39, 1, 1)
	hold.position.x = 0.37 - 0.37 * 0.39
	_rb(root, Vector3(0.22, 2.2, 4.0), Vector3(0.44, 0.44, 0.7), hood, 0.04, Build.R_WOOD)
	var z0 := 5.08
	Build._add(root, Build.bevel_mesh(Vector3(0.42, 0.92, 1.9), 0.04), Vector3(0.21, 1.86, z0 + 0.93), Color(Build.CABINET), 0.0)
	for i in 3:
		Build._add(root, Build.bevel_mesh(Vector3(0.03, 0.8, 0.56), 0.012), Vector3(0.43, 1.86, z0 + 0.33 + i * 0.62), Color(Build._tint(Build.CABINET, 0.07)), 0.0)
		Build._add(root, Build.bevel_mesh(Vector3(0.03, 0.16, 0.04), 0.012), Vector3(0.455, 1.6, z0 + 0.33 + i * 0.62 + (0.2 if i % 2 == 0 else -0.2)), Color("#d9a441"), 0.0, Build.R_WOOD)
	# A shelf of jars over the worktop.
	Build.box(root, Vector3(3.2, 1.5, KITCHEN_Z + 0.12), Vector3(1.1, 0.06, 0.24), Build.WOOD, 0.0, Build.R_WOOD)
	var jars := [Build.PAPER, Build.CORAL, Build.TILE_TEAL, Build.WARN]
	for i in jars.size():
		Build.cyl(root, Vector3(2.8 + i * 0.27, 1.56, KITCHEN_Z + 0.12), 0.09, 0.18 + 0.05 * (i % 2), jars[i], 0.0, Build.R_GLOSS)
		Build.cyl(root, Vector3(2.8 + i * 0.27, 1.74 + 0.05 * (i % 2), KITCHEN_Z + 0.12), 0.07, 0.04, Build.WOOD_DARK)
	_sconce(root, Vector3(0, 2.0, KITCHEN_Z + 0.5), Vector3(1, 0, 0), lights)


static func _dressing(root: Node3D, w: int, h: int) -> void:
	# Woven rug, 1.5 cm thick, under the middle table.
	Build.box(root, Vector3(8.5, 0, 3.5), Vector3(3.1, 0.015, 1.6), "#e9dcc0")
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		Build.box(root, Vector3(8.5 + side * 1.2, 0.003, 3.5), Vector3(0.18, 0.015, 1.6), Build.CORAL)
		Build.box(root, Vector3(8.5 + side * 0.95, 0.003, 3.5), Vector3(0.1, 0.015, 1.6), Build.CABINET)
	# A planter and the menu board outside, on the near side of the door.
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
	var deep := -0.03 - PAPER_Y
	Build.box(root, Vector3(KITCHEN_W / 2.0, PAPER_Y, (KITCHEN_Z + 7.0) / 2.0), Vector3(KITCHEN_W, deep, 7.0 - KITCHEN_Z), t().tile_a)
	Build.box(root, Vector3((KITCHEN_W + w) / 2.0, PAPER_Y, 3.5), Vector3(w - KITCHEN_W, deep, 7.0), t().planks[0], 0.0, Build.R_WOOD)
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
