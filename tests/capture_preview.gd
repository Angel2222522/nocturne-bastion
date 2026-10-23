extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
const PREVIEW_SIZE: Vector2i = Vector2i(1280, 720)


func _initialize() -> void:
	root.size = PREVIEW_SIZE
	call_deferred("_capture_gameplay_frame")


func _capture_gameplay_frame() -> void:
	var game_screen: Control = GAME_SCENE.instantiate() as Control
	root.add_child(game_screen)
	await process_frame
	var simulation: Object = game_screen.get("simulation")
	if simulation != null:
		simulation.call("request_build", 5, "rapid")
		simulation.call("request_build", 17, "rapid")
		game_screen.call("_on_start_pressed")
	for frame_index in range(30):
		await process_frame
	await create_timer(1.2).timeout
	var image: Image = root.get_texture().get_image()
	var output_path: String = ProjectSettings.globalize_path("res://build/PULSE-preview.png")
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save visual preview: %s" % error_string(save_error))
		quit(1)
		return
	print("Visual preview saved: %s (%s x %s)" % [output_path, image.get_width(), image.get_height()])
	quit(0)
