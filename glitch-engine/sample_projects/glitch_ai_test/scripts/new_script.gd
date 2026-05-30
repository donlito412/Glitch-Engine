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

	var tscn_content = _generate_tscn(scene_name, root_type, nodes)

	var abs_path: String
	if scene_path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(scene_path)
	else:
		abs_path = scene_path

	var dir_path = abs_path.get_base_dir()
	var dir_err = DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		return "Failed to create directory: " + dir_path + " (error " + str(dir_err) + ")"

	var file = FileAccess.open(abs_path, FileAccess.WRITE)
	if file == null:
		var open_err = FileAccess.get_open_error()
		return "Failed to open file for writing: " + abs_path + " (error " + str(open_err) + ")"

	file.store_string(tscn_content)
	file.close()

	if editor_interface and editor_interface.has_method("get_resource_filesystem"):
		editor_interface.get_resource_filesystem().scan()

	return "Scene built and saved to: " + scene_path + "\n\nDouble-click it in the FileSystem panel to open it."

static func _generate_tscn(scene_name: String, root_type: String, nodes: Array) -> String:
	var lines: PackedStringArray = []
	var sub_resources: Array = []
	var sub_res_id: int = 1
	var node_lines: PackedStringArray = []

	node_lines.append("[node name=\"%s\" type=\"%s\"]" % [scene_name, root_type])
	node_lines.append("")

	for node_data in nodes:
		if not node_data is Dictionary:
			continue
		var node_name: String = node_data.get("name", "Node")
		var node_type: String = node_data.get("type", "Node3D")
		var parent: String = node_data.get("parent", ".")
		var properties: Dictionary = node_data.get("properties", {})

		node_lines.append("[node name=\"%s\" type=\"%s\" parent=\"%s\"]" % [node_name, node_type, parent])

		for key in properties:
			var val = properties[key]
			var written = false

			if key == "mesh" and val is String:
				var mesh_type: String = val
				var size_val = properties.get("size", "Vector3(1, 1, 1)")
				var res_id = sub_res_id
				sub_res_id += 1
				var res_lines: PackedStringArray = []
				res_lines.append("[sub_resource type=\"%s\" id=\"%s\"]" % [mesh_type, str(res_id)])
				if mesh_type == "PlaneMesh":
					res_lines.append("size = Vector2(200, 200)")
				else:
					res_lines.append("size = %s" % size_val)
				res_lines.append("")
				sub_resources.append("\n".join(res_lines))
				node_lines.append("mesh = SubResource(\"%s\")" % str(res_id))
				written = true

			elif key == "shape" and val is String:
				var shape_type: String = val
				var size_val = properties.get("size", "Vector3(1, 1, 1)")
				var radius_val = properties.get("radius", 0.5)
				var res_id = sub_res_id
				sub_res_id += 1
				var res_lines: PackedStringArray = []
				res_lines.append("[sub_resource type=\"%s\" id=\"%s\"]" % [shape_type, str(res_id)])
				if shape_type == "BoxShape3D":
					res_lines.append("size = %s" % size_val)
				elif shape_type == "SphereShape3D":
					res_lines.append("radius = %s" % str(radius_val))
				elif shape_type == "CapsuleShape3D":
					res_lines.append("radius = %s" % str(radius_val))
				res_lines.append("")
				sub_resources.append("\n".join(res_lines))
				node_lines.append("shape = SubResource(\"%s\")" % str(res_id))
				written = true

			elif key == "size" or key == "radius" or key == "height":
				written = true

			if not written:
				if val is String:
					node_lines.append("%s = %s" % [key, val])
				elif val is bool:
					node_lines.append("%s = %s" % [key, "true" if val else "false"])
				elif val is float or val is int:
					node_lines.append("%s = %s" % [key, str(val)])
				else:
					node_lines.append("%s = %s" % [key, str(val)])

		node_lines.append("")

	lines.append("[gd_scene format=3]")
	lines.append("")

	for sub_res in sub_resources:
		lines.append(sub_res)

	for nl in node_lines:
		lines.append(nl)

	return "\n".join(lines)