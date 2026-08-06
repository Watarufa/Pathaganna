## Lock-on player.
##
## Tab murni **kunci / lepas** — menekannya lagi saat terkunci akan melepas,
## bukan berpindah target. Ganti target dilakukan dengan **menggeser mouse** ke
## arah musuh lain, yang jauh lebih langsung saat beberapa musuh mengepung
## daripada menyiklus daftar sampai kebetulan sampai ke yang dimaksud.
##
## Target = anggota group "lockon_targets". Auto-lepas saat target mati
## (keluar group / di-free) atau lebih jauh dari break_range.
class_name LockOn
extends Node

signal target_changed(target: Node3D)

const GROUP := "lockon_targets"

var body: CharacterBody3D = null
var target: Node3D = null

var _switch_accum := 0.0
var _switch_cd := 0.0

static func point_of(t: Node3D) -> Vector3:
	if t.has_method("get_lockon_point"):
		return t.get_lockon_point()
	return t.global_position + Vector3.UP * 1.2

## Tab: terkunci → lepas; belum → kunci kandidat terdekat.
func toggle() -> void:
	if target != null:
		_set_target(null)
		return
	var candidates := _valid_candidates()
	if candidates.is_empty():
		return
	_set_target(_closest(candidates))

## Gerakan mouse horizontal saat terkunci. Akumulasi + ambang + cooldown supaya
## satu sapuan memindahkan tepat satu target, dan getaran kecil tidak memindahkan
## apa pun.
func accumulate_switch(dx: float, cam_basis: Basis) -> void:
	if target == null or _switch_cd > 0.0:
		return
	_switch_accum += dx
	if absf(_switch_accum) >= Balance.LOCKON.switch_threshold:
		_switch_horizontal(signf(_switch_accum), cam_basis)
		_switch_accum = 0.0
		_switch_cd = Balance.LOCKON.switch_cooldown

func _physics_process(delta: float) -> void:
	if _switch_cd > 0.0:
		_switch_cd -= delta
	_switch_accum = move_toward(_switch_accum, 0.0, Balance.LOCKON.switch_decay * delta)

	if target == null:
		return
	if not is_instance_valid(target) or not target.is_in_group(GROUP):
		_set_target(null)
		return
	if body != null and body.global_position.distance_to(target.global_position) > Balance.LOCKON.break_range:
		_set_target(null)

## Pindah ke kandidat terdekat secara sudut di sisi yang dituju (dir: -1 kiri, +1 kanan).
func _switch_horizontal(dir: float, cam_basis: Basis) -> void:
	if target == null:
		return
	var candidates := _valid_candidates()
	if candidates.size() <= 1:
		return
	var inv := cam_basis.inverse()
	var current := _view_angle(target, inv)
	var best: Node3D = null
	var best_delta := INF
	for c in candidates:
		if c == target:
			continue
		var d := wrapf(_view_angle(c, inv) - current, -PI, PI)
		if d * dir <= 0.0:
			continue  # bukan di sisi yang dituju
		if absf(d) < best_delta:
			best_delta = absf(d)
			best = c
	if best != null:
		_set_target(best)

## Sudut horizontal target relatif arah pandang kamera (positif = kanan layar).
## Dipakai alih-alih posisi layar supaya target di luar layar tetap terjangkau.
func _view_angle(t: Node3D, inv_cam: Basis) -> float:
	var local: Vector3 = inv_cam * (t.global_position - body.global_position)
	return atan2(local.x, -local.z)

func _valid_candidates() -> Array:
	var out := []
	if body == null:
		return out
	for n in get_tree().get_nodes_in_group(GROUP):
		if n is Node3D and is_instance_valid(n):
			if body.global_position.distance_to(n.global_position) <= Balance.LOCKON.acquire_range:
				out.append(n)
	return out

func _closest(candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for c in candidates:
		var d: float = body.global_position.distance_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best

func _set_target(t: Node3D) -> void:
	if t == target:
		return
	target = t
	target_changed.emit(target)
