extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
const PREVIEW_SIZE: Vector2i = Vector2i(1280, 720)
const TOWER_IDS: Array[String] = ["rapid", "nuclear", "barracks", "mage", "enhancer"]
var game_screen: Control
var _watchdog: Timer


func _initialize() -> void:
	root.size = PREVIEW_SIZE
	_watchdog = Timer.new()
	_watchdog.wait_time = 40.0
	_watchdog.one_shot = true
	_watchdog.timeout.connect(_on_watchdog_timeout)
	root.add_child(_watchdog)
	_watchdog.start()
	call_deferred("_capture_gameplay_frame")


func _capture_gameplay_frame() -> void:
	game_screen = GAME_SCENE.instantiate() as Control
	root.add_child(game_screen)
	await process_frame
	await create_timer(0.3).timeout
	var simulation: BattleSimulation = game_screen.get("simulation")
	# Fixture budget lets the evidence run exercise all temporary categories in one real match.
	simulation.wallet.gold = 25000
	for index in range(TOWER_IDS.size()):
		game_screen.call("_on_tower_type_pressed", TOWER_IDS[index])
		game_screen.call("_on_build_slot_pressed", index)
	var extra_towers: Array[Dictionary] = [
		{"slot": 5, "tower": "mage"}, {"slot": 6, "tower": "enhancer"},
		{"slot": 8, "tower": "rapid"}, {"slot": 11, "tower": "rapid"},
		{"slot": 14, "tower": "rapid"}, {"slot": 17, "tower": "rapid"},
		{"slot": 20, "tower": "rapid"}, {"slot": 23, "tower": "rapid"},
		{"slot": 26, "tower": "rapid"}
	]
	for entry in extra_towers:
		if not _require(simulation.request_build(int(entry["slot"]), String(entry["tower"])), "Capture fixture tower purchase failed"):
			return
	if not _require(simulation.towers.size() == 14, "Capture fixture should show all five categories and support towers"):
		return
	for upgrade in [[0, "A"], [1, "B"], [2, "B"], [3, "A"], [4, "B"], [5, "B"], [6, "A"]]:
		if not _upgrade_branch(simulation, int(upgrade[0]), String(upgrade[1])):
			return
	game_screen.set("selected_slot", 1)
	game_screen.get("board").call("set_selected_slot", 1)
	game_screen.call("_refresh")
	var presenter: BattlePresenter = game_screen.get("presenter")
	# Advance the actual match through waves one to three; tower and enemy rules remain the same.
	for target_wave in range(3):
		if not _require(simulation.start_wave(), "Capture fixture could not start configured wave %d" % (target_wave + 1)):
			return
		var safety_steps: int = 0
		while simulation.phase == "active" and safety_steps < 6000:
			simulation.tick(0.25)
			safety_steps += 1
		if not _require(simulation.phase == "intermission", "Configured wave %d did not clear in capture fixture" % (target_wave + 1)):
			return
	# Discard setup combat effects from the visual queue before recording wave four.
	var board: BoardView = game_screen.get("board")
	board.call("set_snapshot", presenter.capture(simulation))
	if not _require(simulation.start_wave(), "Capture fixture could not start wave four"):
		return
	game_screen.call("_refresh")
	await create_timer(15.0).timeout
	await RenderingServer.frame_post_draw
	if not _require(simulation.phase == "active" and simulation.wave_index == 3, "Capture must show an active real fourth wave"):
		return
	if not _require(not simulation.enemies.is_empty(), "Capture must include live gameplay enemies"):
		return
	var output_path: String = ProjectSettings.globalize_path("res://build/PULSE-preview.png")
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var save_error: Error = root.get_texture().get_image().save_png(output_path)
	if not _require(save_error == OK, "Screenshot must save successfully"):
		return
	root.size = Vector2i(960, 540)
	await process_frame
	await RenderingServer.frame_post_draw
	var small_error: Error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/PULSE-small-preview.png"))
	if not _require(small_error == OK, "Small-phone screenshot must save successfully"):
		return
	root.size = PREVIEW_SIZE
	await create_timer(5.0).timeout
	var counts: Dictionary = board.get("animation_counts")
	var winged_spawned: bool = int(simulation.spawned_by_enemy.get("winged", 0)) > 0
	if not _require(winged_spawned, "Real gameplay capture must reach the configured flying-enemy entry"):
		return
	if not _require(simulation.wave_spawned_count == simulation.wave_enemy_total, "Capture video must pass the complete mixed wave spawn sequence"):
		return
	if not _require(int(counts["shot"]) > 0 and int(counts["death"]) > 0 and int(counts["build"]) >= 5, "Capture must show shots, defeats, and all tower builds"):
		return
	if not _require(int(counts["blast"]) > 0 and int(counts["radiation"]) > 0, "Nuclear specialisation must trigger visible combat effects"):
		return
	if not _require(int(counts["debuff"]) > 0 and int(counts["knockback"]) > 0, "Both mage specialisations must trigger visible effects"):
		return
	if not _require(int(counts["soldier_spawn"]) > 0 and int(counts["soldier_attack"]) > 0, "Barracks must produce and fight with visible soldiers"):
		return
	var report: Dictionary = {
		"real_gameplay": true,
		"fixture_gold": 25000,
		"fixture_note": "Evidence-only starting budget; all combat and presentation came from the game simulation.",
		"capture_wave": 4,
		"temporary_tower_categories": TOWER_IDS,
		"animation_events": counts,
		"gold_at_end": simulation.wallet.gold,
		"phase_at_end": simulation.phase,
		"towers": simulation.towers.size(),
		"enemies_spawned": simulation.spawned_count,
		"wave_four_spawned": simulation.wave_spawned_count,
		"flying_enemy_seen": winged_spawned,
		"screenshots": ["1280x720", "960x540"]
	}
	var file: FileAccess = FileAccess.open("res://build/visual-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("Gameplay capture verified: ", JSON.stringify(report))
	_watchdog.stop()
	quit(0)


func _upgrade_branch(simulation: BattleSimulation, slot_id: int, branch: String) -> bool:
	var state: TowerState = simulation.towers[slot_id]["state"]
	while state.level < state.definition["levels"].size():
		if not _require(simulation.upgrade_tower(slot_id), "Capture fixture level upgrade failed for slot %d" % slot_id):
			return false
	if not _require(simulation.upgrade_tower(slot_id, branch), "Capture fixture branch upgrade failed for slot %d" % slot_id):
		return false
	return true


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("Gameplay capture verification failed: " + message)
	_watchdog.stop()
	quit(1)
	return false


func _on_watchdog_timeout() -> void:
	push_error("Gameplay capture exceeded its 40-second simulation budget.")
	quit(2)
