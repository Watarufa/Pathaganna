## Lock-on player: Tab = kunci target terdekat / cycle / lepas.
## Target = anggota group "lockon_targets". Auto-lepas saat target mati
## (keluar group / di-free) atau lebih jauh dari break_range.
class_name LockOn
extends Node

signal target_changed(target: Node3D)

const GROUP := "lockon_targets"

var body: CharacterBody3D = null
var target: Node3D = null

static func point_of(t: Node3D) -> Vector3:
	if t.has_method("get_lockon_point"):
		return t.get_lockon_point()
	return t.global_position + Vector3.UP * 1.2

func toggle() -> void:
	var candidates := _valid_candidates()
	if candidates.is_empty():
		_set_target(null)
		return
	if target == null or not candidates.has(target):
		_set_target(_closest(candidates))
		return
	if candidates.size() == 1:
		_set_target(null)  # tidak ada kandidat lain → unlock
		return
	candidates.sort_custom(_by_distance)
	var i := candidates.find(target)
	_set_target(candidates[(i + 1) % candidates.size()])

func _physics_process(_delta: float) -> void:
	if target == null:
		return
	if not is_instance_valid(target) or not target.is_in_group(GROUP):
		_set_target(null)
		return
	if body != null and body.global_position.distance_to(target.global_position) > Balance.LOCKON.break_range:
		_set_target(null)

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

func _by_distance(a: Node3D, b: Node3D) -> bool:
	return body.global_position.distance_to(a.global_position) < body.global_position.distance_to(b.global_position)

func _set_target(t: Node3D) -> void:
	if t == target:
		return
	target = t
	target_changed.emit(target)
