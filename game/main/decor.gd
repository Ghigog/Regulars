class_name GameDecor
extends RefCounted
## Decor (PRD 7): what cheers a seated guest, bonuses by cell, a piece's reach over seats
## and the reach marks drawn while one is held.

var game: Game


func _init(game_: Game) -> void:
	game = game_


## Decor cheers a guest once, as they sit down: a flat bonus from what is near the
## seat (see Decor). If the room changes while they sit, they get the difference.
func cheer_with_decor(g: Guest) -> void:
	var b := decor_bonus(g.seat)
	var gain: float = b.joy - g.decor
	if absf(gain) > 0.0001:
		g.mood.delight(gain, Decor.thought(b.best) if gain > 0.0 else "")
	g.decor = b.joy


## Works the decor bonus out again for everyone seated, after the room changes.
func recheck_decor() -> void:
	for g: Guest in game.guests:
		if g.seated_waiting() or g.state == "eating":
			cheer_with_decor(g)


## The decor bonus for a seat: {"joy", "best"} from Decor.bonus.
func decor_bonus(cell: Vector2i) -> Dictionary:
	return Decor.bonus(decor_near(cell))


## Every nice thing a seat can see, as {"id", "dist", "tier"} for Decor.bonus:
## each kind of floor, each rug, each kind of wall finish and each fern, at the
## nearest cell of it the seat can see (Decor.nearest, the rule the reach marks use).
func decor_near(cell: Vector2i) -> Array:
	var out: Array = []
	var r := Decor.VIEW_RANGE
	var add := func(id: String, cells: Array, reach: int, tier: int) -> void:
		var d := Decor.nearest(game.grid, cell, cells, reach)
		if d >= 0:
			out.append({"id": id, "dist": d, "tier": tier})
	var floors := {}
	for c: Vector2i in game.plan.floors:
		var id := "floor_" + game.plan.kind(c)
		if Catalog.joy_of(id) > 0.0:
			if not floors.has(id):
				floors[id] = []
			floors[id].append(c)
	for id: String in floors:
		add.call(id, floors[id], r, 1)
	var treated := {}   # a floor finish in force today is decor, like parquet (PRD 9.5)
	for c: Vector2i in game.floor_dirt.mess.treat:
		var id := Treatments.tool_id(game.floor_dirt.mess.treat[c])
		if Catalog.joy_of(id) > 0.0:
			if not treated.has(id):
				treated[id] = []
			treated[id].append(c)
	for id: String in treated:
		add.call(id, treated[id], r, 1)
	for a: Vector2i in game.rugs:
		add.call("rug", GamePlacing.rug_cells(a, int(game.rugs[a].get_meta("facing", 0))), r, 1)
	var walls := {}
	for e: Vector3i in game.plan.finishes:
		var id: String = game.plan.finishes[e]
		if not walls.has(id):
			walls[id] = []
		walls[id].append(e)
	for id: String in walls:
		add.call(id, Decor.finish_cells(game.plan, walls[id]), r, 1)
	for st: Station in game.stations.values():
		if Catalog.is_decor_piece(st.type):
			add.call(st.type, [st.cell], Decor.reach(st.type, st.tier), st.tier)
	return out


static func _dist(a: Vector2i, b: Vector2i) -> int:
	return Decor.dist(a, b)


## How far a piece's effect on guests reaches, in cells. 0 for a piece with none.
static func range_of(id: String, tier := 1) -> int:
	if Catalog.is_decor_piece(id):
		return Decor.reach(id, tier)
	return Game.BIN_RANGE if id == "bin" else 0


## Every seat in the room, and the share of a piece's joy (a Decor band) that would
## reach it from `cell` with a reach of `reach` cells: Decor.BESIDE, Decor.IN_VIEW or 0.
## Partitions block it, as they block a guest's view.
func seats_reached(cell: Vector2i, reach: int) -> Dictionary:
	var out := {}
	for st: Station in game.stations.values():
		for s in st.seats:
			var d := Decor.nearest(game.grid, s, [cell], reach)
			out[s] = Decor.band(maxi(1, d), reach) if d >= 0 else 0.0
	return out


## What a piece held as `h` at the point `at` would reach, with `drag` the drag in
## progress ({"from", "remove"} or {}). Takes the hand and spot as arguments so a
## second chef's hand works the same. {} when the piece cheers or bothers nobody.
## "cells": where its effect comes from; "area": the pale square (no area for
## floors and finishes, which have no single centre); "close": the brighter one.
func piece_reach(h: Dictionary, at: Vector3, drag: Dictionary) -> Dictionary:
	if h.is_empty() or at == Vector3.INF or drag.get("remove", false):
		return {}
	var id: String = h.id
	var tier := int(h.get("tier", 1))
	var cell := Grid.to_cell(at)
	var none := Rect2i()
	if range_of(id, tier) > 0:
		var r := range_of(id, tier)
		return {"id": id, "tier": tier, "cells": [cell], "reach": r, "decor": Catalog.is_decor_piece(id),
			"area": Rect2i(cell - Vector2i(r, r), Vector2i(r, r) * 2 + Vector2i.ONE),
			"close": Rect2i(cell - Vector2i.ONE, Vector2i(3, 3))}
	if Catalog.joy_of(id, tier) <= 0.0:
		return {}
	var from: Vector3 = drag.get("from", at)
	var cells: Array[Vector2i] = []
	var area := none
	var close := none
	if GamePlacing.floor_kind(id) != "":
		var k := GamePlacing.floor_kind(id)
		var rect := Floorplan.rect_cells(Grid.to_cell(from), cell)
		cells = game.plan.lay_order(rect, k)
		for c in rect:   # already this floor: it stays, and still counts
			if game.plan.has_floor(c) and game.plan.kind(c) == k:
				cells.append(c)
	elif Catalog.is_finish(id):
		var edges: Array[Vector3i] = []
		for e in _edge_run(from, at):
			if game.plan.is_wall(e) and not game.plan.openings.has(e):
				edges.append(e)
		cells = Decor.finish_cells(game.plan, edges)
	elif id == "rug":
		cells = GamePlacing.rug_cells(cell, int(h.get("facing", 0)))
		var box := Rect2i(cells[0], Vector2i.ONE)
		for c in cells:
			box = box.expand(c).expand(c + Vector2i.ONE)
		area = box.grow(Decor.VIEW_RANGE)
		close = box.grow(1)
	else:
		return {}
	return {"id": id, "tier": tier, "cells": cells, "reach": Decor.reach(id, tier), "decor": true,
		"area": area, "close": close}


## The wall edges a drag from `from` to `to` runs along (one edge without a drag).
func _edge_run(from: Vector3, to: Vector3) -> Array[Vector3i]:
	var a := Vector2i(roundi(from.x), roundi(from.z))
	var b := Vector2i(roundi(to.x), roundi(to.z))
	if a == b:
		return [GamePlacing.snap_edge(to)]
	return Floorplan.line(a, b)


## The mark each seat gets from a piece_reach: {seat: {"share", "mark", "full"}}.
## "full" is a seat whose decor joy is already at Decor.CAP, so the piece adds nothing.
func reach_marks(pr: Dictionary) -> Dictionary:
	var out := {}
	if pr.is_empty():
		return out
	for st: Station in game.stations.values():
		for s in st.seats:
			var share: float
			if pr.decor:
				share = Decor.share_from(game.grid, s, pr.id, pr.cells, pr.tier)
			else:
				var d := Decor.nearest(game.grid, s, pr.cells, pr.reach)
				share = Decor.band(maxi(1, d), pr.reach) if d >= 0 else 0.0
			var full: bool = pr.decor and share > 0.0 and Decor.is_full(decor_near(s))
			out[s] = {"share": share, "mark": Decor.mark(share), "full": full}
	return out


## While a piece with a reach is carried (a fern, the bin, a fine floor, a finish or
## a rug), every seat gets a mark: a green square on it (all its joy), a big green
## disc beside it (half), a small pale one in view (a fifth), red out of reach, and a
## white tick on a seat already as cheered as decor can make it. The fern, bin and
## rug also wash the floor they are seen from.
func _update_range(ch: Player = null) -> void:
	ch = game._me(ch)
	var pr := piece_reach(ch.hand if game.phase == Game.Phase.BUILD else {}, game.room_edit._hover_point(ch), ch.drag)
	var key := "%s:%s:%s:%d:%d:%d" % [pr.get("id", ""), pr.get("cells", []), pr.get("area", Rect2i()),
		game.stations.size(), game.grid.walls.size(), game.plan.floors.size()] if not pr.is_empty() else ""
	if key == ch.range_key:
		return
	ch.range_key = key
	for c in ch.range_marks.get_children():
		c.queue_free()
	if key == "":
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.22)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var y := 0.03
	for r: Rect2i in [pr.area, pr.close]:
		var area := r.intersection(game.lot.bounds())
		if not area.has_area():
			continue
		var wash := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(area.size)
		wash.mesh = plane
		wash.material_override = m
		wash.position = Vector3(area.position.x + area.size.x / 2.0, y, area.position.y + area.size.y / 2.0)
		ch.range_marks.add_child(wash)
		y += 0.005
	var marks := reach_marks(pr)
	for s: Vector2i in marks:
		ch.range_marks.add_child(_seat_mark(s, marks[s]))


## One seat's reach mark, as reach_marks describes it. Each level differs in shape:
## a white-rimmed square for on, a big disc for beside, a small disc for in view, a
## red disc for not reached; the "full" tick is a white check, inked, on top.
func _seat_mark(s: Vector2i, info: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.position = Grid.center(s) + Vector3(0, 0.05, 0)
	var kind: String = info.mark
	var mark := Node3D.new()
	root.add_child(mark)
	var col := Color(Build.DANGER) if kind == Decor.MARK_NONE else Color(Build.GOOD)
	var fill := Build.overlay_mat(Color(col, 0.5 if kind == Decor.MARK_VIEW else 0.85), 2)
	if kind == Decor.MARK_ON:
		_flat_box(mark, Vector3.ZERO, Vector2(0.78, 0.78), 0.0, Build.overlay_mat(Color(Build.PAPER), 2))
		_flat_box(mark, Vector3(0, 0.005, 0), Vector2(0.6, 0.6), 0.0, Build.overlay_mat(Color(col), 3))
	else:
		var disc := MeshInstance3D.new()
		var puck := CylinderMesh.new()
		puck.top_radius = 0.4
		puck.bottom_radius = 0.4
		puck.height = 0.02
		disc.mesh = puck
		disc.material_override = fill
		mark.add_child(disc)
	var size := Vector3(0.6, 1, 0.6) if kind == Decor.MARK_VIEW else Vector3.ONE
	mark.scale = Vector3(0.3, 1, 0.3)
	mark.create_tween().tween_property(mark, "scale", size, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if info.full:
		# A check mark lying flat, the same size on every mark: ink under, white over.
		var tick := Node3D.new()
		tick.position = Vector3(0, 0.02, 0)
		tick.rotation.y = deg_to_rad(45.0)   # upright to the camera
		tick.scale = Vector3(1.4, 1, 1.4)
		var strokes := [[Vector3(-0.1, 0, 0.05), 0.2, deg_to_rad(-45.0)], [Vector3(0.08, 0, -0.03), 0.4, deg_to_rad(45.0)]]
		for layer: Array in [[Build.TRIM, 0.13, 4], [Build.PAPER, 0.07, 5]]:
			for st: Array in strokes:
				_flat_box(tick, st[0] + Vector3(0, 0.002 * layer[2], 0), Vector2(st[1] + layer[1] - 0.07, layer[1]),
					st[2], Build.overlay_mat(Color(layer[0]), layer[2]))
		root.add_child(tick)
	return root


## A thin flat box lying on the floor, `size` across x and z, turned `turn` about y.
static func _flat_box(parent: Node3D, at: Vector3, size: Vector2, turn: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(size.x, 0.01, size.y)
	m.mesh = b
	m.material_override = mat
	m.position = at
	m.rotation.y = turn
	parent.add_child(m)


static func _near(a: Vector2i, b: Vector2i, r: int) -> bool:
	return absi(a.x - b.x) <= r and absi(a.y - b.y) <= r
