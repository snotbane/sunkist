@tool
class_name TaskRunner
extends Node

const CONFIG_PATH := "user://settings.cfg"
const ROOT_PYTHON_EXE := "python3"

static var inst: TaskRunner

static var config: ConfigFile


var install_venv_dialog: ConfirmationDialog


@export_global_dir var python_venv_path: String = "res://addons/sunkist/.venv":
	get: return get_meta(&"python_venv_path", "")
	set(value):
		if python_venv_path == value: return
		set_meta(&"python_venv_path", value)
		save_settings()
var python_exe_path: String:
	get: return ProjectSettings.globalize_path(python_venv_path.path_join("bin").path_join("python3"))

@export_tool_button("Create Python Venv") var install_venv_button := func() -> void:
	install_venv_dialog.dialog_text = "This will install a python virtual environment at:\n%s" % SunkistUtils.get_project_preferred_path(python_venv_path)
	if not python_venv_path.ends_with(".venv"): install_venv_dialog.dialog_text += "\nWarning! It is recommended that the destination folder is called \".venv\" !"
	install_venv_dialog.popup_centered()
func install_venv() -> void:
	PythonTask.execute_static(ROOT_PYTHON_EXE, ["-m", "venv", ProjectSettings.globalize_path(python_venv_path)])


@export_tool_button("Install Pillow to Venv") var _install_PIL := func() -> void:
	PythonTask.execute_static(python_exe_path, ["-m", "pip", "install", "Pillow"])


@export_tool_button("Reveal Config File") var reveal_settings := func() -> void:
	OS.shell_open(ProjectSettings.globalize_path(CONFIG_PATH))


func _ready() -> void:
	if SunkistUtils.is_node_in_editor(self): return

	inst = self

	install_venv_dialog = ConfirmationDialog.new()
	install_venv_dialog.title = "Installing Python Virtual Environment"
	install_venv_dialog.confirmed.connect(install_venv)
	add_child(install_venv_dialog)

	if FileAccess.file_exists(CONFIG_PATH):
		load_settings()
	else:
		save_settings()


func load_settings() -> void:
	if not config:
		config = ConfigFile.new()

	config.load(CONFIG_PATH)

	for k in config.get_section_keys("metadata"):
		set_meta(k, config.get_value("metadata", k))


func save_settings() -> void:
	if not config:
		config = ConfigFile.new()

	for meta in get_meta_list():
		config.set_value("metadata", meta, get_meta(meta))

	config.save(CONFIG_PATH)
