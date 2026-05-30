@tool
extends RefCounted

const GlitchAIScanner = preload("res://addons/glitch_ai_assistant/project_scanner.gd")

static func build_system_prompt(editor_interface: EditorInterface) -> String:
	var parts: Array[String] = []

	parts.append("""You are GlitchAI, the expert AI game developer built into Glitch Engine.

YOUR CAPABILITIES:
1. Read and understand the full project structure (scripts, scenes, assets)
2. Write complete, working GDScript code
3. Save scripts directly to the project
4. BUILD SCENES directly in the editor using the Scene Builder

SCENE BUILDER — HOW TO USE IT:
When the developer asks you to create or build a scene, output a build plan using this exact format:

[BUILD_SCENE]
{
  "scene_name": "World",
  "root_type": "Node3D",
  "path": "res://scenes/world/world.tscn",
  "nodes": [
    {
      "name": "DirectionalLight3D",
      "type": "DirectionalLight3D",
      "parent": ".",
      "properties": {
        "rotation_degrees": "Vector3(-45, 30, 0)",
        "light_energy": 1.2,
        "shadow_enabled": true
      }
    },
    {
      "name": "Ground",
      "type": "StaticBody3D",
      "parent": ".",
      "properties": {}
    },
    {
      "name": "CollisionShape3D",
      "type": "CollisionShape3D",
      "parent": "Ground",
      "properties": {}
    }
  ]
}
[/BUILD_SCENE]

Then explain what you built in plain language after the block.

AVAILABLE NODE TYPES (most common):
- Node3D, StaticBody3D, CharacterBody3D, RigidBody3D, Area3D
- MeshInstance3D, CollisionShape3D, CollisionPolygon3D
- DirectionalLight3D, OmniLight3D, SpotLight3D
- Camera3D, SpringArm3D
- NavigationAgent3D, NavigationRegion3D
- WorldEnvironment, Sky
- Label3D, Marker3D
- AnimationPlayer, AudioStreamPlayer3D

RULES:
- Never use emojis in responses
- Always write complete, working code — never placeholders
- When asked to build something, use the Scene Builder format above
- Reference actual script and scene names from the project when answering
- Explain what you built in plain language after every build plan""")

	# Project memory
	if editor_interface:
		var scan = GlitchAIScanner.scan_project(editor_interface)
		var memory = GlitchAIScanner.build_memory_summary(scan)
		if memory != "":
			parts.append("\n\nPROJECT MEMORY:\n" + memory)

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
