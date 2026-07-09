## Hitstop & slow-mo global via Engine.time_scale.
## Efek disimpan sebagai daftar {scale, until_ms}; scale efektif = min(scale) semua
## efek aktif (hitstop dalam slow-mo tetap "menggigit", lalu slow-mo lanjut).
## Durasi dihitung real-time (Time.get_ticks_msec) supaya kebal terhadap time_scale.
extends Node

var _effects: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func hitstop(duration: float, scale: float = -1.0) -> void:
	if scale < 0.0:
		scale = Balance.JUICE.hitstop_scale
	_push(scale, duration)

func slowmo(scale: float, duration: float) -> void:
	_push(scale, duration)

func clear() -> void:
	_effects.clear()
	Engine.time_scale = 1.0

func _push(scale: float, duration: float) -> void:
	_effects.append({ scale = scale, until = Time.get_ticks_msec() + int(duration * 1000.0) })
	_apply()

func _process(_delta: float) -> void:
	if _effects.is_empty():
		return
	var now := Time.get_ticks_msec()
	_effects = _effects.filter(func(e): return e.until > now)
	_apply()

func _apply() -> void:
	var s := 1.0
	for e in _effects:
		s = minf(s, e.scale)
	Engine.time_scale = s
