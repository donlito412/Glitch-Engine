@tool
extends RefCounted

# ============================================================
# GlitchAI Scene Builder
# Parses build plans from AI and writes .tscn files to disk
# ============================================================

static func parse_build_plan(text: String) -> Dictionary:
	var start = text.find("[BUILD_SCENE]")
	var end_tag = text.find("[/BUILD_SCENE]")
	if start == -1 or end_tag == -1:
		return {}
	var json_str = text.substr(start + 13, end_tag - start - 13).strip_edges()
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		push_error("[GlitchAI] Failed to parse build plan JSON: " + json.get_error_message())
		return {}
	var data = json.get_data()
	if data is Dictionary:
		return data
	return {}

static func build_scene(plan: Dictionary, editor_interface) -> String:
	if plan.is_empty():
		return "No build plan found in response."

	var scene_name: String = plan.get("scene_name", "NewScene")
	var root_type: String = plan.get("root_type", "Node3D")
	var nodes: Array = plan.get("nodes", [])
	var scene_path: String = plan.get("path", "res://scenes/" + scene_name.to_lower() + ".tscn")

	# Build the tscn content
	var tscn_content = _generate_tscn(scene_name, root_type, nodes)

	# Convert res:// path to absolute path
	var abs_path: String
	if scene_path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(scene_path)
	else:
		abs_path = scene_path

	# Make sure the directory exists
	var dir_path = abs_path.get_base_dir()
	var dir_err = DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		return "Failed to create directory: " + dir_path + " (error " + str(dir_err) + ")"

	# Write the file
	var file = FileAccess.open(abs_path, FileAccess.WRITE)
	if file == null:
		var open_err = FileAccess.get_open_error()
		return "Failed to open file for writing: " + abs_path + " (error " + str(open_err) + ")"

	file.store_string(tscn_content)
	file.close()

	# Refresh the editor filesystem
	if editor_interface and editor_interface.has_method("get_resource_filesystem"):
		editor_interface.get_resource_filesystem().scan()

	return "Scene built and saved to: " + scene_path + "\n\nDouble-click it in the FileSystem panel to open it."

static func _generate_tscn(scene_name: String, root_type: String, nodes: Array) -> String:
	var lines: PackedStringArray = []

	lines.append("[gd_scene format=3]")
	lines.append("")
	lines.append("[node name=\"%s\" type=\"%s\"]" % [scene_name, root_type])
	lines.append("")

	for node_data in nodes:
		if not node_data is Dictionary:
			continue
		var node_name: String = node_data.get("name", "Node")
		var node_type: String = node_data.get("type", "Node3D")
		var parent: String = node_data.get("parent", ".")
		var properties = node_data.get("properties", {})

		lines.append("[node name=\"%s\" type=\"%s\" parent=\"%s\"]" % [node_name, node_type, parent])

		if properties is Dictionary:
			for key in properties:
				var val = properties[key]
				if val is String:
					lines.append("%s = %s" % [key, val])
				elif val is bool:
					lines.append("%s = %s" % [key, "true" if val else "false"])
				elif val is float or val is int:
					lines.append("%s = %s" % [key, str(val)])
				else:
					lines.append("%s = %s" % [key, str(val)])

		lines.append("")

	return "\n".join(lines)
