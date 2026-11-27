class_name GameWorld
extends RefCounted
## The room in the world: scenery and lamps, the floorplan drawn, stations added and
## registered with the kitchen, counters and what stands on them, walls, and the wall
## layer's high pieces (PRD 8.5).

var game: Game
var flood_runs := 0   # how often the door flood ran, for the perf test
var _flood_key := 0   # what the last flood saw


func _init(game_: Game) -> void:
	game = game_


# ---------------------------------------------------------------- world

func _build_scenery() -> void:
	if GameSession.theme_forced():  # a developer's switch: skips the theme card (see choose_theme)
		Scenery.theme_id = OS.get_environment("REGULARS_THEME")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(Scenery.t().backdrop)
	# Shadows are never black: the ambient fill carries the warm plum of #5a423a.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ece0dc")
	env.ambient_light_energy = 0.62  # a high, tinted fill: shadows are soft and never dark
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.tonemap_white = 1.7
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.4
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.15
	env.glow_bloom = 0.03
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	game._env = env
	game.get_viewport().msaa_3d = Viewport.MSAA_4X
	# Grain-free soft shadows and contact shading: the default filters dither.
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, false, 0.5, 3, 50, 300)
	var we := WorldEnvironment.new()
	we.environment = env
	game.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = Game.SUN_ENERGY.x
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.6
	sun.shadow_blur = 2.2  # an even, soft edge; a wide sun disc dithers instead
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 48.0  # just past the far corner of the paper
	sun.directional_shadow_fade_start = 1.0
	# Small biases keep each shadow attached to the foot of what casts it. The
	# defaults (0.1 and 2.0) slide shadows sideways and open a gap under walls.
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.4
	game._sun = sun
	game.add_child(sun)
	game.cam = Camera3D.new()
	game.cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.cam.size = Game.WIDE_SIZE
	# Tight clip planes: with the default 0.05 to 4000 an orthographic camera gets
	# no directional shadows at all.
	game.cam.near = 1.0
	game.cam.far = 80.0
	# Tilt-shift is a screen-space blur drawn over the world and under the interface.
	var lens_layer := CanvasLayer.new()
	lens_layer.layer = -1
	game.add_child(lens_layer)
	game._lens = ColorRect.new()
	game._lens.set_anchors_preset(Control.PRESET_FULL_RECT)
	game._lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lens_mat := ShaderMaterial.new()
	lens_mat.shader = load("res://game/shaders/tilt_shift.gdshader")
	game._lens.material = lens_mat
	lens_layer.add_child(game._lens)
	game.add_child(game.cam)
	game.cam.look_at_from_position(Game.WIDE_FOCUS + Game.CAM_OFFSET, Game.WIDE_FOCUS)

	game._sconces = Scenery.build_ground(game, Game.W, Game.H)
	game.audio.set_tilt_shift(Game.TILT_SHIFT)


## The glow of the mushroom lamp on each table. (No hanging lamps: from this
## camera a shade would sit in front of the guests behind it.)
func _add_lamp(over: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = over + Vector3(0, 1.0, 0)
	light.light_color = Color("#ffd9a0")
	light.light_energy = 0.8
	light.set_meta("full", 0.8)
	light.omni_range = 2.8
	game.add_child(light)
	game._sconces.append(light)
	return light


## The theme's potted plant: the diner's fern or the seaside's palm.
static func fern() -> String:
	return "palm" if Scenery.seaside() else "plant"


static func fixed_main() -> Dictionary:
	return Game.FIXED_MAIN.get(Scenery.theme_id, Game.FIXED_MAIN.diner)


func _build_layout() -> void:
	for spot: Array in [
		# The cooking line runs down the left wall under the hood, as in sheet 1.
		# The cell in front of the back doorway stays clear, so the patties can be reached.
		# The kitchen starts empty but for the sink, the bin, the dish rack and the
		# counters: the player buys the first stations and writes the menu on night zero.
		["dish_rack", 2, 2], ["sink", 3, 2], ["bin", 0, 5, 1],
		["table", 6, 1], ["chair", 5, 1, 2], ["chair", 7, 1, 0],
		["table", 8, 3], ["chair", 7, 3, 2], ["chair", 9, 3, 0],
		["table", 6, 5], ["chair", 5, 5, 2], ["chair", 7, 5, 0], [fern(), 9, 0],
	]:
		add_station(spot[0], Vector2i(spot[1], spot[2]), 1, spot[3] if spot.size() > 3 else 0)
	# The pass: four real counters drawn as the frame's long teal run, each sellable,
	# each able to take a tool (PRD 8).
	for z in range(2, 6):
		add_station("counter", Vector2i(4, z), 1, 0, "counter", true)
	BuildStations.register(game.stations[Vector2i(4, 2)])  # the till: its own piece, standing on the pass
	game.placing.add_rug(Vector2i(8, 3))   # under the middle table, as in sheet 1


## The first room's wall pieces (PRD 8.5), real and sellable like the rest: the hood
## over where the cooking line goes, the wall cabinets by the back door, and the jar
## shelf over the sink.
func _hang_fixtures() -> void:
	for spot: Array in [["hood", 0, 3], ["hood", 0, 4], ["cabinet", 0, 5], ["cabinet", 0, 6], ["shelf", 3, 2]]:
		var cell := Vector2i(spot[1], spot[2])
		if game.kitchen.can_hang(cell, spot[0]):
			add_high(spot[0], cell)


## The first room is an L (sheet 1): a tiled kitchen on the left, set forward of
## the planked dining room, with the front door in the right-hand wall.
func _start_plan() -> void:
	game.plan = Floorplan.new(game.lot)
	game.plan.fill(Rect2i(0, Scenery.KITCHEN_Z, Scenery.KITCHEN_W, Game.H - Scenery.KITCHEN_Z), "tile")
	game.plan.fill(Rect2i(Scenery.KITCHEN_W, 0, Game.W - Scenery.KITCHEN_W, Game.H), "planks")
	game.plan.openings[Vector3i(Game.DOOR.x, Game.DOOR.y, 1)] = "entrance"
	_sync_grid()
	_rebuild_room()


## Copies the plan's walls, doors and bare ground into the grid, with the partitions.
func _sync_grid() -> void:
	game.grid.walls.clear()
	for e in game.plan.solid_walls():
		game.grid.walls[e] = true
	for e: Vector3i in game.wall_nodes:
		game.grid.walls[e] = true
	game.grid.doors.clear()
	for e in game.plan.doors():
		game.grid.doors[e] = true
	game.grid.outside.clear()
	game.grid.roam.clear()
	var pave := game.pavement()
	var from: Vector2i = game.grid.origin
	for x in range(from.x, from.x + game.grid.size.x):   # the grid spans the largest lot the cap allows
		for y in range(from.y, from.y + game.grid.size.y):
			var c := Vector2i(x, y)
			if game.lot.has_point(c):
				if not game.plan.has_floor(c):
					game.grid.outside[c] = true   # bare ground
					game.grid.roam[c] = true
			elif not pave.has_point(c):
				game.grid.outside[c] = true   # not ours yet, or the kerb and the road
				game.grid.roam[c] = true   # chefs walk it at night; the kerb stays shut (pavement_from)
	game.grid.outside[Game.BOARD_CELL] = true   # the menu board stands here; people go round it
	game.grid.roam.erase(Game.BOARD_CELL)


## Redraws the room from the plan and fits the camera round it.
func _rebuild_room() -> void:
	if game._room:
		game.remove_child(game._room)
		game._room.queue_free()
	for l in game._room_lights:
		game._sconces.erase(l)
	game.decor.recheck_decor()   # building is only between days today, so nobody is seated yet
	game._room = Node3D.new()
	game.add_child(game._room)
	var r: Dictionary = Scenery.build_room(game._room, game.plan, Game.DOOR)
	_sync_walls()
	game._room_lights.assign(r.lights)
	game._sconces.append_array(game._room_lights)
	game._openings = r.openings
	game._opening_ok.clear()
	_flood_key = 0
	_refresh_openings()
	# The camera keeps the whole floor in view as it grows back and to the left.
	var b := game.plan.bounds()
	var shift := Vector3((b.position.x + b.end.x - Game.W) / 2.0, 0, (b.position.y + b.end.y - Game.H) / 2.0)
	var grow := maxf(1.0, float(b.size.x + b.size.y + 2) / float(Game.W + Game.H + 2))
	game._frame = [Game.WIDE_FOCUS + shift, Game.WIDE_SIZE * grow, Game.CLOSE_FOCUS + shift, Game.CLOSE_SIZE * grow]


## Greys out each door and archway nobody can get through: one with bare
## ground or furniture on a side, or none of it reachable from the front door.
func _refresh_openings() -> void:
	var key := [game.grid.walls.hash(), game.grid.doors.hash(), game.grid.blocked.hash(), game.grid.outside.hash(), game._openings.size()].hash()
	if key == _flood_key:
		return   # nothing the flood reads has changed
	_flood_key = key
	flood_runs += 1
	var seen := game.grid.flood(Game.DOOR)
	for e: Vector3i in game._openings:
		var ok := opening_usable(e, seen)
		if game._opening_ok.get(e, null) != ok:
			game._opening_ok[e] = ok
			Scenery.dress_opening(game._openings[e], ok)


func opening_usable(e: Vector3i, seen := {}) -> bool:
	if seen.is_empty():
		seen = game.grid.flood(Game.DOOR)
	var s := Floorplan.sides(e)
	return game.plan.opening_has_floor(e) and not game.grid.blocked.has(s[0]) and not game.grid.blocked.has(s[1]) \
		and (seen.has(s[0]) or seen.has(s[1]))


## A tool (a top) added where a bare counter stands goes onto that counter.
func add_station(type: String, cell: Vector2i, tier := 1, facing := 0, base := "", pass_look := false, node := "") -> Station:
	var st := Station.new()
	game.add_child(st)
	st.setup(type, cell, tier, facing, base, pass_look, node)
	if Station.is_table(type) or type == "floor_lamp":
		st.lamp = _add_lamp(st.position)
	if Kitchen.is_top(type) and _bare_counter(cell) != null:
		_onto_counter(st, cell, facing)
	else:
		_register(st)
	return st


## The counter at a cell with nothing on top, or null.
func _bare_counter(cell: Vector2i) -> Station:
	var st: Station = game.stations.get(cell)
	return st if st != null and st.type == "counter" else null


## Stands a tool (not registered yet) on the bare counter at a cell: the counter's
## node gives way to the tool's, which takes over its base, look and the till.
func _onto_counter(top: Station, cell: Vector2i, facing: int) -> void:
	var under := _bare_counter(cell)
	var held := game.kitchen.take_stock(cell)   # the boxes below stay put (PRD 8.4)
	if under != null:
		_unregister(under)
		var till := under.get_node_or_null("till")
		if till:
			till.reparent(top, false)
		top.set_base(under.base, under.pass_look)
		top.stacked = under.stacked
		under.queue_free()
	top.place_at(cell, facing)
	_register(top)
	game.kitchen.give_stock(cell, held)
	_show_boxes(cell)


## Lifts the tool off a counter: the bare counter is left standing in its place.
func _off_counter(top: Station) -> void:
	var held := game.kitchen.take_stock(top.cell)
	_unregister(top)
	var under := Station.new()
	game.add_child(under)
	under.setup("counter", top.cell, 1, top.facing, top.base, top.pass_look)
	under.stacked = top.stacked
	var till := top.get_node_or_null("till")
	if till:
		till.reparent(under, false)
	_register(under)
	game.kitchen.give_stock(under.cell, held)
	_show_boxes(under.cell)
	top.set_boxes([])


## Whether the piece in hand can go onto the station at a cell: a tool onto a bare
## counter, with nothing on the counter below. A counter never goes onto a counter.
func _stacks_on(cell: Vector2i, h: Dictionary) -> bool:
	var under := _bare_counter(cell)
	if under == null or under.item != "" or not Kitchen.is_top(h.id) or Kitchen.grows_from_counter(hand_node(h)):
		return false
	if h.get("moving", false) and (h.node as Station).item != "":
		return false
	return game.kitchen.can_place(cell, Kitchen.node_of(h.id))


func _register(st: Station) -> void:
	game.stations[st.cell] = st
	if Station.is_seat(st.type):   # guests walk onto a seat, but nothing else is built there
		game.grid.reserved[st.cell] = true
	else:
		game.grid.blocked[st.cell] = true
	if st.base != "":
		game.kitchen.set_cell(st.cell, st.base, st.node if Kitchen.is_top(st.type) else "")
	st.set_wall(false)
	_refresh_wall(st.cell)
	_show_boxes(st.cell)
	_update_racks()
	game.tables.rebuild()


## Redraws the tags naming what a cell stores: over the piece standing there, else over
## the piece hung on the wall; above the high layer when the cell has one.
func _show_boxes(cell: Vector2i) -> void:
	var up := game.kitchen.get_piece(cell, "high") != "" or Kitchen.is_tall(game.kitchen.get_piece(cell, "base"))
	var y := 2.62 if up else 1.6
	if game.stations.has(cell):
		(game.stations[cell] as Station).set_boxes(game.kitchen.stock(cell), y)
		if game.highs.has(cell):
			(game.highs[cell] as Station).set_boxes([])
	elif game.highs.has(cell):
		(game.highs[cell] as Station).set_boxes(game.kitchen.stock(cell), y)


# ---------------------------------------------------------------- the wall layer (PRD 8.5)

## The back walls behind a cell that a piece can hang on: full height, with floor on
## this side only and no door, archway or window in them. West first, then north.
func _back_walls(c: Vector2i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for e: Vector3i in [Vector3i(c.x, c.y, 1), Vector3i(c.x, c.y, 0)]:
		if Scenery.wall_look(game.plan, e) == "tall" and not game.plan.openings.has(e) and not game.plan.windows.has(e):
			out.append(e)
	return out


## Marks the kitchen's wall cells from the plan, and which way a piece hung in each
## faces: away from its wall (1 is +x, off the left wall; 0 is +z, off the back wall).
func _sync_walls() -> void:
	game.kitchen.wall_cells.clear()
	game.wall_facing.clear()
	for c: Vector2i in game.plan.floors:
		var e := _back_walls(c)
		if not e.is_empty():
			game.kitchen.set_wall(c)
			game.wall_facing[c] = 1 if e[0].z == 1 else 0


## Whether taking away these wall edges (laying floor behind them, opening them up)
## would leave a hung piece with no wall to hang on.
func _strands_high(edges: Array[Vector3i]) -> bool:
	for c: Vector2i in game.highs:
		var left := _back_walls(c)
		for e in edges:
			left.erase(e)
		if left.is_empty():
			return true
	return false


## The kitchen node of a piece in hand: the counter's node for a counter (a fridge, a
## tall fridge), else the piece's own.
static func hand_node(h: Dictionary) -> String:
	if h.get("node") is Station:
		var st: Station = h.node
		return st.base if st.type == "counter" and st.base != "" else st.node
	if h.get("up", "") != "":
		return h.up   # a tree node the shop sold, built already upgraded
	if h.get("base", "") != "":
		return h.base   # a counter sold as a fridge
	return Kitchen.node_of(str(h.get("id", "")))


## The layer a kitchen piece would take in a cell: "base", "high" or "" (no room). Over
## anything standing there (a kitchen piece or not) only the high layer is left.
func layer_for(cell: Vector2i, node: String) -> String:
	if not Kitchen.has_node(node):
		return ""
	if game.stations.has(cell):
		return "high" if game.kitchen.can_hang(cell, node) else ""
	return game.kitchen.layer_for(cell, node)


## The layer the piece in hand would take where it is held: "high", "base", or "" for
## none (or a piece that is not a kitchen piece).
func hand_layer(ch: Player = null) -> String:
	ch = game._me(ch)
	var hn := hand_node(ch.hand)
	var p := game.room_edit._hover_point(ch)
	if not Kitchen.has_node(hn) or p == Vector3.INF:
		return ""
	var sp := game.placing.snap(p, ch)
	return layer_for(Vector2i(sp.x, sp.y), hn)


## Hangs a new piece from the catalog on a wall cell's high layer.
func add_high(id: String, cell: Vector2i) -> Station:
	var st := Station.new()
	game.add_child(st)
	st.setup(id, cell, 1, int(game.wall_facing.get(cell, 0)))
	_hang(st, cell)
	return st


## Hangs a piece (new or carried) in a cell's high layer, facing off the wall.
func _hang(st: Station, cell: Vector2i) -> void:
	st.visible = true
	st.place_at(cell, int(game.wall_facing.get(cell, 0)))
	game.kitchen.hang(cell, st.node)
	if st.kit_tool != "":   # a shelf carried with its tool keeps it
		game.kitchen.tools[cell] = st.kit_tool
	game.highs[cell] = st
	_refresh_wall(cell)
	_show_boxes(cell)


## Redraws a hung piece.
func _refresh_wall(cell: Vector2i) -> void:
	if game.highs.has(cell):
		(game.highs[cell] as Station).set_wall(true)


## The piece a chef uses at a cell: what stands there, else what hangs on the wall above
## bare floor. A chef holding Reach (`ch`) uses only what hangs there, or nothing.
func station_at(cell: Vector2i, ch: Player = null) -> Station:
	if ch != null and game.card.reaching(ch):
		if not game.highs.has(cell) and is_tall_at(cell):
			return game.stations.get(cell)   # a tall fridge has two levels: Reach takes the upper kind
		return game.highs.get(cell)
	return game.stations.get(cell, game.highs.get(cell))


## Whether a tall piece (tall fridge, freezer, glass fridge) stands on the cell with nothing hung on it.
func is_tall_at(cell: Vector2i) -> bool:
	return Kitchen.is_tall(game.kitchen.get_piece(cell, "base")) and not game.highs.has(cell)


func _unregister(st: Station) -> void:
	game.stations.erase(st.cell)
	st.set_boxes([])   # the lifted piece carries no tags of the cell it left
	game.kitchen.set_cell(st.cell, "")
	game.grid.blocked.erase(st.cell)
	game.grid.reserved.erase(st.cell)
	_refresh_wall(st.cell)
	_show_boxes(st.cell)
	_update_racks()
	game.tables.rebuild()


## Marks each sink that has a dish rack standing beside it (one cell, diagonals too).
func _update_racks() -> void:
	for st: Station in game.stations.values():
		if st.type != "sink":
			continue
		var racked := false
		for o: Station in game.stations.values():
			racked = racked or (o.type == "dish_rack" and Decor.dist(o.cell, st.cell) == 1)
		if racked != st.racked:
			st.racked = racked
			st.refresh()


## A low partition (sheet 11): teal panelled base, tan cap, thin coral line.
func add_wall(cell: Vector2i, axis: int, height := 1.0) -> Node3D:
	game.grid.walls[Vector3i(cell.x, cell.y, axis)] = true
	var n := Node3D.new()
	_place_on_edge(n, Vector3i(cell.x, cell.y, axis))
	game.add_child(n)
	_wall_visual(n, height)
	return n


static func _place_on_edge(n: Node3D, edge: Vector3i) -> void:
	n.position = Vector3(edge.x + 0.5, 0, edge.y) if edge.z == 0 else Vector3(edge.x, 0, edge.y + 0.5)
	n.rotation.y = 0.0 if edge.z == 0 else PI / 2


static func _wall_visual(n: Node3D, height: float) -> void:
	Build.box(n, Vector3.ZERO, Vector3(1.0, height - 0.12, 0.24), Build.CABINET)
	Build.box(n, Vector3(0, height - 0.14, 0), Vector3(1.0, 0.04, 0.26), Build.CORAL)
	Build.box(n, Vector3(0, height - 0.1, 0), Vector3(1.04, 0.1, 0.3), Build.WORKTOP, 0.0, Build.R_WOOD)


func find_station(type: String) -> Station:
	for st: Station in game.stations.values():
		if st.type == type:
			return st
	return null
