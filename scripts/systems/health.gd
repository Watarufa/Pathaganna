## Komponen nyawa generik untuk player dan musuh.
## Angka HP selalu datang dari Balance lewat setup() — tidak ada nilai di sini.
class_name Health
extends Node

signal changed(hp: float, max_hp: float)
signal died

var max_hp := 1.0
var hp := 1.0

func setup(maximum: float) -> void:
	max_hp = maximum
	hp = maximum
	changed.emit(hp, max_hp)

## Mengembalikan true jika damage ini mematikan.
func damage(amount: float) -> bool:
	if hp <= 0.0:
		return false
	hp = maxf(hp - amount, 0.0)
	changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()
		return true
	return false

func heal_full() -> void:
	hp = max_hp
	changed.emit(hp, max_hp)

func is_alive() -> bool:
	return hp > 0.0
