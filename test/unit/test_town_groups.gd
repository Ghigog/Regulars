extends GutTest
## Group sizes: small parties are the norm, big ones rare and capped; big parties wait longer.


func _sizes(max_size: int) -> Array[int]:
	var sizes: Array[int] = []
	for seed_value in range(1, 6):
		var t := Town.new(seed_value)
		for i in t.people.size():
			t.people[i].friends = []
			for j in t.people.size():
				if j != i:
					t.people[i].friends.append(j)
		for day in range(1, 31):
			var coming: Array[int] = []
			for i in t.people.size():
				coming.append(i)
			for group: Array in t.make_groups(coming, max_size, day):
				sizes.append(group.size())
	return sizes


func test_small_groups_are_the_norm_but_big_ones_come():
	var sizes := _sizes(12)
	var small := sizes.filter(func(n: int) -> bool: return n <= 4).size()
	assert_gte(float(small) / sizes.size(), 0.8)
	assert_gt(sizes.max(), 4, "some groups are bigger than 4")
	assert_lte(sizes.max(), 12)


func test_no_group_beyond_max_size():
	assert_lte(_sizes(6).max(), 6)


func test_no_group_beyond_max_party():
	assert_lte(_sizes(40).max(), Town.MAX_PARTY)


func test_party_patience_grows_beyond_four():
	assert_eq(Town.party_patience(5, 4), Town.table_patience(5))
	assert_eq(Town.party_patience(5, 1), Town.table_patience(5))
	assert_gt(Town.party_patience(5, 12), Town.table_patience(5))
