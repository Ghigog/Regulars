class_name Lot
extends RefCounted
## The restaurant's lot: a set of 5x5-tile blocks that grows one block at a time. Blocks are
## Vector2i block coordinates; a cell is block * BLOCK_SIZE + ORIGIN. The street is on the +x
## side, so blocks may be bought away from it (-x) and along it (-y, +y), never over it.
## Unlock only: a bought block is bare ground. Pure data, no scene.

const BLOCK_SIZE := 5
## Cell offset of block (0, 0): the default 3x2 lot spans x -5..9, y -3..6.
const ORIGIN := Vector2i(0, -3)
## Blocks with x at or past this are the street side and cannot be bought. (tunable)
const STREET_BLOCK_X := 2
const MAX_BOUGHT := 6
const FIRST_PRICE := 150
const PRICE_GROWTH := 1.5
const PRICE_STEP := 5

var blocks: Dictionary = {}  # Vector2i -> true
var bought := 0


func _init() -> void:
	for x in range(-1, 2):
		for y in range(0, 2):
			blocks[Vector2i(x, y)] = true


static func block_of(cell: Vector2i) -> Vector2i:
	var c := cell - ORIGIN
	return Vector2i(floori(float(c.x) / BLOCK_SIZE), floori(float(c.y) / BLOCK_SIZE))


## The cells of one block as a Rect2i.
static func block_rect(block: Vector2i) -> Rect2i:
	return Rect2i(block * BLOCK_SIZE + ORIGIN, Vector2i(BLOCK_SIZE, BLOCK_SIZE))


func has_point(cell: Vector2i) -> bool:
	return blocks.has(block_of(cell))


## The cells of the largest lot the cap allows: every block MAX_BOUGHT steps from the default
## ones, away from the street and along it.
static func max_bounds() -> Rect2i:
	var r := Lot.new().bounds()
	return Rect2i(r.position - Vector2i(MAX_BOUGHT, MAX_BOUGHT) * BLOCK_SIZE, r.size + Vector2i(MAX_BOUGHT, MAX_BOUGHT * 2) * BLOCK_SIZE)


## The smallest rect holding every owned block.
func bounds() -> Rect2i:
	var r := Rect2i()
	var first := true
	for b: Vector2i in blocks:
		var br := block_rect(b)
		r = br if first else r.merge(br)
		first = false
	return r


## Blocks sharing an edge with an owned block, off the street side. Empty once capped.
func buyable() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if bought >= MAX_BOUGHT:
		return out
	for b: Vector2i in blocks:
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = b + d
			if n.x < STREET_BLOCK_X and not blocks.has(n) and not out.has(n):
				out.append(n)
	out.sort_custom(func(a: Vector2i, c: Vector2i) -> bool: return a.x < c.x or (a.x == c.x and a.y < c.y))
	return out


## 150 x 1.5^bought, to the nearest $5. -1 once capped.
func next_price() -> int:
	if bought >= MAX_BOUGHT:
		return -1
	var raw := FIRST_PRICE * pow(PRICE_GROWTH, bought)
	return int(round(raw / PRICE_STEP)) * PRICE_STEP


## Adds the block if it is buyable. Returns whether it did; money is the caller's business.
func buy(block: Vector2i) -> bool:
	if not buyable().has(block):
		return false
	blocks[block] = true
	bought += 1
	return true


## Takes a bought block back (undo): drops it and the count, so the next price is what it was.
## The default blocks are never sold. Returns whether it did.
func unbuy(block: Vector2i) -> bool:
	if bought <= 0 or not blocks.has(block):
		return false
	blocks.erase(block)
	bought -= 1
	return true


func to_dict() -> Dictionary:
	var list: Array = []
	for b: Vector2i in blocks:
		list.append([b.x, b.y])
	return {"blocks": list, "bought": bought}


static func from_dict(d: Dictionary) -> Lot:
	var lot := Lot.new()
	if d.has("blocks"):
		lot.blocks.clear()
		for p in d["blocks"]:
			lot.blocks[Vector2i(int(p[0]), int(p[1]))] = true
		lot.bought = int(d.get("bought", 0))
	return lot
