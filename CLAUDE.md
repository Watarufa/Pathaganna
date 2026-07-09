# CLAUDE.md — catatan kerja PATHAGANNA

## Tooling

- **Godot console exe** (`GODOT`):
  `C:\Users\legio\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe` (4.7.stable)
- **Menjalankan game:** buka Godot → Import → `project.godot` → F5. CLI: `& $GODOT --path .`
- **Smoke test (wajib lolos per milestone):**
  1. `& $GODOT --headless --import --path .` — sekali di awal & tiap ada resource baru
  2. `& $GODOT --headless --quit-after 240 --path .` — boot menu 240 frame
  3. `& $GODOT --headless --quit-after 240 --path . -- --smoke` — auto-masuk gameplay (main.gd membaca user arg `--smoke`)
  Milestone **gagal** jika output mengandung `SCRIPT ERROR` atau `ERROR:` (kecuali warning benign di daftar bawah).

## Arsitektur singkat

- Alur scene: `scenes/main.tscn` (main.gd) → menu / gameplay / kalah / menang.
- Autoload (urutan): `Balance` (semua angka tuning — SATU-SATUNYA tempat angka gameplay), `CombatEvents` (signal bus), `TimeJuice` (hitstop/slow-mo, PROCESS_MODE_ALWAYS, timer real-time), `GameManager` (state game, checkpoint Ganna, respawn).
- FSM eksplisit dengan `state_time` sendiri; window (i-frame/parry/hitbox/cancel) dihitung dari `state_time` + `Balance`, TIDAK PERNAH dari animasi. `pose_rig.gd` murni visual.
- Hitbox/Hurtbox = Area3D + `AttackData`; komunikasi lintas sistem lewat `CombatEvents`; UI tidak mem-polling player.
- Musuh extend `scripts/enemies/enemy_base.gd`. Karakter = primitif di bawah pivot bernama (Hips/Torso/Head/ArmL/ArmR/LegL/LegR/WeaponPivot).
- Detail desain + tabel tuning: `GAME_DESIGN.md`. Keputusan sepihak dicatat di bagian Changelog-nya.

## Tuning

Semua angka di `scripts/autoload/balance.gd`, dikelompokkan per sistem (PLAYER/COMBO/DODGE/PARRY/SKILL/JUICE/STYLE/musuh/boss). Feel gate M2: iterasi nilai di file itu saja.

## Aturan commit (ketat)

- Pesan natural gaya developer manusia: subjek singkat, imperatif, spesifik (`add player state machine and dodge i-frames`).
- Commit per unit kerja logis; beberapa commit kecil per milestone; **push minimal tiap akhir milestone**.
- **DILARANG atribusi AI dalam bentuk apa pun**: tanpa "Generated with Claude Code", tanpa `Co-Authored-By: Claude`, tanpa emoji, tanpa menyebut AI di pesan/deskripsi.
- Author = konfigurasi git user (Watarufa). File `*.uid` ikut di-commit (normal Godot 4.4+).

## Warning benign yang diketahui

- `warning: in the working copy of '...', LF will be replaced by CRLF` — perilaku git di Windows, bukan error Godot.
- `[main] menu` / `[main] gameplay start` — log boot yang disengaja dari main.gd, bukan error.
- (belum ada warning Godot yang tercatat)

## Status milestone

Lihat `TODO.md`. M2 = feel gate: berhenti, user main, iterasi `balance.gd` sampai user menyatakan enak. M6 = verifikasi Definisi Selesai oleh user (bukan dicentang sendiri).
