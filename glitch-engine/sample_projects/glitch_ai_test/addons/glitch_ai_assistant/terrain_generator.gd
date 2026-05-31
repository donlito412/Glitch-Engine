@tool
extends RefCounted

# GlitchAI Terrain Generator
# Generates real procedural terrain scenes with hills, water, sky, and collision.
# Usage: TerrainGen.generate("island", "res://scenes/my_island/my_island.tscn", {})

static func generate(terrain_type: String, save_path: String, params: Dictionary = {}) -> void:
	var size: float = params.get("size", 300.0)
	var height_scale: float = params.get("height", 25.0)
	var water: bool = params.get("water", true)
	var noise_seed: int = params.get("seed", randi())

	var folder = save_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))

	# Generate terrain mesh
	var terrain_mesh = _build_terrain_mesh(terrain_type, size, height_scale, noise_seed)
	var mesh_path = folder + "/terrain.mesh"
	ResourceSaver.save(terrain_mesh, mesh_path)

	# Generate trimesh collision from the mesh
	var terrain_shape = terrain_mesh.create_trimesh_shape()
	var shape_path = folder + "/terrain_collision.res"
	ResourceSaver.save(terrain_shape, shape_path)

	# Generate water mesh if requested
	var water_mesh_path = ""
	if water:
		var water_mesh = _build_water_mesh(size)
		water_mesh_path = folder + "/water.mesh"
		ResourceSaver.save(water_mesh, water_mesh_path)

	# Generate sky material
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.18, 0.42, 0.78)
	sky_mat.sky_horizon_color = Color(0.72, 0.88, 1.0)
	sky_mat.ground_bottom_color = Color(0.3, 0.5, 0.4)
	sky_mat.ground_horizon_color = Color(0.72, 0.88, 1.0)
	sky_mat.sun_angle_max = 30.0
	var sky_path = folder + "/sky.tres"
	ResourceSaver.save(sky_mat, sky_path)

	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_res = Sky.new()
	sky_res.sky_material = sky_mat
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var env_path = folder + "/environment.tres"
	ResourceSaver.save(env, env_path)

	# Write the .tscn file
	_write_tscn(save_path, mesh_path, shape_path, water_mesh_path, env_path, size, height_scale, terrain_type)

	print("[GlitchAI] Terrain scene saved to: ", save_path)

static func _build_terrain_mesh(terrain_type: String, size: float, height_scale: float, noise_seed: int) -> ArrayMesh:
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = noise_seed
	noise.frequency = 0.018
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 6
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.1

	var resolution = 80
	var half = size / 2.0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build vertex grid
	for z in range(resolution + 1):
		for x in range(resolution + 1):
			var xf = (float(x) / resolution) * size - half
			var zf = (float(z) / resolution) * size - half
			var h = _get_height(noise, xf, zf, size, height_scale, terrain_type)
			var uv = Vector2(float(x) / resolution * 8.0, float(z) / resolution * 8.0)
			st.set_uv(uv)
			st.add_vertex(Vector3(xf, h, zf))

	# Build triangle indices
	for z in range(resolution):
		for x in range(resolution):
			var i = z * (resolution + 1) + x
			st.add_index(i)
			st.add_index(i + resolution + 1)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + resolution + 1)
			st.add_index(i + resolution + 2)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func _get_height(noise: FastNoiseLite, xf: float, zf: float, size: float, height_scale: float, terrain_type: String) -> float:
	var n = noise.get_noise_2d(xf, zf)
	var h = n * height_scale

	if terrain_type == "island":
		var dist = Vector2(xf, zf).length() / (size * 0.42)
		var island_mask = clamp(1.0 - dist * dist * dist, 0.0, 1.0)
		h = h * island_mask + (island_mask - 1.0) * height_scale * 0.5
	elif terrain_type == "mountains":
		h = abs(h) * 1.5 + noise.get_noise_2d(xf * 0.5, zf * 0.5) * height_scale * 0.5
	elif terrain_type == "plains":
		h = h * 0.3 + abs(noise.get_noise_2d(xf * 0.3, zf * 0.3)) * height_scale * 0.15

	return h

static func _build_water_mesh(size: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half = size / 2.0 * 1.5
	st.set_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-half, 0, -half))
	st.set_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-half, 0, half))
	st.set_uv(Vector2(1, 0))
	st.add_vertex(Vector3(half, 0, -half))
	st.set_uv(Vector2(1, 0))
	st.add_vertex(Vector3(half, 0, -half))
	st.set_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-half, 0, half))
	st.set_uv(Vector2(1, 1))
	st.add_vertex(Vector3(half, 0, half))
	st.generate_normals()
	return st.commit()

static func _write_tscn(save_path: String, mesh_path: String, shape_path: String, water_mesh_path: String, env_path: String, size: float, height_scale: float, terrain_type: String) -> void:
	var load_steps = 3
	if water_mesh_path != "":
		load_steps += 1

	var lines: PackedStringArray = []
	lines.append("[gd_scene load_steps=" + str(load_steps) + " format=3]")
	lines.append("")
	lines.append("[ext_resource type=\"Mesh\" path=\"" + mesh_path + "\" id=\"1\"]")
	lines.append("[ext_resource type=\"Shape3D\" path=\"" + shape_path + "\" id=\"2\"]")
	lines.append("[ext_resource type=\"Environment\" path=\"" + env_path + "\" id=\"3\"]")
	if water_mesh_path != "":
		lines.append("[ext_resource type=\"Mesh\" path=\"" + water_mesh_path + "\" id=\"4\"]")
	lines.append("")

	var root_name = terrain_type.capitalize() + "Scene"
	lines.append("[node name=\"" + root_name + "\" type=\"Node3D\"]")
	lines.append("")
	lines.append("[node name=\"Sun\" type=\"DirectionalLight3D\" parent=\".\"]")
	lines.append("rotation = Vector3(-0.872665, 0.523599, 0)")
	lines.append("light_energy = 1.3")
	lines.append("shadow_enabled = true")
	lines.append("shadow_bias = 0.05")
	lines.append("")
	lines.append("[node name=\"Terrain\" type=\"StaticBody3D\" parent=\".\"]")
	lines.append("")
	lines.append("[node name=\"TerrainMesh\" type=\"MeshInstance3D\" parent=\"Terrain\"]")
	lines.append("mesh = ExtResource(\"1\")")
	lines.append("cast_shadow = 1")
	lines.append("")
	lines.append("[node name=\"TerrainCollision\" type=\"CollisionShape3D\" parent=\"Terrain\"]")
	lines.append("shape = ExtResource(\"2\")")
	lines.append("")
	if water_mesh_path != "":
		lines.append("[node name=\"Water\" type=\"MeshInstance3D\" parent=\".\"]")
		lines.append("mesh = ExtResource(\"4\")")
		lines.append("")
	lines.append("[node name=\"PlayerSpawn\" type=\"Marker3D\" parent=\".\"]")
	lines.append("position = Vector3(0, " + str(height_scale * 0.6) + ", 0)")
	lines.append("")
	lines.append("[node name=\"WorldEnvironment\" type=\"WorldEnvironment\" parent=\".\"]")
	lines.append("environment = ExtResource(\"3\")")

	var tscn = "\n".join(lines)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(tscn)
		file.close()
