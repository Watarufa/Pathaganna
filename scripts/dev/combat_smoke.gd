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
## menangkap regresi diam-diam (mis. parry berhenti mengisi meter, Penyiar berhenti
## menembak, atau respawn tidak pernah terjadi).
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
var _respawn_wait := 0.0

var _seen := {}
var _enemy_seen := {}
var _events := {}
var _meter_peak := 0.0
var _ground_y := INF   # INF = belum pernah menyentuh lantai, jadi belum ada baseline
var _jump_peak := 0.0

const STEP_TIMEOUT := 6.0      # detik game-time; langkah yang menggantung = kegagalan
const RESPAWN_TIMEOUT := 12.0
## Sudut halaman zona 1: di dalam lantai (x −17…17, z −9…17) tapi lebih jauh dari
## radius deteksi terjauh (14 m) ke semua spawn musuh, supaya langkah yang menguji
## mekanik player tidak diganggu musuh yang kebetulan mendekat.
const QUIET_CORNER := Vector3(-13, 0, 13)

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
	CombatEvents.enemy_died.connect(func(_e: Node) -> void: _mark("enemy_died"))
	CombatEvents.player_respawned.connect(_on_respawned)
	CombatEvents.checkpoint_activated.connect(func(_id: String) -> void: _mark("checkpoint_set"))
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
		# Tab = kunci, lalu Tab lagi = LEPAS (bukan pindah target)
		{ act = "lockon", wait = 0.15 },
		{ act = "lockon", wait = 0.15 },
		# kombo A1 → A2 → A3 lewat input buffer
		{ act = "attack", wait = 0.20 },
		{ act = "attack", wait = 0.22 },
		{ act = "attack", wait = 0.60 },
		# dodge lalu serang keluar dari dodge
		{ act = "dodge", wait = 0.50 },
		{ act = "attack", wait = 0.50 },
		# heavy dari berdiri, lalu heavy sebagai finisher kombo (A1 → R)
		{ act = "heavy", idle_first = true, wait = 0.85 },
		{ act = "attack", idle_first = true, wait = 0.24 },
		{ act = "heavy", wait = 0.85 },
		# lompat, lalu serang di udara
		{ act = "jump", idle_first = true, wait = 0.22 },
		{ act = "attack", wait = 0.70 },
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

		# --- musuh sungguhan ---
		{ act = "heal", wait = 0.05 },
		# Kultis harus mengejar, menyerang (windup putih), lalu bisa dibunuh
		{ act = "approach_kultis", wait = 3.0 },
		{ act = "kill_kultis", wait = 0.4 },
		# Penyiar harus menjaga jarak dan melepas proyektil merah
		{ act = "approach_penyiar", wait = 4.0 },

		# --- checkpoint & death loop ---
		# aktifkan Ganna kedua, lalu mati: respawn harus di Ganna itu, bukan di awal
		{ act = "goto_ganna", wait = 0.5 },
		{ act = "interact", wait = 0.4 },
		{ act = "heal", wait = 0.05 },
		{ act = "", idle_first = true, at_state = "IDLE_RUN", at_time = 0.0, send = lethal },
	]

func _physics_process(delta: float) -> void:
	if _done:
		return

	# Pencatatan state dilakukan SEBELUM cabang apa pun: state DEAD baru muncul
	# beberapa frame setelah langkah terakhir, jadi kalau dicatat belakangan ia
	# terlewat dan tes gagal karena kesalahan harness, bukan kesalahan game.
	if player != null and is_instance_valid(player):
		_seen[player.state_name()] = true
		_track_enemies()
		_track_jump_height()
		# Tab harus mengunci lalu MELEPAS, bukan menyiklus ke target lain
		if player.lockon.target != null:
			_mark("lockon_acquired")
		elif _events.has("lockon_acquired"):
			_mark("lockon_released")

	# semua langkah selesai → tunggu respawn menyelesaikan death loop
	if _idx >= _steps.size() and _pending.is_empty():
		_respawn_wait += delta
		if _events.has("player_respawned"):
			_finish()
		elif _respawn_wait >= RESPAWN_TIMEOUT:
			_fail("respawn tidak terjadi setelah player mati")
		return

	if player == null or not is_instance_valid(player):
		return

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

	var step: Dictionary = _steps[_idx]
	if step.get("idle_first", false) and player.state_name() != "IDLE_RUN":
		_timeout -= delta
		if _timeout <= 0.0:
			_fail("langkah %d menunggu IDLE_RUN, macet di %s" % [_idx, player.state_name()])
		return

	_idx += 1
	_timeout = STEP_TIMEOUT
	_run(step)

## Ketinggian maksimum player di atas lantai terakhir yang dipijak. Ini bukan
## murni puncak lompat: player juga bisa naik ke atas musuh atau tumpukan CRT,
## dan justru skenario itulah yang harus tetap terjangkau musuh melee.
##
## Dipakai untuk assertion anti-air di _finish(): kalau nanti JUMP.speed
## dinaikkan tanpa menaikkan jangkauan hitbox musuh, lompat diam-diam berubah
## jadi tombol kebal dan tidak ada tes lain yang akan tahu.
func _track_jump_height() -> void:
	if player.is_on_floor():
		_ground_y = player.global_position.y
	elif _ground_y < INF:
		# hanya diukur setelah ada baseline lantai yang sah — kalau tidak, teleport
		# harness ikut terhitung dan angkanya menyesatkan
		_jump_peak = maxf(_jump_peak, player.global_position.y - _ground_y)

## Catat state tiap jenis musuh + apakah telegraph & proyektilnya benar-benar hidup.
func _track_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.has_method("state_name"):
			continue
		var key: String = e.get_script().resource_path.get_file().get_basename()
		_enemy_seen[key + ":" + e.state_name()] = true
		if e.screen != null and e.screen.is_filling():
			_mark("telegraph_fill_shown")
	for n in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(n):
			_mark("projectile_fired")

func _run(step: Dictionary) -> void:
	match step.get("act", ""):
		"approach":
			# Fase mekanik player dijalankan di sudut terpencil bersama dummy:
			# kalau dilakukan di dekat spawn Kultis, Kultis mengejar dan hit-nya
			# membuat player hitstun di tengah langkah — buffer hilang, tes rapuh.
			var dummy := _nearest_of("dummy")
			if dummy != null:
				dummy.global_position = QUIET_CORNER
				_place_player_near(dummy, 2.0)
				dummy._cooldown = 0.0  # lepas cooldown awal supaya telegraph pasti jalan
		"retreat":
			player.global_position = QUIET_CORNER + Vector3(0, 0.15, 3.0)
			player.velocity = Vector3.ZERO
		"goto_ganna":
			var g := _last_ganna()
			if g != null:
				player.global_position = g.global_position + Vector3(0, 0.15, 1.6)
				player.velocity = Vector3.ZERO
		"interact":
			_tap("interact")
		"approach_kultis":
			var k := _nearest_of("kultis")
			if k != null:
				_place_player_near(k, 3.0)
		"approach_penyiar":
			var s := _nearest_of("penyiar")
			if s != null:
				_place_player_near(s, 10.0)
		"kill_kultis":
			var k := _nearest_of("kultis")
			if k != null:
				var lethal := { damage = 999.0, parryable = true, knockback = 0.0, hitstop = 0.0 }
				k.hurtbox.receive(AttackData.make(lethal, player, "smoke"), player.hurtbox)
		"heal":
			player.health.heal_full()
		"attack", "dodge", "parry", "skill", "lockon", "heavy", "jump":
			_tap(step.act)
		"fill_meter":
			player._add_meter(Balance.SKILL.meter_max)
	_wait = step.get("wait", 0.0)
	if step.has("send"):
		_pending = { at_state = step.at_state, at_time = step.at_time, send = step.send }
		_wait = 0.0

func _place_player_near(node: Node3D, distance: float) -> void:
	player.global_position = node.global_position + Vector3(0, 0.15, distance)
	player.global_position.y = maxf(player.global_position.y, 0.15)
	player.rotation = Vector3.ZERO
	player.rotation.y = PI

func _tap(action: String) -> void:
	Input.action_press(action)
	get_tree().physics_frame.connect(Input.action_release.bind(action), CONNECT_ONE_SHOT)

func _send(data: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.hurtbox.receive(AttackData.make(data, _nearest_of("dummy"), "smoke"), player.hurtbox)

## Ganna paling dalam (z paling kecil) — checkpoint yang bukan titik mulai,
## supaya respawn benar-benar membuktikan checkpoint dipakai.
func _last_ganna() -> Node3D:
	var best: Node3D = null
	for g in get_tree().get_nodes_in_group("ganna"):
		if is_instance_valid(g) and (best == null or g.global_position.z < best.global_position.z):
			best = g
	return best

func _nearest_of(script_name: String) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if not e.get_script().resource_path.ends_with(script_name + ".gd"):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var d: float = player.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _mark(key: String) -> void:
	_events[key] = true

func _on_respawned() -> void:
	_mark("player_respawned")
	player = get_tree().get_first_node_in_group("player")
	# respawn harus mendarat di Ganna yang diaktifkan, bukan di mulut kuil
	var g := _last_ganna()
	if g != null and player != null and player.global_position.distance_to(g.global_position) <= 5.0:
		_mark("respawned_at_ganna")

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
	var enemy_states := _enemy_seen.keys()
	enemy_states.sort()
	print("[combat-smoke] player: ", ", ".join(states))
	print("[combat-smoke] musuh: ", ", ".join(enemy_states))

	var missing: Array[String] = []
	for s in Player.STATE_NAMES:
		if not _seen.has(s):
			missing.append("state:" + s)
	for key in ["player_hit_landed", "parry_perfect", "parry_normal", "enemy_staggered",
			"perfect_dodge", "player_damaged", "skill_used", "player_died", "style_scored",
			"telegraph_fill_shown", "lockon_acquired", "lockon_released",
			"enemy_died", "projectile_fired", "player_respawned",
			"checkpoint_set", "respawned_at_ganna"]:
		if not _events.has(key):
			missing.append(key)
	# musuh sungguhan harus benar-benar mengejar dan menyerang, bukan diam
	for key in ["kultis:CHASE", "kultis:WINDUP", "kultis:SWING",
			"penyiar:CHASE", "penyiar:WINDUP"]:
		if not _enemy_seen.has(key):
			missing.append("enemy_state:" + key)
	if _meter_peak <= 0.0:
		missing.append("meter_gain")

	# --- anti-air: player yang melompat harus tetap terjangkau musuh melee ---
	# Hurtbox player = capsule tinggi 1.65 di y=0.85 → sisi bawahnya y+0.025.
	# Hitbox melee musuh menjangkau sampai melee_hitbox_y + tinggi/2.
	var e: Dictionary = Balance.ENEMY_COMMON
	var melee_top: float = float(e.melee_hitbox_y) + float(e.melee_hitbox_height) * 0.5
	var hurt_bottom := _jump_peak + 0.025
	print("[combat-smoke] ketinggian maks di udara %.2f m; dasar hurtbox %.2f m; jangkauan melee %.2f m"
		% [_jump_peak, hurt_bottom, melee_top])
	if _jump_peak < 0.5:
		missing.append("jump_height(terlalu rendah: %.2f m — lompat mungkin tidak berfungsi)" % _jump_peak)
	elif hurt_bottom >= melee_top:
		missing.append("anti_air(ketinggian %.2f m melampaui jangkauan melee %.2f m — lompat jadi kebal)"
			% [_jump_peak, melee_top])

	if missing.is_empty():
		print("[combat-smoke] OK — semua state & efek terverifikasi (meter puncak %.0f)" % _meter_peak)
		get_tree().quit(0)
	else:
		printerr("[combat-smoke] GAGAL — tidak terjadi: ", ", ".join(missing))
		get_tree().quit(1)
