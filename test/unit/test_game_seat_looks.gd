extends "res://test/helpers/game_case.gd"
## EPIC 85: touching Table tiles draw one top and one candle; booth seats side by side
## draw one bench; a piece lifted or sold redraws its neighbours at once.


func _clear() -> void:
	for st: Station in game.stations.values().duplicate():
		game.world._unregister(st)
		st.queue_free()


func _row(n: int, type := "table", facing := 0) -> Array[Station]:
	_clear()
	var out: Array[Station] = []
	for i in n:
		out.append(game.world.add_station(type, Vector2i(5, 3 + i), 1, facing))
	return out


func _candles(tiles: Array[Station]) -> int:
	var c := 0
	for t in tiles:
		if is_instance_valid(t) and t._vis.get_node_or_null("candle") != null:
			c += 1
	return c


func _top_size(t: Station) -> Vector3:
	return ((t._vis.get_node("top") as MeshInstance3D).mesh as ArrayMesh).get_aabb().size


func test_three_tiles_in_a_row_have_one_candle_in_the_middle_tile():
	var t := _row(3)
	assert_eq(_candles(t), 1)
	assert_not_null(t[1]._vis.get_node_or_null("candle"))


func test_joined_tiles_reach_the_cell_edge_and_lone_tile_keeps_its_overhang():
	var t := _row(3)
	assert_almost_eq(_top_size(t[1]).x, 1.12, 0.001, "open sides keep today's top")
	assert_gt(_top_size(t[1]).z, 1.1, "joined both ways: runs on under both neighbours")
	var lone := _row(1)
	assert_almost_eq(_top_size(lone[0]).z, 1.12, 0.001)
	assert_eq(_candles(lone), 1)


func test_lifting_a_middle_tile_makes_two_tables_with_a_candle_each():
	var t := _row(5)
	assert_eq(_candles(t), 1)
	game.world._unregister(t[2])
	t[2].free()
	var left: Array[Station] = [t[0], t[1], t[3], t[4]]
	assert_eq(_candles(left), 2)
	assert_almost_eq(_top_size(t[1]).z, 1.0 + 0.12 + 0.0, 0.2, "its open end is capped again")


func test_two_tiles_share_one_candle_at_the_seam():
	var t := _row(2)
	assert_eq(_candles(t), 1)
	var holder: Station = t[0] if t[0]._vis.get_node_or_null("candle") else t[1]
	var c: Node3D = holder._vis.get_node("candle")
	assert_almost_eq(absf(c.position.z), 0.5, 0.001)


func test_a_turned_tile_keeps_its_candle_at_the_table_centre():
	var t := _row(2)
	t[0].place_at(t[0].cell, 1)
	t[1].place_at(t[1].cell, 1)
	var holder: Station = t[0] if t[0]._vis.get_node_or_null("candle") else t[1]
	var c: Node3D = holder._vis.get_node("candle")
	var world: Vector3 = holder._vis.to_global(c.position)
	assert_almost_eq(world.z, (t[0].position.z + t[1].position.z) / 2.0, 0.001)


func _bench_len(st: Station) -> float:
	var mx := -INF
	var mn := INF
	for m in st._vis.get_children():
		if m is MeshInstance3D and m.position.y < 0.2 and m.mesh.get_aabb().size.x > 0.6:
			mx = maxf(mx, m.position.z + m.mesh.get_aabb().size.z / 2.0)
			mn = minf(mn, m.position.z - m.mesh.get_aabb().size.z / 2.0)
	return mx - mn


func test_booth_seats_facing_the_same_way_draw_one_longer_bench():
	var lone := _row(1, "booth_seat")
	var single := _bench_len(lone[0])
	var pair := _row(2, "booth_seat")
	assert_gt(_bench_len(pair[0]), single, "its joined end runs on")
	game.world._unregister(pair[1])
	assert_almost_eq(_bench_len(pair[0]), single, 0.001)


func test_booth_seats_facing_different_ways_stay_separate_benches():
	_clear()
	var a: Station = game.world.add_station("booth_seat", Vector2i(5, 3), 1, 0)
	var b: Station = game.world.add_station("booth_seat", Vector2i(5, 4), 1, 2)
	assert_eq(a.joined, 0)
	assert_eq(b.joined, 0)
