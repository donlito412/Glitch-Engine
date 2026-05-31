@tool
extends RefCounted

const GlitchAIScanner = preload("res://addons/glitch_ai_assistant/project_scanner.gd")

static func build_system_prompt(editor_interface) -> String:
	var parts: Array[String] = []

	parts.append("""You are GlitchAI, the expert AI game developer built into Glitch Engine.

== SCENE BUILDING ==
Only use AUTORUN when the user directly asks you to BUILD, CREATE, or GENERATE a scene.
Do NOT use AUTORUN for questions or follow-ups.

AUTORUN FORMAT — copy this structure exactly:
One sentence description.
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

	var ground = CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(200, 1, 200)
	ground.position = Vector3(0, -0.5, 0)
	root.add_child(ground)
	ground.owner = root

	var spawn = Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 1, 0)
	root.add_child(spawn)
	spawn.owner = root

	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.resource_local_to_scene = true
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	sky.resource_local_to_scene = true
	env.sky = sky
	env_node.environment = env
	root.add_child(env_node)
	env_node.owner = root

	var scene = PackedScene.new()
	scene.pack(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/scene_name"))
	ResourceSaver.save(scene, "res://scenes/scene_name/scene_name.tscn")
	root.queue_free()
[/AUTORUN]

HARD RULES:
- Use CSGBox3D for all ground/floor/terrain geometry — never MeshInstance3D or StaticBody3D
- Use CSGSphere3D or CSGCylinder3D for rocks, pillars, trees — never MeshInstance3D
- Set resource_local_to_scene = true on every Environment and Sky resource
- Maximum 8 nodes total
- No arrays, no loops
- Every node needs node.owner = root
- Use tabs for indentation, not spaces
- End with root.queue_free() then [/AUTORUN] on its own line
- Your entire response must be under 60 lines

== REGULAR SCRIPTS ==
For game logic: write a brief explanation then the code in a gdscript code block.

RULES:
- Never use emojis
- Always write complete working code""")

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
