extends GutTest


func test_clear_food_is_no_longer_a_night_action():
	assert_eq(Cleaning.night_action("Clear food"), "")


func test_food_is_not_a_kind_that_needs_cleaning():
	assert_false(Cleaning.needs_cleaning("food", 1, 0))


func test_dirty_note_never_lists_food():
	assert_eq(Cleaning.dirty_note(1, 0, 0), "Still dirty: a table.")
	assert_eq(Cleaning.dirty_note(0, 0, 0), "")
