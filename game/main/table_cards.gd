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
var previews := {}   # Player -> {node: Node3D, seats: int}: the card of the table a carried one would join
var _started := false   # once a card has stood, a card that appears pops up with a squash


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


## What putting down the table for two a chef carries, on its ghost, would join: {seats, at,
## mate} (the seats of the table it would make, its centre, the table it joins), or {}.
func join_preview(ch: Player) -> Dictionary:
	if game.phase != Game.Phase.BUILD or ch.hand.get("id", "") != "table" or ch.ghost == null or not ch.ghost.visible:
		return {}
	var cell := Grid.to_cell(ch.ghost.position)
	var pieces := []
	var dining := game.paying.dining_tables()
	for i in dining.size():
		var st: Station = dining[i]
		pieces.append({"type": st.type, "cell": st.cell, "facing": st.facing, "number": i + 1})
	var mine := dining.size() + 1
	pieces.append({"type": "table", "cell": cell, "facing": int(ch.hand.facing), "number": mine})
	for t in TableJoins.runs(pieces):
		if mine in t.pieces and t.pieces.size() > 1:
			var mate: Station = game.paying.table_by_number(int(t.pieces[0] if t.pieces[0] != mine else t.pieces[1]))
			return {"seats": int(t.seats), "mate": mate, "at": (Grid.center(cell) + mate.position) / 2.0 + Vector3(0, TOP, 0)}
	return {}


## The preview card of each chef who would join a table; returns the leads it covers.
func _tick_previews() -> Dictionary:
	var covered := {}
	for ch: Player in game.chefs:
		var pv := join_preview(ch)
		if previews.has(ch) and (pv.is_empty() or previews[ch].seats != pv.seats):
			_drop_preview(ch)
		if pv.is_empty():
			continue
		covered[game.tables.lead(pv.mate)] = true
		if not previews.has(ch):
			previews[ch] = {"node": BuildSeatCard.make(game, pv.seats), "seats": pv.seats}
		(previews[ch].node as Node3D).position = pv.at
	return covered


func _drop_preview(ch: Player) -> void:
	if is_instance_valid(previews[ch].node):
		(previews[ch].node as Node3D).queue_free()
	previews.erase(ch)


## Brings the cards in line with the room; called every frame, cheap.
func tick() -> void:
	var covered := _tick_previews()
	var leads := {}
	for t in game.tables.list:
		var lead := game.paying.table_by_number(int(t.pieces.min()))
		if lead != null:
			leads[lead] = true
	for st in cards.keys():
		if not is_instance_valid(st) or not leads.has(st):
			_drop(st)
	for lead: Station in leads:
		var want := should_show(lead) and not covered.has(lead)
		var n := seat_count(lead)
		var squash := _started
		if cards.has(lead) and cards[lead].seats != n:
			if n > cards[lead].seats:
				game.audio.sfx("clack")   # two tables pushed together
			_drop(lead)   # the table was joined or split: a new card squashes up
			squash = true
		if not cards.has(lead):
			_add(lead, n, want and not squash)
			if want and squash:
				_set_shown(cards[lead], true)
		var c: Dictionary = cards[lead]
		(c.node as Node3D).position = centre(lead)
		if want != c.shown:
			_set_shown(c, want)
	_started = _started or not leads.is_empty()


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
