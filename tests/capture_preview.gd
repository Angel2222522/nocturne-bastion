extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
const PREVIEW_SIZE: Vector2i = Vector2i(1280, 720)
var game_screen: Control

func _initialize() -> void:
	root.size = PREVIEW_SIZE
	call_deferred("_capture_gameplay_frame")

func _capture_gameplay_frame() -> void:
	game_screen = GAME_SCENE.instantiate() as Control
	root.add_child(game_screen)
	await process_frame
	await create_timer(0.25).timeout
	for slot_id in [0, 1, 17]:
		game_screen.call("_on_build_slot_pressed", slot_id)
		game_screen.call("_on_build_pressed")
		await create_timer(0.55).timeout
	game_screen.call("_on_start_pressed")
	await create_timer(10.0).timeout
	await RenderingServer.frame_post_draw
	var simulation: Object = game_screen.get("simulation")
	assert(simulation.get("phase") == "active", "Preview must capture a real active wave")
	assert(not simulation.get("enemies").is_empty(), "Preview must include a real enemy")
	assert(simulation.get("towers").size() == 3, "Preview must include three purchased towers")
	var output_path: String = ProjectSettings.globalize_path("res://build/PULSE-preview.png")
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var save_error: Error = root.get_texture().get_image().save_png(output_path)
	assert(save_error == OK, "Screenshot must save successfully")
	# Small-phone logical canvas to catch text clipping and touch/layout regressions.
	root.size = Vector2i(960, 540)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/PULSE-small-preview.png"))
	root.size = PREVIEW_SIZE
	await create_timer(12.0).timeout
	var board: Object = game_screen.get("board")
	var counts: Dictionary = board.get("animation_counts")
	assert(int(counts["shot"]) > 0 and int(counts["death"]) > 0 and int(counts["build"]) == 3)
	var report: Dictionary = {"real_gameplay": true, "animation_events": counts, "gold": simulation.get("wallet").gold, "phase": simulation.get("phase"), "towers": simulation.get("towers").size(), "enemies_spawned": simulation.get("spawned_count")}
	var file: FileAccess = FileAccess.open("res://build/visual-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("Gameplay capture verified: ", JSON.stringify(report))
	quit(0)
