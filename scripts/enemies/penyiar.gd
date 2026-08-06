## Penyiar — ranged, memaksa pemain terus bergerak.
## Entitas melayang berbadan radio tua + antena; menjaga jarak 8–12 m dan
## menjauh kalau didekati. Proyektilnya selalu merah: jawabannya dodge, bukan parry.
class_name Penyiar
extends EnemyBase

const DIAL_SIZE := Vector2(0.26, 0.16)
const DIAL_OFFSET := Vector3(0, 0.12, -0.19)

const POSE_IDLE := {
	Torso = Vector3.ZERO, ArmL = Vector3(0, 0, 18), ArmR = Vector3(0, 0, -18),
	Head = Vector3.ZERO,
}
## Antena terangkat dan badan mendongak — bentuk "mengisi daya" sebelum menembak.
const PROFILE_SHOT := {
	neutral = POSE_IDLE,
	ready  = { Torso = Vector3(-16, 0, 0), ArmL = Vector3(-24, 0, 40),
	           ArmR = Vector3(-24, 0, -40), Head = Vector3(-14, 0, 0) },
	coil   = { Torso = Vector3(-28, 0, 0), ArmL = Vector3(-38, 0, 54),
	           ArmR = Vector3(-38, 0, -54), Head = Vector3(-24, 0, 0) },
	follow = { Torso = Vector3(20, 0, 0), ArmL = Vector3(10, 0, 12),
	           ArmR = Vector3(10, 0, -12), Head = Vector3(16, 0, 0) },
}

var _bob := 0.0

func _stats() -> Dictionary:
	return Balance.PENYIAR

func _hitbox_shape() -> Shape3D:
	# tidak dipakai — serangannya melepas proyektil, bukan hitbox melee
	var b := BoxShape3D.new()
	b.size = Vector3(0.1, 0.1, 0.1)
	return b

## Melayang: tubuh & hurtbox berpusat di node, dan node-lah yang naik ke
## ketinggian hover — supaya visual, hurtbox, dan titik lock-on selalu sejajar.
func _body_capsule() -> Dictionary:
	return { radius = 0.42, height = 1.0, y = 0.0 }

func _hurtbox_capsule() -> Dictionary:
	return { radius = 0.5, height = 1.1, y = 0.0 }

func _build_body() -> void:
	rig.add_pivot("Hips", "", Vector3.ZERO)
	rig.add_pivot("Torso", "Hips", Vector3.ZERO)
	rig.add_pivot("Head", "Torso", Vector3(0, 0.3, 0))
	rig.add_pivot("ArmL", "Torso", Vector3(-0.22, 0.1, 0))
	rig.add_pivot("ArmR", "Torso", Vector3(0.22, 0.1, 0))

	# badan radio tua
	rig.attach_box("Torso", Vector3(0.46, 0.34, 0.3), Vector3.ZERO, Palette.METAL)
	rig.attach_box("Torso", Vector3(0.5, 0.06, 0.34), Vector3(0, -0.2, 0), Palette.CABLE)
	# dial menyala = telegraph-nya
	screen = TelegraphScreen.build(rig, "Torso", DIAL_SIZE, DIAL_OFFSET)
	# antena panjang + kepala kecil
	rig.attach_box("Head", Vector3(0.2, 0.14, 0.18), Vector3.ZERO, Palette.METAL)
	rig.attach_box("Head", Vector3(0.015, 0.6, 0.015), Vector3(0.06, 0.42, 0), Palette.METAL)
	rig.attach_sphere("Head", 0.035, Vector3(0.06, 0.74, 0), Palette.NEON_RED)
	# "lengan" antena samping
	rig.attach_box("ArmL", Vector3(0.015, 0.34, 0.015), Vector3(0, 0.17, 0), Palette.METAL)
	rig.attach_box("ArmR", Vector3(0.015, 0.34, 0.015), Vector3(0, 0.17, 0), Palette.METAL)
	# kabel menjuntai — menegaskan siluet melayang
	rig.attach_box("Torso", Vector3(0.02, 0.5, 0.02), Vector3(-0.1, -0.45, 0.05), Palette.CABLE)
	rig.attach_box("Torso", Vector3(0.02, 0.36, 0.02), Vector3(0.12, -0.38, -0.04), Palette.CABLE)

func get_lockon_point() -> Vector3:
	return global_position

func _idle_pose() -> Dictionary:
	return POSE_IDLE

func _attack_profile() -> Dictionary:
	return PROFILE_SHOT

## Melayang: tahan ketinggian di atas titik spawn alih-alih jatuh.
func _apply_gravity(delta: float) -> void:
	var want := _spawn_point.y + float(stats.hover_height)
	velocity.y = move_toward(velocity.y, (want - global_position.y) * 4.0, 18.0 * delta)

func _ai_move(delta: float, target: Node3D, dist: float) -> void:
	var to := target.global_position - global_position
	to.y = 0.0
	if dist < float(stats.keep_min):
		_steer(delta, -to, float(stats.speed))        # terlalu dekat → mundur
	elif dist > float(stats.keep_max):
		_steer(delta, to, float(stats.speed))         # terlalu jauh → maju
	else:
		# dalam jarak ideal: menyamping, supaya pemain tidak bisa diam menembak balik
		var side := Vector3(-to.z, 0.0, to.x)
		_steer(delta, side, float(stats.speed) * 0.5)

func _pick_attack(dist: float) -> Dictionary:
	if dist > float(stats.attack_range):
		return {}
	return stats.shot

func _on_swing_begin() -> void:
	var target := _player()
	if target == null:
		return
	var muzzle := global_position - transform.basis.z * 0.4
	var aim := (target.global_position + Vector3.UP * 1.0) - muzzle
	SignalProjectile.spawn(get_parent(), muzzle, aim, stats.proj, self)

func _pose_for_state(vis_time: float, delta: float) -> void:
	_bob += delta
	rig.pivot("Hips").position.y = sin(_bob * 1.8) * 0.09

	match state:
		State.WINDUP:
			rig.snap(Telegraph.windup_pose(PROFILE_SHOT, vis_time, float(current.windup)))
			screen.set_fill(Telegraph.fill_amount(vis_time, float(current.windup)))
		State.SWING:
			screen.set_fill(0.0)
			var k := clampf(vis_time / maxf(float(current.swing), 0.01), 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			rig.snap(Telegraph.blend(PROFILE_SHOT.coil, PROFILE_SHOT.follow, k))
		State.STAGGER, State.KNOCKDOWN:
			screen.set_fill(0.0)
			rig.pose({
				"Torso": Vector3(-34, 0, 14), "Head": Vector3(-24, 0, 0),
				"ArmL": Vector3(-10, 0, 8), "ArmR": Vector3(-10, 0, -8),
			}, 10.0)
		State.DEAD:
			# sinyalnya putus: berhenti melayang, terkulai jatuh
			screen.power_off()
			rig.pose({
				"Torso": Vector3(48, 0, 26), "Head": Vector3(30, 0, 0),
				"ArmL": Vector3(20, 0, 4), "ArmR": Vector3(20, 0, -4),
			}, 5.0)
		_:
			screen.set_fill(0.0)
			rig.pose(POSE_IDLE, 7.0)
