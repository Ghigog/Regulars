class_name HudShop
extends RefCounted
## The build shop: its cards dealt by category and search, the info panel for a piece, a box
## or a card action, moving the selection and buying.

var hud: Hud


func _init(hud_: Hud) -> void:
	hud = hud_


## The shop: a wooden tray along the bottom with one row of pieces that slides
## left and right. The piece in the middle is the selected one: a little bigger,
## lifted and tipped on a soft white disc, turning slowly, its price underneath.
## Category tabs sit under the row, with the search box at the bottom right.
func show_shop() -> void:
	if hud._shop:
		return
	hud._search = ""
	hud._category = hud.shop_tabs()[0]
	hud._shop_index = hud.game.card.card_actions().size() if hud.game.card.storing() and hud.game.card.card_keeps_boxes() else 0   # the boxes first
	hud.build_bar.visible = false
	hud._shop = Control.new()
	hud._shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud._shop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.root.add_child(hud._shop)
	hud.root.move_child(hud._shop, hud.center.get_index())
	if hud.game.chefs.size() > 1 and hud.game.shopper != null:   # co-op: whose shop this is
		var tag := HudWidgets.Sheet.new("note").pad(12, 6, 16, 6)
		tag.anchor_left = 0.5
		tag.anchor_right = 0.5
		tag.offset_top = 96
		tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
		tag.rotation = -0.02
		hud._shop.add_child(tag)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		tag.add_child(row)
		var who: int = hud.game.chefs.find(hud.game.shopper)
		var chip := HudWidgets.ChefTag.new(who, 26)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		hud._label(row, 18, "Chef %d is shopping" % (who + 1))
		hud._shop_tag = tag
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._shop.add_child(margin)
	var wood := HudWidgets.Sheet.new("wood", 10, 10)
	wood.mouse_filter = Control.MOUSE_FILTER_STOP
	wood.size_flags_vertical = Control.SIZE_SHRINK_END
	wood.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.add_child(wood)
	var paper := HudWidgets.Sheet.new("paper", 14, 8)
	wood.add_child(paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	paper.add_child(box)

	var band := Control.new()
	band.custom_minimum_size = HudHints.BAND
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(band)
	var felt := Panel.new()   # a kraft mat, so the white disc shows against the paper
	felt.set_anchors_preset(Control.PRESET_FULL_RECT)
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.add_theme_stylebox_override("panel", Hud._flat(Hud.KRAFT, 12))
	band.add_child(felt)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.78, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.97), Color(1, 1, 1, 0.0)])
	var disc := GradientTexture2D.new()
	disc.gradient = fade
	disc.fill = GradientTexture2D.FILL_RADIAL
	disc.fill_from = Vector2(0.5, 0.5)
	disc.fill_to = Vector2(1.0, 0.5)
	disc.width = 256
	disc.height = 256
	var glow := TextureRect.new()
	glow.texture = disc
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(216, 216)
	glow.position = Vector2(HudHints.BAND.x / 2.0 - 108, -8)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(glow)
	hud._cards = Control.new()   # only a holder: _lay_out places the pieces by hand
	hud._cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(hud._cards)
	for side: int in [-1, 1]:   # keycaps at the ends: there is more to the left and right
		var key := HudWidgets.Sheet.new("key", 13, 4).pad(13, 1, 13, 7)
		key.position = Vector2(HudHints.BAND.x / 2.0 + side * (HudHints.BAND.x / 2.0 - 30) - 20, 70)
		band.add_child(key)
		hud._label(key, 24, "<" if side < 0 else ">")
	var about := HBoxContainer.new()
	about.alignment = BoxContainer.ALIGNMENT_CENTER
	about.add_theme_constant_override("separation", 14)
	box.add_child(about)
	hud._info = hud._label(about, 21)
	hud._info_blurb = hud._label(about, 18)
	hud._info_blurb.modulate.a = 0.7

	# Under the row: search on the left, the categories in the middle, the keys on the right.
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	box.add_child(strip)
	hud._search_box = LineEdit.new()
	hud._search_box.placeholder_text = "Search...  (F)"
	hud._search_box.custom_minimum_size = Vector2(210, 0)
	hud._search_box.add_theme_font_size_override("font_size", 16)
	hud._search_box.text_changed.connect(hud.set_search)
	hud._search_box.text_submitted.connect(func(_t: String) -> void: hud._search_box.release_focus())
	hud._search_box.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and hud.game.shop_key(event.physical_keycode):
			hud._search_box.accept_event())
	strip.add_child(hud._search_box)
	var middle := HBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 8)
	strip.add_child(middle)
	hud._tabs.clear()
	for cat: String in hud.shop_tabs():
		var tab := hud.receipt_ui._button(middle, cat, hud._set_category.bind(cat))
		tab.add_theme_font_size_override("font_size", 16)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tab.toggle_mode = true
		tab.set_meta("cat", cat)
		hud._tabs.append(tab)
	var keys := hud._label(strip, 15, hud.hints_ui._shop_keys_text())
	hud._shop_keys = keys
	keys.custom_minimum_size = Vector2(210, 0)   # as wide as the search box, so the tabs sit dead centre
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys.modulate.a = 0.75

	_refresh_catalog()
	_deal_cards()
	# The tray slides up from under the screen.
	hud._shop.position.y = Hud.TRAY_DROP
	hud._shop.create_tween().tween_property(hud._shop, "position:y", 0.0, 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Slides the tray away.
func hide_shop() -> void:
	if hud._shop == null:
		return
	hud.stop_typing()
	var tray := hud._shop
	hud._shop = null
	hud.hints_ui._drop_row()
	var tw := tray.create_tween()
	tw.tween_property(tray, "position:y", Hud.TRAY_DROP, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(tray.queue_free)
	if hud.build_bar:
		hud.build_bar.visible = true


## What the shop says about a piece: {name, price, blurb, can, locked}.
func _shop_info(bp: Dictionary) -> Dictionary:
	var l: Ledger = hud.game.ledger
	if bp.id == "flyers":
		return {"name": "Flyers", "price": "Out" if hud.game.flyers_out else "$%d" % Town.FLYER_PRICE,
			"blurb": "More guests tomorrow",
			"can": not hud.game.flyers_out and l.money >= Town.FLYER_PRICE, "locked": false}
	if bp.id == "night_cleaner":
		var p: int = hud.game.room_edit.cleaner_price()
		return {"name": "Night cleaner", "price": "Clean" if p <= 0 else "$%d" % p,
			"blurb": "Clears every table, washes up, takes the bags out and mops the floor" if p > 0 else "Nothing to clean tonight",
			"can": p > 0 and l.money >= p, "locked": false}
	if hud.game.card.storing():
		return _storage_info(bp)
	var id: String = bp.id
	var tier: int = bp.tier
	var need := Catalog.bp_level(bp)
	var locked: bool = bp.get("locked", false) or hud.game.placing.buy_level(id) < need
	var price := "$%d" % Catalog.bp_price(bp)
	if Treatments.is_box(id):   # restocked each night for a flat fee, like food (review, item 8)
		price = Treatments.fee_words(Treatments.key_of(id))
	elif Treatments.is_laying_tool(id):
		price = "Free to lay"
	elif Catalog.is_box(id):   # a box is free to take; its kind costs a fee each night (PRD 8.4)
		var b := Pantry.station_ingredient(id)
		price = "$%d a night" % Pantry.fee_of(b.id, b.ready)
	return {"name": Catalog.label(bp), "blurb": Catalog.bp_blurb(bp), "locked": locked,
		"price": "Level %d" % need if locked else price,
		"can": not locked and hud.game.catalog.can_buy(id, l.money, hud.game.placing.buy_level(id), tier) and l.money >= Catalog.bp_price(bp)}


## A box on the storage card: one stored here is taken out; one that may go in shows
## its nightly fee; one that may not is dimmed with why ("Needs a fridge").
func _storage_info(bp: Dictionary) -> Dictionary:
	if bp.has("act"):
		return _card_act_info(bp)
	var b := Pantry.station_ingredient(bp.id)
	var fee := Treatments.fee_words(Treatments.key_of(bp.id)) if Treatments.is_box(bp.id) \
		else ("Free" if b.is_empty() else "$%d a night" % Pantry.fee_of(b.id, b.ready))
	if bp.get("stored", false):
		return {"name": Catalog.label(bp), "blurb": "Stored here. Take it out", "locked": false,
			"price": "Take out", "can": true}
	var why: String = hud.game.kitchen.store_refusal(hud.game.storing_cell, bp.id)
	var fridge: int = hud.game.card.fridge_offer(bp.id)
	if fridge > 0:   # review, item 11: one press makes this counter the fridge it needs
		return {"name": Catalog.label(bp), "blurb": "%s: E makes this counter one ($%d), with the box in" % [why, fridge],
			"locked": false, "price": "Fridge $%d" % fridge, "can": hud.game.ledger.money >= fridge}
	var plenty := "Unlimited tonight, %s" % fee.trim_suffix(" a night") if fee != "Free" else Catalog.bp_blurb(bp)
	return {"name": Catalog.label(bp), "blurb": plenty if why == "" else why + (": upgrade the counter (Upgrades)" if why.begins_with("Needs a") else ""),
		"locked": why != "", "price": fee if why == "" else why, "can": why == ""}


## An action card on a piece's card: Upgrades, Move, Turn, Sell, the till's Move, or the
## upgrade of a stored treatment box.
func _card_act_info(bp: Dictionary) -> Dictionary:
	var st: Station = hud.game.card.card_station()
	var what: String = hud.game.placing.piece_name({"id": st.type, "tier": st.tier}).to_lower() if st != null else "piece"
	match str(bp.act):
		"upgrades":
			return {"name": "Upgrades", "blurb": "Its upgrade tree: upgrade the %s where it stands" % what,
				"price": "Upgrade", "can": true, "locked": false}
		"box_tree":
			return {"name": "Upgrade the %s" % Catalog.label(bp).to_lower(), "blurb": "Its tree: a better treatment, kept in its slot",
				"price": "Upgrade", "can": true, "locked": false}
		"move":
			return {"name": "Move", "blurb": "Pick the %s up to carry it somewhere else (or hold E)" % what,
				"price": "Move", "can": true, "locked": false}
		"turn":
			return {"name": "Turn", "blurb": "A quarter turn where it stands", "price": "Turn", "can": true, "locked": false}
		"till":
			return {"name": "Move the till", "blurb": "Lift the till off to put it on another counter",
				"price": "Move", "can": true, "locked": false}
		"sell":
			var v: int = hud.game.card.card_sell_value()
			if v < 0:
				return {"name": "Sell", "blurb": hud.game.card.card_sell_block(), "price": "Can't sell", "can": false, "locked": true}
			return {"name": "Sell", "blurb": "Half back; whatever was bought tonight comes back whole",
				"price": "+$%d" % v, "can": true, "locked": false}
	return {"name": "", "blurb": "", "price": "", "can": false, "locked": false}


## Rebuilds the row for the current search and category, keeping the selection on
## the same piece where it is still listed.
func _refresh_catalog() -> void:
	if hud._shop == null:
		return
	var searching := hud._search.strip_edges() != ""   # a search looks through every category
	for tab in hud._tabs:
		tab.set_pressed_no_signal(tab.get_meta("cat") == hud._category and not searching)
	var keep: Dictionary = hud._shop_items[hud._shop_index] if hud._shop_index < hud._shop_items.size() else {}
	var turned := hud._views[hud._shop_index].spin.rotation.y if hud._shop_index < hud._views.size() else -0.6
	for c in hud._cards.get_children():
		hud._cards.remove_child(c)
		c.queue_free()
	hud.hints_ui._drop_row()
	hud._shop_items = hud.game.session.shop_items(hud._search, "" if searching else hud._category)
	for i in hud._shop_items.size():
		var bp := hud._shop_items[i]
		var info := _shop_info(bp)
		var item := Control.new()
		item.size = HudHints.ITEM
		item.pivot_offset = Vector2(HudHints.ITEM.x / 2.0, 122)
		item.tooltip_text = "%s\n%s" % [info.name, info.blurb]
		item.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_card_pressed(i))
		hud._cards.add_child(item)
		hud._items.append(item)
		var view := HudWidgets.ModelView.new(int(HudHints.ITEM.x), true)
		view.modulate = Color(0.22, 0.17, 0.14, 0.5) if info.locked else Color.WHITE   # a silhouette (review, item 10)
		item.add_child(view)
		view.show_piece(hud.game, bp)
		hud._views.append(view)
		var price := hud._label(item, 32, info.price)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.position = Vector2(0, 190)
		price.size = Vector2(HudHints.ITEM.x, 40)
		if not info.can:
			price.add_theme_color_override("font_color", Color(Hud.INK, 0.6) if info.locked else Color("#b8473a"))
	if hud._shop_items.is_empty():
		var none := hud._label(hud._cards, 20, "Nothing in the shop matches.")
		none.modulate.a = 0.7
		none.position = Vector2(HudHints.BAND.x / 2.0 - 120, 196)
	var at := hud._shop_items.find(keep)
	_select(clampi(hud._shop_index, 0, maxi(hud._shop_items.size() - 1, 0)) if at < 0 else at, 0)
	if at >= 0:
		hud._views[at].spin.rotation.y = turned   # the same piece carries on turning from where it was


## Places every piece for a row position: `pos` is the index in the middle, and
## fractional while the row slides. A piece grows, lifts and tips as it comes in.
func _lay_out(pos: float) -> void:
	hud._row_pos = pos
	for j in hud._items.size():
		var away := absf(j - pos)
		var near := 1.0 - clampf(away, 0.0, 1.0)
		var item := hud._items[j]
		var along := (j - pos) * HudHints.SLOT + signf(j - pos) * HudHints.GAP * minf(away, 1.0)
		item.position.x = HudHints.BAND.x / 2.0 - HudHints.ITEM.x / 2.0 + along
		item.scale = Vector2.ONE * lerpf(HudHints.SMALL, 1.0, smoothstep(0.0, 1.0, near))
		item.modulate.a = clampf(5.3 - away, 0.0, 1.0)   # fading out toward the ends of the tray
		item.z_index = 1 if near > 0.5 else 0
		hud._views[j].lift(near)


## The pieces drop into the tray one after another, from the middle outward.
func _deal_cards() -> void:
	for i in hud._items.size():
		var wait := absi(i - hud._shop_index) * 0.03
		hud._items[i].position.y = 90.0
		hud._items[i].create_tween().tween_property(hud._items[i], "position:y", 0.0, 0.3).set_delay(wait) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _card_pressed(i: int) -> void:
	if i == hud._shop_index:
		shop_buy()
	else:
		hud.game.audio.sfx("tick", 0.1)
		_select(i, signi(i - hud._shop_index))


## Brings piece `i` to the middle of the row. `dir` is the way the selection
## moved; 0 puts it there at once.
func _select(i: int, dir: int) -> void:
	hud._shop_index = i
	if hud._row_tween:
		hud._row_tween.kill()
	if hud._shop_items.is_empty():
		hud._info.text = ""
		hud._info_blurb.text = ""
		return
	var info := _shop_info(hud._shop_items[i])
	hud._info.text = info.name
	hud._info_blurb.text = info.blurb
	if dir == 0:
		_lay_out(i)
	else:
		hud._row_tween = hud._shop.create_tween()
		hud._row_tween.tween_method(_lay_out, hud._row_pos, float(i), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Left and right along the tray, wrapping at the ends.
## The box or piece in the middle of the shop row, or {} when the row is empty.
func shop_selected() -> Dictionary:
	if hud._shop == null or hud._shop_items.is_empty():
		return {}
	return hud._shop_items[hud._shop_index]


func shop_move(d: int) -> void:
	if hud._shop == null or hud._shop_items.is_empty():
		return
	hud.game.audio.sfx("tick", 0.1)
	_select(wrapi(hud._shop_index + d, 0, hud._shop_items.size()), d)


func shop_category(d: int) -> void:
	if hud._shop:
		var tabs := hud.shop_tabs()
		hud._set_category(tabs[wrapi(tabs.find(hud._category) + d, 0, tabs.size())])


## Buys the piece in the middle. A refusal shakes it; flyers get a little hop.
func shop_buy() -> void:
	if hud._shop == null or hud._shop_items.is_empty():
		hud.game.audio.sfx("fail")
		return
	var item := hud._items[hud._shop_index]
	if hud.game.placing.buy(hud._shop_items[hud._shop_index]):
		if hud._shop:   # still open: it was the flyers, and the row has been redrawn
			item = hud._items[hud._shop_index]
			var tw := item.create_tween()
			tw.tween_property(item, "position:y", -22.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		return
	var x := item.position.x
	var no := item.create_tween()
	for dx: float in [-12.0, 10.0, -6.0, 0.0]:
		no.tween_property(item, "position:x", x + dx, 0.05)
