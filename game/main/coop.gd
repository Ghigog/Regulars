class_name GameCoop
extends RefCounted
## Co-op (PRD 4): players joining and leaving, setting down, readiness at the receipt and
## the door, and act(), where every player's presses arrive.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- co-op (PRD 4)

## A device that is not seated pressed Start (Enter on the keyboard): it becomes
## the next player and their chef walks in at the door. Returns the new player
## index, or -1 when every chef's place is taken.
func join(source: String) -> int:
	if game.chefs.size() >= Game.MAX_CHEFS or source == "touch":
		return -1
	var p := game.chefs.size()
	game.controls.seat(game.controls.input_of(0).source, 0)   # player one keeps the device they are using
	game.controls.seat(source, p)
	game.controls.set_mode(source.get_slice(":", 0), p)
	game.controls.input_of(p).source = source
	var ch := game.add_chef(Game.ENTRANCE_CELL)
	ch.look(Vector2i(-1, 0))
	game.audio.burst(ch.position + Vector3(0, 1.0, 0), "stars", 0.5)
	game.audio.door_bell()
	ch.punch()
	game.hud.day_ui.say("Chef %d joined." % (p + 1))
	game.hud.hints_ui.refresh_input()
	if game.phase == Game.Phase.BUILD:
		game.hud.hints_ui.show_build()
	_refresh_ready()
	return p


## Player p leaves (held Start, or their controller was unplugged). Their chef
## puts down what they carry and walks out of the door; the players after them
## move up one, so if player one leaves the other becomes player one. The last
## chef never leaves.
func leave(p: int) -> bool:
	if p < 0 or p >= game.chefs.size() or game.chefs.size() <= 1:
		return false
	var ch := game.chefs[p]
	if game.preps.has(p):
		game.prep_games.cancel_prep(p)   # the ingredient comes back to their hands, and then goes down
	if game.shopper == ch:
		game.session.close_shop()
	if ch.hand.get("moving", false):
		game.placing.cancel_hand(ch)   # a moved piece goes back where it was
	ch.hand = {}          # a new piece is only paid for when placed: nothing to refund
	ch.drag = {}
	if ch.held != "":
		set_down(ch)
	game.ready_chefs.erase(ch)
	game.chefs.remove_at(p)
	var moved := {}
	for q: int in game.preps:   # the minigames of later players move up one with them
		var nq := q - 1 if q > p else q
		moved[nq] = game.preps[q]
		(game.preps[q].st as Station).prep_by = nq
	game.preps = moved
	game.controls.unseat(p)
	game.player = game.chefs[0]
	for k in game.chefs.size():
		if game.chefs[k].trim != k:
			game.chefs[k].set_trim(k)
	for n: Node3D in [ch.cursor, ch.no_mark, ch.range_marks, ch.ghost, ch.tool_ghost]:
		if n:
			n.queue_free()
	game._recolour_cursors()
	game.hud.day_ui.trim_prompts(game.chefs.size())
	_walk_out(ch)
	game.hud.day_ui.say("Chef %d left." % (p + 1))
	game.hud.hints_ui.refresh_input()
	if game.phase == Game.Phase.BUILD:
		game.hud.hints_ui.show_build()
	_refresh_ready()
	if game.phase == Game.Phase.SUMMARY and game.ready_chefs.size() >= game.chefs.size() and not game.ready_chefs.is_empty():
		game.session.open_build()
	return true


## What a leaving chef carries goes on the nearest free counter, or is lost.
func set_down(ch: Player) -> void:
	var best: Station = null
	var best_d := INF
	for st: Station in game.stations.values():
		if st.type in ["counter", "pass"] and st.item == "":
			var d := st.position.distance_to(ch.position)
			if d < best_d:
				best_d = d
				best = st
	if best != null:
		if ch.held == "dishes" and not ch.dishes.is_empty():
			best.set_dish(ch.dishes[0])   # the rest go with the tray
		elif Tray.parse(ch.held).size() > 0:
			best.set_item(ch.held, ch.held_quality)
		game.audio.sfx("putdown")
	ch.set_held("")
	game.hud.day_ui.refresh_tickets()


## A chef who left walks out of the door and down the street, then is gone.
func _walk_out(ch: Player) -> void:
	ch.set_process(false)
	var tw := ch.create_tween()
	var path: Array[Vector3] = [Grid.center(Game.ENTRANCE_CELL), Game.DOORWAY, Grid.center(Game.DOOR), Grid.center(Game.EXIT)]
	var from := ch.position
	for at: Vector3 in path:
		var t := from.distance_to(at) / Player.SPEED
		from = at
		tw.tween_callback(func() -> void:
			var d := at - ch.position
			if d.length() > 0.01:
				ch.aim = Vector3(d.x, 0, d.z).normalized())
		tw.tween_property(ch, "position", at, t)
	tw.tween_callback(ch.queue_free)


## The receipt needs every player's Confirm. With one chef, one is enough.
func confirm_receipt(p: int) -> void:
	if game.phase != Game.Phase.SUMMARY or p >= game.chefs.size():
		return
	if not game.ready_chefs.has(game.chefs[p]):
		game.ready_chefs.append(game.chefs[p])
		game.audio.sfx("tick")
	if game.ready_chefs.size() >= game.chefs.size():
		game.session.open_build()
	else:
		_refresh_ready()


## Back on the receipt takes a player's ready back, until everyone has confirmed.
func unconfirm_receipt(p: int) -> void:
	if game.phase != Game.Phase.SUMMARY or p >= game.chefs.size() or not game.ready_chefs.has(game.chefs[p]):
		return
	game.ready_chefs.erase(game.chefs[p])
	game.audio.sfx("tick", 0.0, 0.8)
	_refresh_ready()


## The door card (opening up, or closing early) needs every chef. The first to use
## it turns it half way and shows their ready marker; using it again takes that
## back; the last one turns it. With one chef it turns at once, as before.
func _agree_at_door(ch: Player) -> bool:
	if game.chefs.size() <= 1:
		return true
	if game.ready_chefs.has(ch):
		game.ready_chefs.erase(ch)
		game.audio.sfx("flip", 0.0, 0.8)
	else:
		game.ready_chefs.append(ch)
	if game.ready_chefs.size() >= game.chefs.size():
		game.ready_chefs.clear()   # the card turns all the way (set_door), not part way
		game.hud.hints_ui.refresh_ready()
		return true
	game.audio.sfx("flip")
	game.hud.day_ui.say("Chef %d is ready. Everyone uses the door card to %s." % [game.chefs.find(ch) + 1, "open" if game.phase == Game.Phase.BUILD else "close"]
		if game.ready_chefs.has(ch) else "Chef %d is not ready." % (game.chefs.find(ch) + 1))
	_refresh_ready()
	return false


## Each player's state for the ready markers: "ready" or "waiting", by index.
func ready_states() -> Array[String]:
	var out: Array[String] = []
	for ch in game.chefs:
		out.append("ready" if game.ready_chefs.has(ch) else "waiting")
	return out


## The door card turns part way for each chef who is ready; the receipt and the
## card show the ready markers.
func _refresh_ready() -> void:
	if game._door_turn != null and game.phase in [Game.Phase.BUILD, Game.Phase.SERVICE]:
		var shut := PI if game.phase == Game.Phase.BUILD else 0.0   # the side showing now
		var share := float(game.ready_chefs.size()) / maxf(game.chefs.size(), 1)
		game._door_turn.create_tween().tween_property(game._door_turn, "rotation:y", lerpf(shut, PI - shut, share * 0.5), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	game.hud.hints_ui.refresh_ready()


## Player p pressed an action, on whatever device is theirs (see Controls).
## The options screen and the shop are shared; the rest is done by that
## player's chef.
func act(p: int, action: String, echo := false) -> void:
	if action == "aim":
		return   # held, not pressed: read each frame (`Controls.aiming`)
	if action in ["buy", "prev", "next"] and not game.upgrades.strip_open(p):
		if action == "buy":
			action = "use"   # Space is E everywhere but the lifted piece's strip
		elif game.controls and p < game.controls.players.size() and game.controls.players[p].mode == "pad":
			action = "turn"   # LB and RB turn the piece when there is nothing to choose
		else:
			return
	if game.hud.options_ui.options_open():
		game.hud.options_ui.options_action(action, echo)
		return
	if game.hud.options_ui.pause_open():
		game.hud.options_ui.pause.action(action, echo)
		return
	if game.hud.options_ui.title_open():
		if action == "options":
			game.hud.options_ui.toggle_options()
		else:
			game.hud.options_ui.title.action(action, echo)
		return
	if game.hud.desk_open():
		game.hud.desk.action(action, echo)
		return
	if game.hud.menu_open():
		game.hud.menu.action(action, echo)
		return
	if game.hud.bill_open() and p < game.chefs.size() and game.hud.bill.chef == game.chefs[p]:
		game.hud.bill.action(action, echo)
		return
	if echo:
		return
	if action == "options":
		game.hud.options_ui.toggle_pause()
		return
	if p >= game.chefs.size():
		return   # a seated player with no chef yet
	var ch := game.chefs[p]
	match game.phase:
		Game.Phase.SERVICE:
			if game.preps.has(p):
				if action == "use":
					game.prep_games.prep_press(p)
				elif action == "back":
					game.prep_games.cancel_prep(p)
			elif action == "back" and ch.held == "bill":
				ch.set_held("")   # the slip is thrown away (PRD 11)
				game.audio.sfx("putdown")
			elif action == "back" and ch.held == "" and game.inspected == null:
				game.hud.options_ui.toggle_pause()
			elif action == "turn":
				game.serving.turn_tap(game.stations.get(ch.target_cell()))
			elif action == "menu":
				game.menu_stock.open_menu(ch)   # refused: it says why
			elif game.floor_dirt.is_down(ch) or game.floor_dirt.helping(ch) != null:
				pass   # on the floor, or helping someone up (PRD 9.3)
			elif action == "use" and game.floor_dirt.help_up(ch):
				ch.punch()
			elif action == "use":
				var st: Station = game.world.station_at(ch.target_cell())
				if game.clean_kit.floor_first(ch):
					game.clean_kit.floor_use(ch)   # dirt straight ahead, a tool in hand (PRD 9.4)
				elif st != null and game.cooking.prompt_for(st, ch) != "":
					game.cooking.use_station(st, false, ch)
				elif game.clean_kit.floor_use(ch):
					pass   # a mop or sponge on the floor (PRD 9.4)
				elif not game.day.use_door(ch) and st != null:
					game.cooking.use_station(st, false, ch)
		Game.Phase.SUMMARY:
			if action == "confirm":
				confirm_receipt(p)
			elif action == "back":
				unconfirm_receipt(p)
			elif action == "town":
				game.hud.screens_ui.toggle_town()
		Game.Phase.CLOSED:
			if action == "confirm":
				game.day.restart()
		Game.Phase.BUILD:
			if game.shopper == ch:
				game.shop_action(action)
			else:
				_build_act(action, ch)


func _build_act(action: String, ch: Player = null) -> void:
	ch = game._me(ch)
	match action:
		"use":
			game.room_edit.build_interact(ch)
		"back":
			if ch.hand.is_empty():
				game.hud.options_ui.toggle_pause()
			else:
				game.placing.cancel_hand(ch)
		"turn":
			game.placing.rotate_hand(ch)
		"prev":
			game.upgrades.strip_move(-1, ch)
		"next":
			game.upgrades.strip_move(1, ch)
		"buy":
			game.upgrades.strip_buy(ch)
		"shop":
			if game.upgrades.strip_open(game.chefs.find(ch)) and game.controls and game.controls.players[game.chefs.find(ch)].mode == "pad":
				game.upgrades.strip_buy(ch)   # Y on a pad buys the chosen upgrade
			else:
				game.session.open_shop(ch)
		"menu":
			game.menu_stock.open_menu(ch)
		"sell":
			if not ch.hand.is_empty() and Catalog.is_build_tool(ch.hand.id):
				if game.room_edit._hover_point(ch) != Vector3.INF and game.room_edit.remove_at(game.placing.snap(game.room_edit._hover_point(ch), ch), ch):
					game.room_edit._plan_changed()
					game.audio.sfx("coin")
				else:
					game.audio.sfx("fail")
			elif not game.placing.sell_hand(ch):
				game.audio.sfx("fail")
