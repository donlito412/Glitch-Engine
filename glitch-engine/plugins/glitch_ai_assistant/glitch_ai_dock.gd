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

func _on_response(text: String) -> void:
	conversation_history.append({"role": "assistant", "content": text})

	var scroll_bar = chat_output.get_v_scroll_bar()
	var scroll_before = scroll_bar.max_value
	_append_message("assistant", text)
	await get_tree().process_frame
	await get_tree().process_frame
	scroll_bar.value = scroll_before

	input_field.editable = true
	send_button.disabled = false
	status_label.text = "GlitchAI"
	input_field.grab_focus()

	# Detect code blocks and show save bar
	last_code_blocks = GlitchAIScriptGen.extract_code_blocks(text)
	var gd_blocks = last_code_blocks.filter(func(b): return b["language"] in ["gdscript", "gd", ""])
	if gd_blocks.size() > 0:
		var code = gd_blocks[0]["code"]
		var suggested = GlitchAIScriptGen.detect_script_name(code)
		var is_editor = GlitchAIScriptGen.is_editor_script(code)
		if is_editor:
			save_type_label.text = "Save build script:"
			save_path_field.text = "res://" + suggested
		else:
			save_type_label.text = "Save script:"
			save_path_field.text = "res://scripts/" + suggested
		save_script_bar.visible = true

	provider.get_trial_status()

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
		var is_editor = GlitchAIScriptGen.is_editor_script(code)
		if is_editor:
			_append_message("system", "Build script saved to " + path + "\n\nTo build the scene: right-click the script in the FileSystem panel (bottom left) and click Run.")
		else:
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
