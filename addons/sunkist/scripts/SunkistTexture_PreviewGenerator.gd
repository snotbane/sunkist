@tool
extends EditorResourcePreviewGenerator

func _can_generate_small_preview() -> bool:
	return true


func _generate_small_preview_automatically() -> bool:
	return true


func _handles(type: String) -> bool:
	return type == "Texture2D"


func _generate(resource: Resource, size: Vector2i, metadata: Dictionary) -> Texture2D:
	if resource is not SunkistTexture:
		return null

	var image : Image = resource.texture_default.get_image()
	image.resize(size.x, size.y, Image.Interpolation.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


func _generate_from_path(path: String, size: Vector2i, metadata: Dictionary) -> Texture2D:
	if path.get_extension() not in [ "res", "tres" ]:
		return null

	return _generate(load(path), size, metadata)
