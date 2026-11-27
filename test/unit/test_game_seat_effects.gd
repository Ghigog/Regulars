extends "res://test/helpers/game_case.gd"
## EPIC 87: guests read the menu, then eat, tip and tolerate mess by their chair and table.


## Re-types every chair and table in the room, then seats one guest and runs until they sit.
func _seated(chair: String, chair_tier: int, table: String) -> Guest:
	for st: Station in game.stations.values():
		if st.type == "chair" or st.type == "chair_fast" or st.type == "booth_seat":
			st.type = chair
			st.tier = chair_tier
		elif st.type == "table" or st.type == "table_fast" or st.type == "table_comfy":
			st.type = table
	var g: Guest = game.seating.spawn_guest(0)
	for i in 300:
		game.step(0.1)
		if g.state == "reading" or g.state == "ordering":
			break
	return g


func _reading_seconds(g: Guest) -> float:
	var t := 0.0
	while g.state == "reading" and t < 30.0:
		game.step(0.1)
		t += 0.1
	return t


func test_a_guest_reads_before_ordering_and_patience_holds():
	var g := _seated("chair", 1, "table")
	assert_eq(g.state, "reading")
	assert_eq(game.hud.STATE_WORDS["reading"], "Reading the menu")
	var p := g.mood.patience
	game.step(0.5)
	assert_eq(g.state, "reading")
	assert_almost_eq(g.mood.patience, p, 0.0001, "patience does not drain while reading")
	assert_ne(g._order.visible and g.state == "reading", true, "no notepad yet")
	_reading_seconds(g)
	assert_eq(g.state, "ordering")


func test_a_longer_menu_takes_longer_to_read():
	var short := _seated("chair", 1, "table")
	var t_short := short.timer
	var long := Seating.reading_time(8, 1.0)
	assert_gt(long, Seating.reading_time(2, 1.0))
	assert_almost_eq(t_short, Seating.reading_time(game.menu_stock.tonight_menu().size(), 1.0), 0.001)


func test_fast_seating_calls_sooner_eats_faster_tips_less_and_minds_more():
	var plain := _seated("chair", 1, "table")
	var plain_read := plain.timer
	var plain_fx: Dictionary = plain.seat_fx
	var plain_service := plain.mood.scale_for("service")
	var plain_clean := plain.mood.scale_for("clean")
	plain.queue_free()
	game.guests.erase(plain)
	game.seat_taken.clear()
	var fast := _seated("chair_fast", 2, "table_fast")
	assert_lt(fast.timer, plain_read)
	assert_lt(fast.seat_fx.eat, plain_fx.eat)
	assert_lt(fast.mood.seat_tip, 1.0)
	assert_gt(fast.mood.seat_tolerance, 1.0)
	assert_gt(fast.mood.scale_for("service"), plain_service)
	assert_gt(fast.mood.scale_for("clean"), plain_clean)


func test_booth_and_comfortable_table_call_later_eat_longer_tip_more_and_mind_less():
	var plain := _seated("chair", 1, "table")
	var plain_read := plain.timer
	var plain_service := plain.mood.scale_for("service")
	plain.queue_free()
	game.guests.erase(plain)
	game.seat_taken.clear()
	var cosy := _seated("booth_seat", 1, "table_comfy")
	assert_gt(cosy.timer, plain_read)
	assert_gt(cosy.seat_fx.eat, 1.0)
	assert_gt(cosy.mood.seat_tip, 1.0)
	assert_lt(cosy.mood.seat_tolerance, 1.0)
	assert_gt(cosy.mood.joy, 0.0)
	assert_lt(cosy.mood.scale_for("service"), plain_service)


func test_seat_eat_factor_scales_eating_time():
	var g := _seated("chair_fast", 2, "table_fast")
	var base := Guest.EAT_TIME * GuestMood.stay_scale(0.5)
	g.mood.settle_comfort(g.idx)
	g.start_eating(1.0)
	assert_almost_eq(g.eat_time, Guest.EAT_TIME * GuestMood.stay_scale(g.mood.served_comfort) * g.seat_fx.eat, 0.001)
	assert_lt(g.seat_fx.eat, 1.0)
	assert_gt(base, 0.0)


func test_some_guests_think_grab_and_go_or_nice_to_sit_a_while():
	var grab := 0
	var nice := 0
	for i in 40:
		var f := _seated("chair_fast", 2, "table_fast")
		grab += 1 if f.mood.thoughts.has("Grab and go") else 0
		f.queue_free()
		game.guests.erase(f)
		game.seat_taken.clear()
		var c := _seated("booth_seat", 1, "table_comfy")
		nice += 1 if c.mood.thoughts.has("Nice to sit a while") else 0
		c.queue_free()
		game.guests.erase(c)
		game.seat_taken.clear()
	assert_gt(grab, 0)
	assert_gt(nice, 0)
	assert_lt(grab, 40, "not every guest")


func test_a_reading_guest_holds_a_menu_card_that_snaps_away_with_the_notepad():
	var g := _seated("chair", 1, "table")
	assert_eq(g.state, "reading")
	assert_not_null(g._card, "a menu card in their hands")
	assert_false(g._order.visible, "no notepad while reading")
	_reading_seconds(g)
	assert_eq(g.state, "ordering")
	assert_true(g._order.visible, "the notepad pops up the frame reading ends")
	assert_null(g._card, "the card is let go in that same frame")
	game.step(0.3)
