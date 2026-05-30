@tool
extends RefCounted

# ============================================================
# GlitchAI Context — Reads the current open file/scene
# Provides context to the AI so it knows what you're working on
# ============================================================

static func build_system_prompt(editor_interface: EditorInterface) -> String:
	var context_parts: Array[String] = []

	context_parts.append("""You are GlitchAI, the built-in AI assistant for Glitch Engine — an AI-powered game engine built on Godot 4.

Your role:
- Help the developer build their game using GDScript and Godot/Glitch Engine features
- Generate clean, well-commented GDScript code
- Explain concepts clearly (the developer may not have a programming background)
- Analyze errors and suggest fixes
- Help design game systems, mechanics, and logic
- Be concise but thorough
- When writing code, always explain what it does in plain language

Rules:
- Write production-quality code
- Always use typed GDScript where possible (@export var speed: float = 5.0)
- Format code in markdown code blocks
- If you're unsure, say so — do not guess
- Do not break the fourth wall about being Claude or an AI unless directly asked""")

	# Add current open script context
	var current_script = _get_current_script(editor_interface)
	if current_script != "":
		context_parts.append("\n\nCURRENT OPEN SCRIPT:\n```gdscript\n" + current_script + "\n```")

	# Add current scene name
	var scene_name = _get_current_scene_name(editor_interface)
	if scene_name != "":
		context_parts.append("\n\nCURRENT OPEN SCENE: " + scene_name)

	return "\n".join(context_parts)

static func _get_current_script(editor_interface: EditorInterface) -> String:
	var script_editor = editor_interface.get_script_editor()
	if script_editor == null:
		return ""

	var current = script_editor.get_current_script()
	if current == null:
		return ""

	return current.source_code.left(3000)  # Limit to 3000 chars to stay within context

static func _get_current_scene_name(editor_interface: EditorInterface) -> String:
	var edited_scene = editor_interface.get_edited_scene_root()
	if edited_scene == null:
		return ""
	return edited_scene.name
