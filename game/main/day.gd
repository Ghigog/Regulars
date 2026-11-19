class_name GameDay
extends RefCounted
## The day: its length and progress, starting service, the critic's booking and exit,
## inspecting guests; the door card (open, close early), the end of the day and restart.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- the day

## Days are the same length; they get busier and less forgiving (Town).
func day_length() -> float:
	return Town.day_length(game.ledger.day)


func table_patience() -> float:
	return Town.table_patience(game.ledger.day)


func day_progress() -> float:
	return clampf(game.clock / day_length(), 0.0, 1.0) if game.phase == Game.Phase.SERVICE else 1.0


const GLOW_LOW := 0.15
const GLOW_HIGH := 0.4
var _glow: MeshInstance3D
var _glow_tween: Tween
var _glow_on := false


func start_day() -> void:
	if game.phase == Game.Phase.CLOSED:
		return
	game.ready_chefs.clear()
	for ch in game.chefs:
		if ch.hand.get("moving", false):
			game.placing.cancel_hand(ch)   # a piece still being carried goes back where it was
		ch.hand = {}
		if ch.held == "dishes" or not Tray.parse(ch.held).is_empty():
			ch.set_held("")   # yesterday's food does not carry into the new day
	game.phase = Game.Phase.SERVICE
	game.clock = 0.0
	game.shopper = null
	game.upgrading = false
	set_door(true)
	game.hud.close_menu()
	game.desk.close_desk()
	game.desk._clear_applicants()
	game.hud.receipt_ui.hide_card()
	game.hud.hide_build()
	game.ledger.pay_stock(game.menu_stock.night_cost())   # the door checked it can be paid (tests may skip the door)
	game.floor_dirt.mess.treat = game.menu_stock.treat_active()   # tonight's laying lasts the day (PRD 9.5)
	game.floor_dirt.mess.extractor = game.kitchen.has_extractor()
	game.clean_kit.start_day()
	game.floor_dirt.redraw()
	game.desk.pay_staff()
	game.menu_board.refresh(game.menu_stock.tonight_menu())
	game.town.new_day()
	game.perfect_streak = 0
	var coming := game.town.roll_guests(game.ledger.day, (Town.FLYER_BOOST if game.flyers_out else 0.0) + game.critic.visit_boost(game.ledger.day))
	coming = coming.filter(func(i: int) -> bool: return game.staff.may_visit(i, game.ledger.day))   # staff work; they eat out only on a day off
	var critic_day := game.critic.visits_on(game.ledger.day)
	if critic_day:   # they come alone, whatever the dice or a grudge say
		coming.erase(game.critic.critic_idx)
	var groups := game.town.make_groups(coming, game.seating.max_party(), game.ledger.day)
	var flyered := game.flyers_out
	game.flyers_out = false
	game.arrivals.clear()
	game.critic_guest = null
	game._critic_seen = {}
	game._critic_rated = {}
	for i in groups.size():
		var t := 2.0 + (i + game.town.rng.randf() * 0.6) * (day_length() - 2.0) / groups.size()
		game.arrivals.append({"time": t, "group": groups[i]})
	if critic_day:
		_book_critic(game.critic.arrival_time(day_length()))
	game.crew.start_day()   # staff at work today walk in as the door opens (PRD 10.6)
	game.audio.play_music("day")
	game.hud.day_ui.show_banner("Day %d" % game.ledger.day)
	game.hud.day_ui.say(("%d guests expected today." % coming.size()) + (" The flyers worked." if flyered else ""))
	game.audio.sfx("day")


## Puts the critic in today's arrivals at `time`, in order. Nothing shows it.
func _book_critic(time: float) -> void:
	var k := 0
	while k < game.arrivals.size() and float(game.arrivals[k].time) <= time:
		k += 1
	game.arrivals.insert(k, {"time": time, "group": [game.critic.critic_idx], "critic": true})


## Whether `g` is the critic (on any day; the interface marks them only once known).
func is_critic(g: Guest) -> bool:
	return g != null and g.idx == game.critic.critic_idx


## The critic is leaving: rates the visit from what they saw. Printed at the end of the day.
func _critic_leaves(g: Guest, walked: bool) -> void:
	if g != game.critic_guest or not game._critic_rated.is_empty():
		return
	walked = walked or g.mood.disgust_level() >= 3
	game._critic_rated = {"walked": walked, "ratings": Critic.rate(float(game._critic_seen.get("patience", 0.0)),
		float(game._critic_seen.get("quality", -1.0)), g.mood.disgust, g.mood.disgust_level(), game.menu_stock.tonight_menu(), walked, game.critic.strictness())}
	g.mood.think(Critic.thought("leave"))
	game.critic_guest = null


## Opens the guest card for `g`, or closes it with null.
func inspect(g: Guest) -> void:
	game.inspected = g
	game.hud.show_guest(g)


## The guest drawn nearest a point on screen, or null if none is close.
func guest_at(screen: Vector2, within := 60.0) -> Guest:
	var best: Guest = null
	for g in game.guests:
		var d := game.cam.unproject_position(g.position + Vector3(0, 0.8, 0)).distance_to(screen)
		if d < within:
			within = d
			best = g
	return best


# ---------------------------------------------------------------- the door card

## The OPEN / CLOSED card on a string in the doorway. It hangs from a nail under
## the lintel, facing the street, and spins on its string to show the other side.
func _build_door_card() -> void:
	game._door_hang = Node3D.new()
	game._door_hang.position = Game.DOORWAY + Vector3(0.3, 2.03, 0)
	game._door_hang.rotation.y = PI / 2   # local +z looks out at the street
	game.add_child(game._door_hang)
	Build.ball(game._door_hang, Vector3.ZERO, 0.035, Build.TRIM)
	game._door_turn = Node3D.new()
	game._door_hang.add_child(game._door_turn)
	for side: float in [-1.0, 1.0]:
		var string := Build.box(game._door_turn, Vector3.ZERO, Vector3(0.018, 0.33, 0.018), Build.TRIM)
		string.position = Vector3.ZERO
		string.rotation.z = PI - side * 0.74
		string.position = Vector3(side * 0.11, -0.12, 0)
	Build.box(game._door_turn, Vector3(0, -0.56, 0), Vector3(0.62, 0.34, 0.03), Build.PAPER)
	for open: bool in [true, false]:
		var z := 0.014 if open else -0.014
		Build.box(game._door_turn, Vector3(0, -0.53, z), Vector3(0.55, 0.28, 0.012), Build.LEAF if open else Build.CORAL_DARK)
		var l := Label3D.new()
		l.text = "OPEN" if open else "CLOSED"
		l.font = Hud.lettering()
		l.font_size = 64
		l.pixel_size = 0.0034 if open else 0.0028
		l.outline_size = 0
		l.modulate = Color(Build.PAPER)
		l.double_sided = false
		l.position = Vector3(0, -0.4, z * 1.6)
		l.rotation.y = 0.0 if open else PI
		game._door_turn.add_child(l)
	_build_door_glow()


## A faint warm halo behind the card that breathes at night, while the card can be
## flipped to OPEN. It hangs on the nail, not on the card, so it does not spin.
func _build_door_glow() -> void:
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = fade
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)   # clear at the rim, so no hard edge
	tex.width = 128
	tex.height = 128
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.albedo_color = Color(Build.WARN, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.1)
	quad.material = mat
	_glow = MeshInstance3D.new()
	_glow.mesh = quad
	_glow.position = Vector3(0, -0.53, -0.04)
	_glow.visible = false
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game._door_hang.add_child(_glow)


## Starts or stops the halo as the card's state changes (called every frame).
func update_door_glow() -> void:
	var want := game.phase == Game.Phase.BUILD and not game.door_open and game.menu_stock.open_block() == ""
	if want == _glow_on or _glow == null:
		return
	_glow_on = want
	if _glow_tween:
		_glow_tween.kill()
	var mat := _glow.mesh.material as StandardMaterial3D
	_glow_tween = _glow.create_tween()
	if want:
		_glow.visible = true
		_glow_tween.tween_property(mat, "albedo_color:a", GLOW_HIGH, 0.5)
		_glow_tween.set_loops()   # then breathes: slow in, slow out
		_glow_tween.tween_property(mat, "albedo_color:a", GLOW_LOW, 1.0).set_trans(Tween.TRANS_SINE)
		_glow_tween.tween_property(mat, "albedo_color:a", GLOW_HIGH, 1.0).set_trans(Tween.TRANS_SINE)
	else:
		_glow_tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
		_glow_tween.tween_callback(func() -> void: _glow.visible = false)


## Flips the card, with a spin on its string and a swing from the nail.
func set_door(open: bool) -> void:
	if game.door_open == open:
		return
	game.door_open = open
	game.audio.sfx("flip")
	var tw := game._door_turn.create_tween()
	tw.tween_property(game._door_turn, "rotation:y", 0.0 if open else PI, 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	game._door_hang.rotation.z = 0.5
	game._door_hang.create_tween().tween_property(game._door_hang, "rotation:z", 0.0, 1.4) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func at_door(ch: Player = null) -> bool:
	ch = game._me(ch)
	var d := ch.position - Game.DOORWAY
	return Vector2(d.x, d.z).length() < Game.DOOR_REACH


## What the chef can do with the door card from here: "Open up" at the end of the
## build phase, "Close early" from the middle of the day on, or nothing.
func door_action(ch: Player = null) -> String:
	ch = game._me(ch)
	if not at_door(ch):
		return ""
	if ch.held == "rubbish_bag":
		return "Take out rubbish"
	if game.phase == Game.Phase.BUILD and ch.hand.is_empty() and game.shopper != ch:
		return "Open up"
	if game.phase == Game.Phase.SERVICE and game.door_open and not game.arrivals.is_empty() and day_progress() >= Game.CLOSE_EARLY_FROM:
		return "Close early"
	return ""


func use_door(ch: Player = null) -> bool:
	ch = game._me(ch)
	match door_action(ch):
		"Open up":
			var why := game.menu_stock.open_block()
			if why != "":
				game.audio.sfx("fail")
				game.hud.day_ui.say(why)
				game.hud.hints_ui.show_build()
				return false
			if game.coop._agree_at_door(ch):
				start_day()
		"Close early":
			if game.coop._agree_at_door(ch):
				close_early()
		"Take out rubbish":
			ch.set_held("")
			game.audio.sfx("putdown")
		_:
			return false
	ch.punch()
	return true


## Nobody else comes in today. Guests already here, queue included, stay and are
## served as usual; the day ends when the last of them has gone.
func close_early() -> void:
	if game.phase != Game.Phase.SERVICE or not game.door_open:
		return
	if game.arrivals.any(func(a: Dictionary) -> bool: return a.get("critic", false)):
		game.critic.postpone(game.ledger.day)   # they come tomorrow instead
	game.arrivals.clear()
	set_door(false)
	game.hud.day_ui.say("Closed. Guests already here can stay.")


func _end_day() -> void:
	game.prep_games._cancel_all_preps()
	game.crew.clear()   # the staff go home
	game.floor_dirt.clear_slips()   # a chef still down gets up for the night
	game.clean_kit.end_day()   # robot sweepers go back to their docks
	game.floor_dirt.mess.treat = {}   # the day's treatments are worn off (PRD 9.5)
	game.floor_dirt.redraw()
	set_door(false)
	game.shopper = null
	game.upgrading = false
	game.ready_chefs.clear()
	game.phase = Game.Phase.SUMMARY
	game.audio.play_music("night")
	inspect(null)
	var unordered := game.menu_stock.unordered_nudges()
	game.last_day = game.ledger.end_day()
	if not unordered.is_empty():
		game.last_day["unordered"] = unordered
	if not game._critic_rated.is_empty():   # the paper prints the review with tonight's receipt
		game.last_day["review"] = game.critic.publish(game._critic_rated.ratings, game._critic_rated.walked, game.town, int(game.last_day.day))
		game._critic_rated = {}
		var before := game.ledger.reputation
		game.ledger.record_review(int(game.last_day.review.stars))   # the review moves the meter (review, item 9)
		game.last_day["rep_change"] = float(game.last_day.get("rep_change", 0.0)) + game.ledger.reputation - before
		game.last_day["reputation"] = game.ledger.reputation
		game.ledger.today.rep_change = 0.0   # counted on tonight's receipt
	game.hud.receipt_ui.show_summary(game.last_day)
	game.audio.sfx("coin")


func _close_down() -> void:
	game.prep_games._cancel_all_preps()
	game.crew.clear()
	game.audio.play_music("closed")
	game.phase = Game.Phase.CLOSED
	SaveGame.delete(game.save_path)   # the run is over: nothing to continue
	var days := game.ledger.day
	var earned := game.ledger.lifetime_earnings()
	var best := load_best()
	var is_record: bool = days > int(best.days) or (days == int(best.days) and earned > int(best.earned))
	if is_record:
		var f := FileAccess.open(game.best_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"days": days, "earned": earned}))
	game.hud.screens_ui.show_closed(days, earned, best, is_record)
	game.audio.sfx("fail")


func load_best() -> Dictionary:
	var best := {"days": 0, "earned": 0}
	if FileAccess.file_exists(game.best_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(game.best_path))
		if data is Dictionary and data.has("days") and data.has("earned"):
			best = data
	return best


func restart() -> void:
	Game._theme_picked = false   # a new run: the theme card comes up again
	Game._kept_seats = game.controls.seats.duplicate()   # whoever is seated stays seated
	game.get_tree().reload_current_scene()
