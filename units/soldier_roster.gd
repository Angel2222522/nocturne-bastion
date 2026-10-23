class_name SoldierRoster
extends RefCounted

## Survivors accumulate; this intentionally has no population cap.
var count: int = 0

func produce(amount: int) -> void:
	count += maxi(0, amount)


func lose(amount: int = 1) -> int:
	var losses: int = mini(maxi(0, amount), count)
	count -= losses
	return losses
