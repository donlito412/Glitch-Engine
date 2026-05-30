@tool
extends Control

const GlitchAIProvider = preload("res://addons/glitch_ai_assistant/glitch_ai_provider.gd")
const GlitchAIContext = preload("res://addons/glitch_ai_assistant/glitch_ai_context.gd")
const GlitchAIScriptGen = preload("res://addons/glitch_ai_assistant/script_generator.gd")
const GlitchAISceneBuilder = preload("res://addons/glitch_ai_assistant/scene_builder.gd")

var provider: Node
var conversation_history: Array = []
var editor_interface: EditorInterface
var last_code_blocks: Array[Dictionary] = []
var last_build_plan: Dictionary = {}

# UI nodes
var chat_output: RichTextLabel
var input_field: LineEdit
var send_button: Button
var status_label: Label
var email_panel: PanelContainer
var email_field: LineEdit
var save_script_bar: HBoxContainer
var save_path_field: LineEdit

func _ready() -> void:
	_build_ui()
	_setup_provider()

func set_editor_interface(ei: EditorInterface) -> void:
	editor_interface = ei

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(0, 400)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# Top bar
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

	# Email setup panel
	email_panel = PanelContainer.new()
	vbox.add_child(email_panel)

	var email_vbox = VBoxContainer.new()
	email_panel.add_child(email_vbox)

	var email_label = Label.new()
	email_label.text = "Enter your email to use GlitchAI (10 free messages, then $9.99/month):"
	email_vbox.add_child(email_label)

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

	# Chat output
	chat_output = RichTextLabel.new()
	chat_output.bbcode_enabled = true
	chat_output.scroll_following = false
	chat_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(chat_output)

	# Save script bar (hidden until AI writes code)
	save_script_bar = HBoxContainer.new()
	save_script_bar.visible = false
	vbox.add_child(save_script_bar)

	var save_label = Label.new()
	save_label.text = "Save to:"
	save_script_bar.add_child(save_label)

	save_path_field = LineEdit.new()
	save_path_field.placeholder_text = "res://scripts/my_script.gd"
	save_path_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_script_bar.add_child(save_path_field)

	var save_btn = Button.new()
	save_btn.text = "Save Script"
	save_btn.pressed.connect(_save_last_script)
	save_script_bar.add_child(save_btn)

	var dismiss_btn = Button.new()
	dismiss_btn.text = "X"
	dismiss_btn.pressed.connect(func(): save_script_bar.visible = false)
	save_script_bar.add_child(dismiss_btn)

	# Build scene bar (hidden until AI outputs a build plan)
	var build_bar = HBoxContainer.new()
	build_bar.name = "BuildSceneBar"
	build_bar.visible = false
	vbox.add_child(build_bar)

	var build_label = Label.new()
	build_label.text = "Scene ready to build:"
	build_bar.add_child(build_label)

	var build_name_label = Label.new()
	build_name_label.name = "BuildNameLabel"
	build_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_bar.add_child(build_name_label)

	var build_btn = Button.new()
	build_btn.text = "Build Scene"
	build_btn.pressed.connect(_build_last_scene)
	build_bar.add_child(build_btn)

	var build_dismiss = Button.new()
	build_dismiss.text = "X"
	build_dismiss.pressed.connect(func(): build_bar.visible = false)
	build_bar.add_child(build_dismiss)

	# Input row
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
		# Check for build plan
	last_build_plan = GlitchAISceneBuilder.parse_build_plan(text)
	if not last_build_plan.is_empty():
		var build_bar = get_node_or_null("BuildSceneBar")
		if build_bar:
			var name_label = build_bar.get_node_or_null("BuildNameLabel")
			if name_label:
				name_label.text = last_build_plan.get("path", "unknown path")
			build_bar.visible = true

	provider.get_trial_status()
	else:
		_show_email_mode()

func _show_email_mode() -> void:
	email_panel.visible = true
	chat_output.visible = false
	input_field.get_parent().visible = false
	save_script_bar.visible = false
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

	var system_prompt = GlitchAIContext.build_system_prompt(editor_interface) if editor_interface else "You are GlitchAI, an expert game developer AI built into Glitch Engine. Help build the game. Never use emojis."
	provider.send_message(system_prompt, conversation_history)

func _on_response(text: String) -> void:
	conversation_history.append({"role": "assistant", "content": text})
	# Record scroll position before adding new message
	# so we scroll to the START of the response, not the end
	var scroll_bar = chat_output.get_v_scroll_bar()
	var scroll_before = scroll_bar.max_value
	_append_message("assistant", text)
	# Wait two frames for RichTextLabel to layout new content
	await get_tree().process_frame
	await get_tree().process_frame
	scroll_bar.value = scroll_before
	input_field.editable = true
	send_button.disabled = false
	status_label.text = "GlitchAI"
	input_field.grab_focus()

	# Check if response contains code — show save bar
	last_code_blocks = GlitchAIScriptGen.extract_code_blocks(text)
	var gdscript_blocks = last_code_blocks.filter(func(b): return b["language"] in ["gdscript", "gd", ""])
	if gdscript_blocks.size() > 0:
		var suggested_name = GlitchAIScriptGen.detect_script_name(gdscript_blocks[0]["code"])
		save_path_field.text = "res://scripts/" + suggested_name
		save_script_bar.visible = true

	provider.get_trial_status()

func _save_last_script() -> void:
	var gdscript_blocks = last_code_blocks.filter(func(b): return b["language"] in ["gdscript", "gd", ""])
	if gdscript_blocks.is_empty():
		_append_message("system", "No GDScript code found in the last response.")
		return

	var code = gdscript_blocks[0]["code"]
	var path = save_path_field.text.strip_edges()

	if path.is_empty():
		path = "res://scripts/new_script.gd"

	var abs_path = ProjectSettings.globalize_path(path)
	var err = GlitchAIScriptGen.save_script(code, abs_path)

	if err == OK:
		save_script_bar.visible = false
		_append_message("system", "Script saved to " + path + ". Opening in editor...")
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()
	else:
		_append_message("system", "Failed to save script. Check the path and try again.")

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

func _build_last_scene() -> void:
	if last_build_plan.is_empty():
		_append_message("system", "No scene plan found.")
		return
	var result = GlitchAISceneBuilder.build_scene(last_build_plan, editor_interface)
	_append_message("system", result)
	var build_bar = get_node_or_null("BuildSceneBar")
	if build_bar:
		build_bar.visible = false
	last_build_plan = {}

func _clear_chat() -> void:
	chat_output.clear()
	conversation_history.clear()
	save_script_bar.visible = false
	_append_message("system", "Chat cleared.")

func _append_message(role: String, text: String) -> void:
	var clean = text.strip_edges()
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
	# Code blocks
	regex.compile("```(?:gdscript|gd)?\\n?([\\s\\S]*?)```")
	for m in regex.search_all(text):
		var code = m.get_string(1).strip_edges()
		result = result.replace(m.get_string(), "\n[bgcolor=#1a1a2e][color=#d0d0ff]" + code.xml_escape() + "[/color][/bgcolor]\n")
	# Bold
	var bold_regex = RegEx.new()
	bold_regex.compile("\\*\\*([^*]+)\\*\\*")
	for m in bold_regex.search_all(text):
		result = result.replace(m.get_string(), "[b]" + m.get_string(1) + "[/b]")
	return result
