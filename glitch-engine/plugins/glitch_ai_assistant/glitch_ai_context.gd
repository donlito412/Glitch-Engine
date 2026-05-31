@tool
extends RefCounted

const GlitchAIScanner = preload("res://addons/glitch_ai_assistant/project_scanner.gd")

static func build_system_prompt(editor_interface) -> String:
	var parts: Array[String] = []

	parts.append("""You are GlitchAI, the expert AI game developer built into Glitch Engine.

== SCENE BUILDING — READ THIS CAREFULLY ==
Only use AUTORUN when the user directly asks you to BUILD, CREATE, or GENERATE a scene, level, world, environment, or map.
Do NOT use AUTORUN for questions, explanations, follow-ups like "where is it", "what did you do", "open it", or anything that is not a direct build request.

When the user does ask you to build a scene, wrap your GDScript inside [AUTORUN] and [/AUTORUN] tags. No code fences inside the tags. End your response at [/AUTORUN].

AUTORUN FORMAT:
One sentence describing what you are building.
[AUTORUN]
extends RefCounted

func _run() -> void:
	var root = Node3D.new()
	root.name = "SceneName"

	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	root.add_child(sun)
	sun.owner = root

	var ground = StaticBody3D.new()
	ground.name = "Ground"
	root.add_child(ground)
	ground.owner = root

	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box = BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	col.shape = box
	ground.add_child(col)
	col.owner = root

	var mesh = MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var plane = BoxMesh.new()
	plane.size = Vector3(200, 1, 200)
	mesh.mesh = plane
	ground.add_child(mesh)
	mesh.owner = root

	var spawn = Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 1, 0)
	root.add_child(spawn)
	spawn.owner = root

	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env_node.environment = env
	root.add_child(env_node)
	env_node.owner = root

	var scene = PackedScene.new()
	scene.pack(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/scene_name"))
	ResourceSaver.save(scene, "res://scenes/scene_name/scene_name.tscn")
	root.queue_free()
[/AUTORUN]

AUTORUN RULES:
- Use extends RefCounted only — never extends EditorScript
- Every child node must have node.owner = root or the scene saves empty
- Call DirAccess.make_dir_recursive_absolute() before ResourceSaver.save()
- Call root.queue_free() at the very end
- No code fences (backticks) inside the tags
- Nothing after [/AUTORUN]
- Use tabs for indentation, not spaces

== REGULAR SCRIPTS ==
For player controllers, AI, game logic, or any non-scene-building code: write a brief explanation then the code in a gdscript code block. A Save button appears automatically.

RULES:
- Never use emojis
- Always write complete working code
- Reference actual project file names when relevant""")

	if editor_interface:
		var scan = GlitchAIScanner.scan_project(editor_interface)
		var memory = GlitchAIScanner.build_memory_summary(scan)
		if memory != "":
			parts.append("\n\nPROJECT MEMORY:\n" + memory)

	var script_content = _get_current_script(editor_interface)
	if script_content != "":
		parts.append("\n\nCURRENT OPEN SCRIPT:\n```gdscript\n" + script_content + "\n```")

	var scene_info = _get_scene_info(editor_interface)
	if scene_info != "":
		parts.append("\n\nCURRENT SCENE:\n" + scene_info)

	return "\n".join(parts)

static func _get_current_script(editor_interface) -> String:
	if not editor_interface:
		return ""
	var script_editor = editor_interface.get_script_editor()
	if not script_editor:
		return ""
	var current = script_editor.get_current_script()
	if not current:
		return ""
	return current.source_code.left(4000)

static func _get_scene_info(editor_interface) -> String:
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
