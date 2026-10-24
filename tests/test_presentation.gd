extends SceneTree

const Simulation = preload("res://core/battle_simulation.gd")
const Presenter = preload("res://visuals/battle_presenter.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var observed: BattleSimulation = Simulation.new()
	var baseline: BattleSimulation = Simulation.new()
	var presenter: BattlePresenter = Presenter.new()
	var counters: Dictionary = {"shot": 0, "hit": 0, "death": 0, "build": 0, "spawn": 0, "leak": 0}
	for slot in [0, 1, 17]:
		assert(observed.request_build(slot) == baseline.request_build(slot))
	for event in presenter.capture(observed)["effects"]:
		if counters.has(event["kind"]):
			counters[event["kind"]] += 1
	assert(presenter.capture(observed)["effects"].is_empty(), "Repeated UI refresh must not replay visual events")
	observed.start_wave()
	baseline.start_wave()
	for step in range(900):
		observed.tick()
		baseline.tick()
		var raw_before: Dictionary = observed.snapshot()
		var snapshot: Dictionary = presenter.capture(observed)
		assert(observed.snapshot() == raw_before, "Presentation must not mutate the simulation")
		assert(observed.snapshot() == baseline.snapshot(), "Presentation must preserve deterministic battle results")
		for event in snapshot["effects"]:
			if counters.has(event["kind"]):
				counters[event["kind"]] += 1
			if event["kind"] == "shot":
				assert(event["position"] != event["target"], "Observed shot must have an aim direction")
		if observed.phase != "active":
			break
	assert(counters["build"] == 3)
	assert(counters["spawn"] == 8)
	assert(counters["shot"] > 0 and counters["hit"] > 0)
	assert(counters["death"] == observed.killed_count)
	assert(counters["leak"] == observed.leaked_count)
	assert(presenter.capture(observed)["effects"].is_empty())
	print("Presentation regression passed: ", JSON.stringify(counters), " baseline=", observed.phase)
	quit(0)
