class_name HudScreens
extends RefCounted
## Whole screens over the room: the upgrade tree, the town book and the closed notice.

var hud: Hud


func _init(hud_: Hud) -> void:
	hud = hud_


## The upgrade tree of the piece in the shopper's hand, on blueprint paper, instead
## of the shop (PRD 8.3).
func show_tree(key: String) -> void:
	if hud._tree:
		return
	hud.build_bar.visible = false
	var p: int = maxi(hud.game.chefs.find(hud.game.shopper), 0)
	var keys := "%s buy      %s choose      %s %s" % [hud._g("use", p), "D-pad" if hud._mode(p) == "pad" else "Arrows", hud._g("back", p),
		"back to the card" if hud.game.card.storing() else "close"]
	if hud.game.shopper != null and hud.game.shopper.hand.get("node") is Station:   # the piece in hand turns
		keys += "      %s turn" % hud._g("turn", p)
	if hud._mode(p) == "touch":
		keys = "Tap a step, then tap it again to buy"
	hud._tree = TreeScreen.new(hud.game, hud, key, keys)
	hud.root.add_child(hud._tree)
	hud.root.move_child(hud._tree, hud.center.get_index())


func hide_tree() -> void:
	if hud._tree == null:
		return
	var t := hud._tree
	hud._tree = null
	var tw := t.create_tween()
	tw.tween_property(t, "position:y", TreeScreen.DROP, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(t.queue_free)
	if hud.build_bar:
		hud.build_bar.visible = true


func tree_open() -> bool:
	return hud._tree != null


## The node chosen on the open tree ("" when shut).
func tree_selected() -> String:
	return hud._tree.selected if hud._tree else ""


func tree_move(action: String) -> void:
	if hud._tree:
		hud._tree.move(action)


func tree_buy() -> void:
	if hud._tree:
		hud._tree.buy()
	else:
		hud.game.audio.sfx("fail")


func toggle_town() -> void:
	if hud._town_open:
		hud.receipt_ui.show_summary(hud.game.last_day)
	else:
		show_town()


## The town book: every townsperson, where they stand and whether today moved them.
func show_town() -> void:
	hud.receipt_ui.hide_card()
	hud._town_open = true
	var clip := HudWidgets.Sheet.new("clip").pad(26, 46, 26, 26)
	hud.center.add_child(clip)
	hud._summary_clip = clip
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	clip.add_child(stack)
	var page := HudWidgets.Sheet.new("note").pad(26, 24, 26, 20)
	hud.receipt_ui.paper_box(clip, stack).add_child(page)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	page.add_child(box)
	hud.receipt_ui._ribbon(box, "THE TOWN", Hud.INK)
	var town: Town = hud.game.town
	var cols := GridContainer.new()
	var ncol := 2 if town.people.size() <= 16 else 3
	cols.columns = ncol
	cols.add_theme_constant_override("h_separation", 24)
	cols.add_theme_constant_override("v_separation", 2 if ncol > 2 else 7)
	box.add_child(cols)
	# Fill down the columns, not across.
	var rows := ceili(town.people.size() / float(ncol))
	for n in rows * ncol:
		var i := (n / ncol) + rows * (n % ncol)
		if i >= town.people.size():
			cols.add_child(Control.new())
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		cols.add_child(_pressable(row, i))
		var name_label := hud._label(row, 18 if ncol == 2 else 15, town.people[i].name)
		name_label.custom_minimum_size = Vector2(86 if ncol == 2 else 78, 0)
		if hud.game.critic.known and i == hud.game.critic.critic_idx:   # after the first review only
			var quill := HudWidgets.Icon.new("quill", 20, false)   # inside the name's column, so the pips stay in line
			quill.position = Vector2(name_label.get_minimum_size().x + 4, 2)
			name_label.add_child(quill)
		row.add_child(HudWidgets.Pips.new(town.standing(i) + 1, town.trend(i)))
		var word := hud._label(row, 13 if ncol == 2 else 11, town.status_word(i, hud.game.ledger.day))
		word.custom_minimum_size = Vector2(150 if ncol == 2 else 118, 0)
		word.modulate.a = 0.7
		for part in row.get_children():   # the wrapper takes the pointer, not the parts
			(part as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.receipt_ui._rule(box)
	var key := hud._label(box, 13, "Arrows show who changed their mind today. Friends talk to each other.")
	key.modulate.a = 0.7
	if not hud.game.critic.last_review.is_empty():
		hud.receipt_ui._button(stack, "Last review: %d %s" % [int(hud.game.critic.last_review.stars),
			"star" if int(hud.game.critic.last_review.stars) == 1 else "stars"], hud.receipt_ui.show_review)
	hud.receipt_ui._button(stack, "Back   (T)", toggle_town)
	hud.receipt_ui._fit_when_laid_out(hud.receipt_ui.paper_scroll)
	hud.receipt_ui._pop_in(clip)


## `row` in a control that opens person `i`'s page on a click or tap, with a faint ink band
## behind it while the pointer is over it. Not focusable, so Enter still means carry on.
func _pressable(row: Control, i: int) -> Control:
	var hit := MarginContainer.new()
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.focus_mode = Control.FOCUS_NONE
	var band := ColorRect.new()
	band.color = Color(Hud.INK, 0.1)
	band.visible = false
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.add_child(band)
	hit.add_child(row)
	hit.mouse_entered.connect(band.show)
	hit.mouse_exited.connect(band.hide)
	hit.gui_input.connect(func(event: InputEvent) -> void:
		var released: bool = (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and not event.pressed)
		if released and hit.is_inside_tree() and not hit.has_meta("opened"):
			hit.set_meta("opened", true)   # a tap can arrive as both a touch and a mouse event
			show_person(i))
	return hit


## One townsperson's own page, on the same clipboard: who they are, how they feel about
## the place and what they order. Never their tastes (DESIGN.md: only what they order).
func show_person(i: int) -> void:
	var game: Game = hud.game
	var town: Town = game.town
	hud.receipt_ui.hide_card()
	hud._town_open = true   # T still closes the book back to the receipt
	game.audio.sfx("tick")
	var clip := HudWidgets.Sheet.new("clip").pad(26, 46, 26, 26)
	hud.center.add_child(clip)
	hud._summary_clip = clip
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	clip.add_child(stack)
	var page := HudWidgets.Sheet.new("note").pad(26, 24, 26, 20)
	hud.receipt_ui.paper_box(clip, stack).add_child(page)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	page.add_child(box)
	var who: String = town.people[i].name
	hud.receipt_ui._ribbon(box, who, Hud.INK)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	box.add_child(head)
	var face := HudWidgets.ModelView.new(110, false)
	head.add_child(face)
	face.show_peg(who)
	var words := VBoxContainer.new()
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 6)
	head.add_child(words)
	if game.critic.known and i == game.critic.critic_idx:
		var sign := HBoxContainer.new()
		sign.add_theme_constant_override("separation", 6)
		words.add_child(sign)
		sign.add_child(HudWidgets.Icon.new("quill", 22, false))
		hud._label(sign, 19, "Critic")
	var mood := HBoxContainer.new()
	mood.add_theme_constant_override("separation", 10)
	words.add_child(mood)
	mood.add_child(HudWidgets.Pips.new(town.standing(i) + 1, town.trend(i)))
	hud._label(mood, 17, town.status_word(i, game.ledger.day))
	hud._label(words, 15, "Visits so far: %d" % int(town.people[i].visits)).modulate.a = 0.8
	var lines: Array[String] = []
	if town.friend_names(i) != "":
		lines.append("Friends: " + town.friend_names(i))
	if town.order_summary(i, game.menu) != "":
		lines.append("Orders: " + town.order_summary(i, game.menu))
	for line in lines:
		var l := hud._label(box, 15, line)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
	if town.expects_deal(i):
		hud._label(box, 15, "Expects a deal").add_theme_color_override("font_color", Color(Build.CORAL_DARK))
	hud.receipt_ui._button(stack, "Back", show_town)
	hud.receipt_ui._fit_when_laid_out(hud.receipt_ui.paper_scroll)
	hud.receipt_ui._pop_in(clip)


## Game over: a folded, coral-trimmed menu card.
func show_closed(days: int, earned: int, best: Dictionary, is_record: bool) -> void:
	hud.receipt_ui.hide_card()
	var menu := HudWidgets.Sheet.new("menu").pad(40, 34, 40, 40)
	menu.custom_minimum_size = Vector2(480, 0)
	hud.center.add_child(menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	menu.add_child(box)
	hud.receipt_ui._ribbon(box, "CLOSED DOWN", Hud.INK)
	var why := hud._label(box, 17, "The town's opinion hit rock bottom: nobody will come.")
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.modulate.a = 0.75
	hud.receipt_ui._ornament(box, "day")
	hud.receipt_ui._centred(box, "DAYS SURVIVED: %d" % days)
	hud.receipt_ui._ornament(box, "coin")
	hud.receipt_ui._centred(box, "TOTAL EARNED: $%d" % earned)
	hud.receipt_ui._ornament(box, "star")
	hud.receipt_ui._centred(box, "NEW BEST RUN!" if is_record else "BEST RUN: %d %s" % [best.days, "DAY" if best.days == 1 else "DAYS"])
	hud.receipt_ui._button(box, "Try again" + hud.hints_ui._key_note("confirm"), hud.game.day.restart)
	hud.receipt_ui._pop_in(menu)
