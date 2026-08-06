## Harness smoke test combat (dev only, dijalankan dengan `-- --combat-smoke`).
## Menekan action sungguhan lewat Input dan mengirim serangan lewat Hurtbox.receive()
## — jalur yang sama persis dipakai gameplay — supaya setiap state FSM, window,
## dan efek juice benar-benar tereksekusi di headless. Tanpa ini, `--quit-after`
## hanya membuktikan game boot, bukan bahwa combat berjalan.
##
## Skenario dijadwalkan terhadap JAM FSM player (state + state_time), bukan nomor
## frame: di headless, hitstop diukur real-time sementara loop berlari secepat CPU,
## jadi jadwal berbasis frame akan meleset jauh.
##
## Keluar dengan exit code 1 jika ada perilaku yang hilang, sehingga smoke test
## menangkap regresi diam-diam (mis. parry berhenti mengisi meter).
extends Node

var player: Player = null

## Satu langkah: tekan `act`, lalu (opsional) kirim serangan `send` saat player
## berada di state `at_state` dengan state_time >= `at_time`.
## `idle_first` = tunggu player kembali ke IDLE_RUN sebelum menjalankan langkah.
var _steps: Array = []
var _idx := 0
var _wait := 0.0
var _pending := {}
var _timeout := 0.0
var _done := false

var _seen := {}
var _enemy_seen := {}
var _events := {}
var _meter_peak := 0.0

const STEP_TIMEOUT := 4.0   # detik game-time; langkah yang menggantung = kegagalan

func _ready() -> void:
	process_priority = 100
	_build_steps()
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.parried.connect(_on_parried)
	CombatEvents.perfect_dodge.connect(func(_p: Vector3) -> void: _mark("perfect_dodge"))
	CombatEvents.player_damaged.connect(func(_a: float, _s: Node) -> void: _mark("player_damaged"))
	CombatEvents.player_died.connect(func() -> void: _mark("player_died"))
	CombatEvents.skill_used.connect(func() -> void: _mark("skill_used"))
	CombatEvents.enemy_staggered.connect(func(_e: Node) -> void: _mark("enemy_staggered"))
	CombatEvents.style_changed.connect(func(s: float, _r: String, _c: Color) -> void:
		if s > 0.0:
			_mark("style_scored"))
	CombatEvents.meter_changed.connect(func(v: float, _m: float) -> void:
		_meter_peak = maxf(_meter_peak, v))

func _build_steps() -> void:
	var white: Dictionary = Balance.DUMMY.white
	var red: Dictionary = Balance.DUMMY.red
	var p: Dictionary = Balance.PARRY
	var d: Dictionary = Balance.DODGE
	var lethal: Dictionary = red.duplicate()
	lethal.damage = Balance.PLAYER.max_hp * 2.0

	_steps = [
		{ act = "approach", wait = 0.1 },
		# kombo A1 → A2 → A3 lewat input buffer
		{ act = "attack", wait = 0.20 },
		{ act = "attack", wait = 0.22 },
		{ act = "attack", wait = 0.60 },
		# dodge lalu serang keluar dari dodge
		{ act = "dodge", wait = 0.50 },
		{ act = "attack", wait = 0.50 },
		# perfect parry: kontak tepat setelah window dibuka
		{ act = "parry", idle_first = true,
		  at_state = "PARRY", at_time = p.window_start + 0.02, send = white },
		# parry normal: kontak setelah window perfect lewat
		{ act = "parry", idle_first = true,
		  at_state = "PARRY", at_time = p.perfect_end + 0.03, send = white },
		# perfect dodge: serangan merah mengenai saat i-frames awal
		{ act = "dodge", idle_first = true,
		  at_state = "DODGE", at_time = d.iframe_start + 0.02, send = red },
		# kena telak → hitstun
		{ act = "", idle_first = true, at_state = "IDLE_RUN", at_time = 0.0, send = red },
		{ act = "fill_meter", idle_first = true, wait = 0.05 },
		{ act = "skill", wait = 1.0 },
		{ act = "", idle_first = true, at_state = "IDLE_RUN", at_time = 0.0, send = lethal },
	]

func _physics_process(delta: float) -> void:
	if _done or player == null or not is_instance_valid(player):
		return
	_seen[player.state_name()] = true
	var dummy := _nearest_dummy()
	if dummy != null and dummy.has_method("state_name"):
		_enemy_seen[dummy.state_name()] = true

	# kirim serangan terjadwal begitu jam FSM player mencapai titik yang diminta
	if not _pending.is_empty():
		_timeout -= delta
		if player.state_name() == _pending.at_state and player.state_time >= _pending.at_time:
			_send(_pending.send)
			_pending = {}
			_wait = 0.25
		elif _timeout <= 0.0:
			_fail("langkah %d menggantung menunggu %s@%.2fs (state sekarang %s)"
				% [_idx, _pending.at_state, _pending.at_time, player.state_name()])
		return

	if _wait > 0.0:
		_wait -= delta
		return
	if _idx >= _steps.size():
		_finish()
		return

	var step: Dictionary = _steps[_idx]
	if step.get("idle_first", false) and player.state_name() != "IDLE_RUN":
		_timeout -= delta
		if _timeout <= 0.0:
			_fail("langkah %d menunggu IDLE_RUN, macet di %s" % [_idx, player.state_name()])
		return

	_idx += 1
	_timeout = STEP_TIMEOUT
	_run(step)

func _run(step: Dictionary) -> void:
	match step.get("act", ""):
		"approach":
			var dummy := _nearest_dummy()
			if dummy != null:
				player.global_position = dummy.global_position + Vector3(0, 0.15, 2.0)
				player.rotation = Vector3.ZERO
				player.rotation.y = PI
				# lepas cooldown awal supaya dummy pasti menyerang dalam skenario —
				# tanpa ini jalur telegraph (windup → swing) tidak pernah tereksekusi
				dummy._cooldown = 0.0
		"attack", "dodge", "parry", "skill":
			_tap(step.act)
		"fill_meter":
			player._add_meter(Balance.SKILL.meter_max)
	_wait = step.get("wait", 0.0)
	if step.has("send"):
		_pending = { at_state = step.at_state, at_time = step.at_time, send = step.send }
		_wait = 0.0

func _tap(action: String) -> void:
	Input.action_press(action)
	get_tree().physics_frame.connect(Input.action_release.bind(action), CONNECT_ONE_SHOT)

func _send(data: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.hurtbox.receive(AttackData.make(data, _nearest_dummy(), "smoke"), player.hurtbox)

func _nearest_dummy() -> Node3D:
	var list := get_tree().get_nodes_in_group("enemies")
	return list[0] if not list.is_empty() else null

func _mark(key: String) -> void:
	_events[key] = true

func _on_hit_landed(attacker: Node, _t: Node, _a: AttackData, _p: Vector3) -> void:
	if attacker != null and is_instance_valid(attacker) and attacker.is_in_group("player"):
		_mark("player_hit_landed")

func _on_parried(perfect: bool, _pos: Vector3) -> void:
	_mark("parry_perfect" if perfect else "parry_normal")

func _fail(reason: String) -> void:
	_done = true
	printerr("[combat-smoke] GAGAL — ", reason)
	get_tree().quit(1)

func _finish() -> void:
	_done = true
	var states := _seen.keys()
	states.sort()
	print("[combat-smoke] state: ", ", ".join(states))

	var missing: Array[String] = []
	for s in Player.STATE_NAMES:
		if not _seen.has(s):
			missing.append("state:" + s)
	for key in ["player_hit_landed", "parry_perfect", "parry_normal", "enemy_staggered",
			"perfect_dodge", "player_damaged", "skill_used", "player_died", "style_scored"]:
		if not _events.has(key):
			missing.append(key)
	for s in ["WINDUP", "SWING"]:
		if not _enemy_seen.has(s):
			missing.append("enemy:" + s)
	if _meter_peak <= 0.0:
		missing.append("meter_gain")

	if missing.is_empty():
		print("[combat-smoke] OK — semua state & efek combat terverifikasi (meter puncak %.0f)" % _meter_peak)
		get_tree().quit(0)
	else:
		printerr("[combat-smoke] GAGAL — tidak terjadi: ", ", ".join(missing))
		get_tree().quit(1)
