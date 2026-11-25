extends GutTest
# Every counter has the same dark-teal foot, the pass included.


func _kick_albedo(type: String, pass_look := false) -> Color:
	var n := Node3D.new()
	add_child_autofree(n)
	BuildStations.station(n, type, 1, "", pass_look)
	for c in n.get_children():
		var m := c as MeshInstance3D
		# the toe-kick: a 0.15 m tall box standing on the floor (Build.box centres it at y/2)
		if m != null and is_equal_approx(m.position.y - m.mesh.get_aabb().size.y / 2, 0.0) \
				and is_equal_approx(m.mesh.get_aabb().size.y, 0.15):
			return (m.material_override as ShaderMaterial).get_shader_parameter("albedo")
	fail_test("no toe-kick found on %s" % type)
	return Color.BLACK


func test_pass_plain_and_pass_look_counters_share_one_foot():
	var want := Color(BuildStations._shade(Build.CABINET))
	var plain := _kick_albedo("counter")
	assert_eq(plain, want)
	assert_eq(_kick_albedo("counter", true), plain, "a length of the pass")
	assert_eq(_kick_albedo("pass"), plain, "a pass piece")
	assert_ne(plain, Color(Build.CORAL))
