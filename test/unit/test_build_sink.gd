extends GutTest
# What the sink draws: leaning plates and upright cups, told apart by name (repeats get a number after it).


func _load(plates: int, cups: int, piled := false) -> Node3D:
	var n := Node3D.new()
	add_child_autofree(n)
	BuildStations.sink_load(n, plates, cups, piled)
	return n


func _count(n: Node3D, kind: String) -> int:
	var c := 0
	for ch in n.get_children():
		if str(ch.name).begins_with(kind):
			c += 1
	return c


func test_plates_and_a_cup():
	var n := _load(2, 1)
	assert_eq(_count(n, "dirty_plate"), 2)
	assert_eq(_count(n, "dirty_cup"), 1)


func test_only_cups_draw_no_plates():
	var n := _load(0, 3)
	assert_eq(_count(n, "dirty_cup"), 3)
	assert_eq(_count(n, "dirty_plate"), 0)


func test_a_cup_still_shows_under_a_pile_of_plates():
	var n := _load(6, 1, true)
	assert_eq(_count(n, "dirty_cup"), 1)
	assert_eq(_count(n, "dirty_plate"), 3)


func test_empty_sink_draws_nothing():
	assert_eq(_load(0, 0).get_child_count(), 0)
