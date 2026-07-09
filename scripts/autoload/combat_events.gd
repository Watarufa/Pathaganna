## Signal bus global PATHAGANNA.
## Semua komunikasi lintas sistem (combat → HUD/style/VFX) lewat sini;
## tidak ada UI yang mem-polling player.
extends Node

# --- pertarungan ---
signal hit_landed(attacker: Node, target: Node, attack: AttackData, pos: Vector3)
signal player_damaged(amount: float, source: Node)
signal player_hp_changed(hp: float, max_hp: float)
signal player_died
signal player_respawned
signal parried(perfect: bool, pos: Vector3)
signal perfect_dodge(pos: Vector3)
signal skill_used
signal enemy_staggered(enemy: Node)
signal enemy_died(enemy: Node)

# --- progresi & UI ---
signal meter_changed(value: float, max_value: float)
signal style_changed(score: float, rank: String, rank_color: Color)
signal boss_engaged(boss: Node, display_name: String)
signal boss_hp_changed(hp: float, max_hp: float)
signal boss_phase_started(phase: int, display_name: String)
signal boss_defeated
signal checkpoint_activated(id: String)
signal interact_prompt(text: String)  # "" = sembunyikan prompt
