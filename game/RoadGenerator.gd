@tool
extends Path3D

@export var road_width: float = 10.0
@export var auto_update: bool = true
@export var update_road: bool = false:
	set(value):
		generate_road_from_children()

var last_positions = []

func _ready():
	if Engine.is_editor_hint():
		generate_road_from_children()
		
func _process(_delta):
	if Engine.is_editor_hint() and auto_update:
		var current_positions = []
		for child in get_children():
			if child is Node3D and not child is MeshInstance3D:
				current_positions.append(child.global_position)
		
		if current_positions != last_positions:
			last_positions = current_positions.duplicate()
			generate_road_from_children()

func generate_road_from_children():
	print("=== Generating Road ===")
	print("Children count: ", get_children().size())
	
	if curve == null:
		curve = Curve3D.new()
	curve.clear_points()
	
	var points = []
	for child in get_children():
		if child is Node3D and not child is MeshInstance3D:
			points.append(child.global_position)
			print("Added point: ", child.global_position)
	
	print("Total points: ", points.size())
	
	for i in range(points.size()):
		curve.add_point(points[i])
		
		if i > 0 and i < points.size() - 1:
			var prev = points[i - 1]
			var current = points[i]
			var next = points[i + 1]
			
			var direction = (next - prev).normalized()
			var distance = (next - current).length() * 0.3
			
			curve.set_point_in(i, -direction * distance)
			curve.set_point_out(i, direction * distance)
	
	print("Curve points: ", curve.get_point_count())
	print("Baked points: ", curve.get_baked_points().size())
	
	_update_road_mesh()

var road_mesh_instance: MeshInstance3D = null

func _update_road_mesh():
	if curve.get_point_count() < 2:
		return
	
	# Create or reuse mesh instance
	if road_mesh_instance == null:
		road_mesh_instance = MeshInstance3D.new()
		add_child(road_mesh_instance)
		road_mesh_instance.owner = get_tree().edited_scene_root
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var baked_points = curve.get_baked_points()
	var point_count = baked_points.size()
	
	if point_count < 2:
		return
	
	# PRE-CALCULATE ALL EDGE VERTICES FIRST
	var left_edge = []
	var right_edge = []
	
	for i in range(point_count):
		var pos = baked_points[i]
		var forward = Vector3.FORWARD
		
		# Get forward direction from curve tangent
		if i < point_count - 1:
			forward = (baked_points[i + 1] - pos).normalized()
		elif i > 0:
			forward = (pos - baked_points[i - 1]).normalized()
		
		var right = forward.cross(Vector3.UP).normalized()
		
		# Store the edge vertices
		left_edge.append(pos - right * road_width / 2)
		right_edge.append(pos + right * road_width / 2)
	
	# NOW CREATE TRIANGLES USING THE PRE-CALCULATED EDGES
	for i in range(point_count - 1):
		var p1 = left_edge[i]      # Current left
		var p2 = right_edge[i]     # Current right
		var p3 = right_edge[i + 1] # Next right
		var p4 = left_edge[i + 1]  # Next left
		
		# First triangle
		st.set_uv(Vector2(0, i))
		st.add_vertex(p1)
		st.set_uv(Vector2(1, i + 1))
		st.add_vertex(p3)
		st.set_uv(Vector2(1, i))
		st.add_vertex(p2)
		
		# Second triangle
		st.set_uv(Vector2(0, i))
		st.add_vertex(p1)
		st.set_uv(Vector2(0, i + 1))
		st.add_vertex(p4)
		st.set_uv(Vector2(1, i + 1))
		st.add_vertex(p3)
	
	st.generate_normals()
	road_mesh_instance.mesh = st.commit()
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.DARK_GRAY
	road_mesh_instance.set_surface_override_material(0, material)
	
	_create_collision()

func _create_collision():
	for child in road_mesh_instance.get_children():
		if child is StaticBody3D:
			child.queue_free()
	
	var static_body = StaticBody3D.new()
	road_mesh_instance.add_child(static_body)
	static_body.owner = get_tree().edited_scene_root
	
	var collision_shape = CollisionShape3D.new()
	static_body.add_child(collision_shape)
	collision_shape.owner = get_tree().edited_scene_root
	
	var shape = road_mesh_instance.mesh.create_trimesh_shape()
	collision_shape.shape = shape
	
	
	
	
	
	
	
	
	
	
	
