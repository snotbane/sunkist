@tool
extends Node3D


var _edited_resource: SunkistTexture
@export
var edited_resource: SunkistTexture:
	get: return _edited_resource
	set(value):
		if _edited_resource == value: return
		_edited_resource = value

		if not is_node_ready(): await ready

		%sunkist.texture = _edited_resource


@onready var in_edited_scene: bool = owner == null
@onready var viewport: SubViewport = get_parent()
@onready var fov_onready: float = %camera.fov


func _process(delta: float) -> void:
	var viewport_ratio := 1.0

	if viewport and not in_edited_scene:
		var viewport_size: Vector2 = viewport.size
		viewport_ratio = minf(viewport_size.x, viewport_size.y) / maxf(viewport_size.x, viewport_size.y)
		%camera.fov = lerpf(179.0, fov_onready, sqrt(viewport_ratio))

	if %sunkist.texture:
		var texture_size: Vector2 = %sunkist.texture.get_size()
		%sunkist.pixel_size = viewport_ratio / (maxf(texture_size.x, texture_size.y))


func edit(resource: SunkistTexture) -> void:
	edited_resource = resource
