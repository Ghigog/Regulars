class_name HudPrepKey
extends RefCounted
## The Use key beside a prep minigame's gauge, one keycap per chef playing one: the chef
## prompt's key sheet holding that chef's Use glyph (E, A or the touch word). It moves the way
## the minigame wants pressing (GamePrepGames.key_cue): tap tools press down once when the
## press is wanted, mash tools bounce, hold tools sit pushed down with a "hold" bar under
## them while Use is held and spring up with a warm pop when the fill is in its band.
## A real press dents it. Auto pieces play themselves and show no key.

const DENT := Vector2(0.9, 0.9)
const FOOT := Vector3(0.95, 1.85, 0)   # beside the gauge, on the camera's right of it

var hud: Hud
var caps := {}   # chef index -> {"cap", "label", "bar", "tween", "cue", "sig", "shown"}


func _init(hud_: Hud) -> void:
	hud = hud_


func _make(p: int) -> Dictionary:
	var cap := HudWidgets.Sheet.new("key", 13, 4).pad(13, 1, 13, 7)
	cap.modulate.a = 0.0
	hud.root.add_child(cap)
	hud.root.move_child(cap, 0)   # world marker: every panel and screen draws over it
	var label: Label = hud._label(cap, 24, "E")
	var bar := ColorRect.new()   # the "hold" bar under a cap that is held down
	bar.color = Color(Hud.INK)
	bar.size = Vector2(26, 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	cap.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -3
	bar.offset_bottom = -1
	var d := {"cap": cap, "label": label, "bar": bar, "tween": null, "cue": "", "sig": -1, "shown": false}
	caps[p] = d
	return d


## Called every frame from Game._process.
func update() -> void:
	var game: Game = hud.game
	for p: int in caps.keys():
		if not game.preps.has(p) or game.prep_games.key_cue(p) == "":
			_fade(caps[p], false)
	for p: int in game.preps.keys():
		var cue := game.prep_games.key_cue(p)
		if cue == "":
			continue
		var d: Dictionary = caps.get(p, {})
		if d.is_empty():
			d = _make(p)
		_place(game, p, d)
		_fade(d, true)
		if cue != d.cue:
			_cue(d, cue)
		var sig := _press_sig(game.preps[p], game.controls.holding(p, "use"))
		if d.sig != -1 and sig != d.sig:
			_dent(d)
		d.sig = sig


## A number that changes with every real press of Use, for the dent.
func _press_sig(s: Dictionary, holding: bool) -> int:
	return int(s.hits.size()) * 4 + int(s.presses) * 8 + (1 if holding else 0) + (2 if s.get("lift", false) else 0)


func _place(game: Game, p: int, d: Dictionary) -> void:
	var cap: Control = d.cap
	var glyph: String = game.controls.glyph("use", p)
	if d.label.text != glyph:
		d.label.text = glyph
		cap.reset_size()
	var st: Station = game.preps[p].st
	var at := game.cam.unproject_position(st.global_position + FOOT)
	cap.pivot_offset = cap.size / 2.0
	cap.position = (at - cap.size / 2.0).round()
	cap.position.y = maxf(cap.position.y, 6.0)


func _fade(d: Dictionary, on: bool) -> void:
	if d.shown == on:
		return
	d.shown = on
	if not on:
		d.cue = ""
		d.sig = -1
	var cap: Control = d.cap
	var t: Tween = cap.create_tween()
	t.tween_property(cap, "modulate:a", 1.0 if on else 0.0, 0.15)
	if d.tween != null and not on:
		(d.tween as Tween).kill()
		d.tween = null
		cap.scale = Vector2.ONE
		cap.modulate = Color(1, 1, 1, cap.modulate.a)


func _cue(d: Dictionary, cue: String) -> void:
	var cap: Control = d.cap
	if d.tween != null:
		(d.tween as Tween).kill()
	d.tween = null
	d.cue = cue
	cap.scale = Vector2.ONE
	cap.rotation = 0.0
	cap.modulate = Color(1, 1, 1, cap.modulate.a)
	d.bar.visible = cue == "hold"
	var held: bool = cue == "hold"
	d.label.position.y = 3.0 if held else 0.0
	match cue:
		"tap":   # one sharp press, then still
			var t := cap.create_tween()
			t.tween_property(cap, "scale", Vector2(0.88, 0.8), 0.06)
			t.tween_property(cap, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			d.tween = t
		"mash":   # quick, continuous bouncing
			var t := cap.create_tween().set_loops()
			t.tween_property(cap, "scale", Vector2(0.9, 0.78), 0.07)
			t.tween_property(cap, "scale", Vector2(1.04, 1.08), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			d.tween = t
		"release":   # springs up with a warm pop: let go / keep it here
			var t := cap.create_tween()
			t.tween_property(cap, "scale", Vector2(1.3, 1.3), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(cap, "modulate", Color(1.25, 1.1, 0.7, cap.modulate.a), 0.08)
			t.tween_property(cap, "scale", Vector2(1.08, 1.08), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			d.tween = t
		"hold":
			cap.scale = Vector2(0.94, 0.9)
		_:
			pass


## The real press took: the cap dents for a moment.
func _dent(d: Dictionary) -> void:
	var cap: Control = d.cap
	if d.cue in ["mash", "release"]:
		return   # they are moving already
	var base := Vector2(0.94, 0.9) if d.cue == "hold" else Vector2.ONE
	var t := cap.create_tween()
	t.tween_property(cap, "scale", DENT, 0.04)
	t.tween_property(cap, "scale", base, 0.04)
