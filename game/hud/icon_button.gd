class_name IconButton
extends Control
## A cream paper disc on a wood rim with an ink icon, and a keycap tab (the head
## prompt's keycap) that names the key on desktop and pad. On touch there is no tab
## and the disc is thumb-sized. Hud and Controls own where it sits and what it does.

signal pressed

const REACH := 64.0       ## disc width with a keyboard or pad
const THUMB := 88.0       ## disc width on touch, as Controls.BTN_R discs
const SINK := 3.0         ## how far a press pushes the disc down
const RIM := 5.0

var icon_id := ""
var badge := ""
var blocked := false
var touch := false
## A disc of another width (the touch Use button is bigger); 0 keeps the usual one.
var span := 0.0
## A face colour other than paper (the touch Use button is coral); transparent keeps paper.
var face := Color(0, 0, 0, 0)
## Pressed down by something other than a click: a finger held on it.
var held := false
## Plays a named sound; the owner binds it to `game.audio.sfx`. Silent when unset.
var sfx := Callable()

var _key: HudWidgets.Sheet
var _key_label: Label
var _down := false
var _rest := Vector2.ZERO
var _tween: Tween


func _init(icon_id_ := "", key_text := "") -> void:
	icon_id = icon_id_
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_key = HudWidgets.Sheet.new("key", 8, 2).pad(8, 0, 8, 3)
	_key_label = Label.new()
	_key_label.add_theme_font_override("font", Hud.lettering())
	_key_label.add_theme_font_size_override("font_size", 18)
	_key_label.add_theme_color_override("font_color", Hud.INK)
	_key.add_child(_key_label)
	add_child(_key)
	_key.resized.connect(_place_key)
	resized.connect(_place_key)
	set_key(key_text)
	_fit()


func set_key(text: String) -> void:
	_key_label.text = text
	_key.visible = text != "" and not touch
	_place_key()


func set_touch(on: bool) -> void:
	touch = on
	_key.visible = _key_label.text != "" and not touch
	_fit()


func set_badge(text: String) -> void:
	badge = text
	queue_redraw()


func set_blocked(on: bool) -> void:
	blocked = on
	queue_redraw()


func set_icon(id: String) -> void:
	icon_id = id
	queue_redraw()


## Whether the keycap tab shows.
func key_shown() -> bool:
	return _key.visible


func set_held(on: bool) -> void:
	if on != held:
		held = on
		_place_key()
		queue_redraw()


func disc_width() -> float:
	if span > 0.0:
		return span
	return THUMB if touch else REACH


func show_in() -> void:
	if visible and _tween == null:
		return
	_stop_tween()
	_rest = position if not visible else _rest
	visible = true
	position = _rest + Vector2(0, 90)
	_play("rustle")
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", _rest, 0.3)


func hide_out() -> void:
	if not visible:
		return
	if _tween == null:
		_rest = position
	_stop_tween()
	_play("tick")
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "position", _rest + Vector2(0, 90), 0.22)
	_tween.tween_callback(func() -> void:
		visible = false
		position = _rest)


func _stop_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null


func _play(id: String) -> void:
	if sfx.is_valid():
		sfx.call(id)


## The control is the disc plus the lower half of the keycap that straddles its foot.
func _fit() -> void:
	var d := disc_width()
	custom_minimum_size = Vector2(d, d + 12.0)
	size = custom_minimum_size
	_place_key()
	queue_redraw()


func _place_key() -> void:
	var d := disc_width()
	var ks := _key.get_combined_minimum_size()
	_key.size = ks
	_key.position = Vector2((size.x - ks.x) / 2.0, d - ks.y * 0.5 + (SINK if _down or held else 0.0) - 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_play("thump")
		else:
			var was := _down
			_down = false
			if was and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()   # a blocked button still says so: its owner shows why
		_place_key()
		queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_VISIBILITY_CHANGED:
		if _down:
			_down = false
			_place_key()
			queue_redraw()


func _draw() -> void:
	var d := disc_width()
	var r := d / 2.0
	var c := Vector2(size.x / 2.0, r + (SINK if _down or held else 0.0))
	var fade := 0.5 if blocked else 1.0
	draw_circle(Vector2(c.x, r + 5.0), r, Color(Hud.SHADOW, Hud.SHADOW.a * fade))   # sits on the board
	draw_circle(c, r, Hud.INK)
	draw_circle(c, r - 2.0, Hud.WOOD.darkened(0.14))
	draw_circle(c - Vector2(0, 1), r - 3.0, Hud.WOOD)                                  # the wood rim
	var cream := face if face.a > 0.0 else Hud.CREAM
	if _down or held:
		cream = cream.darkened(0.15)
	draw_circle(c, r - RIM, Color(Hud.INK, 0.6))
	draw_circle(c, r - RIM - 1.5, Color(cream, fade) if not blocked else Color(cream.darkened(0.2), 1.0))
	var ink_r := (r - RIM) * 0.52
	var lift := Vector2(0, -4.0 if badge != "" else 0.0)
	for l: Array in Icons.icon(icon_id):
		var pts := PackedVector2Array()
		for p: Vector2 in l[0]:
			pts.append(c + lift + Vector2(p.x, -p.y) * ink_r)
		var col := Color(l[1])
		if blocked:
			col = col.lerp(Color("#b3aba0"), 0.6)
		draw_colored_polygon(pts, col)
	if badge != "":
		var font: Font = Hud.lettering()
		var fs := 18
		var w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, c + Vector2(-w / 2.0, r - RIM - 6.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Hud.INK, fade) if not blocked else Color(Hud.INK, 0.5))
