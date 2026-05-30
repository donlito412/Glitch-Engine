@tool
extends RefCounted

const GlitchAIScanner = preload("res://addons/glitch_ai_assistant/project_scanner.gd")

static func build_system_prompt(editor_interface: EditorInterface) -> String:
	var parts: Array[String] = []

	parts.append("""You are GlitchAI, the expert AI game developer built into Glitch Engine.

YOUR ROLE:
You are an expert in GDScript, Godot 4, and game development. You help developers build complete, production-quality games. You have full access to the developer's project files — they are included below in PROJECT MEMORY.

RULES:
- Never use emojis in your responses
- Never say you cannot read or access the project — the project data is provided to you below
- Always reference the actual script names, functions, and variables from the project when answering
- Write complete, working GDScript — never write placeholder or incomplete code
- Explain code in plain language
- Use typed GDScript: @export var speed: float = 5.0
- Format code in markdown code blocks with gdscript syntax
- Never say "you would need to" — just write the actual solution""")

	# Project scan
	if editor_interface:
		var scan = GlitchAIScanner.scan_project(editor_interface)
		var memory = GlitchAIScanner.build_memory_summary(scan)
		if memory != "":
			parts.append("\n\nPROJECT MEMORY:\n" + memory)
		else:
			parts.append("\n\nPROJECT MEMORY: No scripts or scenes found yet.")
	else:
		parts.append("\n\nPROJECT MEMORY: Editor not connected.")

	# Current open script
	var script_content = _get_current_script(editor_interface)
	if script_content != "":
		parts.append("\n\nCURRENT OPEN SCRIPT:\n```gdscript\n" + script_content + "\n```")

	# Current scene
	var scene_info = _get_scene_info(editor_interface)
	if scene_info != "":
		parts.append("\n\nCURRENT SCENE:\n" + scene_info)

	return "\n".join(parts)

static func _get_current_script(editor_interface: EditorInterface) -> String:
	if not editor_interface:
		return ""
	var script_editor = editor_interface.get_script_editor()
	if not script_editor:
		return ""
	var current = script_editor.get_current_script()
	if not current:
		return ""
	return current.source_code.left(4000)

static func _get_scene_info(editor_interface: EditorInterface) -> String:
	if not editor_interface:
		return ""
	var root = editor_interface.get_edited_scene_root()
	if not root:
		return ""
	var info = "Scene: %s (%s)\n" % [root.name, root.get_class()]
	for child in root.get_children():
		info += "  - %s (%s)" % [child.name, child.get_class()]
		if child.get_script():
			info += " [scripted]"
		info += "\n"
	return info
