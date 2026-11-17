class_name Bill
extends RefCounted
## One table's bill (PRD 11): which table, and how many of each menu item. The game
## builds the right one from what the party ordered; the player writes one at the till
## from memory; `check` compares them. Pure data, no scene.

var table := -1            # the table's number
var items := {}            # menu item id (int) -> count


func _init(table_ := -1, items_ := {}) -> void:
	table = table_
	for id in items_:
		if int(items_[id]) > 0:
			items[int(id)] = int(items_[id])


## Adds one of item `id` (or takes one off with -1). A count never goes below zero.
func add(id: int, n := 1) -> void:
	var c := maxi(0, int(items.get(id, 0)) + n)
	if c == 0:
		items.erase(id)
	else:
		items[id] = c


func count(id: int) -> int:
	return int(items.get(id, 0))


func total_count() -> int:
	var n := 0
	for id in items:
		n += int(items[id])
	return n


func is_empty() -> bool:
	return items.is_empty()


## The right bill for a table: `orders` holds each guest's ordered items (menu items,
## as `Guest.ordered_items()`); a guest who ordered nothing adds nothing.
static func for_party(table_: int, orders: Array) -> Bill:
	var b := Bill.new(table_)
	for list: Array in orders:
		for item: Dictionary in list:
			if not item.is_empty():
				b.add(int(item.id))
	return b


## "ok" when `written` is exactly `right`, else the first difference:
## {kind: "table"} for the wrong table, {kind: "missing", item: id} for something they
## had that is not on it (or not enough of it), {kind: "extra", item: id} for something
## on it they never had (or too many). Items are compared in id order, so the order of
## ticking does not matter.
static func check(written: Bill, right: Bill) -> Variant:
	if written.table != right.table:
		return {"kind": "table", "item": -1}
	var ids := {}
	for id in right.items:
		ids[id] = true
	for id in written.items:
		ids[id] = true
	var order: Array = ids.keys()
	order.sort()
	for id: int in order:
		if written.count(id) < right.count(id):
			return {"kind": "missing", "item": id}
	for id: int in order:
		if written.count(id) > right.count(id):
			return {"kind": "extra", "item": id}
	return "ok"


## The sum of tonight's list prices for the bill (before mood and deals, which are per
## guest: `GuestMood.pay_for`). An item no longer on the menu counts nothing.
static func price(bill: Bill, menu: Menu) -> int:
	var total := 0
	for id in bill.items:
		var item := menu.find(int(id))
		if not item.is_empty():
			total += Menu.price_of(item) * int(bill.items[id])
	return total


## What a guest says on refusing a wrong bill, given `check`'s answer and the menu
## (for the item's name). `course` is that item's course, for the wording.
static func refusal(diff: Dictionary, menu: Menu) -> String:
	if diff.kind == "table":
		return "That's not our table"
	var item := menu.find(int(diff.item))
	var name := menu.name_of(int(diff.item))
	var drink: bool = item.get("course", "") == "drink"
	if diff.kind == "missing":
		return "You forgot my %s" % name.to_lower() if drink else "You missed the %s" % name.to_lower()
	return "We never had the %s" % name.to_lower()
