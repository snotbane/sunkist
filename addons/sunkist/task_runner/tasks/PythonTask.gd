@abstract
@tool
class_name PythonTask
extends Task

const ABORT_KEY := "stop"


static func restr(str: String) -> String:
	return "/%s/" % str


static func localize_script_path(path: String) -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path(path)
	else:
		var result: String = path.substr(path.rfind("/") + 1)
		return OS.get_executable_path().get_base_dir().path_join("execute").path_join(result)


static func value_as_python_argument(value: Variant) -> String:
	if value is float and fmod(value, 1.0) == 0.0:
		return str(int(value))
	return str(value)


@export_global_dir var python_venv_path: String:
	get: return TaskRunner.inst.python_venv_path
	set(value):
		if not is_node_ready():
			await ready

		TaskRunner.inst.python_venv_path = value

@export var itinerary: TaskItinerary:
	set(value):
		if itinerary == value: return

		if itinerary:
			if itinerary.changed.is_connected(validate_args):
				itinerary.changed.disconnect(validate_args)

		refresh_comment_if_default()
		itinerary = value
		validate_args()

		if itinerary:
			if not itinerary.changed.is_connected(validate_args):
				itinerary.changed.connect(validate_args)


# @export_tool_button("Install Python Venv") var install_venv_button := TaskRunner.inst.install_venv_button


var python_exe_path: String:
	get: return TaskRunner.inst.python_exe_path


var python_script_path: String:
	get: return _get_python_script_path()


var temp_dir: DirAccess

var bus: ConfigFile

var bus_path: String

var thread: Thread


@abstract
func _get_python_script_path() -> String


@abstract
func _get_python_arguments() -> Array


func _get_default_comment() -> String:
	return "%s :: %s" % [super._get_default_comment(), itinerary]


func _save_args(result: Dictionary) -> void:
	result.merge({
		&"itinerary": itinerary.save_args()
	})


func _load_args(data: Dictionary) -> void:
	itinerary = TaskItinerary.new()
	itinerary.load_args(data[&"itinerary"])


func _validate_args() -> void:
	validate_itinerary(itinerary)


func get_python_arguments() -> PackedStringArray:
	var result: PackedStringArray
	result.push_back(PythonTask.localize_script_path(python_script_path))
	result.push_back(ProjectSettings.globalize_path(bus_path))
	result.push_back(itinerary.serialize())
	result.append_array(_get_python_arguments().map(func(e: Variant) -> String:
		return PythonTask.value_as_python_argument(e)
	))
	return result


func _ready() -> void:
	super._ready()

	var user_dir := DirAccess.open("user://")
	if not user_dir.dir_exists("temp"):
		user_dir.make_dir("temp")

	temp_dir = user_dir.open(Task.TEMP_DIR_PATH)

	bus_path = temp_dir.get_current_dir().path_join("%s_%s.cfg" % [
		name,
		get_instance_id()
	])

	thread = Thread.new()


func _exit_tree() -> void:
	temp_dir.remove(bus_path)


func _process_running(delta: float) -> void:
	super._process_running(delta)

	if thread.is_alive():
		refresh_elements()
	else:
		_thread_stopped()


func _thread_stopped() -> void:
	var code := thread.wait_to_finish()

	refresh_elements()
	temp_dir.remove(bus_path)
	bus = null

	finish(code)


func _start() -> void:
	bus = ConfigFile.new()
	bus.save(bus_path)

	var code: int = thread.start(execute.bind(python_exe_path, get_python_arguments()))
	if code == OK: return

	finish(code)


func _abort() -> bool:
	bus.set_value("input", ABORT_KEY, true)
	bus.save(bus_path)

	return true


func execute(cmd: String, args: PackedStringArray) -> int:
	return execute_static(cmd, args)
static func execute_static(cmd: String, args: PackedStringArray, print_output: bool = true) -> int:
	# print("args : %s" % [args])
	var output: Array
	var result: int = OS.execute(cmd, args, output, print_output)
	if print_output:
		for e in output:
			match result:
				ERR_SKIP: continue
				OK: print(e)
				_: printerr(e)
	return result


func refresh_elements() -> void:
	bus.load(bus_path)
	_bus_poll()


func _bus_poll() -> void:
	attempts_bar.value = bus.get_value("output", "attempts", 0)
	attempts_bar.max_value = bus.get_value("output", "progress_max", 1)

	progress_bar.value = bus.get_value("output", "progress", 0)
	progress_bar.max_value = attempts_bar.max_value

	items_completed_label.text = "%s of %s completed" % [int(progress_bar.value), int(progress_bar.max_value)]

	progress_changed.emit()
