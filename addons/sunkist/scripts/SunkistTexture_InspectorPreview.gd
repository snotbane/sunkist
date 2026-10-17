@tool
extends EditorProperty

const DRAG_SPEED := 0.01

var sunkist: Sunkist3D

func _init() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size.y = 256
	container.mouse_default_cursor_shape = Control.CURSOR_CROSS
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

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

	set_bottom_editor(container)


func _update_property() -> void:
	sunkist.texture = get_edited_object()
