## Penyulut VFX combat: mendengarkan signal bus, men-spawn hitspark di titik kontak.
## Ditaruh sebagai child area per sesi gameplay.
class_name FxSpawner
extends Node

const PURPLE := Color(0.706, 0.298, 1.0)
const RED := Color(1.0, 0.18, 0.302)
const WHITE := Color(1.0, 1.0, 1.0)
const GOLD := Color(1.0, 0.85, 0.3)

func _ready() -> void:
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.player_damaged.connect(_on_player_damaged)
	CombatEvents.parried.connect(_on_parried)
	CombatEvents.perfect_dodge.connect(_on_perfect_dodge)

func _on_hit_landed(_attacker: Node, _target: Node, attack: AttackData, pos: Vector3) -> void:
	var big := attack.style_type == "A3" or attack.style_type == "skill"
	HitSpark.spawn(self, pos, PURPLE, 22 if big else 14, 9.0 if big else 7.0)

func _on_player_damaged(_amount: float, _source: Node) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player != null:
		HitSpark.spawn(self, player.global_position + Vector3.UP * 1.1, RED, 16, 7.0)

func _on_parried(perfect: bool, pos: Vector3) -> void:
	if perfect:
		HitSpark.spawn(self, pos, GOLD, 26, 10.0, 0.08)
	else:
		HitSpark.spawn(self, pos, WHITE, 12, 6.0)

func _on_perfect_dodge(pos: Vector3) -> void:
	HitSpark.spawn(self, pos, PURPLE, 20, 5.0, 0.07)
