## Kuil Siaran — tiga zona tersambung dalam satu scene.
##
##   Zona 1 "Gerbang Kuil"      z +16 … −8    halaman reruntuhan, Ganna A, 2 Kultis
##   Zona 2 "Koridor Terkutuk"  z −8 … −40    lorong pilar & CRT, 3 Kultis + 2 Penyiar, Ganna B
##   Zona 3 "Arena Boss"        z −40 … −70   ruang siaran melingkar (boss menyusul di M5)
##
## Total 7 musuh, tapi jarak antar-zona lebih besar dari radius deteksi terjauh
## (14 m), jadi yang aktif bersamaan tidak pernah melebihi 5 — di bawah batas
## performa ENEMY_COMMON.max_active.
extends Node3D

const DUMMY_SCENE := preload("res://scenes/enemies/dummy.tscn")
const KULTIS_SCENE := preload("res://scenes/enemies/kultis.tscn")
const PENYIAR_SCENE := preload("res://scenes/enemies/penyiar.tscn")
const GANNA_SCENE := preload("res://scenes/level/ganna.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")

const SPAWN_POINT := Vector3(0, 0.15, 13)

const SPAWNS := [
	# Zona 1 — ruang lapang untuk belajar parry
	{ kind = "kultis", pos = Vector3(-5, 0, 1) },
	{ kind = "kultis", pos = Vector3(4, 0, -3) },
	# Zona 2 — campuran yang memaksa manajemen posisi
	{ kind = "kultis", pos = Vector3(-4, 0, -15) },
	{ kind = "penyiar", pos = Vector3(6, 0, -19) },
	{ kind = "kultis", pos = Vector3(3, 0, -25) },
	{ kind = "penyiar", pos = Vector3(-6, 0, -30) },
	{ kind = "kultis", pos = Vector3(0, 0, -34) },
]

var _enemies: Array[EnemyBase] = []
var _time := 0.0

func _ready() -> void:
	_build_environment()
	_build_zone1()
	_build_zone2()
	_build_zone3()
	_spawn_gannas()
	_spawn_enemies()
	_spawn_training_dummies()
	_build_systems()

func _process(delta: float) -> void:
	_time += delta
	Props.animate_flicker(_time)

## Titik respawn: Ganna terakhir yang diaktifkan, atau mulut kuil kalau belum ada.
func get_player_spawn() -> Vector3:
	if GameManager.checkpoint_id != "":
		for g in get_tree().get_nodes_in_group("ganna"):
			if is_instance_valid(g) and g.id == GameManager.checkpoint_id:
				return g.global_position + Vector3(0, 0.15, 2.2)
	return SPAWN_POINT

## Death loop: semua musuh kembali ke kondisi awal saat player respawn.
func reset_enemies() -> void:
	for e in _enemies:
		if not is_instance_valid(e):
			_rebuild_enemies()
			return
	for e in _enemies:
		e.reset()
	_clear_projectiles()

func _rebuild_enemies() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	_clear_projectiles()
	_spawn_enemies()

func _clear_projectiles() -> void:
	for n in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(n):
			n.queue_free()

# ------------------------------------------------------------- zona
func _build_zone1() -> void:
	# halaman reruntuhan di mulut kuil
	Props.solid_box(self, Vector3(34, 1, 26), Vector3(0, -0.5, 4), Palette.STONE)
	Props.solid_box(self, Vector3(34, 6, 1), Vector3(0, 3, 17), Palette.STONE)
	Props.solid_box(self, Vector3(1, 6, 26), Vector3(-17, 3, 4), Palette.STONE)
	Props.solid_box(self, Vector3(1, 6, 26), Vector3(17, 3, 4), Palette.STONE)

	# gerbang kuil: dua pilar besar + ambang
	Props.pillar(self, Vector3(-4.5, 0, -8), 5.4)
	Props.pillar(self, Vector3(4.5, 0, -8), 5.4)
	Props.solid_box(self, Vector3(11, 0.8, 1.4), Vector3(0, 5.6, -8), Palette.STONE)
	# dinding dengan celah pintu menuju koridor
	Props.solid_box(self, Vector3(11.5, 6, 1), Vector3(-11.2, 3, -8), Palette.STONE)
	Props.solid_box(self, Vector3(11.5, 6, 1), Vector3(11.2, 3, -8), Palette.STONE)

	for p in [Vector3(-12, 0, 8), Vector3(12, 0, 8), Vector3(-12, 0, -1), Vector3(12, 0, -1)]:
		Props.pillar(self, p, 4.0)
	for r in [Vector3(-8, 0, 12), Vector3(9, 0, 3), Vector3(-13, 0, 4)]:
		Props.rubble(self, r)
	Props.antenna(self, Vector3(-14, 0, 12), 3.4)
	Props.crt_stack(self, Vector3(13.5, 0, 11), 2, 200)
	Props.cable_run(self, Vector3(-4.5, 0.1, -7), Vector3(-12, 0.1, -1))
	Props.cable_run(self, Vector3(4.5, 0.1, -7), Vector3(12, 0.1, -1))

func _build_zone2() -> void:
	# lorong panjang: lebih sempit, lebih padat
	Props.solid_box(self, Vector3(20, 1, 33), Vector3(0, -0.5, -24), Palette.STONE)
	Props.solid_box(self, Vector3(1, 6, 33), Vector3(-10, 3, -24), Palette.STONE)
	Props.solid_box(self, Vector3(1, 6, 33), Vector3(10, 3, -24), Palette.STONE)

	# barisan pilar di kedua sisi + kabel yang menjalar di antaranya
	var z := -12.0
	while z > -38.0:
		Props.pillar(self, Vector3(-7.5, 0, z), 4.6)
		Props.pillar(self, Vector3(7.5, 0, z), 4.6)
		Props.cable_run(self, Vector3(-7.5, 3.6, z), Vector3(7.5, 3.6, z), -0.9)
		z -= 6.5

	# tumpukan CRT menyala statis — sumber cahaya utama koridor
	Props.crt_stack(self, Vector3(-8.6, 0, -14), 4, 90)
	Props.crt_stack(self, Vector3(8.6, 0, -21), 3, -90)
	Props.crt_stack(self, Vector3(-8.8, 0, -28), 3, 90)
	Props.crt_stack(self, Vector3(8.5, 0, -34), 4, -90)
	Props.antenna(self, Vector3(-8.8, 0, -19), 2.8)
	Props.antenna(self, Vector3(8.8, 0, -30), 3.2)
	Props.cable_run(self, Vector3(-8, 0.1, -13), Vector3(-8, 0.1, -35))
	Props.cable_run(self, Vector3(8, 0.1, -13), Vector3(8, 0.1, -35))

	# ambang menuju arena
	Props.solid_box(self, Vector3(6, 6, 1), Vector3(-7, 3, -40), Palette.STONE)
	Props.solid_box(self, Vector3(6, 6, 1), Vector3(7, 3, -40), Palette.STONE)
	Props.solid_box(self, Vector3(20, 1.4, 1.4), Vector3(0, 5.3, -40), Palette.STONE)

func _build_zone3() -> void:
	# ruang siaran melingkar (boss + gerbang penutup menyusul di M5)
	Props.solid_box(self, Vector3(34, 1, 32), Vector3(0, -0.5, -55), Palette.STONE)
	var ring := 16
	for i in ring:
		var a := TAU * float(i) / float(ring)
		var pos := Vector3(sin(a) * 16.0, 0, -55.0 + cos(a) * 15.0)
		if pos.z > -42.0:
			continue  # sisakan celah untuk pintu masuk dari koridor
		Props.solid_box(self, Vector3(4.6, 7, 1.6), pos + Vector3(0, 3.5, 0),
			Palette.STONE, Vector3(0, rad_to_deg(a), 0))
		if i % 2 == 0:
			Props.crt_stack(self, pos * 0.86 + Vector3(0, 0, -55.0 * 0.14), 3, rad_to_deg(a))
	Props.antenna(self, Vector3(0, 0, -66), 5.0)
	for i in 6:
		var a := TAU * float(i) / 6.0
		Props.cable_run(self, Vector3(0, 0.1, -55), Vector3(sin(a) * 13.0, 0.1, -55.0 + cos(a) * 12.0))

func _spawn_gannas() -> void:
	# Ganna A di halaman: titik mulai
	var a: Ganna = GANNA_SCENE.instantiate()
	a.id = "ganna_gerbang"
	a.position = Vector3(0, 0, 10)
	add_child(a)
	# Ganna B di ujung koridor, tepat sebelum arena
	var b: Ganna = GANNA_SCENE.instantiate()
	b.id = "ganna_koridor"
	b.position = Vector3(0, 0, -37)
	add_child(b)

func _spawn_enemies() -> void:
	for s in SPAWNS:
		var scene: PackedScene = KULTIS_SCENE if s.kind == "kultis" else PENYIAR_SCENE
		var e: EnemyBase = scene.instantiate()
		e.position = s.pos
		add_child(e)
		_enemies.append(e)

## Dummy latihan hanya untuk sesi dev — level sungguhan tidak memakainya.
func _spawn_training_dummies() -> void:
	var args := OS.get_cmdline_user_args()
	if not ("--smoke" in args or "--combat-smoke" in args or "--dummies" in args):
		return
	for pos in [Vector3(-12, 0, 13), Vector3(-9, 0, 15)]:
		var d := DUMMY_SCENE.instantiate()
		d.position = pos
		add_child(d)

func _build_systems() -> void:
	var style := StyleMeter.new()
	style.name = "StyleMeter"
	add_child(style)

	var fx := FxSpawner.new()
	fx.name = "FxSpawner"
	add_child(fx)

	add_child(HUD_SCENE.instantiate())
	add_child(PAUSE_SCENE.instantiate())

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
