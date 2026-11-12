extends Node3D
## Regulars vertical slice: an endless run of days. Cook meat, serve guests, get paid.

enum Phase { SERVICE, SUMMARY, CLOSED, BUILD }

const W := 10            # restaurant interior is 10 x 7 cells
const H := 7             # rows 7 and 8 are the pavement outside
const DOOR := Vector2i(5, 7)
const SPAWN := Vector2i(9, 8)
const EXIT := Vector2i(0, 8)
const BILL := 12
const SIGHT_RANGE := 7
const AREA := Rect2i(0, 0, W, H)   # where the player may build
const DISCOUNT_BELOW := 0.5   # half price can be offered once a guest is this impatient
const SOUNDS := {  # name -> volume in dB
	"pickup": -5.0, "putdown": -5.0, "ding": -3.0, "serve": -3.0, "coin": -4.0, "fail": -3.0, "burn": -4.0,
	"day": -4.0, "wash": -6.0, "step": -16.0, "bell": -9.0, "perfect": -4.0, "sizzle": -10.0, "music": -15.0,
}
const LOOPING: Array[String] = ["sizzle", "music"]
# The camera sits wide to show the whole diorama between days, and moves in on
# the room and the queue while guests are being served.
const CAM_OFFSET := Vector3(14, 15, 14)
const WIDE_SIZE := 14.5
const WIDE_FOCUS := Vector3(W / 2.0 + 0.2, 0, H / 2.0 + 1.7)
const CLOSE_SIZE := 11.5
const CLOSE_FOCUS := Vector3(W / 2.0 - 0.6, 0, H / 2.0)

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
var catalog: Catalog
var crate: Array[Dictionary] = []      # tonight's two blueprints; empty once one is taken
var inventory: Array[Dictionary] = []  # blueprints owned but not yet placed
var hand := {}                         # what is being placed: {id, tier, price, owned}
var _ghost: Node3D
var _ghost_key := ""
var _no_mark: Node3D
var _demo_hover := Vector3.INF
var flyers_out := false          # bought tonight, spent on tomorrow's crowd
var best_path := "user://regulars_best.json"
var player: Player
var hud: Hud
var cam: Camera3D
var _cursor: Node3D
var _gross: Array[Dictionary] = []
var _sfx := {}
var _sun: DirectionalLight3D
var _sconces: Array[OmniLight3D] = []
var _env: Environment
var _shot_path := ""
var _shot_time := 0.0


func _ready() -> void:
	var seed_value := int(Time.get_unix_time_from_system())
	grid = Grid.new(W, H + 2)
	town = Town.new(seed_value)
	ledger = Ledger.new()
	catalog = Catalog.new(seed_value)
	_build_scenery()
	_build_layout()
	_load_sounds()
	player = Player.new()
	add_child(player)
	player.setup(self, Vector2i(2, 3))
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	# A warm frame around the top of the station the chef is facing.
	_cursor = Node3D.new()
	add_child(_cursor)
	for i in 4:
		var bar := Build.box(_cursor, Vector3(0, 0, 0.5).rotated(Vector3.UP, i * PI / 2), Vector3(1.06, 0.05, 0.07), Build.WARN, 0.8)
		bar.rotation.y = i * PI / 2
	# Build phase: a coral cross on the floor where the piece in hand cannot go.
	_no_mark = Node3D.new()
	_no_mark.visible = false
	add_child(_no_mark)
	for turn: float in [PI / 4, -PI / 4]:
		var arm := Build.box(_no_mark, Vector3(0, 0.02, 0), Vector3(1.2, 0.05, 0.2), Build.DANGER, 0.6)
		arm.rotation.y = turn
		var m: StandardMaterial3D = arm.get_active_material(0).duplicate()
		m.no_depth_test = true          # shows through whatever is already standing there
		m.render_priority = 5
		arm.material_override = m
	_shot_path = OS.get_environment("REGULARS_SHOT")
	start_day()
	_apply_demo(OS.get_environment("REGULARS_DEMO"))


## Dev aid for screenshots: REGULARS_DEMO=cook or =summary jumps to that moment.
func _apply_demo(demo: String) -> void:
	if demo == "cook":
		find_station("stove").set_item("raw_patty")
		find_station("stove").cook = -8.2
		stations[Vector2i(2, 0)].set_item("raw_patty")
		player.position = Grid.center(Vector2i(1, 1))
		player.look(Vector2i(0, -1))
		player.set_held("plate")
		for a in arrivals:
			a.time = 1.0
	elif demo == "lineup":  # every townsperson and every face, close up
		arrivals.clear()
		phase = Phase.SUMMARY
		cam.size = 6.5
		cam.position += Vector3(-1.5, 0, 3.4)
		var names: Array = Peg.LOOKS.keys()
		for i in names.size():
			var p := Peg.guest(names[i])
			p.position = Vector3(1.0 + (i % 7) * 1.0 + (i / 7) * 0.5, 0, 7.6 + (i / 7) * 1.1 - (i % 7) * 0.25)
			p.rotation.y = PI / 4
			p.pose = ["idle", "carry", "tap", "wave"][i % 4]
			add_child(p)
		for i in Peg.FACES.size():
			var p := Peg.guest(names[i + 3])
			p.set_face(Peg.FACES[i])
			p.position = Vector3(1.6 + i * 0.95, 0, 10.2 - i * 0.3)
			p.rotation.y = PI / 4
			add_child(p)
		for i in 4:
			var c := Peg.chef(i)
			c.position = Vector3(6.2 + i, 0, 12.2 - i * 0.6)
			c.rotation.y = PI / 4 + i * PI / 2
			add_child(c)
	elif demo == "fx":  # fires every effect in turn; shoot at about 6.5 and 8.4
		for a in arrivals:
			a.time = 0.2
		while arrivals.size() < 8:
			arrivals.append({"time": 0.2, "idx": arrivals.size()})
		get_tree().create_timer(6.0).timeout.connect(_demo_fx)
	elif demo == "kind":  # an impatient guest and the half-price prompt; shoot at about 9 and 10.5
		for a in arrivals:
			a.time = 0.2
		get_tree().create_timer(8.0).timeout.connect(_demo_kind.bind(false))
		get_tree().create_timer(9.5).timeout.connect(_demo_kind.bind(true))
	elif demo == "closed":
		best_path = "user://regulars_best_demo.json"
		for i in Ledger.MAX_STRIKES:
			ledger.record_walkout()
	elif demo == "summary" or demo == "town":
		ledger.record_sale(BILL, 5)
		ledger.record_sale(BILL, 3)
		arrivals.clear()
		if demo == "town":  # a spread of opinions, then the town book over the receipt
			for i in town.people.size():
				town.record_visit(i, [0.9, 0.9, 0.3, -0.5, 0.6][i % 5])
				if i % 2 == 0:
					town.record_visit(i, [0.9, -0.5, 0.9][i % 3])
			get_tree().create_timer(1.5).timeout.connect(hud.show_town)
	elif demo == "build" or demo == "build_no":  # a furnished room and a piece in hand
		ledger.record_sale(BILL, 5)
		ledger.money = 300
		ledger.xp = 250
		arrivals.clear()
		get_tree().create_timer(1.0).timeout.connect(_demo_build.bind(demo == "build_no"))
	elif demo == "flyers":
		ledger.record_sale(BILL, 5)
		arrivals.clear()
		get_tree().create_timer(1.5).timeout.connect(buy_flyers)


func _demo_build(refused: bool) -> void:
	open_build()
	take_crate(0)
	cancel_hand()
	for step: Array in [["counter", 2, 4, 0], ["screen", 8, 5, 0], ["screen", 9, 5, 0], ["table", 8, 6, 0], ["plant", 9, 2, 0]]:
		pick_catalog(step[0])
		place(Vector3i(step[1], step[2], step[3]))
	pick_catalog("stove")
	_demo_hover = Vector3(6.5, 0, 5.5) if refused else Vector3(3.5, 0, 5.5)


func _demo_kind(offer: bool) -> void:
	for g in guests:
		if g.state == "waiting":
			if offer:
				use_station(g.table)
				return
			g.mood.patience = 0.3
			player.position = Grid.center(g.table.cell + Vector2i(0, 1))
			player.look(Vector2i(0, -1))
			return


func _demo_fx() -> void:
	var seated: Array[Guest] = []
	for g in guests:
		if g.state == "waiting":
			seated.append(g)
		elif g.state == "queue":
			g.mood.patience = 0.5                 # Zzz bubble
	if seated.size() > 0:
		serve(seated[0], 1.0)                     # stars, heart, chewing, bitten burger
		seated[0].timer = 2.0                     # then the coin and a dirty plate
	if seated.size() > 1:
		seated[1].mood.patience = 0.0             # walkout: anger mark and a stamp
	if seated.size() > 2:
		seated[2]._gross_time = 6.0               # green cloud
	find_station("fridge").used()                 # door swings open
	burst(find_station("sink").position + Vector3(0, 1.15, 0), "bubbles", 0.4)


# ---------------------------------------------------------------- world

func _build_scenery() -> void:
	if OS.get_environment("REGULARS_THEME") != "":  # dev switch until themes are selectable in game
		Scenery.theme_id = OS.get_environment("REGULARS_THEME")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(Scenery.t().backdrop)
	# Shadows are never black: the ambient fill carries the warm plum of #5a423a.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#f4dcd2")
	env.ambient_light_energy = 0.62
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.3
	env.ssao_power = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.03
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.02
	_env = env
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.8
	sun.shadow_blur = 2.5
	sun.light_angular_distance = 5.0  # wide, soft penumbra
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	_sun = sun
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = WIDE_SIZE
	add_child(cam)
	cam.look_at_from_position(WIDE_FOCUS + CAM_OFFSET, WIDE_FOCUS)

	_sconces = Scenery.build(self, W, H, DOOR)


## The glow of the mushroom lamp on each table. (No hanging lamps: from this
## camera a shade would sit in front of the guests behind it.)
func _add_lamp(over: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = over + Vector3(0, 1.0, 0)
	light.light_color = Color("#ffd9a0")
	light.light_energy = 0.45
	light.omni_range = 2.6
	add_child(light)
	_sconces.append(light)


func _build_layout() -> void:
	for spot: Array in [
		["fridge", 0, 0], ["stove", 1, 0], ["stove", 2, 0], ["counter", 3, 0],
		["plates", 0, 2, 1], ["sink", 0, 3, 1], ["bin", 0, 5, 1],
		["pass", 4, 0], ["pass", 4, 1], ["pass", 4, 2], ["pass", 4, 3], ["pass", 4, 4],
		["table", 6, 1], ["table", 8, 3], ["table", 6, 5], ["plant", 9, 0],
	]:
		add_station(spot[0], Vector2i(spot[1], spot[2]), 1, spot[3] if spot.size() > 3 else 0)
	# The front wall (drawn by Scenery as a knee-high cutaway) has a doorway;
	# guests cannot see or walk through the rest.
	for x in W:
		if x != DOOR.x:
			grid.walls[Vector3i(x, H, 0)] = true


func add_station(type: String, cell: Vector2i, tier := 1, facing := 0) -> Station:
	var st := Station.new()
	add_child(st)
	st.setup(type, cell, tier, facing)
	stations[cell] = st
	if type == "table":
		_add_lamp(st.position)
	grid.blocked[cell] = true
	for s in st.seats:
		grid.reserved[s] = true
	return st


## A low partition (sheet 11): teal panelled base, tan cap, thin coral line.
func add_wall(cell: Vector2i, axis: int, height := 1.0) -> void:
	grid.walls[Vector3i(cell.x, cell.y, axis)] = true
	var n := Node3D.new()
	_place_on_edge(n, Vector3i(cell.x, cell.y, axis))
	add_child(n)
	_wall_visual(n, height)


static func _place_on_edge(n: Node3D, edge: Vector3i) -> void:
	n.position = Vector3(edge.x + 0.5, 0, edge.y) if edge.z == 0 else Vector3(edge.x, 0, edge.y + 0.5)
	n.rotation.y = 0.0 if edge.z == 0 else PI / 2


static func _wall_visual(n: Node3D, height: float) -> void:
	Build.box(n, Vector3.ZERO, Vector3(1.0, height - 0.12, 0.24), Build.CABINET)
	Build.box(n, Vector3(0, height - 0.14, 0), Vector3(1.0, 0.04, 0.26), Build.CORAL)
	Build.box(n, Vector3(0, height - 0.1, 0), Vector3(1.04, 0.1, 0.3), Build.WORKTOP, 0.0, Build.R_WOOD)


func find_station(type: String) -> Station:
	for st: Station in stations.values():
		if st.type == type:
			return st
	return null


# ---------------------------------------------------------------- sound & feedback

func _load_sounds() -> void:
	for id: String in SOUNDS:
		var path := "res://assets/sfx/%s.wav" % id
		if not ResourceLoader.exists(path):
			continue
		var p := AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load(path)
		if LOOPING.has(id):
			stream = stream.duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.data.size() / 2
		else:
			p.max_polyphony = 4
		p.volume_db = SOUNDS[id]
		p.stream = stream
		add_child(p)
		_sfx[id] = p
	if _sfx.has("music"):
		_sfx.music.play()


## Plays a sound with a little random pitch so repeats do not sound identical.
func sfx(id: String, vary := 0.06) -> void:
	if _sfx.has(id):
		_sfx[id].pitch_scale = randf_range(1.0 - vary, 1.0 + vary)
		_sfx[id].play()


## A four-frame cut-out effect in the world: stars, bubbles, wisps, anger...
func burst(at: Vector3, id: String, size := 0.45) -> void:
	Fx.play(self, id, at, size).drift = Vector3(0, 0.5, 0)


func shake(amount := 0.12) -> void:
	var tw := cam.create_tween()
	for i in 5:
		tw.tween_property(cam, "h_offset", randf_range(-amount, amount), 0.04)
	tw.tween_property(cam, "h_offset", 0.0, 0.05)


## Morning light drifts to a warm, low evening sun as the day goes on.
func _update_daylight() -> void:
	var t := smoothstep(0.35, 1.0, day_progress())
	_sun.light_color = Color("#fff6ea").lerp(Color("#ffd6ac"), t)
	_sun.rotation_degrees = Vector3(lerpf(-52, -34, t), lerpf(-30, -62, t), 0)
	_env.background_color = Color(Scenery.t().backdrop).lerp(Color("#d9c9cc"), t)
	_env.ambient_light_color = Color("#f4dcd2").lerp(Color("#ead6d6"), t)
	_sun.light_energy = lerpf(0.62, 0.5, t)
	for l in _sconces:  # practical lights come up as the sun goes down
		l.light_energy = float(l.get_meta("full", 0.45)) * lerpf(0.35, 1.0, t)


func popup(text: String, at: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64
	l.outline_size = 20
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_modulate = Color(Build.PAPER)
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
	hand = {}
	hud.hide_card()
	hud.hide_build()
	town.new_day()
	var coming := town.roll_guests(ledger.day, Town.FLYER_BOOST if flyers_out else 0.0)
	var flyered := flyers_out
	flyers_out = false
	arrivals.clear()
	for i in coming.size():
		var t := 2.0 + (i + town.rng.randf() * 0.6) * (day_length() - 2.0) / coming.size()
		arrivals.append({"time": t, "idx": coming[i]})
	hud.show_banner("Day %d" % ledger.day)
	hud.say(("%d guests expected today." % coming.size()) + (" The flyers worked." if flyered else ""))
	sfx("day")


# ---------------------------------------------------------------- building

## After the receipt: the room is yours to change until you open for the day.
func open_build() -> void:
	if phase != Phase.SUMMARY:
		return
	phase = Phase.BUILD
	hud.hide_card()
	hud.show_build()


## Takes one of tonight's two blueprints. The other is gone.
func take_crate(i: int) -> void:
	if phase != Phase.BUILD or i >= crate.size():
		return
	inventory.append(crate[i])
	crate.clear()
	pick_owned(inventory.size() - 1)


func pick_owned(i: int) -> void:
	if phase == Phase.BUILD and i < inventory.size():
		hand = {"id": inventory[i].id, "tier": inventory[i].tier, "price": 0, "owned": i}
		hud.show_build()


func pick_catalog(id: String) -> bool:
	if phase != Phase.BUILD or not catalog.can_buy(id, ledger.money, ledger.level()):
		return false
	hand = {"id": id, "tier": 1, "price": int(Catalog.ITEMS[id].price), "owned": -1}
	hud.show_build()
	return true


## Puts an owned blueprint away to come back a tier higher.
func shelve_owned(i: int) -> bool:
	if phase != Phase.BUILD or i >= inventory.size() or not catalog.can_shelve(inventory[i]):
		return false
	catalog.shelve(inventory[i], ledger.day)
	inventory.remove_at(i)
	hand = {}
	sfx("putdown")
	hud.show_build()
	return true


func cancel_hand() -> void:
	hand = {}
	if phase == Phase.BUILD:
		hud.show_build()


## Where the piece in hand would go for a point on the floor: (x, y, axis).
## Furniture snaps to the cell (axis 0); a partition snaps to the nearest cell edge.
func snap(p: Vector3) -> Vector3i:
	var c := Grid.to_cell(p)
	if hand.get("id", "") != "screen":
		return Vector3i(c.x, c.y, 0)
	var fx := p.x - c.x
	var fz := p.z - c.y
	if minf(fz, 1.0 - fz) < minf(fx, 1.0 - fx):
		return Vector3i(c.x, c.y + (1 if fz > 0.5 else 0), 0)
	return Vector3i(c.x + (1 if fx > 0.5 else 0), c.y, 1)


func _seats_for(id: String, cell: Vector2i) -> Array[Vector2i]:
	var seats: Array[Vector2i] = []
	if id == "table":
		seats = [cell + Vector2i(-1, 0), cell + Vector2i(1, 0)]
	return seats


## Would the piece in hand fit at this spot without cutting anyone off?
func can_place(spot: Vector3i) -> bool:
	if hand.is_empty():
		return false
	var reach: Array[Vector2i] = [player.cell()]
	reach.assign(reach + grid.reserved.keys())
	var touch: Array[Vector2i] = []
	touch.assign(stations.keys())
	if hand.id == "screen":
		return grid.can_place_wall(spot, AREA, DOOR, reach, touch)
	var cell := Vector2i(spot.x, spot.y)
	return grid.can_place_block(cell, _seats_for(hand.id, cell), AREA, DOOR, reach, touch)


## Builds the piece in hand. Catalog pieces are paid for here, so cancelling is free.
func place(spot: Vector3i) -> bool:
	if phase != Phase.BUILD or not can_place(spot):
		return false
	if int(hand.price) > 0 and not ledger.spend(int(hand.price)):
		return false
	var cell := Vector2i(spot.x, spot.y)
	if hand.id == "screen":
		add_wall(cell, spot.z, 0.9 + 0.1 * int(hand.tier))
	else:
		add_station(hand.id, cell, int(hand.tier))
	burst(Grid.center(cell) + Vector3(0, 1.0, 0), "stars", 0.4)
	sfx("putdown")
	if int(hand.owned) >= 0:
		inventory.remove_at(int(hand.owned))
		hand = {}
	elif not catalog.can_buy(hand.id, ledger.money, ledger.level()):
		hand = {}
	hud.show_build()
	return true


func _hover_point() -> Vector3:
	if _demo_hover != Vector3.INF:
		return _demo_hover
	var m := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(m)
	var d := cam.project_ray_normal(m)
	return o - d * (o.y / d.y) if absf(d.y) > 0.001 else Vector3.INF


## The piece in hand follows the mouse; a cross marks spots where it cannot go.
func _update_ghost() -> void:
	var key := "%s:%s" % [hand.get("id", ""), hand.get("tier", 0)] if phase == Phase.BUILD and not hand.is_empty() else ""
	if key != _ghost_key:
		_ghost_key = key
		if _ghost:
			_ghost.queue_free()
			_ghost = null
		if key != "":
			_ghost = Node3D.new()
			add_child(_ghost)
			if hand.id == "screen":
				_wall_visual(_ghost, 0.9 + 0.1 * int(hand.tier))
			else:
				Build.station(_ghost, hand.id, int(hand.tier))
	var p := _hover_point()
	if _ghost == null or p == Vector3.INF:
		_no_mark.visible = false
		if _ghost:
			_ghost.visible = false
		return
	var spot := snap(p)
	var ok := can_place(spot)
	if hand.id == "screen":
		_place_on_edge(_ghost, spot)
	else:
		_ghost.position = Grid.center(Vector2i(spot.x, spot.y))
	_ghost.position.y = 0.12 + 0.04 * sin(Time.get_ticks_msec() / 160.0)   # held just off the floor
	_ghost.visible = ok
	_no_mark.visible = not ok
	_no_mark.position = Vector3(_ghost.position.x, 0, _ghost.position.z)


## Flyers: pay tonight for a bigger crowd tomorrow. One batch a night.
func buy_flyers() -> bool:
	if phase != Phase.SUMMARY or flyers_out or not ledger.spend(Town.FLYER_PRICE):
		return false
	flyers_out = true
	sfx("coin")
	hud.show_summary(last_day, false)
	return true


func _end_day() -> void:
	phase = Phase.SUMMARY
	last_day = ledger.end_day()
	crate = catalog.offer()
	inventory.append_array(catalog.collect_ready(ledger.day))
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
		sfx("bell")
		_reflow_queue()


func on_seated(g: Guest) -> void:
	if g.table.tier > 1:
		g.mood.delight(0.05 * (g.table.tier - 1), "What a lovely table")
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
	var perfect := quality > 0.95
	g.mood.think("Perfectly juicy" if perfect else "A bit dry, this")
	g.start_eating(quality)
	sfx("serve")
	if perfect:
		sfx("perfect")
		burst(g.position + Vector3(0, 1.3, 0), "stars")


## Kindness: half price to say sorry for the wait. The town remembers it.
func offer_discount(g: Guest) -> void:
	if not g.mood.offer_discount():
		return
	town.record_kindness(g.idx)
	hud.say("Half price for %s. Word gets around." % g.info.name)
	burst(g.position + Vector3(0, 1.5, 0), "stars", 0.3)
	g._heart_time = 1.5
	sfx("coin")


func finish_meal(g: Guest) -> void:
	var bill := g.mood.bill_for(BILL)
	var tip := g.mood.tip_for(bill)
	ledger.record_sale(bill, tip)
	var talk := town.gossip_line(g.idx, town.record_visit(g.idx, g.mood.satisfaction()))
	if talk != "":
		hud.say(talk)
	g.table.dirty += 1
	g.table.refresh()
	popup("+$%d" % (bill + tip), g.position + Vector3(0, 1.9, 0), Color(Build.TRIM))
	Fx.coin(self, g.position + Vector3(0, 1.5, 0))
	if g.mood.satisfaction() > 0.5:
		g._heart_time = 2.5
	sfx("coin")
	_leave(g)


func walk_out(g: Guest) -> void:
	g.mood.think("I'm never coming back")
	g.stormed = true
	ledger.record_walkout()
	var talk := town.gossip_line(g.idx, town.record_visit(g.idx, -0.5))
	hud.say(("%s walked out! " % g.info.name) + talk)
	var mark := Fx.play(g, "anger", Vector3(0, 1.75, 0), 0.3, true)
	mark.fps = 6.0
	sfx("fail")
	shake()
	_leave(g)


func _leave(g: Guest) -> void:
	seat_taken.erase(g.seat)
	if queue.has(g):
		queue.erase(g)
		_reflow_queue()
	g.stand_up()
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
			elif held == "" and g != null and not g.mood.discounted and g.mood.patience < DISCOUNT_BELOW:
				act = "Half price for %s" % g.info.name
				if not dry_run:
					offer_discount(g)
	if act != "" and not dry_run:
		player.punch()
		st.used()
		if act == "Wash":
			sfx("wash")
			burst(st.position + Vector3(0, 1.15, 0), "bubbles", 0.4)
		elif not (act.begins_with("Serve") or act.begins_with("Half")):
			sfx("pickup" if player.held != "" else "putdown")
	return act


func _tick_stoves(delta: float) -> void:
	var sizzling := false
	for st: Station in stations.values():
		var stage := st.tick_cooking(delta)
		if stage == "cooked_patty":
			sfx("ding")
			burst(st.position + Vector3(0, 1.2, 0), "stars", 0.4)
		elif stage == "burnt_patty":
			sfx("burn")
			shake(0.08)
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
	_update_camera(delta)
	_update_cursor()
	_update_ghost()
	_update_daylight()
	hud.update_status()
	if _shot_path != "":
		_shot_time += delta
		if _shot_time > float(OS.get_environment("REGULARS_SHOT_AT")):
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


func _update_camera(delta: float) -> void:
	var close := phase == Phase.SERVICE
	var k := 1.0 - exp(-2.5 * delta)
	cam.size = lerpf(cam.size, CLOSE_SIZE if close else WIDE_SIZE, k)
	cam.position = cam.position.lerp((CLOSE_FOCUS if close else WIDE_FOCUS) + CAM_OFFSET, k)


func _update_cursor() -> void:
	var st: Station = stations.get(player.target_cell())
	var action := prompt_for(st) if st != null and phase == Phase.SERVICE else ""
	_cursor.visible = action != ""
	var at := Vector2.ZERO
	if st != null:
		var top := 1.72 if st.type == "fridge" else 0.9
		_cursor.position = st.position + Vector3(0, top, 0)
		at = cam.unproject_position(st.position + Vector3(0, 2.25 if st.type == "stove" else top + 0.7, 0))
	hud.show_prompt(at, action)


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.BUILD and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not hand.is_empty() and _hover_point() != Vector3.INF:
			if not place(snap(_hover_point())):
				sfx("fail")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_hand()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode
	var confirm := key == KEY_ENTER or key == KEY_KP_ENTER
	if key == KEY_M:
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
		return
	if phase == Phase.SERVICE and (key == KEY_E or key == KEY_SPACE):
		if stations.has(player.target_cell()):
			use_station(stations[player.target_cell()])
	elif phase == Phase.SUMMARY and confirm:
		open_build()
	elif phase == Phase.BUILD and confirm:
		start_day()
	elif phase == Phase.BUILD and key == KEY_ESCAPE:
		cancel_hand()
	elif phase == Phase.SUMMARY and key == KEY_F:
		buy_flyers()
	elif phase == Phase.SUMMARY and key == KEY_T:
		hud.toggle_town()
	elif phase == Phase.CLOSED and confirm:
		restart()
