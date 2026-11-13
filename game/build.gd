class_name Build
extends RefCounted
## Makes every visual in the game out of primitive meshes, in the toy-diorama style.

## Palette roles (style guide, sheet 7). Brief values, nudged toward the sampled ones.
const BACKDROP := "#d9cfc1"
const WALL := "#f6eedd"
const WALL_LOW := "#eadfcb"     # the 15 cm darker band at the foot of walls
const TILE_TEAL := "#236a74"
const TILE_CREAM := "#f1e8cc"
const FLOOR_WOOD := "#bd7d49"
const FLOOR_WOOD_2 := "#b47443"
const CORAL := "#f07a63"
const CORAL_DARK := "#dc6450"
const CABINET := "#1f6470"
const CABINET_LOW := "#1a5560"
const WORKTOP := "#ecc083"
const WOOD := "#b07a48"
const WOOD_DARK := "#7a5235"
const STEEL := "#6f8d92"
const STEEL_DARK := "#3d4a4f"
const GOOD := "#6fcf97"
const WARN := "#ffd452"
const DANGER := "#e83d36"
const TRIM := "#3a2c22"
const CHEF_WHITE := "#fefefe"
const PAPER := "#fff6e6"
const LEAF := "#5fa873"
const LEAF_2 := "#74bb86"
const PAVING := "#bdb7b6"
const ROAD := "#8f8a84"

const BEVEL := 0.07   # the large soft bevel is a big part of the look (sheet 1)
const R_MATTE := 0.9   # walls, fabric, skin, plastic
const R_WOOD := 0.6    # wood and metal
const R_GLOSS := 0.4   # tile and food

static var _mats := {}
static var _meshes := {}


const CEL := preload("res://game/shaders/cel.gdshader")
const INK_LINE := preload("res://game/shaders/ink.gdshader")


## `ink` adds the thin outline; leave it off for ground sheets and glows.
static func mat(col: Color, emit := 0.0, rough := R_MATTE, ink := true) -> Material:
	var key := "%s|%s|%s|%s" % [col.to_html(), emit, rough, ink]
	if _mats.has(key):
		return _mats[key]
	if col.a < 1.0:  # glass and the like stay on the standard material
		var g := StandardMaterial3D.new()
		g.albedo_color = col
		g.roughness = rough
		g.metallic_specular = 0.35
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = g
		return g
	var m := ShaderMaterial.new()
	m.shader = CEL
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("emit", emit)
	m.set_shader_parameter("rough", rough)
	if rough == R_WOOD and col.h > 0.02 and col.h < 0.16 and col.s > 0.08:
		m.set_shader_parameter("grain", 1.0)  # warm and wood-rough: give it a grain
	if ink and emit <= 0.0:
		var line := ShaderMaterial.new()
		line.shader = INK_LINE
		line.set_shader_parameter("albedo", col)
		m.next_pass = line
	_mats[key] = m
	return m


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, emit: float, rough := R_MATTE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat(col, emit, rough)
	parent.add_child(mi)
	return mi


static func _poly(st: SurfaceTool, pts: Array, n: Vector3) -> void:
	n = n.normalized()
	for i in range(1, pts.size() - 1):
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[i]
		var c: Vector3 = pts[i + 1]
		if (b - a).cross(c - a).dot(n) > 0.0:  # Godot wants clockwise fronts
			var t := b
			b = c
			c = t
		for v: Vector3 in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(v)


## A box with every edge chamfered by `b` (the 3 cm toy bevel). Cached by size.
static func bevel_mesh(size: Vector3, b := BEVEL) -> ArrayMesh:
	# A rounded box with smooth normals: a sphere of radius `b` pulled apart to the
	# eight corners. Reads as soft moulded clay rather than a chamfered block.
	b = minf(b, minf(size.x, minf(size.y, size.z)) * 0.45)
	var key := "box|%s|%s" % [size, b]
	if _meshes.has(key):
		return _meshes[key]
	var seg := 6 if b >= 0.06 else (4 if b >= 0.025 else 2)
	var inner := size / 2.0 - Vector3(b, b, b)
	var rings := 2 * (seg + 1)
	var cols := 4 * (seg + 1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var sxs := [1.0, -1.0, -1.0, 1.0]
	var szs := [1.0, 1.0, -1.0, -1.0]
	for ri in rings:
		var top := ri <= seg
		var theta := PI / 2.0 * (ri if top else ri - 1) / seg
		for ci in cols:
			var q := ci / (seg + 1)
			var phi := PI / 2.0 * (q + float(ci % (seg + 1)) / seg)
			var d := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			verts.append(Vector3(sxs[q] * inner.x, (1.0 if top else -1.0) * inner.y, szs[q] * inner.z) + d * b)
			norms.append(d)
	var tris: Array = []
	for ri in rings - 1:
		for ci in cols:
			var c2 := (ci + 1) % cols
			var p := ri * cols
			var n := (ri + 1) * cols
			tris.append([p + ci, p + c2, n + c2])
			tris.append([p + ci, n + c2, n + ci])
	var step := seg + 1
	var last := (rings - 1) * cols
	tris.append([0, step, step * 2])
	tris.append([0, step * 2, step * 3])
	tris.append([last, last + step, last + step * 2])
	tris.append([last, last + step * 2, last + step * 3])
	for tri: Array in tris:
		var va := verts[tri[0]]
		var vb := verts[tri[1]]
		var vc := verts[tri[2]]
		var cr := (vb - va).cross(vc - va)
		if cr.length_squared() < 1e-12:
			continue
		if cr.dot(norms[tri[0]] + norms[tri[1]] + norms[tri[2]]) > 0.0:
			idx.append_array([tri[0], tri[2], tri[1]])
		else:
			idx.append_array(tri)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = m
	return m


## A shape turned on a lathe. `profile` is [radius, height] pairs from the bottom
## up the outside. Sharp turns in the profile stay as crisp edges.
## Turns the gentle bends of a lathe profile into curves, so a turned shape has
## a round silhouette instead of a string of straight sides. Sharp corners (more
## than about 40 degrees) are kept as they are.
static func _round_profile(profile: Array, steps := 5) -> Array:
	var pts: Array[Vector2] = []
	for p: Array in profile:
		pts.append(Vector2(p[0], p[1]))
	var n := pts.size()
	if n < 3:
		return profile
	var soft: Array[bool] = []  # is the bend at point i gentle?
	for i in n:
		soft.append(i > 0 and i < n - 1 \
				and (pts[i] - pts[i - 1]).normalized().dot((pts[i + 1] - pts[i]).normalized()) >= 0.75)
	var out: Array = [[pts[0].x, pts[0].y]]
	for i in n - 1:
		var a := pts[i]
		var b := pts[i + 1]
		if soft[i] or soft[i + 1]:
			var before: Vector2 = pts[i - 1] if soft[i] else a - (b - a)
			var after: Vector2 = pts[i + 2] if soft[i + 1] else b + (b - a)
			for k in range(1, steps):
				var q := a.cubic_interpolate(b, before, after, float(k) / steps)
				out.append([maxf(q.x, 0.0), q.y])
		out.append([b.x, b.y])
	return out


static func lathe_mesh(profile: Array, segs := 40) -> ArrayMesh:
	var key := "lathe|%s|%d" % [profile, segs]
	if _meshes.has(key):
		return _meshes[key]
	profile = _round_profile(profile)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var group := 0
	var prev_dir := Vector2.ZERO
	for i in profile.size() - 1:
		var p0 := Vector2(profile[i][0], profile[i][1])
		var p1 := Vector2(profile[i + 1][0], profile[i + 1][1])
		var dir := (p1 - p0).normalized()
		if prev_dir != Vector2.ZERO and prev_dir.dot(dir) < 0.75:
			group += 1
		prev_dir = dir
		st.set_smooth_group(group)
		var n2 := Vector2(dir.y, -dir.x)
		for j in segs:
			var a0 := TAU * j / segs
			var a1 := TAU * (j + 1) / segs
			var mid := (a0 + a1) / 2.0
			var n := Vector3(n2.x * cos(mid), n2.y, n2.x * sin(mid))
			var q := [_spin(p0, a0), _spin(p0, a1), _spin(p1, a1), _spin(p1, a0)]
			for tri: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var c: Vector3 = tri[2]
				if a.is_equal_approx(b) or b.is_equal_approx(c) or a.is_equal_approx(c):
					continue
				if (b - a).cross(c - a).dot(n) > 0.0:
					var t := b
					b = c
					c = t
				st.add_vertex(a)
				st.add_vertex(b)
				st.add_vertex(c)
	st.index()
	st.generate_normals()
	var m := st.commit()
	_meshes[key] = m
	return m


static func _spin(p: Vector2, ang: float) -> Vector3:
	return Vector3(p.x * cos(ang), p.y, p.x * sin(ang))


## The fixed game camera's orientation; flat cards use it to face the screen.
static var CAM_BASIS := Basis.looking_at(-Vector3(14, 15, 14))


static func flat_mat(col: Color) -> StandardMaterial3D:
	var key := "flat|%s" % col.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


## A flat cut-out card in the XY plane (facing +z), from a 2D outline. Layer
## cards by `z`; crisp edges, no alpha (style guide, sheet 13).
static func flat(parent: Node3D, pts: PackedVector2Array, col: String, z := 0.0) -> MeshInstance3D:
	var key := "flat|%s" % [pts]
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in Geometry2D.triangulate_polygon(pts):
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(Vector3(pts[i].x, pts[i].y, 0))
		_meshes[key] = st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.position.z = z
	mi.material_override = flat_mat(Color(col))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func disc_pts(r: float, at := Vector2.ZERO, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(at + Vector2(cos(TAU * i / n), sin(TAU * i / n)) * r)
	return pts


## Part of a ring. Angles in degrees, clockwise from straight up.
static func arc_pts(r0: float, r1: float, a0: float, a1: float, r0_end := -1.0, r1_end := -1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(2, ceili(absf(a1 - a0) / 8.0))
	for i in n + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(i) / n))
		pts.append(Vector2(sin(a), cos(a)) * lerpf(r1, r1 if r1_end < 0.0 else r1_end, float(i) / n))
	for i in range(n, -1, -1):
		var a := deg_to_rad(lerpf(a0, a1, float(i) / n))
		pts.append(Vector2(sin(a), cos(a)) * lerpf(r0, r0 if r0_end < 0.0 else r0_end, float(i) / n))
	return pts


static func star_pts(r: float, points := 4, inner := 0.42, at := Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := PI * i / points
		pts.append(at + Vector2(sin(a), cos(a)) * (r if i % 2 == 0 else r * inner))
	return pts


## Bevelled box whose base centre sits at `pos`.
static func box(parent: Node3D, pos: Vector3, size: Vector3, col: String, emit := 0.0, rough := R_MATTE) -> MeshInstance3D:
	return _add(parent, bevel_mesh(size), pos + Vector3(0, size.y / 2, 0), Color(col), emit, rough)


## Lathed shape whose profile origin sits at `pos`.
static func lathe(parent: Node3D, pos: Vector3, profile: Array, col: String, emit := 0.0, rough := R_MATTE) -> MeshInstance3D:
	return _add(parent, lathe_mesh(profile), pos, Color(col), emit, rough)


## Cylinder with bevelled rims, base centre at `pos`.
static func cyl(parent: Node3D, pos: Vector3, r: float, h: float, col: String, emit := 0.0, rough := R_MATTE) -> MeshInstance3D:
	var b := minf(BEVEL, minf(r, h) * 0.34)
	return lathe(parent, pos, [[0.0, 0.0], [r - b, 0.0], [r, b], [r, h - b], [r - b, h], [0.0, h]], col, emit, rough)


static func ball(parent: Node3D, pos: Vector3, r: float, col: String, emit := 0.0, rough := R_MATTE) -> MeshInstance3D:
	var key := "ball|%s" % r
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2
		m.radial_segments = 40
		m.rings = 20
		_meshes[key] = m
	return _add(parent, _meshes[key], pos, Color(col), emit, rough)


static func _puck(n: Node3D, y: float, r: float, h: float, col: String) -> MeshInstance3D:
	var e := minf(h * 0.45, 0.03)
	return lathe(n, Vector3(0, y, 0), [[0.0, 0.0], [r - e, 0.0], [r, e], [r, h - e], [r - e, h], [0.0, h]], col, 0.0, R_GLOSS)


static func _plate(n: Node3D) -> void:
	lathe(n, Vector3.ZERO, [[0.0, 0.0], [0.12, 0.0], [0.21, 0.03], [0.215, 0.042], [0.195, 0.042], [0.12, 0.018], [0.0, 0.018]], "#f6efe0", 0.0, R_GLOSS)


## The five patty looks from sheet 9: raw, nearly, perfect, dry, burnt.
static func patty(n: Node3D, look: String, y := 0.0) -> void:
	match look:
		"raw":
			_puck(n, y, 0.135, 0.075, "#f2a7ad")
		"nearly":
			_puck(n, y, 0.135, 0.07, "#c9986a")
			lathe(n, Vector3(0, y + 0.012, 0), [[0.125, 0.0], [0.14, 0.012], [0.14, 0.036], [0.125, 0.048]], "#e3a63a", 0.0, R_GLOSS)
		"perfect":
			_puck(n, y, 0.135, 0.07, "#7a3b22")
			for dx: float in [-0.045, 0.045]:
				box(n, Vector3(dx, y + 0.062, 0), Vector3(0.03, 0.014, 0.19), "#4a2414").rotation.y = 0.6
		"dry":
			_puck(n, y, 0.14, 0.04, "#b79f88")
		"burnt":
			_puck(n, y, 0.125, 0.055, "#2a2523")
			for i in 6:  # a jagged hockey puck
				var a := TAU * i / 6.0
				var lump := box(n, Vector3(cos(a) * 0.09, y + 0.005, sin(a) * 0.09), Vector3(0.09, 0.06 + 0.02 * (i % 2), 0.08), "#1f1b1a")
				lump.rotation = Vector3(0.3 * (i % 3 - 1), a, 0.25)


static func look_for(kind: String, quality: float) -> String:
	match kind:
		"raw_patty":
			return "raw"
		"burnt_patty":
			return "burnt"
	return "perfect" if quality > 0.95 else "dry"


## Anything that can be carried or put down. `look` overrides the patty look
## (a stove knows more about its patty than the item kind says).
static func item(kind: String, quality := 1.0, look := "") -> Node3D:
	var n := Node3D.new()
	if look == "":
		look = look_for(kind, quality)
	match kind:
		"raw_patty", "cooked_patty", "burnt_patty":
			patty(n, look)
		"plate":
			_plate(n)
		"dirty_plate":
			_plate(n)
			lathe(n, Vector3(0.01, 0.019, 0.0), [[0.05, 0.0], [0.07, 0.008], [0.09, 0.0]], "#7a4a2b", 0.0, R_GLOSS)
			ball(n, Vector3(-0.03, 0.02, 0.02), 0.022, "#7a4a2b", 0.0, R_GLOSS)
			for c: Vector3 in [Vector3(0.1, 0.03, 0.06), Vector3(-0.09, 0.03, -0.08), Vector3(0.02, 0.03, -0.13)]:
				box(n, c, Vector3(0.035, 0.02, 0.03), "#e0a850").rotation.y = c.x * 20.0
		"burger", "burger_bitten":
			_plate(n)
			_puck(n, 0.018, 0.14, 0.055, "#e6a542")                       # bottom bun
			patty(n, look, 0.07)
			box(n, Vector3(0, 0.135, 0), Vector3(0.25, 0.022, 0.25), "#ffd452", 0.0, R_GLOSS).rotation.y = PI / 4
			lathe(n, Vector3(0, 0.152, 0), [[0.0, 0.0], [0.165, 0.0], [0.175, 0.012], [0.165, 0.024], [0.0, 0.024]], "#6fbf5f", 0.0, R_GLOSS)
			lathe(n, Vector3(0, 0.172, 0), [[0.0, 0.0], [0.135, 0.0], [0.145, 0.03], [0.125, 0.075], [0.07, 0.105], [0.0, 0.112]], "#e6a542", 0.0, R_GLOSS)
			if kind == "burger_bitten":
				ball(n, Vector3(0.12, 0.17, 0.09), 0.105, "#f6e2b4")       # the bite
				for c: Vector3 in [Vector3(0.17, 0.03, -0.06), Vector3(-0.15, 0.03, 0.1)]:
					box(n, c, Vector3(0.03, 0.02, 0.03), "#e0a850")
	return n


static func _shade(col: String, amount := 0.13) -> String:
	return Color(col).darkened(amount).to_html(false)


static func _tint(col: String, amount := 0.08) -> String:
	return Color(col).lightened(amount).to_html(false)


## A 0.9 m counter: darker toe-kick, body with two doors and brass handles on the
## front (+z), bevelled worktop. Everything that takes a carried item sits flush.
static func _counter(n: Node3D, body: String, top: String, doors := true, kick := "") -> void:
	box(n, Vector3.ZERO, Vector3(0.9, 0.15, 0.9), _shade(body) if kick == "" else kick)
	box(n, Vector3(0, 0.12, 0), Vector3(0.94, 0.7, 0.94), body)
	box(n, Vector3(0, 0.77, 0), Vector3(1.0, 0.13, 1.0), top, 0.0, R_WOOD)  # a thick slab of worktop
	if doors:
		for sx: float in [-1.0, 1.0]:
			box(n, Vector3(sx * 0.225, 0.2, 0.462), Vector3(0.4, 0.54, 0.03), _tint(body, 0.07))
			box(n, Vector3(sx * 0.08, 0.5, 0.48), Vector3(0.035, 0.12, 0.03), "#d9a441", 0.0, R_WOOD)


## The till from sheet 1: a cream wedge with a keyboard slope and a display block.
static func register(n: Node3D) -> void:
	var till := Node3D.new()
	till.position = Vector3(0, 0.9, -0.05)
	till.rotation.y = PI / 2
	n.add_child(till)
	_add(till, bevel_mesh(Vector3(0.56, 0.16, 0.5), 0.05), Vector3(0, 0.08, 0), Color("#efe6d4"), 0.0)
	_add(till, bevel_mesh(Vector3(0.56, 0.3, 0.22), 0.05), Vector3(0, 0.29, -0.14), Color("#efe6d4"), 0.0)
	var keys := _add(till, bevel_mesh(Vector3(0.44, 0.03, 0.24), 0.012), Vector3(0, 0.175, 0.1), Color("#bdb5a8"), 0.0)
	keys.rotation.x = 0.25
	_add(till, bevel_mesh(Vector3(0.36, 0.12, 0.02), 0.008), Vector3(0, 0.33, -0.03), Color(CABINET), 0.0)


## Furniture visuals centred on a cell, front facing +z. Tier adds a gold trim.
## Shapes and heights are shared by every theme (sheets 8 and 10).
static func station(n: Node3D, type: String, tier: int) -> void:
	match type:
		"fridge":
			# Rounded retro fridge, 1.7 m: the tall landmark of the kitchen.
			_add(n, bevel_mesh(Vector3(0.9, 1.7, 0.82), 0.08), Vector3(0, 0.85, -0.03), Color("#f3ecdc"), 0.0)
			_add(n, bevel_mesh(Vector3(0.84, 0.56, 0.07), 0.03), Vector3(0, 1.38, 0.41), Color("#fbf6ea"), 0.0)
			box(n, Vector3(0.3, 1.2, 0.45), Vector3(0.05, 0.3, 0.04), STEEL, 0.0, R_WOOD)
			# Inside: dark shelves of red meat, seen when the lower door swings open.
			box(n, Vector3(0, 0.12, 0.376), Vector3(0.78, 0.92, 0.01), "#5b4a44")
			for i in 2:
				box(n, Vector3(0, 0.36 + i * 0.36, 0.38), Vector3(0.76, 0.03, 0.03), "#d8d2c4")
				for j in 3:
					var meat := lathe(n, Vector3(-0.24 + j * 0.24, 0.5 + i * 0.36, 0.385), [[0.0, -0.09], [0.07, -0.09], [0.09, -0.07], [0.09, 0.07], [0.07, 0.09], [0.0, 0.09]], "#e8767c")
					meat.rotation.x = PI / 2
					meat.scale = Vector3(1, 0.2, 1)
			var door := Node3D.new()
			door.name = "door"
			door.position = Vector3(-0.42, 0, 0.385)
			n.add_child(door)
			_add(door, bevel_mesh(Vector3(0.84, 0.98, 0.07), 0.03), Vector3(0.42, 0.57, 0.035), Color("#fbf6ea"), 0.0)
			box(door, Vector3(0.72, 0.62, 0.07), Vector3(0.05, 0.3, 0.04), STEEL, 0.0, R_WOOD)
		"stove":
			_counter(n, STEEL, STEEL_DARK, false)
			var ring := lathe(n, Vector3(0, 0.9, 0), [[0.15, 0.0], [0.17, 0.012], [0.21, 0.012], [0.23, 0.0]], STEEL_DARK)
			ring.name = "ring"
			# The frying pan lives on the burner; the patty sits in it.
			lathe(n, Vector3(0, 0.905, 0), [[0.0, 0.0], [0.2, 0.0], [0.25, 0.045], [0.235, 0.045], [0.19, 0.022], [0.0, 0.022]], "#34383b", 0.0, R_WOOD)
			box(n, Vector3(0.36, 0.925, 0.0), Vector3(0.28, 0.035, 0.06), WOOD_DARK)
			box(n, Vector3(0, 0.2, 0.455), Vector3(0.66, 0.4, 0.05), STEEL_DARK)
			box(n, Vector3(0, 0.52, 0.485), Vector3(0.5, 0.035, 0.03), "#d7dcdc", 0.0, R_WOOD)
			for i in 3:
				ball(n, Vector3(-0.25 + i * 0.25, 0.72, 0.47), 0.05, CORAL)
		"counter":
			_counter(n, CABINET, WORKTOP)
		"pass":
			# The anchor frame's long teal counter: coral foot, slot dividers on the tan top.
			_counter(n, CABINET, WORKTOP, false, CORAL)
			for sz: float in [-0.5, 0.5]:
				box(n, Vector3(0, 0.895, sz), Vector3(0.9, 0.035, 0.06), WOOD, 0.0, R_WOOD)
		"plates":
			_counter(n, CABINET, WORKTOP)
			lathe(n, Vector3(0, 0.9, 0), [[0.0, 0.0], [0.25, 0.0], [0.26, 0.008], [0.25, 0.016], [0.0, 0.016]], CORAL)
		"sink":
			_counter(n, CABINET, WORKTOP)
			box(n, Vector3(0, 0.885, 0.04), Vector3(0.7, 0.03, 0.56), "#c9d0d1", 0.0, R_WOOD)
			box(n, Vector3(0, 0.89, 0.04), Vector3(0.58, 0.03, 0.44), "#8fc3cf", 0.0, R_GLOSS)
			cyl(n, Vector3(0, 0.9, -0.36), 0.035, 0.26, "#c9d0d1", 0.0, R_WOOD)
			box(n, Vector3(0, 1.12, -0.25), Vector3(0.06, 0.05, 0.26), "#c9d0d1", 0.0, R_WOOD)
		"bin":
			box(n, Vector3.ZERO, Vector3(0.6, 0.12, 0.6), _shade(WOOD))
			box(n, Vector3(0, 0.1, 0), Vector3(0.64, 0.56, 0.64), WOOD, 0.0, R_WOOD)
			box(n, Vector3(0, 0.64, 0), Vector3(0.7, 0.08, 0.7), STEEL, 0.0, R_WOOD)
			box(n, Vector3(0, 0.7, 0), Vector3(0.52, 0.025, 0.52), TRIM)
		"plant":
			lathe(n, Vector3.ZERO, [[0.0, 0.0], [0.18, 0.0], [0.2, 0.02], [0.27, 0.36], [0.3, 0.38], [0.3, 0.44], [0.26, 0.46], [0.0, 0.46]], CORAL)
			lathe(n, Vector3(0, 0.2, 0), [[0.228, 0.0], [0.24, 0.006], [0.256, 0.08], [0.246, 0.086]], PAPER)
			var size := 0.3 + 0.05 * tier
			ball(n, Vector3(0, 0.5 + size, 0), size, LEAF)
			for i in 5:
				var a := TAU * i / 5.0 + 0.4
				var frond := ball(n, Vector3(cos(a) * size * 0.8, 0.56 + size * 0.7, sin(a) * size * 0.8), size * 0.62, LEAF_2 if i % 2 else LEAF)
				frond.scale = Vector3(1, 0.7, 1)
			ball(n, Vector3(0.05, 0.62 + size * 1.75, 0.03), size * 0.55, LEAF_2)
		"table":
			# Two-seat table (sheet 1): a slab top with a small bevel on a slim pedestal and
			# disc foot; coral chairs on four pale wooden legs, backs to 0.94 m.
			# Soft-cornered square top on a teal pedestal (the anchor frame).
			lathe(n, Vector3.ZERO, [[0.0, 0.0], [0.25, 0.0], [0.27, 0.02], [0.27, 0.08], [0.25, 0.1], [0.075, 0.1], [0.075, 0.63], [0.0, 0.63]], CABINET, 0.0, R_WOOD)
			_add(n, bevel_mesh(Vector3(1.12, 0.12, 1.12), 0.035), Vector3(0, 0.68, 0), Color("#ecc88f"), 0.0, R_WOOD)
			for sx: float in [-1.0, 1.0]:
				for lx: float in [-0.21, 0.21]:
					for lz: float in [-0.21, 0.21]:
						_add(n, bevel_mesh(Vector3(0.075, 0.36, 0.075), 0.02), Vector3(sx + lx, 0.18, lz), Color("#d9a56a"), 0.0, R_WOOD)
				_add(n, bevel_mesh(Vector3(0.58, 0.1, 0.58), 0.035), Vector3(sx, 0.4, 0), Color(CORAL), 0.0)
				_add(n, bevel_mesh(Vector3(0.1, 0.56, 0.58), 0.035), Vector3(sx * 1.24, 0.66, 0), Color(CORAL), 0.0)
			# Mushroom table lamp, 0.24 m.
			box(n, Vector3(0, 0.72, 0), Vector3(0.12, 0.05, 0.12), CABINET)
			cyl(n, Vector3(0, 0.76, 0), 0.025, 0.1, PAPER)
			lathe(n, Vector3(0, 0.84, 0), [[0.0, 0.0], [0.1, 0.0], [0.11, 0.02], [0.08, 0.08], [0.03, 0.115], [0.0, 0.12]], CORAL, 0.5)
	if tier > 1:
		for i in tier - 1:
			box(n, Vector3(0, 0.05 + i * 0.1, 0), Vector3(1.02, 0.04, 1.02), WARN, 0.6)
