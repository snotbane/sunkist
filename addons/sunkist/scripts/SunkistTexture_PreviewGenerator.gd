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

	var texture : Texture2D = resource.texture_default
	var image: Image
	if texture is AtlasTexture:
		image = texture.atlas.get_image()
	else:
		image = texture.get_image()

	if image.is_compressed():
		var err := image.decompress()
		if err:
			printerr(error_string(err))
			return

	if texture is AtlasTexture:
		var square_size := maxi(texture.region.size.x, texture.region.size.y)
		var square_offset := Vector2i(
			(square_size / 2 - texture.region.size.x / 2) if texture.region.size.y > texture.region.size.x else 0,
			(square_size / 2 - texture.region.size.y / 2) if texture.region.size.y < texture.region.size.x else 0
		)

		var src := image
		image = Image.new()
		image.copy_from(src)
		image.fill(Color.TRANSPARENT)
		image.crop(square_size, square_size)
		image.blit_rect(src, texture.region, square_offset)

	image.resize(size.x, size.y, Image.Interpolation.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


func _generate_from_path(path: String, size: Vector2i, metadata: Dictionary) -> Texture2D:
	return _generate(load(path), size, metadata)
