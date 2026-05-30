@tool
extends RefCounted

# ============================================================
# GlitchAI Project Scanner
# Reads all .gd scripts and .tscn scenes in the project
# Builds a compact summary the AI can understand
# ============================================================

const MAX_SCRIPT_CHARS = 800   # Max chars per script in summary
const MAX_SCRIPTS = 20         # Max scripts to include
const MAX_SCENES = 15          # Max scenes to include

static func scan_project(editor_interface: EditorInterface) -> Dictionary:
	var result = {
		"scripts": [],
		"scenes": [],
		"assets": [],
		"project_name": "",
		"node_count": 0
	}

	if not editor_interface:
		return result

	# Get project name from settings
	result["project_name"] = ProjectSettings.get_setting("application/config/name", "Unnamed Project")

	# Scan filesystem
	var fs = editor_interface.get_resource_filesystem()
	if fs:
		_scan_directory(fs.get_filesystem(), result)

	return result

static func _scan_directory(dir, result: Dictionary) -> void:
	if not dir:
		return

	for i in range(dir.get_file_count()):
		var file_name = dir.get_file(i)
		var file_path = dir.get_file_path(i)

		if file_name.ends_with(".gd"):
			if result["scripts"].size() < MAX_SCRIPTS:
				var script_info = _read_script(file_path, file_name)
				if script_info:
					result["scripts"].append(script_info)

		elif file_name.ends_with(".tscn"):
			if result["scenes"].size() < MAX_SCENES:
				result["scenes"].append({
					"name": file_name.replace(".tscn", ""),
					"path": file_path
				})

		elif file_name.ends_with(".png") or file_name.ends_with(".jpg") or \
			 file_name.ends_with(".wav") or file_name.ends_with(".mp3") or \
			 file_name.ends_with(".glb") or file_name.ends_with(".fbx"):
			result["assets"].append(file_name)

	for i in range(dir.get_subdir_count()):
		_scan_directory(dir.get_subdir(i), result)

static func _read_script(path: String, name: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var content = file.get_as_text()
	file.close()

	# Extract key info
	var extends_class = ""
	var functions = []
	var exports = []
	var signals_list = []

	for line in content.split("\n"):
		var stripped = line.strip_edges()
		if stripped.begins_with("extends "):
			extends_class = stripped.replace("extends ", "")
		elif stripped.begins_with("func ") and not stripped.begins_with("func _"):
			var func_name = stripped.split("(")[0].replace("func ", "")
			functions.append(func_name)
		elif stripped.begins_with("@export"):
			exports.append(stripped.left(80))
		elif stripped.begins_with("signal "):
			signals_list.append(stripped.replace("signal ", ""))

	return {
		"name": name.replace(".gd", ""),
		"path": path,
		"extends": extends_class,
		"functions": functions.slice(0, 10),
		"exports": exports.slice(0, 8),
		"signals": signals_list.slice(0, 5),
		"preview": content.left(MAX_SCRIPT_CHARS)
	}

static func build_memory_summary(scan: Dictionary) -> String:
	if scan.is_empty():
		return ""

	var lines: Array[String] = []
	lines.append("PROJECT: " + scan.get("project_name", "Unknown"))
	lines.append("")

	# Scripts
	var scripts = scan.get("scripts", [])
	if scripts.size() > 0:
		lines.append("SCRIPTS (%d):" % scripts.size())
		for s in scripts:
			var info = "  • %s" % s["name"]
			if s.get("extends", "") != "":
				info += " (extends %s)" % s["extends"]
			if s.get("functions", []).size() > 0:
				info += " | funcs: " + ", ".join(s["functions"])
			if s.get("exports", []).size() > 0:
				info += " | exports: " + str(s["exports"].size())
			lines.append(info)
		lines.append("")

	# Scenes
	var scenes = scan.get("scenes", [])
	if scenes.size() > 0:
		lines.append("SCENES (%d):" % scenes.size())
		for scene in scenes:
			lines.append("  • " + scene["name"] + " (" + scene["path"] + ")")
		lines.append("")

	# Assets
	var assets = scan.get("assets", [])
	if assets.size() > 0:
		lines.append("ASSETS: " + ", ".join(assets.slice(0, 10)))

	return "\n".join(lines)
