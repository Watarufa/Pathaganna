## Dummy latihan M2: target lock-on yang menyerang berkala dengan pola campuran
## putih (parryable) dan merah (wajib dodge). Tidak pernah benar-benar mati —
## "reboot" lalu kembali penuh, supaya sesi tuning tidak terputus.
## Bukan turunan enemy_base (itu untuk musuh sungguhan di M3); ini prop latihan.
class_name TrainingDummy
extends CharacterBody3D

enum State { IDLE, WINDUP, SWING, RECOVER, STAGGER, REBOOT }
const STATE_NAMES := ["IDLE", "WINDUP", "SWING", "RECOVER", "STAGGER", "REBOOT"]

var state: State = State.IDLE
var state_time := 0.0

var rig: PoseRig
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox

var _screen: MeshInstance3D
var _cooldown := 0.0
var _current: Dictionary = {}
var _hitbox_on := false

# Profil gerakan telegraph. Putih dan merah sengaja punya BENTUK berbeda —
# tebasan atas vs sapuan samping — supaya jenis serangan terbaca dari siluet
# meski warnanya luput dari perhatian. `follow` = pose akhir ayunan.
const POSE_IDLE := {
	Torso = Vector3.ZERO, ArmR = Vector3(-8, 0, -6), ArmL = Vector3(-8, 0, 6),
	Head = Vector3.ZERO, WeaponPivot = Vector3(-58, 0, 0),
}
const PROFILE_WHITE := {
	neutral = POSE_IDLE,
	ready  = { Torso = Vector3(-14, 0, 0), ArmR = Vector3(-138, 0, -16),
	           ArmL = Vector3(-16, 0, 16), Head = Vector3(-10, 0, 0),
	           WeaponPivot = Vector3(-52, 0, 0) },
	coil   = { Torso = Vector3(-26, 0, 0), ArmR = Vector3(-172, 0, -26),
	           ArmL = Vector3(-24, 0, 22), Head = Vector3(-20, 0, 0),
	           WeaponPivot = Vector3(-74, 0, 0) },
	follow = { Torso = Vector3(26, 0, 0), ArmR = Vector3(-22, 0, 6),
	           ArmL = Vector3(-10, 0, 10), Head = Vector3(16, 0, 0),
	           WeaponPivot = Vector3(-14, 0, 0) },
}
const PROFILE_RED := {
	neutral = POSE_IDLE,
	ready  = { Torso = Vector3(0, 46, 0), ArmR = Vector3(-84, 0, -66),
	           ArmL = Vector3(-28, 0, 28), Head = Vector3(0, 32, 0),
	           WeaponPivot = Vector3(-16, -34, 0) },
	coil   = { Torso = Vector3(0, 72, 0), ArmR = Vector3(-90, 0, -98),
	           ArmL = Vector3(-36, 0, 34), Head = Vector3(0, 52, 0),
	           WeaponPivot = Vector3(-16, -52, 0) },
	follow = { Torso = Vector3(0, -58, 0), ArmR = Vector3(-88, 0, 70),
	           ArmL = Vector3(-20, 0, -20), Head = Vector3(0, -42, 0),
	           WeaponPivot = Vector3(-16, 46, 0) },
}

func _ready() -> void:
	add_to_group("lockon_targets")
	add_to_group("enemies")
	collision_layer = 4   # enemy_body
	collision_mask = 1    # world

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

	hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 64   # enemy_attack
	hitbox.collision_mask = 8     # player_hurt
	var hbshape := CollisionShape3D.new()
	var hbbox := BoxShape3D.new()
	hbbox.size = Vector3(2.0, 1.8, Balance.DUMMY.white.range)
	hbshape.shape = hbbox
	hitbox.add_child(hbshape)
	hitbox.position = Vector3(0, 1.0, -Balance.DUMMY.white.range * 0.5)
	add_child(hitbox)

	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.setup(Balance.DUMMY.hp)
	health.died.connect(_on_pseudo_death)

	_cooldown = Balance.DUMMY.interval

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
	# kepala monitor CRT — layar wajahnya ADALAH telegraph (diegetik)
	rig.attach_box("Head", Vector3(0.42, 0.34, 0.38), Vector3(0, 0.17, 0), Palette.METAL)
	_screen = rig.attach_box("Head", Vector3(0.3, 0.22, 0.02), Vector3(0, 0.17, -0.2), Palette.CRT_SCREEN)
	# lengan
	rig.attach_capsule("ArmL", 0.07, 0.55, Vector3(0, -0.28, 0), Palette.CLOTH)
	rig.attach_capsule("ArmR", 0.07, 0.55, Vector3(0, -0.28, 0), Palette.CLOTH)
	# batang antena berkarat — memperbesar siluet ayunan supaya telegraph
	# terbaca dari jarak tempur, bukan cuma dari lengan setipis capsule
	rig.add_pivot("WeaponPivot", "ArmR", Vector3(0, -0.5, 0))
	rig.attach_box("WeaponPivot", Vector3(0.055, 0.055, 0.95), Vector3(0, 0, -0.45), Palette.METAL)

func get_lockon_point() -> Vector3:
	return global_position + Vector3.UP * 1.35

func state_name() -> String:
	return STATE_NAMES[state]

# ------------------------------------------------------------- FSM
func _physics_process(delta: float) -> void:
	state_time += delta
	if _cooldown > 0.0:
		_cooldown -= delta

	match state:
		State.IDLE:
			_st_idle()
		State.WINDUP:
			_st_windup()
		State.SWING:
			_st_swing()
		State.RECOVER:
			if state_time >= Balance.DUMMY.recover:
				_change_state(State.IDLE)
		State.STAGGER:
			if state_time >= Balance.ENEMY_COMMON.stagger_time:
				_change_state(State.IDLE)
		State.REBOOT:
			if state_time >= Balance.ENEMY_COMMON.die_free_delay:
				_reboot()

	_face_player(delta)
	# dummy tidak berjalan — hanya meluncur sesaat dari knockback lalu berhenti
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 26.0 * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - Balance.PLAYER.gravity * delta
	move_and_slide()
	_update_visuals()

func _st_idle() -> void:
	if _cooldown > 0.0:
		return
	var p := _player()
	if p == null or global_position.distance_to(p.global_position) > Balance.DUMMY.attack_range:
		return
	var red: bool = randf() < Balance.DUMMY.red_chance
	_current = Balance.DUMMY.red if red else Balance.DUMMY.white
	_change_state(State.WINDUP)

func _st_windup() -> void:
	if state_time >= _current.windup:
		_change_state(State.SWING)

func _st_swing() -> void:
	var active: bool = state_time >= _current.hit_start and state_time <= _current.hit_end
	if active and not _hitbox_on:
		_hitbox_on = true
		hitbox.begin(AttackData.make(_current, self, "dummy"))
	elif not active and _hitbox_on:
		_stop_hitbox()
	if state_time >= _current.swing:
		_stop_hitbox()
		_cooldown = Balance.DUMMY.interval
		_change_state(State.RECOVER)

func _profile() -> Dictionary:
	return PROFILE_WHITE if _current.get("parryable", true) else PROFILE_RED

func _stop_hitbox() -> void:
	if _hitbox_on:
		_hitbox_on = false
		hitbox.end()

func _face_player(delta: float) -> void:
	var p := _player()
	if p == null or state == State.REBOOT:
		return
	var to := p.global_position - global_position
	if Vector2(to.x, to.z).length_squared() < 0.04:
		return
	var speed := 2.0 if state == State.WINDUP else 6.0
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-speed * delta))

func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player")

# ------------------------------------------------------------- telegraph diegetik
func _update_visuals() -> void:
	match state:
		State.WINDUP:
			# Gerakan windup dihitung langsung dari state_time: angkat progresif →
			# anticipation → pukul, jadi pemain membaca KAPAN, bukan cuma APA.
			_screen.material_override = Telegraph.screen_material(
				state_time, _current.windup, _current.parryable, Palette.CRT_SCREEN)
			rig.snap(Telegraph.windup_pose(_profile(), state_time, _current.windup))
		State.SWING:
			_screen.material_override = Palette.CRT_SCREEN
			# lanjut dari pose coil supaya ayunan menyambung mulus dari windup
			var k := clampf(state_time / maxf(_current.hit_end, 0.01), 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			rig.snap(Telegraph.blend(_profile().coil, _profile().follow, k))
		State.STAGGER:
			_screen.material_override = Palette.CRT_SCREEN
			rig.pose({
				"Torso": Vector3(-26, 0, 8), "Head": Vector3(-18, 0, 0),
				"ArmR": Vector3(-15, 0, -35), "ArmL": Vector3(-15, 0, 35),
				"WeaponPivot": Vector3(-30, 0, 0),
			}, 12.0)
		State.REBOOT:
			rig.pose({
				"Torso": Vector3(-14, 0, 0), "Head": Vector3(24, 0, 0),
				"ArmR": Vector3(-4, 0, -10), "ArmL": Vector3(-4, 0, 10),
				"WeaponPivot": Vector3(-84, 0, 0),
			}, 6.0)
		_:
			_screen.material_override = Palette.CRT_SCREEN
			rig.pose(POSE_IDLE, 8.0)

# ------------------------------------------------------------- reaksi
func _on_hit(attack: AttackData, hit_from: Area3D) -> void:
	if state == State.REBOOT:
		return
	rig.flash(Balance.JUICE.flash_time)
	CombatEvents.hit_landed.emit(attack.source, self, attack, hit_from.global_position)
	if attack.knockback > 0.0 and attack.source is Node3D:
		var away := global_position - (attack.source as Node3D).global_position
		away.y = 0.0
		velocity += away.normalized() * attack.knockback
	health.damage(attack.damage)

## Dipanggil player saat serangan ini berhasil diparry.
func on_parried(perfect: bool) -> void:
	_stop_hitbox()
	if perfect:
		_change_state(State.STAGGER)
		CombatEvents.enemy_staggered.emit(self)
	else:
		_cooldown = Balance.DUMMY.interval
		_change_state(State.RECOVER)

func _on_pseudo_death() -> void:
	_stop_hitbox()
	_screen.material_override = Palette.CABLE
	HitSpark.spawn(get_parent(), global_position + Vector3.UP * 1.2, Color(0.85, 1.0, 0.9), 30, 8.0)
	_change_state(State.REBOOT)

func _reboot() -> void:
	health.heal_full()
	_cooldown = Balance.DUMMY.interval
	_change_state(State.IDLE)

func _change_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0
