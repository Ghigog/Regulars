extends GutTest
## A counter upgraded to a fridge is white on every side under its worktop.

const WHITE := Color("#eef3f4")


func _meshes(n: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.find_children("*", "MeshInstance3D", true, false):
		out.append(c)
	return out


func _colour(m: MeshInstance3D) -> Color:
	return (m.material_override as ShaderMaterial).get_shader_parameter("albedo")


func _has_colour(n: Node3D, col: Color) -> bool:
	return _meshes(n).any(func(m: MeshInstance3D) -> bool: return _colour(m).is_equal_approx(col))


func _white_body_spans_cell(n: Node3D) -> bool:
	return _meshes(n).any(func(m: MeshInstance3D) -> bool:
		var size := m.mesh.get_aabb().size * m.scale
		return _colour(m).is_equal_approx(WHITE) and size.x >= 0.94 - 0.01 and size.z >= 0.94 - 0.01 and size.y >= 0.69)


func _build(type: String, base: String, pass_look := false) -> Node3D:
	var n := Node3D.new()
	BuildStations.station(n, type, 1, base, pass_look)
	add_child_autofree(n)
	return n


func test_a_fridge_counter_is_white_all_round_not_teal():
	for pass_look in [false, true]:
		var n := _build("counter", "fridge", pass_look)
		assert_false(_has_colour(n, Color(Build.CABINET)), "no teal cabinet (pass %s)" % pass_look)
		assert_true(_white_body_spans_cell(n), "a white body spans the cell (pass %s)" % pass_look)


func test_a_tool_on_a_fridge_has_the_white_body():
	var n := _build("slicer", "fridge")
	assert_false(_has_colour(n, Color(Build.CABINET)))
	assert_true(_white_body_spans_cell(n))


func test_a_plain_counter_keeps_its_teal_body():
	var n := _build("counter", "")
	assert_true(_has_colour(n, Color(Build.CABINET)))
	assert_false(_white_body_spans_cell(n))


func test_a_steel_bodied_tool_on_a_fridge_is_white_not_steel():
	for type in ["stove", "fryer"]:
		var n := _build(type, "fridge")
		assert_true(_white_body_spans_cell(n), "%s has the white body" % type)
		assert_false(_meshes(n).any(func(m: MeshInstance3D) -> bool:
			var size := m.mesh.get_aabb().size * m.scale
			return _colour(m).is_equal_approx(Color(Build.STEEL)) and size.x >= 0.9 and size.y >= 0.69), "%s keeps no steel body" % type)
