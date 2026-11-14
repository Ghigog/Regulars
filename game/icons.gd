class_name Icons
extends RefCounted
## Flat cut-out artwork shared by the world effects (Fx) and the interface (Hud).
## An icon is a list of [outline, colour] layers in a unit square (y up, about
## -1..1). Effects are four such frames (style guide, sheets 13 and 14).

const INK := "#3a2c22"
const CREAM := "#fff6e6"
const GOLD := "#f2b632"
const GOLD_DARK := "#c98a1b"
const GREEN := "#7fbf6a"
const RED := "#e83d36"
const CORAL := "#ee7560"
const TEAL := "#6fc0c4"

static var _cache := {}


static func ell(x: float, y: float, rx: float, ry := -1.0, a0 := 0.0, a1 := 360.0, n := 20) -> PackedVector2Array:
	if ry < 0.0:
		ry = rx
	var pts := PackedVector2Array()
	var full := is_equal_approx(a1 - a0, 360.0)
	for i in (n if full else n + 1):
		var a := deg_to_rad(lerpf(a0, a1, float(i) / n))
		pts.append(Vector2(x + cos(a) * rx, y + sin(a) * ry))
	return pts


static func rect(x: float, y: float, w: float, h: float, turn := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for c: Vector2 in [Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)]:
		pts.append(Vector2(x, y) + (c / 2.0).rotated(turn))
	return pts


static func star(x: float, y: float, r: float, points := 4, inner := 0.4, turn := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := PI * i / points + turn
		pts.append(Vector2(x, y) + Vector2(sin(a), cos(a)) * (r if i % 2 == 0 else r * inner))
	return pts


static func _blob(out: Array, circles: Array, col: String, rim := 0.0, rim_col := INK) -> void:
	if rim > 0.0:
		for c: Array in circles:
			out.append([ell(c[0], c[1], c[2] + rim), rim_col])
	for c: Array in circles:
		out.append([ell(c[0], c[1], c[2]), col])


static func _moved(layers: Array, by: Vector2, scale := 1.0) -> Array:
	var out: Array = []
	for l: Array in layers:
		var pts := PackedVector2Array()
		for p: Vector2 in l[0]:
			pts.append(p * scale + by)
		out.append([pts, l[1]])
	return out


## A convex outline pushed out from its centre, for an ink rim.
static func _grown(pts: PackedVector2Array, by: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	c /= pts.size()
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p + (p - c).normalized() * by)
	return out


static func icon(id: String) -> Array:
	if _cache.has(id):
		return _cache[id]
	var o: Array = []
	match id:
		"burger":
			o.append([ell(0, -0.42, 0.78, 0.36, 180, 360), "#e6a542"])
			o.append([rect(0, -0.3, 1.56, 0.26), "#e6a542"])
			o.append([rect(0, -0.1, 1.74, 0.3), "#7a3b22"])
			o.append([PackedVector2Array([Vector2(-0.84, 0.05), Vector2(-0.5, -0.22), Vector2(-0.1, 0.05), Vector2(0.3, -0.22), Vector2(0.84, 0.05), Vector2(0.84, 0.16), Vector2(-0.84, 0.16)]), "#ffd452"])
			o.append([rect(0, 0.2, 1.86, 0.17), "#6fbf5f"])
			o.append([ell(0, 0.26, 0.8, 0.62, 0, 180), "#e6a542"])
		"food":
			o = _moved(icon("burger"), Vector2.ZERO, 1.0)
		"order":  # waiting to order: an order pad with a coral binding and a pencil
			o.append([rect(-0.12, -0.04, 1.36, 1.72, -0.1), INK])
			o.append([rect(-0.12, -0.08, 1.12, 1.48, -0.1), CREAM])
			o.append([rect(-0.06, 0.62, 1.24, 0.32, -0.1), CORAL])
			for i in 3:
				o.append([rect(-0.2 + i * 0.03, 0.2 - i * 0.34, 0.74 - i * 0.18, 0.13, -0.1), INK])
			var pen := PackedVector2Array([Vector2(0.98, 0.62), Vector2(1.12, 0.5), Vector2(0.4, -0.5), Vector2(0.26, -0.38)])
			o.append([_grown(pen, 0.07), INK])
			o.append([pen, GOLD])
			o.append([PackedVector2Array([Vector2(0.26, -0.38), Vector2(0.4, -0.5), Vector2(0.2, -0.7)]), INK])
		"warning":  # a gold road-sign triangle with an ink rim and a bold "!"
			o.append([PackedVector2Array([Vector2(0, 1.0), Vector2(-1.05, -0.82), Vector2(1.05, -0.82)]), INK])
			o.append([PackedVector2Array([Vector2(0, 0.74), Vector2(-0.8, -0.66), Vector2(0.8, -0.66)]), GOLD])
			o.append([rect(0, 0.06, 0.2, 0.62), INK])
			o.append([ell(0, -0.44, 0.12), INK])
		"zzz":
			for i in 3:
				o.append([ell(-0.62 + i * 0.36, -0.55, 0.14), INK])
			for z: Array in [[-0.3, 0.05, 0.3], [0.38, 0.5, 0.42]]:
				var s: float = z[2]
				var c := Vector2(z[0], z[1])
				o.append([rect(c.x, c.y + s * 0.8, s * 2, s * 0.42), INK])
				o.append([rect(c.x, c.y - s * 0.8, s * 2, s * 0.42), INK])
				o.append([PackedVector2Array([c + Vector2(s * 0.4, s), c + Vector2(s, s), c + Vector2(-s * 0.4, -s), c + Vector2(-s, -s)]), INK])
		"ick", "gross":
			# Sheet 13: wavy stink lines; the stronger stage adds a third and a puff.
			var lines := [-0.42, 0.18] if id == "ick" else [-0.6, -0.12, 0.36]
			for x0: float in lines:
				for k in 9:
					o.append([ell(x0 + 0.13 * sin(k * 0.95), -0.7 + k * 0.17, 0.105), "#6f9f3f"])
			if id == "gross":
				_blob(o, [[0.52, 0.55, 0.2], [0.72, 0.42, 0.16], [0.6, 0.72, 0.14]], GREEN)
		"stink":  # sheet 14: a green cloud on a darker base, fumes inside
			_blob(o, [[-0.35, -0.3, 0.42], [0.2, -0.4, 0.5], [0.5, -0.05, 0.36]], "#6f8f3a")
			_blob(o, [[-0.35, -0.1, 0.42], [0.2, -0.2, 0.5], [0.5, 0.15, 0.36], [-0.05, 0.3, 0.46]], GREEN)
			for x0: float in [-0.3, 0.02, 0.34]:
				for k in 5:
					o.append([ell(x0 + 0.06 * sin(k * 1.4), -0.22 + k * 0.11, 0.05), "#4c8f3f"])
		"heart":  # a coral heart with a cream rim
			for pass_: Array in [[1.2, CREAM], [1.0, CORAL]]:
				var k: float = pass_[0]
				o.append([ell(-0.36 * k, 0.25 * k - (k - 1.0) * 0.1, 0.44 * k), pass_[1]])
				o.append([ell(0.36 * k, 0.25 * k - (k - 1.0) * 0.1, 0.44 * k), pass_[1]])
				o.append([PackedVector2Array([Vector2(-0.77 * k, 0.1 * k - (k - 1.0) * 0.1), Vector2(0.77 * k, 0.1 * k - (k - 1.0) * 0.1), Vector2(0, -0.82 * k - (k - 1.0) * 0.1)]), pass_[1]])
			o.append([ell(-0.42, 0.38, 0.13), "#ffc2b4"])
		"coin":  # sheet 14: a thick rim round an embossed crest
			o.append([ell(0, -0.06, 0.94), GOLD_DARK])
			o.append([ell(0, 0.04, 0.9), GOLD])
			o.append([ell(0, 0.04, 0.68), GOLD_DARK])
			o.append([ell(0, 0.0, 0.62), "#f7c948"])
			o.append([PackedVector2Array([Vector2(-0.3, 0.34), Vector2(-0.1, 0.22), Vector2(0, 0.36), Vector2(0.1, 0.22), Vector2(0.3, 0.34), Vector2(0.3, -0.08), Vector2(0, -0.4), Vector2(-0.3, -0.08)]), "#ffe08a"])
		"coins":  # a short stack, for totals
			for i in 3:
				o.append([ell(0.05 * (i % 2), -0.55 + i * 0.36, 0.8, 0.3), GOLD_DARK])
				o.append([ell(0.05 * (i % 2), -0.45 + i * 0.36, 0.8, 0.3), GOLD if i < 2 else "#f7c948"])
		"tip":  # two mint notes and a coin
			for n: Array in [[-0.12, 0.28, 0.2], [-0.02, 0.08, 0.08]]:
				o.append([rect(n[0], n[1], 1.5, 0.84, n[2]), "#f4f1e4"])
				o.append([rect(n[0], n[1], 1.32, 0.66, n[2]), "#bfe3d0"])
				o.append([ell(n[0], n[1], 0.26), "#6fb6a8"])
			o.append_array(_moved(icon("coin"), Vector2(0.48, -0.48), 0.5))
		"walkout":  # a red token with an angry face pressed into it
			o.append([ell(0, -0.06, 0.94), "#b83228"])
			o.append([ell(0, 0.04, 0.9), "#e8564a"])
			o.append([ell(0, 0.04, 0.72), "#d9463b"])
			o.append([ell(0, 0.02, 0.66), "#e8564a"])
			for sx: float in [-1.0, 1.0]:
				o.append([PackedVector2Array([Vector2(sx * 0.48, 0.42), Vector2(sx * 0.1, 0.2), Vector2(sx * 0.13, 0.08), Vector2(sx * 0.5, 0.26)]), "#a82a22"])
				o.append([ell(sx * 0.26, 0.04, 0.085), "#a82a22"])
			o.append([ell(0, -0.44, 0.28, 0.2, 0, 180, 10), "#a82a22"])
			o.append([ell(0, -0.48, 0.2, 0.12, 0, 180, 10), "#e8564a"])
		"hourglass":  # teal caps, cream posts, sand running through
			for y: float in [0.82, -0.82]:
				o.append([rect(0, y, 1.36, 0.3), "#1f6470"])
				o.append([rect(0, y + 0.05, 1.2, 0.12), "#3f8a94"])
			for x: float in [-0.56, 0.56]:
				o.append([rect(x, 0, 0.1, 1.36), "#efe4cc"])
			o.append([PackedVector2Array([Vector2(-0.42, 0.66), Vector2(0.42, 0.66), Vector2(0.07, 0), Vector2(0.42, -0.66), Vector2(-0.42, -0.66), Vector2(-0.07, 0)]), "#dff0f0"])
			o.append([PackedVector2Array([Vector2(-0.28, 0.42), Vector2(0.28, 0.42), Vector2(0, 0.04)]), "#e3b77e"])
			o.append([PackedVector2Array([Vector2(-0.38, -0.62), Vector2(0.38, -0.62), Vector2(0, -0.26)]), "#e3b77e"])
		"star":  # a chunky gold star with a raised centre
			o.append([star(0, -0.05, 1.0, 5, 0.55), GOLD_DARK])
			o.append([star(0, 0.03, 0.9, 5, 0.55), GOLD])
			o.append([star(0, 0.03, 0.56, 5, 0.55), "#ffd76a"])
		"day":  # a cream card in a wooden frame: the sun coming up
			o.append([rect(0, 0, 1.6, 1.9), "#a8703f"])
			o.append([rect(0, 0.03, 1.36, 1.64), CREAM])
			o.append([star(0, -0.1, 0.62, 8, 0.66), GOLD])
			o.append([ell(0, -0.1, 0.36), "#ffd76a"])
			o.append([rect(0, -0.52, 1.36, 0.82), CREAM])
			o.append([rect(0, -0.14, 1.0, 0.07), GOLD_DARK])
		"sun":
			o.append([star(0, 0, 0.98, 8, 0.62), GOLD])
			o.append([ell(0, 0, 0.56), "#ffd76a"])
		"anger":
			pass
	if id == "anger":  # four curved arms: keep only the red crescents
		var arms: Array = []
		for i in 4:
			var a := PI / 2 * i + PI / 4
			var pts := PackedVector2Array()
			for k in 9:
				var t := deg_to_rad(lerpf(-58, 58, k / 8.0))
				pts.append(Vector2(cos(a), sin(a)) * 0.95 - Vector2(cos(a + t), sin(a + t)) * 0.66)
			for k in range(8, -1, -1):
				var t := deg_to_rad(lerpf(-58, 58, k / 8.0))
				pts.append(Vector2(cos(a), sin(a)) * 0.95 - Vector2(cos(a + t), sin(a + t)) * 0.42)
			arms.append([pts, RED])
		o = arms
	_cache[id] = o
	return o


## The thought-bubble cloud: thick dark rim, cream fill, two lead-in dots.
static func bubble() -> Array:
	var o: Array = []
	var lobes := [[0, 0, 0.74], [-0.62, -0.05, 0.5], [0.62, -0.05, 0.5], [-0.34, 0.46, 0.5], [0.34, 0.46, 0.52], [-0.3, -0.48, 0.46], [0.34, -0.46, 0.46]]
	_blob(o, [[-0.82, -1.02, 0.17], [-1.08, -1.34, 0.1]], CREAM, 0.07)
	_blob(o, lobes, CREAM, 0.09)
	return o


## Four-frame effect sequences.
static func fx(id: String) -> Array:
	var key := "fx_" + id
	if _cache.has(key):
		return _cache[key]
	var frames: Array = []
	for f in 4:
		var o: Array = []
		var t := f / 3.0
		match id:
			"steam":  # off-white curls
				for w in 2:
					for k in 5:
						var y := k * 0.36 + f * 0.09
						var x := (w - 0.5) * 0.7 + sin(y * 4.0 + f * 1.57 + w * 2.0) * 0.16
						o.append([ell(x, y, 0.17 - k * 0.022), "#f7f3ea"])
			"smoke", "burn":  # a puff that grows as it rises
				var col := "#cbbfae" if id == "smoke" else "#3b3533"
				var g := 0.55 + 0.2 * t
				_blob(o, [[0, 0.3 + t * 0.5, 0.4 * g], [-0.36 * g, 0.5 + t * 0.5, 0.32 * g], [0.36 * g, 0.55 + t * 0.5, 0.34 * g], [0.02, 0.84 + t * 0.55, 0.36 * g]], col)
				_blob(o, [[-0.3 + 0.2 * (f % 2), 0.0, 0.2], [0.26, 0.12, 0.16]], col)
				if id == "burn":
					for k in 3:
						var a := 0.5 + k * 1.0 + f * 0.3
						o.append([star(cos(a) * (0.5 + t * 0.4), 0.5 + sin(a) * 0.3 + t * 0.6, 0.12, 4, 0.4), RED if (k + f) % 2 else "#ff9a3c"])
			"flame":  # toy flames
				for k in 3:
					var x := (k - 1) * 0.42
					var h := 0.75 + 0.25 * ((k + f) % 2) + (0.3 if k == 1 else 0.0)
					var lean := 0.12 * (1 if (k + f) % 2 else -1)
					o.append([PackedVector2Array([Vector2(x - 0.24, 0), Vector2(x + 0.24, 0), Vector2(x + 0.2, h * 0.45), Vector2(x + lean, h), Vector2(x - 0.2, h * 0.45)]), "#f5762c"])
					o.append([PackedVector2Array([Vector2(x - 0.12, 0), Vector2(x + 0.12, 0), Vector2(x + lean * 0.5, h * 0.55)]), "#ffd452"])
			"spatter":  # yellow droplets flicking up
				for k in 4:
					var a := 0.5 + k * 0.7
					var d := 0.3 + 0.6 * fmod(t + k * 0.25, 1.0)
					o.append([ell(cos(a) * d, sin(a) * d * 0.9, 0.09), "#ffd452"])
			"stars":  # gold and white four-point stars bursting, then dissolving
				for k in 5:
					var a := TAU * k / 5.0 + 0.3
					var d := 0.25 + 0.75 * t
					var r := 0.34 * (1.0 if f < 2 else (0.7 if f == 2 else 0.35))
					o.append([star(cos(a) * d, sin(a) * d, r, 4, 0.38), "#ffffff" if k % 2 else GOLD])
			"bubbles":  # teal and white, growing, then a ripple
				if f < 3:
					for k in 4:
						var x := -0.5 + k * 0.33
						var y := 0.15 * (k % 2) + t * 0.6
						var r := 0.12 + 0.07 * f + 0.03 * (k % 2)
						o.append([ell(x, y, r + 0.035), "#ffffff"])
						o.append([ell(x, y, r), TEAL])
						o.append([ell(x - r * 0.35, y + r * 0.35, r * 0.28), "#ffffff"])
				else:
					o.append([Build.arc_pts(0.62, 0.74, 0, 360), TEAL])
					o.append([Build.arc_pts(0.3, 0.38, 0, 360), "#ffffff"])
			"wisps":  # green wisps rising into a puff
				if f < 2:
					for w in 3:
						for k in 3:
							o.append([ell((w - 1) * 0.4 + sin(k * 2.0 + f) * 0.1, k * 0.26 + f * 0.2, 0.12 - k * 0.02), GREEN])
				else:
					var g := 0.7 if f == 2 else 1.0
					_blob(o, [[-0.3 * g, 0.5, 0.36 * g], [0.3 * g, 0.5, 0.36 * g], [0, 0.78, 0.4 * g], [0, 0.4, 0.34 * g]], GREEN)
			"anger":  # the vein-pop mark, pulsing, with small puffs
				var s := 0.85 if f % 2 else 1.0
				o.append_array(_moved(icon("anger"), Vector2.ZERO, s))
				_blob(o, [[-1.05 - 0.1 * f, -0.5, 0.16 + 0.03 * f], [1.05 + 0.1 * f, -0.45, 0.14 + 0.03 * f]], "#f1e6da")
		frames.append(o)
	_cache[key] = frames
	return frames
