class_name Grid
extends RefCounted
## Tile grid for the restaurant: furniture blocks cells, walls sit on cell edges.
## Cell (x, y) covers world x..x+1 and z..z+1.

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var size: Vector2i
var blocked := {}   # Vector2i -> true: furniture, nobody can stand here
var reserved := {}  # Vector2i -> true: seats and doorways, walkable but not buildable
var walls := {}     # Vector3i(x, y, axis) -> true; axis 0 = north edge of the cell, 1 = west edge


func _init(w: int, h: int) -> void:
	size = Vector2i(w, h)


static func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


static func center(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0, c.y + 0.5)


static func edge_between(a: Vector2i, b: Vector2i) -> Vector3i:
	if a.x == b.x:
		return Vector3i(a.x, maxi(a.y, b.y), 0)
	return Vector3i(maxi(a.x, b.x), a.y, 1)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func is_blocked(c: Vector2i) -> bool:
	return not in_bounds(c) or blocked.has(c)


func edge_open(a: Vector2i, b: Vector2i) -> bool:
	return not walls.has(edge_between(a, b))


func can_step(a: Vector2i, b: Vector2i) -> bool:
	return not is_blocked(b) and edge_open(a, b)


## Breadth-first path. Excludes `from`, includes `to`. Empty when unreachable or from == to.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from == to or is_blocked(to):
		return result
	var came := {from: from}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if cur == to:
			break
		for d in DIRS:
			var n: Vector2i = cur + d
			if not came.has(n) and can_step(cur, n):
				came[n] = cur
				frontier.append(n)
	if not came.has(to):
		return result
	var c := to
	while c != from:
		result.push_front(c)
		c = came[c]
	return result


func reachable(from: Vector2i, to: Vector2i) -> bool:
	return from == to or not find_path(from, to).is_empty()


## Line of sight between two cell centres. Only walls block sight; furniture is low.
func has_los(a: Vector2i, b: Vector2i) -> bool:
	var from := Vector2(a) + Vector2(0.5, 0.5)
	var to := Vector2(b) + Vector2(0.5, 0.5)
	var steps := maxi(1, int(from.distance_to(to) * 10.0))
	var prev := a
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / steps)
		var cur := Vector2i(floori(p.x), floori(p.y))
		if cur == prev:
			continue
		if cur.x == prev.x or cur.y == prev.y:
			if not edge_open(prev, cur):
				return false
		else:
			var m1 := Vector2i(cur.x, prev.y)
			var m2 := Vector2i(prev.x, cur.y)
			var r1 := edge_open(prev, m1) and edge_open(m1, cur)
			var r2 := edge_open(prev, m2) and edge_open(m2, cur)
			if not (r1 or r2):
				return false
		prev = cur
	return true
