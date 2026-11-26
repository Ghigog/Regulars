extends GutTest
# Poured-drink dispensers stand on the plain counter, not a cabinet of their own.

const DISPENSERS := ["fountain", "two_tap_fountain", "coffee_machine", "wine_barrel", "wine_rack", "beer_tap"]


func _boxes(type: String) -> Array:
	var n := Node3D.new()
	add_child_autofree(n)
	# an upgrade is drawn as its parent's body plus its own marks
	var parent := Kitchen.parent_of(type)
	if parent == "":
		parent = type
	BuildStations.station(n, parent, 1, "", false, type)
	var out := []
	for c in n.get_children():
		var m := c as MeshInstance3D
		if m != null and m.material_override is ShaderMaterial:
			out.append(m)
	return out


func test_dispensers_have_the_plain_counter_foot_and_no_coral_body():
	var want := Color(BuildStations._shade(Build.CABINET))
	for type: String in DISPENSERS:
		var foot = null
		var coral := false
		for m: MeshInstance3D in _boxes(type):
			var sz := m.mesh.get_aabb().size
			var albedo: Color = (m.material_override as ShaderMaterial).get_shader_parameter("albedo")
			if is_equal_approx(m.position.y - sz.y / 2, 0.0) and is_equal_approx(sz.y, 0.15):
				foot = albedo
			if sz.y > 0.5 and sz.x > 0.7 and albedo.is_equal_approx(Color(Build.CORAL)):
				coral = true
		assert_eq(foot, want, "%s foot" % type)
		assert_false(coral, "%s has a coral body" % type)
