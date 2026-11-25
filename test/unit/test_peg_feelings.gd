extends GutTest
## A peg's head shows what a guest feels: red anger, green disgust, rosy delight.

var _pegs: Array[Peg] = []


func _peg() -> Peg:
	var p := Peg.guest("Mabel")
	add_child_autofree(p)
	_pegs.append(p)
	return p


func _u(p: Peg, name: String) -> Variant:
	return p._head.material_override.get_shader_parameter(name)


func _settle() -> void:
	await get_tree().create_timer(Peg.HEAD_EASE + 0.2).timeout


func test_anger_only_is_red_and_no_green() -> void:
	var p := _peg()
	p.set_feelings({"anger": 0.4, "disgust": 0, "delight": 0.0})
	await _settle()
	assert_almost_eq(_u(p, "top_amount"), 0.38, 0.01)
	assert_eq(_u(p, "bottom_amount"), 0.0)
	assert_true((_u(p, "top_col") as Color).is_equal_approx(Color(Peg.ANGER_RED)))
	var plain := _peg()
	assert_gt(p._features.get_child_count(), plain._features.get_child_count(), "lowered brows add strokes")
	assert_eq(_u(p, "top_y"), -1.0, "red covers the whole head when alone")


func test_disgust_only_is_clear_green_with_wavy_mouth() -> void:
	var p := _peg()
	p.set_feelings({"anger": 0.0, "disgust": 2, "delight": 0.0})
	await _settle()
	assert_eq(_u(p, "top_amount"), 0.0)
	assert_almost_eq(_u(p, "bottom_amount"), 0.6, 0.01)
	var plain := _peg()
	plain.set_feelings({"anger": 0.0, "disgust": 0, "delight": 0.0})
	assert_gt(p._features.get_child_count(), plain._features.get_child_count(), "wavy mouth and a nose wrinkle add strokes")


func test_ick_is_faint_green() -> void:
	var p := _peg()
	p.set_feelings({"anger": 0.0, "disgust": 1, "delight": 0.0})
	await _settle()
	assert_almost_eq(_u(p, "bottom_amount"), 0.28, 0.01)
	assert_eq(_u(p, "top_amount"), 0.0)


func test_both_split_red_over_green() -> void:
	var p := _peg()
	p.set_feelings({"anger": 0.6, "disgust": 2, "delight": 0.0})
	await _settle()
	assert_gt(_u(p, "top_amount"), 0.0)
	assert_gt(_u(p, "bottom_amount"), 0.0)
	assert_between(_u(p, "top_y"), -Peg.HEAD_R, Peg.HEAD_R, "the line sits on the head")
	assert_eq(_u(p, "top_y"), _u(p, "bottom_y"))


func test_delight_warms_the_skin() -> void:
	var p := _peg()
	var before: Color = _u(p, "skin")
	p.set_feelings({"anger": 0.0, "disgust": 0, "delight": 1.0})
	await _settle()
	assert_gt((_u(p, "skin") as Color).r - (_u(p, "skin") as Color).g, before.r - before.g)
	assert_eq(_u(p, "top_amount"), 0.0)


func test_green_eases_in_and_other_heads_are_untouched() -> void:
	var a := _peg()
	var b := _peg()
	assert_ne(a._head.material_override, b._head.material_override, "each head has its own material")
	a.set_feelings({"anger": 0.0, "disgust": 2, "delight": 0.0})
	await get_tree().create_timer(Peg.HEAD_EASE * 0.4).timeout
	var mid: float = _u(a, "bottom_amount")
	assert_between(mid, 0.01, 0.59, "part way, not snapped")
	await _settle()
	assert_almost_eq(_u(a, "bottom_amount"), 0.6, 0.01)
	assert_eq(_u(b, "bottom_amount"), 0.0)
