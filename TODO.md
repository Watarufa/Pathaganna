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
- [ ] `project.godot`: InputMap lengkap, 1280×720, MSAA 2×, V-Sync, nama layer collision
- [ ] Struktur folder scenes/ scripts/ resources/
- [ ] 4 autoload terdaftar: `balance.gd`, `game_manager.gd`, `combat_events.gd`, `time_juice.gd`
- [ ] `balance.gd` berisi seluruh tabel tuning awal
- [ ] `main.tscn` boot ke menu placeholder (MULAI/KELUAR)
- [ ] `README.md` (cara main, kontrol, syarat Godot 4.4+)
- [ ] Smoke test: import + run 240 frame tanpa ERROR

## M1 — Gerak & Kamera
- [ ] Graybox datar (lantai + WorldEnvironment dasar + DirectionalLight)
- [ ] Rig player primitif (pivot bernama) + pose_rig.gd (idle + run cycle sinus + bobbing)
- [ ] Gerak WASD relatif kamera: akselerasi/deselerasi, rotasi menghadap arah gerak
- [ ] Kamera third-person SpringArm3D: orbit mouse, pitch −50°..30°, jarak 4.5 m, pivot 1.8 m
- [ ] Dummy statis ber-hurtbox + health
- [ ] Lock-on Tab: kamera melunak ke target, strafe, cycle target, auto-lepas (mati / >15 m)
- [ ] Debug overlay F3: FPS, state, timeline window i-frame/parry/hitbox
- [ ] Smoke test (menu + `--smoke` gameplay boot)

## M2 — COMBAT CORE (FEEL GATE)
- [ ] Input buffer global 0.15 s
- [ ] Kombo 3-hit + chain + cancel dodge/parry
- [ ] Dodge + i-frames + perfect dodge (slow-mo + buff +50% + meter)
- [ ] Parry + perfect parry (stagger + meter + hitstop besar); merah menembus parry
- [ ] Skill Q (meter penuh, AoE 3.5 m, knockdown)
- [ ] time_juice: hitstop bertingkat + slow-mo (prioritas min-scale)
- [ ] Camera shake trauma; weapon trail; hitspark; flash hit; hitstun player
- [ ] Style meter dasar D→SSS + decay + penalti kena hit
- [ ] HUD dasar: HP, meter kaset (versi awal), rank
- [ ] Dummy menyerang berkala pola putih/merah; stagger saat perfect parry
- [ ] Pause dasar (Esc lepas mouse, lanjut/keluar)
- [ ] **BERHENTI: instruksi main + checklist rasa ke user; iterasi balance.gd sampai user puas**

## M3 — Musuh
- [ ] enemy_base.gd (health, telegraph, stagger, deteksi, mati, event style)
- [ ] Kultis CRT: AI kejar/serang/recovery, tebasan putih + kombo 2-hit, layar wajah telegraph, mati padam
- [ ] Penyiar: melayang, jaga jarak 8–12 m, proyektil merah windup 0.8 s
- [ ] Spawn per zona (batas 6 aktif)
- [ ] Mati player → layar kalah sementara → respawn

## M4 — Level & Loop
- [ ] 3 zona ter-dressing dasar (Gerbang Kuil, Koridor Terkutuk, Arena)
- [ ] 2 Ganna berfungsi (E, sigil ungu, checkpoint)
- [ ] Death loop utuh: respawn player + musuh, meter dipertahankan
- [ ] HUD final (kaset styled, prompt kontekstual)
- [ ] Pause menu final
- [ ] `# P1: essence drop here` di titik kematian

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
