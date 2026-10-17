@tool
extends TextureRect

@export
var sub_window_size := Vector2i(256, 256)

@export
var expand_speed := 100.0

@export
var focused_z_index: int = 10


@onready var zoom_control: Control = $zoom_control

@onready var zoom_image: Sprite2D = $zoom_control/clip/zoom_image

@onready var border: Panel = $zoom_control/border


var relative_mouse_position: Vector2

var mouse_inside := false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		relative_mouse_position = event.position


func _process(delta: float) -> void:
	if not visible: return

	zoom_control.size = zoom_control.size.lerp(sub_window_size if mouse_inside else Vector2.ZERO, minf(expand_speed * delta, 1.0))

	var viewport_center: Vector2 = zoom_control.size / 2
	zoom_control.position = relative_mouse_position - viewport_center
	zoom_image.texture = texture

	if not texture: return
	var texture_size := texture.get_size()

	var offset_in_rect := Vector2(size.x / size.y - texture_size.x / texture_size.y, size.y / size.x - texture_size.y / texture_size.x).max(Vector2.ZERO) * 0.5

	var offset_percent := -Vector2(
		remap(relative_mouse_position.x, 0.0, size.x, -offset_in_rect.x, 1.0 + offset_in_rect.x),
		remap(relative_mouse_position.y, 0.0, size.y, -offset_in_rect.y, 1.0 + offset_in_rect.y)
	)

	zoom_image.position = offset_percent * texture_size
	zoom_image.position += viewport_center


func _on_mouse_entered() -> void:
	# zoom_control.visible = texture != null
	mouse_inside = true
	border.visible = mouse_inside
	zoom_control.z_index = focused_z_index


func _on_mouse_exited() -> void:
	# zoom_control.hide()
	mouse_inside = false
	border.visible = mouse_inside
	zoom_control.z_index = 0
