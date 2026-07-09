## Debug overlay F3 — alat utama tuning fairness.
## Menampilkan FPS, state aktif, dan TIMELINE window (i-frame / parry / hitbox / cancel)
## yang digambar langsung dari Balance + state_time player.
## Catatan: overlay ini SENGAJA membaca player secara langsung — ini debug tool,
## bukan UI gameplay (aturan "UI tidak polling player" berlaku untuk HUD).
extends CanvasLayer

const BAR_W := 440.0
const BAR_H := 22.0

var player: Node = null

var _text: Label
var _timeline: Control

func _ready() -> void:
	layer = 90
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_text = Label.new()
	_text.position = Vector2(12, 12)
	_text.add_theme_font_size_override("font_size", 13)
	_text.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 1)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_child(_text)

	_timeline = Control.new()
	_timeline.position = Vector2(12, 190)
	_timeline.size = Vector2(BAR_W, 70)
	_timeline.draw.connect(_draw_timeline)
	add_child(_timeline)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_text()
	_timeline.queue_redraw()

func _update_text() -> void:
	var lines: Array[String] = []
	lines.append("FPS %d   time_scale %.2f" % [Engine.get_frames_per_second(), Engine.time_scale])
	if player != null and is_instance_valid(player):
		lines.append("state %s   t = %.3f s" % [player.state_name(), player.state_time])
		lines.append("hp %.0f/%.0f   meter %.0f" % [player.health.hp, player.health.max_hp, player.meter])
		var v: Vector3 = player.velocity
		lines.append("speed %.2f m/s" % Vector2(v.x, v.z).length())
		var lt: Node3D = player.lockon.target
		lines.append("lockon: %s" % (String(lt.name) if lt != null and is_instance_valid(lt) else "-"))
		lines.append("buffer: %s" % (player.buffered_action if player.buffered_action != "" else "-"))
	else:
		lines.append("(player belum ada)")
	_text.text = "\n".join(lines)

# ------------------------------------------------------------- timeline window
func _draw_timeline() -> void:
	if player == null or not is_instance_valid(player):
		return
	var spec := _state_spec()
	if spec.is_empty():
		return
	var duration: float = spec.duration
	var font := ThemeDB.fallback_font

	_timeline.draw_rect(Rect2(0, 0, BAR_W, BAR_H), Color(0, 0, 0, 0.6))
	for seg in spec.segments:
		var x0: float = seg.from / duration * BAR_W
		var x1: float = seg.to / duration * BAR_W
		_timeline.draw_rect(Rect2(x0, 2, x1 - x0, BAR_H - 4), seg.color)
		_timeline.draw_string(font, Vector2(x0 + 2, BAR_H + 14), seg.label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, seg.color)
	for mk in spec.markers:
		var x: float = mk.t / duration * BAR_W
		_timeline.draw_line(Vector2(x, 0), Vector2(x, BAR_H), mk.color, 2.0)
		_timeline.draw_string(font, Vector2(x + 2, BAR_H + 28), mk.label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, mk.color)
	# kursor state_time
	var cx: float = clampf(player.state_time / duration, 0.0, 1.0) * BAR_W
	_timeline.draw_line(Vector2(cx, -4), Vector2(cx, BAR_H + 4), Color(1, 1, 1), 2.0)
	_timeline.draw_string(font, Vector2(0, -8), "%s  %.0f ms / %.0f ms" %
		[player.state_name(), player.state_time * 1000.0, duration * 1000.0],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))

func _state_spec() -> Dictionary:
	match player.state_name():
		"ATTACK_1":
			return _attack_spec(0)
		"ATTACK_2":
			return _attack_spec(1)
		"ATTACK_3":
			return _attack_spec(2)
		"DODGE":
			var d := Balance.DODGE
			return {
				duration = d.duration,
				segments = [
					{ from = d.iframe_start, to = d.iframe_end, color = Color(0.3, 0.9, 1.0, 0.85), label = "i-frames" },
					{ from = d.iframe_start, to = d.perfect_window, color = Color(0.3, 1.0, 0.5, 0.9), label = "perfect" },
				],
				markers = [
					{ t = d.attack_out_at, color = Color(1.0, 0.8, 0.2), label = "attack-out" },
				],
			}
		"PARRY":
			var p := Balance.PARRY
			return {
				duration = p.duration,
				segments = [
					{ from = p.window_start, to = p.window_end, color = Color(1.0, 0.85, 0.25, 0.85), label = "window" },
					{ from = p.window_start, to = p.perfect_end, color = Color(0.3, 1.0, 0.5, 0.9), label = "perfect" },
				],
				markers = [],
			}
		"SKILL":
			var s := Balance.SKILL
			return {
				duration = s.duration,
				segments = [
					{ from = s.hit_start, to = s.hit_end, color = Color(1.0, 0.45, 0.2, 0.85), label = "hit" },
				],
				markers = [],
			}
	return {}

func _attack_spec(idx: int) -> Dictionary:
	var a: Dictionary = Balance.COMBO[idx]
	var markers := [
		{ t = a.cancel_at, color = Color(1.0, 0.8, 0.2), label = "cancel" },
	]
	if a.chain_at > 0.0:
		markers.append({ t = a.chain_at, color = Color(0.4, 1.0, 0.4), label = "chain" })
	return {
		duration = a.duration,
		segments = [
			{ from = a.hit_start, to = a.hit_end, color = Color(1.0, 0.3, 0.35, 0.85), label = "hitbox" },
		],
		markers = markers,
	}
