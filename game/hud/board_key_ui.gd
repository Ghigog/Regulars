class_name HudBoardKey
extends RefCounted
## The big glowing key over the menu board: a keycap in the style of the chef's prompt,
## holding whatever is bound to "menu" on the first player's device. It shows in the build
## phase only, pulses slowly and warmly (brighter while tonight's menu has no main), and
## swells once, hard, when the door card refuses for want of a main.

const BRIGHT := 1.0
const DIM := 0.5
const FOOT := Vector3(0, 0.8, 0)   # above the board's slate

var hud: Hud
var cap: HudWidgets.Sheet
var label: Label
var bright := true             # no main on tonight's menu yet
var _tween: Tween
var _swell: Tween
var _built := false


func _init(hud_: Hud) -> void:
	hud = hud_


func _build() -> void:
	_built = true
	cap = HudWidgets.Sheet.new("key", 20, 6).pad(26, 4, 26, 14)
	cap.visible = false
	hud.root.add_child(cap)
	label = hud._label(cap, 58, "N")


## Called every frame from Game._process.
func update() -> void:
	var game: Game = hud.game
	if not _built:
		_build()
	var show: bool = game.phase == Game.Phase.BUILD and hud.options_ui.title == null and game.menu_board != null
	cap.visible = show
	if not show:
		return
	var glyph: String = game.controls.glyph("menu") if game.controls != null else "N"
	if label.text != glyph:
		label.text = glyph
		cap.reset_size()
	var want: bool = not Menu.has_main(game.menu_stock.tonight_menu())
	if _tween == null or want != bright:
		bright = want
		_start_pulse()
	var at := game.cam.unproject_position(game.menu_board.global_position + FOOT)
	cap.pivot_offset = cap.size / 2.0
	cap.position = (at - Vector2(cap.size.x / 2.0, cap.size.y)).round()
	cap.position.y = maxf(cap.position.y, 6.0)


func _start_pulse() -> void:
	if _tween:
		_tween.kill()
	var hi := BRIGHT if bright else 0.8
	var lo := 0.62 if bright else DIM
	cap.modulate.a = hi
	_tween = cap.create_tween().set_loops()   # slow in, slow out, like the door card's halo
	_tween.tween_property(cap, "modulate", Color(1, 1, 1, lo), 1.0).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(cap, "modulate", Color(1.15, 1.05, 0.9, hi), 1.0).set_trans(Tween.TRANS_SINE)


## One hard, quick swell and settle: the card would not flip for want of a main.
func pulse() -> void:
	if not _built:
		_build()
	if _swell:
		_swell.kill()
	cap.pivot_offset = cap.size / 2.0
	cap.scale = Vector2.ONE
	_swell = cap.create_tween()
	_swell.tween_property(cap, "scale", Vector2(1.35, 1.35), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swell.tween_property(cap, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
