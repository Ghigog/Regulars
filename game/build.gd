class_name Build
extends RefCounted
## Makes every visual in the game out of primitive meshes, in the toy-diorama style.

const SKIN: Array[String] = ["#f2c9a1", "#c68958", "#8a5a3c", "#f7dcc0"]
const FACE := {"joy": "#5fd38d", "meh": "#ffd34e", "mad": "#ff6b5e"}

static var _mats := {}


static func mat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [col.to_html(), emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, emit: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat(col, emit)
	parent.add_child(mi)
	return mi


## Box whose base centre sits at `pos`.
static func box(parent: Node3D, pos: Vector3, size: Vector3, col: String, emit := 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, pos + Vector3(0, size.y / 2, 0), Color(col), emit)


static func cyl(parent: Node3D, pos: Vector3, r: float, h: float, col: String, emit := 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 24
	return _add(parent, m, pos + Vector3(0, h / 2, 0), Color(col), emit)


static func ball(parent: Node3D, pos: Vector3, r: float, col: String, emit := 0.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2
	m.radial_segments = 20
	m.rings = 10
	return _add(parent, m, pos, Color(col), emit)


static func person(shirt: String, skin: int, chef := false) -> Node3D:
	var n := Node3D.new()
	var tone := SKIN[skin % SKIN.size()]
	cyl(n, Vector3.ZERO, 0.2, 0.62, shirt)
	ball(n, Vector3(0, 0.62, 0), 0.2, shirt)
	ball(n, Vector3(0, 0.96, 0), 0.27, tone)
	for side: float in [-1.0, 1.0]:  # eyes and hands; the person faces +z
		ball(n, Vector3(side * 0.1, 1.0, 0.235), 0.04, "#2b2220")
		ball(n, Vector3(side * 0.25, 0.42, 0.07), 0.075, tone)
	if chef:
		cyl(n, Vector3(0, 1.14, 0), 0.2, 0.22, "#ffffff")
		ball(n, Vector3(0, 1.38, 0), 0.23, "#ffffff")
	return n


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
	box(n, Vector3.ZERO, Vector3(0.94, 0.8, 0.94), body)
	box(n, Vector3(0, 0.8, 0), Vector3(1.0, 0.08, 1.0), top)


## Furniture visuals centred on a cell. Tier adds a gold trim.
static func station(n: Node3D, type: String, tier: int) -> void:
	match type:
		"fridge":
			box(n, Vector3.ZERO, Vector3(0.9, 1.7, 0.9), "#e8eef0")
			box(n, Vector3(0.3, 0.8, 0.46), Vector3(0.06, 0.5, 0.04), "#8a949a")
		"stove":
			_counter(n, "#8a949a", "#33373b")
			for d: Vector2 in [Vector2(-0.22, -0.2), Vector2(0.22, -0.2), Vector2(-0.22, 0.2), Vector2(0.22, 0.2)]:
				cyl(n, Vector3(d.x, 0.88, d.y), 0.13, 0.015, "#ff6b5e", 1.5)
			for i in 3:
				ball(n, Vector3(-0.25 + i * 0.25, 0.62, 0.48), 0.05, "#33373b")
		"counter":
			_counter(n, "#3f7f86", "#f4ead8")
		"pass":
			_counter(n, "#e56b5d", "#f6efe2")
		"plates":
			_counter(n, "#3f7f86", "#f4ead8")
		"sink":
			_counter(n, "#3f7f86", "#f4ead8")
			box(n, Vector3(0, 0.86, 0), Vector3(0.62, 0.04, 0.5), "#7fb8d6")
		"bin":
			cyl(n, Vector3.ZERO, 0.3, 0.7, "#5b6b57")
			cyl(n, Vector3(0, 0.7, 0), 0.33, 0.06, "#42503f")
		"plant":
			cyl(n, Vector3.ZERO, 0.26, 0.4, "#c96f4a")
			ball(n, Vector3(0, 0.75, 0), 0.38 + 0.05 * tier, "#4f9d69")
			ball(n, Vector3(0.14, 1.1, 0.08), 0.26, "#5fb37a")
		"table":
			cyl(n, Vector3.ZERO, 0.09, 0.62, "#7a5235")
			cyl(n, Vector3(0, 0.62, 0), 0.6, 0.07, "#f6efe2")
			box(n, Vector3(-1, 0, 0), Vector3(0.42, 0.34, 0.42), "#d9534f")
			box(n, Vector3(-1.19, 0.3, 0), Vector3(0.07, 0.5, 0.42), "#c2453f")
			box(n, Vector3(1, 0, 0), Vector3(0.42, 0.34, 0.42), "#e9a23b")
			box(n, Vector3(1.19, 0.3, 0), Vector3(0.07, 0.5, 0.42), "#d08a25")
			cyl(n, Vector3(0, 0.69, 0), 0.06, 0.12, "#8fc7c3")
			ball(n, Vector3(0, 0.86, 0), 0.07, "#e56b5d")
	if tier > 1:
		for i in tier - 1:
			box(n, Vector3(0, 0.05 + i * 0.1, 0), Vector3(1.02, 0.04, 1.02), "#ffd34e", 0.6)
