class_name QueueChoice
extends RefCounted
## Whether a party that reaches the end of the line outside joins it. The chance falls with
## the groups already waiting and rises with how much the party likes the place. There is no
## hard cap: a long line puts strangers off well before it puts off people who love it.

const PER_GROUP_DROP := 0.08     # tunable: chance lost per group ahead, for someone with no opinion
const AFFINITY_WEIGHT := 0.75    # tunable: how far liking the place softens (or disliking sharpens) that drop
const FLOOR := 0.05              # tunable: the lowest chance, however long the line


## `like` is -1..1: the party's mean affinity plus the restaurant's reputation.
static func join_chance(groups_ahead: int, like: float) -> float:
	var drop := groups_ahead * PER_GROUP_DROP * (1.0 - AFFINITY_WEIGHT * clampf(like, -1.0, 1.0))
	return clampf(1.0 - drop, FLOOR, 1.0)
