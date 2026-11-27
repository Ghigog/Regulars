extends GutTest
# A ready-made tub stands open: a floor, walls that rise above it, no lid, and a heap of the
# prepped food inside, so the tub reads by its contents.

const WORKTOP := 0.9   # the counter's top, where the tub stands


func _ready_types() -> Array:
	var out := []
	for t: String in Catalog.ITEMS:
		if Catalog.ITEMS[t].get("ready", false):
			out.append(t)
	return out


func _build(type: String) -> Node3D:
	var n := Node3D.new()
	add_child_autofree(n)
	BuildStations.station(n, type, 1)
	# a ready-made tub is built as a box of stock: one scaled node holding the body, tub and food
	return n.get_child(0) as Node3D


## The tub's own meshes: direct children standing on the worktop, within one cell's tub footprint.
func _tub_parts(n: Node3D) -> Array:
	var out := []
	for c in n.get_children():
		var m := c as MeshInstance3D
		if m != null and m.mesh != null and m.position.y >= WORKTOP - 0.001 and m.mesh.get_aabb().size.x < 0.9:
			out.append(m)
	return out


func _top(m: MeshInstance3D) -> float:
	return m.position.y + m.mesh.get_aabb().end.y


func _footprint(m: MeshInstance3D) -> Rect2:
	var a := m.mesh.get_aabb()
	return Rect2(m.position.x + a.position.x, m.position.z + a.position.z, a.size.x, a.size.z)


func _floor(parts: Array) -> MeshInstance3D:
	var best: MeshInstance3D = null
	for m: MeshInstance3D in parts:
		if best == null or m.mesh.get_aabb().size.x * m.mesh.get_aabb().size.z > best.mesh.get_aabb().size.x * best.mesh.get_aabb().size.z:
			best = m
	return best


func _food_pieces(n: Node3D) -> int:
	var count := 0
	for c in n.get_children():
		if c is Node3D and not c is MeshInstance3D and not c.find_children("*", "MeshInstance3D", true, false).is_empty():
			count += 1
	return count


func test_there_are_ready_items():
	assert_gt(_ready_types().size(), 0)


func test_tub_is_heaped_with_prepped_food():
	for type: String in _ready_types():
		assert_gte(_food_pieces(_build(type)), 3, type)


func test_tub_walls_rise_above_its_floor():
	for type: String in _ready_types():
		var parts := _tub_parts(_build(type))
		var floor_mesh := _floor(parts)
		assert_not_null(floor_mesh, type)
		var walls := 0
		for m: MeshInstance3D in parts:
			if m != floor_mesh and _top(m) > _top(floor_mesh) + 0.08:
				walls += 1
		assert_gte(walls, 4, "%s: four walls" % type)


func test_nothing_covers_the_tub_opening():
	for type: String in _ready_types():
		var parts := _tub_parts(_build(type))
		var floor_mesh := _floor(parts)
		var inner := _footprint(floor_mesh).grow(-0.1)
		for m: MeshInstance3D in parts:
			if m == floor_mesh:
				continue
			# no part over the floor's inner area may sit above the floor except as food
			assert_false(_footprint(m).intersects(inner), "%s: a mesh covers the opening" % type)
