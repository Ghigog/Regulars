class_name Build
extends RefCounted
## Makes every visual in the game out of primitive meshes, in the toy-diorama style.

## Palette roles (style guide, sheet 7). Brief values, nudged toward the sampled ones.
const BACKDROP := "#f0dfc4"
const WALL := "#f6eee0"
const WALL_LOW := "#e3d8c6"     # the 15 cm darker band at the foot of walls
const TILE_TEAL := "#99c3b5"
const TILE_CREAM := "#f2ead4"
const FLOOR_WOOD := "#dc9d4e"
const FLOOR_WOOD_2 := "#d39346"
const CORAL := "#ee7560"
const CORAL_DARK := "#d9604d"
const CABINET := "#30676c"
const CABINET_LOW := "#2a5a5f"
const WORKTOP := "#e6c391"
const WOOD := "#a8703f"
const WOOD_DARK := "#7a5235"
const STEEL := "#a3abad"
const STEEL_DARK := "#4a4f52"
const GOOD := "#6fcf97"
const WARN := "#ffd452"
const DANGER := "#e83d36"
const TRIM := "#3a2c22"
const CHEF_WHITE := "#fefefe"
const PAPER := "#fff6e6"
const LEAF := "#5fa873"
const LEAF_2 := "#74bb86"
const PAVING := "#cfc6ba"
const ROAD := "#8f8a84"

const BEVEL := 0.03
const R_MATTE := 0.9   # walls, fabric, skin, plastic
const R_WOOD := 0.6    # wood and metal
const R_GLOSS := 0.4   # tile and food

static var _mats := {}
static var _meshes := {}


static func mat(col: Color, emit := 0.0, rough := R_MATTE) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [col.to_html(), emit, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic_specular = 0.35
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
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
	b = minf(b, minf(size.x, minf(size.y, size.z)) * 0.34)
	var key := "box|%s|%s" % [size, b]
	if _meshes.has(key):
		return _meshes[key]
	var h := size / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var vx := func(sx: float, sy: float, sz: float) -> Vector3: return Vector3(sx * h.x, sy * (h.y - b), sz * (h.z - b))
	var vy := func(sx: float, sy: float, sz: float) -> Vector3: return Vector3(sx * (h.x - b), sy * h.y, sz * (h.z - b))
	var vz := func(sx: float, sy: float, sz: float) -> Vector3: return Vector3(sx * (h.x - b), sy * (h.y - b), sz * h.z)
	for s: float in [-1.0, 1.0]:
		_poly(st, ring.map(func(r: Vector2) -> Vector3: return vx.call(s, r.x, r.y)), Vector3(s, 0, 0))
		_poly(st, ring.map(func(r: Vector2) -> Vector3: return vy.call(r.x, s, r.y)), Vector3(0, s, 0))
		_poly(st, ring.map(func(r: Vector2) -> Vector3: return vz.call(r.x, r.y, s)), Vector3(0, 0, s))
	for r: Vector2 in ring:
		_poly(st, [vy.call(-1, r.x, r.y), vy.call(1, r.x, r.y), vz.call(1, r.x, r.y), vz.call(-1, r.x, r.y)], Vector3(0, r.x, r.y))
		_poly(st, [vx.call(r.x, -1, r.y), vx.call(r.x, 1, r.y), vz.call(r.x, 1, r.y), vz.call(r.x, -1, r.y)], Vector3(r.x, 0, r.y))
		_poly(st, [vx.call(r.x, r.y, -1), vx.call(r.x, r.y, 1), vy.call(r.x, r.y, 1), vy.call(r.x, r.y, -1)], Vector3(r.x, r.y, 0))
		for s: float in [-1.0, 1.0]:
			_poly(st, [vx.call(s, r.x, r.y), vy.call(s, r.x, r.y), vz.call(s, r.x, r.y)], Vector3(s, r.x, r.y))
	var m := st.commit()
	_meshes[key] = m
	return m


## A shape turned on a lathe. `profile` is [radius, height] pairs from the bottom
## up the outside. Sharp turns in the profile stay as crisp edges.
static func lathe_mesh(profile: Array, segs := 24) -> ArrayMesh:
	var key := "lathe|%s|%d" % [profile, segs]
	if _meshes.has(key):
		return _meshes[key]
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
		m.radial_segments = 24
		m.rings = 12
		_meshes[key] = m
	return _add(parent, _meshes[key], pos, Color(col), emit, rough)


static func item(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"raw_patty":
			cyl(n, Vector3.ZERO, 0.13, 0.06, "#e58a8a")
		"cooked_patty":
			cyl(n, Vector3.ZERO, 0.13, 0.06, "#7a4a2b")
		"burnt_patty":
			cyl(n, Vector3.ZERO, 0.13, 0.06, "#1d1b1a")
		"plate":
			cyl(n, Vector3.ZERO, 0.19, 0.03, "#ffffff")
		"dirty_plate":
			cyl(n, Vector3.ZERO, 0.19, 0.03, "#b9a98a")
			ball(n, Vector3(0.05, 0.05, 0), 0.04, "#6b4a2b")
		"burger":
			cyl(n, Vector3.ZERO, 0.19, 0.03, "#ffffff")
			cyl(n, Vector3(0, 0.03, 0), 0.12, 0.05, "#e8a23a")
			cyl(n, Vector3(0, 0.08, 0), 0.13, 0.04, "#7a4a2b")
			ball(n, Vector3(0, 0.14, 0), 0.12, "#e8a23a")
	return n


static func _counter(n: Node3D, body: String, top: String) -> void:
	box(n, Vector3.ZERO, Vector3(0.9, 0.15, 0.9), Color(body).darkened(0.13).to_html(false))
	box(n, Vector3(0, 0.12, 0), Vector3(0.94, 0.7, 0.94), body)
	box(n, Vector3(0, 0.82, 0), Vector3(1.0, 0.08, 1.0), top, 0.0, R_WOOD)


## Furniture visuals centred on a cell. Tier adds a gold trim.
static func station(n: Node3D, type: String, tier: int) -> void:
	match type:
		"fridge":
			box(n, Vector3.ZERO, Vector3(0.9, 1.7, 0.9), "#e8eef0")
			box(n, Vector3(0.3, 0.8, 0.46), Vector3(0.06, 0.5, 0.04), STEEL)
		"stove":
			_counter(n, STEEL, STEEL_DARK)
			for d: Vector2 in [Vector2(-0.22, -0.2), Vector2(0.22, -0.2), Vector2(-0.22, 0.2), Vector2(0.22, 0.2)]:
				cyl(n, Vector3(d.x, 0.88, d.y), 0.13, 0.015, CORAL, 1.5)
			for i in 3:
				ball(n, Vector3(-0.25 + i * 0.25, 0.62, 0.48), 0.05, STEEL_DARK)
		"counter":
			_counter(n, CABINET, WORKTOP)
		"pass":
			_counter(n, CORAL, WORKTOP)
		"plates":
			_counter(n, CABINET, WORKTOP)
		"sink":
			_counter(n, CABINET, WORKTOP)
			box(n, Vector3(0, 0.86, 0), Vector3(0.62, 0.04, 0.5), "#7fb8d6")
		"bin":
			cyl(n, Vector3.ZERO, 0.3, 0.7, "#5b6b57")
			cyl(n, Vector3(0, 0.7, 0), 0.33, 0.06, "#42503f")
		"plant":
			cyl(n, Vector3.ZERO, 0.26, 0.4, "#c96f4a")
			ball(n, Vector3(0, 0.75, 0), 0.38 + 0.05 * tier, LEAF)
			ball(n, Vector3(0.14, 1.1, 0.08), 0.26, LEAF_2)
		"table":
			cyl(n, Vector3.ZERO, 0.09, 0.62, WOOD_DARK)
			cyl(n, Vector3(0, 0.62, 0), 0.6, 0.07, WORKTOP)
			box(n, Vector3(-1, 0, 0), Vector3(0.42, 0.34, 0.42), CORAL)
			box(n, Vector3(-1.19, 0.3, 0), Vector3(0.07, 0.5, 0.42), CORAL_DARK)
			box(n, Vector3(1, 0, 0), Vector3(0.42, 0.34, 0.42), CORAL)
			box(n, Vector3(1.19, 0.3, 0), Vector3(0.07, 0.5, 0.42), CORAL_DARK)
			cyl(n, Vector3(0, 0.69, 0), 0.06, 0.12, "#8fc7c3")
			ball(n, Vector3(0, 0.86, 0), 0.07, CORAL)
	if tier > 1:
		for i in tier - 1:
			box(n, Vector3(0, 0.05 + i * 0.1, 0), Vector3(1.02, 0.04, 1.02), WARN, 0.6)
