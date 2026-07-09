## State global game: alur menu/main/mati/menang, checkpoint Ganna, statistik run.
## Respawn dieksekusi oleh main.gd; manager ini hanya menyimpan kebenaran.
extends Node

enum GameState { MENU, PLAYING, DEAD, VICTORY }

var state: GameState = GameState.MENU

## Checkpoint aktif ("" = belum ada; spawn awal level dipakai).
var checkpoint_id: String = ""

## Meter skill dipertahankan lintas kematian (aturan death loop).
var persisted_meter: float = 0.0

## Statistik run untuk layar menang.
var play_time: float = 0.0
var best_rank: String = "D"
var best_rank_index: int = 0

func _process(delta: float) -> void:
	if state == GameState.PLAYING:
		play_time += delta

func start_run() -> void:
	state = GameState.PLAYING
	checkpoint_id = ""
	persisted_meter = 0.0
	play_time = 0.0
	best_rank = "D"
	best_rank_index = 0

func set_checkpoint(id: String) -> void:
	checkpoint_id = id
	CombatEvents.checkpoint_activated.emit(id)

func report_rank(rank: String, index: int) -> void:
	if index > best_rank_index:
		best_rank_index = index
		best_rank = rank

func format_play_time() -> String:
	var total := int(play_time)
	return "%02d:%02d" % [total / 60, total % 60]
