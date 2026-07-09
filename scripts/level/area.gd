## Level graybox M1: lantai datar + environment gelap-neon dasar + dummy latihan.
## M4 memecah menjadi 3 zona (Gerbang Kuil, Koridor Terkutuk, Arena Boss).
extends Node3D

const DUMMY_SCENE := preload("res://scenes/enemies/dummy.tscn")

func _ready() -> void:
	_build_environment()
	_build_graybox()
	_spawn_dummy()

func get_player_spawn() -> Vector3:
	return Vector3(0, 0.15, 8)

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.051, 0.039, 0.078)  # #0d0a14
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.1, 0.18)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.045, 0.1)
	env.fog_density = 1.4 / Balance.LEVEL.fog_distance  # jarak pandang ±30 m
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# satu-satunya shadow caster
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_color = Color(0.65, 0.7, 0.95)
	sun.light_energy = 0.4
	sun.shadow_enabled = true
	add_child(sun)

func _build_graybox() -> void:
	_static_box(Vector3(60, 1, 60), Vector3(0, -0.5, 0), Palette.STONE)      # lantai
	_static_box(Vector3(60, 4, 1), Vector3(0, 2, -30), Palette.STONE)        # dinding
	_static_box(Vector3(60, 4, 1), Vector3(0, 2, 30), Palette.STONE)
	_static_box(Vector3(1, 4, 60), Vector3(-30, 2, 0), Palette.STONE)
	_static_box(Vector3(1, 4, 60), Vector3(30, 2, 0), Palette.STONE)
	# pilar orientasi
	for p in [Vector3(-8, 1.75, -8), Vector3(8, 1.75, -8), Vector3(-8, 1.75, 8), Vector3(8, 1.75, 8)]:
		_static_box(Vector3(1.2, 3.5, 1.2), p, Palette.STONE)

func _static_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1  # world
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)

func _spawn_dummy() -> void:
	var d := DUMMY_SCENE.instantiate()
	d.position = Vector3(0, 0, 0)
	add_child(d)
