@tool
extends EditorPlugin

# ============================================================
# GlitchAI Assistant — Editor Plugin Entry Point
# Registers the AI dock at the bottom of the editor
# ============================================================

const DOCK_SCENE_PATH = "res://addons/glitch_ai_assistant/glitch_ai_dock.tscn"

var dock: Control

func _enter_tree() -> void:
	# Load the dock scene
	var dock_scene = load(DOCK_SCENE_PATH)
	if dock_scene == null:
		push_error("[GlitchAI] Could not load dock scene at: " + DOCK_SCENE_PATH)
		return

	dock = dock_scene.instantiate()
	dock.name = "GlitchAI"

	# Add dock to the BOTTOM panel (next to Output, Debugger, etc.)
	add_control_to_bottom_panel(dock, "🤖 GlitchAI")

	print("[GlitchAI] Assistant loaded. Click 'GlitchAI' tab at the bottom to open.")

func _exit_tree() -> void:
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
		dock = null
	print("[GlitchAI] Assistant unloaded.")
