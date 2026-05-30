extends CharacterBody3D

@export var npc_name: String = "Villager"
@export var personality: String = "Friendly"
@export var occupation: String = "Farmer"
@export var walk_speed: float = 2.0

var is_talking: bool = false
var nav_agent: NavigationAgent3D

signal conversation_started(npc)
signal conversation_ended(npc)

func _ready() -> void:
	nav_agent = $NavigationAgent3D

func start_conversation(player) -> void:
	is_talking = true
	emit_signal("conversation_started", self)

func end_conversation() -> void:
	is_talking = false
	emit_signal("conversation_ended", self)
