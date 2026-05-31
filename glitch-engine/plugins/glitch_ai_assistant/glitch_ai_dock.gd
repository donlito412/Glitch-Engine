@tool
extends Control

const GlitchAIProvider = preload("res://addons/glitch_ai_assistant/glitch_ai_provider.gd")
const GlitchAIContext = preload("res://addons/glitch_ai_assistant/glitch_ai_context.gd")
const GlitchAIScriptGen = preload("res://addons/glitch_ai_assistant/script_generator.gd")

var provider: Node
var conversation_history: Array = []
var editor_interface_ref
var last_code_blocks: Array = []

var chat_output: RichTextLabel
var input_field: LineEdit
var send_button: Button
var status_label: Label
var email_panel: PanelContainer
var email_field: LineEdit
var save_script_bar: HBoxContainer
var save_path_field: LineEdit
var save_type_label: Label

func _ready() -> void:
	_build_ui()
	_setup_provider()

func set_editor_interface_ref(ei) -> void:
	editor_interface_ref = ei

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(0, 400)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var top_bar = HBoxContainer.new()
	vbox.add_child(top_bar)

	status_label = Label.new()
	status_label.text = "GlitchAI"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(status_label)

	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_clear_chat)
	top_bar.add_child(clear_btn)

	email_panel = PanelContainer.new()
	vbox.add_child(email_panel)

	var email_vbox = VBoxContainer.new()
	email_panel.add_child(email_vbox)

	var email_lbl = Label.new()
	email_lbl.text = "Enter your email to use GlitchAI (10 free messages, then $9.99/month):"
	email_vbox.add_child(email_lbl)

	var email_row = HBoxContainer.new()
	email_vbox.add_child(email_row)

	email_field = LineEdit.new()
	email_field.placeholder_text = "your@email.com"
	email_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	email_row.add_child(email_field)

	var start_btn = Button.new()
	start_btn.text = "Start"
	start_btn.pressed.connect(_save_email)
	email_row.add_child(start_btn)

	chat_output = RichTextLabel.new()
	chat_output.bbcode_enabled = true
	chat_output.scroll_following = false
	chat_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(chat_output)

	save_script_bar = HBoxContainer.new()
	save_script_bar.visible = false
	vbox.add_child(save_script_bar)

	save_type_label = Label.new()
	save_type_label.text = "Save:"
	save_script_bar.add_child(save_type_label)

	save_path_field = LineEdit.new()
	save_path_field.placeholder_text = "res://scripts/my_script.gd"
	save_path_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_script_bar.add_child(save_path_field)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_save_last_script)
	save_script_bar.add_child(save_btn)

	var save_x = Button.new()
	save_x.text = "X"
	save_x.pressed.connect(func(): save_script_bar.visible = false)
	save_script_bar.add_child(save_x)

	var input_row = HBoxContainer.new()
	vbox.add_child(input_row)

	input_field = LineEdit.new()
	input_field.placeholder_text = "Ask GlitchAI anything about your game..."
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.text_submitted.connect(_on_send)
	input_row.add_child(input_field)

	send_button = Button.new()
	send_button.text = "Send"
	send_button.pressed.connect(func(): _on_send(input_field.text))
	input_row.add_child(send_button)

func _setup_provider() -> void:
	provider = GlitchAIProvider.new()
	add_child(provider)
	provider.response_received.connect(_on_response)
	provider.response_failed.connect(_on_error)
	provider.trial_expired.connect(_on_trial_expired)
	provider.subscribe_url_received.connect(_on_subscribe_url)

	if provider.has_email():
		_show_chat_mode()
		provider.get_trial_status()
	else:
		_show_email_mode()

func _show_email_mode() -> void:
	email_panel.visible = true
	chat_output.visible = false
	input_field.get_parent().visible = false
	status_label.text = "GlitchAI  |  Enter your email to get started"

func _show_chat_mode() -> void:
	email_panel.visible = false
	chat_output.visible = true
	input_field.get_parent().visible = true
	status_label.text = "GlitchAI"
	_append_message("system", "GlitchAI ready. Ask me anything or tell me what to build.")

func _save_email() -> void:
	var email = email_field.text.strip_edges()
	if email.is_empty() or not "@" in email:
		return
	provider.save_email(email)
	_show_chat_mode()
	provider.get_trial_status()

func _on_send(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return

	input_field.text = ""
	input_field.editable = false
	send_button.disabled = true
	save_script_bar.visible = false
	status_label.text = "GlitchAI  |  Working..."

	_append_message("user", text)
	conversation_history.append({"role": "user", "content": text})
	if conversation_history.size() > 20:
		conversation_history = conversation_history.slice(conversation_history.size() - 20)

	var system_prompt: String
	if editor_interface_ref:
		system_prompt = GlitchAIContext.build_system_prompt(editor_interface_ref)
	else:
		system_prompt = "You are GlitchAI, an expert game developer AI. Never use emojis."

	provider.send_message(system_prompt, conversation_history)

func _extract_autorun(text: String) -> Dictionary:
	var start_tag = "[AUTORUN]"
	var end_tag = "[/AUTORUN]"
	var start = text.find(start_tag)
	if start == -1:
		return {"code": "", "display": text}
	var code_start = start + start_tag.length()
	var end = text.find(end_tag)
	var code: String
	var display: String
	if end != -1:
		code = text.substr(code_start, end - code_start).strip_edges()
		display = (text.left(start) + text.substr(end + end_tag.length())).strip_edges()
	else:
		code = text.substr(code_start).strip_edges()
		display = text.left(start).strip_edges()
	return {"code": code, "display": display}

func _detect_scene_build_code(text: String) -> String:
	var blocks = GlitchAIScriptGen.extract_code_blocks(text)
	for block in blocks:
		var code: String = block["code"]
		if "func _run" in code:
			return code
		if "add_child" in code and ".new()" in code and "ResourceSaver" in code:
			var wrapped = "extends RefCounted\nfunc _run() -> void:\n"
			var lines = code.split("\n")
			var has_root = false
			for line in lines:
				var trimmed = line.strip_edges()
				if trimmed.begins_with("extends ") or trimmed.begins_with("func ") or trimmed.begins_with("@tool"):
					continue
				if "var root " in line or "var root=" in line or "var root:" in line:
					has_root = true
			if not has_root:
				wrapped += "\tvar root = Node3D.new()\n\troot.name = \"GeneratedScene\"\n"
			for line in lines:
				var trimmed = line.strip_edges()
				if trimmed.begins_with("extends ") or trimmed.begins_with("func ") or trimmed.begins_with("@tool"):
					continue
				wrapped += "\t" + line + "\n"
			return wrapped
	return ""

func _on_response(text: String) -> void:
	text = text.xml_unescape().replace("&qt;", ">").replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&")
	conversation_history.append({"role": "assistant", "content": text})

	var extracted = _extract_autorun(text)
	var autorun_code: String = extracted["code"]
	var display_text: String = extracted["display"]

	if autorun_code == "":
		var scene_code = _detect_scene_build_code(display_text)
		if scene_code != "":
			autorun_code = scene_code
			var regex = RegEx.new()
			regex.compile("```(?:gdscript|gd)?\\n?[\\s\\S]*?```")
			var found_block = false
			for m in regex.search_all(display_text):
				var block_str = m.get_string()
				if "func _run" in block_str or ("add_child" in block_str and "ResourceSaver" in block_str):
					display_text = display_text.replace(block_str, "[i](Building scene...)[/i]")
					found_block = true
			if not found_block:
				display_text = "[i](Building scene...)[/i]"

	if display_text.is_empty():
		display_text = "[i](Building scene...)[/i]"

	var scroll_bar = chat_output.get_v_scroll_bar()
	var scroll_before = scroll_bar.max_value
	_append_message("assistant", display_text)
	await get_tree().process_frame
	await get_tree().process_frame
	scroll_bar.value = scroll_before

	input_field.editable = true
	send_button.disabled = false
	status_label.text = "GlitchAI"
	input_field.grab_focus()

	if autorun_code != "":
		await _run_autorun_script(autorun_code)
		provider.get_trial_status()
		return

	last_code_blocks = GlitchAIScriptGen.extract_code_blocks(display_text)
	var gd_blocks = last_code_blocks.filter(func(b): return b["language"] in ["gdscript", "gd", ""])
	if gd_blocks.size() > 0:
		var code = gd_blocks[0]["code"]
		var suggested = GlitchAIScriptGen.detect_script_name(code)
		save_type_label.text = "Save script:"
		save_path_field.text = "res://scripts/" + suggested
		save_script_bar.visible = true

	provider.get_trial_status()

func _collect_scene_paths(base: String, result: Array) -> void:
	var dir = DirAccess.open(base)
	if dir == null:
		return
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if dir.current_is_dir() and name != "." and name != "..":
			_collect_scene_paths(base + "/" + name, result)
		elif name.ends_with(".tscn"):
			result.append(base + "/" + name)
		name = dir.get_next()
	dir.list_dir_end()

func _normalize_indent(code: String) -> String:
	var norm: PackedStringArray = []
	for line in code.split("\n"):
		if line.strip_edges().is_empty():
			norm.append("")
			continue
		var stripped = line.lstrip(" \t")
		var indent = line.left(line.length() - stripped.length())
		var depth = 0
		var i = 0
		while i < indent.length():
			if indent[i] == "\t":
				depth += 1
				i += 1
			elif i + 3 < indent.length() and indent.substr(i, 4) == "    ":
				depth += 1
				i += 4
			elif i + 1 < indent.length() and indent.substr(i, 2) == "  ":
				depth += 1
				i += 2
			else:
				i += 1
		norm.append("\t".repeat(depth) + stripped)
	return "\n".join(norm)

func _run_autorun_script(code: String) -> void:
	status_label.text = "GlitchAI  |  Building..."

	var clean_code = code.strip_edges()

	# Strip markdown code fences if present
	if clean_code.begins_with("```"):
		var first_newline = clean_code.find("\n")
		if first_newline != -1:
			clean_code = clean_code.substr(first_newline + 1)
		clean_code = clean_code.strip_edges()
		if clean_code.ends_with("```"):
			clean_code = clean_code.left(clean_code.length() - 3).strip_edges()

	# Strip nested AUTORUN tags if present
	if "[AUTORUN]" in clean_code:
		var s = clean_code.find("[AUTORUN]") + 9
		var e = clean_code.find("[/AUTORUN]")
		if e != -1:
			clean_code = clean_code.substr(s, e - s).strip_edges()
		else:
			clean_code = clean_code.substr(s).strip_edges()

	# Strip @tool decorator
	if clean_code.begins_with("@tool"):
		var nl = clean_code.find("\n")
		if nl != -1:
			clean_code = clean_code.substr(nl + 1).strip_edges()

	# Replace EditorScript with RefCounted
	clean_code = clean_code.replace("extends EditorScript", "extends RefCounted")

	# Add extends if missing
	if not clean_code.begins_with("extends"):
		clean_code = "extends RefCounted\n\n" + clean_code

	# Normalize indentation (handles 2-space, 4-space, tabs, or mixed)
	clean_code = _normalize_indent(clean_code)

	# Print to Output panel so we can see exactly what is being compiled
	print("[GlitchAI] Compiling scene script:\n", clean_code)

	# Snapshot existing scenes before build
	var scenes_before: Array = []
	_collect_scene_paths("res://scenes", scenes_before)

	var script = GDScript.new()
	script.source_code = clean_code
	var compile_err = script.reload()

	if compile_err != OK:
		_append_message("error", "Scene build failed — compile error " + str(compile_err) + ". Check the Output panel at the bottom of the editor for the exact line.")
		status_label.text = "GlitchAI"
		return

	var instance = script.new()
	if not instance.has_method("_run"):
		_append_message("error", "Scene build failed — no _run() method found.")
		status_label.text = "GlitchAI"
		return

	instance._run()

	if editor_interface_ref:
		editor_interface_ref.get_resource_filesystem().scan()
		await get_tree().process_frame
		await get_tree().process_frame

		var scenes_after: Array = []
		_collect_scene_paths("res://scenes", scenes_after)

		var new_scene = ""
		for p in scenes_after:
			if p not in scenes_before:
				new_scene = p
				break

		if new_scene != "":
			editor_interface_ref.open_scene_from_path(new_scene)
			_append_message("system", "Scene built and opened: " + new_scene)
		else:
			_append_message("system", "Scene built. Check the FileSystem panel.")
	else:
		_append_message("system", "Scene built. Check the FileSystem panel.")

	status_label.text = "GlitchAI"

func _save_last_script() -> void:
	var gd_blocks = last_code_blocks.filter(func(b): return b["language"] in ["gdscript", "gd", ""])
	if gd_blocks.is_empty():
		_append_message("system", "No GDScript code found.")
		return

	var code = gd_blocks[0]["code"]
	var path = save_path_field.text.strip_edges()
	if path.is_empty():
		path = "res://scripts/new_script.gd"

	var abs_path = ProjectSettings.globalize_path(path)
	var err = GlitchAIScriptGen.save_script(code, abs_path)

	if err == OK:
		save_script_bar.visible = false
		_append_message("system", "Script saved to " + path)
		if editor_interface_ref:
			editor_interface_ref.get_resource_filesystem().scan()
	else:
		_append_message("system", "Failed to save. Check the path and try again.")

func _on_error(error: String) -> void:
	_append_message("error", "Error: " + error)
	input_field.editable = true
	send_button.disabled = false
	status_label.text = "GlitchAI  |  Error"

func _on_trial_expired() -> void:
	_append_message("system", "Your 10 free messages are used. Subscribe at $9.99/month to continue.")
	input_field.editable = true
	send_button.disabled = false

func _on_subscribe_url(url: String) -> void:
	OS.shell_open(url)

func _clear_chat() -> void:
	chat_output.clear()
	conversation_history.clear()
	save_script_bar.visible = false
	_append_message("system", "Chat cleared.")

func _append_message(role: String, text: String) -> void:
	var clean = text.strip_edges()
	if clean.is_empty():
		return
	match role:
		"user":
			chat_output.append_text("\n[color=#7890f8][b]You:[/b][/color] " + clean.xml_escape() + "\n")
		"assistant":
			chat_output.append_text("\n[color=#a0d0a0][b]GlitchAI:[/b][/color]\n" + _format_response(clean) + "\n")
		"system":
			chat_output.append_text("\n[color=#808080][i]" + clean.xml_escape() + "[/i][/color]\n")
		"error":
			chat_output.append_text("\n[color=#f87070]" + clean.xml_escape() + "[/color]\n")

func _format_response(text: String) -> String:
	var result = text
	var regex = RegEx.new()
	regex.compile("```(?:gdscript|gd)?\\n?([\\s\\S]*?)```")
	for m in regex.search_all(text):
		var code = m.get_string(1).strip_edges()
		result = result.replace(m.get_string(), "\n[bgcolor=#1a1a2e][color=#d0d0ff]" + code.xml_escape() + "[/color][/bgcolor]\n")
	var bold_regex = RegEx.new()
	bold_regex.compile("\\*\\*([^*]+)\\*\\*")
	for m in bold_regex.search_all(text):
		result = result.replace(m.get_string(), "[b]" + m.get_string(1) + "[/b]")
	return result
