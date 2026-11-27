extends GutTest
## Fries are two steps for a helper: fetch a potato to the board, chop it, then fry the cut
## potato for the ticket. Lemonade, milkshake and steamed corn stay one step at their tool.

const BOX := Vector2i(0, 0)
const BOARD := Vector2i(1, 0)
const FRYER := Vector2i(2, 0)
const STOVE := Vector2i(3, 0)


func _world(stations: Array, extra := {}, lacks := ["fries"], kinds := ["potato"]) -> Dictionary:
	var w := {
		"stations": stations,
		"storage": [{"cell": BOX, "kinds": kinds}],
		"tickets": [{"id": 1, "cell": Vector2i(5, 0), "lacks": lacks}],
	}
	w.merge(extra, true)
	return w


func _board(w: Dictionary) -> JobBoard:
	var b := JobBoard.new()
	b.rebuild(w)
	return b


func _tools(with_fryer := true, with_stove := false) -> Array:
	var out := [{"id": BOARD, "cell": BOARD, "tool": "board"}]
	if with_fryer:
		out.append({"id": FRYER, "cell": FRYER, "tool": "fryer"})
	if with_stove:
		out.append({"id": STOVE, "cell": STOVE, "tool": "stove"})
	return out


func test_a_potato_is_fetched_to_the_board_first():
	var t: Dictionary = _board(_world(_tools())).tasks["fetch:1:0"]
	assert_eq(t.dest, BOARD)
	assert_eq(t.job, "chop")
	assert_eq(t.source, "potato")
	assert_eq(t.kind, "fries", "it still covers the ticket's lack")


func test_the_fetch_chops_and_leaves_the_cut_potato_on_the_board():
	var t: Dictionary = _board(_world(_tools())).tasks["fetch:1:0"]
	var steps := HelperWork.steps(t, ["fetch", "board"], "board")
	assert_eq(steps.map(func(s: Dictionary) -> String: return s.do), ["take", "cook", "leave"])
	assert_eq(steps[1].kind, "potato")
	assert_eq(steps[1].hold, "raw:potato")
	assert_eq(steps[2].at, BOARD)


func test_a_fetcher_without_the_board_duty_leaves_the_raw_potato():
	var t: Dictionary = _board(_world(_tools())).tasks["fetch:1:0"]
	var steps := HelperWork.steps(t, ["fetch"], "board")
	assert_eq(steps.map(func(s: Dictionary) -> String: return s.do), ["take", "leave"])


func test_a_raw_potato_waiting_on_the_board_is_chopped_there():
	var item := {"id": "c:1,0", "kind": "potato", "cell": BOARD, "state": "raw", "station": BOARD}
	var b := _board(_world(_tools(), {"items": [item]}))
	assert_false(b.tasks.has("fetch:1:0"), "the potato out covers the lack")
	var t: Dictionary = b.tasks["prep:c:1,0"]
	assert_eq(t.job, "chop")
	var steps := HelperWork.steps(t, ["board"])
	assert_eq(steps.map(func(s: Dictionary) -> String: return s.do), ["cook", "leave"])
	assert_eq(steps[0].kind, "potato")


func test_the_cut_potato_is_fried_at_the_fryer():
	var item := {"id": "c:1,0", "kind": "potato", "cell": BOARD, "state": "raw", "form": "prep:potato"}
	var b := _board(_world(_tools(), {"items": [item]}))
	var t: Dictionary = b.tasks["prep:c:1,0"]
	assert_eq(t.job, "fry")
	assert_eq(t.hold, "prep:potato")
	assert_eq(t.options[0].station, FRYER)
	var steps := HelperWork.steps(t, ["fry"])
	t.station = FRYER
	steps = HelperWork.steps(t, ["fry"])
	assert_eq(steps.map(func(s: Dictionary) -> String: return s.do), ["pick", "cook", "deliver"])
	assert_eq(steps[1].kind, "fries")
	assert_eq(steps[1].hold, "prep:potato")


func test_the_cut_potato_is_fried_on_the_stove_without_a_fryer():
	var item := {"id": "c:1,0", "kind": "potato", "cell": BOARD, "state": "raw", "form": "prep:potato"}
	var b := _board(_world(_tools(false, true), {"items": [item]}))
	assert_eq(b.tasks["prep:c:1,0"].options[0].station, STOVE)


func test_no_board_leaves_the_lack_stuck():
	var b := _board(_world([{"id": FRYER, "cell": FRYER, "tool": "fryer"}]))
	assert_false(b.tasks.has("fetch:1:0"))


func test_no_fryer_or_stove_leaves_the_lack_stuck():
	var b := _board(_world(_tools(false)))
	assert_false(b.tasks.has("fetch:1:0"))


func test_hold_for_fries_is_the_cut_potato():
	assert_eq(HelperWork.hold_for("fries"), "prep:potato")


func test_lemonade_is_still_one_step_at_its_tool():
	var w := _world([{"id": BOARD, "cell": BOARD, "tool": "juicer"}], {}, ["lemonade"], ["lemon"])
	var t: Dictionary = _board(w).tasks["fetch:1:0"]
	assert_false(t.has("make"))
	assert_eq(t.job, "juice")
	assert_eq(t.dest, BOARD)
	assert_eq(HelperWork.hold_for("lemonade"), "raw:lemon")
	assert_eq(HelperWork.hold_for("steamed_corn"), "raw:corn")
	assert_eq(HelperWork.hold_for("milkshake"), "prep:ice_cream")
