@tool
class_name ImagePreview
extends Control

@onready var name_label: Label = $main/name_label

@onready var image_rect: TextureRect = $main/zoomable_image

@onready var path_label: Label = $main/path_label


var _label: String
@export var label: String:
	get: return _label
	set(value):
		_label = value

		if not name_label: return

		name_label.text = _label
		name_label.visible = not _label.is_empty()


@export var show_path: bool = true:
	get: return path_label.visible if path_label else true
	set(value):
		if not path_label: return
		path_label.visible = value


@export_enum("Auto", "Manual") var path_mode: int = 0:
	set(value):
		if path_mode == value: return
		path_mode = value

		refresh()


@export var path_text: String:
	get: return path_label.text if path_label else ""
	set(value):
		if not path_label: return
		path_label.text = value
		path_label.tooltip_text = value

		refresh()


@export_storage var value: String:
	get: return path_label.text if path_label else ""
	set(val):
		if not path_label or value == val: return
		path_text = val

		refresh()


@export_subgroup("Slot Label", "slot_")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var slot_enabled: bool = false:
	set(value):
		slot_enabled = value
		if not is_node_ready():
			await ready

		%slot_label.visible = slot_enabled


@export var slot_index: int = 0:
	set(value):
		slot_index = value
		%slot_label.text = ("L" if slot_index & 1 else "R") + str(slot_index / 2)


func set_value(val: String) -> void:
	value = val


var texture: Texture2D:
	get: return image_rect.texture
	set(value): image_rect.texture = value


func refresh() -> void:
	visible = not value.is_empty()

	var file_exists := FileAccess.file_exists(value)

	match path_mode:
		0:
			path_label.self_modulate = Color.WHITE if file_exists else Color.INDIAN_RED
			path_label.focus_mode = Control.FOCUS_CLICK
			path_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if file_exists else Control.CURSOR_FORBIDDEN
		1:
			path_label.self_modulate = Color.WHITE
			path_label.focus_mode = Control.FOCUS_NONE
			path_label.mouse_default_cursor_shape = Control.CURSOR_ARROW

	if not file_exists:
		texture = null
		return

	elif ResourceLoader.exists(value, "Texture2D"):
		texture = ResourceLoader.load(value, "Texture2D")

	else:
		var image := Image.new()
		image.load(value)
		texture = ImageTexture.new()
		texture.set_image(image)


func clear() -> void:
	value = ""


func _ready() -> void:
	refresh()


func _on_path_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			if ResourceLoader.exists(value):
				EditorInterface.get_file_system_dock().navigate_to_path(value)

			elif FileAccess.file_exists(value):
				OS.shell_show_in_file_manager(value)
