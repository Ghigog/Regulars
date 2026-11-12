class_name GuestMood
extends RefCounted
## The four things we track about every guest, plus what they are thinking.

var patience := 1.0  # drains while queueing or waiting for food
var disgust := 0.0   # rises when they can see something gross
var joy := 0.5       # atmosphere, friends, kindness
var savour := 0.0    # how good the food was
var thoughts: Array[String] = []


func think(t: String) -> bool:
	if thoughts.has(t):
		return false
	thoughts.append(t)
	return true


func latest_thought() -> String:
	return "" if thoughts.is_empty() else thoughts[-1]


func wait(delta: float, seconds_to_snap: float) -> void:
	patience = maxf(0.0, patience - delta / seconds_to_snap)


func see_gross(strength: float, delta: float, thought: String) -> void:
	disgust = minf(1.0, disgust + strength * delta)
	think(thought)


func delight(amount: float, thought := "") -> void:
	joy = clampf(joy + amount, 0.0, 1.0)
	if thought != "":
		think(thought)


func taste(quality: float) -> void:
	savour = clampf(quality, 0.0, 1.0)
	joy = clampf(joy + 0.15 * savour, 0.0, 1.0)


func walked_out() -> bool:
	return patience <= 0.0


## How they feel right now, for the dot above their head: "joy", "meh" or "mad".
func face() -> String:
	var live := 0.5 * patience + 0.5 * joy - disgust
	if live > 0.6:
		return "joy"
	return "meh" if live > 0.3 else "mad"


## Final verdict on the visit, from -1 (furious) to 1 (delighted).
func satisfaction() -> float:
	return clampf(0.35 * savour + 0.3 * joy + 0.2 * patience - 0.5 * disgust, -1.0, 1.0)


func tip_for(bill: int) -> int:
	return roundi(bill * clampf(satisfaction(), 0.0, 1.0) * 0.6)
