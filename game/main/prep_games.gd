class_name GamePrepGames
extends RefCounted
## The prep minigames being played, per player: starting, pressing, ticking, finishing;
## the stoves' ticks and the looping sizzle fades.

var game: Game


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- prep minigames

## `src`: the kind the chef held, when it differs from what is made (a lemon for
## lemonade, PRD 8.6); it sits on the tool meanwhile and comes back on Back.
func start_prep(p: int, st: Station, tool: String, ing: String, src := "", cup: Dish = null) -> void:
	var chef: Player = game.chefs[p]
	var hands := {"cup": cup, "dishes": chef.dishes.duplicate(), "on_tray": chef.on_tray}
	var q := st.q(tool) if st.q(tool) > 0.0 else 1.0
	game.preps[p] = {"tool": tool, "st": st, "ing": ing, "t": 0.0, "hits": [], "presses": 0, "fill": 0.0, "last": 0.0,
		"q": q, "sweep": Prep.chop_sweep(q), "auto": Kitchen.is_auto(st.node),
		"src": src if src != "" else Tray.kind("raw", ing), "v": 0.0, "w": 0.0, "was_held": true}
	if cup != null:
		game.preps[p].merge(hands)   # the dishes in hand wait while the cup is filled
	if tool == "saw":
		game.preps[p].sweep = Prep.saw_stroke(q)
	st.prep_by = p
	chef.set_held("")
	if tool != "pour":
		st.set_item(game.preps[p].src)
	st.show_widget(tool, q, ing if tool in ["pour", "grate", "blend", "juice"] else "")
	chef.punch()
	st.used()
	_show_prep(p)


func prep_of(p := 0) -> Dictionary:
	return game.preps.get(p, {})


## Use was pressed during a minigame.
func prep_press(p: int) -> void:
	var s: Dictionary = game.preps[p]
	if s.get("auto", false):
		return   # it plays itself
	match s.tool:
		"chop":
			if s.hits.size() == int(s.t / s.sweep) and s.hits.size() < Prep.CHOP_SWEEPS:
				var hit := Prep.chop_hit(_chop_pos(s), s.q)
				s.hits.append(hit)
				game.audio.sfx("chop", 0.1, 1.0 if hit else 0.8)
				game.chefs[p].punch()
		"slice":
			s.presses += 1
			s.last = s.t
			game.audio.sfx("slice", 0.15)
			game.chefs[p].punch()
		"saw":
			if s.hits.size() == int(s.t / s.sweep) and s.hits.size() < Prep.SAW_STROKES:
				var hit := Prep.saw_hit(_chop_pos(s), s.q)
				s.hits.append(hit)
				game.audio.sfx("chop", 0.1, 0.7 if hit else 0.55)
				game.chefs[p].punch()
		"blend":
			s.presses += 1
			s.w += Prep.blend_kick(s.q)
			game.audio.sfx("slice", 0.15, 0.6)
			game.chefs[p].punch()
		"steam":
			s.lift = true
	_show_prep(p)


## Back leaves a press-based minigame and gives the ingredient back raw.
func cancel_prep(p: int) -> void:
	var s: Dictionary = game.preps[p]
	game.preps.erase(p)
	var st: Station = s.st
	st.prep_by = -1
	st.hide_widget()
	if s.tool != "pour":
		st.set_item("")
		game.chefs[p].set_held(s.src, Prep.PLAIN if str(s.src).begins_with("prep") else 1.0)
	elif s.get("cup") != null:
		game.chefs[p].set_held("dishes", 1.0, s.dishes, s.on_tray)
	game.audio.sfx("putdown")


func _chop_pos(s: Dictionary) -> float:
	return fmod(s.t, s.sweep) / s.sweep


func _tick_preps(delta: float) -> void:
	for p: int in game.preps.keys():
		var s: Dictionary = game.preps[p]
		if s.get("frozen", false):
			continue   # a demo shot
		s.t += delta
		var result := ""
		if s.get("auto", false):   # an auto piece plays itself: always good, no burst
			s.presses = mini(int(s.t / Prep.AUTO_TIME * Prep.SLICE_COUNT), Prep.SLICE_COUNT)
			s.hits = []
			for k in mini(int(s.t / Prep.AUTO_TIME * Prep.CHOP_SWEEPS), Prep.CHOP_SWEEPS):
				s.hits.append(true)
			if s.t >= Prep.AUTO_TIME:
				_finish_prep(p, "good")
			else:
				_show_prep(p)
			continue
		match s.tool:
			"chop":
				while s.hits.size() < mini(int(s.t / s.sweep), Prep.CHOP_SWEEPS):
					s.hits.append(false)   # a sweep went by without a press
				if s.hits.size() >= Prep.CHOP_SWEEPS:
					result = Prep.chop(s.hits.count(true))
			"slice":
				if s.t >= Prep.slice_time(s.q) or (s.presses >= Prep.SLICE_COUNT and s.t - s.last > 0.5):
					result = Prep.slice(s.presses, s.q)
			"pour":
				if game.controls.holding(p, "use"):
					s.fill += Prep.pour_rate(s.q) * delta
					if s.fill > 1.04:
						result = "bad"   # overflowed
				else:
					result = Prep.pour(s.fill, s.q)
			"grate":
				var holding := game.controls.holding(p, "use")
				s.v = Prep.grate_speed(s.v, holding, delta, s.q)
				var band := Prep.grate_band(s.q)
				if s.v >= band.x and s.v <= band.y:
					s.fill += delta / Prep.GRATE_FILL
					if fmod(s.t, 0.25) < delta:
						game.audio.sfx("slice", 0.1, 1.3)
				result = Prep.grate(s.t, s.fill >= 1.0, s.v > 1.0, s.q)
			"saw":
				while s.hits.size() < mini(int(s.t / s.sweep), Prep.SAW_STROKES):
					s.hits.append(false)   # a stroke went by without a press
				if s.hits.size() >= Prep.SAW_STROKES:
					result = Prep.saw(s.hits.count(true))
			"juice":
				var holding := game.controls.holding(p, "use")
				if holding:
					s.fill += Prep.juice_rate(s.q) * delta
					if s.fill > 1.0:   # pressed too hard: the pips squirt
						s.hits.append(false)
						s.fill = 0.0
						game.audio.sfx("wobble", 0.1)
				elif s.fill >= Prep.JUICE_MIN:
					var hit := Prep.juice_hit(s.fill, s.q)
					s.hits.append(hit)
					game.audio.sfx("pickup", 0.1, 1.2 if hit else 0.8)
					game.chefs[p].punch()
					s.fill = 0.0
				else:
					s.fill = 0.0
				if s.hits.size() >= Prep.JUICE_HALVES:
					result = Prep.juice(s.hits.count(true))
			"blend":
				s.w = Prep.blend_settle(s.w, delta)
				result = Prep.blend(s.t, s.presses, s.w > 1.0, s.q)
			"steam":
				var frac: float = s.t / Prep.steam_time(s.q)
				if s.get("lift", false) or frac >= Prep.STEAM_OVER:
					result = Prep.steam(frac, s.q)
		if result != "":
			_finish_prep(p, result)
		else:
			_show_prep(p)


func _show_prep(p: int) -> void:
	var s: Dictionary = game.preps[p]
	var w: PrepWidget = s.st.widget
	match s.tool:
		"chop":
			w.show_state({"pos": _chop_pos(s), "hits": s.hits})
		"slice":
			w.show_state({"presses": s.presses, "left": 1.0 - s.t / (Prep.AUTO_TIME if s.get("auto", false) else Prep.slice_time(s.q))})
		"pour":
			w.show_state({"fill": s.fill})
		"grate":
			w.show_state({"v": s.v, "fill": s.fill})
		"saw":
			w.show_state({"pos": _chop_pos(s), "stroke": int(s.t / s.sweep), "hits": s.hits})
		"juice":
			w.show_state({"p": s.fill, "hits": s.hits})
		"blend":
			w.show_state({"w": s.w, "pulses": s.presses})
		"steam":
			w.show_state({"frac": s.t / Prep.steam_time(s.q)})


func _finish_prep(p: int, result: String) -> void:
	var s: Dictionary = game.preps[p]
	game.preps.erase(p)
	var st: Station = s.st
	st.prep_by = -1
	st.hide_widget()
	if s.tool != "pour":
		st.set_item("")
	if s.get("cup") != null:
		(s.cup as Dish).add(Tray.kind("prep", s.ing), Prep.quality_of(result))
		game.chefs[p].set_held("dishes", 1.0, s.dishes, s.on_tray)
	else:
		game.chefs[p].set_held(Tray.kind("prep", s.ing), Prep.quality_of(result))
	game.audio.sfx("pickup")
	_prep_done(p, st, s.tool, result)


## A minigame ended: a mark over the tool, and the chef's burst or penalty.
func _prep_done(p: int, st: Station, tool: String, result: String) -> void:
	if result == "" or p < 0:
		return
	game.floor_dirt.prep_grease(tool, result, game.chefs[p].cell(), st)
	PrepWidget.pop(st, Vector3(0, 2.0, 0), result)
	match Prep.reward(tool, result, Kitchen.is_auto(st.node) and tool in ["chop", "slice"]):
		"burst":
			game.chefs[p].boost("burst")
			game.audio.sfx("zoom")
		"penalty":
			game.chefs[p].boost("penalty")
			game.audio.sfx("wobble")


func _cancel_all_preps() -> void:
	for p: int in game.preps.keys():
		cancel_prep(p)


func _tick_stoves(delta: float) -> void:
	var loops := {}
	for st: Station in game.stations.values():
		var stage := st.tick_cooking(delta)
		if stage == "prep":
			game.audio.sfx("ding")
			game.audio.burst(st.position + Vector3(0, 1.2, 0), "stars", 0.4)
		elif stage == "burnt":
			game.audio.sfx("burn")
			game.audio.shake(0.08)
		elif stage == "rested":
			game.audio.sfx("tick")
		if st.sizzle_stage() != "":
			loops[st.sizzle_stage()] = true
	_fade_loops(loops, delta)


## Fades each looping sound toward on (wanted) or off, so a patty's sizzle changes
## smoothly as it cooks; one that has faded out stops.
func _fade_loops(want: Dictionary, delta: float) -> void:
	for id: String in Game.LOOPING:
		if not game._sfx.has(id):
			continue
		var p: AudioStreamPlayer = game._sfx[id]
		var on := want.has(id)
		if on and not p.playing:
			p.volume_db = Game.LOOP_OFF
			p.play()
		if p.playing:
			p.volume_db = move_toward(p.volume_db, float(Game.SOUNDS[id]) if on else Game.LOOP_OFF, Game.LOOP_FADE * delta)
			if not on and p.volume_db <= Game.LOOP_OFF:
				p.stop()
