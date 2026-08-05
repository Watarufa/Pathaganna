## HUD gameplay. Murni pendengar signal bus — tidak pernah mem-polling player.
## HP kiri bawah, meter skill bergaya kaset di sebelahnya, style rank kanan atas.
extends CanvasLayer

const PURPLE := Color(0.706, 0.298, 1.0)
const DIM := Color(0.32, 0.28, 0.4)

var _hp := 1.0
var _meter := 0.0
var _meter_full := false

var _bars: Control
var _rank_label: Label
var _prompt: Label
var _reel_spin := 0.0

func _ready() -> void:
	layer = 10

	_bars = Control.new()
	_bars.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bars.position = Vector2(28, -128)
	_bars.size = Vector2(460, 110)
	_bars.draw.connect(_draw_bars)
	add_child(_bars)

	_rank_label = Label.new()
	_rank_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rank_label.position = Vector2(-190, 22)
	_rank_label.size = Vector2(160, 80)
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rank_label.add_theme_font_size_override("font_size", 60)
	_rank_label.add_theme_constant_override("shadow_offset_x", 2)
	_rank_label.add_theme_constant_override("shadow_offset_y", 2)
	_rank_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	add_child(_rank_label)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-200, -210)
	_prompt.size = Vector2(400, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", PURPLE)
	_prompt.visible = false
	add_child(_prompt)

	CombatEvents.player_hp_changed.connect(_on_hp)
	CombatEvents.meter_changed.connect(_on_meter)
	CombatEvents.style_changed.connect(_on_style)
	CombatEvents.interact_prompt.connect(_on_prompt)

func _process(delta: float) -> void:
	# reel kaset berputar saat "merekam" (meter penuh) — umpan balik kecil, gratis
	if _meter_full:
		_reel_spin += delta * 6.0
	_bars.queue_redraw()

func _on_hp(hp: float, max_hp: float) -> void:
	_hp = hp / maxf(max_hp, 0.001)

func _on_meter(value: float, max_value: float) -> void:
	_meter = value / maxf(max_value, 0.001)
	_meter_full = _meter >= 1.0

func _on_style(_score: float, rank: String, color: Color) -> void:
	_rank_label.text = rank
	_rank_label.add_theme_color_override("font_color", color)

func _on_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = not text.is_empty()

# ------------------------------------------------------------- gambar
func _draw_bars() -> void:
	var font := ThemeDB.fallback_font

	# --- HP bar ---
	var hp_rect := Rect2(0, 74, 260, 16)
	_bars.draw_rect(hp_rect.grow(2), Color(0, 0, 0, 0.65))
	_bars.draw_rect(hp_rect, Color(0.16, 0.1, 0.14))
	var hp_fill := hp_rect
	hp_fill.size.x = hp_rect.size.x * _hp
	var hp_color := Color(0.9, 0.25, 0.35) if _hp < 0.3 else Color(0.85, 0.82, 0.9)
	_bars.draw_rect(hp_fill, hp_color)
	_bars.draw_string(font, Vector2(0, 68), "H P", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)

	# --- meter skill bergaya kaset: dua reel + pita yang terisi ---
	var origin := Vector2(276, 44)
	var body := Rect2(origin.x, origin.y, 168, 52)
	var glow: Color = PURPLE if _meter_full else Color(0.4, 0.34, 0.5)
	_bars.draw_rect(body.grow(2), Color(0, 0, 0, 0.65))
	_bars.draw_rect(body, Color(0.1, 0.09, 0.14))
	_bars.draw_rect(body, glow, false, 2.0)

	var reel_l := origin + Vector2(44, 26)
	var reel_r := origin + Vector2(124, 26)
	for c in [reel_l, reel_r]:
		_bars.draw_circle(c, 18.0, Color(0.07, 0.06, 0.1))
		_bars.draw_arc(c, 18.0, 0, TAU, 24, glow, 1.5)
		# jari-jari reel berputar saat penuh
		for i in 3:
			var ang := _reel_spin + float(i) * TAU / 3.0
			_bars.draw_line(c, c + Vector2(cos(ang), sin(ang)) * 12.0, glow, 1.5)

	# pita antar reel: terisi seiring meter ("merekam" energi tiap parry)
	var tape := Rect2(reel_l.x, origin.y + 38, reel_r.x - reel_l.x, 8)
	_bars.draw_rect(tape, Color(0.13, 0.11, 0.17))
	var tape_fill := tape
	tape_fill.size.x = tape.size.x * _meter
	_bars.draw_rect(tape_fill, PURPLE)
	var label: String = "S K I L L   S I A P  ( Q )" if _meter_full else "S K I L L"
	_bars.draw_string(font, Vector2(origin.x, origin.y - 8), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, glow)
