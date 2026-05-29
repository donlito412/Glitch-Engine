@tool
extends Node

# ============================================================
# GlitchAI Provider — Handles communication with AI APIs
# Currently supports: Anthropic (Claude)
# Phase 4 will add: OpenAI, Gemini, local models
# ============================================================

const API_URL = "https://api.anthropic.com/v1/messages"
const API_VERSION = "2023-06-01"
const MODEL = "claude-sonnet-4-6"
const MAX_TOKENS = 2048

var api_key: String = ""

signal response_received(text: String)
signal response_failed(error: String)
signal response_streaming(chunk: String)

func _ready() -> void:
	_load_api_key()

func _load_api_key() -> void:
	var config = ConfigFile.new()
	var path = "user://glitch_ai_config.cfg"
	if config.load(path) == OK:
		api_key = config.get_value("anthropic", "api_key", "")

func save_api_key(key: String) -> void:
	api_key = key.strip_edges()
	var config = ConfigFile.new()
	config.set_value("anthropic", "api_key", api_key)
	config.save("user://glitch_ai_config.cfg")
	print("[GlitchAI] API key saved.")

func has_api_key() -> bool:
	return api_key != "" and api_key.length() > 10

func send_message(system_prompt: String, messages: Array) -> void:
	if not has_api_key():
		emit_signal("response_failed", "No API key set. Add your Anthropic key in the GlitchAI settings.")
		return

	var body = {
		"model": MODEL,
		"max_tokens": MAX_TOKENS,
		"system": system_prompt,
		"messages": messages
	}

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_response.bind(http))

	var headers = [
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: " + API_VERSION
	]

	var err = http.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		emit_signal("response_failed", "Failed to send request (error code: %d)" % err)
		http.queue_free()

func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if code != 200:
		var raw = body.get_string_from_utf8()
		emit_signal("response_failed", "API error %d: %s" % [code, raw.left(200)])
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		emit_signal("response_failed", "Failed to parse API response.")
		return

	var data = json.get_data()
	if not data.has("content") or data["content"].is_empty():
		emit_signal("response_failed", "Empty response from API.")
		return

	var text = data["content"][0]["text"]
	emit_signal("response_received", text)
