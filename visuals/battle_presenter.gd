class_name BattlePresenter
extends RefCounted

## Read-only event adapter. The simulation emits completed combat events; the presenter never chooses targets.
var _last_sequence: int = 0


func capture(simulation: BattleSimulation) -> Dictionary:
	var snapshot: Dictionary = simulation.snapshot()
	snapshot["effects"] = simulation.events_after(_last_sequence)
	_last_sequence = simulation.event_sequence()
	return snapshot
