class_name Ledger
extends RefCounted
## Money, XP and the day-by-day books.

const MAX_STRIKES := 3
const XP_PER_LEVEL := 100

var money := 50
var xp := 0
var day := 1
var today := _blank()
var history: Array[Dictionary] = []


static func _blank() -> Dictionary:
	return {"sales": 0, "tips": 0, "served": 0, "walkouts": 0, "spent": 0, "stock": 0, "found_nothing": 0}


func level() -> int:
	return 1 + floori(float(xp) / XP_PER_LEVEL)


func record_sale(bill: int, tip: int) -> void:
	money += bill + tip
	today.sales += bill
	today.tips += tip
	today.served += 1
	xp += 10 + tip


## Pays for tonight's stock as the door opens. False, and nothing paid, if it is
## more than the money there is.
func pay_stock(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	today.stock += amount
	return true


## Someone read the menu and found no main they would eat. Not a strike.
func record_found_nothing(count := 1) -> void:
	today.found_nothing += count


func record_walkout() -> void:
	today.walkouts += 1


func strikes() -> int:
	return today.walkouts


func is_closed_down() -> bool:
	return strikes() >= MAX_STRIKES


## Everything earned across the whole run, including today.
func lifetime_earnings() -> int:
	var total: int = today.sales + today.tips
	for rec in history:
		total += int(rec.sales) + int(rec.tips)
	return total


func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	today.spent += amount
	return true


## Money back for something sold. It comes off today's spending.
func refund(amount: int) -> void:
	money += amount
	today.spent -= amount


## Closes the books for the day and returns that day's record.
func end_day() -> Dictionary:
	var record := today.duplicate()
	record["day"] = day
	history.append(record)
	today = _blank()
	day += 1
	return record
