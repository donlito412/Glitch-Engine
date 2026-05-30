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
		return "Failed to open file for writing: " + abs_path + " (error " + str(FileAccess.get_open_error()) + ")"

	file.store_string(tscn_content)
	file.close()

	if editor_interface and editor_interface.has_method("get_resource_filesystem"):
		editor_interface.get_resource_filesystem().scan()

	return "Scene built and saved to: " + scene_path + "\n\nDouble-click it in the FileSystem panel to open it."

static func _generate_tscn(scene_name: String, root_type: String, nodes: Array) -> String:
	var sub_resources: PackedStringArray = []
	var node_lines: PackedStringArray = []
	var next_id: int = 1

	node_lines.append("[node name=\"%s\" type=\"%s\"]" % [scene_name, root_type])
	node_lines.append("")

	for node_data in nodes:
		if not node_data is Dictionary:
			continue
		var node_name: String = node_data.get("name", "Node")
		var node_type: String = node_data.get("type", "Node3D")
		var parent: String = node_data.get("parent", ".")
		var properties = node_data.get("properties", {})

		node_lines.append("[node name=\"%s\" type=\"%s\" parent=\"%s\"]" % [node_name, node_type, parent])

		match node_type:
			"MeshInstance3D":
				var mesh_type: String = properties.get("mesh", "BoxMesh")
				var rid = str(next_id); next_id += 1
				var sr = "[sub_resource type=\"%s\" id=\"%s\"]" % [mesh_type, rid]
				if properties.has("size"):   sr += "\nsize = %s"   % _fmt(properties["size"])
				if properties.has("radius"): sr += "\nradius = %s" % _fmt(properties["radius"])
				if properties.has("height"): sr += "\nheight = %s" % _fmt(properties["height"])
				sub_resources.append(sr)
				node_lines.append("mesh = SubResource(\"%s\")" % rid)

			"CollisionShape3D":
				var shape_type: String = properties.get("shape", "BoxShape3D")
				var rid = str(next_id); next_id += 1
				var sr = "[sub_resource type=\"%s\" id=\"%s\"]" % [shape_type, rid]
				if properties.has("size"):   sr += "\nsize = %s"   % _fmt(properties["size"])
				if properties.has("radius"): sr += "\nradius = %s" % _fmt(properties["radius"])
				if properties.has("height"): sr += "\nheight = %s" % _fmt(properties["height"])
				sub_resources.append(sr)
				node_lines.append("shape = SubResource(\"%s\")" % rid)

			"WorldEnvironment":
				var sky_rid = str(next_id); next_id += 1
				var env_rid = str(next_id); next_id += 1
				sub_resources.append("[sub_resource type=\"Sky\" id=\"%s\"]" % sky_rid)
				var env_sr = "[sub_resource type=\"Environment\" id=\"%s\"]\nbackground_mode = 2\nsky = SubResource(\"%s\")" % [env_rid, sky_rid]
				if properties.get("fog_enabled", false):
					env_sr += "\nfog_enabled = true\nfog_density = %s" % str(properties.get("fog_density", 0.01))
				sub_resources.append(env_sr)
				node_lines.append("environment = SubResource(\"%s\")" % env_rid)

			_:
				var skip = ["mesh", "shape", "size", "radius", "height", "fog_enabled", "fog_density"]
				if properties is Dictionary:
					for key in properties:
						if key not in skip:
							node_lines.append("%s = %s" % [key, _fmt(properties[key])])

		node_lines.append("")

	var lines: PackedStringArray = []
	lines.append("[gd_scene format=3]")
	lines.append("")
	for sr in sub_resources:
		lines.append(sr)
		lines.append("")
	for nl in node_lines:
		lines.append(nl)
	return "\n".join(lines)

static func _fmt(val) -> String:
	if val is String:
		if val.begins_with("Vector") or val.begins_with("Color") or val.begins_with("Basis") or val.begins_with("Transform"):
			return val
		return "\"%s\"" % val
	elif val is bool:
		return "true" if val else "false"
	return str(val)
