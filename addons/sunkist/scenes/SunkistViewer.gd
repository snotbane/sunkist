@tool
class_name SunkistSheetViewer
extends Control

const IMAGE_PREVIEW_SCENE: PackedScene = preload("uid://3djnsrgpqbb1")


signal edited(resource: SunkistTexture)


@onready var grid: GridContainer = $split/composite/grid


@export_storage var resource: SunkistTexture


func edit(__resource__: Object) -> void:
	if __resource__ is not SunkistTexture:
		return

	resource = __resource__

	for child in grid.get_children():
		child.queue_free.call_deferred()

	for i in resource.textures.size():
		var j := i - 1 if i & 1 else i + 1
		var texture := resource.textures[j]
		if texture == null: continue

		var image_preview: ImagePreview = IMAGE_PREVIEW_SCENE.instantiate()
		grid.add_child(image_preview)
		image_preview.path_mode = 1
		image_preview.value = texture.resource_path
		image_preview.visible = true
		image_preview.slot_enabled = true
		image_preview.slot_index = j


	edited.emit(resource)
