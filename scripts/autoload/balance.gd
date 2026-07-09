## PATHAGANNA — SEMUA angka tuning gameplay hidup di file ini.
## Aturan mengikat: tidak ada timing/damage/HP/kecepatan yang di-hardcode di file lain.
## Nilai awal dari GAME_DESIGN.md; iterasi di feel gate M2 cukup mengubah file ini.
extends Node

# ------------------------------------------------------------------ input
const INPUT := {
	buffer_time = 0.15,          # s — buffer global semua aksi combat
}

# ------------------------------------------------------------------ player
const PLAYER := {
	max_hp = 100.0,
	move_speed = 6.5,            # m/s
	accel = 45.0,                # m/s^2 menuju kecepatan target
	decel = 38.0,
	turn_speed = 14.0,           # kecepatan lerp menghadap arah gerak
	gravity = 24.0,
	hitstun_time = 0.3,
	hitstun_knockback = 4.0,     # m/s impuls menjauh dari sumber
	dead_wait = 1.2,             # s pose mati sebelum layar kalah
	spawn_invuln = 1.0,          # s kebal setelah respawn
}

# Kombo 3-hit. Semua window dihitung dari state_time (JAM FSM, bukan animasi).
# chain_at = kapan serangan lanjutan (buffered) boleh mulai; -1 = tidak bisa chain.
const COMBO := [
	{ name = "A1", duration = 0.36, hit_start = 0.12, hit_end = 0.22, damage = 10.0,
	  cancel_at = 0.18, chain_at = 0.22, knockback = 2.0, hitstop = 0.05, lunge = 2.5 },
	{ name = "A2", duration = 0.38, hit_start = 0.12, hit_end = 0.24, damage = 12.0,
	  cancel_at = 0.18, chain_at = 0.24, knockback = 2.0, hitstop = 0.05, lunge = 2.5 },
	{ name = "A3", duration = 0.55, hit_start = 0.20, hit_end = 0.34, damage = 18.0,
	  cancel_at = 0.30, chain_at = -1.0, knockback = 7.0, hitstop = 0.09, lunge = 3.5 },
]
const COMBO_RESET_TIME := 0.5    # s setelah serangan selesai → kombo kembali ke A1

# Dimensi hitbox serangan ringan player (box di depan dada, generous demi feel)
const COMBO_HITBOX := {
	width = 2.0, height = 1.6, length = 2.2,   # m
	forward = 1.3,                              # offset pusat box dari player
}

const DODGE := {
	duration = 0.45,
	speed = 12.0,                # m/s dorongan ke arah input (mundur jika netral)
	iframe_start = 0.04,
	iframe_end = 0.32,
	attack_out_at = 0.32,        # serangan boleh keluar dari dodge mulai sini
	perfect_window = 0.16,       # kontak saat i-frames dan state_time <= ini → perfect
	slowmo_scale = 0.3,
	slowmo_time = 0.35,          # s real-time
	buff_time = 1.5,             # s window bonus damage setelah perfect dodge
	buff_mult = 1.5,             # +50% damage
	meter_gain = 10.0,
}

const PARRY := {
	duration = 0.35,
	window_start = 0.02,
	window_end = 0.20,
	perfect_end = 0.10,          # kontak window_start..perfect_end = perfect parry
	meter_normal = 10.0,
	meter_perfect = 30.0,
	hitstop_normal = 0.05,
	hitstop_perfect = 0.12,
	recover_after_contact = 0.12,# s setelah kontak sebelum parry bisa cancel ke serangan
}

const SKILL := {
	meter_max = 100.0,
	duration = 0.8,
	hit_start = 0.25,
	hit_end = 0.45,
	radius = 3.5,
	damage = 45.0,
	knockdown_time = 1.2,        # musuh biasa knockdown
	hitstop = 0.09,
}

# ------------------------------------------------------------------ game feel
const JUICE := {
	hitstop_scale = 0.05,        # Engine.time_scale saat hitstop
	hitstop_light = 0.05,        # s real-time
	hitstop_finisher = 0.09,
	hitstop_perfect_parry = 0.12,
	shake_hit_dealt = 0.2,       # trauma (0..1)
	shake_hit_taken = 0.35,
	shake_skill = 0.5,
	trauma_decay = 2.2,          # pengurangan trauma per detik
	shake_max_offset = 0.28,     # m offset kamera pada trauma penuh
	shake_max_roll = 0.05,       # rad
	trail_frames = 12,           # panjang ribbon weapon trail
	flash_time = 0.12,           # s overlay putih saat terkena hit
}

const STYLE := {
	max_score = 1500.0,
	hit_gain = 40.0,
	variety_bonus = 20.0,        # jenis serangan beda dari hit sebelumnya
	defense_gain = 80.0,         # perfect dodge / parry
	skill_gain = 120.0,
	decay_per_sec = 25.0,
	decay_delay = 2.0,           # s tanpa aksi ofensif sebelum decay
	hit_penalty_frac = 0.25,     # terkena hit: skor -25%
	ranks = [                    # [huruf, ambang, warna]
		["D", 0.0, Color(0.55, 0.55, 0.6)],
		["C", 150.0, Color(0.45, 0.7, 0.9)],
		["B", 350.0, Color(0.4, 0.85, 0.7)],
		["A", 600.0, Color(0.65, 0.95, 0.4)],
		["S", 850.0, Color(1.0, 0.85, 0.3)],
		["SS", 1100.0, Color(1.0, 0.55, 0.2)],
		["SSS", 1400.0, Color(1.0, 0.25, 0.45)],
	],
}

# ------------------------------------------------------------------ kamera & lock-on
const CAMERA := {
	distance = 4.5,              # m panjang SpringArm
	pivot_height = 1.8,
	pitch_min = -50.0,           # derajat
	pitch_max = 30.0,
	mouse_sens = 0.0025,         # rad per pixel
	follow_lerp = 18.0,          # pivot mengejar posisi player
	lockon_lerp = 6.0,           # kamera melunak ke arah target
	fov = 68.0,
}

const LOCKON := {
	acquire_range = 15.0,
	break_range = 15.0,
}

# ------------------------------------------------------------------ musuh
const ENEMY_COMMON := {
	max_active = 6,              # batas performa musuh aktif bersamaan
	stagger_time = 1.4,          # perfect parry vs musuh biasa
	die_free_delay = 1.6,        # s sebelum jasad dibersihkan
}

# Dummy latihan M1/M2 (tidak pernah mati; HP reset otomatis)
const DUMMY := {
	hp = 80.0,
	attack_range = 3.4,          # mulai menyerang jika player <= jarak ini
	interval = 2.6,              # jeda antar serangan
	red_chance = 0.35,
	white = { windup = 0.6, swing = 0.3, hit_start = 0.05, hit_end = 0.18, damage = 12.0,
	          parryable = true, knockback = 3.0, hitstop = 0.05, range = 2.8 },
	red   = { windup = 0.7, swing = 0.3, hit_start = 0.05, hit_end = 0.18, damage = 10.0,
	          parryable = false, knockback = 4.0, hitstop = 0.05, range = 2.8 },
}

const KULTIS := {
	hp = 45.0,
	speed = 4.5,
	detect_radius = 12.0,
	attack_range = 2.0,
	recovery = 0.8,              # jendela hukuman setelah menyerang
	combo2_chance = 0.35,        # peluang tebasan jadi kombo 2-hit (dua-duanya putih)
	combo2_gap = 0.4,            # windup hit kedua
	slash = { windup = 0.6, swing = 0.25, hit_start = 0.04, hit_end = 0.16, damage = 12.0,
	          parryable = true, knockback = 3.0, hitstop = 0.05, range = 2.4 },
}

const PENYIAR := {
	hp = 30.0,
	speed = 3.8,
	hover_height = 1.6,
	keep_min = 8.0,              # menjauh jika player lebih dekat dari ini
	keep_max = 12.0,
	detect_radius = 14.0,
	windup = 0.8,                # telegraph merah
	cooldown = 2.4,              # jeda antar tembakan
	proj = { speed = 10.0, damage = 10.0, parryable = false, radius = 0.35, life = 4.0 },
}

# ------------------------------------------------------------------ boss
const BOSS_P1 := {
	display_name = "BERHALA PEMANCAR",
	hp = 320.0,
	turn_speed = 1.6,            # rad/s — berputar lambat
	stagger_time = 1.6,
	recovery = 1.0,
	attack_cooldown = 1.4,
	reposition_cooldown = 7.0,
	slam  = { windup = 0.9, swing = 0.35, hit_start = 0.05, hit_end = 0.22, damage = 20.0,
	          parryable = true, knockback = 5.0, hitstop = 0.06, range = 3.4 },
	sweep = { windup = 0.7, swing = 0.55, hit_start = 0.08, hit_end = 0.45, damage = 25.0,
	          parryable = false, knockback = 7.0, hitstop = 0.06, range = 4.2 },
	wave  = { windup = 0.6, damage = 15.0, parryable = false, speed = 7.0,
	          ring_width = 0.9, max_radius = 13.0 },
}

const BOSS_TRANSITION := {
	duration = 2.5,              # boss invulnerable, player tidak bisa memberi damage
	slowmo_scale = 0.35,
	slowmo_time = 1.0,
}

const BOSS_P2 := {
	display_name = "SANG SUARA",
	hp = 360.0,
	speed = 6.0,
	stagger_time = 1.6,
	recovery = 0.9,
	attack_cooldown = 1.1,
	backstep_chance = 0.35,
	string3 = { windup = 0.5, gap = 0.32, swing = 0.22, hit_start = 0.03, hit_end = 0.15,
	            damages = [12.0, 12.0, 16.0], parryable = true, knockback = 2.5,
	            hitstop = 0.05, range = 2.4 },
	dash    = { windup = 0.6, speed = 18.0, max_time = 0.5, damage = 22.0, parryable = false,
	            knockback = 6.0, hitstop = 0.06, range = 1.6 },
	wave    = { windup = 0.5, damage = 12.0, parryable = false, speed = 11.0,
	            radius = 0.4, life = 3.0 },
	backstep = { speed = 10.0, time = 0.25 },
	counter  = { windup = 0.35, swing = 0.2, hit_start = 0.02, hit_end = 0.12, damage = 14.0,
	             parryable = true, knockback = 3.0, hitstop = 0.05, range = 2.4 },
}

# ------------------------------------------------------------------ level & layar
const LEVEL := {
	ganna_range = 2.5,           # jarak interaksi E
	death_screen_time = 2.5,     # auto-respawn dari layar kalah
	fog_distance = 30.0,
}
