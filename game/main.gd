extends Node3D
## Regulars vertical slice: an endless run of days. Cook meat, serve guests, get paid.

enum Phase { SERVICE, SUMMARY, CLOSED }

const W := 10            # restaurant interior is 10 x 7 cells
const H := 7             # rows 7 and 8 are the pavement outside
const DOOR := Vector2i(5, 7)
const SPAWN := Vector2i(9, 8)
const EXIT := Vector2i(0, 8)
const BILL := 12
const SIGHT_RANGE := 7
const SOUNDS: Array[String] = ["pickup", "putdown", "ding", "serve", "coin", "fail", "burn", "day", "wash", "sizzle"]

var grid: Grid
var town: Town
var ledger: Ledger
var phase: int = Phase.SERVICE
var stations := {}               # Vector2i -> Station
var guests: Array[Guest] = []
var queue: Array[Guest] = []
var seat_taken := {}             # Vector2i -> Guest
var arrivals: Array[Dictionary] = []
var clock := 0.0
var last_day := {}
var best_path := "user://regulars_best.json"
var player: Player
var hud: Hud
var cam: Camera3D
var _cursor: MeshInstance3D
var _prompt: Label3D
var _gross: Array[Dictionary] = []
var _sfx := {}
var _shot_path := ""
var _shot_time := 0.0


func _ready() -> void:
	var seed_value := int(Time.get_unix_time_from_system())
	grid = Grid.new(W, H + 2)
	town = Town.new(seed_value)
	ledger = Ledger.new()
	_build_scenery()
	_build_layout()
	_load_sounds()
	player = Player.new()
	add_child(player)
	player.setup(self, Vector2i(2, 3))
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	_cursor = Build.box(self, Vector3.ZERO, Vector3(0.96, 0.03, 0.96), "#ffd34e", 1.0)
	_prompt = Label3D.new()
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 44
	_prompt.outline_size = 14
	_prompt.pixel_size = 0.006
	_prompt.modulate = Color("#ffe9a8")
	add_child(_prompt)
	_shot_path = OS.get_environment("REGULARS_SHOT")
	start_day()
	_apply_demo(OS.get_environment("REGULARS_DEMO"))


## Dev aid for screenshots: REGULARS_DEMO=cook or =summary jumps to that moment.
func _apply_demo(demo: String) -> void:
	if demo == "cook":
		find_station("stove").set_item("raw_patty")
		find_station("stove").cook = -8.0
		stations[Vector2i(2, 0)].set_item("raw_patty")
		player.position = Grid.center(Vector2i(1, 1))
		player.facing = Vector2i(0, -1)
		player.set_held("plate")
		for a in arrivals:
			a.time = 1.0
	elif demo == "summary":
		ledger.record_sale(BILL, 5)
		ledger.record_sale(BILL, 3)
		arrivals.clear()


# ---------------------------------------------------------------- world

func _build_scenery() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#f0dfc4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff1e0")
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 13.5
	add_child(cam)
	var focus := Vector3(W / 2.0 + 0.3, 0, H / 2.0 + 1.2)
	cam.look_at_from_position(focus + Vector3(14, 15, 14), focus)

	Build.box(self, Vector3(W / 2.0, -0.14, H / 2.0), Vector3(W + 0.5, 0.12, H + 0.5), "#5a4636")
	Build.box(self, Vector3(W / 2.0, -0.12, H + 1.0), Vector3(W + 0.5, 0.1, 2.0), "#cdbfae")
	for x in W:
		for y in H:
			var col := "#d9a066" if y % 2 else "#cf9458"
			if x < 4:
				col = "#f4ead8" if (x + y) % 2 else "#8fc7c3"
			Build.box(self, Vector3(x + 0.5, -0.02, y + 0.5), Vector3(0.98, 0.02, 0.98), col)
	# Back and left walls are scenery; the grid bounds already stop movement.
	Build.box(self, Vector3(W / 2.0, 0, -0.1), Vector3(W + 0.4, 2.2, 0.2), "#fff6e6")
	Build.box(self, Vector3(-0.1, 0, H / 2.0), Vector3(0.2, 2.2, H + 0.4), "#fff6e6")
	Build.box(self, Vector3(7, 1.1, 0.02), Vector3(5.8, 0.9, 0.05), "#e56b5d")
	for wx: float in [5.5, 8.5]:
		Build.box(self, Vector3(wx, 1.05, 0.04), Vector3(1.3, 0.9, 0.06), "#9fd4ea")
	Build.box(self, Vector3(DOOR.x + 0.5, 0.0, H + 0.2), Vector3(1.0, 0.02, 0.5), "#d9534f")


func _build_layout() -> void:
	for spot: Array in [
		["fridge", 0, 0], ["stove", 1, 0], ["stove", 2, 0], ["counter", 3, 0],
		["plates", 0, 2], ["sink", 0, 3], ["bin", 0, 5],
		["pass", 4, 0], ["pass", 4, 1], ["pass", 4, 2], ["pass", 4, 3], ["pass", 4, 4],
		["table", 6, 1], ["table", 8, 3], ["table", 6, 5], ["plant", 9, 0],
	]:
		add_station(spot[0], Vector2i(spot[1], spot[2]))
	# Low front wall with a doorway; guests cannot see or walk through it.
	for x in W:
		if x != DOOR.x:
			add_wall(Vector2i(x, H), 0, 0.3)


func add_station(type: String, cell: Vector2i, tier := 1) -> Station:
	var st := Station.new()
	add_child(st)
	st.setup(type, cell, tier)
	stations[cell] = st
	grid.blocked[cell] = true
	for s in st.seats:
		grid.reserved[s] = true
	return st


func add_wall(cell: Vector2i, axis: int, height := 1.1) -> void:
	grid.walls[Vector3i(cell.x, cell.y, axis)] = true
	if axis == 0:
		Build.box(self, Vector3(cell.x + 0.5, 0, cell.y), Vector3(1.04, height, 0.12), "#fff6e6")
	else:
		Build.box(self, Vector3(cell.x, 0, cell.y + 0.5), Vector3(0.12, height, 1.04), "#fff6e6")


func find_station(type: String) -> Station:
	for st: Station in stations.values():
		if st.type == type:
			return st
	return null


# ---------------------------------------------------------------- sound & feedback

func _load_sounds() -> void:
	for id in SOUNDS:
		var path := "res://assets/sfx/%s.wav" % id
		if not ResourceLoader.exists(path):
			continue
		var p := AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load(path)
		if id == "sizzle":
			stream = stream.duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.data.size() / 2
			p.volume_db = -8.0
		p.stream = stream
		add_child(p)
		_sfx[id] = p


func sfx(id: String) -> void:
	if _sfx.has(id):
		_sfx[id].play()


func popup(text: String, at: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 72
	l.outline_size = 18
	l.pixel_size = 0.006
	l.modulate = col
	l.position = at
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", at.y + 1.3, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- the day

## Days get longer, busier and less forgiving.
func day_length() -> float:
	return 50.0 + 5.0 * ledger.day


func table_patience() -> float:
	return maxf(24.0, 46.0 - 1.5 * ledger.day)


func day_progress() -> float:
	return clampf(clock / day_length(), 0.0, 1.0) if phase == Phase.SERVICE else 1.0


func start_day() -> void:
	if phase == Phase.CLOSED:
		return
	phase = Phase.SERVICE
	clock = 0.0
	hud.hide_card()
	var coming := town.roll_guests(ledger.day)
	arrivals.clear()
	for i in coming.size():
		var t := 2.0 + (i + town.rng.randf() * 0.6) * (day_length() - 2.0) / coming.size()
		arrivals.append({"time": t, "idx": coming[i]})
	hud.show_banner("Day %d" % ledger.day)
	hud.say("%d guests expected today." % coming.size())
	sfx("day")


func _end_day() -> void:
	phase = Phase.SUMMARY
	last_day = ledger.end_day()
	hud.show_summary(last_day)
	sfx("coin")


func _close_down() -> void:
	phase = Phase.CLOSED
	var days := ledger.day
	var earned := ledger.lifetime_earnings()
	var best := load_best()
	var is_record: bool = days > int(best.days) or (days == int(best.days) and earned > int(best.earned))
	if is_record:
		var f := FileAccess.open(best_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"days": days, "earned": earned}))
	hud.show_closed(days, earned, best, is_record)
	sfx("fail")


func load_best() -> Dictionary:
	var best := {"days": 0, "earned": 0}
	if FileAccess.file_exists(best_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(best_path))
		if data is Dictionary and data.has("days") and data.has("earned"):
			best = data
	return best


func restart() -> void:
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- guests

func spawn_guest(idx: int) -> Guest:
	var g := Guest.new()
	add_child(g)
	g.setup(self, idx, SPAWN)
	guests.append(g)
	queue.append(g)
	_reflow_queue()
	return g


func _reflow_queue() -> void:
	for i in queue.size():
		queue[i].walk_to(Vector2i(mini(DOOR.x + i, W - 1), H))


func _free_seat_for(g: Guest) -> Array:
	var fallback: Array = []
	for st: Station in stations.values():
		for s in st.seats:
			if seat_taken.has(s):
				continue
			if fallback.is_empty():
				fallback = [st, s]
			for other in st.seats:
				if seat_taken.has(other) and town.are_friends(g.idx, seat_taken[other].idx):
					return [st, s]
	return fallback


func _seat_waiting_guests() -> void:
	while not queue.is_empty():
		var g := queue[0]
		var found := _free_seat_for(g)
		if found.is_empty():
			return
		queue.pop_front()
		g.table = found[0]
		g.seat = found[1]
		seat_taken[g.seat] = g
		g.state = "to_seat"
		g.walk_to(g.seat)
		_reflow_queue()


func on_seated(g: Guest) -> void:
	for other in g.table.seats:
		if other != g.seat and seat_taken.has(other):
			var mate: Guest = seat_taken[other]
			if town.are_friends(g.idx, mate.idx):
				g.mood.delight(0.15, "Oh good, %s is here!" % mate.info.name)
				mate.mood.delight(0.15, "Oh good, %s is here!" % g.info.name)


## Everything a seated guest can see changes how they feel.
func apply_surroundings(g: Guest, delta: float) -> void:
	for s in _gross:
		var c: Vector2i = s.cell
		if _near(g.cell, c, SIGHT_RANGE) and grid.has_los(g.cell, c):
			g.mood.see_gross(s.strength, delta, s.thought)
	for st: Station in stations.values():
		if st.type == "plant" and _near(g.cell, st.cell, 2 + st.tier) and grid.has_los(g.cell, st.cell):
			g.mood.delight(0.015 * st.tier * delta, "That fern is rather nice")


static func _near(a: Vector2i, b: Vector2i, r: int) -> bool:
	return absi(a.x - b.x) <= r and absi(a.y - b.y) <= r


func _collect_gross() -> void:
	_gross.clear()
	for st: Station in stations.values():
		if st.type == "table" and st.dirty > 0:
			_gross.append({"cell": st.cell, "strength": 0.03, "thought": "Nobody has cleared that table"})
	if player.carrying_something_gross():
		_gross.append({"cell": player.cell(), "strength": 0.15, "thought": "I just watched the chef carry rubbish past me"})


func _waiting_guest_at(table: Station) -> Guest:
	var best: Guest = null
	for s in table.seats:
		if seat_taken.has(s):
			var g: Guest = seat_taken[s]
			if g.state == "waiting" and (best == null or g.mood.patience < best.mood.patience):
				best = g
	return best


func serve(g: Guest, quality: float) -> void:
	if g.mood.patience > 0.65:
		g.mood.delight(0.15, "That was quick!")
	g.mood.taste(quality)
	g.mood.think("Perfectly juicy" if quality > 0.95 else "A bit dry, this")
	g.state = "eating"
	g.timer = Guest.EAT_TIME
	g.hop()
	sfx("serve")


func finish_meal(g: Guest) -> void:
	var tip := g.mood.tip_for(BILL)
	ledger.record_sale(BILL, tip)
	town.record_visit(g.idx, g.mood.satisfaction())
	g.table.dirty += 1
	g.table.refresh()
	popup("+$%d" % (BILL + tip), g.position + Vector3(0, 1.8, 0), Color("#ffd34e"))
	sfx("coin")
	_leave(g)


func walk_out(g: Guest) -> void:
	g.mood.think("I'm never coming back")
	ledger.record_walkout()
	town.record_visit(g.idx, -0.5)
	hud.say("%s walked out!" % g.info.name)
	popup("walked out", g.position + Vector3(0, 1.8, 0), Color("#ff6b5e"))
	sfx("fail")
	_leave(g)


func _leave(g: Guest) -> void:
	seat_taken.erase(g.seat)
	if queue.has(g):
		queue.erase(g)
		_reflow_queue()
	g.state = "leaving"
	g.walk_to(EXIT)


func remove_guest(g: Guest) -> void:
	guests.erase(g)
	g.queue_free()


# ---------------------------------------------------------------- cooking & carrying

## What using this station would do right now, e.g. "Cook". Empty when nothing.
func prompt_for(st: Station) -> String:
	return use_station(st, true)


## The player uses the station they are facing. Returns the name of the action taken.
## With dry_run, nothing changes and only the name is returned.
func use_station(st: Station, dry_run := false) -> String:
	var held := player.held
	var q := player.held_quality
	var act := ""
	match st.type:
		"fridge":
			if held == "":
				act = "Take meat"
				if not dry_run:
					player.set_held("raw_patty")
		"stove", "counter", "pass":
			if held == "plate" and st.item == "cooked_patty":
				act = "Plate it"
				if not dry_run:
					player.set_held("burger", st.current_quality())
					st.set_item("")
			elif held == "cooked_patty" and st.item == "plate":
				act = "Plate it"
				if not dry_run:
					st.set_item("burger", q)
					player.set_held("")
			elif held != "" and st.item == "" and (st.type != "stove" or held.ends_with("patty")):
				act = "Cook" if st.type == "stove" else "Put down"
				if not dry_run:
					st.set_item(held, q)
					player.set_held("")
			elif held == "" and st.item != "":
				act = "Take off the heat" if st.type == "stove" else "Pick up"
				if not dry_run:
					player.set_held(st.item, st.current_quality())
					st.set_item("")
		"plates":
			if held == "" and st.count > 0:
				act = "Take plate"
				if not dry_run:
					st.count -= 1
					player.set_held("plate")
			elif held == "plate":
				act = "Put back"
				if not dry_run:
					st.count += 1
					player.set_held("")
			elif held == "cooked_patty" and st.count > 0:
				act = "Plate it"
				if not dry_run:
					st.count -= 1
					player.set_held("burger", q)
			if not dry_run:
				st.refresh()
		"sink":
			if held == "dirty_plate":
				act = "Wash"
				if not dry_run:
					player.set_held("")
					var stack := find_station("plates")
					stack.count += 1
					stack.refresh()
		"bin":
			if held == "burger":
				act = "Scrape off"
				if not dry_run:
					player.set_held("plate")
			elif held.ends_with("patty"):
				act = "Throw away"
				if not dry_run:
					player.set_held("")
		"table":
			var g := _waiting_guest_at(st)
			if held == "burger" and g != null:
				act = "Serve %s" % g.info.name
				if not dry_run:
					player.set_held("")
					serve(g, q)
			elif held == "" and st.dirty > 0:
				act = "Clear plate"
				if not dry_run:
					st.dirty -= 1
					st.refresh()
					player.set_held("dirty_plate")
	if act != "" and not dry_run:
		if act == "Wash":
			sfx("wash")
		elif not act.begins_with("Serve"):
			sfx("pickup" if player.held != "" else "putdown")
	return act


func _tick_stoves(delta: float) -> void:
	var sizzling := false
	for st: Station in stations.values():
		var stage := st.tick_cooking(delta)
		if stage == "cooked_patty":
			sfx("ding")
			popup("ready!", st.position + Vector3(0, 2.0, 0), Color("#5fd38d"))
		elif stage == "burnt_patty":
			sfx("burn")
			popup("burnt!", st.position + Vector3(0, 2.0, 0), Color("#ff6b5e"))
		sizzling = sizzling or st.is_cooking()
	if _sfx.has("sizzle") and _sfx.sizzle.playing != sizzling:
		_sfx.sizzle.playing = sizzling


func step(delta: float) -> void:
	if phase != Phase.SERVICE:
		return
	clock += delta
	while not arrivals.is_empty() and float(arrivals[0].time) <= clock:
		spawn_guest(arrivals.pop_front().idx)
	_tick_stoves(delta)
	_collect_gross()
	_seat_waiting_guests()
	for g in guests.duplicate():
		g.tick(delta)
	if ledger.is_closed_down():
		_close_down()
	elif arrivals.is_empty() and guests.is_empty():
		_end_day()


# ---------------------------------------------------------------- input & frame

func _process(delta: float) -> void:
	var input := Vector2.ZERO
	if phase == Phase.SERVICE:
		input = Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
			- float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)))
	player.move(input, delta)
	step(delta)
	_update_cursor()
	hud.update_status()
	if _shot_path != "":
		_shot_time += delta
		if _shot_time > float(OS.get_environment("REGULARS_SHOT_AT")):
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


func _update_cursor() -> void:
	var st: Station = stations.get(player.target_cell())
	var action := prompt_for(st) if st != null and phase == Phase.SERVICE else ""
	_cursor.visible = action != ""
	_prompt.visible = action != ""
	if st != null:
		var top := 1.75 if st.type == "fridge" else 0.9
		_cursor.position = st.position + Vector3(0, top, 0)
		_prompt.position = st.position + Vector3(0, 2.45 if st.type == "stove" else top + 0.75, 0)
		_prompt.text = "[E] " + action


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode
	var confirm := key == KEY_ENTER or key == KEY_KP_ENTER
	if phase == Phase.SERVICE and (key == KEY_E or key == KEY_SPACE):
		if stations.has(player.target_cell()):
			use_station(stations[player.target_cell()])
	elif phase == Phase.SUMMARY and confirm:
		start_day()
	elif phase == Phase.CLOSED and confirm:
		restart()
