@tool
class_name TaskTemplate
extends Resource

@export
var name: String

@export_multiline
var description: String

@export
var icon: Texture2D

@export
var _scene_uid: String

var scene: PackedScene:
	get: return load(_scene_uid)


func create_button() -> Button:
	var result := Button.new()

	result.text = name
	result.tooltip_text = description
	result.icon = icon
	result.pressed.connect(create_task)

	return result


func create_task(become_selected: bool = true) -> Task:
	var result: Task = scene.instantiate()
	result.template = self

	TaskContainer.inst.add_child(result)
	TaskContainer.inst.visible = true
	result.visible = become_selected

	return result
