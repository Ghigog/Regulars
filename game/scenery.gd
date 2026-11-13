class_name Scenery
extends RefCounted
## The room itself: floors, walls, the knee-high cutaway, windows, wall art and
## lights (style guide, sheets 10 and 11). No gameplay lives here.

const WALL_H := 2.4
const WALL_T := 0.3
const CUT_H := 0.55
const KITCHEN_W := 4
## A theme is a re-skin of the same kit (sheet 16): grid, stations, heights and
## bevels never change; walls, windows, floors, wall art and the slab edge do.
const THEMES := {
	"diner": {
		"backdrop": "#d9cfc1", "wall": "#f6eedd", "wall_low": "#eadfcb", "cut": "#f07a63",
		"tile_a": "#236a74", "tile_b": "#f1e8cc", "planks": ["#bd7d49", "#b47443", "#c4864f"],
		"lawn": "#b9c990", "hedge": "#5fa873", "slab": "#4a3a2e",
	},
	"seaside": {
		"backdrop": "#e4ebe0", "wall": "#f3f5ee", "wall_low": "#dde5dc", "cut": "#bfe0d2",
		"tile_a": "#a8dccb", "tile_b": "#f4efe0", "planks": ["#b9b1a4", "#aaa295", "#c6bfb2"],
		"lawn": "#ead9b0", "hedge": "#8fb98a", "slab": "#4a3a2e",
	},
}
const SEAFOAM := "#bfe0d2"
const BRASS := "#d9a441"
const X0 := -2.6    # the slab everything stands on
const Z0 := -1.2
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
	# Far walls stand full height, just outside the floor.
	_wall(root, Vector3(-WALL_T, 0, -WALL_T), Vector3(w + WALL_T * 2, WALL_H, WALL_T))
	_wall(root, Vector3(-WALL_T, 0, 0), Vector3(WALL_T, WALL_H, h + WALL_T / 2))
	# Walls that face the camera drop to a knee-high cutaway. No transparency.
	_wall(root, Vector3(0, 0, h - WALL_T / 2), Vector3(door.x, CUT_H, WALL_T), t().cut)
	_wall(root, Vector3(door.x + 1, 0, h - WALL_T / 2), Vector3(w - door.x - 1 + WALL_T, CUT_H, WALL_T), t().cut)
	_wall(root, Vector3(w, 0, 0), Vector3(WALL_T, CUT_H, h - WALL_T / 2), t().cut)
	_doorway(root, door, h)
	_dining_wall(root, w, lights)
	_kitchen_wall(root, h, lights)
	_dressing(root, w, h)
	return lights


static func _floors(root: Node3D, w: int, h: int) -> void:
	for x in KITCHEN_W:
		for y in h:
			var col: String = t().tile_b if (x + y) % 2 else t().tile_a
			Build.box(root, Vector3(x + 0.5, -0.03, y + 0.5), Vector3(0.985, 0.03, 0.985), col, 0.0, Build.R_GLOSS)
	# Dining: oak planks, half a metre wide, with staggered joints.
	var tones: Array = t().planks
	for r in h * 2:
		var cuts: Array[float] = [float(KITCHEN_W)]
		var x := KITCHEN_W + 0.7 + fmod(r * 0.9, 1.6)
		while x < w - 0.3:
			cuts.append(x)
			x += 2.0
		cuts.append(float(w))
		for i in cuts.size() - 1:
			var length := cuts[i + 1] - cuts[i]
			Build.box(root, Vector3(cuts[i] + length / 2, -0.03, r * 0.5 + 0.25), Vector3(length - 0.012, 0.03, 0.488), tones[(r + i * 2) % 3], 0.0, Build.R_WOOD)
	# A flat wooden threshold hides the seam between any two floors.
	Build.box(root, Vector3(KITCHEN_W, -0.004, h / 2.0), Vector3(0.1, 0.012, h), Build.WOOD, 0.0, Build.R_WOOD)


## A wall block from its low corner: one thick, soft-edged cream slab (the
## anchor frame). `face` paints a knee-high cutaway wall and gives it a cream cap.
static func _wall(root: Node3D, from: Vector3, size: Vector3, face := "") -> void:
	var c := from + Vector3(size.x / 2, 0, size.z / 2)
	if face == "":
		Build._add(root, Build.bevel_mesh(size + Vector3(0, 0.2, 0), 0.07), c + Vector3(0, size.y / 2 - 0.1, 0), Color(t().wall), 0.0)
		return
	Build._add(root, Build.bevel_mesh(Vector3(size.x, size.y - 0.02, size.z), 0.05), c + Vector3(0, size.y / 2 - 0.11, 0), Color(face), 0.0)
	Build._add(root, Build.bevel_mesh(Vector3(size.x + 0.04, 0.14, size.z + 0.04), 0.06), c + Vector3(0, size.y - 0.07, 0), Color(t().wall), 0.0)


static func _doorway(root: Node3D, door: Vector2i, h: int) -> void:
	# A coral frame stands full height in the cutaway, with the hanging burger sign.
	for dx: float in [-0.02, 1.02]:
		Build.box(root, Vector3(door.x + dx, 0, h), Vector3(0.16, 2.1, 0.3), Build.CORAL)
	Build.box(root, Vector3(door.x + 0.5, 2.0, h), Vector3(1.36, 0.18, 0.32), Build.CORAL)
	Build.box(root, Vector3(door.x + 0.5, 0.0, h), Vector3(0.9, 0.012, 0.34), Build.WOOD, 0.0, Build.R_WOOD)
	Build.box(root, Vector3(door.x + 0.5, 0.0, h + 0.45), Vector3(0.8, 0.02, 0.5), Build.CORAL_DARK)
	var sign_at := Vector3(door.x + 0.5, 2.22, h)
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
	Build._add(root, Build.bevel_mesh(Vector3(1.5, 1.2, 0.12), 0.06), Vector3(x, 1.55, 0.03), Color(Build.CORAL), 0.0)
	Build.box(root, Vector3(x, 1.07, 0.05), Vector3(1.26, 0.96, 0.1), "#cfe6e6", 0.15, Build.R_GLOSS)
	Build.box(root, Vector3(x, 1.07, 0.06), Vector3(0.07, 0.96, 0.1), Build.CORAL)
	Build.box(root, Vector3(x, 0.9, 0.09), Vector3(1.6, 0.06, 0.16), Build.WOOD, 0.0, Build.R_WOOD)


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
		# Teal wainscoting with a wooden rail, and two framed abstract prints.
		Build.box(root, Vector3(mid, 0, 0.02), Vector3(span, 0.82, 0.05), Build.CABINET)
		Build.box(root, Vector3(mid, 0.8, 0.03), Vector3(span, 0.06, 0.09), Build.WOOD, 0.0, Build.R_WOOD)
		for i in 2:
			var x := mid - 0.42 + i * 0.84
			Build.box(root, Vector3(x, 1.15, 0.02), Vector3(0.66, 0.8, 0.06), Build.TRIM)
			Build.box(root, Vector3(x, 1.2, 0.03), Vector3(0.56, 0.7, 0.06), Build.PAPER)
			Build.ball(root, Vector3(x - 0.08 + i * 0.16, 1.66, 0.06), 0.13, Build.CORAL if i == 0 else Build.TILE_TEAL).scale = Vector3(1, 1, 0.3)
			Build.box(root, Vector3(x, 1.26, 0.04), Vector3(0.4, 0.16, 0.06), Build.CABINET if i == 0 else Build.CORAL)
	_window(root, KITCHEN_W + 1.55)
	_window(root, w - 1.55)
	_sconce(root, Vector3(KITCHEN_W + 0.5, 1.75, 0), Vector3(0, 0, 1), lights)
	_sconce(root, Vector3(w - 0.45, 1.75, 0), Vector3(0, 0, 1), lights)


static func _kitchen_wall(root: Node3D, h: int, lights: Array[OmniLight3D]) -> void:
	# Wall cabinets over the sink side, where they cannot hide a stove or a dial.
	Build.box(root, Vector3(0.18, 1.5, 3.0), Vector3(0.36, 0.66, 2.9), Build.CABINET)
	for i in 4:
		Build.box(root, Vector3(0.365, 1.56, 1.92 + i * 0.72), Vector3(0.03, 0.54, 0.64), Build._tint(Build.CABINET, 0.07))
		Build.box(root, Vector3(0.385, 1.6, 2.16 + i * 0.72 - (0.48 if i % 2 else 0.0)), Vector3(0.03, 0.12, 0.035), "#d9a441", 0.0, Build.R_WOOD)
	# A shelf of jars over the worktop.
	Build.box(root, Vector3(3.2, 1.5, 0.12), Vector3(1.3, 0.06, 0.24), Build.WOOD, 0.0, Build.R_WOOD)
	var jars := [Build.PAPER, Build.CORAL, Build.TILE_TEAL, Build.WARN]
	for i in jars.size():
		Build.cyl(root, Vector3(2.75 + i * 0.3, 1.56, 0.12), 0.09, 0.18 + 0.05 * (i % 2), jars[i], 0.0, Build.R_GLOSS)
		Build.cyl(root, Vector3(2.75 + i * 0.3, 1.74 + 0.05 * (i % 2), 0.12), 0.07, 0.04, Build.WOOD_DARK)
	_sconce(root, Vector3(0, 1.75, h - 1.2), Vector3(1, 0, 0), lights)


static func _dressing(root: Node3D, w: int, h: int) -> void:
	# Woven rug, 1.5 cm thick, under the middle table.
	Build.box(root, Vector3(8.5, 0, 3.5), Vector3(3.1, 0.015, 1.6), "#e9dcc0")
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		Build.box(root, Vector3(8.5 + side * 1.2, 0.003, 3.5), Vector3(0.18, 0.015, 1.6), Build.CORAL)
		Build.box(root, Vector3(8.5 + side * 0.95, 0.003, 3.5), Vector3(0.1, 0.015, 1.6), Build.CABINET)
	# Coat stand in the far front corner.
	var cs := Vector3(w - 0.3, 0, h - 0.42)
	Build.lathe(root, cs, [[0.0, 0.0], [0.17, 0.0], [0.18, 0.02], [0.05, 0.07], [0.035, 1.5], [0.06, 1.56], [0.0, 1.6]], Build.WOOD, 0.0, Build.R_WOOD)
	Build.box(root, cs + Vector3(0, 1.36, 0), Vector3(0.42, 0.04, 0.04), Build.WOOD, 0.0, Build.R_WOOD)
	Build.lathe(root, cs + Vector3(-0.1, 0.72, 0), [[0.0, 0.0], [0.14, 0.0], [0.16, 0.1], [0.12, 0.56], [0.05, 0.66], [0.0, 0.66]], Peg.OUTFITS.royal)
	# Planters and the menu board outside, on the kitchen side of the door.
	for px: float in [0.95, 2.75]:
		Build.box(root, Vector3(px, 0, h + 0.3), Vector3(1.6, 0.55, 0.34), Build.WOOD, 0.0, Build.R_WOOD)
		for i in 4:
			Build.ball(root, Vector3(px - 0.57 + i * 0.38, 0.6, h + 0.3), 0.2, Build.LEAF if i % 2 else Build.LEAF_2)
	for lean: float in [-1.0, 1.0]:
		var board := Build.box(root, Vector3(4.2, 0, h + 0.34 + lean * 0.09), Vector3(0.5, 0.78, 0.05), Build.WOOD, 0.0, Build.R_WOOD)
		board.rotation.x = -lean * 0.22
		var slate := Build.box(root, Vector3(4.2, 0.14, h + 0.34 + lean * 0.115), Vector3(0.4, 0.5, 0.03), "#3f4a45")
		slate.rotation.x = -lean * 0.22


## The plot, the street and the thick floating slab (sheet 12). Everything ends
## cleanly at the slab edge: no fade.
static func _ground(root: Node3D, w: int, lights: Array[OmniLight3D]) -> void:
	var x1 := w + 2.4
	var cx := (X0 + x1) / 2
	var span := x1 - X0
	Build.box(root, Vector3(cx, -0.85, (Z0 + Z1) / 2), Vector3(span, 0.75, Z1 - Z0), t().slab)
	Build.box(root, Vector3(cx, -0.26, (Z0 + Z1) / 2), Vector3(span + 0.08, 0.16, Z1 - Z0 + 0.08), Build.WOOD_DARK, 0.0, Build.R_WOOD)
	Build.box(root, Vector3(cx, -0.1, (Z0 + 7.0) / 2), Vector3(span, 0.08, 7.0 - Z0), t().lawn)
	# Boundaries: a low hedge and a 0.55 m picket fence. Nothing tall.
	Build._add(root, Build.bevel_mesh(Vector3(0.5, 0.5, 7.4), 0.12), Vector3(x1 - 0.35, 0.23, 3.0), Color(t().hedge), 0.0)
	Build._add(root, Build.bevel_mesh(Vector3(2.1, 0.5, 0.5), 0.12), Vector3(X0 + 1.15, 0.23, 6.7), Color(t().hedge), 0.0)
	for i in 9:
		var fx := w + 0.42 + i * 0.2
		Build.box(root, Vector3(fx, -0.02, 6.85), Vector3(0.12, 0.57 if i % 4 else 0.62, 0.05), Build.PAPER)
	for fy: float in [0.14, 0.36]:
		Build.box(root, Vector3(w + 1.2, fy, 6.82), Vector3(1.8, 0.06, 0.04), Build.PAPER)
	if seaside():
		_pier(root, w, x1)
	else:
		_street(root, w, x1, lights)


static func _street(root: Node3D, w: int, x1: float, lights: Array[OmniLight3D]) -> void:
	# Grey paving slabs, with a paler kerb row along the road.
	var x := X0
	while x < x1 - 0.01:
		for row in 3:
			var depth := 1.0 if row < 2 else PAVE_Z - 9.0
			var col := "#d9d1c5" if row == 2 else (Build.PAVING if int(absf(x * 2.0) + row) % 2 else "#c8beb1")
			Build.box(root, Vector3(x + 0.5, -0.1, 7.0 + row + depth / 2), Vector3(0.985, 0.1, depth - 0.015), col)
		x += 1.0
	# A two-lane road with white dashes, cut clean at the slab edge.
	Build.box(root, Vector3((X0 + x1) / 2, -0.17, (PAVE_Z + Z1) / 2), Vector3(x1 - X0, 0.1, Z1 - PAVE_Z), Build.ROAD)
	x = X0 + 0.7
	while x < x1 - 1.0:
		Build.box(root, Vector3(x + 0.5, -0.075, (PAVE_Z + Z1) / 2), Vector3(1.0, 0.012, 0.13), "#f6efe2")
		x += 2.2
	# Street furniture sits on the kerb side only, never over the queue line.
	var kerb := PAVE_Z - 0.45
	_lamp_post(root, Vector3(-0.7, 0, kerb), lights)
	# A layered-sphere tree in a stone surround.
	var tree := Vector3(X0 + 0.75, 0, kerb - 0.05)
	Build.box(root, tree, Vector3(0.8, 0.16, 0.8), "#bdb5a8")
	Build.cyl(root, tree, 0.09, 1.1, Build.WOOD_DARK, 0.0, Build.R_WOOD)
	Build.ball(root, tree + Vector3(0, 1.45, 0), 0.6, Build.LEAF)
	Build.ball(root, tree + Vector3(0.1, 2.05, 0.05), 0.44, Build.LEAF_2)
	Build.ball(root, tree + Vector3(-0.3, 1.3, 0.25), 0.36, Build.LEAF_2)
	# A slatted bench, a teal bin and a coral bike.
	var bench := Vector3(2.4, 0, kerb)
	for i in 3:
		Build.box(root, bench + Vector3(0, 0.36, -0.14 + i * 0.14), Vector3(1.5, 0.045, 0.12), Build.WOOD, 0.0, Build.R_WOOD)
	for i in 2:
		Build.box(root, bench + Vector3(0, 0.5 + i * 0.15, 0.3), Vector3(1.5, 0.12, 0.045), Build.WOOD, 0.0, Build.R_WOOD)
	for sx: float in [-0.6, 0.6]:
		Build.box(root, bench + Vector3(sx, 0, 0.02), Vector3(0.07, 0.36, 0.4), Build.TRIM)
		Build.box(root, bench + Vector3(sx, 0.3, 0.3), Vector3(0.07, 0.52, 0.06), Build.TRIM)
	Build.cyl(root, Vector3(4.2, 0, kerb), 0.22, 0.6, Build.CABINET)
	Build.cyl(root, Vector3(4.2, 0.6, kerb), 0.25, 0.07, Build._shade(Build.CABINET))
	var bike := Node3D.new()
	bike.position = Vector3(w + 1.2, 0, kerb)
	root.add_child(bike)
	for sx: float in [-0.42, 0.42]:
		var wheel := Build.lathe(bike, Vector3(sx, 0.3, 0), [[0.22, -0.025], [0.3, -0.025], [0.3, 0.025], [0.22, 0.025], [0.22, -0.025]], Build.TRIM)
		wheel.rotation.x = PI / 2
	Build.box(bike, Vector3(0, 0.36, 0), Vector3(0.6, 0.06, 0.05), Build.CORAL)
	Build.box(bike, Vector3(-0.12, 0.38, 0), Vector3(0.06, 0.36, 0.05), Build.CORAL).rotation.z = 0.3
	Build.box(bike, Vector3(0.32, 0.36, 0), Vector3(0.06, 0.5, 0.05), Build.CORAL).rotation.z = -0.3
	Build.box(bike, Vector3(-0.2, 0.72, 0), Vector3(0.26, 0.06, 0.12), Build.TRIM)
	Build.box(bike, Vector3(0.24, 0.84, 0), Vector3(0.06, 0.06, 0.4), Build.TRIM)


static func _lamp_post(root: Node3D, at: Vector3, lights: Array[OmniLight3D]) -> void:
	Build.lathe(root, at, [[0.0, 0.0], [0.16, 0.0], [0.18, 0.03], [0.08, 0.2], [0.055, 0.3], [0.055, 2.3], [0.12, 2.36], [0.0, 2.36]], "#3a3f44", 0.0, Build.R_WOOD)
	Build.box(root, at + Vector3(0, 2.36, 0), Vector3(0.26, 0.3, 0.26), "#ffe9bd", 1.6)
	Build.lathe(root, at + Vector3(0, 2.64, 0), [[0.0, 0.0], [0.22, 0.0], [0.24, 0.02], [0.06, 0.14], [0.0, 0.16]], "#3a3f44", 0.0, Build.R_WOOD)
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
		Build.box(root, Vector3(x + 0.25, -0.1, (7.0 + PAVE_Z) / 2), Vector3(0.485, 0.1, PAVE_Z - 7.0), tones[i % 3], 0.0, Build.R_WOOD)
		x += 0.5
		i += 1
	Build.box(root, Vector3((X0 + x1) / 2, -0.17, (PAVE_Z + Z1) / 2), Vector3(x1 - X0, 0.1, Z1 - PAVE_Z), "#4fc3c8", 0.0, 0.25)
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
