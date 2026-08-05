## Player PATHAGANNA. FSM eksplisit; SEMUA window (hitbox/i-frame/parry/cancel)
## dihitung dari state_time + Balance — tidak pernah dari animasi (aturan #2).
## Rig, kamera, hitbox, hurtbox, dan health dirakit lewat kode.
class_name Player
extends CharacterBody3D

enum State { IDLE_RUN, ATTACK_1, ATTACK_2, ATTACK_3, DODGE, PARRY, SKILL, HITSTUN, DEAD }
const STATE_NAMES := ["IDLE_RUN", "ATTACK_1", "ATTACK_2", "ATTACK_3", "DODGE", "PARRY", "SKILL", "HITSTUN", "DEAD"]
const ATTACK_STATES := [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3]

var state: State = State.IDLE_RUN
var state_time := 0.0

## Meter skill — hanya terisi dari parry & perfect dodge.
var meter := 0.0
## Input buffer global (aksi terakhir yang ditekan + sisa umurnya).
var buffered_action := ""
var _buffer_left := 0.0

var _attack_index := 0
## Kombo tetap "hidup" sesaat setelah serangan selesai, jadi dodge-cancel di tengah
## kombo bisa dilanjutkan ke hit berikutnya alih-alih jatuh kembali ke A1.
var _combo_next := 0
var _combo_window_left := 0.0
var _hitbox_on := false
var _skill_hitbox_on := false
var _dodge_dir := Vector3.ZERO
var _pd_triggered := false        # perfect dodge sekali per roll
var _pd_buff_left := 0.0          # window bonus damage +50%
var _parry_contact_time := -1.0   # state_time saat parry sukses (-1 = belum)
var _spawn_invuln_left := 0.0

var rig: PoseRig
var camera_rig: CameraRig
var lockon: LockOn
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox
var skill_hitbox: Hitbox
var trail: SlashTrail

# ------------------------------------------------------------- pose data (murni visual)
const POSE_STANCE := {
	Torso = Vector3(3, 0, 0),
	Head = Vector3(-2, 0, 0),
	WeaponPivot = Vector3(-20, 10, 0),
}
const POSE_HITSTUN := {
	Torso = Vector3(-16, 6, 0),
	Head = Vector3(-14, 0, 0),
	ArmL = Vector3(-25, 0, 30),
	ArmR = Vector3(-15, 0, -20),
	WeaponPivot = Vector3(-10, 0, 0),
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
# keyframe ayunan (from → to, disinkronkan ke window hit via state_time)
const ATTACK_VIS := [
	{ torso_from = Vector3(4, 30, 0), torso_to = Vector3(4, -32, 0),
	  arm_from = Vector3(-78, 0, 18), arm_to = Vector3(-84, 0, -12),
	  wep_from = Vector3(-8, 72, 0), wep_to = Vector3(-8, -78, 0) },
	{ torso_from = Vector3(4, -34, 0), torso_to = Vector3(4, 28, 0),
	  arm_from = Vector3(-84, 0, -12), arm_to = Vector3(-78, 0, 18),
	  wep_from = Vector3(-8, -78, 0), wep_to = Vector3(-8, 72, 0) },
	{ torso_from = Vector3(-14, 0, 0), torso_to = Vector3(26, 0, 0),
	  arm_from = Vector3(-152, 0, 0), arm_to = Vector3(-52, 0, 0),
	  wep_from = Vector3(38, 0, 0), wep_to = Vector3(-52, 0, 0) },
]

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

	# hitbox kombo: box generous di depan dada (Changelog GAME_DESIGN)
	hitbox = Hitbox.new()
	hitbox.name = "ComboHitbox"
	hitbox.collision_layer = 32  # player_attack
	hitbox.collision_mask = 16   # enemy_hurt
	var hb: Dictionary = Balance.COMBO_HITBOX
	hitbox.position = Vector3(0, 1.1, -hb.forward)
	var hbshape := CollisionShape3D.new()
	var hbbox := BoxShape3D.new()
	hbbox.size = Vector3(hb.width, hb.height, hb.length)
	hbshape.shape = hbbox
	hitbox.add_child(hbshape)
	add_child(hitbox)
	hitbox.landed.connect(_on_hitbox_landed)

	# hitbox skill: bola AoE
	skill_hitbox = Hitbox.new()
	skill_hitbox.name = "SkillHitbox"
	skill_hitbox.collision_layer = 32
	skill_hitbox.collision_mask = 16
	skill_hitbox.position = Vector3(0, 1.0, 0)
	var skshape := CollisionShape3D.new()
	var sksphere := SphereShape3D.new()
	sksphere.radius = Balance.SKILL.radius
	skshape.shape = sksphere
	skill_hitbox.add_child(skshape)
	add_child(skill_hitbox)
	skill_hitbox.landed.connect(_on_hitbox_landed)

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

	trail = SlashTrail.new()
	trail.name = "SlashTrail"
	trail.tip = rig.pivot("BladeTip")
	trail.blade_base = rig.pivot("BladeBase")
	add_child(trail)

	# meter skill dipertahankan lintas kematian (aturan death loop)
	meter = GameManager.persisted_meter
	_spawn_invuln_left = Balance.PLAYER.spawn_invuln
	call_deferred("_emit_initial_ui")

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
	_tick_timers(delta)
	_poll_combat_input()

	if Input.is_action_just_pressed("lockon") and state != State.DEAD:
		lockon.toggle()

	match state:
		State.IDLE_RUN:
			_st_idle_run(delta)
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			_st_attack(delta)
		State.DODGE:
			_st_dodge(delta)
		State.PARRY:
			_st_parry(delta)
		State.SKILL:
			_st_skill(delta)
		State.HITSTUN:
			_st_hitstun(delta)
		State.DEAD:
			_st_dead(delta)

	move_and_slide()
	_update_visuals(delta)

# ------------------------------------------------------------- input buffer
func _poll_combat_input() -> void:
	if state == State.DEAD:
		return
	for a in ["attack", "dodge", "parry", "skill"]:
		if Input.is_action_just_pressed(a):
			buffered_action = a
			_buffer_left = Balance.INPUT.buffer_time

func _tick_timers(delta: float) -> void:
	if _buffer_left > 0.0:
		_buffer_left -= delta
		if _buffer_left <= 0.0:
			buffered_action = ""
	if _pd_buff_left > 0.0:
		_pd_buff_left -= delta
	if _spawn_invuln_left > 0.0:
		_spawn_invuln_left -= delta
	if _combo_window_left > 0.0:
		_combo_window_left -= delta
		if _combo_window_left <= 0.0:
			_combo_next = 0

func _consume_buffer() -> void:
	buffered_action = ""
	_buffer_left = 0.0

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

	# konsumsi buffer — dodge menang atas segalanya (identitas DMC)
	if buffered_action == "dodge":
		_consume_buffer()
		_enter_dodge()
	elif buffered_action == "skill":
		_consume_buffer()
		if meter >= Balance.SKILL.meter_max:
			_enter_skill()
	elif buffered_action == "parry":
		_consume_buffer()
		_enter_parry()
	elif buffered_action == "attack":
		_consume_buffer()
		_enter_attack(_combo_next if _combo_window_left > 0.0 else 0)

func _st_attack(delta: float) -> void:
	var a: Dictionary = Balance.COMBO[_attack_index]
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, Balance.PLAYER.decel * 0.6 * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_apply_gravity(delta)

	# window hitbox dari jam state (bukan animasi)
	var active: bool = state_time >= a.hit_start and state_time <= a.hit_end
	if active and not _hitbox_on:
		_hitbox_on = true
		hitbox.begin(_make_attack(a))
	elif not active and _hitbox_on:
		_hitbox_on = false
		hitbox.end()

	# dodge/parry bisa cancel setelah cancel point
	if state_time >= a.cancel_at and (buffered_action == "dodge" or buffered_action == "parry"):
		var act := buffered_action
		_consume_buffer()
		_stop_attack_boxes()
		_open_combo_window()
		if act == "dodge":
			_enter_dodge()
		else:
			_enter_parry()
		return
	# chain serangan lanjutan
	if a.chain_at > 0.0 and state_time >= a.chain_at and buffered_action == "attack":
		_consume_buffer()
		_stop_attack_boxes()
		_enter_attack(_attack_index + 1)
		return
	if state_time >= a.duration:
		_stop_attack_boxes()
		_open_combo_window()
		_change_state(State.IDLE_RUN)

func _open_combo_window() -> void:
	if _attack_index + 1 < Balance.COMBO.size():
		_combo_next = _attack_index + 1
		_combo_window_left = Balance.COMBO_RESET_TIME
	else:
		_combo_next = 0
		_combo_window_left = 0.0

func _st_dodge(delta: float) -> void:
	var d: Dictionary = Balance.DODGE
	var brake := clampf((state_time - d.iframe_end) / maxf(d.duration - d.iframe_end, 0.01), 0.0, 1.0)
	var flat: Vector3 = _dodge_dir * float(d.speed) * (1.0 - brake * 0.85)
	velocity.x = flat.x
	velocity.z = flat.z
	_apply_gravity(delta)

	if state_time >= d.attack_out_at and buffered_action == "attack":
		_consume_buffer()
		_enter_attack(_combo_next if _combo_window_left > 0.0 else 0)
		return
	if state_time >= d.duration:
		_change_state(State.IDLE_RUN)

func _st_parry(delta: float) -> void:
	var p: Dictionary = Balance.PARRY
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, Balance.PLAYER.decel * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_apply_gravity(delta)

	# setelah kontak parry sukses, boleh langsung cancel ke serangan/dodge
	if _parry_contact_time >= 0.0 and state_time >= _parry_contact_time + p.recover_after_contact:
		if buffered_action == "attack":
			_consume_buffer()
			_enter_attack(0)
			return
		if buffered_action == "dodge":
			_consume_buffer()
			_enter_dodge()
			return
	if state_time >= p.duration:
		_change_state(State.IDLE_RUN)

func _st_skill(delta: float) -> void:
	var s: Dictionary = Balance.SKILL
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, Balance.PLAYER.decel * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_apply_gravity(delta)

	var active: bool = state_time >= s.hit_start and state_time <= s.hit_end
	if active and not _skill_hitbox_on:
		_skill_hitbox_on = true
		var atk := AttackData.make(s, self, "skill")
		if _pd_buff_left > 0.0:
			atk.damage *= Balance.DODGE.buff_mult
		skill_hitbox.begin(atk)
	elif not active and _skill_hitbox_on:
		_skill_hitbox_on = false
		skill_hitbox.end()

	if state_time >= s.duration:
		_stop_attack_boxes()
		_change_state(State.IDLE_RUN)

func _st_hitstun(delta: float) -> void:
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, Balance.PLAYER.decel * 1.5 * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_apply_gravity(delta)
	if state_time >= Balance.PLAYER.hitstun_time:
		_change_state(State.IDLE_RUN)

func _st_dead(delta: float) -> void:
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, Balance.PLAYER.decel * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_apply_gravity(delta)

# ------------------------------------------------------------- transisi state
func _enter_attack(idx: int) -> void:
	_attack_index = clampi(idx, 0, Balance.COMBO.size() - 1)
	_hitbox_on = false
	# hadap niat serang: lock-on → target; ada input → arah input
	var in_dir := _cam_relative(Input.get_vector("move_left", "move_right", "move_forward", "move_back"))
	if lockon.target != null and is_instance_valid(lockon.target):
		var to := lockon.target.global_position - global_position
		if Vector2(to.x, to.z).length_squared() > 0.04:
			rotation.y = atan2(-to.x, -to.z)
	elif in_dir.length_squared() > 0.001:
		rotation.y = atan2(-in_dir.x, -in_dir.z)
	_change_state(ATTACK_STATES[_attack_index])
	var a: Dictionary = Balance.COMBO[_attack_index]
	var fwd := -transform.basis.z
	velocity.x = fwd.x * a.lunge
	velocity.z = fwd.z * a.lunge

func _enter_dodge() -> void:
	var in_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := _cam_relative(in_vec)
	if dir.length_squared() < 0.001:
		dir = transform.basis.z  # netral → mundur (forward = -Z)
	_dodge_dir = dir.normalized()
	_pd_triggered = false
	if lockon.target == null:
		rotation.y = atan2(-_dodge_dir.x, -_dodge_dir.z)
	_change_state(State.DODGE)
	velocity.x = _dodge_dir.x * Balance.DODGE.speed
	velocity.z = _dodge_dir.z * Balance.DODGE.speed

func _enter_parry() -> void:
	_parry_contact_time = -1.0
	_change_state(State.PARRY)
	velocity.x *= 0.2
	velocity.z *= 0.2

func _enter_skill() -> void:
	meter = 0.0
	GameManager.persisted_meter = 0.0
	CombatEvents.meter_changed.emit(meter, Balance.SKILL.meter_max)
	CombatEvents.skill_used.emit()
	_skill_hitbox_on = false
	_change_state(State.SKILL)
	velocity.x = 0.0
	velocity.z = 0.0

func _enter_hitstun(source: Node) -> void:
	_stop_attack_boxes()
	_combo_next = 0
	_combo_window_left = 0.0
	_change_state(State.HITSTUN)
	var away := Vector3.ZERO
	if source != null and is_instance_valid(source) and source is Node3D:
		away = global_position - (source as Node3D).global_position
		away.y = 0.0
		away = away.normalized()
	velocity.x = away.x * Balance.PLAYER.hitstun_knockback
	velocity.z = away.z * Balance.PLAYER.hitstun_knockback

func _stop_attack_boxes() -> void:
	if _hitbox_on:
		_hitbox_on = false
		hitbox.end()
	if _skill_hitbox_on:
		_skill_hitbox_on = false
		skill_hitbox.end()

# ------------------------------------------------------------- terkena serangan
func _on_hurt(attack: AttackData, _hitbox_from: Area3D) -> void:
	if state == State.DEAD:
		return
	if _spawn_invuln_left > 0.0:
		return

	# i-frames dodge: damage diabaikan, event tetap terdeteksi (spec perfect dodge)
	var d: Dictionary = Balance.DODGE
	if state == State.DODGE and state_time >= d.iframe_start and state_time <= d.iframe_end:
		if state_time <= d.perfect_window and not _pd_triggered:
			_pd_triggered = true
			_trigger_perfect_dodge()
		return

	# parry: hanya serangan putih (parryable)
	var p: Dictionary = Balance.PARRY
	if state == State.PARRY and attack.parryable \
			and state_time >= p.window_start and state_time <= p.window_end:
		var perfect: bool = state_time <= p.perfect_end
		_parry_contact_time = state_time
		_add_meter(p.meter_perfect if perfect else p.meter_normal)
		TimeJuice.hitstop(p.hitstop_perfect if perfect else p.hitstop_normal)
		var contact := global_position + Vector3.UP * 1.2 - transform.basis.z * 0.6
		CombatEvents.parried.emit(perfect, contact)
		if attack.source != null and is_instance_valid(attack.source) \
				and attack.source.has_method("on_parried"):
			attack.source.on_parried(perfect)
		return

	# serangan merah menembus parry → damage penuh
	_take_damage(attack)

func _take_damage(attack: AttackData) -> void:
	health.damage(attack.damage)
	CombatEvents.player_damaged.emit(attack.damage, attack.source)
	rig.flash(Balance.JUICE.flash_time)
	if state != State.SKILL and state != State.DEAD:
		_enter_hitstun(attack.source)

func _trigger_perfect_dodge() -> void:
	TimeJuice.slowmo(Balance.DODGE.slowmo_scale, Balance.DODGE.slowmo_time)
	_pd_buff_left = Balance.DODGE.buff_time
	_add_meter(Balance.DODGE.meter_gain)
	CombatEvents.perfect_dodge.emit(global_position + Vector3.UP)

func _on_hitbox_landed(_target: Area3D, _attack: AttackData) -> void:
	TimeJuice.hitstop(_attack.hitstop)
	if _pd_buff_left > 0.0:
		_pd_buff_left = 0.0  # bonus +50% dikonsumsi hit pertama yang mendarat

func _make_attack(a: Dictionary) -> AttackData:
	var atk := AttackData.make(a, self, a.get("name", ""))
	if _pd_buff_left > 0.0:
		atk.damage *= Balance.DODGE.buff_mult
	return atk

func _add_meter(amount: float) -> void:
	meter = minf(meter + amount, Balance.SKILL.meter_max)
	GameManager.persisted_meter = meter
	CombatEvents.meter_changed.emit(meter, Balance.SKILL.meter_max)

# ------------------------------------------------------------- event kecil
func _on_hp_changed(hp: float, max_hp: float) -> void:
	CombatEvents.player_hp_changed.emit(hp, max_hp)

func _on_died() -> void:
	# P1: essence drop here
	_stop_attack_boxes()
	_change_state(State.DEAD)
	CombatEvents.player_died.emit()

func _on_lock_changed(t: Node3D) -> void:
	camera_rig.lock_target = t

func _emit_initial_ui() -> void:
	CombatEvents.player_hp_changed.emit(health.hp, health.max_hp)
	CombatEvents.meter_changed.emit(meter, Balance.SKILL.meter_max)

# ------------------------------------------------------------- visual (murni ikut state)
func _update_visuals(delta: float) -> void:
	trail.active = state in ATTACK_STATES or state == State.SKILL
	match state:
		State.IDLE_RUN:
			rig.pose(POSE_STANCE, 8.0)
			var ratio := Vector2(velocity.x, velocity.z).length() / Balance.PLAYER.move_speed
			rig.locomotion(ratio, delta)
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			_attack_visual(_attack_index)
		State.DODGE:
			_dodge_visual()
		State.PARRY:
			rig.pose({
				"ArmR": Vector3(-95, 0, -25), "WeaponPivot": Vector3(95, 0, 0),
				"ArmL": Vector3(-45, 0, 35), "Torso": Vector3(4, -15, 0),
			}, 30.0)
		State.SKILL:
			_skill_visual()
		State.HITSTUN:
			rig.pose(POSE_HITSTUN, 22.0)
		State.DEAD:
			rig.pose(POSE_DEAD, 5.0)

func _attack_visual(idx: int) -> void:
	var a: Dictionary = Balance.COMBO[idx]
	var v: Dictionary = ATTACK_VIS[idx]
	var wind_end: float = a.hit_start * 0.7
	if state_time < wind_end:
		rig.pose({ "Torso": v.torso_from, "ArmR": v.arm_from, "WeaponPivot": v.wep_from }, 26.0)
	else:
		var k := clampf((state_time - wind_end) / (a.hit_end - wind_end), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		rig.snap({
			"Torso": v.torso_from.lerp(v.torso_to, k),
			"ArmR": v.arm_from.lerp(v.arm_to, k),
			"WeaponPivot": v.wep_from.lerp(v.wep_to, k),
		})
	rig.pose({ "ArmL": Vector3(-30, 0, 25), "Head": Vector3(-4, 0, 0) }, 14.0)

func _dodge_visual() -> void:
	var d: Dictionary = Balance.DODGE
	var p := clampf(state_time / d.duration, 0.0, 1.0)
	var spin := p * p * (3.0 - 2.0 * p) * -360.0
	rig.snap({ "Hips": Vector3(spin, 0, 0) })
	rig.pose({
		"ArmL": Vector3(-70, 0, 30), "ArmR": Vector3(-70, 0, -30),
		"LegL": Vector3(35, 0, 0), "LegR": Vector3(28, 0, 0),
		"Torso": Vector3(22, 0, 0), "WeaponPivot": Vector3(-30, 0, 0),
	}, 25.0)
	rig.pivot("Hips").position = Vector3(0, 0.92 - 0.34 * sin(p * PI), 0)

func _skill_visual() -> void:
	var s: Dictionary = Balance.SKILL
	var start: float = s.hit_start * 0.6
	var k := clampf((state_time - start) / (s.hit_end - start), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	rig.snap({ "Hips": Vector3(0, k * 360.0, 0) })
	rig.pose({
		"Torso": Vector3(8, 0, 0),
		"ArmR": Vector3(-88, 0, 55), "WeaponPivot": Vector3(0, 88, 0),
		"ArmL": Vector3(-60, 0, 45), "Head": Vector3(-6, 0, 0),
	}, 20.0)

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
