@tool
extends RefCounted

# ============================================================
# GlitchAI Context — Builds the full AI system prompt
# Includes: project memory, open script, open scene
# ============================================================

const GlitchAIScanner = preload("res://addons/glitch_ai_assistant/project_scanner.gd")

static func build_system_prompt(editor_interface: EditorInterface) -> String:
	var parts: Array[String] = []

	# Core identity and rules
	parts.append("""You are GlitchAI — the expert AI game developer built into Glitch Engine.

YOUR ROLE:
You help developers build real, complete, production-quality games using GDScript and Glitch Engine (built on Godot 4). You are an expert in:
- GDScript and Godot 4 architecture
- 3D and 2D game development
- Game design patterns (player controllers, AI, inventory, dialogue, quests, saves)
- Open world systems, physics, navigation, animation
- Performance optimization

HOW YOU WORK:
- Read the project context below carefully before answering
- Reference actual script names, function names, and node paths from the project
- Write complete, working GDScript code — never write placeholder or incomplete code
- Explain what each piece of code does in plain language
- If you see a bug in the project files, point it out proactively
- Always use typed GDScript: @export var speed: float = 5.0
- Format all code in markdown code blocks with gdscript syntax

RULES:
- Never write pseudocode — always write real, runnable GDScript
- Never say "you would need to" — just write it
- If asked to fix a bug, fix it completely
- If asked to add a feature, implement it fully
- The developer may not have a programming background — explain clearly but don't be condescending""")

	# Project memory — full project scan
	var scan = GlitchAIScanner.scan_project(editor_interface)
	var memory = GlitchAIScanner.build_memory_summary(scan)
	if memory != "":
		parts.append("\n\nPROJECT MEMORY (full project structure):\n" + memory)

	# Current open script — full content
	var current_script = _get_current_script(editor_interface)
	if current_script != "":
		parts.append("\n\nCURRENT OPEN SCRIPT (what the developer is working on):\n```gdscript\n" + current_script + "\n```")
	else:
		parts.append("\n\nNo script currently open.")

	# Current open scene
	var scene_info = _get_scene_info(editor_interface)
	if scene_info != "":
		parts.append("\n\nCURRENT OPEN SCENE:\n" + scene_info)

	return "\n".join(parts)

static func _get_current_script(editor_interface: EditorInterface) -> String:
	var script_editor = editor_interface.get_script_editor()
	if not script_editor:
		return ""
	var current = script_editor.get_current_script()
	if not current:
		return ""
	# Return full script up to 4000 chars
	return current.source_code.left(4000)

static func _get_scene_info(editor_interface: EditorInterface) -> String:
	var root = editor_interface.get_edited_scene_root()
	if not root:
		return ""

	var info = "Scene: %s\n" % root.name
	info += "Root type: %s\n" % root.get_class()

	# List direct children with their types
	var children_info: Array[String] = []
	for child in root.get_children():
		var child_line = "  • %s (%s)" % [child.name, child.get_class()]
		if child.get_script():
			child_line += " [has script]"
		children_info.append(child_line)

	if children_info.size() > 0:
		info += "Nodes:\n" + "\n".join(children_info)

	return info
