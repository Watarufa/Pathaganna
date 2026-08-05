## Area penyerang. FSM pemilik memanggil begin()/end() sesuai window state-nya —
## hitbox hanya monitoring selama window itu. Satu aktivasi = maksimal satu hit
## per target. Membawa AttackData ke Hurtbox lawan.
class_name Hitbox
extends Area3D

signal landed(target_hurtbox: Area3D, attack: AttackData)

var attack: AttackData = null

var _hit_targets: Array = []

func _init() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)

func begin(attack_data: AttackData) -> void:
	attack = attack_data
	_hit_targets.clear()
	monitoring = true

func end() -> void:
	monitoring = false
	attack = null

## area_entered saja melewatkan hurtbox yang SUDAH tumpang tindih saat window dibuka
## (kasus umum: musuh menempel di badan player). Sapuan per frame menutup celah itu;
## _hit_targets menjaga satu hit per target per aktivasi.
func _physics_process(_delta: float) -> void:
	if not monitoring or attack == null:
		return
	for area in get_overlapping_areas():
		_try_hit(area)

func _on_area_entered(area: Area3D) -> void:
	_try_hit(area)

func _try_hit(area: Area3D) -> void:
	if attack == null or area in _hit_targets or not (area is Hurtbox):
		return
	_hit_targets.append(area)
	area.receive(attack, self)
	landed.emit(area, attack)
