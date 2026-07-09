## Area penerima serangan. Hitbox lawan memanggil receive();
## pemilik hurtbox memutuskan konsekuensinya (i-frame, parry, damage).
## Layer: player_hurt (4) atau enemy_hurt (5); monitorable, tidak monitoring.
class_name Hurtbox
extends Area3D

signal hit_received(attack: AttackData, hitbox: Area3D)

func _init() -> void:
	monitoring = false
	monitorable = true

func receive(attack: AttackData, hitbox: Area3D) -> void:
	hit_received.emit(attack, hitbox)
