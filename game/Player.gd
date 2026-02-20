extends Node3D

signal rotation_speed_changed(new_speed: float)
signal speed_multiplier_changed(speed_multiplier: float)
signal pedal_feedback(result: String, combo: int)
signal bike_crashed()

@onready var pivot: CharacterBody3D = $Pivot  # Change this to CharacterBody3D!
@onready var body: Node3D = $Pivot/Body  # Change this to Node3D!
@onready var camera: Camera3D = $Pivot/Body/Camera3D
@onready var pedals = $Pivot/Body/Pedals  # adjust path as needed

@onready var label_type: Label = $PedalUI/Control/Type
@onready var label_streak: Label = $PedalUI/Control/Streak

# Collision detection nodes (create these in your scene!)
@onready var collision_ray: RayCast3D = $Pivot/CollisionRay
@onready var collision_area: Area3D = $Pivot/CollisionArea

@onready var pedal_ui = $PedalUI/Control  # adjust path

@onready var particles: CPUParticles3D = $Pivot/Body/Particles

const TICKER_MID: float = 209.0
const PERFECT_ZONE_PX: float = 47.0  # pixels from center = perfect
const OK_ZONE_PX: float = 99.0       # pixels from center = okay

# movement vars
var move_speed := 0.0
var max_speed := 20.0

# checkpoint vars
var checkpoints := []
var current_checkpoint := 0
var last_checkpoint_position := Vector3.ZERO
var last_checkpoint_rotation := 0.0

# turning vars
var turn_target := 0.0
var turn_angle := 0.0
var turn_sensitivity := 0.15
var turn_rate := 2.5
var max_turn_target := 1.0
var max_turn_speed := 90.0 # degrees per sec

var tilt := 0.0
var tilt_speed := 50.0
var tilt_recovery := 3.0
var fall_threshold := 30.0
var base_tilt := 5.0
var tilt_strength := 0.0
var max_tilt := 45.0
var target_tilt := 0.0
var tilt_sens := 0.0

# pedal vars
var base_rotation_speed := 60.0
var rotation_speed := base_rotation_speed
var red_angle := 0.0
var blue_angle := 180.0
const TOP_ANGLE := 90.0

const PEDAL_CYCLE_DURATION = 1.0
var pedal_rotation_speed: float = TAU / (PEDAL_CYCLE_DURATION * 2)  # radians per second

var base_fov := 75.0
var max_fov := 125.0
var fov_lerp_speed := 1.0

var vertical_velocity := 0.0

# improved camera vars
var cam_offset := Vector3(0, 1.78, 3)
var cam_position_speed := 2.5  # slower = more lag/inertia
var cam_rotation_speed := 3.0  # separate rotation smoothing
var cam_velocity := Vector3.ZERO
var prev_pivot_pos := Vector3.ZERO

# dynamic camera offset based on movement
var cam_dynamic_offset := Vector3.ZERO
var cam_offset_speed := 2.0

# combo system
var combo := 0
var speed_multiplier := 1.0
var max_multiplier := 4.0

# crash detection
var crash_speed_threshold := 5.0  # minimum speed to crash
var is_crashed := false
var crash_cooldown := 0.0
var crash_cooldown_time := 1.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	prev_pivot_pos = pivot.global_transform.origin
	# initialize camera position immediately
	var rotated_offset = pivot.global_transform.basis * cam_offset
	camera.global_transform.origin = pivot.global_transform.origin + rotated_offset
	
	_setup_checkpoints()

func _physics_process(delta: float) -> void:
	# Update crash cooldown
	if crash_cooldown > 0.0:
		crash_cooldown -= delta
	
	_update_pedals(delta)
	
	pedals.rotation.x -= pedal_rotation_speed * delta

	# Apply steering rotation to Pivot
	turn_angle = lerp(turn_angle, turn_target, delta * turn_rate)
	pivot.rotation_degrees.y += turn_angle * delta * max_turn_speed
	
	# tilt depending on steering
	tilt_speed = lerp(10.0, 1.0, clamp(move_speed / 10.0, 0.0, 1.0))
	tilt_sens = lerp(1.0, 0.3, clamp(move_speed / max_speed, 0.0, 1.0))
	
	target_tilt = turn_target * max_tilt * tilt_sens
	
	tilt = lerp(tilt, target_tilt, delta * tilt_speed)
	
	# fall if tilt reaches threshold
	if abs(tilt) > fall_threshold:
		print("you just fell over")
		tilt = 0.0
		move_speed = 0.0
		turn_target = 0.0
	
	var forward_dir = pivot.transform.basis.z.normalized()

	if pivot.is_on_floor():
		vertical_velocity = 0.0
	else:
		vertical_velocity -= 10.0 * delta  # accumulates over time

	pivot.velocity = forward_dir * move_speed
	pivot.velocity.y = vertical_velocity

	pivot.move_and_slide()
	
	# CRASH DETECTION - Check for wall/obstacle collisions
	_check_collisions()
	_check_terrain_collision()
	
	# ALIGN BODY TO SLOPE (Body is now just visual, no physics)
	if pivot.is_on_floor():
		var floor_normal = pivot.get_floor_normal()
		
		# Get the slope angle relative to the pivot's forward direction
		var pivot_forward = -pivot.global_transform.basis.z
		var slope_angle = asin(clamp(-floor_normal.dot(pivot_forward), -1.0, 1.0))
		
		# Just rotate body on its local X axis to match slope, keep everything else
		var target_x = rad_to_deg(slope_angle)
		body.rotation_degrees.x = lerp(body.rotation_degrees.x, target_x, delta * 8.0)
		body.rotation_degrees.z = lerp(body.rotation_degrees.z, tilt, delta * tilt_speed)
	else:
		# In air
		body.rotation_degrees.z = lerp(body.rotation_degrees.z, tilt, delta * tilt_speed)
		body.rotation_degrees.x = lerp(body.rotation_degrees.x, 0.0, delta * 2.0)
	
	# Track for camera
	var body_pos = body.global_transform.origin
	cam_velocity = (body_pos - prev_pivot_pos) / delta if delta > 0 else Vector3.ZERO
	prev_pivot_pos = body_pos
	
	# dynamic camera offset
	var speed_factor = clamp(move_speed / max_speed, 0.0, 1.0)
	cam_dynamic_offset.z = speed_factor * 0.5
	cam_dynamic_offset.x = -turn_target * 0.8 * speed_factor
	
	# Camera
	var current_offset = cam_offset + cam_dynamic_offset
	var rotated_offset = pivot.global_transform.basis * current_offset
	var target_cam_pos = body_pos + rotated_offset
	
	camera.global_transform.origin = camera.global_transform.origin.lerp(
		target_cam_pos, 
		delta * cam_position_speed
	)
	
	# smooth rotation
	var look_target = body_pos + (pivot.global_transform.basis * Vector3.FORWARD * 10)
	var desired_transform = camera.global_transform.looking_at(look_target, Vector3.UP)
	desired_transform = desired_transform.rotated_local(Vector3.RIGHT, deg_to_rad(-30))
	
	camera.global_transform.basis = camera.global_transform.basis.slerp(
		desired_transform.basis,
		delta * cam_rotation_speed
	)

	# FOV
	var t = clamp(move_speed / max_speed, 0.0, 1.0)
	camera.fov = lerp(camera.fov, base_fov + (max_fov - base_fov) * t, delta * fov_lerp_speed)

	# slow down
	move_speed = lerp(move_speed, 0.0, delta * 0.15)
	
		# particles
	particles.emitting = move_speed > 0.5
	particles.initial_velocity_min = lerp(1.0, 5.0, speed_factor)
	particles.initial_velocity_max = lerp(1.0, 5.0, speed_factor)

func _check_collisions() -> void:
	# SIMPLIFIED - just detect ANY collision while moving
	if crash_cooldown > 0.0:
		return
	
	# METHOD 1: Check slide collisions (for static bodies/CharacterBody3D)
	for i in range(pivot.get_slide_collision_count()):
		var collision = pivot.get_slide_collision(i)
		var collider = collision.get_collider()
		var collision_normal = collision.get_normal()
		
		# Only crash if the collider is in the "obstacle" group
		if collider and collider.is_in_group("obstacle"):
			print("💥 CRASHED!")
			print("   Hit obstacle:", collider.name)
			_handle_crash(collision)
			return
	
	# METHOD 2: Check RigidBody3D collisions using raycast
	if collision_ray and collision_ray.is_colliding():
		var collider = collision_ray.get_collider()
		
		# Only crash if it's in the obstacle group
		if collider and collider.is_in_group("obstacle"):
			var collision_normal = collision_ray.get_collision_normal()
			print("💥 CRASHED via RayCast!")
			print("   Hit obstacle:", collider.name)
			
			if collider is RigidBody3D:
				_handle_rigidbody_crash(collider, collision_normal)
			else:
				# Create a minimal crash handler for non-rigidbodies
				is_crashed = true
				crash_cooldown = crash_cooldown_time
				move_speed *= 0.3
				combo = 0
				speed_multiplier = 1.0
				emit_signal("bike_crashed")
			return
	
	# METHOD 3: Check Area3D overlaps
	if collision_area:
		var overlapping_bodies = collision_area.get_overlapping_bodies()
		
		for body_node in overlapping_bodies:
			if body_node != pivot and body_node.is_in_group("obstacle"):
				print("💥 CRASHED via Area3D!")
				print("   Hit obstacle:", body_node.name)
				
				var normal = (pivot.global_position - body_node.global_position).normalized()
				
				if body_node is RigidBody3D:
					_handle_rigidbody_crash(body_node, normal)
				else:
					is_crashed = true
					crash_cooldown = crash_cooldown_time
					move_speed *= 0.3
					combo = 0
					speed_multiplier = 1.0
					emit_signal("bike_crashed")
				return
	
	for i in range(pivot.get_slide_collision_count()):
		var collision = pivot.get_slide_collision(i)
		var collider = collision.get_collider()
		var collision_normal = collision.get_normal()

		# Push moveable objects without crashing
		if collider and collider.is_in_group("moveable") and collider is RigidBody3D:
			_push_rigidbody(collider, collision_normal)
			continue  # don't crash, just shove it

		# Only crash if the collider is in the "obstacle" group
		if collider and collider.is_in_group("obstacle"):
			_handle_crash(collision)
			return

func _handle_rigidbody_crash(rigidbody: RigidBody3D, collision_normal: Vector3) -> void:
	"""Handle crash with a RigidBody3D"""
	# Crash effects
	is_crashed = true
	crash_cooldown = crash_cooldown_time
	
	# Apply impulse to the RigidBody
	var impact_point = pivot.global_position + (-pivot.transform.basis.z * 1.0)
	var impulse = -collision_normal * move_speed * 5.0  # Adjust multiplier as needed
	rigidbody.apply_impulse(impulse, impact_point - rigidbody.global_position)
	
	# Reduce speed dramatically
	move_speed *= 0.3
	
	combo = 0
	speed_multiplier = 1.0
	rotation_speed = base_rotation_speed
	# Add these:
	label_type.text = "CRASHED"
	label_streak.text = "Streak: x0"
	
	# Reset combo
	combo = 0
	speed_multiplier = 1.0
	rotation_speed = base_rotation_speed
	
	# Add some tilt based on impact direction
	var right_dir = pivot.transform.basis.x
	var side_impact = collision_normal.dot(right_dir)
	tilt += side_impact * 15.0
	
	# Emit signal for other systems to react
	emit_signal("bike_crashed")
	emit_signal("speed_multiplier_changed", speed_multiplier)
	
	# Reset after a moment
	await get_tree().create_timer(0.5).timeout
	is_crashed = false

func _handle_crash(collision: KinematicCollision3D) -> void:
	print("💥 CRASHED!")
	
	# Get what we hit
	var collider = collision.get_collider()
	if collider:
		print("   Hit:", collider.name)
	
	# Crash effects
	is_crashed = true
	crash_cooldown = crash_cooldown_time
	
	# Reduce speed dramatically
	move_speed *= 0.3
	
	combo = 0
	speed_multiplier = 1.0
	rotation_speed = base_rotation_speed
	# Add these:
	label_type.text = "CRASHED"
	label_streak.text = "Streak: x0"
	
	# Reset combo
	combo = 0
	speed_multiplier = 1.0
	rotation_speed = base_rotation_speed
	
	# Add some tilt based on impact direction
	var impact_direction = collision.get_normal()
	var right_dir = pivot.transform.basis.x
	var side_impact = impact_direction.dot(right_dir)
	tilt += side_impact * 15.0  # Tilt away from impact
	
	# Emit signal for other systems to react
	emit_signal("bike_crashed")
	emit_signal("speed_multiplier_changed", speed_multiplier)
	
	# Reset after a moment
	await get_tree().create_timer(0.5).timeout
	is_crashed = false
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		turn_target = clamp(turn_target - event.relative.x * turn_sensitivity * 0.01, -max_turn_target, max_turn_target)

	if event.is_action_pressed("left_click"):
		if pedal_ui.is_left_active():
			_check_pedal_timing("left", pedal_ui.get_left_ticker_y())
		else:
			print("Left clicked but right is active")
	elif event.is_action_pressed("right_click"):
		if not pedal_ui.is_left_active():
			_check_pedal_timing("right", pedal_ui.get_right_ticker_y())

func _update_pedals(delta: float) -> void:
	red_angle = fposmod(red_angle + rotation_speed * delta, 360.0)
	blue_angle = fposmod(blue_angle + rotation_speed * delta, 360.0)

func _check_pedal_timing(side: String, ticker_y: float) -> void:
	var diff = abs(ticker_y - TICKER_MID)
	
	var result := ""
	if diff <= PERFECT_ZONE_PX:
		result = "PERFECT"
		combo += 1
		_pedal_result(result, side, 0.8)
	elif diff <= OK_ZONE_PX:
		result = "OKAY"
		combo += 1
		_pedal_result(result, side, 0.3)  # was -0.3, same as MISS — fixed
	else:
		result = "MISS"
		combo = 0
		_pedal_result(result, side, -0.3)

	speed_multiplier = 1.0 + float(combo) * 0.1
	speed_multiplier = clamp(speed_multiplier, 1.0, max_multiplier)

	label_type.text = result
	label_streak.text = "Streak: x" + str(combo)
	emit_signal("pedal_feedback", result, combo)

	speed_multiplier = 1.0 + float(combo) * 0.1
	speed_multiplier = clamp(speed_multiplier, 1.0, max_multiplier)

	# Update UI labels
	label_type.text = result
	label_streak.text = "Streak: x" + str(combo)

func _pedal_result(result: String, side: String, thrust: float) -> void:
	move_speed += thrust * (0.8 + (speed_multiplier - 1.0) * 0.5)
	move_speed = clamp(move_speed, 0.0, max_speed)
	print("%s pedal: %s | Angle: %.1f | Speed: %.2f" % [side, result, (red_angle if side == "left" else blue_angle), move_speed])

func _push_rigidbody(rigidbody: RigidBody3D, collision_normal: Vector3) -> void:
	var speed_factor = clamp(move_speed / max_speed, 0.0, 1.0)
	var push_dir = -collision_normal
	push_dir.y += 0.3  # slight upward kick so it flies a bit
	var impulse = push_dir.normalized() * move_speed * 8.0 * speed_factor
	rigidbody.apply_central_impulse(impulse)

func _setup_checkpoints() -> void:
	var checkpoint_node = get_parent().get_node("Checkpoints")
	if not checkpoint_node:
		print("No Checkpoints node found!")
		return
	
	checkpoints = checkpoint_node.get_children()
	
	# hide all except the first
	for i in range(checkpoints.size()):
		var cp = checkpoints[i]
		if i == 0:
			cp.visible = true
		else:
			cp.visible = false
		cp.body_entered.connect(_on_checkpoint_entered.bind(i))

func _on_checkpoint_entered(body: Node3D, idx: int) -> void:
	if body != pivot:
		return
	if idx != current_checkpoint:
		return
	
	checkpoints[idx].visible = false
	current_checkpoint += 1
	
	# Switch scene at checkpoint 20
	if current_checkpoint == 20:
		get_tree().change_scene_to_file("res://GameEnd.gd")
		return
	
	if current_checkpoint < checkpoints.size():
		checkpoints[current_checkpoint].visible = true
		print("Checkpoint ", current_checkpoint, " activated!")
	else:
		print("All checkpoints complete!")
	
	last_checkpoint_position = checkpoints[idx].global_position
	last_checkpoint_rotation = checkpoints[idx].global_rotation.y

func _teleport_to_checkpoint() -> void:
	if checkpoints.size() == 0:
		return
	var cp_index = max(current_checkpoint - 1, 0)
	var cp = checkpoints[cp_index]
	pivot.global_position = cp.global_position
	pivot.rotation_degrees.y = cp.global_rotation_degrees.y
	move_speed = 0.0
	vertical_velocity = 0.0
	tilt = 0.0
	turn_target = 0.0
	is_crashed = false

func _check_terrain_collision() -> void:
	if crash_cooldown > 0.0:
		return
	for i in range(pivot.get_slide_collision_count()):
		var collision = pivot.get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.name == "HTerrain":
			is_crashed = true
			crash_cooldown = crash_cooldown_time
			combo = 0
			speed_multiplier = 1.0
			label_type.text = "CRASHED"
			label_streak.text = "Streak: x0"
			emit_signal("bike_crashed")
			emit_signal("speed_multiplier_changed", speed_multiplier)
			_teleport_to_checkpoint()
			return
