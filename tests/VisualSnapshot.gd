extends Node
## 自动渲染主场景并保存一张 1280×720 快照，供发布前布局回归使用。


func _ready() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = main_scene.instantiate()
	add_child(main)
	for _index: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png("res://tests/main_preview.png")
	print("VISUAL_SNAPSHOT: %s" % ("PASS" if error == OK else "FAIL %d" % error))
	get_tree().quit(0 if error == OK else 1)
