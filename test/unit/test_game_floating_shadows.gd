extends "res://test/helpers/game_case.gd"
# Name tags, money popups and seat cards float above the room and cast no shadow.


func test_guest_name_tag_casts_no_shadow():
	var g: Guest = game.seating.spawn_guest(0)
	assert_eq(g._label.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_money_popup_casts_no_shadow():
	game.audio.popup("+$5", Vector3.ZERO, Color.WHITE)
	var found := false
	for c in game.get_children():
		if c is Label3D and c.text == "+$5":
			found = true
			assert_eq(c.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_true(found, "popup exists")


func test_table_seat_cards_cast_no_shadow():
	game.tables.rebuild()
	assert_gt(game.tables.cards.size(), 0, "a seat card exists")
	for c in game.tables.cards:
		assert_eq(c.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
