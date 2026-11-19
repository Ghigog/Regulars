extends GutTest


func test_food_needs_cleaning_when_there_is_some():
	assert_true(Cleaning.needs_cleaning("food", 1, 0))
	assert_false(Cleaning.needs_cleaning("food", 0, 0))


func test_clear_food_is_a_night_action():
	assert_eq(Cleaning.night_action("Clear food"), "Clear food")


func test_dirty_note_counts_food():
	assert_eq(Cleaning.dirty_note(1, 0, 0, 1), "Still dirty: a table, a counter of food.")
	assert_eq(Cleaning.dirty_note(1, 0, 0, 2), "Still dirty: a table, 2 counters of food.")
	assert_eq(Cleaning.dirty_note(0, 0, 0, 0), "")
