@tool
extends EditorProperty

const DRAG_SPEED := 0.01

var sunkist: Sunkist3D

func _init() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size.y = 256
	container.mouse_default_cursor_shape = Control.CURSOR_CROSS
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_child(container)

	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	viewport.world_3d.environment = Environment.new()
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	container.add_child(viewport)

	var scene := preload("res://addons/sunkist/scenes/SunkistViewerWorld.tscn")
	var scene_node := scene.instantiate()
	viewport.add_child(scene_node)

	sunkist = scene_node.get_node(^"sunkist")

	# var screenshot_button := Button.new()
	# screenshot_button.text = "Take Preview Snapshot"
	# screenshot_button.pressed.connect((func() -> void:
	# 	var temp_vp := viewport.duplicate()
	# 	get_tree().root.add_child(temp_vp)
	# 	# container.stretch = false
	# 	# viewport.size = Vector2i(512, 512)
	# 	temp_vp.size = sunkist.texture.get_size()
	# 	await get_tree().process_frame
	# 	await get_tree().process_frame
	# 	temp_vp.get_texture().get_image().save_png("res://image.png")
	# 	temp_vp.size = Vector2i.ZERO
	# 	# viewport.get_texture().get_image().save_png("res://image.png")
	# 	# viewport.size = Vector2i.ZERO
	# 	# container.stretch = true
	# ))
	# vbox.add_child(screenshot_button)

	set_bottom_editor(vbox)


func _update_property() -> void:
	sunkist.texture = get_edited_object()
