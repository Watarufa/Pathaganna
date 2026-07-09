## Root alur game: menu → gameplay → (kalah → respawn) → menang.
## Bertindak sebagai composition root; scene lain tidak saling load langsung.
extends Node

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const AREA_SCENE := "res://scenes/level/area.tscn"

var _current: Node = null

func _ready() -> void:
	# `-- --smoke` dari CLI: langsung boot gameplay tanpa menu (untuk smoke test headless)
	if "--smoke" in OS.get_cmdline_user_args():
		start_game()
	else:
		show_menu()

func show_menu() -> void:
	_clear_current()
	GameManager.state = GameManager.GameState.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var menu: Node = load(MENU_SCENE).instantiate()
	add_child(menu)
	_current = menu
	menu.start_requested.connect(start_game)
	menu.quit_requested.connect(_on_quit)

func start_game() -> void:
	if not ResourceLoader.exists(AREA_SCENE):
		push_warning("area.tscn belum dibangun (menyusul di M1).")
		return
	_clear_current()
	GameManager.start_run()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var game: Node = load(AREA_SCENE).instantiate()
	add_child(game)
	_current = game

func _on_quit() -> void:
	get_tree().quit()

func _clear_current() -> void:
	TimeJuice.clear()
	if is_instance_valid(_current):
		_current.queue_free()
	_current = null
