## Level graybox M3: arena datar + environment gelap-neon dasar, dua gugus musuh,
## dan perakitan sistem per-sesi (style meter, penyulut VFX, HUD).
## M4 memecah ini menjadi 3 zona (Gerbang Kuil, Koridor Terkutuk, Arena Boss).
extends Node3D

const DUMMY_SCENE := preload("res://scenes/enemies/dummy.tscn")
const KULTIS_SCENE := preload("res://scenes/enemies/kultis.tscn")
const PENYIAR_SCENE := preload("res://scenes/enemies/penyiar.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

## Penempatan musuh per zona. Total tetap di bawah ENEMY_COMMON.max_active
## supaya batas performa terjaga (dummy latihan tidak dihitung — ia prop).
const SPAWNS := [
	# Zona 1 — Gerbang Kuil: ruang lapang, dua Kultis untuk belajar parry
	{ kind = "kultis", pos = Vector3(-6, 0, -6) },
	{ kind = "kultis", pos = Vector3(5, 0, -9) },
	# Zona 2 — Koridor Terkutuk: campuran yang memaksa manajemen posisi
	{ kind = "kultis", pos = Vector3(-3, 0, -18) },
	{ kind = "penyiar", pos = Vector3(-10, 0, -21) },
	{ kind = "penyiar", pos = Vector3(8, 0, -20) },
]

var _enemies: Array[EnemyBase] = []

func _ready() -> void:
	_build_environment()
	_build_graybox()
	_spawn_dummies()
	_spawn_enemies()
	_build_systems()

func get_player_spawn() -> Vector3:
	return Vector3(0, 0.15, 8)

## Death loop: semua musuh kembali ke kondisi awal saat player respawn.
func reset_enemies() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.reset()
		else:
			_respawn_missing()
			return
	_clear_projectiles()

## Ada musuh yang sudah di-free (mati) — bangun ulang seluruh gugus.
func _respawn_missing() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	_clear_projectiles()
	_spawn_enemies()

func _clear_projectiles() -> void:
	for n in get_children():
		if n is SignalProjectile:
			n.queue_free()

func _spawn_enemies() -> void:
	for s in SPAWNS:
		var scene: PackedScene = KULTIS_SCENE if s.kind == "kultis" else PENYIAR_SCENE
		var e: EnemyBase = scene.instantiate()
		e.position = s.pos
		add_child(e)
		_enemies.append(e)

func _build_systems() -> void:
	var style := StyleMeter.new()
	style.name = "StyleMeter"
	add_child(style)

	var fx := FxSpawner.new()
	fx.name = "FxSpawner"
	add_child(fx)

	add_child(HUD_SCENE.instantiate())

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
	_static_box(Vector3(60, 1, 70), Vector3(0, -0.5, -5), Palette.STONE)     # lantai
	_static_box(Vector3(60, 4, 1), Vector3(0, 2, -40), Palette.STONE)        # dinding
	_static_box(Vector3(60, 4, 1), Vector3(0, 2, 30), Palette.STONE)
	_static_box(Vector3(1, 4, 70), Vector3(-30, 2, -5), Palette.STONE)
	_static_box(Vector3(1, 4, 70), Vector3(30, 2, -5), Palette.STONE)
	# pilar orientasi
	for p in [Vector3(-8, 1.75, -8), Vector3(8, 1.75, -8), Vector3(-8, 1.75, 8), Vector3(8, 1.75, 8),
			Vector3(-12, 1.75, -20), Vector3(12, 1.75, -20)]:
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

func _spawn_dummies() -> void:
	# dummy latihan tetap ada di dekat spawn — target aman untuk menguji feel
	for pos in [Vector3(0, 0, 0), Vector3(6, 0, -4)]:
		var d := DUMMY_SCENE.instantiate()
		d.position = pos
		add_child(d)
