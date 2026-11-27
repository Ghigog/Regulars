extends GutTest
## A dining wall's wainscot and rail stop at the face of a knee-high wall that meets
## them, and still run right into a tall corner.

const LOW_FACE := 4.0 - Scenery.WALL_T / 2

var _theme := ""


func before_each():
	_theme = Scenery.theme_id


func after_each():
	Scenery.theme_id = _theme


## A 4x3 plank room: tall back wall along y = 0, tall wall on the left, knee-high
## wall on the right (a street edge), so the back wall ends at the low wall.
func _room() -> Node3D:
	var plan := Floorplan.new(Rect2i(0, 0, 8, 8))
	plan.fill(Rect2i(0, 0, 4, 3), "planks")
	var root := Node3D.new()
	add_child_autofree(root)
	Scenery.build_room(root, plan, Vector2i(-9, -9))
	return root


## [min x, max x] over the wainscot and rail boxes standing on the back wall.
func _extent(root: Node3D) -> Array:
	var lo := INF
	var hi := -INF
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not n is MeshInstance3D:
			continue
		var sz: Vector3 = n.mesh.get_aabb().size
		var diner := (is_equal_approx(sz.y, 0.82) and is_equal_approx(sz.z, 0.05)) or (is_equal_approx(sz.y, 0.06) and is_equal_approx(sz.z, 0.09))
		var sea := is_equal_approx(sz.y, 0.3) and is_equal_approx(sz.z, 0.04)
		if not (sea if Scenery.seaside() else diner) or absf(n.position.z) > 0.05:
			continue
		lo = minf(lo, n.position.x - sz.x / 2)
		hi = maxf(hi, n.position.x + sz.x / 2)
	return [lo, hi]


func _check(theme: String) -> void:
	Scenery.theme_id = theme
	var e := _extent(_room())
	assert_lt(e[1], LOW_FACE + 0.001, "%s: wainscot stops at the low wall's room face" % theme)
	assert_gt(e[1], LOW_FACE - 0.001, "%s: and reaches it" % theme)
	assert_lt(e[0], 0.001, "%s: still runs into the tall corner" % theme)


func test_diner_wainscot_stops_at_low_wall():
	_check("diner")


func test_seaside_clapboard_stops_at_low_wall():
	_check("seaside")
