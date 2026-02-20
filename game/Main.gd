extends Node3D

@onready var music: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var player: Node = $Player  # or get via get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if player:
		var pitch = lerp(0.75, 1.5, clamp(player.move_speed / player.max_speed, 0.0, 1.0))
		music.pitch_scale = lerp(music.pitch_scale, pitch, delta * 2.0)
