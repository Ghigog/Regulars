class_name Peg
extends Node3D
## One peg-person: the shared body every guest and chef is built on (style guide,
## sheets 2 to 6). Huge ball head, short barrel body, no neck, no legs, floating
## mitten hands. The figure faces +z. Variety comes from the kit: skin, hair, hat,
## face extras, outfit colour and pattern.

const HEAD_R := 0.27
const HEAD_Y := 0.8
const INK := "#3a2c22"
const BLUSH := "#ee8a78"
const SKINS: Array[String] = ["#f6dcc6", "#f0c39c", "#dba276", "#a8693f", "#6f4428"]
const OUTFITS := {
	"navy": "#2f3e63", "royal": "#3f5fa8", "periwinkle": "#8b9bd6", "teal": "#2f6e73", "slate": "#66788a",
	"lilac": "#b7a3d6", "plum": "#7a4a72", "brown": "#7b5a43", "cream": "#efe4cc", "charcoal": "#44444c",
}
const HAIR_COLS := {
	"grey": "#b9b4ac", "white": "#f1ede4", "black": "#2b2523", "brown": "#6b4630", "blonde": "#e6c36a",
	"auburn": "#9a4f2e",
}
const PLAYER_TRIM: Array[String] = [Build.CORAL, "#3f9aa0", Build.WARN, Build.GOOD]
## One top-down hook each: a hat, a hair shape or a bold shirt (sheet 4).
## Felix and Nell were never drawn; theirs are made from the same kit.
const LOOKS := {
	"Mabel": {"skin": 1, "hair": "bun", "hair_col": "grey", "outfit": "lilac", "pattern": "collar"},
	"Otis": {"skin": 0, "hair": "bald", "hair_col": "white", "extra": "beard", "outfit": "slate", "pattern": "dungarees"},
	"Priya": {"skin": 4, "hair": "twin_buns", "hair_col": "black", "outfit": "teal", "pattern": "stripe"},
	"Gus": {"skin": 2, "hair": "short", "hair_col": "brown", "hat": "flat_cap", "outfit": "navy", "pattern": "apron"},
	"Ingrid": {"skin": 0, "hair": "top_knot", "hair_col": "blonde", "outfit": "periwinkle", "pattern": "stripe"},
	"Tobias": {"skin": 1, "hair": "wavy", "hair_col": "brown", "extra": "glasses", "outfit": "brown", "pattern": "collar"},
	"Wren": {"skin": 3, "hair": "short", "hair_col": "black", "hat": "beanie", "outfit": "royal", "pattern": "stripe"},
	"Hattie": {"skin": 2, "hair": "curls", "hair_col": "grey", "hat": "sun_hat", "outfit": "plum", "pattern": "plain"},
	"Leopold": {"skin": 0, "hair": "short", "hair_col": "grey", "hat": "bowler", "extra": "glasses", "outfit": "charcoal", "pattern": "collar"},
	"Suki": {"skin": 1, "hair": "bob", "hair_col": "black", "outfit": "royal", "pattern": "dungarees"},
	"Barnaby": {"skin": 3, "hair": "short", "hair_col": "brown", "hat": "bobble", "extra": "beard", "outfit": "slate", "pattern": "plain"},
	"Odette": {"skin": 4, "hair": "curls", "hair_col": "black", "hat": "beret", "outfit": "plum", "pattern": "apron"},
	"Felix": {"skin": 2, "hair": "side_swept", "hair_col": "auburn", "outfit": "cream", "pattern": "collar"},
	"Nell": {"skin": 3, "hair": "top_knot", "hair_col": "black", "outfit": "periwinkle", "pattern": "dungarees"},
}
const FACES: Array[String] = ["neutral", "content", "delighted", "impatient", "snap", "disgusted", "angry", "chewing"]
const TINTS := {"snap": ["#f08a3c", 0.5], "disgusted": ["#8fc27a", 0.7], "angry": ["#e0463a", 0.9]}

var skin := SKINS[1]
var pose := "idle"   # idle, carry, eat, tap, wave
var face := ""
var _head: MeshInstance3D
var _features: Node3D
var _hands: Array[Node3D] = []
var _age := 0.0


static func guest(person_name: String) -> Peg:
	var p := Peg.new()
	p._build(LOOKS.get(person_name, LOOKS.Mabel), false, 0)
	return p


static func chef(player := 0) -> Peg:
	var p := Peg.new()
	p._build({"skin": 2, "hair": "bald"}, true, player)
	return p


func _build(look: Dictionary, is_chef: bool, player: int) -> void:
	skin = SKINS[look.skin]
	var outfit: String = Build.CHEF_WHITE if is_chef else OUTFITS[look.outfit]
	var top := outfit
	var pattern: String = look.get("pattern", "plain")
	if pattern == "dungarees":
		top = OUTFITS.cream if look.outfit != "cream" else OUTFITS.slate
	# Barrel body on a rounded base; the bottom 15 cm is a shade darker.
	Build.lathe(self, Vector3.ZERO, [[0.0, 0.0], [0.13, 0.0], [0.19, 0.04], [0.225, 0.14]], Color(outfit).darkened(0.13).to_html(false))
	Build.lathe(self, Vector3.ZERO, [[0.225, 0.14], [0.23, 0.26], [0.215, 0.36]], outfit)
	Build.lathe(self, Vector3.ZERO, [[0.215, 0.36], [0.19, 0.5], [0.15, 0.57], [0.08, 0.6], [0.0, 0.6]], top)
	var trim: String = PLAYER_TRIM[player % 4] if is_chef else OUTFITS.cream
	if is_chef:
		_band(0.15, 0.05, 0.228, trim)                       # jacket hem
		_band(0.53, 0.07, 0.2, trim)                         # neckerchief
		for i in 2:
			for sx: float in [-0.06, 0.06]:
				Build.ball(self, Vector3(sx, 0.3 + i * 0.12, 0.215 - i * 0.012), 0.024, trim)
	match pattern:
		"stripe":
			_band(0.2, 0.045, 0.232, trim)
			_band(0.32, 0.045, 0.228, trim)
			_band(0.44, 0.04, 0.208, trim)
		"collar":
			_band(0.52, 0.06, 0.19, trim)
		"apron":
			var apron := Build.box(self, Vector3(0, 0.12, 0.185), Vector3(0.3, 0.36, 0.1), OUTFITS.cream)
			apron.rotation.x = -0.06
		"dungarees":
			Build.box(self, Vector3(0, 0.33, 0.165), Vector3(0.2, 0.17, 0.1), outfit)
			for sx: float in [-0.1, 0.1]:
				Build.ball(self, Vector3(sx, 0.47, 0.19), 0.022, Build.WARN)
	for side: float in [-1.0, 1.0]:
		var hand := Node3D.new()
		add_child(hand)
		var mitt := Build.ball(hand, Vector3.ZERO, 0.075, skin)
		mitt.scale = Vector3(0.85, 1.0, 1.0)
		Build.ball(hand, Vector3(-side * 0.05, 0.03, 0.03), 0.032, skin)  # thumb
		hand.position = _hand_rest(side)
		_hands.append(hand)
	_head = Build.ball(self, Vector3(0, HEAD_Y, 0), HEAD_R, skin)
	_features = Node3D.new()
	_head.add_child(_features)
	var hair_col: String = HAIR_COLS[look.get("hair_col", "brown")]
	if not ["flat_cap", "beanie", "bobble"].has(look.get("hat", "")):  # these cover the hair
		_hair(look.get("hair", "bald"), hair_col)
	if is_chef:
		_toque(trim)
	elif look.has("hat"):
		_hat(look.hat)
	match look.get("extra", ""):
		"glasses":
			for sx: float in [-0.085, 0.085]:
				var pts: Array = []
				for i in 11:
					pts.append(Vector2(sx + cos(TAU * i / 10.0) * 0.05, -0.015 + sin(TAU * i / 10.0) * 0.05))
				_stroke(_head, pts, 0.011, "#2b2523")
			_stroke(_head, [Vector2(-0.035, -0.005), Vector2(0.035, -0.005)], 0.011, "#2b2523")
		"beard":
			var beard := Build.lathe(_head, Vector3.ZERO, _dome(HEAD_R + 0.02, 38.0), hair_col)
			beard.rotation.x = deg_to_rad(128.0)
	set_face("neutral")


func _band(y: float, h: float, r: float, col: String) -> void:
	Build.lathe(self, Vector3(0, y, 0), [[r - 0.01, 0.0], [r + 0.006, 0.01], [r + 0.006, h - 0.01], [r - 0.01, h]], col)


## A dome of a ball: from `from_deg` of latitude up to the pole.
static func _dome(r: float, from_deg: float, squash := 1.0) -> Array:
	var pts: Array = []
	for i in 9:
		var a := deg_to_rad(lerpf(from_deg, 90.0, i / 8.0))
		pts.append([snappedf(r * cos(a), 0.001), snappedf(r * sin(a) * squash, 0.001)])
	return pts


func _on_head(u: float, v: float, lift := 0.0) -> Vector3:
	var yaw := u / HEAD_R
	var pitch := v / HEAD_R
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * (HEAD_R + lift)


## A thick line drawn on the face, in metres across (u) and up (v) from its centre.
func _stroke(parent: Node3D, pts: Array, r: float, col: String) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var steps := maxi(1, ceili(a.distance_to(b) / (r * 0.9)))
		for s in steps + (1 if i == pts.size() - 2 else 0):
			var p := a.lerp(b, float(s) / steps)
			Build.ball(parent, _on_head(p.x, p.y, -r * 0.35), r, col)


func _hair(kind: String, col: String) -> void:
	var r := HEAD_R + 0.018
	var cap_from := 8.0
	var tilt := -32.0
	match kind:
		"bald":
			return
		"bob":
			cap_from = -30.0
			tilt = -46.0
		"side_swept", "wavy":
			tilt = -24.0
	var cap := Build.lathe(_head, Vector3.ZERO, _dome(r, cap_from), col)
	cap.rotation.x = deg_to_rad(tilt)
	match kind:
		"bob":
			Build.box(_head, Vector3(0, 0.13, 0.17), Vector3(0.34, 0.09, 0.12), col).rotation.x = -0.5
		"side_swept":
			var sweep := Build.ball(_head, Vector3(0.09, 0.2, 0.12), 0.13, col)
			sweep.scale = Vector3(1.3, 0.6, 1.0)
		"wavy":
			for i in 5:
				var a := TAU * i / 5.0
				Build.ball(_head, Vector3(cos(a) * 0.13, 0.22, sin(a) * 0.13 - 0.03), 0.1, col)
		"bun":
			Build.ball(_head, Vector3(0, 0.02, -0.29), 0.11, col)
		"top_knot":
			Build.ball(_head, Vector3(0, 0.33, -0.05), 0.12, col)
		"twin_buns":
			for sx: float in [-1.0, 1.0]:
				Build.ball(_head, Vector3(sx * 0.2, 0.26, -0.04), 0.11, col)
		"curls":
			for i in 9:
				var a := PI * (0.05 + 0.9 * i / 8.0) + PI
				Build.ball(_head, Vector3(cos(a) * 0.25, 0.02 + 0.06 * (i % 2), sin(a) * 0.25), 0.085, col)


func _hat(kind: String) -> void:
	var top := HEAD_R
	match kind:
		"flat_cap":
			var c := Build.lathe(_head, Vector3(0, top - 0.11, 0.0), _dome(0.285, 0.0, 0.5), "#6c6f63")
			c.rotation.x = 0.12
			Build.box(_head, Vector3(0, top - 0.105, 0.2), Vector3(0.3, 0.035, 0.2), "#5d6055").rotation.x = 0.2
		"beanie", "bobble":
			var col := "#4b79b8" if kind == "beanie" else "#8a5a7a"
			Build.lathe(_head, Vector3(0, 0.04, -0.01), _dome(HEAD_R + 0.035, 12.0, 1.04), col).rotation.x = -0.3
			var cuff := Build.lathe(_head, Vector3(0, 0.0, 0), [[0.285, 0.07], [0.305, 0.085], [0.3, 0.15], [0.275, 0.165]], Color(col).lightened(0.18).to_html(false))
			cuff.rotation.x = -0.3
			if kind == "bobble":
				Build.ball(_head, Vector3(0, 0.33, -0.1), 0.075, OUTFITS.cream)
		"sun_hat":
			Build.lathe(_head, Vector3(0, top - 0.13, 0), [[0.0, 0.0], [0.46, 0.0], [0.48, 0.02], [0.46, 0.04], [0.0, 0.04]], "#ead9a8")
			Build.lathe(_head, Vector3(0, top - 0.1, 0), _dome(0.23, 0.0, 0.72), "#ead9a8")
			_band_on(_head, top - 0.1, 0.235, 0.045, OUTFITS.plum)
		"bowler":
			Build.lathe(_head, Vector3(0, top - 0.1, 0), [[0.0, 0.0], [0.3, 0.0], [0.32, 0.015], [0.3, 0.03], [0.0, 0.03]], "#2b2a2e")
			Build.lathe(_head, Vector3(0, top - 0.08, 0), _dome(0.21, 0.0, 0.9), "#2b2a2e")
		"beret":
			var b := Build.lathe(_head, Vector3(0.03, top - 0.09, -0.02), [[0.0, 0.0], [0.2, 0.0], [0.29, 0.04], [0.27, 0.08], [0.12, 0.11], [0.0, 0.115]], "#7d55a6")
			b.rotation.z = -0.18
			Build.ball(_head, Vector3(0.01, top + 0.03, -0.02), 0.025, "#7d55a6")


static func _band_on(parent: Node3D, y: float, r: float, h: float, col: String) -> void:
	Build.lathe(parent, Vector3(0, y, 0), [[r - 0.01, 0.0], [r + 0.004, 0.008], [r + 0.004, h - 0.008], [r - 0.01, h]], col)


## The player's tall puffed toque: about a quarter taller than anyone else.
func _toque(trim: String) -> void:
	var y := HEAD_R - 0.1
	Build.lathe(_head, Vector3(0, y, 0), [[0.0, 0.0], [0.2, 0.0], [0.21, 0.01], [0.21, 0.19], [0.0, 0.19]], Build.CHEF_WHITE)
	_band_on(_head, y, 0.213, 0.07, trim)
	Build.lathe(_head, Vector3(0, y + 0.17, 0), [[0.0, 0.0], [0.19, 0.0], [0.27, 0.05], [0.29, 0.13], [0.25, 0.21], [0.15, 0.255], [0.0, 0.265]], Build.CHEF_WHITE)


# ---------------------------------------------------------------- faces

## Shows one of the eight faces from sheet 3. Strong moods tint the whole head.
func set_face(kind: String) -> void:
	if kind == face:
		return
	face = kind
	for c in _features.get_children():
		c.queue_free()
	var f := _features
	var ink := "#1f1512" if skin == SKINS[4] else INK
	var tint: Array = TINTS.get(kind, ["#ffffff", 0.0])
	_head.material_override = Build.mat(Color(skin).lerp(Color(tint[0]), tint[1]))
	var ex := 0.088
	var ey := -0.012
	# Blush cheeks never go away.
	for sx: float in [-1.0, 1.0]:
		var cheek := 0.062 if kind == "delighted" else 0.052
		Build.ball(f, _on_head(sx * 0.15, -0.085, -cheek + 0.007), cheek, BLUSH)
	var eye := func(sx: float, style: String) -> void:
		var c := Vector2(sx * ex, ey)
		match style:
			"dot":
				Build.ball(f, _on_head(c.x, c.y, -0.014), 0.036, ink)
			"arc":
				_stroke(f, [c + Vector2(-0.034, -0.012), c + Vector2(0, 0.014), c + Vector2(0.034, -0.012)], 0.014, ink)
			"squeeze":
				_stroke(f, [c + Vector2(-sx * 0.03, 0.028), c + Vector2(sx * 0.022, 0), c + Vector2(-sx * 0.03, -0.028)], 0.014, ink)
			"narrow":
				_stroke(f, [c + Vector2(-0.028, 0), c + Vector2(0.028, 0)], 0.02, ink)
	var brow := func(sx: float, inner: float, outer: float, r := 0.014) -> void:
		_stroke(f, [Vector2(sx * (ex - 0.045), ey + inner), Vector2(sx * (ex + 0.045), ey + outer)], r, ink)
	var mouth := func(pts: Array) -> void:
		_stroke(f, pts, 0.013, ink)
	var wavy := [Vector2(-0.045, -0.112), Vector2(-0.022, -0.1), Vector2(0, -0.112), Vector2(0.022, -0.1), Vector2(0.045, -0.112)]
	match kind:
		"neutral":
			eye.call(-1.0, "dot")
			eye.call(1.0, "dot")
			mouth.call([Vector2(-0.028, -0.1), Vector2(-0.014, -0.11), Vector2(0, -0.102), Vector2(0.014, -0.11), Vector2(0.028, -0.1)])
		"content":
			eye.call(-1.0, "arc")
			eye.call(1.0, "arc")
			mouth.call([Vector2(-0.04, -0.095), Vector2(-0.02, -0.112), Vector2(0.02, -0.112), Vector2(0.04, -0.095)])
		"delighted":
			for sx: float in [-1.0, 1.0]:
				eye.call(sx, "dot")
				Build.ball(f, _on_head(sx * ex + 0.012, ey + 0.014, 0.014), 0.011, "#ffffff")
				brow.call(sx, 0.07, 0.075, 0.011)
			Build.ball(f, _on_head(0, -0.11, -0.026), 0.046, ink)
			Build.ball(f, _on_head(0, -0.125, -0.012), 0.026, Build.CORAL)
		"impatient":
			for sx: float in [-1.0, 1.0]:
				eye.call(sx, "dot")
				brow.call(sx, 0.03, 0.03, 0.017)
			mouth.call([Vector2(-0.04, -0.105), Vector2(0.04, -0.105)])
		"snap":
			for sx: float in [-1.0, 1.0]:
				eye.call(sx, "dot")
				brow.call(sx, 0.022, 0.07, 0.017)
			mouth.call(wavy)
		"disgusted":
			for sx: float in [-1.0, 1.0]:
				eye.call(sx, "squeeze")
				brow.call(sx, 0.04, 0.06)
			mouth.call(wavy)
		"angry":
			for sx: float in [-1.0, 1.0]:
				eye.call(sx, "narrow")
				brow.call(sx, 0.02, 0.075, 0.021)
			mouth.call([Vector2(-0.045, -0.118), Vector2(-0.02, -0.1), Vector2(0.02, -0.1), Vector2(0.045, -0.118)])
		"chewing":
			eye.call(-1.0, "dot")
			eye.call(1.0, "arc")
			brow.call(-1.0, 0.06, 0.07, 0.012)
			Build.ball(f, _on_head(0.13, -0.09, -0.05), 0.075, skin)  # puffed cheek
			Build.ball(f, _on_head(0.16, -0.085, -0.02), 0.05, BLUSH)
			mouth.call([Vector2(-0.02, -0.108), Vector2(0.03, -0.108)])


# ---------------------------------------------------------------- hands

func _hand_rest(side: float) -> Vector3:
	return Vector3(side * 0.29, 0.3, 0.06)


func _hand_target(side: float) -> Vector3:
	match pose:
		"carry":
			return Vector3(side * 0.17, 0.4, 0.3)
		"eat":
			return Vector3(side * 0.16, 0.42 + maxf(0.0, sin(_age * 7.0 + side)) * 0.16, 0.27)
		"tap":  # an impatient drum on the table
			return Vector3(side * 0.2, 0.4 + absf(sin(_age * 16.0 + side * 0.8)) * 0.07, 0.28)
		"wave":
			if side > 0.0:
				return Vector3(0.36 + sin(_age * 9.0) * 0.07, 0.78, 0.05)
	return _hand_rest(side) + Vector3(0, sin(_age * 2.2 + side) * 0.012, 0)


func _process(delta: float) -> void:
	_age += delta
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_hands[i].position = _hands[i].position.lerp(_hand_target(side), 1.0 - exp(-14.0 * delta))
