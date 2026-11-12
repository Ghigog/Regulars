class_name Hud
extends CanvasLayer
## On-screen status, the day banner, and the end-of-day and game-over cards.

const INK := Color("#3a2c22")
const CREAM := Color("#fff6e6")
const CORAL := Color("#e56b5d")

var game
var root: Control
var day_label: Label
var day_bar: ProgressBar
var toast: Label
var money: Label
var strikes: Array[Panel] = []
var hint: Label
var banner: Label
var center: CenterContainer
var _shown_money := -1
var _toast_tween: Tween


func setup(game_) -> void:
	game = game_
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)

	var left := VBoxContainer.new()
	left.position = Vector2(24, 16)
	root.add_child(left)
	day_label = _label(left, 34)
	day_bar = ProgressBar.new()
	day_bar.custom_minimum_size = Vector2(240, 12)
	day_bar.show_percentage = false
	day_bar.max_value = 1.0
	left.add_child(day_bar)
	toast = _label(left, 17)

	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -264
	right.offset_right = -24
	right.offset_top = 16
	root.add_child(right)
	money = _label(right, 40)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	right.add_child(row)
	for i in Ledger.MAX_STRIKES:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(20, 20)
		row.add_child(dot)
		strikes.append(dot)

	hint = _label(root, 15)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 24
	hint.offset_top = -40
	hint.modulate.a = 0.7
	hint.text = "WASD move     E or Space use     M mute"

	banner = _label(root, 96)
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_outline_color", CREAM)
	banner.add_theme_constant_override("outline_size", 24)
	banner.modulate.a = 0.0

	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)


static func _flat(col: Color, radius: int, margin := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


func _theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("normal", "Button", _flat(CORAL, 12, 12))
	t.set_stylebox("hover", "Button", _flat(CORAL.lightened(0.12), 12, 12))
	t.set_stylebox("pressed", "Button", _flat(CORAL.darkened(0.15), 12, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_font_size("font_size", "Button", 20)
	t.set_stylebox("background", "ProgressBar", _flat(Color(INK, 0.2), 6))
	t.set_stylebox("fill", "ProgressBar", _flat(CORAL, 6))
	var card := _flat(CREAM, 22, 32)
	card.shadow_color = Color(0, 0, 0, 0.22)
	card.shadow_size = 18
	card.shadow_offset = Vector2(0, 6)
	t.set_stylebox("panel", "PanelContainer", card)
	return t


func _label(parent: Node, font_size: int, text := "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func update_status() -> void:
	var l: Ledger = game.ledger
	# After closing the books the ledger is already on tomorrow; keep showing the day just played.
	day_label.text = "Day %d" % (l.day - 1 if game.phase == game.Phase.SUMMARY else l.day)
	day_bar.value = game.day_progress()
	if l.money != _shown_money:
		if _shown_money >= 0 and l.money > _shown_money:
			money.pivot_offset = money.size * Vector2(1.0, 0.5)
			money.scale = Vector2(1.35, 1.35)
			money.create_tween().tween_property(money, "scale", Vector2.ONE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_shown_money = l.money
		money.text = "$%d" % l.money
	for i in strikes.size():
		var lost := i < l.strikes()
		strikes[i].add_theme_stylebox_override("panel", _flat(CORAL if lost else Color(INK, 0.18), 10))


func say(s: String) -> void:
	toast.text = s
	toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = toast.create_tween()
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.8)


func show_banner(s: String) -> void:
	banner.text = s
	banner.modulate.a = 0.0
	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(0.9)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)


func hide_card() -> void:
	for c in center.get_children():
		center.remove_child(c)
		c.queue_free()


func _card(title: String) -> VBoxContainer:
	hide_card()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_label(box, 40, title).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.pivot_offset = Vector2(220, 160)
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	return box


func _row(box: VBoxContainer, title: String, value: String, font := 22) -> Label:
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := _label(row, font, title)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _label(row, font, value)


func _button(box: VBoxContainer, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	box.add_child(b)


func show_summary(rec: Dictionary) -> void:
	var box := _card("Day %d done" % rec.day)
	_row(box, "Meals served", str(rec.served))
	_row(box, "Sales", "$%d" % rec.sales)
	_row(box, "Tips", "$%d" % rec.tips)
	_row(box, "Walkouts", str(rec.walkouts))
	box.add_child(HSeparator.new())
	var earned: int = rec.sales + rec.tips
	var total := _row(box, "Earned today", "$0", 30)
	total.create_tween().tween_method(func(v: float) -> void: total.text = "$%d" % roundi(v), 0.0, float(earned), 0.9) \
		.set_delay(0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_row(box, "In the bank", "$%d" % game.ledger.money)
	var gossip := _label(box, 16, game.town.headline())
	gossip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gossip.modulate.a = 0.75
	_button(box, "Open for day %d   (Enter)" % game.ledger.day, game.start_day)


func show_closed(days: int, earned: int, best: Dictionary, is_record: bool) -> void:
	var box := _card("Closed down")
	var why := _label(box, 17, "Three guests walked out in one day.")
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.modulate.a = 0.75
	_row(box, "Days survived", str(days), 26)
	_row(box, "Total earned", "$%d" % earned, 26)
	box.add_child(HSeparator.new())
	if is_record:
		_label(box, 22, "New best run!").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_row(box, "Best run", "%d days, $%d" % [best.days, best.earned], 18)
	_button(box, "Try again   (Enter)", game.restart)
