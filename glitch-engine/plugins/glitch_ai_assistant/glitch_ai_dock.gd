@tool
extends Control

# ============================================================
# GlitchAI Dock — The chat UI panel at the bottom of the editor
# ============================================================

const GlitchAIProvider = preload("res://addons/glitch_ai_assistant/glitch_ai_provider.gd")
const GlitchAIContext = preload("res://addons/glitch_ai_assistant/glitch_ai_context.gd")

var provider: Node
var conversation_history: Array = []
var editor_interface: EditorInterface

# UI Nodes (built in code — no .tscn needed)
var chat_output: RichTextLabel
var input_field: LineEdit
var send_button: Button
var clear_button: Button
var api_key_field: LineEdit
var save_key_button: Button
var status_label: Label
var settings_panel: PanelContainer
var settings_visible: bool = false

func _ready() -> void:
	_build_ui()
	_setup_provider()

func set_editor_interface(ei: EditorInterface) -> void:
	editor_interface = ei

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(0, 200)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# --- Top bar ---
	var top_bar = HBoxContainer.new()
	vbox.add_child(top_bar)

	status_label = Label.new()
	status_label.text = "🤖 GlitchAI  |  No API key set"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(status_label)

	var settings_btn = Button.new()
	settings_btn.text = "⚙ Settings"
	settings_btn.pressed.connect(_toggle_settings)
	top_bar.add_child(settings_btn)

	clear_button = Button.new()
	clear_button.text = "🗑 Clear"
	clear_button.pressed.connect(_clear_chat)
	top_bar.add_child(clear_button)

	# --- Settings panel (hidden by default) ---
	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	vbox.add_child(settings_panel)

	var settings_vbox = VBoxContainer.new()
	settings_panel.add_child(settings_vbox)

	var key_label = Label.new()
	key_label.text = "Anthropic API Key:"
	settings_vbox.add_child(key_label)

	var key_row = HBoxContainer.new()
	settings_vbox.add_child(key_row)

	api_key_field = LineEdit.new()
	api_key_field.placeholder_text = "sk-ant-..."
	api_key_field.secret = true
	api_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(api_key_field)

	save_key_button = Button.new()
	save_key_button.text = "Save Key"
	save_key_button.pressed.connect(_save_api_key)
	key_row.add_child(save_key_button)

	var key_hint = Label.new()
	key_hint.text = "Get your key at console.anthropic.com"
	key_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	settings_vbox.add_child(key_hint)

	# --- Chat output ---
	chat_output = RichTextLabel.new()
	chat_output.bbcode_enabled = true
	chat_output.scroll_following = true
	chat_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(chat_output)

	_append_message("system", "Welcome to GlitchAI! Type a message below to get started.\nTip: I can see your current open script and scene to give you context-aware help.")

	# --- Input row ---
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
	provider.name = "GlitchAIProvider"
	add_child(provider)
	provider.response_received.connect(_on_response)
	provider.response_failed.connect(_on_error)

	if provider.has_api_key():
		status_label.text = "🤖 GlitchAI  |  Ready"
	else:
		status_label.text = "🤖 GlitchAI  |  ⚠ No API key — click Settings"

func _toggle_settings() -> void:
	settings_visible = not settings_visible
	settings_panel.visible = settings_visible

func _save_api_key() -> void:
	var key = api_key_field.text.strip_edges()
	if key.is_empty():
		return
	provider.save_api_key(key)
	api_key_field.text = ""
	settings_panel.visible = false
	settings_visible = false
	status_label.text = "🤖 GlitchAI  |  ✅ API key saved — Ready"
	_append_message("system", "✅ API key saved. You're all set!")

func _on_send(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return

	input_field.text = ""
	input_field.editable = false
	send_button.disabled = true
	status_label.text = "🤖 GlitchAI  |  Thinking..."

	_append_message("user", text)

	# Build context-aware system prompt
	var system_prompt = ""
	if editor_interface:
		system_prompt = GlitchAIContext.build_system_prompt(editor_interface)
	else:
		system_prompt = "You are GlitchAI, the AI assistant built into Glitch Engine. Help the developer build their game."

	# Add to conversation history
	conversation_history.append({"role": "user", "content": text})

	# Keep history to last 20 messages to avoid token limits
	if conversation_history.size() > 20:
		conversation_history = conversation_history.slice(conversation_history.size() - 20)

	provider.send_message(system_prompt, conversation_history)

func _on_response(text: String) -> void:
	conversation_history.append({"role": "assistant", "content": text})
	_append_message("assistant", text)
	input_field.editable = true
	send_button.disabled = false
	status_label.text = "🤖 GlitchAI  |  Ready"
	input_field.grab_focus()

func _on_error(error: String) -> void:
	_append_message("error", "❌ Error: " + error)
	input_field.editable = true
	send_button.disabled = false
	status_label.text = "🤖 GlitchAI  |  Error — check settings"

func _clear_chat() -> void:
	chat_output.clear()
	conversation_history.clear()
	_append_message("system", "Chat cleared. Ready for a new conversation.")

func _append_message(role: String, text: String) -> void:
	match role:
		"user":
			chat_output.append_text("\n[color=#7890f8][b]You:[/b][/color] " + text.xml_escape() + "\n")
		"assistant":
			chat_output.append_text("\n[color=#a0d0a0][b]GlitchAI:[/b][/color]\n" + _format_response(text) + "\n")
		"system":
			chat_output.append_text("\n[color=#808080][i]" + text.xml_escape() + "[/i][/color]\n")
		"error":
			chat_output.append_text("\n[color=#f87070]" + text.xml_escape() + "[/color]\n")

func _format_response(text: String) -> String:
	# Basic markdown-to-BBCode conversion for code blocks
	var result = text
	# Code blocks: ```...``` → [code]...[/code]
	var regex = RegEx.new()
	regex.compile("```(?:gdscript|python|bash|json)?\\n?([\\s\\S]*?)```")
	var matches = regex.search_all(result)
	for m in matches:
		var code = m.get_string(1).strip_edges()
		result = result.replace(m.get_string(), "\n[bgcolor=#1a1a2e][color=#d0d0ff][code]" + code.xml_escape() + "[/code][/color][/bgcolor]\n")
	# Inline code: `...` → [code]...[/code]
	var inline_regex = RegEx.new()
	inline_regex.compile("`([^`]+)`")
	for m in inline_regex.search_all(text):
		result = result.replace(m.get_string(), "[color=#d0a0ff]" + m.get_string(1).xml_escape() + "[/color]")
	# Bold: **...** → [b]...[/b]
	var bold_regex = RegEx.new()
	bold_regex.compile("\\*\\*([^*]+)\\*\\*")
	for m in bold_regex.search_all(text):
		result = result.replace(m.get_string(), "[b]" + m.get_string(1) + "[/b]")
	return result.xml_escape() if result == text else result
