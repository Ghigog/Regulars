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
	var want := {"cups": Station.CUPS, "tray_stack": Station.TRAYS}
	for id: String in want:
		var base := Node3D.new()   # the same piece, bare, without its load
		add_child_autofree(base)
		base.set_meta("bare", true)
		BuildStations.station(base, id, 1, "", false, "")
		assert_eq(_preview(id).get_child_count() - base.get_child_count(), want[id], "%s items" % id)


func test_counter_top_previews_have_no_counter() -> void:
	for id in ["slicer", "cups", "tray_stack"]:
		assert_eq(_slabs(_preview(id)), 0, "%s has no worktop" % id)


func test_placed_stack_keeps_its_counter() -> void:
	var probe := Node3D.new()
	add_child_autofree(probe)
	BuildStations.station(probe, "cups", 1)
	assert_gt(_slabs(probe), 0)
