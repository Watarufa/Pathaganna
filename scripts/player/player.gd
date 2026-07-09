## Player PATHAGANNA. FSM eksplisit; semua window dihitung dari state_time + Balance
## (tidak pernah dari animasi). Rig, kamera, hurtbox, dan health dirakit lewat kode.
class_name Player
extends CharacterBody3D

enum State { IDLE_RUN, ATTACK_1, ATTACK_2, ATTACK_3, DODGE, PARRY, SKILL, HITSTUN, DEAD }
const STATE_NAMES := ["IDLE_RUN", "ATTACK_1", "ATTACK_2", "ATTACK_3", "DODGE", "PARRY", "SKILL", "HITSTUN", "DEAD"]

var state: State = State.IDLE_RUN
var state_time := 0.0

## Meter skill (terisi hanya dari parry & perfect dodge — M2).
var meter := 0.0
## Aksi yang sedang di-buffer + sisa umurnya (M2).
var buffered_action := ""

var rig: PoseRig
var camera_rig: CameraRig
var lockon: LockOn
var health: Health
var hurtbox: Hurtbox

# Pose dasar (Torso/Head/Weapon; kaki-lengan dikendalikan locomotion)
const POSE_STANCE := {
	Torso = Vector3(3, 0, 0),
	Head = Vector3(-2, 0, 0),
	WeaponPivot = Vector3(-20, 10, 0),
}
const POSE_DEAD := {
	Torso = Vector3(-78, 0, 6),
	Head = Vector3(-20, 0, 0),
	ArmL = Vector3(-60, 0, 20),
	ArmR = Vector3(-70, 0, -15),
	LegL = Vector3(8, 0, 0),
	LegR = Vector3(-6, 0, 0),
	WeaponPivot = Vector3(30, 0, 0),
}

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2      # player_body
	collision_mask = 1 | 4   # world + enemy_body

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	add_child(col)

	_build_rig()

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 8   # player_hurt
	hurtbox.collision_mask = 0
	hurtbox.position = Vector3(0, 0.85, 0)
	var hshape := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.38
	hcap.height = 1.65
	hshape.shape = hcap
	hurtbox.add_child(hshape)
	add_child(hurtbox)
	hurtbox.hit_received.connect(_on_hurt)

	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.setup(Balance.PLAYER.max_hp)
	health.changed.connect(_on_hp_changed)
	health.died.connect(_on_died)

	lockon = LockOn.new()
	lockon.name = "LockOn"
	add_child(lockon)
	lockon.body = self
	lockon.target_changed.connect(_on_lock_changed)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target_body = self
	add_child(camera_rig)

func _build_rig() -> void:
	rig = PoseRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.arm_r_scale = 0.35

	rig.add_pivot("Hips", "", Vector3(0, 0.92, 0))
	rig.add_pivot("Torso", "Hips", Vector3(0, 0.12, 0))
	rig.add_pivot("Head", "Torso", Vector3(0, 0.62, 0))
	rig.add_pivot("ArmL", "Torso", Vector3(-0.27, 0.52, 0))
	rig.add_pivot("ArmR", "Torso", Vector3(0.27, 0.52, 0))
	rig.add_pivot("LegL", "Hips", Vector3(-0.13, 0, 0))
	rig.add_pivot("LegR", "Hips", Vector3(0.13, 0, 0))
	rig.add_pivot("WeaponPivot", "ArmR", Vector3(0.02, -0.52, 0))

	# jaket panjang retro
	rig.attach_box("Torso", Vector3(0.42, 0.58, 0.26), Vector3(0, 0.3, 0), Palette.CLOTH)
	rig.attach_box("Torso", Vector3(0.46, 0.42, 0.3), Vector3(0, -0.08, 0), Palette.CLOTH)
	rig.attach_box("Torso", Vector3(0.3, 0.07, 0.22), Vector3(0, 0.6, 0), Palette.CABLE)  # kerah
	# kepala + rambut
	rig.attach_box("Head", Vector3(0.22, 0.26, 0.24), Vector3(0, 0.14, 0), Palette.SKIN)
	rig.attach_box("Head", Vector3(0.24, 0.1, 0.26), Vector3(0, 0.3, 0.01), Palette.CLOTH)
	# lengan & kaki
	rig.attach_capsule("ArmL", 0.07, 0.6, Vector3(0, -0.3, 0), Palette.CLOTH)
	rig.attach_capsule("ArmR", 0.07, 0.6, Vector3(0, -0.3, 0), Palette.CLOTH)
	rig.attach_capsule("LegL", 0.09, 0.9, Vector3(0, -0.45, 0), Palette.CLOTH)
	rig.attach_capsule("LegR", 0.09, 0.9, Vector3(0, -0.45, 0), Palette.CLOTH)
	# bilah antena: grip + core + tepi emissive ungu (justifikasi weapon trail)
	rig.attach_cylinder("WeaponPivot", 0.022, 0.16, Vector3(0, 0, 0.05), Palette.CABLE)
	rig.attach_box("WeaponPivot", Vector3(0.026, 0.05, 1.1), Vector3(0, 0, -0.62), Palette.METAL)
	rig.attach_box("WeaponPivot", Vector3(0.012, 0.054, 1.06), Vector3(0.02, 0, -0.62), Palette.NEON_PURPLE)
	rig.add_marker("WeaponPivot", "BladeTip", Vector3(0, 0, -1.17))
	rig.add_marker("WeaponPivot", "BladeBase", Vector3(0, 0, -0.1))

func _physics_process(delta: float) -> void:
	state_time += delta

	if Input.is_action_just_pressed("lockon") and state != State.DEAD:
		lockon.toggle()

	match state:
		State.IDLE_RUN:
			_st_idle_run(delta)
		State.DEAD:
			_st_dead(delta)
		_:
			# M2: ATTACK_1..3 / DODGE / PARRY / SKILL / HITSTUN diisi di combat core
			_st_idle_run(delta)

	move_and_slide()
	_update_visuals(delta)

# ------------------------------------------------------------- states
func _st_idle_run(delta: float) -> void:
	var in_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := _cam_relative(in_vec)
	var target_v := dir * Balance.PLAYER.move_speed
	var rate: float = Balance.PLAYER.accel if dir.length_squared() > 0.001 else Balance.PLAYER.decel
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(target_v, rate * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_apply_gravity(delta)
	_face(delta, dir)

func _st_dead(delta: float) -> void:
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, Balance.PLAYER.decel * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_apply_gravity(delta)

# ------------------------------------------------------------- visual (murni ikut state)
func _update_visuals(delta: float) -> void:
	match state:
		State.IDLE_RUN:
			rig.pose(POSE_STANCE, 8.0)
			var ratio := Vector2(velocity.x, velocity.z).length() / Balance.PLAYER.move_speed
			rig.locomotion(ratio, delta)
		State.DEAD:
			rig.pose(POSE_DEAD, 5.0)
		_:
			pass

# ------------------------------------------------------------- reaksi (M2)
func _on_hurt(_attack: AttackData, _hitbox: Area3D) -> void:
	pass  # M2: i-frame / parry / damage + hitstun

func _on_hp_changed(hp: float, max_hp: float) -> void:
	CombatEvents.player_hp_changed.emit(hp, max_hp)

func _on_died() -> void:
	# P1: essence drop here
	_change_state(State.DEAD)
	CombatEvents.player_died.emit()

func _on_lock_changed(t: Node3D) -> void:
	camera_rig.lock_target = t

# ------------------------------------------------------------- helpers
func _change_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0

func state_name() -> String:
	return STATE_NAMES[state]

func _cam_relative(v: Vector2) -> Vector3:
	return Basis(Vector3.UP, camera_rig.yaw) * Vector3(v.x, 0, v.y)

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= Balance.PLAYER.gravity * delta

func _face(delta: float, move_dir: Vector3) -> void:
	var target_yaw: float
	if lockon.target != null and is_instance_valid(lockon.target):
		var to := lockon.target.global_position - global_position
		if Vector2(to.x, to.z).length_squared() < 0.04:
			return
		target_yaw = atan2(-to.x, -to.z)
	elif move_dir.length_squared() > 0.001:
		target_yaw = atan2(-move_dir.x, -move_dir.z)
	else:
		return
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-Balance.PLAYER.turn_speed * delta))
