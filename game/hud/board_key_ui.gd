class_name HudBoardKey
extends RefCounted
## The menu board's glow and its key: a prompt-sized keycap just above the board, the
## chef prompt's key sheet, holding whatever is bound to "menu" on the first player's
## device, while the board itself glows (MenuBoard.update_glow). They show in the build
## phase only, pulse slowly and warmly (brighter while tonight's menu has no main), and
## swells once, hard, when the door card refuses for want of a main.

const BRIGHT := 1.0
const DIM := 0.5
const FOOT := Vector3(0, 0.45, 0)   # the board's top edge

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
	cap = HudWidgets.Sheet.new("key", 13, 4).pad(13, 1, 13, 7)
	cap.visible = false
	hud.root.add_child(cap)
	hud.root.move_child(cap, 0)   # world marker: every panel and screen draws over it
	label = hud._label(cap, 24, "N")


## Called every frame from Game._process.
func update() -> void:
	var game: Game = hud.game
	if not _built:
		_build()
	var show: bool = game.phase == Game.Phase.BUILD and hud.options_ui.title == null and game.menu_board != null
	cap.visible = show
	var no_main: bool = not Menu.has_main(game.menu_stock.tonight_menu())
	if game.menu_board != null:
		game.menu_board.update_glow(show, no_main)
	if not show:
		return
	var glyph: String = game.controls.glyph("menu") if game.controls != null else "N"
	if label.text != glyph:
		label.text = glyph
		cap.reset_size()
	var want := no_main
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
