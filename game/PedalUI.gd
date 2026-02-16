extends Node2D

@onready var spinner := $Spin
@onready var ComboLabel := $Combo

var rotation_speed := -60.0

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.connect("rotation_speed_changed", Callable(self, "_on_rotation_speed_changed"))
		player.connect("pedal_feedback", Callable(self, "_on_pedal_feedback"))
	else:
		print("⚠️ no player found in group 'player'")

func _process(delta: float) -> void:
	spinner.rotation_degrees += rotation_speed * delta

func _on_rotation_speed_changed(new_speed: float) -> void:
	rotation_speed = -new_speed

func _on_pedal_feedback(result: String, combo: int) -> void:
	# update the combo label visually
	ComboLabel.text = "%s (%dx)" % [result, combo]
