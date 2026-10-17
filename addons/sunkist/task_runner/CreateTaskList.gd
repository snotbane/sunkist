@tool
extends HFlowContainer

var _templates: Array[TaskTemplate]
@export
var templates: Array[TaskTemplate]:
	get: return _templates
	set(value):
		if _templates == value: return
		_templates = value

		for child in get_children():
			remove_child(child)

		for template in _templates:
			if not template: continue
			add_child(template.create_button())
