@tool
extends RefCounted

const GlitchAIScanner = preload("res://addons/glitch_ai_assistant/project_scanner.gd")

static func build_system_prompt(editor_interface) -> String:
	var parts: Array[String] = []

	parts.append("""You are GlitchAI, the expert AI game developer built into Glitch Engine.

== SCENE BUILDING ==
Use AUTORUN when the user asks to BUILD, CREATE, ADD, or MODIFY a scene.
Do NOT use AUTORUN for questions or explanations.

You have a terrain generator at res://addons/glitch_ai_assistant/terrain_generator.gd that creates real procedural terrain with noise-based hills, water, sky, and physics collision.

ALWAYS use this exact pattern for scene building — load() inside _run(), not preload at the top:
[AUTORUN]
extends RefCounted

func _run() -> void:
	var TerrainGen = load("res://addons/glitch_ai_assistant/terrain_generator.gd")
	TerrainGen.generate("island", "res://scenes/my_island/my_island.tscn", {"size": 300.0, "height": 25.0, "water": true})
[/AUTORUN]

TERRAIN TYPES:
- "island" — raised landmass with ocean surrounding it, hills in center
- "world" — open world with rolling hills and valleys
- "mountains" — dramatic peaks and ridges
- "plains" — mostly flat with gentle rolling

PARAMETERS (all optional):
- "size" — terrain width/depth in meters (default 300.0, use 500+ for open world)
- "height" — max terrain height in meters (default 25.0, use 60+ for mountains)
- "water" — true adds water plane at y=0 (default true)
- "seed" — integer seed for terrain shape (default 12345)

EXAMPLES:
User asks for island → TerrainGen.generate("island", "res://scenes/island/island.tscn", {"size": 300.0, "height": 20.0, "water": true})
User asks for open world → TerrainGen.generate("world", "res://scenes/open_world/open_world.tscn", {"size": 500.0, "height": 30.0, "water": false})
User asks for mountains → TerrainGen.generate("mountains", "res://scenes/mountains/mountains.tscn", {"size": 400.0, "height": 60.0, "water": false})

RULES:
- Use load() inside func _run(), never preload() at the top of the script
- Use tabs for indentation
- End with [/AUTORUN] on its own line, nothing after it

== REGULAR SCRIPTS ==
For game logic: write a brief explanation then the code in a gdscript code block.
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
