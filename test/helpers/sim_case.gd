extends GutTest
## Shared setup and helpers for the test_sim* test files.


# ---------- Building ----------

func _room() -> Grid:
	# A 4 x 3 room with the door cell just outside its bottom edge at (1, 3).
	var g := Grid.new(4, 4)
	for x in 4:
		if x != 1:
			g.walls[Vector3i(x, 3, 0)] = true
	return g



func _roots(found: Array[Dictionary]) -> Array[Dictionary]:
	return found.filter(func(bp: Dictionary) -> bool: return not bp.has("tree"))



# ---------------------------------------------------------------- floorplan

func _plan() -> Floorplan:
	var p := Floorplan.new(Rect2i(-3, -3, 10, 10))
	p.fill(Rect2i(0, 0, 2, 2), "planks")
	return p



# ---------- Pantry and Menu (PRD 1) ----------

func _stations(ids: Array, ready := [], off := []) -> Array:
	var out := []
	for id: String in ids:
		out.append({"ingredient": id, "ready": ready.has(id), "stocked": not off.has(id)})
	return out



func _menu_items() -> Array:
	var m := Menu.new()
	m.add("main", ["bun", "patty"])
	m.add("main", ["lettuce", "tomato"])
	m.add("side", ["potato"])
	m.add("side", ["corn"])
	m.add("drink", ["soda"])
	return m.items



# ---------------------------------------------------------------- PRD 7: catalog and themes

const PRD7_PIECES := ["floor_lamp", "flower_stand", "coat_stand", "jukebox", "gumball", "aquarium",
	"palm", "lantern", "stool", "bin", "dish_rack", "sink"]



# ---------- The critic (PRD 2) ----------

func _sum_parts(t: Town, i: int) -> float:
	var sum := 0.0
	for k: String in t.people[i].opinion:
		sum += float(t.people[i].opinion[k])
	return sum



# ---------- Plates, cups and stacks ----------

func _burger_menu() -> Array:
	var m := Menu.new()
	m.add("main", ["bun", "patty"], "Burger")
	m.add("side", ["potato"], "Fries")
	m.add("drink", ["soda"], "Soda")
	return m.items
