@tool
extends RefCounted

# ============================================================
# GlitchAI Script Generator
# Extracts code from AI responses and saves files to project
# ============================================================

static func extract_code_blocks(text: String) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
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
	# Try to detect a good filename from the script content
	for line in code.split("\n"):
		var stripped = line.strip_edges()
		# Look for class_name
		if stripped.begins_with("class_name "):
			var name = stripped.replace("class_name ", "").split(" ")[0].to_lower()
			return name + ".gd"
		# Look for extends to suggest a name
		if stripped.begins_with("extends CharacterBody"):
			return "character.gd"
		if stripped.begins_with("extends RigidBody"):
			return "rigid_body.gd"
		if stripped.begins_with("extends Area"):
			return "area.gd"
		if stripped.begins_with("extends Control"):
			return "ui_element.gd"
		if stripped.begins_with("extends Node"):
			return "game_manager.gd"
	return "new_script.gd"

static func save_script(code: String, file_path: String) -> Error:
	# Ensure directory exists
	var dir = file_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return ERR_FILE_CANT_WRITE
	file.store_string(code)
	file.close()
	return OK

static func open_in_editor(file_path: String, editor_interface: EditorInterface) -> void:
	if not editor_interface:
		return
	# Refresh filesystem so new file appears
	editor_interface.get_resource_filesystem().scan()
	# Wait a frame then open the script
	await Engine.get_main_loop().process_frame
	var script = load(file_path)
	if script and editor_interface.get_script_editor():
		editor_interface.edit_resource(script)
