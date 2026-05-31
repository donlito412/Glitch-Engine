extends RefCounted

static func generate(terrain_type: String, save_path: String, params: Dictionary = {}) -> void:
	var size: float = params.get("size", 500.0)
	var height_scale: float = params.get("height", 55.0)
	var water: bool = params.get("water", true)
	var noise_seed: int = params.get("seed", 42)

	var folder = save_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))

	var terrain_mesh = _build_terrain_mesh(terrain_type, size, height_scale, noise_seed)
	var mesh_path = folder + "/terrain.mesh"
	ResourceSaver.save(terrain_mesh, mesh_path)

	var terrain_shape = terrain_mesh.create_trimesh_shape()
	var shape_path = folder + "/terrain_collision.res"
	ResourceSaver.save(terrain_shape, shape_path)

	var terrain_mat = _build_terrain_material(height_scale)
	var terrain_mat_path = folder + "/terrain_material.tres"
	ResourceSaver.save(terrain_mat, terrain_mat_path)

	var water_mesh_path = ""
	var water_mat_path = ""
	if water:
		var water_mesh = _build_water_mesh(size)
		water_mesh_path = folder + "/water.mesh"
		ResourceSaver.save(water_mesh, water_mesh_path)
		var water_mat = _build_water_material()
		water_mat_path = folder + "/water_material.tres"
		ResourceSaver.save(water_mat, water_mat_path)

	var env = _build_environment()
	var env_path = folder + "/environment.tres"
	ResourceSaver.save(env, env_path)

	_write_tscn(save_path, mesh_path, shape_path, terrain_mat_path, water_mesh_path, water_mat_path, env_path, height_scale)
	print("[GlitchAI] Scene saved: ", save_path)

static func _build_environment() -> Environment:
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.08, 0.18, 0.48)
	sky_mat.sky_horizon_color = Color(0.88, 0.52, 0.18)
	sky_mat.sky_curve = 0.06
	sky_mat.sky_energy_multiplier = 1.4
	sky_mat.ground_bottom_color = Color(0.05, 0.04, 0.02)
	sky_mat.ground_horizon_color = Color(0.40, 0.26, 0.10)
	sky_mat.ground_curve = 0.06
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.05
	sky_mat.sky_energy_multiplier = 1.4

	var sky_res = Sky.new()
	sky_res.sky_material = sky_mat
	sky_res.radiance_size = Sky.RADIANCE_SIZE_512

	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_color = Color(0.95, 0.82, 0.60)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 1.3

	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.85
	env.glow_strength = 1.2
	env.glow_bloom = 0.14
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.88
	env.glow_hdr_scale = 2.0

	env.ssao_enabled = true
	env.ssao_radius = 1.8
	env.ssao_intensity = 2.2
	env.ssao_power = 1.5
	env.ssao_detail = 0.5
	env.ssao_horizon = 0.06
	env.ssao_sharpness = 0.98

	env.ssil_enabled = true
	env.ssil_radius = 5.0
	env.ssil_intensity = 1.0
	env.ssil_sharpness = 0.98

	env.fog_enabled = true
	env.fog_density = 0.0004
	env.fog_aerial_perspective = 0.22
	env.fog_sky_affect = 0.5
	env.fog_light_color = Color(0.82, 0.62, 0.38)
	env.fog_light_energy = 2.0
	env.fog_sun_scatter = 0.4

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.9, 0.85, 0.75)
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	env.volumetric_fog_gi_inject = 1.0
	env.volumetric_fog_anisotropy = 0.2
	env.volumetric_fog_length = 64.0

	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12

	return env

static func _build_terrain_material(height_scale: float) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """shader_type spatial;

uniform float height_scale = 55.0;

void fragment() {
	float height_n = clamp(VERTEX.y / height_scale, -0.3, 1.2);
	float slope = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	slope = slope * slope;

	vec3 sand = vec3(0.76, 0.70, 0.52);
	vec3 shore = vec3(0.62, 0.58, 0.40);
	vec3 grass_dark = vec3(0.14, 0.38, 0.07);
	vec3 grass_mid = vec3(0.22, 0.50, 0.11);
	vec3 grass_bright = vec3(0.30, 0.58, 0.15);
	vec3 dirt = vec3(0.32, 0.20, 0.08);
	vec3 rock_dark = vec3(0.22, 0.20, 0.17);
	vec3 rock_light = vec3(0.36, 0.34, 0.30);
	vec3 snow = vec3(0.88, 0.91, 0.94);

	vec3 base;
	if (height_n < 0.0) {
		base = mix(sand, shore, smoothstep(-0.3, 0.0, height_n));
	} else if (height_n < 0.12) {
		base = mix(shore, grass_dark, smoothstep(0.0, 0.12, height_n));
	} else if (height_n < 0.45) {
		float t = smoothstep(0.12, 0.45, height_n);
		base = mix(grass_dark, mix(grass_mid, grass_bright, t), t);
	} else if (height_n < 0.70) {
		base = mix(grass_bright, rock_light, smoothstep(0.45, 0.70, height_n));
	} else if (height_n < 0.88) {
		base = mix(rock_light, rock_dark, smoothstep(0.70, 0.88, height_n));
	} else {
		base = mix(rock_dark, snow, smoothstep(0.88, 1.05, height_n));
	}

	vec3 slope_col = mix(dirt, rock_dark, smoothstep(0.45, 0.78, slope));
	base = mix(base, slope_col, smoothstep(0.22, 0.60, slope));
	base = mix(base, rock_dark, smoothstep(0.62, 0.88, slope));

	float micro_n = fract(sin(dot(UV * 22.0 + VERTEX.xz * 0.08, vec2(127.1, 311.7))) * 43758.5);
	float macro_n = fract(sin(dot(VERTEX.xz * 0.03, vec2(269.5, 183.3))) * 43758.5);
	base += (micro_n - 0.5) * 0.022 + (macro_n - 0.5) * 0.012;

	ALBEDO = clamp(base, vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(0.96, 0.55, smoothstep(0.15, 0.75, slope));
	METALLIC = 0.0;
	SPECULAR = mix(0.06, 0.42, smoothstep(0.50, 0.90, slope));
}"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("height_scale", height_scale)
	return mat

static func _build_water_material() -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

void vertex() {
	float t = TIME * 0.55;
	VERTEX.y += sin(VERTEX.x * 1.40 + t * 1.20) * 0.28;
	VERTEX.y += sin(VERTEX.z * 1.10 + t * 0.85) * 0.22;
	VERTEX.y += sin((VERTEX.x + VERTEX.z) * 0.72 + t * 1.45) * 0.16;
	VERTEX.y += sin(VERTEX.x * 3.10 - t * 0.72) * 0.09;
	VERTEX.y += cos(VERTEX.z * 2.60 + t * 1.08) * 0.07;
	VERTEX.y += sin((VERTEX.x * 0.4 - VERTEX.z * 0.7) + t * 1.9) * 0.05;

	vec3 n = NORMAL;
	n.x -= cos(VERTEX.x * 1.40 + t * 1.20) * 0.28 * 1.40;
	n.x -= cos((VERTEX.x + VERTEX.z) * 0.72 + t * 1.45) * 0.16 * 0.72;
	n.z -= cos(VERTEX.z * 1.10 + t * 0.85) * 0.22 * 1.10;
	n.z -= cos((VERTEX.x + VERTEX.z) * 0.72 + t * 1.45) * 0.16 * 0.72;
	NORMAL = normalize(n);
}

void fragment() {
	float fresnel = pow(clamp(1.0 - dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 1.8);

	vec3 shallow = vec3(0.10, 0.50, 0.72);
	vec3 mid = vec3(0.05, 0.28, 0.52);
	vec3 deep = vec3(0.02, 0.10, 0.30);
	vec3 foam = vec3(0.86, 0.93, 0.97);

	vec3 col = mix(shallow, mid, fresnel * 0.5);
	col = mix(col, deep, fresnel * fresnel * 0.5);
	col = mix(col, foam, pow(fresnel, 5.5) * 0.50);

	float crest = clamp((NORMAL.y - 0.92) * 12.0, 0.0, 1.0);
	col = mix(col, foam, crest * 0.65);

	ALBEDO = col;
	ALPHA = mix(0.65, 0.94, fresnel * 0.55 + 0.28);
	ROUGHNESS = mix(0.04, 0.01, fresnel);
	METALLIC = 0.0;
	SPECULAR = 0.98;
}"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	return mat

static func _build_terrain_mesh(terrain_type: String, size: float, height_scale: float, noise_seed: int) -> ArrayMesh:
	var noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 0.0055
	noise.fractal_octaves = 8
	noise.fractal_gain = 0.50
	noise.fractal_lacunarity = 2.1
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = 120.0
	noise.domain_warp_frequency = 0.004
	noise.domain_warp_fractal_octaves = 5

	var ridge_noise = FastNoiseLite.new()
	ridge_noise.seed = noise_seed + 777
	ridge_noise.frequency = 0.012
	ridge_noise.fractal_octaves = 5
	ridge_noise.fractal_gain = 0.45
	ridge_noise.fractal_lacunarity = 2.3
	ridge_noise.domain_warp_enabled = true
	ridge_noise.domain_warp_amplitude = 60.0
	ridge_noise.domain_warp_frequency = 0.006

	var detail_noise = FastNoiseLite.new()
	detail_noise.seed = noise_seed + 333
	detail_noise.frequency = 0.065
	detail_noise.fractal_octaves = 3

	var resolution = 120
	var half = size / 2.0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in range(resolution + 1):
		for x in range(resolution + 1):
			var xf = (float(x) / resolution) * size - half
			var zf = (float(z) / resolution) * size - half
			var h = _get_height(noise, ridge_noise, detail_noise, xf, zf, size, height_scale, terrain_type)
			st.set_uv(Vector2(float(x) / resolution * 12.0, float(z) / resolution * 12.0))
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

static func _get_height(noise: FastNoiseLite, ridge_noise: FastNoiseLite, detail_noise: FastNoiseLite, xf: float, zf: float, size: float, height_scale: float, terrain_type: String) -> float:
	var base_n = noise.get_noise_2d(xf, zf)

	var r = ridge_noise.get_noise_2d(xf, zf)
	var ridge = 1.0 - abs(r)
	ridge = ridge * ridge * ridge

	var detail = detail_noise.get_noise_2d(xf, zf) * 0.08

	var h = (base_n * 0.52 + ridge * 0.40 + detail) * height_scale

	if terrain_type == "island":
		var dist = Vector2(xf, zf).length() / (size * 0.38)
		var mask = clamp(1.0 - dist * dist, 0.0, 1.0)
		mask = mask * mask * mask
		h = h * mask - (1.0 - mask) * height_scale * 0.35
	elif terrain_type == "mountains":
		var r2 = abs(ridge_noise.get_noise_2d(xf * 0.6, zf * 0.6))
		h = (ridge * 0.60 + (1.0 - r2) * r2 * 0.40 + detail) * height_scale * 1.8
	elif terrain_type == "plains":
		h = (base_n * 0.28 + ridge * 0.08 + detail) * height_scale * 0.30
	elif terrain_type == "world":
		h = (base_n * 0.58 + ridge * 0.34 + detail) * height_scale

	return h

static func _build_water_mesh(size: float) -> ArrayMesh:
	var res = 40
	var half = size * 0.70
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(res + 1):
		for x in range(res + 1):
			var xf = (float(x) / res) * half * 2.0 - half
			var zf = (float(z) / res) * half * 2.0 - half
			st.set_uv(Vector2(float(x) / res * 6.0, float(z) / res * 6.0))
			st.add_vertex(Vector3(xf, 0.0, zf))
	for z in range(res):
		for x in range(res):
			var i = z * (res + 1) + x
			st.add_index(i)
			st.add_index(i + res + 1)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + res + 1)
			st.add_index(i + res + 2)
	st.generate_normals()
	return st.commit()

static func _write_tscn(save_path: String, mesh_path: String, shape_path: String, terrain_mat_path: String, water_mesh_path: String, water_mat_path: String, env_path: String, height_scale: float) -> void:
	var load_steps = 4
	if water_mesh_path != "":
		load_steps += 2

	var L: PackedStringArray = []
	L.append("[gd_scene load_steps=" + str(load_steps) + " format=3]")
	L.append("")
	L.append("[ext_resource type=\"Mesh\" path=\"" + mesh_path + "\" id=\"1\"]")
	L.append("[ext_resource type=\"Shape3D\" path=\"" + shape_path + "\" id=\"2\"]")
	L.append("[ext_resource type=\"Material\" path=\"" + terrain_mat_path + "\" id=\"3\"]")
	L.append("[ext_resource type=\"Environment\" path=\"" + env_path + "\" id=\"4\"]")
	if water_mesh_path != "":
		L.append("[ext_resource type=\"Mesh\" path=\"" + water_mesh_path + "\" id=\"5\"]")
		L.append("[ext_resource type=\"Material\" path=\"" + water_mat_path + "\" id=\"6\"]")
	L.append("")
	L.append("[node name=\"Scene\" type=\"Node3D\"]")
	L.append("")
	L.append("[node name=\"Sun\" type=\"DirectionalLight3D\" parent=\".\"]")
	L.append("rotation = Vector3(-0.28, 0.88, 0.0)")
	L.append("light_color = Color(1.0, 0.84, 0.58)")
	L.append("light_energy = 2.2")
	L.append("shadow_enabled = true")
	L.append("shadow_bias = 0.03")
	L.append("shadow_blur = 1.5")
	L.append("directional_shadow_max_distance = 500.0")
	L.append("directional_shadow_mode = 2")
	L.append("directional_shadow_fade_start = 0.85")
	L.append("")
	L.append("[node name=\"FillLight\" type=\"DirectionalLight3D\" parent=\".\"]")
	L.append("rotation = Vector3(-0.6, -2.2, 0.0)")
	L.append("light_color = Color(0.48, 0.58, 0.82)")
	L.append("light_energy = 0.35")
	L.append("shadow_enabled = false")
	L.append("")
	L.append("[node name=\"Terrain\" type=\"StaticBody3D\" parent=\".\"]")
	L.append("")
	L.append("[node name=\"TerrainMesh\" type=\"MeshInstance3D\" parent=\"Terrain\"]")
	L.append("mesh = ExtResource(\"1\")")
	L.append("surface_material_override/0 = ExtResource(\"3\")")
	L.append("cast_shadow = 1")
	L.append("gi_mode = 1")
	L.append("")
	L.append("[node name=\"TerrainCollision\" type=\"CollisionShape3D\" parent=\"Terrain\"]")
	L.append("shape = ExtResource(\"2\")")
	L.append("")
	if water_mesh_path != "":
		L.append("[node name=\"Water\" type=\"MeshInstance3D\" parent=\".\"]")
		L.append("mesh = ExtResource(\"5\")")
		L.append("surface_material_override/0 = ExtResource(\"6\")")
		L.append("transparency = 1")
		L.append("cast_shadow = 0")
		L.append("")
	L.append("[node name=\"PlayerSpawn\" type=\"Marker3D\" parent=\".\"]")
	L.append("position = Vector3(0, " + str(height_scale * 0.65) + ", 0)")
	L.append("")
	L.append("[node name=\"WorldEnvironment\" type=\"WorldEnvironment\" parent=\".\"]")
	L.append("environment = ExtResource(\"4\")")

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(L))
		file.close()
