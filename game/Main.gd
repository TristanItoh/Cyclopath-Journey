extends Node3D

@onready var music: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var player: Node = $Player  # or get via get_tree().get_first_node_in_group("player")

func _ready():
	print("test")
	if player:
		print("test2")
		player.connect("speed_multiplier_changed", Callable(self, "_on_speed_multiplier_changed"))
		# optional: sync initial speed
		_on_speed_multiplier_changed(player.speed_multiplier)

func _on_speed_multiplier_changed(multiplier: float) -> void:
	var rotation_speed = player.base_rotation_speed * multiplier
	var pitch = 0.75 + (rotation_speed - 60.0) * 0.006944
	pitch = min(pitch, 2.0)  # optional, just to not overshoot
	music.pitch_scale = pitch
	print("music speed: " + str(pitch))
