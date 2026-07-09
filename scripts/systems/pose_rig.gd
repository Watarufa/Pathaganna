## Rig visual murni: pivot bernama + mesh primitif + interpolasi pose.
## ATURAN ARSITEKTUR #2: rig ini TIDAK PERNAH menjadi sumber timing gameplay.
## State FSM pemiliknya yang mendorong pose; rig hanya mengikuti.
class_name PoseRig
extends Node3D

## Ayunan ArmR dikali ini saat locomotion (tangan pembawa senjata mengayun lebih kecil).
var arm_r_scale := 1.0

var meshes: Array[MeshInstance3D] = []

var _pivots := {}      # String -> Node3D
var _base_pos := {}    # String -> Vector3 posisi lokal awal
var _targets := {}     # String -> Quaternion target
var _speeds := {}      # String -> float kecepatan blend
var _cycle_phase := 0.0
var _flash_until_ms := -1

# ------------------------------------------------------------- konstruksi
func add_pivot(pname: String, parent_name: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = pname
	p.position = pos
	if parent_name.is_empty():
		add_child(p)
	else:
		_pivots[parent_name].add_child(p)
	_pivots[pname] = p
	_base_pos[pname] = pos
	_targets[pname] = Quaternion.IDENTITY
	_speeds[pname] = 12.0
	return p

func add_marker(parent_name: String, mname: String, pos: Vector3) -> Node3D:
	var m := Node3D.new()
	m.name = mname
	m.position = pos
	_pivots[parent_name].add_child(m)
	_pivots[mname] = m
	return m

func pivot(pname: String) -> Node3D:
	return _pivots.get(pname)

func attach_box(pname: String, size: Vector3, offset: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _attach(pname, mesh, offset, mat)

func attach_capsule(pname: String, radius: float, height: float, offset: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _attach(pname, mesh, offset, mat)

func attach_cylinder(pname: String, radius: float, height: float, offset: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return _attach(pname, mesh, offset, mat)

func attach_sphere(pname: String, radius: float, offset: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _attach(pname, mesh, offset, mat)

func _attach(pname: String, mesh: Mesh, offset: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = offset
	mi.material_override = mat
	_pivots[pname].add_child(mi)
	meshes.append(mi)
	return mi

# ------------------------------------------------------------- pose
## Set target rotasi pivot (euler DERAJAT), diinterpolasi dengan kecepatan blend.
func pose(targets: Dictionary, speed: float) -> void:
	for k in targets:
		if not _pivots.has(k):
			continue
		_targets[k] = Quaternion.from_euler(targets[k] * (PI / 180.0))
		_speeds[k] = speed

## Set rotasi langsung tanpa interpolasi (untuk ayunan yang didorong state_time).
func snap(targets: Dictionary) -> void:
	for k in targets:
		if not _pivots.has(k):
			continue
		var q := Quaternion.from_euler(targets[k] * (PI / 180.0))
		(_pivots[k] as Node3D).quaternion = q
		_targets[k] = q

## Siklus lari prosedural: ayunan sinus kaki/lengan + bobbing pinggul.
func locomotion(speed_ratio: float, delta: float) -> void:
	var r := clampf(speed_ratio, 0.0, 1.0)
	_cycle_phase += delta * lerpf(1.5, 10.0, r)
	var s := sin(_cycle_phase)
	var leg := s * lerpf(2.0, 40.0, r)
	var arm := s * lerpf(1.5, 32.0, r)
	pose({
		"LegL": Vector3(leg, 0, 0),
		"LegR": Vector3(-leg, 0, 0),
		"ArmL": Vector3(-arm, 0, 0),
		"ArmR": Vector3(arm * arm_r_scale, 0, 0),
	}, 30.0)
	if _pivots.has("Hips"):
		var hips: Node3D = _pivots["Hips"]
		hips.position = _base_pos["Hips"] + Vector3(0, absf(cos(_cycle_phase)) * 0.055 * r, 0)

## Overlay putih singkat saat terkena hit (durasi real-time, tetap terlihat saat hitstop).
func flash(duration: float) -> void:
	_flash_until_ms = Time.get_ticks_msec() + int(duration * 1000.0)
	for m in meshes:
		m.material_overlay = Palette.FLASH_OVERLAY

func _process(delta: float) -> void:
	for k in _targets:
		var p: Node3D = _pivots[k]
		p.quaternion = p.quaternion.slerp(_targets[k], 1.0 - exp(-_speeds[k] * delta))
	if _flash_until_ms >= 0 and Time.get_ticks_msec() >= _flash_until_ms:
		_flash_until_ms = -1
		for m in meshes:
			m.material_overlay = null
