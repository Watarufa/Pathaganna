## Dasar semua musuh: FSM, health, hitbox/hurtbox, telegraph, stagger, mati.
##
## Turunan mengisi bagian yang khas dirinya lewat method virtual:
##   `_stats()`            → dictionary tuning dari Balance
##   `_build_body()`       → rig primitif + layar telegraph
##   `_pick_attack()`      → serangan berikutnya (atau {} kalau belum mau menyerang)
##   `_ai_move()`          → gerak saat mengejar/menjaga jarak
##   `_attack_profile()`   → pose telegraph untuk serangan yang sedang berjalan
##   `_on_swing_begin()`   → hook saat ayunan mulai (Penyiar melepas proyektil di sini)
##
## Semua window dihitung dari `state_time` + data Balance, tidak pernah dari
## animasi. Pose digambar di `_process` lewat PoseRig.visual_time() — menggambar
## pose di physics tick membuat gerakan tersendat di monitor >60 Hz.
class_name EnemyBase
extends CharacterBody3D

enum State { IDLE, CHASE, WINDUP, SWING, RECOVER, STAGGER, KNOCKDOWN, DEAD }
const STATE_NAMES := ["IDLE", "CHASE", "WINDUP", "SWING", "RECOVER", "STAGGER", "KNOCKDOWN", "DEAD"]

var state: State = State.IDLE
var state_time := 0.0

var rig: PoseRig
var screen: TelegraphScreen
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox

var stats: Dictionary = {}
## Serangan yang sedang berjalan (dictionary dari Balance). Kosong = tidak ada.
var current: Dictionary = {}

var _hitbox_on := false
var _cooldown := 0.0
var _spawn_point := Vector3.ZERO
var _spawn_yaw := 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("lockon_targets")
	collision_layer = 4   # enemy_body
	collision_mask = 1    # world (musuh saling tembus — mencegah macet tanpa navmesh)

	stats = _stats()
	_spawn_point = global_position
	_spawn_yaw = rotation.y

	var body_cap: Dictionary = _body_capsule()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = body_cap.radius
	cap.height = body_cap.height
	col.shape = cap
	col.position = Vector3(0, body_cap.y, 0)
	add_child(col)

	rig = PoseRig.new()
	rig.name = "Rig"
	add_child(rig)
	_build_body()

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 16  # enemy_hurt
	hurtbox.collision_mask = 0
	var hurt_cap: Dictionary = _hurtbox_capsule()
	hurtbox.position = Vector3(0, hurt_cap.y, 0)
	var hshape := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = hurt_cap.radius
	hcap.height = hurt_cap.height
	hshape.shape = hcap
	hurtbox.add_child(hshape)
	add_child(hurtbox)
	hurtbox.hit_received.connect(_on_hit)

	hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 64   # enemy_attack
	hitbox.collision_mask = 8     # player_hurt
	var hbshape := CollisionShape3D.new()
	hbshape.shape = _hitbox_shape()
	hitbox.add_child(hbshape)
	hitbox.position = _hitbox_offset()
	add_child(hitbox)

	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.setup(stats.hp)
	health.died.connect(_on_died)

func get_lockon_point() -> Vector3:
	return global_position + Vector3.UP * 1.2

func state_name() -> String:
	return STATE_NAMES[state]

func is_alive() -> bool:
	return state != State.DEAD and health.is_alive()

## Kembalikan ke kondisi awal (dipakai death loop saat player respawn).
func reset() -> void:
	_stop_hitbox()
	global_position = _spawn_point
	rotation.y = _spawn_yaw
	velocity = Vector3.ZERO
	current = {}
	_cooldown = 0.0
	health.heal_full()
	screen.set_fill(0.0)
	visible = true
	_change_state(State.IDLE)

# ------------------------------------------------------------- virtual
func _stats() -> Dictionary:
	return {}

func _build_body() -> void:
	pass

## Geometri tubuh & hurtbox — dioverride musuh yang bukan humanoid berdiri
## (Penyiar melayang, boss jauh lebih besar).
func _body_capsule() -> Dictionary:
	return { radius = 0.4, height = 1.8, y = 0.9 }

func _hurtbox_capsule() -> Dictionary:
	return { radius = 0.45, height = 1.7, y = 1.0 }

## Tinggi hitbox melee dibaca dari ENEMY_COMMON supaya semua musuh darat
## sama-sama bisa menjangkau player yang melompat — lihat catatan anti-air.
func _hitbox_shape() -> Shape3D:
	var b := BoxShape3D.new()
	b.size = Vector3(1.8, Balance.ENEMY_COMMON.melee_hitbox_height, 2.0)
	return b

func _hitbox_offset() -> Vector3:
	return Vector3(0, Balance.ENEMY_COMMON.melee_hitbox_y, -1.0)

## Serangan berikutnya, atau {} kalau belum saatnya menyerang.
func _pick_attack(_dist: float) -> Dictionary:
	return {}

## Gerak saat IDLE/CHASE. Turunan menulis ke `velocity`.
func _ai_move(_delta: float, _target: Node3D, _dist: float) -> void:
	pass

## Profil pose telegraph untuk `current`.
func _attack_profile() -> Dictionary:
	return {}

## Dipanggil sekali saat state SWING dimulai.
func _on_swing_begin() -> void:
	pass

## Pose saat tidak menyerang (dipakai juga sebagai neutral telegraph).
func _idle_pose() -> Dictionary:
	return {}

## `vis_time` = state_time terinterpolasi ke frame render; `delta` = delta render
## (untuk animasi berbasis akumulasi seperti siklus jalan).
func _pose_for_state(_vis_time: float, _delta: float) -> void:
	pass

# ------------------------------------------------------------- FSM
func _physics_process(delta: float) -> void:
	state_time += delta
	if _cooldown > 0.0:
		_cooldown -= delta

	var target := _player()
	var dist := global_position.distance_to(target.global_position) if target != null else INF

	match state:
		State.IDLE:
			_st_idle(delta, target, dist)
		State.CHASE:
			_st_chase(delta, target, dist)
		State.WINDUP:
			_st_windup()
		State.SWING:
			_st_swing()
		State.RECOVER:
			_brake(delta)
			if state_time >= float(stats.recovery):
				_change_state(State.IDLE)
		State.STAGGER:
			_brake(delta)
			if state_time >= float(stats.stagger_time):
				_change_state(State.IDLE)
		State.KNOCKDOWN:
			_brake(delta)
			if state_time >= Balance.SKILL.knockdown_time:
				_change_state(State.IDLE)
		State.DEAD:
			_brake(delta)
			if state_time >= Balance.ENEMY_COMMON.die_free_delay:
				queue_free()
				return

	_apply_gravity(delta)
	move_and_slide()

	if state != State.DEAD and state != State.KNOCKDOWN:
		_face(delta, target)

func _process(delta: float) -> void:
	_pose_for_state(PoseRig.visual_time(state_time, get_physics_process_delta_time()), delta)

func _st_idle(delta: float, target: Node3D, dist: float) -> void:
	_brake(delta)
	if target != null and dist <= float(stats.detect_radius):
		_change_state(State.CHASE)

func _st_chase(delta: float, target: Node3D, dist: float) -> void:
	if target == null or dist > float(stats.detect_radius) * 1.4:
		_change_state(State.IDLE)
		return
	_ai_move(delta, target, dist)
	if _cooldown <= 0.0 and _can_reach_height(target):
		var atk := _pick_attack(dist)
		if not atk.is_empty():
			begin_attack(atk)

## Jangan mulai serangan kalau player jauh di atas jangkauan hitbox: musuh yang
## menebas angin terlihat seperti bug, bukan seperti musuh yang kalah posisi.
## Musuh ranged menimpa ini dengan true — proyektilnya mengarah ke player.
func _can_reach_height(target: Node3D) -> bool:
	return target.global_position.y - global_position.y <= Balance.ENEMY_COMMON.max_attack_height

func _st_windup() -> void:
	if state_time >= float(current.windup):
		_change_state(State.SWING)
		_on_swing_begin()

func _st_swing() -> void:
	var has_box: bool = current.has("hit_start")
	if has_box:
		var active: bool = state_time >= float(current.hit_start) and state_time <= float(current.hit_end)
		if active and not _hitbox_on:
			_hitbox_on = true
			hitbox.begin(AttackData.make(current, self, String(current.get("kind", "enemy"))))
		elif not active and _hitbox_on:
			_stop_hitbox()
	if state_time >= float(current.get("swing", 0.2)):
		_stop_hitbox()
		_after_swing()

## Setelah satu ayunan selesai — turunan bisa menyambung jadi kombo.
func _after_swing() -> void:
	_cooldown = float(stats.attack_cooldown)
	_change_state(State.RECOVER)

func begin_attack(atk: Dictionary) -> void:
	current = atk
	screen.arm(bool(atk.get("parryable", true)))
	_hitbox_on = false
	_change_state(State.WINDUP)

# ------------------------------------------------------------- reaksi
func _on_hit(attack: AttackData, hit_from: Area3D) -> void:
	if state == State.DEAD:
		return
	rig.flash(Balance.JUICE.flash_time)
	CombatEvents.hit_landed.emit(attack.source, self, attack, hit_from.global_position)
	if attack.knockback > 0.0 and attack.source is Node3D:
		var away := global_position - (attack.source as Node3D).global_position
		away.y = 0.0
		velocity += away.normalized() * attack.knockback
	var lethal := health.damage(attack.damage)
	if lethal:
		return
	if attack.knockdown:
		_stop_hitbox()
		screen.set_fill(0.0)
		_change_state(State.KNOCKDOWN)

## Dipanggil player saat serangan musuh ini berhasil diparry.
func on_parried(perfect: bool) -> void:
	_stop_hitbox()
	screen.set_fill(0.0)
	if perfect:
		_change_state(State.STAGGER)
		CombatEvents.enemy_staggered.emit(self)
	else:
		_cooldown = float(stats.attack_cooldown)
		_change_state(State.RECOVER)

func _on_died() -> void:
	_stop_hitbox()
	screen.power_off()
	remove_from_group("lockon_targets")
	_change_state(State.DEAD)
	HitSpark.spawn(get_parent(), global_position + Vector3.UP * 1.1,
		Color(0.85, 1.0, 0.9), 30, 8.0)
	CombatEvents.enemy_died.emit(self)

# ------------------------------------------------------------- helpers
func _stop_hitbox() -> void:
	if _hitbox_on:
		_hitbox_on = false
		hitbox.end()

func _change_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0

func _player() -> Node3D:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return null
	if p.has_method("state_name") and p.state_name() == "DEAD":
		return null
	return p

func _brake(delta: float) -> void:
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 26.0 * delta)
	velocity.x = flat.x
	velocity.z = flat.z

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= Balance.PLAYER.gravity * delta

## Berputar menghadap player. Melambat drastis saat windup supaya serangan
## yang sudah di-telegraph tidak bisa "dibuntuti" — pemain yang sudah
## melakukan dodge harus benar-benar lolos.
func _face(delta: float, player: Node3D) -> void:
	if player == null:
		return
	var to := player.global_position - global_position
	if Vector2(to.x, to.z).length_squared() < 0.04:
		return
	var speed := 8.0
	if state == State.WINDUP:
		speed = 1.5
	elif state == State.SWING:
		speed = 0.0
	if speed <= 0.0:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-speed * delta))

## Steering langsung menuju/menjauhi titik (tanpa NavigationServer — zona terbuka).
func _steer(delta: float, dir: Vector3, speed: float) -> void:
	var target := dir.normalized() * speed
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(target, 30.0 * delta)
	velocity.x = flat.x
	velocity.z = flat.z
