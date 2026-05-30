@tool
extends RefCounted

static func extract_code_blocks(text: String) -> Array:
	var blocks: Array = []
	var lines = text.split("\n")
	var in_block = false
	var current_code = ""
	var current_lang = ""

	for line in lines:
		if line.begins_with("```"):
			if not in_block:
				in_block = true
				current_lang = line.replace("```", "").strip_edges()
				current_code = ""
			else:
				if current_code.strip_edges() != "":
					blocks.append({
						"language": current_lang,
						"code": current_code.strip_edges()
					})
				in_block = false
				current_code = ""
				current_lang = ""
		elif in_block:
			current_code += line + "\n"

	return blocks

static func detect_script_name(code: String) -> String:
	# EditorScript — save to tools/ folder
	if "extends EditorScript" in code:
		for line in code.split("\n"):
			if "ResourceSaver.save" in line and "res://" in line:
				# Extract scene name from the save path
				var start = line.find("res://")
				var end = line.find(".tscn")
				if start != -1 and end != -1:
					var path = line.substr(start, end - start)
					var scene_name = path.get_file()
					if scene_name != "":
						return "tools/build_" + scene_name + ".gd"
		return "tools/build_scene.gd"

	# Regular script detection
	for line in code.split("\n"):
		var stripped = line.strip_edges()
		if stripped.begins_with("class_name "):
			return stripped.replace("class_name ", "").split(" ")[0].to_lower() + ".gd"
		if stripped.begins_with("extends CharacterBody"):
			return "player.gd"
		if stripped.begins_with("extends RigidBody"):
			return "rigid_body.gd"
		if stripped.begins_with("extends Area"):
			return "area.gd"
		if stripped.begins_with("extends Control"):
			return "ui_element.gd"
		if stripped.begins_with("extends Node"):
			return "game_manager.gd"
	return "new_script.gd"

static func is_editor_script(code: String) -> bool:
	return "extends EditorScript" in code

static func save_script(code: String, file_path: String) -> Error:
	var dir = file_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return ERR_FILE_CANT_WRITE
	file.store_string(code)
	file.close()
	return OK
