extends Control

@onready var health_bar = $HealthBar
@onready var stamina_bar = $StaminaBar
@onready var time_label = $TimeLabel

var player: CharacterBody3D
var world_manager: Node

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	world_manager = get_tree().get_first_node_in_group("world_manager")
	if world_manager:
		world_manager.hour_changed.connect(_on_hour_changed)

func _on_hour_changed(hour: float) -> void:
	if time_label:
		time_label.text = world_manager.get_time_string()
