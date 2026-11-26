extends GutTest


func test_clear_food_is_no_longer_a_night_action():
	assert_eq(Cleaning.night_action("Clear food"), "")


func test_food_is_not_a_kind_that_needs_cleaning():
	assert_false(Cleaning.needs_cleaning("food", 1, 0))




func test_hands_are_busy_with_mess_or_a_washed_dish():
	assert_true(Cleaning.hands_busy("dishes"))
	assert_true(Cleaning.hands_busy("dirty_dishes"))
	assert_true(Cleaning.hands_busy("rubbish_bag"))
	assert_false(Cleaning.hands_busy(""))
