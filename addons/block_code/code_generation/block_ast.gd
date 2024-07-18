class_name BlockAST
extends Object

var root: ASTNode


class ASTNode:
	var data  #: BlockStatementResource ONLY STATEMENT BLOCKS
	var children: Array[ASTNode]

	func _init():
		children = []

	func get_code(depth: int) -> String:
		var code: String = ""
		var block_code: String = data.generate_code()  # generate multiline string from statementblock

		block_code = block_code.indent("\t".repeat(depth))

		code += block_code + "\n"

		for child in children:
			code += child.get_code(depth + 1)

		return code


func get_code() -> String:
	return root.get_code(0)


func _to_string():
	return to_string_recursive(root, 0)


func to_string_recursive(node: ASTNode, depth: int) -> String:
	var string: String = "%s %s\n" % ["-".repeat(depth), node.data.block_format]

	for c in node.children:
		string += to_string_recursive(c, depth + 1)

	return string
