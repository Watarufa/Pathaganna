## Kultis CRT — melee, serangannya mayoritas parryable.
## Jubah kultus gelap + kepala monitor CRT; layar wajahnya ADALAH telegraph-nya.
## Sesekali menyambung tebasan jadi kombo 2-hit (kedua hit tetap putih).
class_name Kultis
extends EnemyBase

const SCREEN_SIZE := Vector2(0.3, 0.22)
const SCREEN_OFFSET := Vector3(0, 0.17, -0.2)

const POSE_IDLE := {
	Torso = Vector3.ZERO, ArmR = Vector3(-8, 0, -6), ArmL = Vector3(-8, 0, 6),
	Head = Vector3.ZERO, WeaponPivot = Vector3(-58, 0, 0),
}
## Tebasan atas — bentuk gerak khas serangan putih di seluruh game.
const PROFILE_SLASH := {
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

var _combo_pending := false

func _stats() -> Dictionary:
	return Balance.KULTIS

func _hitbox_shape() -> Shape3D:
	var b := BoxShape3D.new()
	b.size = Vector3(1.8, Balance.ENEMY_COMMON.melee_hitbox_height, float(Balance.KULTIS.slash.range))
	return b

func _hitbox_offset() -> Vector3:
	return Vector3(0, Balance.ENEMY_COMMON.melee_hitbox_y,
		-float(Balance.KULTIS.slash.range) * 0.5)

func _build_body() -> void:
	rig.add_pivot("Hips", "", Vector3(0, 0.9, 0))
	rig.add_pivot("Torso", "Hips", Vector3(0, 0.1, 0))
	rig.add_pivot("Head", "Torso", Vector3(0, 0.62, 0))
	rig.add_pivot("ArmL", "Torso", Vector3(-0.3, 0.5, 0))
	rig.add_pivot("ArmR", "Torso", Vector3(0.3, 0.5, 0))
	rig.add_pivot("LegL", "Hips", Vector3(-0.13, 0, 0))
	rig.add_pivot("LegR", "Hips", Vector3(0.13, 0, 0))
	rig.add_pivot("WeaponPivot", "ArmR", Vector3(0, -0.5, 0))

	# jubah kultus: bahu sempit melebar ke bawah
	rig.attach_box("Torso", Vector3(0.44, 0.5, 0.3), Vector3(0, 0.28, 0), Palette.CLOTH)
	rig.attach_box("Torso", Vector3(0.56, 0.5, 0.38), Vector3(0, -0.1, 0), Palette.CLOTH)
	# kepala monitor CRT — layar wajahnya adalah telegraph (diegetik)
	rig.attach_box("Head", Vector3(0.42, 0.34, 0.38), Vector3(0, 0.17, 0), Palette.METAL)
	screen = TelegraphScreen.build(rig, "Head", SCREEN_SIZE, SCREEN_OFFSET)
	# antena kecil di atas monitor
	rig.attach_box("Head", Vector3(0.02, 0.22, 0.02), Vector3(0.1, 0.44, 0), Palette.METAL)

	rig.attach_capsule("ArmL", 0.07, 0.55, Vector3(0, -0.28, 0), Palette.CLOTH)
	rig.attach_capsule("ArmR", 0.07, 0.55, Vector3(0, -0.28, 0), Palette.CLOTH)
	rig.attach_capsule("LegL", 0.09, 0.85, Vector3(0, -0.42, 0), Palette.CLOTH)
	rig.attach_capsule("LegR", 0.09, 0.85, Vector3(0, -0.42, 0), Palette.CLOTH)
	# batang antena berkarat — memperbesar siluet ayunan supaya telegraph terbaca
	rig.attach_box("WeaponPivot", Vector3(0.055, 0.055, 0.95), Vector3(0, 0, -0.45), Palette.METAL)

func _idle_pose() -> Dictionary:
	return POSE_IDLE

func _attack_profile() -> Dictionary:
	return PROFILE_SLASH

func _ai_move(delta: float, target: Node3D, dist: float) -> void:
	var to := target.global_position - global_position
	to.y = 0.0
	if dist > float(stats.attack_range) * 0.85:
		_steer(delta, to, float(stats.speed))
	else:
		_brake(delta)

func _pick_attack(dist: float) -> Dictionary:
	if dist > float(stats.attack_range):
		return {}
	_combo_pending = randf() < float(stats.combo2_chance)
	return stats.slash

## Hit kedua kombo: tebasan yang sama dengan windup dipendekkan, jadi tetap
## putih dan tetap punya hitung mundur — cuma jendelanya lebih ketat.
func _after_swing() -> void:
	if _combo_pending:
		_combo_pending = false
		var second: Dictionary = stats.slash.duplicate()
		second.windup = stats.combo2_gap
		begin_attack(second)
		return
	super()

func _pose_for_state(vis_time: float, delta: float) -> void:
	match state:
		State.WINDUP:
			rig.snap(Telegraph.windup_pose(PROFILE_SLASH, vis_time, float(current.windup)))
			screen.set_fill(Telegraph.fill_amount(vis_time, float(current.windup)))
		State.SWING:
			screen.set_fill(0.0)
			var k := clampf(vis_time / maxf(float(current.hit_end), 0.01), 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			rig.snap(Telegraph.blend(PROFILE_SLASH.coil, PROFILE_SLASH.follow, k))
		State.STAGGER:
			screen.set_fill(0.0)
			rig.pose({
				"Torso": Vector3(-26, 0, 8), "Head": Vector3(-18, 0, 0),
				"ArmR": Vector3(-15, 0, -35), "ArmL": Vector3(-15, 0, 35),
				"WeaponPivot": Vector3(-30, 0, 0),
			}, 12.0)
		State.KNOCKDOWN:
			screen.set_fill(0.0)
			rig.pose({
				"Torso": Vector3(-70, 0, 12), "Head": Vector3(-30, 0, 0),
				"ArmR": Vector3(-20, 0, -50), "ArmL": Vector3(-20, 0, 50),
				"LegL": Vector3(30, 0, 0), "LegR": Vector3(24, 0, 0),
				"WeaponPivot": Vector3(-20, 0, 0),
			}, 9.0)
		State.DEAD:
			rig.pose({
				"Torso": Vector3(-84, 0, 10), "Head": Vector3(-24, 0, 0),
				"ArmR": Vector3(-10, 0, -40), "ArmL": Vector3(-10, 0, 40),
				"LegL": Vector3(14, 0, 0), "LegR": Vector3(-8, 0, 0),
				"WeaponPivot": Vector3(-10, 0, 0),
			}, 6.0)
		State.CHASE:
			screen.set_fill(0.0)
			rig.pose(POSE_IDLE, 8.0)
			rig.locomotion(Vector2(velocity.x, velocity.z).length() / float(stats.speed), delta)
		_:
			screen.set_fill(0.0)
			rig.pose(POSE_IDLE, 8.0)
