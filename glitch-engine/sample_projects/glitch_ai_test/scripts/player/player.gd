extends CharacterBody3D

@export var move_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_force: float = 8.0
@export var gravity: float = 20.0
@export var stamina: float = 100.0

var is_sprinting: bool = false
var camera: Camera3D

func _ready() -> void:
	camera = $Camera3D

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_gravity(delta)
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var dir = Vector3.ZERO
	if Input.is_action_pressed("ui_up"): dir.z -= 1
	if Input.is_action_pressed("ui_down"): dir.z += 1
	if Input.is_action_pressed("ui_left"): dir.x -= 1
	if Input.is_action_pressed("ui_right"): dir.x += 1
	is_sprinting = Input.is_action_pressed("shift")
	var speed = sprint_speed if is_sprinting else move_speed
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_force
