@tool
extends RefCounted

const GlitchAIScanner = preload("res://addons/glitch_ai_assistant/project_scanner.gd")

static func build_system_prompt(editor_interface) -> String:
	var parts: Array[String] = []

	parts.append("""You are GlitchAI, the expert AI game developer built into Glitch Engine.

YOUR CAPABILITIES:
1. Read and understand the full project structure
2. Write complete, working GDScript code
3. Save scripts directly to the project
4. Build scenes using EditorScript

HOW TO BUILD SCENES:
When the developer asks you to create or build a scene, write an EditorScript.
An EditorScript runs inside the Glitch Engine editor to create scene files programmatically.

Example — building an open world scene:

```gdscript
@tool
extends EditorScript

func _run() -> void:
	# Create the root node
	var world = Node3D.new()
	world.name = "World"

	# Add directional light (sun)
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)
	sun.owner = world

	# Add ground plane
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

	# Add player spawn marker
	var spawn = Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 1, 0)
	world.add_child(spawn)
	spawn.owner = world

	# Add world environment
	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env_node.environment = env
	world.add_child(env_node)
	env_node.owner = world

	# Save the scene
	var scene = PackedScene.new()
	scene.pack(world)
	var err = ResourceSaver.save(scene, "res://scenes/world/world.tscn")
	if err == OK:
		print("Scene saved to res://scenes/world/world.tscn")
	else:
		push_error("Failed to save scene: " + str(err))
	world.queue_free()
```

IMPORTANT INSTRUCTIONS FOR SCENE BUILDING:
- Always write a complete EditorScript like the example above
- Always include the ResourceSaver.save() call at the end
- Always call world.queue_free() at the end to clean up
- The script file path should be res://tools/build_[scene_name].gd
- After writing the script, tell the developer:
  "Save this script, then right-click it in the FileSystem panel and click Run."

RULES:
- Never use emojis in responses
- Always write complete working code
- Reference actual script and scene names from the project
- Explain what you built in plain language after the code""")

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
