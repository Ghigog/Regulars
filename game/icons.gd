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
		"zzz":
			for i in 3:
				o.append([ell(-0.62 + i * 0.36, -0.55, 0.14), INK])
			for z: Array in [[-0.3, 0.05, 0.3], [0.38, 0.5, 0.42]]:
				var s: float = z[2]
				var c := Vector2(z[0], z[1])
				o.append([rect(c.x, c.y + s * 0.8, s * 2, s * 0.42), INK])
				o.append([rect(c.x, c.y - s * 0.8, s * 2, s * 0.42), INK])
				o.append([PackedVector2Array([c + Vector2(s * 0.4, s), c + Vector2(s, s), c + Vector2(-s * 0.4, -s), c + Vector2(-s, -s)]), INK])
		"stink":
			_blob(o, [[-0.35, -0.1, 0.42], [0.2, -0.2, 0.5], [0.5, 0.15, 0.36], [-0.05, 0.3, 0.46]], GREEN)
			for i in 2:
				o.append([ell(-0.2 + i * 0.4, 0.05, 0.09), "#4c8f3f"])
			o.append([rect(0, -0.25, 0.5, 0.1), "#4c8f3f"])
		"heart":
			o.append([ell(-0.36, 0.25, 0.44), CORAL])
			o.append([ell(0.36, 0.25, 0.44), CORAL])
			o.append([PackedVector2Array([Vector2(-0.77, 0.1), Vector2(0.77, 0.1), Vector2(0, -0.82)]), CORAL])
			o.append([ell(-0.42, 0.38, 0.13), "#ffc2b4"])
		"coin":
			o.append([ell(0, 0, 0.9), GOLD_DARK])
			o.append([ell(0, 0.06, 0.82), GOLD])
			o.append([ell(0, 0.06, 0.56), "#ffd76a"])
			o.append([rect(0, 0.06, 0.2, 0.62), GOLD_DARK])
		"tip":
			o.append([rect(-0.15, 0.2, 1.3, 0.7, 0.25), "#5fa873"])
			o.append([rect(-0.15, 0.2, 1.0, 0.44, 0.25), "#a9d6b4"])
			o.append_array(_moved(icon("coin"), Vector2(0.3, -0.3), 0.6))
		"walkout":
			o.append([ell(0, 0, 0.9), "#a82a25"])
			o.append([ell(0, 0.05, 0.82), RED])
			for sx: float in [-1.0, 1.0]:
				o.append([PackedVector2Array([Vector2(sx * 0.6, 0.5), Vector2(sx * 0.1, 0.2), Vector2(sx * 0.14, 0.05), Vector2(sx * 0.62, 0.3)]), INK])
				o.append([ell(sx * 0.32, 0.02, 0.1), INK])
			o.append([ell(0, -0.52, 0.34, 0.2, 0, 180, 10), INK])
		"hourglass":
			o.append([rect(0, 0.78, 1.3, 0.24), "#a8703f"])
			o.append([rect(0, -0.78, 1.3, 0.24), "#a8703f"])
			o.append([PackedVector2Array([Vector2(-0.5, 0.66), Vector2(0.5, 0.66), Vector2(0.06, 0), Vector2(0.5, -0.66), Vector2(-0.5, -0.66), Vector2(-0.06, 0)]), "#dff0f0"])
			o.append([PackedVector2Array([Vector2(-0.32, 0.4), Vector2(0.32, 0.4), Vector2(0, 0.02)]), GOLD])
			o.append([PackedVector2Array([Vector2(-0.44, -0.62), Vector2(0.44, -0.62), Vector2(0, -0.3)]), GOLD])
		"star":
			o.append([star(0, -0.03, 0.98, 5, 0.5), GOLD_DARK])
			o.append([star(0, 0.03, 0.8, 5, 0.5), "#ffd452"])
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
