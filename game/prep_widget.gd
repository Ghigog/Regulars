class_name PrepWidget
extends Node3D
## The little paper-and-wood gauge over a tool while a prep minigame runs (sheet 13's
## flat cut-outs, readable at the size of the cook dial). One kind per tool:
## chop (a bar, a notch and a knife), slice (a row of pips), pour (a glass), boil (a
## pot with a filling ring) and rack (fried food draining); and from PRD 8.6 grate (a
## box grater and a speed meter), saw (a loaf and a blade), juice (a reamer and a
## pressure gauge), blend (a rocking jug) and steam (a basket in a ring). Built once;
## `show_state` only moves and shows pieces.

const W := 0.8   # the chop bar's length
const RING := 12 # segments in the boil ring

var kind := ""
var quality := 1.0   # the tool's quality at the job: sizes the notch, the slack and the band (PRD 8.3)
var _knife: Node3D
var _sweeps: Array = []   # chop: per sweep [empty, hit, miss]
var _pips: Array = []     # slice: per pip [empty, full]
var _timer: Node3D
var _fill: Node3D
var _spill: Node3D
var _ring: Array = []
var _lid: Node3D
var _drips: Array = []
var _age := 0.0
var _liquid := "#7a3b2e"   # pour: the drink's colour
var _needle: Node3D       # grate, juice: the marker on the meter
var _pile: Node3D         # grate: the heap under the grater
var _blade: Node3D        # saw
var _jug: Node3D          # blend
var _rock: Node3D         # blend: the rocking meter's fill
const METER_H := 0.5      # the grate and juice meters' height


static func make(kind_: String, liquid := "", q := 1.0) -> PrepWidget:
	var w := PrepWidget.new()
	w.kind = kind_
	w.quality = q
	if liquid != "":
		w._liquid = liquid
	w.basis = Build.CAM_BASIS
	w._build()
	Build.on_top(w)
	return w


func _process(delta: float) -> void:
	_age += delta


func _build() -> void:
	match kind:
		"chop":
			Build.flat(self, Icons.rect(0, 0, W + 0.08, 0.22), Build.TRIM)
			Build.flat(self, Icons.rect(0, 0, W, 0.15), "#c98f58", 0.002)
			Build.flat(self, Icons.rect(0, 0, Prep.chop_notch(quality) * 2.0 * W, 0.15), Build.GOOD, 0.004)
			Build.flat(self, PackedVector2Array([Vector2(-0.05, 0.075), Vector2(0.05, 0.075), Vector2(0, 0.02)]), Build.TRIM, 0.006)
			_knife = Node3D.new()
			_knife.position.z = 0.01
			add_child(_knife)
			Build.flat(_knife, PackedVector2Array([Vector2(-0.03, -0.02), Vector2(0.03, -0.02), Vector2(0.03, 0.2), Vector2(-0.03, 0.14)]), "#dfe6e7")
			Build.flat(_knife, Icons.rect(0, 0.25, 0.05, 0.11), Build.WOOD_DARK, 0.001)
			for k in Prep.CHOP_SWEEPS:
				_sweeps.append(_slot(Vector2(-0.16 + k * 0.16, 0.24)))
		"slice":
			var n := Prep.SLICE_COUNT + Prep.slice_slack(quality) + 1
			Build.flat(self, Icons.rect(0, 0.02, n * 0.085 + 0.06, 0.28), Build.TRIM)
			Build.flat(self, Icons.rect(0, 0.02, n * 0.085 + 0.02, 0.24), Build.PAPER, 0.002)
			for k in n:
				var at := Vector2((k - (n - 1) / 2.0) * 0.085, 0.05)
				var col := Build.GOOD if k < Prep.SLICE_COUNT else (Build.WARN if k < Prep.SLICE_COUNT + Prep.slice_slack(quality) else Build.DANGER)
				var empty := Build.flat(self, Build.disc_pts(0.03, at, 12), "#d8ccb6", 0.004)
				var full := Build.flat(self, Build.disc_pts(0.036, at, 12), col, 0.006)
				if k == Prep.SLICE_COUNT - 1:   # the target pip: a star, so it reads by shape
					Build.flat(self, Build.star_pts(0.06, 5, 0.5, at), Build.TRIM, 0.003)
				_pips.append([empty, full])
			_timer = Node3D.new()
			_timer.position = Vector3(-(n * 0.085) / 2.0, -0.06, 0.004)
			add_child(_timer)
			Build.flat(_timer, Icons.rect(n * 0.085 / 2.0, 0, n * 0.085, 0.035), Build.CORAL)
		"pour":
			var glass := PackedVector2Array([Vector2(-0.2, 0.28), Vector2(0.2, 0.28), Vector2(0.15, -0.28), Vector2(-0.15, -0.28)])
			Build.flat(self, Icons._grown(glass, 0.035), Build.TRIM)
			Build.flat(self, glass, "#dff0f2", 0.002)
			_fill = Node3D.new()
			_fill.position = Vector3(0, -0.28, 0.004)
			add_child(_fill)
			Build.flat(_fill, Icons.rect(0, 0.28, 0.36, 0.56), _liquid)
			var band := -0.28 + 0.56 * Prep.pour_good(quality)
			Build.flat(self, Icons.rect(0, band, 0.44, 0.02), Build.TRIM, 0.008)
			Build.flat(self, Build.star_pts(0.05, 5, 0.5, Vector2(0.27, band)), Build.WARN, 0.008)
			_spill = Node3D.new()
			_spill.position.z = 0.01
			add_child(_spill)
			for x: float in [-0.24, 0.24]:
				Build.flat(_spill, Build.disc_pts(0.035, Vector2(x, 0.2), 10), _liquid)
				Build.flat(_spill, Build.disc_pts(0.025, Vector2(x * 1.15, 0.05), 10), _liquid)
		"boil":
			Build.flat(self, Build.disc_pts(0.34), Build.TRIM)
			Build.flat(self, Build.disc_pts(0.3), "#5a4636", 0.002)
			for k in RING:
				var a0 := 360.0 * k / RING + 2.0
				var seg := Build.flat(self, Build.arc_pts(0.2, 0.28, a0, a0 + 360.0 / RING - 4.0), Build.GOOD, 0.004)
				_ring.append(seg)
			Build.flat(self, Icons.rect(0, -0.04, 0.22, 0.14), "#c9d0d1", 0.006)   # the pot
			_lid = Node3D.new()
			_lid.position = Vector3(0, 0.04, 0.008)
			add_child(_lid)
			Build.flat(_lid, Icons.rect(0, 0, 0.26, 0.04), "#9aa3a6")
			Build.flat(_lid, Icons.rect(0, 0.04, 0.05, 0.04), Build.TRIM, 0.001)
		"grate":
			# A box grater over a growing heap, and the speed meter beside it.
			Build.flat(self, Icons.rect(0, 0, 0.74, 0.66), Build.TRIM)
			Build.flat(self, Icons.rect(0, 0, 0.68, 0.6), Build.PAPER, 0.002)
			var g := PackedVector2Array([Vector2(-0.3, -0.12), Vector2(-0.06, -0.12), Vector2(-0.1, 0.24), Vector2(-0.26, 0.24)])
			Build.flat(self, Icons._grown(g, 0.02), Build.TRIM, 0.003)
			Build.flat(self, g, "#c9d0d1", 0.004)
			for k in 4:   # the grater's teeth
				for j in 2:
					Build.flat(self, Build.disc_pts(0.014, Vector2(-0.23 + j * 0.06, -0.06 + k * 0.07), 6), "#5a6466", 0.005)
			Build.flat(self, Icons.rect(-0.18, 0.27, 0.1, 0.03), Build.TRIM, 0.005)
			_pile = Node3D.new()
			_pile.position = Vector3(-0.18, -0.27, 0.006)
			add_child(_pile)
			Build.flat(_pile, PackedVector2Array([Vector2(-0.14, 0), Vector2(0.14, 0), Vector2(0.06, 0.1), Vector2(-0.06, 0.1)]), _liquid)
			_meter(Vector2(0.2, 0), Prep.grate_band(quality), true)
		"saw":
			# A loaf on the bar; the blade runs through it. Both ends of a stroke glow green.
			Build.flat(self, Icons.rect(0, 0, W + 0.08, 0.3), Build.TRIM)
			Build.flat(self, Icons.rect(0, 0, W, 0.24), "#c98f58", 0.002)
			var zone := Prep.SAW_END * quality * W
			for sx: float in [-1.0, 1.0]:
				Build.flat(self, Icons.rect(sx * (W - zone) / 2.0, 0, zone, 0.24), Build.GOOD, 0.004)
			Build.flat(self, Build.disc_pts(0.11, Vector2(0, 0), 20), Build.TRIM, 0.005)
			Build.flat(self, Build.disc_pts(0.095, Vector2(0, 0), 20), "#b5722f", 0.006)
			Build.flat(self, Build.disc_pts(0.07, Vector2(0, -0.005), 20), "#ead2a4", 0.007)
			_blade = Node3D.new()
			_blade.position.z = 0.01
			add_child(_blade)
			var teeth := PackedVector2Array([Vector2(-0.16, 0.0), Vector2(0.16, 0.0), Vector2(0.16, 0.07), Vector2(-0.16, 0.07)])
			Build.flat(_blade, teeth, "#dfe6e7")
			for k in 6:
				Build.flat(_blade, PackedVector2Array([Vector2(-0.16 + k * 0.055, 0.0), Vector2(-0.13 + k * 0.055, -0.03), Vector2(-0.105 + k * 0.055, 0.0)]), "#dfe6e7")
			Build.flat(_blade, Icons.rect(0.2, 0.04, 0.1, 0.07), Build.WOOD_DARK, 0.001)
			for k in Prep.SAW_STROKES:
				_sweeps.append(_slot(Vector2(-0.24 + k * 0.16, 0.27)))
		"juice":
			# A half orange on a ribbed cone, and the pressure gauge beside it.
			Build.flat(self, Icons.rect(0, 0, 0.74, 0.66), Build.TRIM)
			Build.flat(self, Icons.rect(0, 0, 0.68, 0.6), Build.PAPER, 0.002)
			Build.flat(self, PackedVector2Array([Vector2(-0.32, -0.2), Vector2(-0.04, -0.2), Vector2(-0.08, -0.12), Vector2(-0.28, -0.12)]), "#c9d0d1", 0.003)
			Build.flat(self, PackedVector2Array([Vector2(-0.26, -0.12), Vector2(-0.1, -0.12), Vector2(-0.18, 0.02)]), "#e9e2c8", 0.004)
			_lid = Node3D.new()   # the half orange, pressed down
			_lid.position = Vector3(-0.18, 0.1, 0.005)
			add_child(_lid)
			Build.flat(_lid, Build.arc_pts(0.0, 0.12, -90, 90), _liquid)   # the fruit's peel: orange, or lemon
			Build.flat(_lid, Build.arc_pts(0.0, 0.09, -90, 90), "#fbf0d0", 0.001)
			_lid.rotation.z = PI
			_meter(Vector2(0.2, 0), Vector2(Prep.juice_good(quality), Prep.JUICE_TOP), false)
			for k in Prep.JUICE_HALVES:
				_sweeps.append(_slot(Vector2(-0.26 + k * 0.08, 0.24)))
		"blend":
			# A jug on its base that rocks with each pulse; a meter of how hard it rocks,
			# and a pip a pulse.
			Build.flat(self, Icons.rect(0, 0, 0.74, 0.66), Build.TRIM)
			Build.flat(self, Icons.rect(0, 0, 0.68, 0.6), Build.PAPER, 0.002)
			Build.flat(self, Icons.rect(-0.12, -0.24, 0.26, 0.08), Build.CORAL, 0.003)
			_jug = Node3D.new()
			_jug.position = Vector3(-0.12, -0.2, 0.004)
			add_child(_jug)
			var jug := PackedVector2Array([Vector2(-0.09, 0.0), Vector2(0.09, 0.0), Vector2(0.12, 0.3), Vector2(-0.12, 0.3)])
			Build.flat(_jug, Icons._grown(jug, 0.02), Build.TRIM)
			Build.flat(_jug, jug, "#dff0f2", 0.001)
			_fill = Node3D.new()
			_fill.position.z = 0.002
			_jug.add_child(_fill)
			Build.flat(_fill, Icons.rect(0, 0.09, 0.19, 0.18), _liquid)
			Build.flat(_jug, Icons.rect(0, 0.32, 0.27, 0.04), Build.TRIM, 0.003)
			var w_bar := Node3D.new()
			w_bar.position = Vector3(0.2, -0.2, 0.004)
			add_child(w_bar)
			Build.flat(w_bar, Icons.rect(0, 0.2, 0.1, 0.42), Build.TRIM)
			Build.flat(w_bar, Icons.rect(0, 0.2, 0.06, 0.38), "#d8ccb6", 0.001)
			Build.flat(w_bar, Icons.rect(0, 0.36, 0.06, 0.06), Build.DANGER, 0.002)
			_rock = Node3D.new()
			_rock.position = Vector3(0, 0.01, 0.003)
			w_bar.add_child(_rock)
			Build.flat(_rock, Icons.rect(0, 0.19, 0.06, 0.38), Build.WARN)
			for k in Prep.BLEND_PULSES:
				var at := Vector2(-0.27 + k * 0.05, 0.24)
				var empty := Build.flat(self, Build.disc_pts(0.02, at, 10), "#d8ccb6", 0.004)
				var full := Build.flat(self, Build.disc_pts(0.024, at, 10), Build.GOOD, 0.006)
				_pips.append([empty, full])
		"steam":
			# A bamboo basket with a lid, in a ring that fills; lift on the green arc.
			Build.flat(self, Build.disc_pts(0.34), Build.TRIM)
			Build.flat(self, Build.disc_pts(0.3), "#5a4636", 0.002)
			var band := Prep.steam_band(quality)
			for k in RING:
				var a0 := 360.0 * k / RING + 2.0
				var mid := (k + 0.5) / RING
				var col := Build.GOOD if mid >= band.x and mid <= band.y else (Build.PAPER if mid < band.x else Build.DANGER)
				var seg := Build.flat(self, Build.arc_pts(0.2, 0.28, a0, a0 + 360.0 / RING - 4.0), col, 0.004)
				_ring.append(seg)
			Build.flat(self, Icons.rect(0, -0.05, 0.24, 0.12), "#d9b26a", 0.006)   # the basket
			for k in 2:
				Build.flat(self, Icons.rect(0, -0.08 + k * 0.05, 0.24, 0.012), "#b08440", 0.007)
			_lid = Node3D.new()
			_lid.position = Vector3(0, 0.03, 0.008)
			add_child(_lid)
			Build.flat(_lid, PackedVector2Array([Vector2(-0.13, 0), Vector2(0.13, 0), Vector2(0.08, 0.06), Vector2(-0.08, 0.06)]), "#e2c07a")
			Build.flat(_lid, Icons.rect(0, 0.07, 0.04, 0.03), Build.TRIM, 0.001)
		"rack":
			Build.flat(self, Icons.rect(0, 0, 0.5, 0.3), Build.TRIM)
			Build.flat(self, Icons.rect(0, 0, 0.44, 0.24), "#c9d0d1", 0.002)
			for k in 4:   # the basket's mesh
				Build.flat(self, Icons.rect(-0.15 + k * 0.1, 0, 0.02, 0.22), "#9aa3a6", 0.004)
			for k in 3:
				var d := Build.flat(self, PackedVector2Array([Vector2(0, -0.12), Vector2(0.035, -0.2), Vector2(0, -0.235), Vector2(-0.035, -0.2)]), "#e8b04e", 0.006)
				d.position.x = -0.12 + k * 0.12
				_drips.append(d)


## An empty slot for a chop sweep: a ring, a green disc with a star (hit) or a
## coral cross (miss).
func _slot(at: Vector2) -> Array:
	var ring := Node3D.new()
	add_child(ring)
	Build.flat(ring, Build.disc_pts(0.06, at, 14), Build.TRIM, 0.004)
	Build.flat(ring, Build.disc_pts(0.04, at, 14), Build.PAPER, 0.006)
	var hit := Node3D.new()
	add_child(hit)
	Build.flat(hit, Build.disc_pts(0.065, at, 14), Build.TRIM, 0.008)
	Build.flat(hit, Build.disc_pts(0.05, at, 14), Build.GOOD, 0.01)
	Build.flat(hit, Build.star_pts(0.04, 5, 0.5, at), "#ffffff", 0.012)
	var miss := Node3D.new()
	add_child(miss)
	for turn: float in [0.785, -0.785]:
		var bar := Build.flat(miss, Icons.rect(0, 0, 0.14, 0.04), Build.DANGER, 0.012)
		bar.position = Vector3(at.x, at.y, 0)
		bar.rotation.z = turn
	return [ring, hit, miss]


## A tall meter at `at` with a green band [band.x, band.y] (shares of its height) and
## red above it; `pile` marks the grate (the band's top is a knuckle line).
func _meter(at: Vector2, band: Vector2, _pile_kind: bool) -> void:
	var m := Node3D.new()
	m.position = Vector3(at.x, at.y - METER_H / 2.0, 0.004)
	add_child(m)
	Build.flat(m, Icons.rect(0, METER_H / 2.0, 0.12, METER_H + 0.04), Build.TRIM)
	Build.flat(m, Icons.rect(0, METER_H / 2.0, 0.08, METER_H), "#d8ccb6", 0.001)
	Build.flat(m, Icons.rect(0, METER_H * (band.x + band.y) / 2.0, 0.08, METER_H * (band.y - band.x)), Build.GOOD, 0.002)
	Build.flat(m, Icons.rect(0, METER_H * (1.0 + band.y) / 2.0, 0.08, METER_H * (1.0 - band.y)), Build.DANGER, 0.002)
	Build.flat(m, Build.star_pts(0.04, 5, 0.5, Vector2(-0.1, METER_H * (band.x + band.y) / 2.0)), Build.WARN, 0.003)
	_needle = Node3D.new()
	_needle.position.z = 0.004
	m.add_child(_needle)
	Build.flat(_needle, PackedVector2Array([Vector2(0.05, 0), Vector2(0.1, 0.03), Vector2(0.1, -0.03)]), Build.TRIM)
	Build.flat(_needle, Icons.rect(0, 0, 0.1, 0.018), Build.TRIM, 0.001)


## Shows a minigame's state. chop: {pos, hits: Array of bool}; slice: {presses,
## left}; pour: {fill}; boil: {t, done}; rack: {left}; grate: {v, fill}; saw: {pos,
## stroke, hits}; juice: {p, hits}; blend: {w, pulses}; steam: {frac}.
func show_state(s: Dictionary) -> void:
	match kind:
		"chop":
			_knife.position.x = (float(s.get("pos", 0.0)) - 0.5) * W
			var hits: Array = s.get("hits", [])
			for k in _sweeps.size():
				var done := k < hits.size()
				_sweeps[k][0].visible = not done
				_sweeps[k][1].visible = done and hits[k]
				_sweeps[k][2].visible = done and not hits[k]
		"slice":
			var presses := int(s.get("presses", 0))
			for k in _pips.size():
				_pips[k][1].visible = k < presses
			_timer.scale.x = maxf(0.001, float(s.get("left", 1.0)))
		"pour":
			var fill := float(s.get("fill", 0.0))
			_fill.scale.y = clampf(fill, 0.001, 1.0)
			_spill.visible = fill > 1.0
		"boil":
			var t := clampf(float(s.get("t", 0.0)), 0.0, 1.0)
			for k in _ring.size():
				_ring[k].visible = k < roundi(t * RING)
			var done: bool = s.get("done", false)
			_lid.position.y = 0.04 + (absf(sin(_age * 22.0)) * 0.04 if done else 0.0)   # rattles when done
			_lid.rotation.z = sin(_age * 30.0) * 0.15 if done else 0.0
		"grate":
			_needle.position.y = clampf(float(s.get("v", 0.0)), 0.0, 1.05) * METER_H
			_pile.scale = Vector3(0.4 + 0.6 * clampf(float(s.get("fill", 0.0)), 0.0, 1.0), 0.2 + 1.6 * clampf(float(s.get("fill", 0.0)), 0.0, 1.0), 1.0)
		"saw":
			var pos := float(s.get("pos", 0.0))
			var back := int(s.get("stroke", 0)) % 2 == 1
			_blade.position.x = ((1.0 - pos) if back else pos) * W - W / 2.0
			var hits: Array = s.get("hits", [])
			for k in _sweeps.size():
				var done := k < hits.size()
				_sweeps[k][0].visible = not done
				_sweeps[k][1].visible = done and hits[k]
				_sweeps[k][2].visible = done and not hits[k]
		"juice":
			var pr := clampf(float(s.get("p", 0.0)), 0.0, 1.05)
			_needle.position.y = pr * METER_H
			_lid.position.y = 0.1 - pr * 0.08
			var hits: Array = s.get("hits", [])
			for k in _sweeps.size():
				var done := k < hits.size()
				_sweeps[k][0].visible = not done
				_sweeps[k][1].visible = done and hits[k]
				_sweeps[k][2].visible = done and not hits[k]
		"blend":
			var w := float(s.get("w", 0.0))
			_jug.rotation.z = sin(_age * 26.0) * clampf(w, 0.0, 1.0) * 0.35
			_rock.scale.y = clampf(w, 0.001, 1.0)
			var pulses := int(s.get("pulses", 0))
			_fill.scale.y = 0.4 + 0.6 * clampf(float(pulses) / Prep.BLEND_PULSES, 0.0, 1.0)
			for k in _pips.size():
				_pips[k][1].visible = k < pulses
		"steam":
			var frac := clampf(float(s.get("frac", 0.0)), 0.0, 1.0)
			for k in _ring.size():
				_ring[k].visible = k < roundi(frac * RING)
			_lid.position.y = 0.03 + absf(sin(_age * 20.0)) * 0.03 * frac   # rattles as it builds
			_lid.rotation.z = sin(_age * 26.0) * 0.12 * frac
		"rack":
			var left := float(s.get("left", 0.0))
			for k in _drips.size():
				_drips[k].visible = left > float(k) / _drips.size()
				_drips[k].position.y = -fmod(_age * 0.3 + k * 0.05, 0.06)


## A quick mark over a tool as a minigame ends. Good: a gold star that spins up;
## plain: a paper dot; bad: a coral cross that wobbles. Shape and motion differ, not
## only colour.
## `plus`: the piece was marinated, so a small plus rides beside the mark.
static func pop(parent: Node3D, at: Vector3, result: String, plus := false) -> void:
	var n := Node3D.new()
	n.position = at
	n.basis = Build.CAM_BASIS
	parent.add_child(n)
	var mark := Node3D.new()   # turns in its own plane, under the camera-facing card
	n.add_child(mark)
	match result:
		"good":
			Build.flat(mark, Build.star_pts(0.2, 5, 0.48), Build.TRIM)
			Build.flat(mark, Build.star_pts(0.15, 5, 0.48), "#f2b632", 0.004)
		"plain":
			Build.flat(mark, Build.disc_pts(0.1), Build.TRIM)
			Build.flat(mark, Build.disc_pts(0.075), Build.PAPER, 0.004)
		_:
			for turn: float in [0.785, -0.785]:
				Build.flat(mark, Icons.rect(0, 0, 0.32, 0.1), Build.TRIM).rotation.z = turn
				var bar := Build.flat(mark, Icons.rect(0, 0, 0.27, 0.06), Build.DANGER, 0.004)
				bar.rotation.z = turn
	var tag: Node3D = null
	if plus:
		tag = Node3D.new()   # does not turn with the star
		tag.position = Vector3(0.3, 0.14, 0)
		n.add_child(tag)
		for fill: bool in [false, true]:
			for turn: float in [0.0, PI / 2]:
				var bar := Build.flat(tag, Icons.rect(0, 0, 0.2 if fill else 0.25, 0.07 if fill else 0.12), Build.GOOD if fill else Build.TRIM, 0.006 if fill else 0.0)
				bar.rotation.z = turn
	Build.on_top(n)
	if tag != null:
		tag.scale = Vector3.ONE * 0.2
		var tg := tag.create_tween()
		tg.tween_property(tag, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tg.tween_property(tag, "position:y", 0.14 + 0.3, 0.45)
	mark.scale = Vector3.ONE * 0.2
	var tw := mark.create_tween()
	tw.tween_property(mark, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if result == "good":
		tw.parallel().tween_property(mark, "rotation:z", TAU / 5.0, 0.5)
	elif result != "plain":
		for k in 3:
			tw.tween_property(mark, "rotation:z", 0.3 if k % 2 == 0 else -0.3, 0.08)
	tw.tween_property(mark, "position:y", 0.3, 0.45)
	tw.tween_callback(n.queue_free)
