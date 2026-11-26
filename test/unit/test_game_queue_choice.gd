extends "res://test/helpers/game_case.gd"
## A party at the end of a long line may decide not to join it.


func _long_line(n: int) -> void:
	for i in n:   # the critic always joins, so this builds a line of n parties
		game.seating.spawn_group([10 + i], true)
	game.critic_guest = null


func test_disliked_guest_walks_on_when_roll_fails():
	_long_line(12)
	game.town.people[0].affinity = -0.8
	var before := float(game.town.people[0].affinity)
	game.order_rng.seed = s_of_failing_roll()
	var party: Array[Guest] = game.seating.spawn_group([0])
	assert_eq(party[0].state, "browse")
	assert_false(game.queue.has(party[0]))
	assert_true(party[0].line_too_long)
	_run(30.0)
	assert_eq(float(game.town.people[0].affinity), before)
	assert_eq(game.town.people[0].grudges, 0)
	assert_eq(int(game.ledger.today.found_nothing), 0)
	assert_eq(int(game.ledger.today.no_table), 0)
	assert_eq(game.ledger.strikes(), 0)


func s_of_failing_roll() -> int:
	for s in 50:
		var probe := RandomNumberGenerator.new()
		probe.seed = s
		if probe.randf() >= QueueChoice.join_chance(12, -0.8):
			return s
	return 0


func test_critic_joins_a_long_line():
	_long_line(12)
	game.town.people[0].affinity = -0.8
	game.order_rng.seed = s_of_failing_roll()
	var party: Array[Guest] = game.seating.spawn_group([0], true)
	assert_true(game.queue.has(party[0]))


func test_empty_line_joins():
	var party: Array[Guest] = game.seating.spawn_group([0])
	assert_true(game.queue.has(party[0]))
