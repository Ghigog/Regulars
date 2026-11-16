class_name FloorMess
extends RefCounted
## Dirt on the floor (PRD 9), separate from the plates, sink and bin in Cleaning.
## Each floor cell holds a level from 0 (clean) to 4 (fully covered). Dirt lands, grows,
## overflows to a neighbour, is tracked by feet, slows and trips people, and puts guests
## off by sight and smell. Cells are Vector2i; this knows nothing about the scene. All
## randomness goes through `rng`, so a seeded FloorMess is deterministic.

const MAX_LEVEL := 4

## Speed multiplier for anyone standing on a cell, by level. (tunable)
const SPEED: Array[float] = [1.0, 0.9, 0.8, 0.65, 0.5]

## Slipping: the chance each time someone steps onto a level 4 cell. (tunable)
const SLIP_LEVEL := 4
const SLIP_CHANCE := 0.25        # a guest
const SLIP_CHANCE_CHEF := 0.15   # a chef
## Getting back up, in seconds. (tunable; used from 9.3)
const HELP_UP_CHEF := 1.0        # a chef pressing E beside them
const HELP_UP_GUEST := 6.0       # a guest within one cell who is not seated
const GET_UP_ALONE_GUEST := 20.0
const GET_UP_ALONE_CHEF := 4.0
const WITNESS_RADIUS := 1
## After a slip, the walkout chance runs from this (opinion 0) to this (opinion 1). (tunable)
const SLIP_WALKOUT_HATED := 0.9
const SLIP_WALKOUT_LOVED := 0.1
## What a slip does to mood (9.3). The fallen guest loses about a walkout's worth; each
## witness within WITNESS_RADIUS a little; left on the floor until GET_UP_ALONE_GUEST, a
## guest gets up angrier still. (tunable)
const SLIP_PATIENCE := 0.35
const SLIP_JOY := 0.4
const WITNESS_PATIENCE := 0.05
const WITNESS_JOY := 0.1
const ALONE_PATIENCE := 0.15
const ALONE_JOY := 0.2
const SLIP_THOUGHT := "Ow! The floor!"
const WITNESS_THOUGHT := "Did they just fall?"
const ALONE_THOUGHT := "Nobody helped me up"
const HELPED_THOUGHT := "Thanks for the hand"

## Disgust per second to anyone who can see a dirty cell, by level. Same scale as GROSS
## in game/main.gd. (tunable)
const SIGHT_DISGUST: Array[float] = [0.0, 0.003, 0.008, 0.015, 0.03]
## Disgust per second from smell, seen or not, by level of a cell within SMELL_RADIUS
## (Chebyshev distance, so the 5x5 square around it). (tunable)
const SMELL_DISGUST: Array[float] = [0.0, 0.0, 0.0, 0.006, 0.012]
const SMELL_RADIUS := 2

## Grease: the chance per prep done that a level drops on the chef's cell or one beside the
## station, by prep tool. (tunable)
const GREASE := {
	"fry": 0.5,
	"grill": 0.3,
	"boil": 0.15,
	"chop": 0.1,
	"slice": 0.1,
	"pour": 0.1,
}
const GREASE_BAD := 2.0    # a badly played prep (or a spoiled one)
const GREASE_GOOD := 0.5   # a well played prep
const HOOD := 0.3          # a hood over the stove

## Guests: the chance once per meal, when they finish eating. (tunable)
const GUEST_BASE := 0.15
const GUEST_MESSY := 2.0    # a townsperson with the messy trait
const GUEST_GREASY := 1.5   # a fried or meat dish
const GUEST_RADIUS := 2     # lands on a free floor cell within this of the seat

const OVERFLOW_TRIES := 8   # chained overflows before a level is lost (all full around)

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var floor_cells := {}   # Vector2i -> true: where dirt can be
var covered := {}       # Vector2i -> true: floor under furniture
var dirt := {}          # Vector2i -> int 1..4; clean cells are absent
var rng := RandomNumberGenerator.new()


func _init(cells: Array = [], seed_value: int = 0) -> void:
	set_floor(cells)
	rng.seed = seed_value


func set_floor(cells: Array) -> void:
	floor_cells.clear()
	for c in cells:
		floor_cells[c] = true


## Which floor cells furniture stands on. Dirt already there stays.
func set_covered(cells: Array) -> void:
	covered.clear()
	for c in cells:
		covered[c] = true


func is_floor(cell: Vector2i) -> bool:
	return floor_cells.has(cell)


func is_covered(cell: Vector2i) -> bool:
	return covered.has(cell)


func level(cell: Vector2i) -> int:
	return dirt.get(cell, 0)


func total() -> int:
	var n := 0
	for c in dirt:
		n += dirt[c]
	return n


func _set_level(cell: Vector2i, value: int) -> void:
	if value <= 0:
		dirt.erase(cell)
	else:
		dirt[cell] = mini(value, MAX_LEVEL)


## One level of new dirt lands on `cell`. Below 4 it grows the cell by one; at 4 it goes
## to a random one of the eight neighbours instead (under furniture included), and on
## from there if that is full too. Returns the cell that grew, or null if none did
## (not floor, or everything around was full).
func add_dirt(cell: Vector2i) -> Variant:
	if not is_floor(cell):
		return null
	var at := cell
	for i in OVERFLOW_TRIES:
		if level(at) < MAX_LEVEL:
			_set_level(at, level(at) + 1)
			return at
		var around := _floor_neighbours(at)
		if around.is_empty():
			return null
		var open := around.filter(func(c): return level(c) < MAX_LEVEL)
		var pick: Array = open if not open.is_empty() else around
		at = pick[rng.randi() % pick.size()]
	return null


func _floor_neighbours(cell: Vector2i) -> Array:
	var out := []
	for d in NEIGHBOURS:
		if is_floor(cell + d):
			out.append(cell + d)
	return out


## Whether a cell can be mopped now: not while furniture stands on it.
func can_clean(cell: Vector2i) -> bool:
	return not is_covered(cell)


## Clears up to `levels` from a cell; returns how many came off (0 under furniture).
func clean(cell: Vector2i, levels: int = 1) -> int:
	if not can_clean(cell):
		return 0
	var had := level(cell)
	var off := mini(had, maxi(levels, 0))
	_set_level(cell, had - off)
	return off


## Someone walks from `from` to the next cell `to`. Off a dirty cell they carry one
## level: `from` loses one, `to` gains one (overflowing as new dirt does). Returns
## whether anything was tracked. A fallen guest does not walk, so is never passed here.
func track(from: Vector2i, to: Vector2i) -> bool:
	if level(from) <= 0 or not is_floor(to) or from == to:
		return false
	_set_level(from, level(from) - 1)
	add_dirt(to)
	return true


## How fast anyone moves on a cell at this level.
static func speed_of(lvl: int) -> float:
	return SPEED[clampi(lvl, 0, MAX_LEVEL)]


func speed_at(cell: Vector2i) -> float:
	return speed_of(level(cell))


## The chance of slipping on stepping onto a cell at this level.
static func slip_chance(lvl: int, chef: bool = false) -> float:
	if lvl < SLIP_LEVEL:
		return 0.0
	return SLIP_CHANCE_CHEF if chef else SLIP_CHANCE


## Rolls a slip for someone stepping onto `cell`.
func rolls_slip(cell: Vector2i, chef: bool = false) -> bool:
	var p := slip_chance(level(cell), chef)
	return p > 0.0 and rng.randf() < p


## The chance a guest walks out on getting up, from their opinion of the place (town
## affinity and current mood, 0 to 1): low for one who loves it, very high otherwise.
static func slip_walkout_chance(opinion: float) -> float:
	return lerpf(SLIP_WALKOUT_HATED, SLIP_WALKOUT_LOVED, clampf(opinion, 0.0, 1.0))


## A guest's opinion of the place, 0 to 1, for the walkout roll after a slip: their town
## affinity (-1 to 1) and how the visit feels now (GuestMood.satisfaction, -1 to 1), equally.
static func slip_opinion(affinity: float, satisfaction: float) -> float:
	return clampf(0.25 * (clampf(affinity, -1.0, 1.0) + 1.0) + 0.25 * (clampf(satisfaction, -1.0, 1.0) + 1.0), 0.0, 1.0)


## Rolls whether a guest who slipped walks out on getting up.
func rolls_slip_walkout(opinion: float) -> bool:
	return rng.randf() < slip_walkout_chance(opinion)


## How long someone stays down: until helped (a chef 1 s, a guest 6 s, from when help
## starts) or alone (a guest 20 s, a chef 4 s).
static func get_up_alone_time(chef: bool) -> float:
	return GET_UP_ALONE_CHEF if chef else GET_UP_ALONE_GUEST


static func help_time(by_chef: bool) -> float:
	return HELP_UP_CHEF if by_chef else HELP_UP_GUEST


## Whether `who` at cell `at` is close enough to see a fall at `fell` (or to help).
static func within_witness(at: Vector2i, fell: Vector2i) -> bool:
	return maxi(absi(at.x - fell.x), absi(at.y - fell.y)) <= WITNESS_RADIUS


static func sight_disgust_of(lvl: int) -> float:
	return SIGHT_DISGUST[clampi(lvl, 0, MAX_LEVEL)]


static func smell_disgust_of(lvl: int) -> float:
	return SMELL_DISGUST[clampi(lvl, 0, MAX_LEVEL)]


## Disgust per second from the dirty cells someone can see (the game's sightlines).
func sight_disgust(visible: Array) -> float:
	var sum := 0.0
	for c in visible:
		sum += sight_disgust_of(level(c))
	return sum


## Disgust per second from smell at `cell`: every level 3 or 4 cell within SMELL_RADIUS,
## seen or not.
func smell_disgust(cell: Vector2i) -> float:
	var sum := 0.0
	for c in dirt:
		var d: Vector2i = c - cell
		if maxi(absi(d.x), absi(d.y)) <= SMELL_RADIUS:
			sum += smell_disgust_of(dirt[c])
	return sum


## Both together: what standing at `cell` and seeing `visible` costs a guest a second.
func disgust_at(cell: Vector2i, visible: Array) -> float:
	return sight_disgust(visible) + smell_disgust(cell)


## The hood's multiplier on a stove's grease. Until PRD 8.5 there is no hood.
static func hood_factor(has_hood: bool = false) -> float:
	return HOOD if has_hood else 1.0


## The chance one prep drops grease. `result` is the prep's ("good", "plain", "bad",
## "spoiled"); `mess` is the tool node's factor from PRD 8's trees (1.0 until 8.3).
static func grease_chance(tool: String, result: String = "plain", mess: float = 1.0,
		has_hood: bool = false) -> float:
	var p: float = GREASE.get(tool, 0.0)
	match result:
		"good":
			p *= GREASE_GOOD
		"bad", "spoiled":
			p *= GREASE_BAD
	return clampf(p * mess * hood_factor(has_hood), 0.0, 1.0)


## Rolls one prep's grease; on a hit a level lands on one of `cells` (the chef's cell and
## the cells beside the station). Returns the cell that grew, or null.
func drop_grease(tool: String, result: String, cells: Array, mess: float = 1.0,
		has_hood: bool = false) -> Variant:
	if cells.is_empty() or rng.randf() >= grease_chance(tool, result, mess, has_hood):
		return null
	return add_dirt(cells[rng.randi() % cells.size()])


## The chance a guest leaves mess when they finish eating. `annoyance` is 0 to 1.
static func guest_mess_chance(annoyance: float, messy: bool = false, greasy: bool = false) -> float:
	var p := GUEST_BASE * (1.0 + clampf(annoyance, 0.0, 1.0))
	if messy:
		p *= GUEST_MESSY
	if greasy:
		p *= GUEST_GREASY
	return clampf(p, 0.0, 1.0)


## The free floor cells (not under furniture) within GUEST_RADIUS of a seat.
func guest_landing_cells(seat: Vector2i) -> Array:
	var out := []
	for y in range(-GUEST_RADIUS, GUEST_RADIUS + 1):
		for x in range(-GUEST_RADIUS, GUEST_RADIUS + 1):
			var c := seat + Vector2i(x, y)
			if is_floor(c) and not is_covered(c):
				out.append(c)
	return out


## Rolls a guest's mess once per meal; on a hit a level lands on a random free floor
## cell near the seat (and may still overflow under furniture). Returns the cell that
## grew, or null.
func drop_guest_mess(seat: Vector2i, annoyance: float, messy: bool = false,
		greasy: bool = false) -> Variant:
	if rng.randf() >= guest_mess_chance(annoyance, messy, greasy):
		return null
	var cells := guest_landing_cells(seat)
	if cells.is_empty():
		return null
	return add_dirt(cells[rng.randi() % cells.size()])
