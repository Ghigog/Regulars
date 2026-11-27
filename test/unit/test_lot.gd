extends GutTest

func test_default_lot_cells() -> void:
	var lot := Lot.new()
	assert_eq(lot.bounds(), Rect2i(-5, -3, 15, 10))
	for x in range(-8, 14):
		for y in range(-6, 10):
			var inside := x >= -5 and x <= 9 and y >= -3 and y <= 6
			assert_eq(lot.has_point(Vector2i(x, y)), inside, "cell %d,%d" % [x, y])


func test_default_buyable_exact() -> void:
	var got := Lot.new().buyable()
	var want: Array[Vector2i] = [Vector2i(-2, 0), Vector2i(-2, 1), Vector2i(-1, -1),
		Vector2i(-1, 2), Vector2i(0, -1), Vector2i(0, 2), Vector2i(1, -1), Vector2i(1, 2)]
	assert_eq(got, want)


func test_price_rises() -> void:
	var lot := Lot.new()
	var prices: Array[int] = []
	for i in 6:
		prices.append(lot.next_price())
		lot.buy(lot.buyable()[0])
	assert_eq(prices, [150, 225, 340, 505, 760, 1140] as Array[int])


func test_cap_after_six() -> void:
	var lot := Lot.new()
	for i in 6:
		assert_true(lot.buy(lot.buyable()[0]))
	assert_eq(lot.buyable().size(), 0)
	assert_false(lot.buy(Vector2i(-2, 0)))


func test_buy_rejects_street_and_unowned_far() -> void:
	var lot := Lot.new()
	assert_false(lot.buy(Vector2i(2, 0)))
	assert_false(lot.buy(Vector2i(-5, 0)))
	assert_eq(lot.bought, 0)


func test_buy_grows_lot() -> void:
	var lot := Lot.new()
	assert_true(lot.buy(Vector2i(-2, 0)))
	assert_true(lot.has_point(Vector2i(-10, 0)))
	assert_eq(lot.bounds().position.x, -10)


func test_round_trip() -> void:
	var lot := Lot.new()
	lot.buy(Vector2i(-1, -1))
	var back := Lot.from_dict(lot.to_dict())
	assert_eq(back.bought, 1)
	assert_eq(back.bounds(), lot.bounds())
	assert_eq(back.next_price(), 225)
