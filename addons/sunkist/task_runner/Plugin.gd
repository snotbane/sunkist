@tool
extends EditorPlugin

const MAIN_SCENE := preload("uid://ef5hvftp4smh")


var main: Control


func _get_plugin_name() -> String:
	return "Tasks"


func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/sunkist/ui/icons/Stiletto.svg")


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if main:
		main.visible = visible


func _enable_plugin() -> void:
	# Add autoloads here.
	_enter_tree()


func _disable_plugin() -> void:
	# Remove autoloads here.
	_exit_tree()


func _enter_tree() -> void:
	if main != null: return

	main = MAIN_SCENE.instantiate()
	EditorInterface.get_editor_main_screen().add_child(main)
	_make_visible(false)

	if FileAccess.file_exists(TaskTree.TEMP_JSON_PATH):
		TaskTree.inst.load_json.call_deferred()
	else:
		TaskTree.inst.save_json.call_deferred()


func _exit_tree() -> void:
	if main == null: return

	TaskTree.inst.save_json()

	main.queue_free.call_deferred()
	main = null
