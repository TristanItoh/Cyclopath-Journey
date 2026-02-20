@tool
extends Node3D

@export var count := 100
@export var area := Vector3(50, 0, 50)
@export var base_scale := 1.5
@export var scale_variation := 0.3
@export var min_distance := 4.0
@export var trunk_radius := 0.2
@export var trunk_height := 1.0
@export var tree_meshes: Array[Mesh] = []  # assign 3 meshes in the inspector
@export var regenerate := false:
	set(value):
		if value:
			scatter()
			regenerate = false

var collision_body: StaticBody3D
var _mmi_nodes: Array[MultiMeshInstance3D] = []

func _ready():
	if not Engine.is_editor_hint():
		scatter()

func scatter():
	# Clean up old collision body
	for c in get_children():
		if c is StaticBody3D and c.name == "TreeCollisions":
			c.free()
	# Clean up old MultiMeshInstance3D nodes
	for n in _mmi_nodes:
		if is_instance_valid(n):
			n.free()
	_mmi_nodes.clear()
	collision_body = null

	if tree_meshes.is_empty():
		return

	# Create one MultiMeshInstance3D per tree type
	var mmis: Array[MultiMeshInstance3D] = []
	for mesh in tree_meshes:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mmi.multimesh = mm
		add_child(mmi)
		if Engine.is_editor_hint():
			mmi.owner = get_owner()
		mmis.append(mmi)
		_mmi_nodes.append(mmi)

	# Create collision body
	collision_body = StaticBody3D.new()
	collision_body.name = "TreeCollisions"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 1
	collision_body.add_to_group("obstacle")
	add_child(collision_body)
	if Engine.is_editor_hint():
		collision_body.owner = get_owner()

	# Generate positions
	var positions: Array[Vector3] = []
	var tree_types: Array[int] = []
	var tries := 0
	var max_tries := count * 20
	while positions.size() < count and tries < max_tries:
		tries += 1
		var pos := Vector3(
			randf_range(-area.x, area.x),
			0.0,
			randf_range(-area.z, area.z)
		)
		var ok := true
		for p in positions:
			if p.distance_squared_to(pos) < min_distance * min_distance:
				ok = false
				break
		if ok:
			positions.append(pos)
			tree_types.append(randi() % tree_meshes.size())

	# Count how many of each type
	var counts := []
	counts.resize(tree_meshes.size())
	counts.fill(0)
	for t in tree_types:
		counts[t] += 1

	# Pre-set instance counts
	for i in mmis.size():
		mmis[i].multimesh.instance_count = counts[i]

	# Track per-type index
	var indices := []
	indices.resize(tree_meshes.size())
	indices.fill(0)

	for i in positions.size():
		var t := tree_types[i]
		var scale := base_scale + randf_range(-scale_variation, scale_variation)
		scale = max(scale, 0.1)

		# Random Y rotation
		var basis := Basis(Vector3.UP, randf_range(0.0, TAU))
		basis = basis.scaled(Vector3.ONE * scale)

		mmis[t].multimesh.set_instance_transform(indices[t], Transform3D(basis, positions[i]))
		indices[t] += 1

		# Collision
		var capsule := CapsuleShape3D.new()
		capsule.radius = trunk_radius * scale
		capsule.height = trunk_height * scale

		var shape := CollisionShape3D.new()
		shape.shape = capsule
		shape.position = positions[i] + Vector3(0, capsule.height * 0.5, 0)
		collision_body.add_child(shape)
		if Engine.is_editor_hint():
			shape.owner = get_owner()
