class_name BlockNameTree
extends Resource

@export var root: BlockNameTreeNode
@export var canvas_position: Vector2


func _init(p_root: BlockNameTreeNode = null, p_canvas_position: Vector2 = Vector2(0, 0)):
	root = p_root
	canvas_position = p_canvas_position
