extends Node

@export var day_length_minutes: float = 20.0
var current_hour: float = 8.0
var current_weather: String = "clear"

signal hour_changed(hour: float)
signal weather_changed(weather: String)

func _process(delta: float) -> void:
	var hours_per_second = 24.0 / (day_length_minutes * 60.0)
	current_hour += hours_per_second * delta
	if current_hour >= 24.0:
		current_hour = 0.0
	emit_signal("hour_changed", current_hour)

func get_time_string() -> String:
	var h = int(current_hour)
	var m = int((current_hour - h) * 60)
	return "%02d:%02d" % [h, m]

func set_weather(weather: String) -> void:
	current_weather = weather
	emit_signal("weather_changed", weather)
