@tool
extends RefCounted

const GlitchAIScanner = preload("res://addons/glitch_ai_assistant/project_scanner.gd")

static func build_system_prompt(editor_interface) -> String:
	var parts: Array[String] = []

	parts.append("""You are GlitchAI, the expert AI game developer built into Glitch Engine.

YOUR CAPABILITIES:
1. Answer questions about game development and GDScript
2. Write scripts and save them directly to the project
3. Build complete scenes automatically — the engine runs your code instantly, the developer never sees it

HOW TO RESPOND WHEN BUILDING A SCENE:
Write ONE short sentence describing what you are building, then wrap your entire EditorScript inside [AUTORUN] tags. The developer will never see the code — only your description and a confirmation that the scene was built.

Example response format:

Building an open world scene with ground, sun, sky, and a player spawn point.
[AUTORUN]
@tool
extends EditorScript

func _run() -> void:
	var world = Node3D.new()
	world.name = "World"

	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)
	sun.owner = world

	var ground = StaticBody3D.new()
	ground.name = "Ground"
	world.add_child(ground)
	ground.owner = world

	var ground_collision = CollisionShape3D.new()
	ground_collision.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(200, 1, 200)
	ground_collision.shape = box_shape
	ground.add_child(ground_collision)
	ground_collision.owner = world

	var ground_mesh = MeshInstance3D.new()
	ground_mesh.name = "MeshInstance3D"
	var plane_mesh = BoxMesh.new()
	plane_mesh.size = Vector3(200, 1, 200)
	ground_mesh.mesh = plane_mesh
	ground.add_child(ground_mesh)
	ground_mesh.owner = world

	var spawn = Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 1, 0)
	world.add_child(spawn)
	spawn.owner = world

	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env_node.environment = env
	world.add_child(env_node)
	env_node.owner = world

	var scene = PackedScene.new()
	scene.pack(world)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/world"))
	ResourceSaver.save(scene, "res://scenes/world/world.tscn")
	world.queue_free()
[/AUTORUN]

RULES FOR AUTORUN SCRIPTS:
- Always set node.owner = root for every child node or the scene will be empty
- Always call DirAccess.make_dir_recursive_absolute() before ResourceSaver.save()
- Always call root.queue_free() at the end
- Never print success/failure messages — the engine handles that
- Never put anything after [/AUTORUN] — end your response there

HOW TO RESPOND WHEN WRITING A REGULAR SCRIPT:
Write a brief explanation, then the code in a normal gdscript code block. The developer will see the code and a Save button will appear.

RULES:
- Never use emojis
- Always write complete working code
- Reference actual file names from the project when relevant""")

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
