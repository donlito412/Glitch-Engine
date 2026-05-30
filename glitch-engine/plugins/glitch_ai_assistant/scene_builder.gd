@tool
extends RefCounted

# ============================================================
# GlitchAI Scene Builder
# Parses structured build commands from AI responses
# and creates real .tscn scene files in the project
# ============================================================

# Parse a JSON build plan from AI response
static func parse_build_plan(text: String) -> Dictionary:
	# Look for a JSON block tagged with [BUILD_SCENE]
	var start = text.find("[BUILD_SCENE]")
	var end = text.find("[/BUILD_SCENE]")
	if start == -1 or end == -1:
		return {}
	var json_str = text.substr(start + 13, end - start - 13).strip_edges()
	var json = JSON.new()
	if json.parse(json_str) != OK:
		return {}
	return json.get_data()

# Build a scene from a plan dictionary and save it
static func build_scene(plan: Dictionary, editor_interface: EditorInterface) -> String:
	if plan.is_empty():
		return "No build plan found."

	var scene_name = plan.get("scene_name", "new_scene")
	var root_type = plan.get("root_type", "Node3D")
	var nodes = plan.get("nodes", [])
	var scene_path = plan.get("path", "res://scenes/" + scene_name + ".tscn")

	# Build the .tscn file content
	var tscn = _build_tscn(scene_name, root_type, nodes)

	# Ensure directory exists
	var dir = ProjectSettings.globalize_path(scene_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(dir)

	# Write the file
	var abs_path = ProjectSettings.globalize_path(scene_path)
	var file = FileAccess.open(abs_path, FileAccess.WRITE)
	if not file:
		return "Failed to write scene file: " + scene_path

	file.store_string(tscn)
	file.close()

	# Refresh and open the scene
	if editor_interface:
		editor_interface.get_resource_filesystem().scan()

	return "Scene built: " + scene_path

# Build tscn file content from a plan
static func _build_tscn(scene_name: String, root_type: String, nodes: Array) -> String:
	var lines: Array[String] = []
	var node_count = 1 + nodes.size()

	lines.append('[gd_scene format=3]')
	lines.append('')

	# Root node
	lines.append('[node name="%s" type="%s"]' % [scene_name, root_type])
	lines.append('')

	# Child nodes
	for node_data in nodes:
		var node_name = node_data.get("name", "Node")
		var node_type = node_data.get("type", "Node3D")
		var parent = node_data.get("parent", ".")
		var properties = node_data.get("properties", {})

		lines.append('[node name="%s" type="%s" parent="%s"]' % [node_name, node_type, parent])

		# Write properties
		for key in properties:
			var val = properties[key]
			if val is String:
				lines.append('%s = "%s"' % [key, val])
			elif val is bool:
				lines.append('%s = %s' % [key, "true" if val else "false"])
			elif val is Array:
				lines.append('%s = %s' % [key, JSON.stringify(val)])
			else:
				lines.append('%s = %s' % [key, str(val)])

		lines.append('')

	return "\n".join(lines)
