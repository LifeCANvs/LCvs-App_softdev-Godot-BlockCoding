@tool
class_name BasicBlock
extends Block

@export var label: String = "":
	set = _set_label

@onready var _top_bar := %TopBar
@onready var _label := %Label


func _set_label(new_label: String) -> void:
	label = new_label

	if not is_node_ready():
		return

	_label.text = label


func _ready():
	super()

	_top_bar.color = color

	_set_label(label)


func _on_drag_drop_area_mouse_down():
	_drag_started()
