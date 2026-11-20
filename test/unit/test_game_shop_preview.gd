extends "res://test/helpers/game_case.gd"
## Shop and tree previews: counter-top pieces are shown as themselves, off their counter.


func _preview(id: String) -> Node3D:
	var view := HudWidgets.ModelView.new(200, false)
	add_child_autofree(view)
	view.show_piece(game, {"id": id, "tier": 1})
	return view.spin.get_child(0)


## Meshes whose box is the worktop slab's 1.0 x 0.13 x 1.0.
func _slabs(root: Node) -> int:
	var found := 0
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if (m.mesh as Mesh).get_aabb().size.is_equal_approx(Vector3(1.0, 0.13, 1.0)):
			found += 1
	return found


func test_stack_previews_hold_their_items() -> void:
	var plates := _preview("plates")
	var cups := _preview("cups")
	var trays := _preview("tray_stack")
	var want := {plates: Station.PLATES, cups: Station.CUPS, trays: Station.TRAYS}
	for n: Node3D in want:
		var probe := Node3D.new()
		var type := "plates" if n == plates else ("cups" if n == cups else "tray_stack")
		BuildFood.stack_load(probe, type, want[n])
		assert_eq(n.get_child_count() - 1 >= probe.get_child_count(), true, type)
		probe.free()


func test_counter_top_previews_have_no_counter() -> void:
	for id in ["slicer", "plates", "cups", "tray_stack"]:
		assert_eq(_slabs(_preview(id)), 0, "%s has no worktop" % id)


func test_placed_stack_keeps_its_counter() -> void:
	var probe := Node3D.new()
	add_child_autofree(probe)
	BuildStations.station(probe, "plates", 1)
	assert_gt(_slabs(probe), 0)
