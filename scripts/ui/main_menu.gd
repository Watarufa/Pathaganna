## Menu utama placeholder (M0). Versi final dengan latar Ganna TV statis dibangun di M5.
extends Control

signal start_requested
signal quit_requested

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.051, 0.039, 0.078)  # #0d0a14
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = "P A T H A G A N N A"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.706, 0.298, 1.0))  # #b44cff
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "S I A R A N   M E N U N G G U"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6))
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	box.add_child(spacer)

	var start := Button.new()
	start.text = "M U L A I"
	start.custom_minimum_size = Vector2(280, 46)
	start.pressed.connect(func() -> void: start_requested.emit())
	box.add_child(start)

	var quit := Button.new()
	quit.text = "K E L U A R"
	quit.custom_minimum_size = Vector2(280, 46)
	quit.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(quit)

	start.call_deferred("grab_focus")
