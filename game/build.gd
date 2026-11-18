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
const BAG := "#4f6b4a"    # bin bags: a dull green that still reads against the brown bin
const SUDS := "#f4fbfb"
const ROAD := "#8f8a84"

const BEVEL := 0.05   # soft, but small enough that slabs still read as slabs (sheet 1)
const R_MATTE := 0.9   # walls, fabric, skin, plastic
const R_WOOD := 0.6    # wood and metal
const R_GLOSS := 0.4   # tile and food
const PAN := Vector3(-0.22, 0, -0.17)  # the stove's working burner, from the cell centre

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


## A flat colour that draws over everything in the world, for gauges that must
## never be hidden. Higher `prio` draws later.
static func overlay_mat(col: Color, prio := 0, depth := false) -> StandardMaterial3D:
	var key := "over|%s|%d|%s" % [col.to_html(), prio, depth]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = not depth   # `depth`: hidden behind what stands in front of it
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS  # keeps it sharp under the tilt-shift blur
		m.render_priority = clampi(prio, 0, 120)
		_mats[key] = m
	return _mats[key]


## Makes every flat card under `n` draw on top of the world, keeping their layering.
static func on_top(n: Node, depth := 0.0) -> void:
	if n is Node3D:
		depth += (n as Node3D).position.z
	if n is MeshInstance3D and (n as MeshInstance3D).material_override is StandardMaterial3D:
		var m: StandardMaterial3D = (n as MeshInstance3D).material_override
		(n as MeshInstance3D).material_override = overlay_mat(m.albedo_color, roundi(depth * 1000.0))
	for c in n.get_children():
		on_top(c, depth)


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


