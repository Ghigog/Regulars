class_name Cleaning
extends RefCounted
## Night cleaning: mess carries over from one day to the next, and the build phase
## is when the chef can tidy it. These rules say what still needs cleaning, what a
## clean-up is called at night, what mess stops the chef doing, and when mess ages.
## Pieces are described by kind ("table", "sink", "bin") and plain counts, so this
## knows nothing about the scene.

const AGES_AT_NIGHT := false   # tunable: whether mess grows older in the build phase (PRD 5 says no)

## What the chef can be holding that is mess: while carried, the shop stays shut
## and no piece can be picked up.
const CARRIED_MESS: Array[String] = ["dirty_tray", "rubbish_bag"]

## The service actions that are cleaning, and what the prompt calls each at night.
## Any other action a station offers is not available in the build phase.
const NIGHT_ACTIONS := {
	"Clear tray": "Clear table",
	"Put in sink": "Put in sink",
	"Wash": "Wash up",
	"Empty bin": "Take the bag out",
}

const CLEAN_FIRST := "Clean it first."              # trying to move or sell a messy piece
const WALK_OVER := "Walk over and press Use"        # the mouse over a messy piece at night
const HANDS_FULL := "Put that down first."          # opening the shop with mess in hand


## Whether a piece has anything left to clean: plates on a table, plates soaking
## in a sink, scraps in a bin. `dirty` is plates (tables, sinks); `count` is scraps (bins).
static func needs_cleaning(kind: String, dirty: int, count: int) -> bool:
	match kind:
		"table", "sink":
			return dirty > 0
		"bin":
			return count > 0
	return false


## The night prompt for a service action, or "" when that action is not cleaning.
static func night_action(service_action: String) -> String:
	return str(NIGHT_ACTIONS.get(service_action, ""))


## Whether what the chef holds is mess that blocks building and the shop.
static func carrying_mess(held: String) -> bool:
	return held in CARRIED_MESS


## How old a piece's mess is after `delta` seconds. Mess ages only while it is
## messy, and at night only if AGES_AT_NIGHT; clean, it is back to zero.
static func aged(age: float, delta: float, messy: bool, in_service: bool) -> float:
	if not messy:
		return 0.0
	return age + delta if in_service or AGES_AT_NIGHT else age


## The build-phase note for what is still dirty, e.g.
## "Still dirty: 2 tables, the sink, the bin." Empty when nothing is. Sinks and
## bins are counted like tables: one is "the sink", more are "2 sinks".
static func dirty_note(tables: int, sinks: int, bins: int) -> String:
	var parts: Array[String] = []
	for pair: Array in [[tables, "a table", "tables"], [sinks, "the sink", "sinks"], [bins, "the bin", "bins"]]:
		var n: int = pair[0]
		if n == 1:
			parts.append(pair[1])
		elif n > 1:
			parts.append("%d %s" % [n, pair[2]])
	if parts.is_empty():
		return ""
	return "Still dirty: %s." % ", ".join(parts)
