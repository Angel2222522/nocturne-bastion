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
	_watchdog.autostart = true
	_watchdog.timeout.connect(_on_watchdog_timeout)
	root.add_child(_watchdog)
	call_deferred("_capture_gameplay_frame")


func _capture_gameplay_frame() -> void:
	game_screen = GAME_SCENE.instantiate() as Control
	root.add_child(game_screen)
	await process_frame
	await create_timer(0.3).timeout
	var simulation: BattleSimulation = game_screen.get("simulation")
	# Fixture budget lets the evidence run exercise all temporary categories in one real match.
	simulation.wallet.gold = 25000
	var fixture_towers: Array[Dictionary] = [
		{"slot": 27, "tower": "rapid"}, {"slot": 19, "tower": "nuclear"},
		{"slot": 5, "tower": "mage"},
		{"slot": 6, "tower": "enhancer"}, {"slot": 17, "tower": "mage"},
		{"slot": 2, "tower": "enhancer"}, {"slot": 8, "tower": "rapid"}
	]
	for entry in fixture_towers:
		var slot_id: int = int(entry["slot"])
		var tower_id: String = String(entry["tower"])
		game_screen.call("_on_tower_type_pressed", tower_id)
		game_screen.call("_on_build_slot_pressed", slot_id)
		if not _require(simulation.towers.has(slot_id), "Capture fixture tower purchase failed for %s" % tower_id):
			return
	if not _require(simulation.towers.size() == 7, "Capture fixture should place all non-Barracks support towers before the warm-up waves"):
		return
	for upgrade in [[27, "B"], [19, "B"], [5, "A"], [6, "B"], [17, "B"], [2, "A"]]:
		if not _upgrade_branch(simulation, int(upgrade[0]), String(upgrade[1])):
			return
	game_screen.set("selected_slot", 19)
	game_screen.get("board").call("set_selected_slot", 19)
	game_screen.call("_refresh")
	var presenter: BattlePresenter = game_screen.get("presenter")
	# Advance the actual match through waves one to four; wave five stays live for the recording.
	for target_wave in range(4):
		if not _require(simulation.start_wave(), "Capture fixture could not start configured wave %d" % (target_wave + 1)):
			return
		var safety_steps: int = 0
		while simulation.phase == "active" and safety_steps < 6000:
			simulation.tick(0.25)
			safety_steps += 1
		if not _require(simulation.phase == "intermission", "Configured wave %d did not clear in capture fixture" % (target_wave + 1)):
			return
	game_screen.call("_on_tower_type_pressed", "barracks")
	game_screen.call("_on_build_slot_pressed", 14)
	if not _require(simulation.towers.has(14), "Capture fixture could not build the Barracks before wave five"):
		return
	if not _upgrade_branch(simulation, 14, "B"):
		return
	if not _require(simulation.towers.size() == 8, "Capture fixture must show all five categories in the recorded battle"):
		return
	# Keep construction cues while preventing synchronous setup combat from replaying in the clip.
	var board: BoardView = game_screen.get("board")
	board.call("set_snapshot", presenter.capture(simulation))
	board.set("_effects", [])
	board.set("_hit_age", {})
	board.set("_recoil", {})
	board.set("_core_hit_age", 10.0)
	var animation_counts: Dictionary = board.get("animation_counts")
	var build_events: int = int(animation_counts.get("build", 0))
	var upgrade_events: int = int(animation_counts.get("upgrade", 0))
	for kind in animation_counts.keys():
		animation_counts[kind] = 0
	animation_counts["build"] = build_events
	animation_counts["upgrade"] = upgrade_events
	board.set("animation_counts", animation_counts)
	game_screen.call("_on_wave_pressed")
	if not _require(simulation.phase == "active" and simulation.wave_index == 4, "Capture fixture could not start wave five from the game control"):
		return
	# Step the real simulation until its first surviving enemy, then freeze the frame for evidence.
	game_screen.set_process(false)
	var original_cooldowns: Dictionary = {}
	for slot_value in simulation.towers.keys():
		var slot_id: int = int(slot_value)
		var runtime: Dictionary = simulation.towers[slot_id]
		original_cooldowns[slot_id] = {
			"cooldown": float(runtime["cooldown"]),
			"production_cooldown": float(runtime["production_cooldown"])
		}
		runtime["cooldown"] = 1.0
		runtime["production_cooldown"] = 1.0
		simulation.towers[slot_id] = runtime
	var screenshot_steps: int = 0
	while simulation.phase == "active" and simulation.enemies.is_empty() and screenshot_steps < 20:
		simulation.tick(0.1)
		screenshot_steps += 1
	await RenderingServer.frame_post_draw
	if not _require(simulation.phase == "active" and simulation.wave_index == 4, "Capture must show an active real fifth wave"):
		return
	if not _require(not simulation.enemies.is_empty(), "Capture must include live gameplay enemies"):
		return
	board.set_snapshot(presenter.capture(simulation))
	await RenderingServer.frame_post_draw
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
	await process_frame
	for slot_value in original_cooldowns:
		var slot_id: int = int(slot_value)
		var runtime: Dictionary = simulation.towers[slot_id]
		runtime["cooldown"] = float(original_cooldowns[slot_id]["cooldown"])
		runtime["production_cooldown"] = float(original_cooldowns[slot_id]["production_cooldown"])
		simulation.towers[slot_id] = runtime
	var counts: Dictionary = board.get("animation_counts")
	for kind in counts.keys():
		counts[kind] = 0
	counts["build"] = build_events
	counts["upgrade"] = upgrade_events
	board.set("animation_counts", counts)
	game_screen.set_process(true)
	await create_timer(30.0).timeout
	counts = board.get("animation_counts")
	print("Captured battle animation events: ", JSON.stringify(counts))
	var winged_spawned: bool = int(simulation.spawned_by_enemy.get("winged", 0)) > 0
	if not _require(winged_spawned, "Real gameplay capture must reach the configured flying-enemy entry"):
		return
	if not _require(simulation.wave_spawned_count == simulation.wave_enemy_total, "Capture video must pass the complete mixed wave spawn sequence"):
		return
	if not _require(int(counts["shot"]) > 0 and int(counts["death"]) > 0 and int(counts["build"]) >= 5, "Capture must show shots, defeats, and all tower builds"):
		return
	if not _require(int(counts["blast"]) > 0, "Nuclear specialisation must trigger a visible blast"):
		return
	if not _require(int(counts["radiation"]) > 0, "Nuclear B must radiate across multiple living enemies during the captured battle"):
		return
	if not _require(int(counts["debuff"]) > 0 and int(counts["knockback"]) > 0, "Both mage specialisations must trigger visible effects"):
		return
	if not _require(int(counts["soldier_spawn"]) > 0 and int(counts["soldier_attack"]) > 0, "Barracks must produce and fight with visible soldiers"):
		return
	var report: Dictionary = {
		"real_gameplay": true,
		"fixture_gold": 25000,
		"fixture_note": "Evidence-only starting budget; all combat and presentation came from the game simulation.",
		"capture_wave": 5,
		"temporary_tower_categories": TOWER_IDS,
		"animation_events": counts,
		"gold_at_end": simulation.wallet.gold,
		"phase_at_end": simulation.phase,
		"towers": simulation.towers.size(),
		"enemies_spawned": simulation.spawned_count,
		"wave_five_spawned": simulation.wave_spawned_count,
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
