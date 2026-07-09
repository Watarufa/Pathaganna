## Kamera third-person: SpringArm orbit mouse + pelunakan lock-on + shake trauma.
## top_level: tidak ikut rotasi body player.
class_name CameraRig
extends Node3D

var target_body: CharacterBody3D = null
var lock_target: Node3D = null
var yaw := 0.0
var pitch := deg_to_rad(-12.0)
var trauma := 0.0

var _arm: SpringArm3D
var _cam: Camera3D
var _noise := FastNoiseLite.new()
var _pitch_min: float
var _pitch_max: float

func _ready() -> void:
	top_level = true
	_pitch_min = deg_to_rad(Balance.CAMERA.pitch_min)
	_pitch_max = deg_to_rad(Balance.CAMERA.pitch_max)

	_arm = SpringArm3D.new()
	_arm.spring_length = Balance.CAMERA.distance
	_arm.collision_mask = 1  # hanya world
	_arm.margin = 0.3
	add_child(_arm)

	_cam = Camera3D.new()
	_cam.fov = Balance.CAMERA.fov
	_cam.near = 0.05
	_arm.add_child(_cam)
	_cam.current = true

	_noise.seed = 7
	_noise.frequency = 1.0

	# shake didorong signal bus — tidak ada polling combat
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.player_damaged.connect(_on_player_damaged)
	CombatEvents.skill_used.connect(_on_skill_used)

	if target_body != null:
		global_position = target_body.global_position + Vector3(0, Balance.CAMERA.pivot_height, 0)
		yaw = target_body.rotation.y

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if lock_target == null:
			yaw -= event.relative.x * Balance.CAMERA.mouse_sens
			pitch = clampf(pitch - event.relative.y * Balance.CAMERA.mouse_sens, _pitch_min, _pitch_max)

func _process(delta: float) -> void:
	if target_body == null or not is_instance_valid(target_body):
		return
	var target_pos: Vector3 = target_body.global_position + Vector3(0, Balance.CAMERA.pivot_height, 0)
	global_position = global_position.lerp(target_pos, 1.0 - exp(-Balance.CAMERA.follow_lerp * delta))

	if lock_target != null and is_instance_valid(lock_target):
		var to: Vector3 = lock_target.global_position - target_body.global_position
		to.y = 0.0
		if to.length_squared() > 0.25:
			var k := 1.0 - exp(-Balance.CAMERA.lockon_lerp * delta)
			yaw = lerp_angle(yaw, atan2(-to.x, -to.z), k)
			pitch = lerpf(pitch, deg_to_rad(-14.0), k)

	rotation.y = yaw
	_arm.rotation.x = pitch
	_apply_shake(delta)

func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)

func _apply_shake(delta: float) -> void:
	trauma = maxf(trauma - Balance.JUICE.trauma_decay * delta, 0.0)
	var amt := trauma * trauma
	if amt < 0.0001:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
		_cam.rotation.z = 0.0
		return
	var t := Time.get_ticks_msec() / 1000.0
	_cam.h_offset = _noise.get_noise_2d(t * 28.0, 0.0) * Balance.JUICE.shake_max_offset * amt
	_cam.v_offset = _noise.get_noise_2d(0.0, t * 28.0) * Balance.JUICE.shake_max_offset * amt
	_cam.rotation.z = _noise.get_noise_2d(t * 28.0, 99.0) * Balance.JUICE.shake_max_roll * amt

func _on_hit_landed(_attacker: Node, _target: Node, _attack: AttackData, _pos: Vector3) -> void:
	add_trauma(Balance.JUICE.shake_hit_dealt)

func _on_player_damaged(_amount: float, _source: Node) -> void:
	add_trauma(Balance.JUICE.shake_hit_taken)

func _on_skill_used() -> void:
	add_trauma(Balance.JUICE.shake_skill)
