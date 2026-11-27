class_name HudHints
extends RefCounted
## Hints: co-op ready marks, key notes, the build bar (show_build: the cleaning note, the
## restock note and the lifted piece's strip of choices) and the shop's key line.

var hud: Hud


func _init(hud_: Hud) -> void:
	hud = hud_


# ---------------------------------------------------------------- co-op (PRD 4)

## The receipt's and the door card's ready markers, from the game's ready list.
func refresh_ready() -> void:
	var states: Array[String] = hud.game.coop.ready_states()
	var coop: bool = hud.game.chefs.size() > 1
	if hud._ready_row and is_instance_valid(hud._ready_row):
		_fill_ready(hud._ready_row, states, 30)
		hud._ready_row.visible = coop
	for c in hud._door_ready_row.get_children():
		c.queue_free()
	var any: bool = coop and hud.game.ready_chefs.size() > 0 and hud.game.phase in [hud.game.Phase.BUILD, hud.game.Phase.SERVICE]
	hud._door_ready.visible = any
	if any:
		_fill_ready(hud._door_ready_row, states, 24)
		hud._door_ready.reset_size()


func _fill_ready(row: HBoxContainer, states: Array[String], px: float) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	for p in states.size():
		row.add_child(HudWidgets.ChefTag.new(p, px, states[p]))


## Keeps the door card's ready markers over the card (a point on screen).
func place_door_ready(at: Vector2) -> void:
	if hud._door_ready.visible:
		hud._door_ready.position = (at - Vector2(hud._door_ready.size.x / 2.0, 0.0)).round()


## "   (Enter)" after a button's words; nothing on touch, where it is tapped.
func _key_note(action: String) -> String:
	return "" if hud._mode() == "touch" or hud._g(action) == "" else "   (%s)" % hud._g(action)


func _shop_keys_text() -> String:
	if hud.game.card.storing():   # a piece's card: only E and Back (review, item 4)
		match hud._mode():
			"pad":
				return "A choose      D-pad browse      B back"
			"touch":
				return "Tap a card, then tap it again"
		return "E choose      Arrows browse      Esc back"
	match hud._mode():
		"pad":
			return "A buy      D-pad browse      B close"
		"touch":
			return "Tap a piece, then tap it again to buy"
	return "E buy      Tab close"


## Redraws every hint for a new device: the prompt's keycap, the strip and the shop's key line.
func refresh_input() -> void:
	hud._prompt_key.visible = hud._mode() != "touch"
	hud._prompt_key_label.text = hud._g("use")
	if hud._shop_keys:
		hud._shop_keys.text = _shop_keys_text()
	if hud.build_bar:
		show_build()
	if hud.options_ui._options_card:
		hud.options_ui._show_options_tab(hud.options_ui._options_tab)
	if hud.options_ui.title:
		hud.options_ui.title.refresh()


## The build phase: the notes and the lifted piece's strip sit along the bottom. The
## shop (show_shop) slides up over it. Later calls only redraw.
func show_build() -> void:
	if hud.build_bar == null:
		var holder := MarginContainer.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_theme_constant_override("margin_bottom", 16)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.root.add_child(holder)
		hud.root.move_child(holder, hud.center.get_index())
		hud.build_bar = holder
		var stack := VBoxContainer.new()
		stack.size_flags_vertical = Control.SIZE_SHRINK_END
		stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.alignment = BoxContainer.ALIGNMENT_END
		stack.add_theme_constant_override("separation", 6)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(stack)
		hud.menu_notes = MenuScreen.BuildNotes.new(hud.game, hud)
		stack.add_child(hud.menu_notes)
		stack.move_child(hud.menu_notes, 0)
		hud._strip = VBoxContainer.new()
		hud._strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hud._strip.add_theme_constant_override("separation", 6)
		hud._strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(hud._strip)
		holder.modulate.a = 0.0
		holder.create_tween().tween_property(holder, "modulate:a", 1.0, 0.3)
		hud.game.audio.sfx("rustle")
	hud.build_bar.visible = hud._shop == null
	_fill_strip()
	hud.menu_notes.refresh()
	hud.shop_ui._refresh_catalog()


## The lifted piece's strip (one row a chef who has one): a chip for each upgrade it can
## take now and each box it carries, the chosen one raised, its blurb and keys under it.
func _fill_strip() -> void:
	for c in hud._strip.get_children():
		hud._strip.remove_child(c)
		c.queue_free()
	var n: int = hud.game.chefs.size()
	for p in n:
		var ch: Player = hud.game.chefs[p]
		var list: Array[Dictionary] = hud.game.upgrades.strip_choices(ch)
		if list.is_empty():
			continue
		var chosen: Dictionary = hud.game.upgrades.strip_chosen(ch)
		var sheet := HudWidgets.Sheet.new("paper", 16, 8)
		sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hud._strip.add_child(sheet)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		sheet.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		box.add_child(head)
		if n > 1:
			head.add_child(HudWidgets.ChefTag.new(p))
		hud._label(head, 18, "Upgrades for the %s" % hud.game.placing.piece_name(ch.hand).to_lower()).modulate = Color(Hud.INK, 0.7)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		for i in list.size():
			row.add_child(_strip_chip(ch, i, list[i], list[i] == chosen))
		var m := hud._mode(p)
		var keys := ""
		var act := "take out" if chosen.kind == "box" else "buy"
		if m == "touch":
			keys = "Tap a card, tap it again to %s" % act
		else:
			keys = "%s %s choose      %s %s" % [hud._g("prev", p), hud._g("next", p), hud._g("buy", p), act]
		var what := ""
		if chosen.kind == "box":
			what = "Stocked every night for $%d. Take it out to stop that." % _box_fee(chosen.id)
		else:
			what = Upgrades.blurb(chosen.key)
		hud._label(box, 18, "%s      %s" % [what, keys])


func _box_fee(id: String) -> int:
	if Treatments.is_box(id):
		return int(Treatments.ITEMS[Treatments.key_of(id)].fee)
	return Pantry.box_fee(id)


func _strip_chip(ch: Player, i: int, c: Dictionary, on: bool) -> Control:
	var chip := HudWidgets.Sheet.new("label" if on else "inset", 12, 6)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	chip.add_child(col)
	if c.kind == "box":
		hud._label(col, 20, Catalog.label({"id": c.id, "tier": 1}))
		hud._label(col, 16, "In it: take out").modulate = Color(Hud.INK, 0.7)
	else:
		var price := Upgrades.step_price(c.key)
		hud._label(col, 20, Upgrades.name_of(c.key))
		var tag := hud._label(col, 16, "$%d" % price)
		tag.modulate = Color(Hud.CORAL) if price > hud.game.ledger.money else Color(Hud.INK, 0.7)
	if not on:
		chip.modulate = Color(1, 1, 1, 0.8)
	chip.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			if ch.strip_pick == i:
				hud.game.upgrades.strip_buy(ch)
			else:
				ch.strip_pick = i
				hud.game.audio.sfx("tab", 0.08)
				show_build()
			chip.accept_event())
	return chip


const SLOT := 88.0                  # the gap between the small pieces along the row
const GAP := 64.0                   # extra room either side of the piece in the middle
const BAND := Vector2(1080, 232)    # the row itself
const ITEM := Vector2(204, 232)     # one piece: its picture with the price underneath
const SMALL := 0.42                 # how big the pieces either side of the middle are


func _drop_row() -> void:
	if hud._row_tween:
		hud._row_tween.kill()
	hud._items.clear()
	hud._views.clear()
