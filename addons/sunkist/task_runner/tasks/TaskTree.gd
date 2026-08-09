@tool
class_name TaskTree
extends Tree

enum {
	TEMPLATE,
	COMMENT,
	STATUS,
	BUTTONS,
}

enum {
	EXECUTE,
	COPY,
	REMOVE,
}


const JSON_IDENTIFIER := "Sunkist"

const TEMP_JSON_PATH := "user://temp_queue.json"


static var inst: TaskTree


signal started

signal stop_requested

signal stopped


var root: TreeItem

var tasks: Array[Node]

var task_count: int:
	get: return tasks.size()

var task_items: Dictionary

var buttons: Dictionary

var dragged_item: TreeItem

var running: bool


var selected_task: Task:
	get: return find_task(get_selected())


func _ready() -> void:
	if SunkistUtils.is_node_in_editor(self): return

	inst = self

	for i in columns: set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)

	set_column_expand(BUTTONS, false)
	set_column_expand_ratio(COMMENT, 6)

	set_column_title(TEMPLATE, "Type")
	set_column_title(COMMENT, "Comment")
	set_column_title(STATUS, "Status")
	set_column_title(BUTTONS, "Actions")

	set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)

	await get_tree().process_frame

	tasks = TaskContainer.inst.get_children()


func _process(delta: float) -> void:
	var color := lerp(Color.DARK_SLATE_GRAY, Color.SLATE_GRAY, remap(sin(float(Time.get_ticks_msec()) * PI / 1000.0), -1.0, 1.0, 0.0, 1.0))
	for task in task_items:
		if task == null or not task.running: continue
		var item: TreeItem = task_items[task]
		for i in columns:
			item.set_custom_bg_color(i, color)


#region Drag and Drop

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var target := get_item_at_position(at_position)
	if not target: return

	var target_index := get_item_index(target)
	if target_index == -1: return

	var section := get_drop_section_at_position(at_position)
	var delta: int = target_index - data
	if delta != 0:
		reorder_item(dragged_item, delta + (mini(section, 0) if signi(delta) > 0 else maxi(section, 0)))
		if dragged_item: dragged_item.free()
	drop_mode_flags = DROP_MODE_DISABLED


func _get_drag_data(at_position: Vector2) -> Variant:
	dragged_item = get_item_at_position(at_position)
	if not dragged_item: return null

	drop_mode_flags = DROP_MODE_INBETWEEN

	var drag_preview = Label.new()
	drag_preview.text = dragged_item.get_text(COMMENT)
	set_drag_preview(drag_preview)

	return get_item_index(dragged_item)

#endregion
#region Queue Flow

func start_queue() -> void:
	if running: return
	running = true
	started.emit()
	for task in tasks:
		if not running: break
		await task.run()
	running = false
	stopped.emit()


func stop_queue():
	if not running: return
	running = false
	for task in tasks:
		await task.abort()
	stopped.emit()

#endregion
#region Item Querying

func get_item_index(item: TreeItem) -> int:
	var parent = item.get_parent()
	var i = 0
	var child = parent.get_first_child()
	while child:
		if child == item:
			return i
		i += 1
		child = child.get_next()
	return -1


func refresh_items() -> void:
	clear()
	task_items.clear()
	root = create_item()
	for task in tasks:
		if task == null or task.is_queued_for_deletion(): continue
		add_task_item(task)


func find_task(item: TreeItem) -> Task:
	if item == null: return null
	for i in tasks:
		if i not in task_items: continue
		if task_items[i] == item: return i
	return null

#endregion
#region Item Manipulation

func add_task(task: Task) -> TreeItem:
	tasks.push_back(task)
	# task.tree_exited.connect(task_items.erase.bind(task))
	task.comment_changed.connect(refresh_task_comment.bind(task))
	task.status_changed.connect(refresh_task_status.bind(task))
	task.attempts_changed.connect(refresh_task_progress.bind(task))
	var result := add_task_item(task)

	if task.visible:
		set_selected.call_deferred(result, 0)

	return result


func add_task_item(task: Task) -> TreeItem:
	var result := create_item(root)
	task_items[task] = result

	for i in columns:
		if i >= BUTTONS: break
		result.set_selectable(i, true)

	if task.template:
		result.set_text(TEMPLATE, task.template.name)

	result.add_button(BUTTONS, Task.PLAY_ICON, EXECUTE)
	result.add_button(BUTTONS, Task.COPY_ICON, COPY)
	result.set_button_tooltip_text(BUTTONS, COPY, "Duplicate")
	result.add_button(BUTTONS, Task.REMOVE_ICON, REMOVE)
	result.set_button_tooltip_text(BUTTONS, REMOVE, "Remove")

	refresh_task_comment(task)
	refresh_task_status(task)

	return result


func remove_task(task: Task) -> void:
	if task.running: return

	if TaskContainer.inst.current_task == task:
		TaskContainer.inst.current_task = null

	tasks.erase(task)

	refresh_items()


func remove_item(item: TreeItem) -> void:
	remove_task(find_task(item))


func remove_all_tasks() -> void:
	for task in tasks:
		remove_task(task)
	refresh_items()


func reorder_task(task: Task, amount: int) -> void:
	var idx := tasks.find(task)
	# tasks.remove_at(idx)
	idx = clampi(idx + amount, 0, task_count)
	# tasks.insert(idx, task)
	TaskContainer.inst.move_child(task, idx)

	refresh_items()


func reorder_item(item: TreeItem, amount: int) -> void:
	reorder_task(find_task(item), amount)


func copy_task(task: Task) -> void:
	var copy := task.duplicate()
	task.add_sibling(copy)
	open_task(copy)


func copy_item(item: TreeItem) -> void:
	copy_task(find_task(item))


func open_task(task: Task) -> void:
	if task: task.visible = true
	else: TaskContainer.inst.current_tab = -1


func open_item(item: TreeItem) -> void:
	open_task(find_task(item))


func reset_all() -> void:
	for task in tasks:
		task.reset()


func execute_task(task: Task) -> void:
	match task.status:
		Task.QUEUED:
			task.start()
		Task.RUNNING:
			if running:
				stop_queue()
			else:
				task.abort(true)
		Task.SUCCEEDED, Task.FAILED:
			task.reset()


func execute_item(item: TreeItem) -> void:
	execute_task(find_task(item))


func refresh_task_status(task: Task) -> void:
	var item: TreeItem = task_items[task]

	var text: String
	var tooltip: String
	var icon: Texture2D = null
	match task.status:
		Task.QUEUED:
			text = "Ready"
			tooltip = "Run"
			icon = Task.PLAY_ICON
		Task.INVALID:
			text = "Invalid"
			tooltip = "Can't run due to errors:\n" + task.error_tooltip_text
			icon = Task.PLAY_ICON
		Task.RUNNING:
			text = ""
			tooltip = "Stop"
			icon = Task.STOP_ICON
		Task.ABORTING:
			text = "Stopping"
			tooltip = "Stopping. Please wait..."
			icon = Task.STOP_ICON
		Task.SUCCEEDED:
			text = "Completed"
			tooltip = "Reset"
			icon = Task.RESET_ICON
		Task.FAILED:
			text = "Failed"
			tooltip = "Reset"
			icon = Task.RESET_ICON

	item.set_text(STATUS, text)
	item.set_tooltip_text(STATUS, task.error_tooltip_text)
	item.set_button_tooltip_text(BUTTONS, EXECUTE, tooltip)
	item.set_button(BUTTONS, EXECUTE, icon)

	for i in columns:
		match task.status:
			Task.QUEUED:
				item.clear_custom_color(i)
				item.clear_custom_bg_color(i)
			Task.RUNNING, Task.ABORTING:
				item.set_custom_color(i, Color.WHITE)
				item.set_custom_bg_color(i, Color.SEA_GREEN)
			Task.SUCCEEDED:
				item.set_custom_color(i, Color.DIM_GRAY)
				item.clear_custom_bg_color(i)
			Task.FAILED, Task.INVALID:
				item.set_custom_color(i, Color.WHITE)
				item.set_custom_bg_color(i, Color.INDIAN_RED)

	item.set_button_disabled(BUTTONS, REMOVE, task.status == Task.RUNNING or task.status == Task.ABORTING)
	item.set_button_disabled(BUTTONS, EXECUTE, task.status == Task.INVALID or task.status == Task.ABORTING)


	refresh_task_progress(task)


func refresh_task_progress(task: Task) -> void:
	if task.status != Task.RUNNING: return
	var item: TreeItem = task_items[task]
	var progress := floori(task.attempts_percent * 100.0)
	item.set_text(STATUS, "%s%%" % progress)


func refresh_task_comment(task: Task) -> void:
	var item: TreeItem = task_items[task]
	item.set_text(COMMENT, task.comment)
	item.set_tooltip_text(COMMENT, task.comment)

#endregion
#region Save/Load

func save_json(path: String = TEMP_JSON_PATH) -> void:
	var json_file := FileAccess.open(path, FileAccess.WRITE)
	var json := {
		&"type": JSON_IDENTIFIER,
		&"data": tasks.map(func(e: Task): return e.save_args())
	}
	json_file.store_string(JSON.stringify(json))


func load_json(path: String = TEMP_JSON_PATH, append: bool = false) -> void:
	if not FileAccess.file_exists(path):
		printerr("File at path '%s' does not exist." % path)
		return

	if not append:
		remove_all_tasks()

	var json_file := FileAccess.open(path, FileAccess.READ)
	var json: Dictionary = JSON.parse_string(json_file.get_as_text())

	if json.get(&"type") != JSON_IDENTIFIER:
		printerr("File at path '%s' cannot be loaded because it is not a Sunkist task list.")
		return

	for data in json[&"data"]:
		var template: TaskTemplate = load(data[&"template_uid"])
		var task := template.create_task(false)
		task.load_args(data)


#endregion
#region Signal Events

func _on_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	match id:
		EXECUTE: execute_item(item)
		# OPEN: open_item(item)
		COPY: copy_item(item)
		REMOVE: remove_item(item)


func _on_run_stop_toggled(toggled_on: bool) -> void:
	if toggled_on: start_queue()
	else: stop_queue()


func _on_item_selected() -> void:
	open_task(selected_task)


func _on_empty_clicked(click_position: Vector2, mouse_button_index: int) -> void:
	open_task(null)
	deselect_all()

#endregion
