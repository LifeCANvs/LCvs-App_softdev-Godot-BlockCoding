@tool
class_name BlockCanvas
extends MarginContainer

const Util = preload("res://addons/block_code/ui/util.gd")

const EXTEND_MARGIN: float = 800
const BLOCK_AUTO_PLACE_MARGIN: Vector2 = Vector2(25, 8)
const DEFAULT_WINDOW_MARGIN: Vector2 = Vector2(25, 25)
const SNAP_GRID: Vector2 = Vector2(25, 25)
const ZOOM_FACTOR: float = 1.1

@onready var _window: Control = %Window
@onready var _empty_box: BoxContainer = %EmptyBox

@onready var _selected_node_box: BoxContainer = %SelectedNodeBox
@onready var _selected_node_label: Label = %SelectedNodeBox/Label
@onready var _selected_node_label_format: String = _selected_node_label.text

@onready var _selected_node_with_block_code_box: BoxContainer = %SelectedNodeWithBlockCodeBox
@onready var _selected_node_with_block_code_label: Label = %SelectedNodeWithBlockCodeBox/Label
@onready var _selected_node_with_block_code_label_format: String = _selected_node_with_block_code_label.text

@onready var _add_block_code_button: Button = %AddBlockCodeButton
@onready var _open_scene_button: Button = %OpenSceneButton
@onready var _replace_block_code_button: Button = %ReplaceBlockCodeButton

@onready var _open_scene_icon = _open_scene_button.get_theme_icon("Load", "EditorIcons")

@onready var _mouse_override: Control = %MouseOverride
@onready var _zoom_label: Label = %ZoomLabel

var _current_bsd: BlockScriptData
var _current_ast_list: ASTList
var _block_scenes_by_class = {}
var _panning := false
var zoom: float:
	set(value):
		_window.scale = Vector2(value, value)
		_zoom_label.text = "%.1fx" % value
	get:
		return _window.scale.x

signal reconnect_block(block: Block)
signal add_block_code
signal open_scene
signal replace_block_code


func _ready():
	if not _open_scene_button.icon and not Util.node_is_part_of_edited_scene(self):
		_open_scene_button.icon = _open_scene_icon
	_populate_block_scenes_by_class()


func _populate_block_scenes_by_class():
	for _class in ProjectSettings.get_global_class_list():
		if not _class.base.ends_with("Block"):
			continue
		var _script = load(_class.path)
		if not _script.has_method("get_scene_path"):
			continue
		_block_scenes_by_class[_class.class] = _script.get_scene_path()


func add_block(block: Block, position: Vector2 = Vector2.ZERO) -> void:
	if block is EntryBlock:
		block.position = canvas_to_window(position).snapped(SNAP_GRID)
	else:
		block.position = canvas_to_window(position)

	_window.add_child(block)


func get_blocks() -> Array[Block]:
	var blocks: Array[Block] = []
	for child in _window.get_children():
		var block = child as Block
		if block:
			blocks.append(block)
	return blocks


func arrange_block(block: Block, nearby_block: Block) -> void:
	add_block(block)
	var rect = nearby_block.get_global_rect()
	rect.position += (rect.size * Vector2.RIGHT) + BLOCK_AUTO_PLACE_MARGIN
	block.global_position = rect.position


func set_child(n: Node):
	n.owner = _window
	for c in n.get_children():
		set_child(c)


func bsd_selected(bsd: BlockScriptData):
	clear_canvas()

	var edited_node = EditorInterface.get_inspector().get_edited_object() as Node

	if bsd != _current_bsd:
		_window.position = Vector2(0, 0)
		zoom = 1

	_window.visible = false
	_zoom_label.visible = false

	_empty_box.visible = false
	_selected_node_box.visible = false
	_selected_node_with_block_code_box.visible = false
	_add_block_code_button.disabled = true
	_open_scene_button.disabled = true
	_replace_block_code_button.disabled = true

	if bsd != null:
		_load_bsd(bsd)
		_window.visible = true
		_zoom_label.visible = true

		if bsd != _current_bsd:
			reset_window_position()
	elif edited_node == null:
		_empty_box.visible = true
	elif BlockCodePlugin.node_has_block_code(edited_node):
		# If the selected node has a block code node, but BlockCodePlugin didn't
		# provide it to bsd_selected, we assume the block code itself is not
		# editable. In that case, provide options to either edit the node's
		# scene file, or override the BlockCode node. This is mostly to avoid
		# creating a situation where a node has multiple BlockCode nodes.
		_selected_node_with_block_code_box.visible = true
		_selected_node_with_block_code_label.text = _selected_node_with_block_code_label_format.format({"node": edited_node.name})
		_open_scene_button.disabled = false if edited_node.scene_file_path else true
		_replace_block_code_button.disabled = false
	else:
		_selected_node_box.visible = true
		_selected_node_label.text = _selected_node_label_format.format({"node": edited_node.name})
		_add_block_code_button.disabled = false

	_current_bsd = bsd


func _load_bsd(bsd: BlockScriptData):
	_current_ast_list = ASTList.new()

	for name_tree in bsd.block_name_trees:
		var ast: BlockAST = ast_from_name_tree(name_tree)
		_current_ast_list.append(ast, name_tree.canvas_position)

	reload_ui_from_ast_list()


func reload_ui_from_ast_list():
	for ast_pair in _current_ast_list.array:
		var root_block = ui_tree_from_ast_node(ast_pair.ast.root)
		root_block.position = ast_pair.canvas_position
		_window.add_child(root_block)


func ui_tree_from_ast_node(ast_node: BlockAST.ASTNode) -> Block:
	var block: Block = CategoryFactory.construct_block_from_resource(ast_node.data)

	var current_block: Block = block

	var i: int = 0
	for c in ast_node.children:
		var child_block: Block = ui_tree_from_ast_node(c)

		if i == 0:
			current_block.child_snap.add_child(child_block)
		else:
			current_block.bottom_snap.add_child(child_block)

		current_block = child_block

	return block


func scene_has_bsd_nodes() -> bool:
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		return false
	return scene_root.find_children("*", "BlockCode").size() > 0


func clear_canvas():
	for child in _window.get_children():
		_window.remove_child(child)
		child.queue_free()


func ast_from_name_tree(tree: BlockNameTree) -> BlockAST:
	var ast: BlockAST = BlockAST.new()
	ast.root = ast_from_name_tree_recursive(tree.root)
	return ast


func ast_from_name_tree_recursive(node: BlockNameTreeNode):
	var ast_node := BlockAST.ASTNode.new()
	var block_resource: BlockResource = CategoryFactory.get_block_resource_from_name(node.block_name)
	ast_node.data = block_resource

	var children: Array[BlockAST.ASTNode] = []

	for c in node.children:
		children.append(ast_from_name_tree_recursive(c))

	ast_node.children = children

	return ast_node


func rebuild_ast_list():
	var _current_ast_list = []
	for c in _window.get_children():
		var root: BlockAST.ASTNode = build_tree(c)
		var ast: BlockAST = BlockAST.new()
		ast.root = root
		_current_ast_list.append(ast)

	print(_current_ast_list[0])


func build_tree(block: Block) -> BlockAST.ASTNode:
	var ast_node := BlockAST.ASTNode.new()
	ast_node.data = block.block_resource

	var children: Array[BlockAST.ASTNode] = []

	if block.child_snap:
		var child: Block = block.child_snap.get_snapped_block()

		while child != null:
			var child_ast_node := build_tree(child)
			child_ast_node.data = child.block_resource

			children.append(child_ast_node)
			if child.bottom_snap == null:
				child = null
			else:
				child = child.bottom_snap.get_snapped_block()

	ast_node.children = children

	return ast_node


func find_snaps(node: Node) -> Array[SnapPoint]:
	var snaps: Array[SnapPoint]

	if node.is_in_group("snap_point") and node is SnapPoint:
		snaps.append(node)
	else:
		for c in node.get_children():
			snaps.append_array(find_snaps(c))

	return snaps


func set_scope(scope: String):
	for block in _window.get_children():
		var valid := false

		if block is EntryBlock:
			if scope == block.get_entry_statement():
				valid = true
		else:
			var tree_scope := DragManager.get_tree_scope(block)
			if tree_scope == "" or scope == tree_scope:
				valid = true

		if not valid:
			block.modulate = Color(0.5, 0.5, 0.5, 1)


func release_scope():
	for block in _window.get_children():
		block.modulate = Color.WHITE


func _on_add_block_code_button_pressed():
	_add_block_code_button.disabled = true

	add_block_code.emit()


func _on_open_scene_button_pressed():
	_open_scene_button.disabled = true

	open_scene.emit()


func _on_replace_block_code_button_pressed():
	_replace_block_code_button.disabled = true

	replace_block_code.emit()


func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_SHIFT:
			set_mouse_override(event.pressed)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed and is_mouse_over():
				_panning = true
			else:
				_panning = false

		if event.button_index == MOUSE_BUTTON_MIDDLE:
			set_mouse_override(event.pressed)

		var relative_mouse_pos := get_global_mouse_position() - get_global_rect().position

		if is_mouse_over():
			var old_mouse_window_pos := canvas_to_window(relative_mouse_pos)

			if event.button_index == MOUSE_BUTTON_WHEEL_UP and zoom < 2:
				zoom *= ZOOM_FACTOR
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and zoom > 0.2:
				zoom /= ZOOM_FACTOR

			_window.position -= (old_mouse_window_pos - canvas_to_window(relative_mouse_pos)) * zoom

	if event is InputEventMouseMotion:
		if (Input.is_key_pressed(KEY_SHIFT) and _panning) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and _panning):
			_window.position += event.relative


func reset_window_position():
	var blocks = get_blocks()
	var top_left: Vector2 = Vector2.INF

	for block in blocks:
		if block.position.x < top_left.x:
			top_left.x = block.position.x
		if block.position.y < top_left.y:
			top_left.y = block.position.y

	if top_left == Vector2.INF:
		top_left = Vector2.ZERO

	_window.position = (-top_left + DEFAULT_WINDOW_MARGIN) * zoom


func canvas_to_window(v: Vector2) -> Vector2:
	return _window.get_transform().affine_inverse() * v


func window_to_canvas(v: Vector2) -> Vector2:
	return _window.get_transform() * v


func is_mouse_over() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func set_mouse_override(override: bool):
	if override:
		_mouse_override.mouse_filter = Control.MOUSE_FILTER_PASS
		_mouse_override.mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		_mouse_override.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mouse_override.mouse_default_cursor_shape = Control.CURSOR_ARROW


func generate_script_from_current_window() -> String:
	var entry_asts: Array[BlockAST] = _current_ast_list.get_top_level_nodes_of_type(Types.BlockType.ENTRY)

	var script := ""

	for entry_ast in entry_asts:
		script += entry_ast.get_code()

	return script

	#return InstructionTree.generate_script_from_nodes(_window.get_children(), bsd)
