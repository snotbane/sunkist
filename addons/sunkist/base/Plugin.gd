@tool
extends EditorPlugin

class InspectorPlugin \
extends EditorInspectorPlugin:
	static var InspectorPreview := preload("res://addons/sunkist/scripts/SunkistTexture_InspectorPreview.gd")

	func _can_handle(object: Object) -> bool:
		return object is SunkistTexture

	func _parse_begin(object: Object) -> void:
		add_property_editor("", InspectorPreview.new())

static var inspector_plugin: InspectorPlugin


static var PreviewGenerator := preload("res://addons/sunkist/scripts/SunkistTexture_PreviewGenerator.gd")
var preview_generator: EditorResourcePreviewGenerator


func _enter_tree() -> void:
	inspector_plugin = InspectorPlugin.new()
	add_inspector_plugin(inspector_plugin)

	preview_generator = PreviewGenerator.new()
	EditorInterface.get_resource_previewer().add_preview_generator(preview_generator)

	EditorInterface.get_resource_filesystem().resources_reimported.connect(_resources_reimported)


func _exit_tree() -> void:
	remove_inspector_plugin(inspector_plugin)
	inspector_plugin = null

	EditorInterface.get_resource_previewer().remove_preview_generator(preview_generator)

	EditorInterface.get_resource_filesystem().resources_reimported.disconnect(_resources_reimported)


func _resources_reimported(resources: PackedStringArray) -> void:
	for path in resources:
		if path.get_extension() in SunkistSheet.VALID_EXTENSIONS:
			_sunkist_sheet_resource_reimported(path)


func _sunkist_sheet_resource_reimported(path: String) -> void:
	ResourceLoader.load(path, "", ResourceLoader.CacheMode.CACHE_MODE_IGNORE)
