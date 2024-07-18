class_name BlockNameTreeNode
extends Resource

@export var block_name: String
@export var children: Array[BlockNameTreeNode]


func _init(p_block_name: String = "", p_children: Array[BlockNameTreeNode] = []):
	block_name = p_block_name
	p_children = p_children
