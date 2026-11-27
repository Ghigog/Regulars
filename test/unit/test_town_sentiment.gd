extends GutTest


func _town(affinity: float) -> Town:
	var t := Town.new(1)
	for p in t.people:
		p.affinity = affinity
	return t


func test_neutral_town_scores_zero_and_f() -> void:
	var t := _town(0.0)
	assert_eq(t.sentiment_points(), 0)
	assert_eq(Town.tier_for(0), "F")


func test_town_at_point_six_scores_sixty_and_s() -> void:
	var t := _town(0.6)
	assert_eq(t.sentiment_points(), 60)
	assert_eq(Town.tier_for(60), "S")


func test_negative_affinity_floors_at_zero() -> void:
	var t := _town(-0.7)
	assert_eq(t.sentiment_points(), 0)
	assert_eq(Town.tier_for(t.sentiment_points()), "F")


func test_tier_edges() -> void:
	var edges := {60: "S", 59: "A", 45: "A", 44: "B", 35: "B", 34: "C", 25: "C", 24: "D", 15: "D", 14: "E", 5: "E", 4: "F", 100: "S"}
	for pts: int in edges:
		assert_eq(Town.tier_for(pts), edges[pts], "points %d" % pts)
