extends GutTest
## Windows are bought per full-height wall length: where one can go, and when laying floor takes it away.

var plan: Floorplan


func before_each() -> void:
	plan = Floorplan.new(Rect2i(0, 0, 8, 8))
	plan.floors[Vector2i(2, 2)] = "planks"
	plan.floors[Vector2i(3, 2)] = "planks"
	plan.floors[Vector2i(2, 3)] = "planks"


func test_a_full_height_wall_takes_a_window():
	assert_true(plan.can_glaze(Vector3i(2, 2, 0)), "floor in front, none behind")
	assert_true(plan.can_glaze(Vector3i(2, 2, 1)), "the west wall too")


func test_knee_high_street_side_and_open_edges_do_not():
	assert_false(plan.can_glaze(Vector3i(2, 3, 0)), "between two floors is knee-high")
	assert_false(plan.can_glaze(Vector3i(4, 2, 1)), "the street side: floor behind, none in front")
	assert_false(plan.can_glaze(Vector3i(6, 6, 0)), "no wall at all")
	plan.openings[Vector3i(3, 2, 0)] = "door"
	assert_false(plan.can_glaze(Vector3i(3, 2, 0)), "a door edge")
	plan.windows[Vector3i(2, 2, 0)] = true
	assert_false(plan.can_glaze(Vector3i(2, 2, 0)), "already windowed")
	assert_false(plan.can_open(Vector3i(2, 2, 0), "door"), "a windowed edge takes no door")


func test_a_window_is_not_an_opening():
	var e := Vector3i(2, 2, 0)
	var before := plan.solid_walls().size()
	plan.windows[e] = true
	assert_eq(plan.solid_walls().size(), before)
	assert_true(plan.solid_walls().has(e))
	assert_true(plan.doors().is_empty())


func test_laying_floor_behind_takes_the_window_away():
	var e := Vector3i(2, 2, 0)
	plan.windows[e] = true
	plan.windows[Vector3i(3, 2, 0)] = true
	var gone := plan.lay(Vector2i(2, 1), "planks")
	assert_eq(gone.get(e), "window", "returned so the caller can refund it")
	assert_false(plan.windows.has(e))
	assert_true(plan.windows.has(Vector3i(3, 2, 0)), "the next length is untouched")
