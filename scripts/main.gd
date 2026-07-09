## Root alur game: menu → gameplay → (kalah → respawn) → menang.
## Bertindak sebagai composition root; scene lain tidak saling load langsung.
extends Node

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const AREA_SCENE := "res://scenes/level/area.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const OVERLAY_SCENE := "res://scenes/ui/debug_overlay.tscn"

var _current: Node = null
var _overlay: CanvasLayer = null

func _ready() -> void:
	_overlay = load(OVERLAY_SCENE).instantiate()
	add_child(_overlay)
	# `-- --smoke` dari CLI: langsung boot gameplay tanpa menu (untuk smoke test headless)
	if "--smoke" in OS.get_cmdline_user_args():
		start_game()
	else:
		show_menu()

func show_menu() -> void:
	print("[main] menu")
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
	var player: Node = load(PLAYER_SCENE).instantiate()
	player.position = area.get_player_spawn()
	area.add_child(player)
	_overlay.player = player

func _unhandled_input(event: InputEvent) -> void:
	# Sementara (sampai pause menu M4): Esc melepas/menangkap mouse saat gameplay
	if event.is_action_pressed("pause") and GameManager.state == GameManager.GameState.PLAYING:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_quit() -> void:
	get_tree().quit()

func _clear_current() -> void:
	TimeJuice.clear()
	if _overlay != null:
		_overlay.player = null
	if is_instance_valid(_current):
		_current.queue_free()
	_current = null
