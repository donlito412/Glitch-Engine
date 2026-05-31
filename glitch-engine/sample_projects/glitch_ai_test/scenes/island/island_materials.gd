extends Node3D

func _ready() -> void:
	var terrain_mesh = get_node_or_null("Terrain/TerrainMesh")
	if terrain_mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.3, 0.15)
		terrain_mesh.material_override = mat

	var water = get_node_or_null("Water")
	if water:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.4, 0.8, 0.75)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water.material_override = mat

	_spawn_trees()

func _spawn_trees() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	for i in range(40):
		var tree = Node3D.new()
		tree.name = "Tree_" + str(i)

		# Trunk
		var trunk = MeshInstance3D.new()
		var trunk_mesh = CylinderMesh.new()
		trunk_mesh.top_radius = 0.2
		trunk_mesh.bottom_radius = 0.3
		trunk_mesh.height = 2.0
		trunk.mesh = trunk_mesh
		var trunk_mat = StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.35, 0.2, 0.1)
		trunk.material_override = trunk_mat
		trunk.position.y = 1.0
		tree.add_child(trunk)

		# Leaves
		var leaves = MeshInstance3D.new()
		var leaves_mesh = SphereMesh.new()
		leaves_mesh.radius = 1.2
		leaves_mesh.height = 2.4
		leaves.mesh = leaves_mesh
		var leaves_mat = StandardMaterial3D.new()
		leaves_mat.albedo_color = Color(0.1, 0.5, 0.1)
		leaves.material_override = leaves_mat
		leaves.position.y = 2.8
		tree.add_child(leaves)

		# Random position on island avoiding water
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(10.0, 120.0)
		tree.position.x = cos(angle) * dist
		tree.position.z = sin(angle) * dist
		tree.position.y = 0.0

		add_child(tree)
