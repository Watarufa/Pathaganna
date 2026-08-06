## Ganna — altar checkpoint: TV tua di atas altar batu berlilin.
## Tekan E di dekatnya → layar statis berubah jadi sigil ungu, checkpoint
## tersimpan di GameManager, dan HP player dipulihkan.
##
## Sekali aktif tetap aktif: mendekatinya lagi hanya memindahkan titik respawn,
## tidak "mematikan" yang sebelumnya.
class_name Ganna
extends Node3D

@export var id: String = "ganna"

var activated := false

var _screen: MeshInstance3D
var _sigil: Node3D
var _screen_mat: StandardMaterial3D
var _player_near := false
var _time := 0.0

func _ready() -> void:
	add_to_group("ganna")
	_build()
	# checkpoint yang sudah diaktifkan tetap menyala setelah player mati & respawn
	if GameManager.checkpoint_id == id:
		_light_up(false)
	# player lama di-free saat respawn; tanpa reset ini prompt bisa nyangkut
	# menyala walau player barunya berada di tempat lain
	CombatEvents.player_respawned.connect(_on_player_respawned)

func _on_player_respawned() -> void:
	_player_near = false
	CombatEvents.interact_prompt.emit("")

func _build() -> void:
	# altar batu bertingkat
	Props.solid_box(self, Vector3(2.2, 0.35, 2.2), Vector3(0, 0.175, 0), Palette.STONE)
	Props.solid_box(self, Vector3(1.7, 0.35, 1.7), Vector3(0, 0.52, 0), Palette.STONE)
	Props.solid_box(self, Vector3(1.1, 0.5, 1.1), Vector3(0, 0.95, 0), Palette.STONE)

	# TV tua di atas altar
	var tv := Props.mesh_box(self, Vector3(0.9, 0.72, 0.78), Vector3(0, 1.56, 0), Palette.METAL)
	Props.mesh_box(tv, Vector3(0.98, 0.08, 0.86), Vector3(0, -0.4, 0), Palette.CABLE)
	_screen_mat = Palette.CRT_SCREEN.duplicate()
	_screen = Props.mesh_box(tv, Vector3(0.66, 0.5, 0.03), Vector3(0, 0.03, -0.4), _screen_mat)

	# sigil ungu — tersembunyi sampai diaktifkan
	_sigil = Node3D.new()
	_sigil.position = Vector3(0, 0.03, -0.44)
	_sigil.visible = false
	tv.add_child(_sigil)
	for i in 3:
		var ring := Props.mesh_box(_sigil, Vector3(0.34 - 0.09 * float(i), 0.012, 0.012),
			Vector3.ZERO, Palette.SIGIL, Vector3(0, 0, 60.0 * float(i)))
		ring.name = "Ring%d" % i
	Props.mesh_box(_sigil, Vector3(0.012, 0.3, 0.012), Vector3.ZERO, Palette.SIGIL)

	# antena + kabel yang menjalar turun dari altar
	Props.mesh_box(tv, Vector3(0.015, 0.5, 0.015), Vector3(-0.16, 0.62, 0), Palette.METAL,
		Vector3(0, 0, -18))
	Props.mesh_box(tv, Vector3(0.015, 0.42, 0.015), Vector3(0.16, 0.58, 0), Palette.METAL,
		Vector3(0, 0, 22))
	Props.cable_run(self, Vector3(0.3, 1.15, 0.35), Vector3(1.6, 0.05, 1.4), -0.15)
	Props.cable_run(self, Vector3(-0.3, 1.15, 0.35), Vector3(-1.5, 0.05, 1.7), -0.15)

	# lilin di sudut altar
	for c in [Vector3(0.72, 0.7, 0.72), Vector3(-0.72, 0.7, 0.72),
			Vector3(0.72, 0.7, -0.72), Vector3(-0.72, 0.7, -0.72)]:
		Props.candle(self, c)

	# area interaksi
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # player_body
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Balance.LEVEL.ganna_range
	col.shape = sphere
	col.position = Vector3(0, 1.0, 0)
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	_time += delta
	if activated:
		_sigil.rotation.z = _time * 0.7
		_screen_mat.emission_energy_multiplier = 1.6 + 0.5 * sin(_time * 2.2)
	# Input di-poll, bukan lewat _unhandled_input: konsisten dengan player, dan
	# tetap terpicu oleh Input.action_press() yang dipakai harness smoke test.
	if _player_near and GameManager.state == GameManager.GameState.PLAYING \
			and Input.is_action_just_pressed("interact"):
		_activate()

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = true
	_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	CombatEvents.interact_prompt.emit("")

func _activate() -> void:
	var was_active := activated
	GameManager.set_checkpoint(id)
	_light_up(true)
	_update_prompt()
	# mengaktifkan Ganna memulihkan HP — pengganti "istirahat" ala soulslike
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		player.health.heal_full()
	if not was_active:
		HitSpark.spawn(self, global_position + Vector3(0, 1.6, -0.5),
			Color(0.706, 0.298, 1.0), 34, 6.0, 0.07)

func _light_up(with_flash: bool) -> void:
	activated = true
	_sigil.visible = true
	_screen_mat.albedo_color = Color(0.12, 0.05, 0.2)
	_screen_mat.emission = Color(0.45, 0.16, 0.75)
	_screen_mat.emission_energy_multiplier = 1.8
	if with_flash:
		TimeJuice.hitstop(0.06, 0.25)

func _update_prompt() -> void:
	if not _player_near:
		return
	if GameManager.checkpoint_id == id:
		CombatEvents.interact_prompt.emit("GANNA AKTIF")
	elif activated:
		CombatEvents.interact_prompt.emit("E  —  Kembali ke Ganna ini")
	else:
		CombatEvents.interact_prompt.emit("E  —  Aktifkan Ganna")
