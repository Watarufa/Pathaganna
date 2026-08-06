## Pause menu (Esc). Menghentikan seluruh tree kecuali dirinya sendiri, dan
## melepas mouse supaya tombol bisa diklik.
##
## Tidak pernah membuka saat player sudah mati: layar kalah yang memegang alur
## di situ, dan mem-pause di atasnya akan menggantung death loop.
extends CanvasLayer

var _panel: Control
var _paused := false

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.015, 0.03, 0.78)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 14)
	center.add_child(_panel)

	var title := Label.new()
	title.text = "J E D A"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.706, 0.298, 1.0))
	_panel.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	_panel.add_child(spacer)

	var resume := Button.new()
	resume.text = "L A N J U T"
	resume.custom_minimum_size = Vector2(280, 44)
	resume.pressed.connect(_resume)
	_panel.add_child(resume)

	var quit := Button.new()
	quit.text = "K E L U A R   K E   M E N U"
	quit.custom_minimum_size = Vector2(280, 44)
	quit.pressed.connect(_to_menu)
	_panel.add_child(quit)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _paused:
		_resume()
	elif GameManager.state == GameManager.GameState.PLAYING:
		_pause()
	get_viewport().set_input_as_handled()

func _pause() -> void:
	_paused = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in _panel.get_children():
		if c is Button:
			c.call_deferred("grab_focus")
			break

func _resume() -> void:
	_paused = false
	visible = false
	get_tree().paused = false
	if GameManager.state == GameManager.GameState.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _to_menu() -> void:
	_paused = false
	visible = false
	get_tree().paused = false
	CombatEvents.quit_to_menu.emit()
