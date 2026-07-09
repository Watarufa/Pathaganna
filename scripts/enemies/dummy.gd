## Dummy latihan M1/M2: target lock-on ber-hurtbox yang tidak pernah benar-benar mati.
## M2 menambahkan pola serangan putih/merah berkala. Bukan turunan enemy_base
## (itu untuk musuh sungguhan di M3) — ini prop latihan.
class_name TrainingDummy
extends StaticBody3D

var rig: PoseRig
var health: Health
var hurtbox: Hurtbox
var _screen: MeshInstance3D

func _ready() -> void:
	collision_layer = 4  # enemy_body
	collision_mask = 0
	add_to_group("lockon_targets")

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.9
	col.shape = cap
	col.position = Vector3(0, 0.95, 0)
	add_child(col)

	_build_rig()

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 16  # enemy_hurt
	hurtbox.collision_mask = 0
	hurtbox.position = Vector3(0, 1.1, 0)
	var hshape := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.45
	hcap.height = 1.7
	hshape.shape = hcap
	hurtbox.add_child(hshape)
	add_child(hurtbox)
	hurtbox.hit_received.connect(_on_hit)

	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.setup(Balance.DUMMY.hp)
	health.died.connect(_on_pseudo_death)

func _build_rig() -> void:
	rig = PoseRig.new()
	rig.name = "Rig"
	add_child(rig)

	rig.add_pivot("Hips", "", Vector3(0, 0.9, 0))
	rig.add_pivot("Torso", "Hips", Vector3(0, 0.1, 0))
	rig.add_pivot("Head", "Torso", Vector3(0, 0.62, 0))
	rig.add_pivot("ArmL", "Torso", Vector3(-0.3, 0.5, 0))
	rig.add_pivot("ArmR", "Torso", Vector3(0.3, 0.5, 0))

	# alas latihan (pengganti kaki)
	rig.attach_cylinder("Hips", 0.28, 0.9, Vector3(0, -0.45, 0), Palette.STONE)
	# badan berjubah
	rig.attach_box("Torso", Vector3(0.5, 0.8, 0.32), Vector3(0, 0.2, 0), Palette.CLOTH)
	# kepala monitor CRT + layar (layar = telegraph diegetik di M2)
	rig.attach_box("Head", Vector3(0.42, 0.34, 0.38), Vector3(0, 0.17, 0), Palette.METAL)
	_screen = rig.attach_box("Head", Vector3(0.3, 0.22, 0.02), Vector3(0, 0.17, -0.2), Palette.CRT_SCREEN)
	# lengan menggantung
	rig.attach_capsule("ArmL", 0.07, 0.55, Vector3(0, -0.28, 0), Palette.CLOTH)
	rig.attach_capsule("ArmR", 0.07, 0.55, Vector3(0, -0.28, 0), Palette.CLOTH)

func get_lockon_point() -> Vector3:
	return global_position + Vector3.UP * 1.35

# ------------------------------------------------------------- reaksi hit (aktif begitu hitbox player ada di M2)
func _on_hit(attack: AttackData, hitbox: Area3D) -> void:
	rig.flash(Balance.JUICE.flash_time)
	health.damage(attack.damage)
	CombatEvents.hit_landed.emit(attack.source, self, attack, hitbox.global_position)

func _on_pseudo_death() -> void:
	# dummy "reboot" — layar padam sebentar lalu pulih; tidak pernah hilang
	_screen.material_override = Palette.CABLE
	var t := get_tree().create_timer(1.0)
	t.timeout.connect(_reboot)

func _reboot() -> void:
	_screen.material_override = Palette.CRT_SCREEN
	health.heal_full()
