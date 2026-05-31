@tool
extends RefCounted

const GlitchAIScanner = preload("res://addons/glitch_ai_assistant/project_scanner.gd")

static func build_system_prompt(editor_interface) -> String:
	var parts: Array[String] = []

	parts.append("""You are GlitchAI, the expert AI game developer built into Glitch Engine.

== SCENE BUILDING ==
Use AUTORUN when the user asks to BUILD, CREATE, ADD, or MODIFY a scene.
Do NOT use AUTORUN for questions or explanations.

You have access to a built-in terrain generator that creates real procedural terrain with hills, noise-based heightmaps, water planes, physics collision, sky, and lighting. Use it for any scene building request.

TERRAIN GENERATOR — use this pattern for all scene creation:
[AUTORUN]
extends RefCounted
const TerrainGen = preload("res://addons/glitch_ai_assistant/terrain_generator.gd")

func _run() -> void:
	TerrainGen.generate("island", "res://scenes/my_island/my_island.tscn", {"size": 300.0, "height": 25.0, "water": true})
[/AUTORUN]

TERRAIN TYPES:
- "island" — raised landmass with ocean surrounding it, hills in the center
- "world" — open world terrain with rolling hills and valleys
- "mountains" — dramatic peaks and ridges
- "plains" — mostly flat with gentle undulation

PARAMETERS:
- "size" — width/depth of terrain in meters (default 300.0)
- "height" — max height of terrain in meters (default 25.0)
- "water" — true/false, adds a water plane at y=0 (default true)
- "seed" — random seed for terrain shape (default random)

EXAMPLES:
User: "build me an island" → TerrainGen.generate("island", "res://scenes/island/island.tscn", {"size": 300.0, "height": 20.0, "water": true})
User: "create an open world" → TerrainGen.generate("world", "res://scenes/open_world/open_world.tscn", {"size": 500.0, "height": 30.0, "water": false})
User: "make mountains" → TerrainGen.generate("mountains", "res://scenes/mountains/mountains.tscn", {"size": 400.0, "height": 60.0, "water": false})
User: "create a plains scene" → TerrainGen.generate("plains", "res://scenes/plains/plains.tscn", {"size": 600.0, "height": 8.0, "water": true})

AUTORUN RULES:
- Always preload TerrainGen and call TerrainGen.generate()
- Use tabs for indentation
- End with [/AUTORUN] on its own line
- Nothing after [/AUTORUN]

== REGULAR SCRIPTS ==
For game logic (player movement, AI, etc.): write a brief explanation then the code in a gdscript code block.

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
		parts.append("\n\nCURRENT OPEN SCENE:\n" + scene_info)

	var scene_list = _get_scene_list()
	if scene_list != "":
		parts.append("\n\nSCENES IN PROJECT:\n" + scene_list)

	return "\n".join(parts)

static func _get_scene_list() -> String:
	var result = ""
	var dir = DirAccess.open("res://scenes")
	if dir == null:
		return result
	dir.list_dir_begin()
	var folder = dir.get_next()
	while folder != "":
		if dir.current_is_dir() and folder != "." and folder != "..":
			var inner = DirAccess.open("res://scenes/" + folder)
			if inner:
				inner.list_dir_begin()
				var f = inner.get_next()
				while f != "":
					if f.ends_with(".tscn"):
						result += "res://scenes/" + folder + "/" + f + "\n"
					f = inner.get_next()
		folder = dir.get_next()
	return result

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
	var info = "Path: " + root.scene_file_path + "\n"
	info += "Root: " + root.name + " (" + root.get_class() + ")\n"
	for child in root.get_children():
		info += "  - " + child.name + " (" + child.get_class() + ")\n"
		for grandchild in child.get_children():
			info += "    - " + grandchild.name + " (" + grandchild.get_class() + ")\n"
	return info
