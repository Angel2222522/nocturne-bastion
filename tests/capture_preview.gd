extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
const PREVIEW_SIZE: Vector2i = Vector2i(1280, 720)
const TOWER_IDS: Array[String] = ["rapid", "nuclear", "barracks", "mage", "enhancer"]
var game_screen: Control


func _initialize() -> void:
	root.size = PREVIEW_SIZE
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
		assert(simulation.request_build(int(entry["slot"]), String(entry["tower"])), "Capture fixture tower purchase failed")
	assert(simulation.towers.size() == 14, "Capture fixture should show all five categories and support towers")
	_upgrade_branch(simulation, 0, "A")
	_upgrade_branch(simulation, 1, "B")
	_upgrade_branch(simulation, 2, "B")
	_upgrade_branch(simulation, 3, "A")
	_upgrade_branch(simulation, 4, "B")
	_upgrade_branch(simulation, 5, "B")
	_upgrade_branch(simulation, 6, "A")
	game_screen.set("selected_slot", 1)
	game_screen.get("board").call("set_selected_slot", 1)
	game_screen.call("_refresh")
	var presenter: BattlePresenter = game_screen.get("presenter")
	# Advance the actual match through waves one to three; tower and enemy rules remain the same.
	for target_wave in range(3):
		assert(simulation.start_wave(), "Capture fixture could not start configured wave %d" % (target_wave + 1))
		var safety_steps: int = 0
		while simulation.phase == "active" and safety_steps < 6000:
			simulation.tick(0.25)
			safety_steps += 1
		assert(simulation.phase == "intermission", "Configured wave %d did not clear in capture fixture" % (target_wave + 1))
	# Discard setup combat effects from the visual queue before recording wave four.
	var board: BoardView = game_screen.get("board")
	board.call("set_snapshot", presenter.capture(simulation))
	assert(simulation.start_wave(), "Capture fixture could not start wave four")
	game_screen.call("_refresh")
	await create_timer(15.0).timeout
	await RenderingServer.frame_post_draw
	assert(simulation.phase == "active" and simulation.wave_index == 3, "Capture must show an active real fourth wave")
	assert(not simulation.enemies.is_empty(), "Capture must include live gameplay enemies")
	var output_path: String = ProjectSettings.globalize_path("res://build/PULSE-preview.png")
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var save_error: Error = root.get_texture().get_image().save_png(output_path)
	assert(save_error == OK, "Screenshot must save successfully")
	root.size = Vector2i(960, 540)
	await process_frame
	await RenderingServer.frame_post_draw
	var small_error: Error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/PULSE-small-preview.png"))
	assert(small_error == OK, "Small-phone screenshot must save successfully")
	root.size = PREVIEW_SIZE
	await create_timer(5.0).timeout
	var counts: Dictionary = board.get("animation_counts")
	var winged_spawned: bool = int(simulation.spawned_by_enemy.get("winged", 0)) > 0
	assert(winged_spawned, "Real gameplay capture must reach the configured flying-enemy entry")
	assert(simulation.wave_spawned_count == simulation.wave_enemy_total, "Capture video must pass the complete mixed wave spawn sequence")
	assert(int(counts["shot"]) > 0 and int(counts["death"]) > 0 and int(counts["build"]) >= 5)
	assert(int(counts["blast"]) > 0 and int(counts["radiation"]) > 0, "Nuclear specialisation must trigger visible combat effects")
	assert(int(counts["debuff"]) > 0 and int(counts["knockback"]) > 0, "Both mage specialisations must trigger visible effects")
	assert(int(counts["soldier_spawn"]) > 0 and int(counts["soldier_attack"]) > 0, "Barracks must produce and fight with visible soldiers")
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
	quit(0)


func _upgrade_branch(simulation: BattleSimulation, slot_id: int, branch: String) -> void:
	var state: TowerState = simulation.towers[slot_id]["state"]
	while state.level < state.definition["levels"].size():
		assert(simulation.upgrade_tower(slot_id), "Capture fixture level upgrade failed for slot %d" % slot_id)
	assert(simulation.upgrade_tower(slot_id, branch), "Capture fixture branch upgrade failed for slot %d" % slot_id)
