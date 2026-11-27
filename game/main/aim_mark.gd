class_name GameAimMark
extends RefCounted
## The faint mark on the spot a chef is pointing at while Aim or Reach is held: the same cell
## `Player.target_cell()` (service) or the card's piece in front (build) gives, so it never
## disagrees with what E will do. Quieter than the station cursor; it only draws, never decides.

const SIZE := 0.35        # of a cell
const ALPHA := 0.4
const FADE := 0.12        # seconds to fade and scale in; out about as fast
const GLIDE := 18.0       # exponential smoothing rate towards a new cell
const FLOOR_Y := 0.04

var game: Game


func _init(game_: Game) -> void:
	game = game_


## True when this chef should be shown pointing: Aim or Reach held, in a phase and state where it means something.
func wanted(ch: Player) -> bool:
	if not (ch.aiming or ch.get_meta("aim", false) or game.card.reaching(ch)):
		return false
	if not (game.phase == Game.Phase.SERVICE or (game.phase == Game.Phase.BUILD and game.shopper != ch)):
		return false
	if ch.aim_mouse or ch.give_t > 0.0 or ch.demo_giving >= 0.0:
		return false
	if game.hud.bill_open() and game.hud.bill.chef == ch:
		return false
	if game.floor_dirt.is_down(ch) or game.floor_dirt.helping(ch) != null:
		return false
	return true


## The cell the chef points at.
func cell_of(ch: Player) -> Vector2i:
	if game.phase == Game.Phase.SERVICE:
		return ch.target_cell()
	var p: Vector3 = game.room_edit._piece_in_front(ch)
	return Grid.to_cell(p) if p != Vector3.INF else ch.cell() + ch.facing


## Where the mark rests: the middle of the cell, at floor level or at wall-shelf height while reaching.
func goal(ch: Player) -> Vector3:
	var y := BuildStations.HIGH_Y0 + 0.2 if game.card.reaching(ch) else FLOOR_Y
	return Grid.center(cell_of(ch)) + Vector3(0, y, 0)


func update(ch: Player, delta := -1.0) -> void:
	if delta < 0.0:
		delta = game.get_process_delta_time()
	_rebuild(ch)
	var amt: float = ch.aim_mark.get_meta("amt")
	var on := wanted(ch)
	var was := amt
	amt = move_toward(amt, 1.0 if on else 0.0, delta / FADE)
	ch.aim_mark.set_meta("amt", amt)
	ch.aim_mark.visible = amt > 0.0
	if not on and amt <= 0.0:
		return
	if on:
		var to := goal(ch)
		ch.aim_mark.position = to if was <= 0.0 else ch.aim_mark.position.lerp(to, 1.0 - exp(-GLIDE * delta))
	ch.aim_mark.scale = Vector3.ONE * lerpf(0.6, 1.0, amt)
	(ch.aim_mark.get_child(0) as MeshInstance3D).transparency = 1.0 - amt


## Built again only when the chef's trim or the number of chefs changes, as the station cursor is.
func _rebuild(ch: Player) -> void:
	var key := "%d:%d" % [ch.trim, game.chefs.size()]
	if ch.aim_mark and ch.aim_mark.get_meta("key") == key:
		return
	var at := ch.aim_mark.position if ch.aim_mark else Vector3.ZERO
	var amt: float = ch.aim_mark.get_meta("amt") if ch.aim_mark else 0.0
	if ch.aim_mark:
		ch.aim_mark.queue_free()
	ch.aim_mark = Node3D.new()
	ch.aim_mark.set_meta("key", key)
	ch.aim_mark.set_meta("amt", amt)
	ch.aim_mark.position = at
	ch.aim_mark.visible = false
	var col: String = Build.WARN if game.chefs.size() == 1 else Peg.PLAYER_TRIM[ch.trim % 4]
	var m := MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(SIZE, 0.02, SIZE)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col, ALPHA)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true   # floor level is inside a counter: show through it, faintly
	m.material_override = mat
	m.transparency = 1.0 - amt
	ch.aim_mark.add_child(m)
	game.add_child(ch.aim_mark)
