extends "res://test/helpers/game_case.gd"
## Keycap tags over the chef while a piece is held (EPIC-5 T4).


func _hold(id: String, moving := false, ch: Player = null) -> Player:
	_to_build()
	ch = ch if ch != null else game.player
	ch.hand = {"id": id, "tier": 1, "price": Catalog.price_of(id), "facing": 0, "moving": moving, "from": Vector3i(1, 1, 0)}
	return ch


func _tags(p := 0) -> Array:
	var d: Dictionary = game.hud._prompts[p]
	var out := []
	for e: Dictionary in d.extras:
		if e.label.visible:
			out.append([e.key_label.text if e.cap.visible else "", e.label.text])
	return out


func _draw(ch: Player) -> void:
	game._update_cursor(ch)


func test_new_piece_shows_price_turn_and_aim() -> void:
	var ch := _hold("table")
	_draw(ch)
	var d: Dictionary = game.hud._prompts[0]
	assert_eq(d.key_label.text, "E")
	assert_true(d.label.text.begins_with("PUT DOWN $"), d.label.text)
	assert_eq(_tags(), [["R", "TURN"], ["Shift", "AIM"]])
	var r := Rect2(d.sheet.position, d.sheet.size)
	assert_true(Rect2(Vector2.ZERO, game.hud.root.size).encloses(r), "fully on screen")


func test_a_moved_piece_shows_no_price_or_carrying() -> void:
	var ch := _hold("table", true)
	_draw(ch)
	var d: Dictionary = game.hud._prompts[0]
	assert_eq(d.label.text, "PUT DOWN")
	assert_false("CARRYING" in d.label.text.to_upper())


func test_pad_chef_reads_pad_glyphs_and_keyboard_chef_keys() -> void:
	_hold("table")
	assert_eq(game.coop.join("pad:1"), 1)
	var two: Player = game.chefs[1]
	two.hand = game.player.hand.duplicate()
	game._update_cursor(game.player)
	game._update_cursor(two)
	assert_eq(_tags(0), [["R", "TURN"], ["Shift", "AIM"]])
	assert_eq(_tags(1), [["RS", "TURN"], ["LT", "AIM"]])
	assert_eq(game.hud._prompts[1].key_label.text, "A")


func test_touch_shows_words_without_caps() -> void:
	game.controls.set_mode("touch")
	var ch := _hold("table")
	_draw(ch)
	assert_eq(_tags()[0], ["", "TURN"])


func test_box_shows_put_in_and_its_fee() -> void:
	var ch := _hold("box_patty")
	_draw(ch)
	var d: Dictionary = game.hud._prompts[0]
	assert_true(d.label.text.begins_with("PUT IN"), d.label.text)
	assert_true("A NIGHT" in d.label.text, d.label.text)
	assert_eq(_tags(), [])


func test_wall_tool_shows_price_each() -> void:
	var ch := _hold("wall")
	var r: Dictionary = game.room_edit.held_prompt(ch, game.room_edit.build_action(ch))
	assert_eq(r.text, "Build wall $%d each" % Catalog.price_of("wall"))
	assert_eq(r.extras, [])
