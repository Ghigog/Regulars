class_name GameTableCards
extends RefCounted
## The seat-count card on every free table (EPIC 28): one paper tent card at the centre of
## each table (the seam of a joined pair) showing how many chairs it seats. Shown in the
## build phase and on free tables in service; it folds flat when a group sits and pops back
## up with a squash once the table is free and clear (no plates left on any half).

const FOLD_TIME := 0.15
const TOP := 0.8   # tabletop height the card stands on

var game: Game
var cards := {}   # lead Station -> {node: Node3D, shown: bool, seats: int}


func _init(game_: Game) -> void:
	game = game_


## The number the card of this table shows.
func seat_count(lead: Station) -> int:
	return game.tables.seats_of(lead).size()


## Whether the card of this table stands: a phase with a room, no group sat, no plates.
func should_show(lead: Station) -> bool:
	if game.phase != Game.Phase.BUILD and game.phase != Game.Phase.SERVICE:
		return false
	for h in game.tables.halves(lead):
		if h.dirty > 0:
			return false
	for s in game.tables.seats_of(lead):
		if game.seat_taken.has(s):
			return false
	return true


## The centre of the table: the seam of a joined pair.
func centre(lead: Station) -> Vector3:
	var sum := Vector3.ZERO
	var halves := game.tables.halves(lead)
	for h in halves:
		sum += h.position
	return sum / halves.size() + Vector3(0, TOP, 0)


## The card (node) of a table, for tests.
func card_of(lead: Station) -> Node3D:
	return cards[lead].node if cards.has(lead) else null


## Whether this table's card is up (or rising) right now.
func is_up(lead: Station) -> bool:
	return cards.has(lead) and cards[lead].shown


## Brings the cards in line with the room; called every frame, cheap.
func tick() -> void:
	var leads := {}
	for t in game.tables.list:
		var lead := game.paying.table_by_number(int(t.pieces.min()))
		if lead != null:
			leads[lead] = true
	for st in cards.keys():
		if not is_instance_valid(st) or not leads.has(st):
			_drop(st)
	for lead: Station in leads:
		var want := should_show(lead)
		var n := seat_count(lead)
		if cards.has(lead) and cards[lead].seats != n:
			_drop(lead)   # the table was joined or split: a new card
		if not cards.has(lead):
			_add(lead, n, want)
		var c: Dictionary = cards[lead]
		(c.node as Node3D).position = centre(lead)
		if want != c.shown:
			_set_shown(c, want)


func _add(lead: Station, n: int, shown: bool) -> void:
	var node := BuildSeatCard.make(game, n)
	node.visible = shown
	cards[lead] = {"node": node, "shown": shown, "seats": n}
	if not shown:
		(node.get_meta("fold") as Node3D).scale = Vector3(1, 0.02, 1)


func _drop(lead) -> void:
	var c: Dictionary = cards[lead]
	if is_instance_valid(c.node):
		(c.node as Node3D).queue_free()
	cards.erase(lead)


func _set_shown(c: Dictionary, shown: bool) -> void:
	c.shown = shown
	var node: Node3D = c.node
	var fold: Node3D = node.get_meta("fold")
	if c.has("tween") and c.tween != null and c.tween.is_valid():
		c.tween.kill()
	var tw := node.create_tween()
	c["tween"] = tw
	if shown:
		node.visible = true
		tw.tween_property(fold, "scale", Vector3(1.08, 1.12, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(fold, "scale", Vector3.ONE, 0.08)
	else:
		tw.tween_property(fold, "scale", Vector3(1, 0.02, 1), FOLD_TIME).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			if is_instance_valid(node):
				node.visible = c.shown)
