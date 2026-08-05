## Style meter D→SSS. Murni pendengar signal bus — tidak menyentuh player.
## Hidup per sesi gameplay (child area); mati bersama sesi.
class_name StyleMeter
extends Node

var score := 0.0

var _since_action := 999.0
var _last_type := ""

func _ready() -> void:
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.parried.connect(_on_parried)
	CombatEvents.perfect_dodge.connect(_on_perfect_dodge)
	CombatEvents.player_damaged.connect(_on_player_damaged)
	_emit()

func _process(delta: float) -> void:
	_since_action += delta
	if _since_action >= Balance.STYLE.decay_delay and score > 0.0:
		score = maxf(score - Balance.STYLE.decay_per_sec * delta, 0.0)
		_emit()

func _on_hit_landed(attacker: Node, _target: Node, attack: AttackData, _pos: Vector3) -> void:
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_in_group("player"):
		return
	var gain: float
	if attack.style_type == "skill":
		gain = Balance.STYLE.skill_gain
	else:
		gain = Balance.STYLE.hit_gain
		if _last_type != "" and attack.style_type != _last_type:
			gain += Balance.STYLE.variety_bonus
	_last_type = attack.style_type
	_gain(gain)

func _on_parried(_perfect: bool, _pos: Vector3) -> void:
	_gain(Balance.STYLE.defense_gain)

func _on_perfect_dodge(_pos: Vector3) -> void:
	_gain(Balance.STYLE.defense_gain)

func _on_player_damaged(_amount: float, _source: Node) -> void:
	score *= (1.0 - Balance.STYLE.hit_penalty_frac)
	_emit()

func _gain(amount: float) -> void:
	score = clampf(score + amount, 0.0, Balance.STYLE.max_score)
	_since_action = 0.0
	_emit()

func _emit() -> void:
	var idx := 0
	for i in Balance.STYLE.ranks.size():
		if score >= Balance.STYLE.ranks[i][1]:
			idx = i
	var rank: Array = Balance.STYLE.ranks[idx]
	GameManager.report_rank(rank[0], idx)
	CombatEvents.style_changed.emit(score, rank[0], rank[2])
