class_name Finance
extends RefCounted
## Balance plus a ledger of every transaction.

var balance: int = 0
var ledger: Array = []   # [{round, season, category, amount, note}]
const MAX_LEDGER := 400


## note is an untranslated format string; note_args fill it in (translated at display time).
func add(amount: int, category: String, note: String, season: int, round_idx: int, note_args: Array = []) -> void:
	balance += amount
	ledger.append({"season": season, "round": round_idx, "category": category, "amount": amount, "note": note, "args": note_args})
	if ledger.size() > MAX_LEDGER:
		ledger = ledger.slice(ledger.size() - MAX_LEDGER)


static func note_text(e: Dictionary) -> String:
	var args := []
	for a in e.get("args", []):
		args.append(TranslationServer.translate(a) if a is String else a)
	var key := TranslationServer.translate(str(e.get("note", "")))
	return key % args if args.size() > 0 else key


func can_afford(amount: int) -> bool:
	return balance >= amount


## Sum of ledger entries per category for one round (or whole season when round_idx < 0).
func summary(season: int, round_idx: int = -1) -> Dictionary:
	var out := {}
	for e in ledger:
		if int(e["season"]) != season:
			continue
		if round_idx >= 0 and int(e["round"]) != round_idx:
			continue
		out[e["category"]] = out.get(e["category"], 0) + int(e["amount"])
	return out


func to_dict() -> Dictionary:
	return {"balance": balance, "ledger": ledger}


static func from_dict(d: Dictionary) -> Finance:
	var f := Finance.new()
	f.balance = int(d.get("balance", 0))
	f.ledger = d.get("ledger", []).duplicate(true)
	return f
