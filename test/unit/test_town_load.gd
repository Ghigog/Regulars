extends GutTest
## Older saves lack newer person keys; fill_missing_keys restores the defaults.


func test_missing_keys_come_back_with_defaults() -> void:
	var town := Town.new(5)
	town.people[0].affinity = 4.5
	for p in town.people:
		p.erase("warning")
		p.erase("deals")
		p.opinion.erase("variety")
	town.fill_missing_keys()
	for i in town.people.size():
		var p: Dictionary = town.people[i]
		assert_eq(p.warning, false)
		assert_eq(p.deals, 0)
		assert_eq(p.opinion.variety, 0.0)
	assert_eq(town.people[0].affinity, 4.5)
	assert_true(town.headline() is String)


func test_saved_values_are_not_overwritten() -> void:
	var town := Town.new(5)
	town.people[1].warning = true
	town.people[1].opinion.speed = 2.0
	town.fill_missing_keys()
	assert_true(town.people[1].warning)
	assert_eq(town.people[1].opinion.speed, 2.0)
