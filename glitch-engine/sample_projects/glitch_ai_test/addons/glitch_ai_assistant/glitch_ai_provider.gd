@tool
extends Node

# ============================================================
# GlitchAI Provider — Talks to Glitch Engine backend (Vercel)
# No API key needed in the engine — handled server-side
# ============================================================

const BASE_URL = "https://glitch-engine.vercel.app"
const CHAT_URL = BASE_URL + "/api/chat"
const SUBSCRIBE_URL = BASE_URL + "/api/subscribe"
const TRIAL_URL = BASE_URL + "/api/trial"

var user_email: String = ""

signal response_received(text: String)
signal response_failed(error: String)
signal trial_expired()
signal trial_status_received(data: Dictionary)
signal subscribe_url_received(url: String)

func _ready() -> void:
	_load_email()

func _load_email() -> void:
	var config = ConfigFile.new()
	if config.load("user://glitch_ai_config.cfg") == OK:
		user_email = config.get_value("user", "email", "")

func save_email(email: String) -> void:
	user_email = email.strip_edges().to_lower()
	var config = ConfigFile.new()
	config.load("user://glitch_ai_config.cfg")
	config.set_value("user", "email", user_email)
	config.save("user://glitch_ai_config.cfg")

func has_email() -> bool:
	return user_email != "" and "@" in user_email

func get_trial_status() -> void:
	if not has_email():
		return
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_trial_status.bind(http))
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"email": user_email})
	http.request(TRIAL_URL, headers, HTTPClient.METHOD_POST, body)

func _on_trial_status(result, code, _headers, body, http):
	http.queue_free()
	if code != 200:
		return
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		emit_signal("trial_status_received", json.get_data())

func send_message(system_prompt: String, messages: Array) -> void:
	if not has_email():
		emit_signal("response_failed", "Please enter your email to use GlitchAI.")
		return

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_response.bind(http))

	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"email": user_email,
		"messages": messages,
		"system": system_prompt
	})

	var err = http.request(CHAT_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		emit_signal("response_failed", "Failed to connect to GlitchAI server.")
		http.queue_free()

func _on_response(result, code, _headers, body, http):
	http.queue_free()
	var raw = body.get_string_from_utf8()

	if code == 402:
		emit_signal("trial_expired")
		return

	if code != 200:
		emit_signal("response_failed", "Server error %d" % code)
		return

	var json = JSON.new()
	if json.parse(raw) != OK:
		emit_signal("response_failed", "Failed to parse response.")
		return

	var data = json.get_data()
	if data.has("error"):
		emit_signal("response_failed", data["error"])
		return

	emit_signal("response_received", data.get("text", ""))

func get_subscribe_url() -> void:
	if not has_email():
		return
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_subscribe_url.bind(http))
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"email": user_email})
	http.request(SUBSCRIBE_URL, headers, HTTPClient.METHOD_POST, body)

func _on_subscribe_url(result, code, _headers, body, http):
	http.queue_free()
	if code != 200:
		return
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var data = json.get_data()
		if data.has("url"):
			emit_signal("subscribe_url_received", data["url"])
