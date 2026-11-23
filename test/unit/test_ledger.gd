extends GutTest
## The day's ledger: groups turned away for want of a table.


func test_groups_with_no_table_are_counted_without_a_strike_or_reputation_change():
	var l := Ledger.new()
	var rep := l.reputation
	l.record_no_table()
	l.record_no_table()
	assert_eq(int(l.today.no_table), 2)
	assert_eq(l.strikes(), 0)
	assert_eq(l.reputation, rep)
	assert_eq(int(l.end_day().no_table), 2, "the receipt counts them")
	assert_eq(int(l.today.no_table), 0, "a new day starts at none")
