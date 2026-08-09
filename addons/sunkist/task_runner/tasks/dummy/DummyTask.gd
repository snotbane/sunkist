@tool
extends Task

var _wait_time: float = 1.0
@export_range(0.0, 10.0, 0.5, "or_greater") var wait_time: float = 1.0:
	get: return _wait_time
	set(value):
		if _wait_time == value: return

		refresh_comment_if_default()
		_wait_time = value
		validate_args()

		_refresh_wait_time()
func _refresh_wait_time() -> void:
	$timer.wait_time = _wait_time
	$v_box_container/content/center_container/label.text = str(_wait_time)


func _get_default_comment() -> String:
	return "Waiting for %s seconds" % wait_time


func _validate_args() -> void:
	if wait_time <= 0.0:
		_errors.push_back("wait_time must be greater than 0.0.")


func _ready() -> void:
	super._ready()

	_refresh_wait_time()

	$timer.timeout.connect(finish.bind(OK))


func _process_running(delta: float) -> void:
	attempts_bar.value = 1.0 - ($timer.time_left / $timer.wait_time)
	progress_changed.emit()


func _start() -> void:
	$timer.start()


func _abort() -> bool:
	$timer.stop()

	return false
