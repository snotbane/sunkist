@tool
extends EditorPlugin

var PREVIEW_GENERATOR_SCRIPT := preload("res://addons/sunkist/scripts/SunkistTexture_PreviewGenerator.gd")
var preview_generator: EditorResourcePreviewGenerator


var MAIN_SCENE := preload("res://addons/sunkist/scenes/SunkistViewer.tscn")
var main: SunkistSheetViewer


func _get_plugin_name() -> String:
	return "Sunkist Preview"


func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/sunkist/ui/icons/layers.svg")


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if main:
		main.visible = visible


func _handles(object: Object) -> bool:
	return object is SunkistTexture


func _edit(object: Object) -> void:
	if main == null: return

	main.edit(object)


func _enter_tree() -> void:
	preview_generator = PREVIEW_GENERATOR_SCRIPT.new()
	# print(preview_generator)
	EditorInterface.get_resource_previewer().add_preview_generator(preview_generator)
	EditorInterface.get_resource_filesystem().resources_reimported.connect(_resources_reimported)

	if main != null: return

	main = MAIN_SCENE.instantiate()
	EditorInterface.get_editor_main_screen().add_child(main)
	_make_visible(false)


func _exit_tree() -> void:
	EditorInterface.get_resource_previewer().remove_preview_generator(preview_generator)
	EditorInterface.get_resource_filesystem().resources_reimported.disconnect(_resources_reimported)

	if main == null: return

	main.queue_free.call_deferred()
	main = null


func _resources_reimported(resources: PackedStringArray) -> void:
	for path in resources:
		if path.get_extension() in SunkistSheet.VALID_EXTENSIONS:
			_sunkist_sheet_resource_reimported(path)


func _sunkist_sheet_resource_reimported(path: String) -> void:
	ResourceLoader.load(path, "", ResourceLoader.CacheMode.CACHE_MODE_IGNORE)
