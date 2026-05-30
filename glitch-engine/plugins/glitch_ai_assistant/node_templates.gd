@tool
extends RefCounted

# ============================================================
# GlitchAI Node Templates
# Ready-made node structures for common game objects
# The AI references these by name in build plans
# ============================================================

static func get_template(name: String) -> Dictionary:
	match name.to_lower():
		"player":
			return player_template()
		"npc":
			return npc_template()
		"world", "open_world":
			return open_world_template()
		"directional_light", "sun":
			return sun_template()
		"sky":
			return sky_template()
		"ground", "terrain":
			return ground_template()
		"camera":
			return camera_template()
		_:
			return {}

static func player_template() -> Dictionary:
	return {
		"scene_name": "Player",
		"root_type": "CharacterBody3D",
		"path": "res://scenes/player/player.tscn",
		"nodes": [
			{
				"name": "CollisionShape3D",
				"type": "CollisionShape3D",
				"parent": ".",
				"properties": {}
			},
			{
				"name": "MeshInstance3D",
				"type": "MeshInstance3D",
				"parent": ".",
				"properties": {}
			},
			{
				"name": "Camera3D",
				"type": "Camera3D",
				"parent": ".",
				"properties": {
					"position": "Vector3(0, 1.8, 3)"
				}
			},
			{
				"name": "SpringArm3D",
				"type": "SpringArm3D",
				"parent": ".",
				"properties": {
					"spring_length": 3.0
				}
			}
		]
	}

static func open_world_template() -> Dictionary:
	return {
		"scene_name": "World",
		"root_type": "Node3D",
		"path": "res://scenes/world/world.tscn",
		"nodes": [
			{
				"name": "WorldEnvironment",
				"type": "WorldEnvironment",
				"parent": ".",
				"properties": {}
			},
			{
				"name": "DirectionalLight3D",
				"type": "DirectionalLight3D",
				"parent": ".",
				"properties": {
					"rotation_degrees": "Vector3(-45, 30, 0)",
					"light_energy": 1.2,
					"shadow_enabled": true
				}
			},
			{
				"name": "Ground",
				"type": "StaticBody3D",
				"parent": ".",
				"properties": {}
			},
			{
				"name": "CollisionShape3D",
				"type": "CollisionShape3D",
				"parent": "Ground",
				"properties": {}
			},
			{
				"name": "MeshInstance3D",
				"type": "MeshInstance3D",
				"parent": "Ground",
				"properties": {}
			},
			{
				"name": "NPCSpawnPoints",
				"type": "Node3D",
				"parent": ".",
				"properties": {}
			},
			{
				"name": "PlayerSpawn",
				"type": "Marker3D",
				"parent": ".",
				"properties": {
					"position": "Vector3(0, 1, 0)"
				}
			}
		]
	}

static func npc_template() -> Dictionary:
	return {
		"scene_name": "NPC",
		"root_type": "CharacterBody3D",
		"path": "res://scenes/npcs/npc.tscn",
		"nodes": [
			{
				"name": "CollisionShape3D",
				"type": "CollisionShape3D",
				"parent": ".",
				"properties": {}
			},
			{
				"name": "MeshInstance3D",
				"type": "MeshInstance3D",
				"parent": ".",
				"properties": {}
			},
			{
				"name": "NavigationAgent3D",
				"type": "NavigationAgent3D",
				"parent": ".",
				"properties": {
					"max_speed": 3.5
				}
			},
			{
				"name": "InteractionArea",
				"type": "Area3D",
				"parent": ".",
				"properties": {}
			},
			{
				"name": "NameLabel",
				"type": "Label3D",
				"parent": ".",
				"properties": {
					"position": "Vector3(0, 2.2, 0)",
					"billboard": 3
				}
			}
		]
	}

static func sun_template() -> Dictionary:
	return {
		"scene_name": "Sun",
		"root_type": "DirectionalLight3D",
		"path": "res://scenes/world/sun.tscn",
		"nodes": []
	}

static func ground_template() -> Dictionary:
	return {
		"scene_name": "Ground",
		"root_type": "StaticBody3D",
		"path": "res://scenes/world/ground.tscn",
		"nodes": [
			{
				"name": "CollisionShape3D",
				"type": "CollisionShape3D",
				"parent": ".",
				"properties": {}
			},
			{
				"name": "MeshInstance3D",
				"type": "MeshInstance3D",
				"parent": ".",
				"properties": {}
			}
		]
	}

static func sky_template() -> Dictionary:
	return {
		"scene_name": "Sky",
		"root_type": "WorldEnvironment",
		"path": "res://scenes/world/sky.tscn",
		"nodes": []
	}

static func camera_template() -> Dictionary:
	return {
		"scene_name": "Camera",
		"root_type": "Camera3D",
		"path": "res://scenes/camera.tscn",
		"nodes": []
	}
