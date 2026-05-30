@tool
extends Control

# ============================================================
# GlitchAI Dock — Bottom panel with email login + trial UI
# ============================================================

const GlitchAIProvider = preload("res://addons/glitch_ai_assistant/glitch_ai_provider.gd")
const GlitchAIContext = preload("res://addons/glitch_ai_assistant/glitch_ai_context.gd")

var provider: Node
var conversation_history: Array = []
var editor_interface: EditorInterface

# UI nodes
var chat_output: RichTextLabel
var input_field: LineEdit
var send_button: Button
var status_label: Label
var email_panel: PanelContainer
var email_field: LineEdit
var trial_label: Label
var subscribe_button: Button

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

	# --- Top bar ---
	var top_bar = HBoxContainer.new()
	vbox.add_child(top_bar)

	status_label = Label.new()
	status_label.text = "🤖 GlitchAI"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(status_label)

	trial_label = Label.new()
	trial_label.text = ""
	trial_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	top_bar.add_child(trial_label)

	subscribe_button = Button.new()
	subscribe_button.text = "⭐ Subscribe $9.99/mo"
	subscribe_button.visible = false
	subscribe_button.pressed.connect(_on_subscribe_pressed)
	top_bar.add_child(subscribe_button)

	var clear_btn = Button.new()
	clear_btn.text = "🗑"
	clear_btn.pressed.connect(_clear_chat)
	top_bar.add_child(clear_btn)

	# --- Email panel ---
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

	var save_btn = Button.new()
	save_btn.text = "Start"
	save_btn.pressed.connect(_save_email)
	email_row.add_child(save_btn)

	# --- Chat output ---
	chat_output = RichTextLabel.new()
	chat_output.bbcode_enabled = true
	chat_output.scroll_following = true
	chat_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(chat_output)

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
	add_child(provider)
	provider.response_received.connect(_on_response)
	provider.response_failed.connect(_on_error)
	provider.trial_expired.connect(_on_trial_expired)
	provider.trial_status_received.connect(_on_trial_status)
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
	status_label.text = "🤖 GlitchAI  |  Enter your email to get started"

func _show_chat_mode() -> void:
	email_panel.visible = false
	chat_output.visible = true
	input_field.get_parent().visible = true
	status_label.text = "🤖 GlitchAI"
	_append_message("system", "Welcome back! Ask me anything about your game.")

func _save_email() -> void:
	var email = email_field.text.strip_edges()
	if email.is_empty() or not "@" in email:
		status_label.text = "🤖 GlitchAI  |  ⚠ Enter a valid email"
		return
	provider.save_email(email)
	_show_chat_mode()
	provider.get_trial_status()

func _on_trial_status(data: Dictionary) -> void:
	match data.get("status", ""):
		"admin":
			trial_label.visible = false
			trial_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		"subscribed":
			trial_label.visible = false
			subscribe_button.visible = false
		"trial":
			var remaining = data.get("remaining", 0)
			trial_label.text = "  %d free messages left" % remaining
			subscribe_button.visible = remaining <= 3
		"expired":
			trial_label.text = "  Trial ended"
			subscribe_button.visible = true
			_append_message("system", "Your 10 free messages are used. Click 'Subscribe' to continue with unlimited AI.")

func _on_send(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty(): return

	input_field.text = ""
	input_field.editable = false
	send_button.disabled = true
	status_label.text = "🤖 GlitchAI  |  Thinking..."

	_append_message("user", text)
	conversation_history.append({"role": "user", "content": text})
	if conversation_history.size() > 20:
		conversation_history = conversation_history.slice(conversation_history.size() - 20)

	var system_prompt = ""
	if editor_interface:
		system_prompt = GlitchAIContext.build_system_prompt(editor_interface)
	else:
		system_prompt = "You are GlitchAI, the AI assistant built into Glitch Engine. Help the developer build their game."

	provider.send_message(system_prompt, conversation_history)

func _on_response(text: String) -> void:
	conversation_history.append({"role": "assistant", "content": text})
	_append_message("assistant", text)
	input_field.editable = true
	send_button.disabled = false
	status_label.text = "🤖 GlitchAI"
	input_field.grab_focus()
	provider.get_trial_status()

func _on_error(error: String) -> void:
	_append_message("error", "❌ " + error)
	input_field.editable = true
	send_button.disabled = false
	status_label.text = "🤖 GlitchAI  |  Error"

func _on_trial_expired() -> void:
	_append_message("system", "🔒 Your 10 free messages are used up. Click 'Subscribe $9.99/mo' to continue with unlimited GlitchAI.")
	subscribe_button.visible = true
	trial_label.text = "  Trial ended"
	input_field.editable = true
	send_button.disabled = false

func _on_subscribe_pressed() -> void:
	provider.get_subscribe_url()
	status_label.text = "🤖 GlitchAI  |  Opening checkout..."

func _on_subscribe_url(url: String) -> void:
	OS.shell_open(url)
	status_label.text = "🤖 GlitchAI  |  Checkout opened in browser"

func _clear_chat() -> void:
	chat_output.clear()
	conversation_history.clear()
	_append_message("system", "Chat cleared.")

func _append_message(role: String, text: String) -> void:
	match role:
		"user":
			chat_output.append_text("\n[color=#7890f8][b]You:[/b][/color] " + text.xml_escape() + "\n")
		"assistant":
			chat_output.append_text("\n[color=#a0d0a0][b]GlitchAI:[/b][/color]\n" + text.xml_escape() + "\n")
		"system":
			chat_output.append_text("\n[color=#808080][i]" + text.xml_escape() + "[/i][/color]\n")
		"error":
			chat_output.append_text("\n[color=#f87070]" + text.xml_escape() + "[/color]\n")
