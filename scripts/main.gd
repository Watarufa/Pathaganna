## Root alur game: menu → gameplay → (kalah → respawn) → menang.
## Bertindak sebagai composition root; scene lain tidak saling load langsung.
extends Node

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const AREA_SCENE := "res://scenes/level/area.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const OVERLAY_SCENE := "res://scenes/ui/debug_overlay.tscn"
const DEATH_SCENE := "res://scenes/ui/death_screen.tscn"
const COMBAT_SMOKE := "res://scripts/dev/combat_smoke.gd"

var _current: Node = null
var _overlay: CanvasLayer = null
var _player: Node = null
var _death_screen: CanvasLayer = null

func _ready() -> void:
	_overlay = load(OVERLAY_SCENE).instantiate()
	add_child(_overlay)
	CombatEvents.player_died.connect(_on_player_died)
	CombatEvents.quit_to_menu.connect(show_menu)
	# `-- --smoke` / `-- --combat-smoke` dari CLI: langsung boot gameplay tanpa menu
	var args := OS.get_cmdline_user_args()
	if "--smoke" in args or "--combat-smoke" in args:
		start_game()
	else:
		show_menu()

func show_menu() -> void:
	print("[main] menu")
	get_tree().paused = false
	_clear_current()
	GameManager.state = GameManager.GameState.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var menu: Node = load(MENU_SCENE).instantiate()
	add_child(menu)
	_current = menu
	menu.start_requested.connect(start_game)
	menu.quit_requested.connect(_on_quit)

func start_game() -> void:
	print("[main] gameplay start")
	_clear_current()
	GameManager.start_run()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var area: Node = load(AREA_SCENE).instantiate()
	add_child(area)
	_current = area
	_spawn_player(area)

	if "--combat-smoke" in OS.get_cmdline_user_args():
		var smoke: Node = load(COMBAT_SMOKE).new()
		smoke.name = "CombatSmoke"
		smoke.player = _player
		area.add_child(smoke)

func _spawn_player(area: Node) -> void:
	var player: Node = load(PLAYER_SCENE).instantiate()
	player.position = area.get_player_spawn()
	area.add_child(player)
	_player = player
	_overlay.player = player

# ------------------------------------------------------------- death loop
## Respawn di Ganna terakhir yang diaktifkan (area yang menentukan titiknya),
## HP penuh, meter skill dipertahankan, semua musuh biasa kembali.
func _on_player_died() -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	GameManager.state = GameManager.GameState.DEAD
	TimeJuice.clear()
	if _death_screen != null:
		return
	_death_screen = load(DEATH_SCENE).instantiate()
	add_child(_death_screen)
	_death_screen.respawn_requested.connect(_respawn)

func _respawn() -> void:
	if _death_screen != null:
		_death_screen.queue_free()
		_death_screen = null
	if not is_instance_valid(_current):
		return

	if is_instance_valid(_player):
		_player.queue_free()
	# player baru mengambil meter yang dipertahankan lewat GameManager
	_spawn_player(_current)
	_current.reset_enemies()
	GameManager.state = GameManager.GameState.PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	CombatEvents.player_respawned.emit()

func _on_quit() -> void:
	get_tree().quit()

func _clear_current() -> void:
	TimeJuice.clear()
	if _overlay != null:
		_overlay.player = null
	if _death_screen != null:
		_death_screen.queue_free()
		_death_screen = null
	if is_instance_valid(_current):
		_current.queue_free()
	_current = null
	_player = null
