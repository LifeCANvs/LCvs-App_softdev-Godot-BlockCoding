class_name CategoryFactory
extends Object

const BLOCKS: Dictionary = {
	"control_block": preload("res://addons/block_code/ui/blocks/control_block/control_block.tscn"),
	"parameter_block": preload("res://addons/block_code/ui/blocks/parameter_block/parameter_block.tscn"),
	"statement_block": preload("res://addons/block_code/ui/blocks/statement_block/statement_block.tscn"),
	"entry_block": preload("res://addons/block_code/ui/blocks/entry_block/entry_block.tscn"),
}

## Properties for builtin categories. Order starts at 10 for the first
## category and then are separated by 10 to allow custom categories to
## be easily placed between builtin categories.
const BUILTIN_PROPS: Dictionary = {
	"Lifecycle":
	{
		"color": Color("ec3b59"),
		"order": 10,
	},
	"Transform | Position":
	{
		"color": Color("4b6584"),
		"order": 20,
	},
	"Transform | Rotation":
	{
		"color": Color("4b6584"),
		"order": 30,
	},
	"Transform | Scale":
	{
		"color": Color("4b6584"),
		"order": 40,
	},
	"Graphics | Modulate":
	{
		"color": Color("03aa74"),
		"order": 50,
	},
	"Graphics | Visibility":
	{
		"color": Color("03aa74"),
		"order": 60,
	},
	"Graphics | Viewport":
	{
		"color": Color("03aa74"),
		"order": 61,
	},
	"Graphics | Animation":
	{
		"color": Color("03aa74"),
		"order": 62,
	},
	"Sounds":
	{
		"color": Color("e30fc0"),
		"order": 70,
	},
	"Physics | Mass":
	{
		"color": Color("a5b1c2"),
		"order": 80,
	},
	"Physics | Velocity":
	{
		"color": Color("a5b1c2"),
		"order": 90,
	},
	"Input":
	{
		"color": Color("d54322"),
		"order": 100,
	},
	"Communication | Methods":
	{
		"color": Color("4b7bec"),
		"order": 110,
	},
	"Communication | Groups":
	{
		"color": Color("4b7bec"),
		"order": 120,
	},
	"Info | Score":
	{
		"color": Color("cf6a87"),
		"order": 130,
	},
	"Loops":
	{
		"color": Color("20bf6b"),
		"order": 140,
	},
	"Logic | Conditionals":
	{
		"color": Color("45aaf2"),
		"order": 150,
	},
	"Logic | Comparison":
	{
		"color": Color("45aaf2"),
		"order": 160,
	},
	"Logic | Boolean":
	{
		"color": Color("45aaf2"),
		"order": 170,
	},
	"Variables":
	{
		"color": Color("ff8f08"),
		"order": 180,
	},
	"Math":
	{
		"color": Color("a55eea"),
		"order": 190,
	},
	"Log":
	{
		"color": Color("002050"),
		"order": 200,
	},
}

static var block_resource_dictionary: Dictionary


static func init_block_resource_dictionary():
	block_resource_dictionary = {}

	var path: String = "res://addons/block_code/blocks/"
	var dir := DirAccess.open(path)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir():
				var block_name: String = file_name.trim_suffix(".tres")
				var block_resource = load(path + file_name)
				block_resource_dictionary[block_name] = block_resource

			file_name = dir.get_next()


## Compare block categories for sorting. Compare by order then name.
static func _category_cmp(a: BlockCategory, b: BlockCategory) -> bool:
	if a.order != b.order:
		return a.order < b.order
	return a.name.naturalcasecmp_to(b.name) < 0


static func get_categories(blocks: Array[Block], extra_categories: Array[BlockCategory] = []) -> Array[BlockCategory]:
	var cat_map: Dictionary = {}
	var extra_cat_map: Dictionary = {}

	for cat in extra_categories:
		extra_cat_map[cat.name] = cat

	for block in blocks:
		var block_cat_name: String = block.block_resource.category
		var cat: BlockCategory = cat_map.get(block_cat_name)
		if cat == null:
			cat = extra_cat_map.get(block_cat_name)
			if cat == null:
				var props: Dictionary = BUILTIN_PROPS.get(block_cat_name, {})
				var color: Color = props.get("color", Color.SLATE_GRAY)
				var order: int = props.get("order", 0)
				cat = BlockCategory.new(block_cat_name, color, order)
			cat_map[block_cat_name] = cat
		cat.block_list.append(block)

	# Dictionary.values() returns an untyped Array and there's no way to
	# convert an array type besides Array.assign().
	var cats: Array[BlockCategory] = []
	cats.assign(cat_map.values())
	# Accessing a static Callable from a static function fails in 4.2.1.
	# Use the fully qualified name.
	# https://github.com/godotengine/godot/issues/86032
	cats.sort_custom(CategoryFactory._category_cmp)
	return cats


static func get_block_resource_from_name(block_name: String) -> BlockResource:
	if not block_name in block_resource_dictionary:
		push_error("Cannot construct unknown block name.")
		return null

	return block_resource_dictionary[block_name]


static func construct_block_from_name(block_name: String):
	var block_resource: BlockResource = get_block_resource_from_name(block_name)
	return construct_block_from_resource(block_resource)


# Essentially: Create UI from block resource.
# Using current API but we can make a cleaner one
static func construct_block_from_resource(block_resource: BlockResource):
	if block_resource == null:
		push_error("Cannot construct block from null block resource.")
		return null

	if block_resource.block_type == Types.BlockType.EXECUTE:
		var b = BLOCKS["statement_block"].instantiate()
		b.block_resource = block_resource
		b.color = BUILTIN_PROPS[block_resource.category].color
		return b
	elif block_resource.block_type == Types.BlockType.ENTRY:
		var b = BLOCKS["entry_block"].instantiate()
		b.block_resource = block_resource
		b.color = BUILTIN_PROPS[block_resource.category].color
		return b
	else:
		push_error("Other block types not implemented yet.")
		return null


static func get_general_blocks() -> Array[Block]:
	var b: Block
	var block_list: Array[Block] = []

	for block_name in block_resource_dictionary:
		b = construct_block_from_name(block_name)
		block_list.append(b)

	return block_list


static func property_to_blocklist(property: Dictionary) -> Array[Block]:
	var block_list: Array[Block] = []

	var variant_type = property.type

	if variant_type:
		var type_string: String = Types.VARIANT_TYPE_TO_STRING[variant_type]

		var b = BLOCKS["statement_block"].instantiate()
		b.block_name = "set_prop_%s" % property.name
		b.block_format = "Set %s to {value: %s}" % [property.name.capitalize(), type_string]
		b.statement = "%s = {value}" % property.name
		b.category = property.category
		block_list.append(b)

		b = BLOCKS["statement_block"].instantiate()
		b.block_name = "change_prop_%s" % property.name
		b.block_format = "Change %s by {value: %s}" % [property.name.capitalize(), type_string]
		b.statement = "%s += {value}" % property.name
		b.category = property.category
		block_list.append(b)

		b = BLOCKS["parameter_block"].instantiate()
		b.block_name = "get_prop_%s" % property.name
		b.variant_type = variant_type
		b.block_format = "%s" % property.name.capitalize()
		b.statement = "%s" % property.name
		b.category = property.category
		block_list.append(b)

	return block_list


static func blocks_from_property_list(property_list: Array, selected_props: Dictionary) -> Array[Block]:
	var block_list: Array[Block]

	for selected_property in selected_props:
		var found_prop
		for prop in property_list:
			if selected_property == prop.name:
				found_prop = prop
				found_prop.category = selected_props[selected_property]
				break
		if found_prop:
			block_list.append_array(property_to_blocklist(found_prop))
		else:
			push_warning("No property matching %s found in %s" % [selected_property, property_list])

	return block_list


static func get_inherited_blocks(_class_name: String) -> Array[Block]:
	var blocks: Array[Block] = []

	var current: String = _class_name

	while current != "":
		blocks.append_array(get_built_in_blocks(current))
		current = ClassDB.get_parent_class(current)

	return blocks


static func get_built_in_blocks(_class_name: String) -> Array[Block]:
	var props: Dictionary = {}
	var block_list: Array[Block] = []

	#match _class_name:
	#"Node2D":
	#var b = BLOCKS["statement_block"].instantiate()
	#b.block_name = "node2d_rotation"
	#b.block_format = "Set Rotation Degrees {angle: FLOAT}"
	#b.statement = "rotation_degrees = {angle}"
	#b.category = "Transform | Rotation"
	#block_list.append(b)
#
	#props = {
	#"position": "Transform | Position",
	#"rotation": "Transform | Rotation",
	#"scale": "Transform | Scale",
	#}
#
	#"CanvasItem":
	#props = {
	#"modulate": "Graphics | Modulate",
	#"visible": "Graphics | Visibility",
	#}
#
	#"RigidBody2D":
	#for verb in ["entered", "exited"]:
	#var b = BLOCKS["entry_block"].instantiate()
	#b.block_name = "rigidbody2d_on_%s" % verb
	#b.block_format = "On [body: NODE_PATH] %s" % [verb]
	## HACK: Blocks refer to nodes by path but the callback receives the node itself;
	## convert to path
	#b.statement = (
	#(
	#"""
	#func _on_body_%s(_body: Node):
	#var body: NodePath = _body.get_path()
	#"""
	#. dedent()
	#)
	#% [verb]
	#)
	#b.signal_name = "body_%s" % [verb]
	#b.category = "Communication | Methods"
	#block_list.append(b)
#
	#var b = BLOCKS["statement_block"].instantiate()
	#b.block_name = "rigidbody2d_physics_position"
	#b.block_format = "Set Physics Position {position: VECTOR2}"
	#b.statement = (
	#"""
	#PhysicsServer2D.body_set_state(
	#get_rid(),
	#PhysicsServer2D.BODY_STATE_TRANSFORM,
	#Transform2D.IDENTITY.translated({position})
	#)
	#"""
	#. dedent()
	#)
	#b.category = "Transform | Position"
	#block_list.append(b)
#
	#props = {
	#"mass": "Physics | Mass",
	#"linear_velocity": "Physics | Velocity",
	#"angular_velocity": "Physics | Velocity",
	#}
#
	#"AnimationPlayer":
	#var b = BLOCKS["statement_block"].instantiate()
	#b.block_name = "animationplayer_play"
	#b.block_format = "Play {animation: STRING} {direction: OPTION}"
	#b.statement = (
	#"""
	#if "{direction}" == "ahead":
	#play({animation})
	#else:
	#play_backwards({animation})
	#"""
	#. dedent()
	#)
	#b.defaults = {
	#"direction": OptionData.new(["ahead", "backwards"]),
	#}
	#b.tooltip_text = "Play the animation."
	#b.category = "Graphics | Animation"
	#block_list.append(b)
#
	#b = BLOCKS["statement_block"].instantiate()
	#b.block_name = "animationplayer_pause"
	#b.block_format = "Pause"
	#b.statement = "pause()"
	#b.tooltip_text = "Pause the currently playing animation."
	#b.category = "Graphics | Animation"
	#block_list.append(b)
#
	#b = BLOCKS["statement_block"].instantiate()
	#b.block_name = "animationplayer_stop"
	#b.block_format = "Stop"
	#b.statement = "stop()"
	#b.tooltip_text = "Stop the currently playing animation."
	#b.category = "Graphics | Animation"
	#block_list.append(b)
#
	#b = BLOCKS["parameter_block"].instantiate()
	#b.block_name = "animationplayer_is_playing"
	#b.variant_type = TYPE_BOOL
	#b.block_format = "Is playing"
	#b.statement = "is_playing()"
	#b.tooltip_text = "Check if an animation is currently playing."
	#b.category = "Graphics | Animation"
	#block_list.append(b)
#
	#"Area2D":
	#for verb in ["entered", "exited"]:
	#var b = BLOCKS["entry_block"].instantiate()
	#b.block_name = "area2d_on_%s" % verb
	#b.block_format = "On [body: NODE_PATH] %s" % [verb]
	## HACK: Blocks refer to nodes by path but the callback receives the node itself;
	## convert to path
	#b.statement = (
	#(
	#"""
	#func _on_body_%s(_body: Node2D):
	#var body: NodePath = _body.get_path()
	#"""
	#. dedent()
	#)
	#% [verb]
	#)
	#b.signal_name = "body_%s" % [verb]
	#b.category = "Communication | Methods"
	#block_list.append(b)
#
	#"CharacterBody2D":
	#var b = BLOCKS["statement_block"].instantiate()
	#b.block_name = "characterbody2d_move"
	#b.block_type = Types.BlockType.EXECUTE
	#b.block_format = "Move with keys {up: STRING} {down: STRING} {left: STRING} {right: STRING} with speed {speed: VECTOR2}"
	#b.statement = (
	#"var dir = Vector2()\n"
	#+ "dir.x += float(Input.is_key_pressed(OS.find_keycode_from_string({right})))\n"
	#+ "dir.x -= float(Input.is_key_pressed(OS.find_keycode_from_string({left})))\n"
	#+ "dir.y += float(Input.is_key_pressed(OS.find_keycode_from_string({down})))\n"
	#+ "dir.y -= float(Input.is_key_pressed(OS.find_keycode_from_string({up})))\n"
	#+ "dir = dir.normalized()\n"
	#+ "velocity = dir*{speed}\n"
	#+ "move_and_slide()"
	#)
	#b.defaults = {
	#"up": "W",
	#"down": "S",
	#"left": "A",
	#"right": "D",
	#}
	#b.category = "Input"
	#block_list.append(b)
#
	#b = BLOCKS["statement_block"].instantiate()
	#b.block_name = "characterbody2d_move_and_slide"
	#b.block_type = Types.BlockType.EXECUTE
	#b.block_format = "Move and slide"
	#b.statement = "move_and_slide()"
	#b.category = "Physics | Velocity"
	#block_list.append(b)
#
	#props = {
	#"velocity": "Physics | Velocity",
	#}
#
	#var prop_list = ClassDB.class_get_property_list(_class_name, true)
	#block_list.append_array(blocks_from_property_list(prop_list, props))

	return block_list


static func _get_input_blocks() -> Array[Block]:
	var block_list: Array[Block]

	var editor_input_actions: Dictionary = {}
	var editor_input_action_deadzones: Dictionary = {}
	if Engine.is_editor_hint():
		var actions := InputMap.get_actions()
		for action in actions:
			if action.begins_with("spatial_editor"):
				var events := InputMap.action_get_events(action)
				editor_input_actions[action] = events
				editor_input_action_deadzones[action] = InputMap.action_get_deadzone(action)

	InputMap.load_from_project_settings()

	var block: Block = BLOCKS["parameter_block"].instantiate()
	block.block_name = "is_action"
	block.variant_type = TYPE_BOOL
	block.block_format = "Is action {action_name: OPTION} {action: OPTION}"
	block.statement = 'Input.is_action_{action}("{action_name}")'
	block.defaults = {"action_name": OptionData.new(InputMap.get_actions()), "action": OptionData.new(["pressed", "just_pressed", "just_released"])}
	block.category = "Input"
	block_list.append(block)

	if Engine.is_editor_hint():
		for action in editor_input_actions.keys():
			InputMap.add_action(action, editor_input_action_deadzones[action])
			for event in editor_input_actions[action]:
				InputMap.action_add_event(action, event)

	return block_list


static func get_variable_blocks(variables: Array[VariableResource]):
	var block_list: Array[Block]

	for variable in variables:
		var type_string: String = Types.VARIANT_TYPE_TO_STRING[variable.var_type]

		var b = BLOCKS["parameter_block"].instantiate()
		b.block_name = "get_var_%s" % variable.var_name
		b.variant_type = variable.var_type
		b.block_format = variable.var_name
		b.statement = variable.var_name
		# HACK: Color the blocks since they are outside of the normal picker system
		b.color = BUILTIN_PROPS["Variables"].color
		block_list.append(b)

		b = BLOCKS["statement_block"].instantiate()
		b.block_name = "set_var_%s" % variable.var_name
		b.block_type = Types.BlockType.EXECUTE
		b.block_format = "Set %s to {value: %s}" % [variable.var_name, type_string]
		b.statement = "%s = {value}" % [variable.var_name]
		b.color = BUILTIN_PROPS["Variables"].color
		block_list.append(b)

	return block_list
