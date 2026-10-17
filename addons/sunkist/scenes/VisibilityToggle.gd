@tool
extends CheckBox

@export
var link: Node


func _ready() -> void:
	if SunkistUtils.is_node_in_editor(self): return

	link.visibility_changed.connect(func() -> void:
		set_pressed_no_signal(link.visible)
	)
	toggled.connect(func(toggled_on: bool) -> void:
		link.visible = toggled_on
	)
