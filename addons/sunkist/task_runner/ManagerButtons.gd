@tool
extends GridContainer

@export
var buttons_disabled_while_running: Array[Button]


func _on_task_tree_started() -> void:
	for button in buttons_disabled_while_running:
		button.disabled = true


func _on_task_tree_stopped() -> void:
	for button in buttons_disabled_while_running:
		button.disabled = false
