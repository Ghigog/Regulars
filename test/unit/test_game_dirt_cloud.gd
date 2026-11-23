extends "res://test/helpers/game_case.gd"
# Messy pieces (a table with plates, a piled sink, a full bin) carry the floor's grime cloud.


func _cloud(st: Station) -> Node:
	return st._fx.get("grime")


func test_messy_pieces_show_the_cloud_and_lose_it_when_clean():
	var t := _dirty_table(2)
	var sink: Station = game.world.find_station("sink")
	var bin: Station = game.world.find_station("bin")
	sink.dirty = Station.SINK_PILED
	bin.count = Station.BIN_HOLDS
	sink.refresh()
	bin.refresh()
	for st: Station in [t, sink, bin]:
		assert_not_null(_cloud(st), "%s has the cloud" % st.type)
	var first := _cloud(sink)
	sink.refresh()
	assert_eq(_cloud(sink), first, "made once")
	t.dirty = 0
	sink.dirty = 0
	bin.count = 0
	for st: Station in [t, sink, bin]:
		st.refresh()
		assert_null(_cloud(st), "%s is clean" % st.type)


func test_a_few_plates_or_scraps_show_no_cloud():
	var sink: Station = game.world.find_station("sink")
	var bin: Station = game.world.find_station("bin")
	sink.dirty = Station.SINK_PILED - 1
	bin.count = Station.BIN_HOLDS - 1
	sink.refresh()
	bin.refresh()
	assert_null(_cloud(sink))
	assert_null(_cloud(bin))


func test_the_door_opens_with_dirt_left():
	_dirty_table(1)
	game.world.find_station("bin").count = Station.BIN_HOLDS
	_to_build()
	assert_eq(game.menu_stock.open_block(), "")
	game.day.start_day()
	assert_eq(game.phase, game.Phase.SERVICE)


func test_a_carried_over_dirty_table_still_disgusts():
	game.stations.erase(Vector2i(0, 5))
	var g: Guest = game.seating.spawn_guest(2)
	_run(12.0)
	var other: Station = game.stations[Vector2i(6, 5)] if g.table.cell != Vector2i(6, 5) else game.stations[Vector2i(6, 1)]
	other.dirty = 1
	other.dirty_age = 40.0
	other.refresh()
	_run(2.0)
	assert_true(g.mood.thoughts.has("Nobody has cleared that table"))
