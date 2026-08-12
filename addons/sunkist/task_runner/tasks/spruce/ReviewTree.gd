@tool class_name ReviewTree extends Tree

enum {
	FILE,
	BUTTONS,
}

enum {
	ACCEPT,
	INSPECT,
	REJECT,
}

enum {
	OLD,
	NEW,
	DIFF,
}


const ICON_ACCEPT := preload("res://addons/sunkist/ui/icons/ImportCheck.svg")

const ICON_INSPECT := preload("res://addons/sunkist/ui/icons/ExternalLink.svg")

const ICON_REJECT := preload("res://addons/sunkist/ui/icons/ImportFail.svg")


@export var task: PythonTask

@export var old_preview: ImagePreview

@export var new_preview: ImagePreview

@export var diff_bitmap: ImagePreview


var root: TreeItem

var source_paths: PackedStringArray

# var target_paths: PackedStringArray

var item_source_paths: Dictionary

var item_target_paths: Dictionary


func _ready() -> void:
	if SunkistUtils.is_node_in_editor(self): return

	item_selected.connect(_on_item_selected)
	button_clicked.connect(_on_button_clicked)

	self.set_column_expand(BUTTONS, false)
	refresh_files.call_deferred()


func clear_items() -> void:
	source_paths.clear()
	refresh_items()


func refresh_files() -> void:
	source_paths = get_files(task.itinerary.source)
	refresh_items()


func refresh_items() -> void:
	self.clear()
	item_source_paths.clear()
	root = self.create_item()
	for i in source_paths:
		add_path_item(i)


func add_path_item(path: String):
	var result := self.create_item(root)
	item_source_paths[result] = path

	if task.itinerary.target.is_empty():
		item_target_paths[result] = item_source_paths[result]
	else:
		var subdirpath := path.get_base_dir().right(-task.itinerary.source.length())
		if subdirpath:
			item_target_paths[result] = task.itinerary.target.path_join(subdirpath).path_join(path.get_file())
		else:
			item_target_paths[result] = task.itinerary.target.path_join(path.get_file())

	result.add_button(BUTTONS, ICON_ACCEPT, ACCEPT)
	result.set_button_tooltip_text(BUTTONS, ACCEPT, "Accept Changes")
	result.add_button(BUTTONS, ICON_INSPECT, INSPECT)
	result.set_button_tooltip_text(BUTTONS, INSPECT, "Manual Review")
	result.add_button(BUTTONS, ICON_REJECT, REJECT)
	result.set_button_tooltip_text(BUTTONS, REJECT, "Revert Changes")

	result.set_text(FILE, path.get_basename().get_file())
	result.set_tooltip_text(FILE, path)


func open_item(item: TreeItem) -> void:
	OS.shell_open(item_source_paths[item])
	OS.shell_open(get_temp_path(item_source_paths[item], DIFF))
	OS.shell_open(get_temp_path(item_source_paths[item], NEW))


func accept_item(item: TreeItem) -> void:
	DirAccess.copy_absolute(get_temp_path(item_source_paths[item], NEW), item_target_paths[item])

	remove_path_by_item(item)
	refresh_items()
	if item == get_selected():
		old_preview.clear()
		diff_bitmap.clear()


func reject_item(item: TreeItem) -> void:
	remove_path_by_item(item)
	refresh_items()
	if item == get_selected():
		new_preview.clear()
		# old_bitmap.clear()
		diff_bitmap.clear()


func remove_path_by_item(item: TreeItem) -> void:
	source_paths.erase(item_source_paths[item])
	DirAccess.remove_absolute(get_temp_path(item_source_paths[item], NEW))
	DirAccess.remove_absolute(get_temp_path(item_source_paths[item], DIFF))
	item_source_paths.erase(item)
	item_target_paths.erase(item)


func accept_all() -> void:
	for item in item_source_paths.keys():
		accept_item(item)


func reject_all() -> void:
	for item in item_source_paths.keys():
		reject_item(item)


func _on_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	set_selected(item, FILE)
	var next := clampi(item.get_index() + 1, 0, self.source_paths.size() - 1)
	match id:
		ACCEPT: accept_item(item); select_tree_item_by_index(next)
		INSPECT: open_item(item)
		REJECT: reject_item(item); select_tree_item_by_index(next)


func _on_item_selected() -> void:
	var selected := get_selected()
	var path: String = item_source_paths[selected] if selected and item_source_paths.has(selected) else ""
	old_preview.value = get_temp_path(path, OLD)
	new_preview.value = get_temp_path(path, NEW)
	diff_bitmap.value = get_temp_path(path, DIFF)


func get_files(path: String) -> PackedStringArray:
	if DirAccess.dir_exists_absolute(path):
		return get_all_matching_files(path, task.itinerary.include_regex, task.itinerary.exclude_regex)
	elif FileAccess.file_exists(path):
		if FileAccess.file_exists(get_temp_path(path, NEW)):
			return [path]
	return []


func get_all_matching_files(path: String, include: RegEx, exclude: RegEx) -> PackedStringArray:
	var dir := DirAccess.open(path)
	if not dir.dir_exists(path): return []

	var result: PackedStringArray = []

	dir.list_dir_begin()
	var file := dir.get_next()
	while file:
		var full_path := path.path_join(file)
		if dir.current_is_dir():
			result.append_array(get_all_matching_files(full_path, include, exclude))
		else:
			if (
				(include.get_pattern() == "" or include.search(file.get_basename()) != null)
				and (exclude.get_pattern() == "" or exclude.search(file.get_basename()) == null)
				and FileAccess.file_exists(get_temp_path(full_path, NEW))
			):
				result.push_back(full_path)
		file = dir.get_next()
	dir.list_dir_end()
	return result


func get_temp_path(old: String, type: int) -> String:
	if type == OLD: return old

	var file: String = old.get_file()

	var p_root := Task.TEMP_DIR_PATH
	var suffix: String
	match type:
		NEW: suffix = "__new"
		DIFF: suffix = "__diff"

	var result := p_root

	var subdirpath := old.get_base_dir().right(-task.itinerary.source.length())
	if subdirpath:
		result = result.path_join(subdirpath)

	result = result.path_join("%s%s.%s" % [file.get_basename(), suffix, file.get_extension()])
	return result


func select_tree_item_by_index(idx: int) -> void:
	if root == null:
		return

	var queue: Array = [root]
	var current_index = 0

	while queue.size() > 0:
		var item: TreeItem = queue.pop_front()
		if current_index == idx:
			self.set_selected(item, FILE)
			return
		current_index += 1

		var child = item.get_first_child()
		while child:
			queue.append(child)
			child = child.get_next()
