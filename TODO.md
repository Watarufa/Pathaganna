# TODO — PATHAGANNA V1

Protokol tiap milestone: (a) smoke test lolos, (b) TODO.md + CLAUDE.md diperbarui, (c) commit + push, (d) laporan ke user.

## Langkah 0 — Environment
- [x] Verifikasi Godot 4.4+ (4.7 stable, console exe di `%LOCALAPPDATA%\Programs\Godot\`)
- [x] Git repo + remote GitHub (clone user: Watarufa/Pathaganna) + commit awal + push
- [x] `.gitignore` (`.godot/`)
- [x] `CLAUDE.md`

## Langkah 1 — Dokumen
- [x] `GAME_DESIGN.md` (visi, kontrol, combat + tabel tuning, musuh, boss, level, UI, art, roadmap, changelog)
- [x] `TODO.md` (file ini)

## M0 — Scaffold
- [x] `project.godot`: InputMap lengkap, 1280×720, MSAA 2×, V-Sync, nama layer collision
- [x] Struktur folder scenes/ scripts/ resources/
- [x] 4 autoload terdaftar: `balance.gd`, `game_manager.gd`, `combat_events.gd`, `time_juice.gd`
- [x] `balance.gd` berisi seluruh tabel tuning awal
- [x] `main.tscn` boot ke menu placeholder (MULAI/KELUAR)
- [x] `README.md` (cara main, kontrol, syarat Godot 4.4+)
- [x] Smoke test: import + run 240 frame tanpa ERROR (exit 0, output bersih)

## M1 — Gerak & Kamera
- [x] Graybox datar (lantai + WorldEnvironment dasar + DirectionalLight)
- [x] Rig player primitif (pivot bernama) + pose_rig.gd (idle + run cycle sinus + bobbing)
- [x] Gerak WASD relatif kamera: akselerasi/deselerasi, rotasi menghadap arah gerak
- [x] Kamera third-person SpringArm3D: orbit mouse, pitch −50°..30°, jarak 4.5 m, pivot 1.8 m
- [x] Dummy statis ber-hurtbox + health
- [x] Lock-on Tab: kamera melunak ke target, strafe, auto-lepas (mati / >15 m)
      (Tab direvisi jadi kunci/lepas + ganti target lewat geser mouse — feedback feel gate)
- [x] Debug overlay F3: FPS, state, timeline window i-frame/parry/hitbox
- [x] Smoke test (menu + `--smoke` gameplay boot) — exit 0 bersih

## M2 — COMBAT CORE (FEEL GATE)
- [x] Input buffer global 0.15 s
- [x] Kombo 3-hit + chain + cancel dodge/parry (+ window lanjut kombo 0.5 s setelah dodge-cancel)
- [x] Dodge + i-frames + perfect dodge (slow-mo + buff +50% + meter)
- [x] Parry + perfect parry (stagger + meter + hitstop besar); merah menembus parry
- [x] Skill Q (meter penuh, AoE 3.5 m, knockdown)
- [x] time_juice: hitstop bertingkat + slow-mo (prioritas min-scale)
- [x] Camera shake trauma; weapon trail; hitspark; flash hit; hitstun player
- [x] Style meter dasar D→SSS + decay + penalti kena hit
- [x] HUD dasar: HP, meter kaset (versi awal), rank
- [x] Dummy menyerang berkala pola putih/merah; stagger saat perfect parry
- [x] Pause dasar (Esc lepas mouse, lanjut/keluar)
- [x] Harness `--combat-smoke`: verifikasi semua state + efek combat, exit 1 kalau gagal
- [x] Iterasi 1 feedback user: kombo/cancel/perfect dodge/hitstop/kamera → oke
- [x] Iterasi 1 feedback user: telegraph butuh **gerakan**, bukan cuma kedip warna
      → sistem `telegraph.gd` (angkat progresif → coil → pukul, kedip mengencang lalu solid,
        bentuk gerak beda putih/merah), dummy diberi senjata, overlay F3 tampilkan hitung mundur
- [x] Iterasi 2 feedback user: gerakan "seperti 1 fps" + terlalu cepat + ganti kedip dengan fill
      → visual pindah ke `_process` + `PoseRig.visual_time()` (akar stutter physics-vs-render),
        kurva windup jadi smoothstep, kedip diganti fill layar linear + denyut glow,
        windup dummy 0.9 s / 1.0 s
- [ ] **Menunggu user cek ulang keterbacaan telegraph sebelum lanjut M3**

## M3 — Musuh
- [x] `TelegraphScreen` diangkat jadi komponen bersama (dummy, Kultis, Penyiar, nanti boss)
- [x] enemy_base.gd (health, telegraph, stagger, knockdown, deteksi, mati, event style)
- [x] Kultis CRT: AI kejar/serang/recovery, tebasan putih + kombo 2-hit, layar wajah telegraph, mati padam
- [x] Penyiar: melayang, jaga jarak 8–12 m (strafe di jarak ideal), proyektil merah windup 0.8 s
- [x] Spawn per zona (5 musuh — di bawah batas 6 aktif)
- [x] Mati player → layar kalah "SINYAL HILANG" → auto-respawn + reset musuh
- [x] Harness diperluas: state Kultis/Penyiar, proyektil, musuh mati, respawn
- [x] Histeresis lock-on (break_range 18 > acquire 15) supaya lock tidak berkedip di batas

## M4 — Level & Loop
- [x] Kit props (`props.gd`): pilar berkabel, kabel akar, tumpukan CRT berkedip, antena, lilin, reruntuhan
- [x] 3 zona ter-dressing (Gerbang Kuil, Koridor Terkutuk, Arena melingkar)
- [x] 2 Ganna berfungsi (E, sigil ungu berputar, checkpoint, pulihkan HP)
- [x] Death loop utuh: respawn di Ganna terakhir + reset musuh, meter dipertahankan
- [x] HUD final (kaset styled, prompt kontekstual)
- [x] Pause menu (Esc): lanjut / keluar ke menu
- [x] `# P1: essence drop here` di titik kematian (player.gd `_on_died`)
- [x] Harness: aktivasi Ganna + respawn mendarat di checkpoint, bukan titik awal

## M5 — Boss & Layar
- [ ] Arena + gerbang menutup
- [ ] Fase 1 Berhala Pemancar (slam putih, sapuan merah, gelombang lantai, stagger + retak)
- [ ] Transisi invulnerable 2.5 s (slow-mo, ledakan CRT, nama baru)
- [ ] Fase 2 Sang Suara (string putih, dash merah, proyektil, backstep counter)
- [ ] HP bar boss; reset boss saat player mati
- [ ] Layar kalah final ("SINYAL HILANG") + menang ("SIARAN BERAKHIR" + waktu + rank)
- [ ] Menu utama final (latar Ganna TV statis)

## M6 — Polish & Verifikasi
- [ ] Art pass: fog, glow, emissive, kedip layar, partikel debu
- [ ] Performance pass: profil sampai ±60 fps stabil
- [ ] Bug sweep + README final
- [ ] **Verifikasi Definisi Selesai bersama user (user yang main)**
