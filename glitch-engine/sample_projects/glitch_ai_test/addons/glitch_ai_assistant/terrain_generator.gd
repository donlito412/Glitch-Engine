extends RefCounted

static func generate(terrain_type: String, save_path: String, params: Dictionary = {}) -> void:
	var size: float = params.get("size", 300.0)
	var height_scale: float = params.get("height", 25.0)
	var water: bool = params.get("water", true)
	var noise_seed: int = params.get("seed", 12345)

	var folder = save_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))

	var terrain_mesh = _build_terrain_mesh(terrain_type, size, height_scale, noise_seed)
	var mesh_path = folder + "/terrain.mesh"
	ResourceSaver.save(terrain_mesh, mesh_path)

	var terrain_shape = terrain_mesh.create_trimesh_shape()
	var shape_path = folder + "/terrain_collision.res"
	ResourceSaver.save(terrain_shape, shape_path)

	var water_mesh_path = ""
	if water:
		var water_mesh = _build_water_mesh(size)
		water_mesh_path = folder + "/water.mesh"
		ResourceSaver.save(water_mesh, water_mesh_path)

	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.18, 0.42, 0.78)
	sky_mat.sky_horizon_color = Color(0.72, 0.88, 1.0)
	sky_mat.ground_bottom_color = Color(0.3, 0.5, 0.4)
	sky_mat.ground_horizon_color = Color(0.72, 0.88, 1.0)

	var sky_res = Sky.new()
	sky_res.sky_material = sky_mat

	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var env_path = folder + "/environment.tres"
	ResourceSaver.save(env, env_path)

	_write_tscn(save_path, mesh_path, shape_path, water_mesh_path, env_path, height_scale)
	print("[GlitchAI] Terrain saved to: ", save_path)

static func _build_terrain_mesh(terrain_type: String, size: float, height_scale: float, noise_seed: int) -> ArrayMesh:
	var noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 0.018
	noise.fractal_octaves = 6

	var resolution = 80
	var half = size / 2.0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in range(resolution + 1):
		for x in range(resolution + 1):
			var xf = (float(x) / resolution) * size - half
			var zf = (float(z) / resolution) * size - half
			var h = _get_height(noise, xf, zf, size, height_scale, terrain_type)
			st.set_uv(Vector2(float(x) / resolution * 8.0, float(z) / resolution * 8.0))
			st.add_vertex(Vector3(xf, h, zf))

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
		var mask = clamp(1.0 - dist * dist * dist, 0.0, 1.0)
		h = h * mask + (mask - 1.0) * height_scale * 0.5
	elif terrain_type == "mountains":
		h = abs(h) * 1.5
	elif terrain_type == "plains":
		h = h * 0.25

	return h

static func _build_water_mesh(size: float) -> ArrayMesh:
	var half = size * 0.75
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
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

static func _write_tscn(save_path: String, mesh_path: String, shape_path: String, water_mesh_path: String, env_path: String, height_scale: float) -> void:
	var load_steps = 3
	if water_mesh_path != "":
		load_steps += 1

	var L: PackedStringArray = []
	L.append("[gd_scene load_steps=" + str(load_steps) + " format=3]")
	L.append("")
	L.append("[ext_resource type=\"Mesh\" path=\"" + mesh_path + "\" id=\"1\"]")
	L.append("[ext_resource type=\"Shape3D\" path=\"" + shape_path + "\" id=\"2\"]")
	L.append("[ext_resource type=\"Environment\" path=\"" + env_path + "\" id=\"3\"]")
	if water_mesh_path != "":
		L.append("[ext_resource type=\"Mesh\" path=\"" + water_mesh_path + "\" id=\"4\"]")
	L.append("")
	L.append("[node name=\"Scene\" type=\"Node3D\"]")
	L.append("")
	L.append("[node name=\"Sun\" type=\"DirectionalLight3D\" parent=\".\"]")
	L.append("rotation = Vector3(-0.872665, 0.523599, 0)")
	L.append("light_energy = 1.3")
	L.append("shadow_enabled = true")
	L.append("")
	L.append("[node name=\"Terrain\" type=\"StaticBody3D\" parent=\".\"]")
	L.append("")
	L.append("[node name=\"TerrainMesh\" type=\"MeshInstance3D\" parent=\"Terrain\"]")
	L.append("mesh = ExtResource(\"1\")")
	L.append("")
	L.append("[node name=\"TerrainCollision\" type=\"CollisionShape3D\" parent=\"Terrain\"]")
	L.append("shape = ExtResource(\"2\")")
	L.append("")
	if water_mesh_path != "":
		L.append("[node name=\"Water\" type=\"MeshInstance3D\" parent=\".\"]")
		L.append("mesh = ExtResource(\"4\")")
		L.append("")
	L.append("[node name=\"PlayerSpawn\" type=\"Marker3D\" parent=\".\"]")
	L.append("position = Vector3(0, " + str(height_scale * 0.6) + ", 0)")
	L.append("")
	L.append("[node name=\"WorldEnvironment\" type=\"WorldEnvironment\" parent=\".\"]")
	L.append("environment = ExtResource(\"3\")")

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(L))
		file.close()
