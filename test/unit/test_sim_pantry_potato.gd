extends GutTest
## The potato is chopped, then fried into fries.


func test_potato_is_a_potato_chopped_on_the_board():
	assert_eq(Pantry.name_of("potato"), "Potato")
	assert_eq(Pantry.tool_of("potato"), "chop")
	assert_true(Pantry.has_box("potato"))


func test_fries_are_made_from_the_potato_sack_at_the_fryer():
	assert_eq(Pantry.name_of("fries"), "Fries")
	assert_eq(Pantry.tool_of("fries"), "fry")
	assert_eq(Pantry.source_of("fries"), "potato")
	assert_false(Pantry.has_box("fries"))
