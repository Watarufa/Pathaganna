## Layar kalah: "SINYAL HILANG" + statis berkedip, auto-respawn setelah
## LEVEL.death_screen_time. Versi final (partikel statis penuh) menyusul di M5.
extends CanvasLayer

signal respawn_requested

var _time := 0.0
var _fired := false
var _static_rect: ColorRect
var _title: Label

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.015, 0.03, 0.82)
	add_child(bg)

	_static_rect = ColorRect.new()
	_static_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_static_rect.color = Color(0.7, 0.75, 0.72, 0.05)
	add_child(_static_rect)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_title = Label.new()
	_title.text = "S I N Y A L   H I L A N G"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 58)
	_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	center.add_child(_title)

func _process(delta: float) -> void:
	_time += delta
	# flicker statis: intensitas acak, kesan siaran yang putus
	_static_rect.color.a = randf_range(0.02, 0.09)
	_title.modulate.a = 0.65 + 0.35 * absf(sin(_time * 3.0))
	if not _fired and _time >= Balance.LEVEL.death_screen_time:
		_fired = true
		respawn_requested.emit()
