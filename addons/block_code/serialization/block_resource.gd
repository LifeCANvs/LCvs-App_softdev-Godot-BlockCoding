@tool
class_name BlockResource
extends Resource

@export var block_type: Types.BlockType
@export var block_format: String
@export var statement: String
@export var tooltip_text: String
@export var category: String
@export var defaults: Dictionary


func _init(p_block_type: Types.BlockType = Types.BlockType.EXECUTE, p_block_format: String = "", p_statement: String = "", p_tooltip_text: String = "", p_category: String = "", p_defaults = {}):
	block_type = p_block_type
	block_format = p_block_format
	statement = p_statement
	tooltip_text = p_tooltip_text
	category = p_category
	defaults = p_defaults


# Eventually these resources will be replaced with Manuel's


# VERY simple, just use statement no args
func generate_code() -> String:
	return statement
