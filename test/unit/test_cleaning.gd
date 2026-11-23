extends GutTest


func test_clear_food_is_no_longer_a_night_action():
	assert_eq(Cleaning.night_action("Clear food"), "")


func test_food_is_not_a_kind_that_needs_cleaning():
	assert_false(Cleaning.needs_cleaning("food", 1, 0))


