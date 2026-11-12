class_name Scenery
extends RefCounted
## The room itself: floors, walls, the knee-high cutaway, windows, wall art and
## lights (style guide, sheets 10 and 11). No gameplay lives here.

const WALL_H := 2.4
const WALL_T := 0.24
const CUT_H := 0.55
const KITCHEN_W := 4


## Builds the room and returns its practical lights so the day can dim them.
static func build(root: Node3D, w: int, h: int, door: Vector2i) -> Array[OmniLight3D]:
	var lights: Array[OmniLight3D] = []
	_floors(root, w, h)
	# Far walls stand full height, just outside the floor.
	_wall(root, Vector3(-WALL_T, 0, -WALL_T), Vector3(w + WALL_T * 2, WALL_H, WALL_T))
	_wall(root, Vector3(-WALL_T, 0, 0), Vector3(WALL_T, WALL_H, h + WALL_T / 2))
	# Walls that face the camera drop to a knee-high cutaway. No transparency.
	_wall(root, Vector3(0, 0, h - WALL_T / 2), Vector3(door.x, CUT_H, WALL_T))
	_wall(root, Vector3(door.x + 1, 0, h - WALL_T / 2), Vector3(w - door.x - 1 + WALL_T, CUT_H, WALL_T))
	_wall(root, Vector3(w, 0, 0), Vector3(WALL_T, CUT_H, h - WALL_T / 2))
	_doorway(root, door, h)
	_dining_wall(root, w, lights)
	_kitchen_wall(root, h, lights)
	_dressing(root, w, h)
	return lights


static func _floors(root: Node3D, w: int, h: int) -> void:
	for x in KITCHEN_W:
		for y in h:
			var col := Build.TILE_CREAM if (x + y) % 2 else Build.TILE_TEAL
			Build.box(root, Vector3(x + 0.5, -0.03, y + 0.5), Vector3(0.985, 0.03, 0.985), col, 0.0, Build.R_GLOSS)
	# Dining: oak planks, half a metre wide, with staggered joints.
	var tones := [Build.FLOOR_WOOD, Build.FLOOR_WOOD_2, "#dab078"]
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


## A wall block from its low corner: darker foot, body, dark trim cap.
static func _wall(root: Node3D, from: Vector3, size: Vector3, body := Build.WALL) -> void:
	var c := from + Vector3(size.x / 2, 0, size.z / 2)
	Build.box(root, c, Vector3(size.x, 0.17, size.z), Build.WALL_LOW)
	Build.box(root, c + Vector3(0, 0.15, 0), Vector3(size.x, size.y - 0.23, size.z), body)
	Build.box(root, c + Vector3(0, size.y - 0.1, 0), Vector3(size.x + 0.05, 0.1, size.z + 0.05), Build.TRIM)


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
	Build._add(root, Build.bevel_mesh(Vector3(1.5, 1.2, 0.12), 0.06), Vector3(x, 1.55, 0.03), Color(Build.CORAL), 0.0)
	Build.box(root, Vector3(x, 1.07, 0.05), Vector3(1.26, 0.96, 0.1), "#cfe6e6", 0.15, Build.R_GLOSS)
	Build.box(root, Vector3(x, 1.07, 0.06), Vector3(0.07, 0.96, 0.1), Build.CORAL)
	Build.box(root, Vector3(x, 0.9, 0.09), Vector3(1.6, 0.06, 0.16), Build.WOOD, 0.0, Build.R_WOOD)


static func _dining_wall(root: Node3D, w: int, lights: Array[OmniLight3D]) -> void:
	var span := float(w - KITCHEN_W)
	var mid := KITCHEN_W + span / 2
	# Teal wainscoting with a wooden rail.
	Build.box(root, Vector3(mid, 0, 0.02), Vector3(span, 0.82, 0.05), Build.CABINET)
	Build.box(root, Vector3(mid, 0.8, 0.03), Vector3(span, 0.06, 0.09), Build.WOOD, 0.0, Build.R_WOOD)
	_window(root, KITCHEN_W + 1.55)
	_window(root, w - 1.55)
	# Two framed abstract prints.
	for i in 2:
		var x := mid - 0.42 + i * 0.84
		Build.box(root, Vector3(x, 1.15, 0.02), Vector3(0.66, 0.8, 0.06), Build.TRIM)
		Build.box(root, Vector3(x, 1.2, 0.03), Vector3(0.56, 0.7, 0.06), Build.PAPER)
		Build.ball(root, Vector3(x - 0.08 + i * 0.16, 1.66, 0.06), 0.13, Build.CORAL if i == 0 else Build.TILE_TEAL).scale = Vector3(1, 1, 0.3)
		Build.box(root, Vector3(x, 1.26, 0.04), Vector3(0.4, 0.16, 0.06), Build.CABINET if i == 0 else Build.CORAL)
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
