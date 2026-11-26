extends GutTest
# No two stacked meshes of a station may draw their top faces in the same plane (z-fighting).

const TOLERANCE := 0.002


func _flat_meshes(type: String, rack_dishes := 0) -> Array:
	var n := Node3D.new()
	add_child_autofree(n)
	BuildStations.station(n, type, 1)
	if rack_dishes > 0:
		BuildStations.rack_load(n, rack_dishes, 1)
	var out := []
	for c in n.get_children():
		var m := c as MeshInstance3D
		# a sphere has only a point for a top, so two balls at one height never fight
		if m != null and m.mesh != null and not m.mesh is SphereMesh and m.rotation.is_zero_approx() and m.scale.is_equal_approx(Vector3.ONE):
			out.append(m)
	return out


func _footprint(m: MeshInstance3D) -> Rect2:
	var a := m.mesh.get_aabb()
	return Rect2(m.position.x + a.position.x, m.position.z + a.position.z, a.size.x, a.size.z)


func _top(m: MeshInstance3D) -> float:
	return m.position.y + m.mesh.get_aabb().end.y


func _clashes(type: String) -> Array:
	var ms := _flat_meshes(type)
	var bad := []
	for i in ms.size():
		for j in range(i + 1, ms.size()):
			if _footprint(ms[i]).grow(-0.0005).intersects(_footprint(ms[j]).grow(-0.0005)) \
					and absf(_top(ms[i]) - _top(ms[j])) < TOLERANCE:
				bad.append("%s: meshes %d and %d share a top at y=%.3f" % [type, i, j, _top(ms[i])])
	return bad


func test_no_station_has_two_overlapping_meshes_sharing_a_top_face():
	var types: Array = Catalog.ITEMS.keys()
	for t: String in ["dish_rack", "fryer", "twin_fryer"]:
		if not types.has(t):
			types.append(t)
	for type: String in types:
		assert_eq(_clashes(type), [], type)
