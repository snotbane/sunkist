@icon("res://addons/sunkist/ui/icons/SunkistTexture.svg")
@tool
class_name SunkistTexture
extends Texture2D

@export var textures: Array[Texture2D]


var texture_default: Texture2D:
	get: return textures[0]


var offset_default: Vector2:
	get: return texture_default.offset if texture_default is SunkistAtlasTexture else Vector2.ZERO


var texture_slots: int:
	get: return textures.size()


func _get_texture_slots() -> int:
	return 8


func _init() -> void:
	textures.resize(_get_texture_slots())


func get_texture_slot(backface: bool, component: int) -> int:
	var idx := component * 2 + int(backface)
	assert(idx >= 0 and idx < texture_slots, "Texture slot %s doesn't exist on SunkistTexture '%s'" % [idx, resource_path])
	return idx


## Sets the texture in the slot based on [param backface] and [param component]. Returns the non-backface texture if the backface texture is null.
func get_texture(backface: bool = false, component: int = 0) -> Texture2D:
	var idx := get_texture_slot(backface, component)
	return textures[idx - 1] if backface and textures[idx] == null else textures[idx]


## Sets the texture in the slot based on [param backface] and [param component]. Returns the slot index.
func set_texture(backface: bool, component: int, texture: Texture2D) -> int:
	var idx := get_texture_slot(backface, component)
	assert(idx >= 0 and idx < texture_slots, "Texture slot %s doesn't exist on SunkistTexture '%s'" % [idx, resource_path])
	textures[idx] = texture
	return idx


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	if not Engine.is_editor_hint(): return
	texture_default.draw(to_canvas_item, pos, modulate, transpose)


func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	if not Engine.is_editor_hint(): return
	texture_default.draw_rect(to_canvas_item, rect, tile, modulate, transpose)


func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	if not Engine.is_editor_hint(): return
	texture_default.draw_rect_region(to_canvas_item, rect, src_rect, modulate, transpose, clip_uv)


func _get_width() -> int:
	return texture_default.get_width() if texture_default else 0


func _get_height() -> int:
	return texture_default.get_height() if texture_default else 0


# func _is_pixel_opaque(x: int, y: int) -> bool:
# 	return texture_default.is_pixel_opaque(x, y)


func _has_alpha() -> bool:
	return texture_default.has_alpha() if texture_default else true
