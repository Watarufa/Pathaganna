# PATHAGANNA — Game Design Document (V1)

> Sumber kebenaran desain. Semua perubahan desain dicatat di **Changelog** (bagian 14).
> Nilai tuning di dokumen ini adalah *nilai awal*; nilai berjalan yang sebenarnya hidup di
> `scripts/autoload/balance.gd` dan boleh bergeser saat feel gate M2 (perubahan besar dicatat di Changelog).

---

## 1. Ringkasan

- **Genre:** 3D stylish action / soulslike singkat (10–15 menit per run).
- **Engine:** Godot 4.4+ (dev di 4.7 stable), GDScript, tanpa asset eksternal — semua dari primitif + kode + partikel.
- **Struktur:** 3 zona tersambung → boss 2 fase → layar menang.
- **Loop inti:** serang (kombo 3-hit) — parry (flash putih) — dodge (flash merah) — isi meter dari parry/perfect dodge — ledakkan skill.

## 2. Visi & Pillars (tidak boleh dilanggar)

1. **Combat feel nomor satu.** Responsif ala Devil May Cry: input buffer, animation cancel, hitstop, slow-motion, camera shake, weapon trail. Jika harus memilih, korbankan apa pun kecuali ini.
2. **Fair ala soulslike.** Setiap serangan musuh punya telegraph jelas: **flash putih = bisa diparry; flash merah = wajib dodge.** Tanpa pengecualian.
3. **Modular untuk masa depan.** Fitur P1/P2 (bagian 12) harus bisa ditambahkan tanpa rombak besar.
4. **Tanpa asset eksternal.** Estetika stylized gelap ber-aksen neon — bukan realisme, bukan filter retro PS1/pixelated.

## 3. Tema

Kultus kuno pemuja **"Siaran"** — sinyal dari sesuatu di seberang. Kuil batu dengan kabel menjalar seperti akar, tumpukan TV CRT menyala statis, antena berkarat. Struktur, outfit, dan senjata bergaya retro; musuh campuran teknologi retro dan supranatural.

- **Ganna** = altar checkpoint: TV tua di atas altar batu berlilin; diaktifkan dengan E → layar statis berubah jadi sigil ungu.
- Player: pria berjaket panjang gaya retro, senjata **bilah antena** tipis bertepi emissive ungu.
- Boss: **Berhala Pemancar** (menara CRT) → bentuk asli **Sang Suara** (perempuan retro, bilah antena neon merah — cermin player).

## 4. Kontrol (InputMap actions)

| Aksi | Input | Action name |
|---|---|---|
| Gerak | WASD | `move_forward/back/left/right` |
| Kamera | Mouse | (mouse motion, captured) |
| Serang (kombo 3-hit) | Klik kiri | `attack` |
| Parry | Klik kanan | `parry` |
| Dodge roll | Shift **atau** Space | `dodge` |
| Skill | Q | `skill` |
| Lock-on / ganti target | Tab | `lockon` |
| Interaksi (Ganna) | E | `interact` |
| Pause | Esc | `pause` |
| Debug overlay | F3 | `debug_overlay` |

Mouse captured saat gameplay, dilepas saat menu/pause. Semua input lewat InputMap → gamepad (P2) tinggal menambah mapping.

## 5. Arsitektur (aturan mengikat)

1. **Semua angka gameplay hidup di `scripts/autoload/balance.gd`** (const/dictionary per sistem). Tidak ada timing/damage/HP/kecepatan hardcoded di tempat lain.
2. **Timing gameplay tidak pernah dibaca dari sistem animasi.** Setiap FSM memegang jam sendiri (`state_time`); window i-frame, parry, cancel point, dan frame aktif hitbox dihitung dari jam itu + `balance.gd`. Animasi hanya lapisan visual yang mengikuti state. (Port visual ke model impor di masa depan = tanpa retuning combat.)
3. **FSM eksplisit**: enum state + `match` di `_physics_process`, satu fungsi per state. State player: `IDLE_RUN, ATTACK_1, ATTACK_2, ATTACK_3, DODGE, PARRY, SKILL, HITSTUN, DEAD`.
4. **Hitbox/Hurtbox = Area3D.** Hitbox membawa `AttackData` (damage, parryable, knockback, hitstop, style_gain). Hitbox hanya monitoring selama frame window state-nya. Collision layer memisahkan tim.
5. **Komunikasi lintas sistem lewat signal bus `combat_events`** (autoload). HUD/style/VFX mendengarkan event; tidak ada UI yang mem-polling player.
6. **Musuh baru = extend `enemy_base.gd`** + moveset/data sendiri. Zona level = child node dalam `area.tscn`.
7. **Karakter = MeshInstance3D primitif** di bawah pivot Node3D bernama (`Hips, Torso, Head, ArmL, ArmR, LegL, LegR, WeaponPivot`) pada CharacterBody3D.
8. **Animasi prosedural via `pose_rig.gd`**: pose = dictionary rotasi/posisi pivot, interpolasi antar-pose per state; lari = ayunan sinus + bobbing; ayunan serangan = kurva rotasi `WeaponPivot` disinkronkan ke `state_time / durasi_state`. AnimationPlayer dilarang untuk logika gameplay (boleh untuk flourish non-gameplay: aktivasi Ganna, transisi fase boss).

### Collision layers

| # | Nama | Isi |
|---|---|---|
| 1 | world | geometri statis |
| 2 | player_body | CharacterBody3D player |
| 3 | enemy_body | CharacterBody3D musuh |
| 4 | player_hurt | hurtbox player (Area3D) |
| 5 | enemy_hurt | hurtbox musuh |
| 6 | player_attack | hitbox player → mask 5 |
| 7 | enemy_attack | hitbox musuh (+proyektil) → mask 4 |

### Struktur folder

```
scenes/    main.tscn · ui/ · player/ · enemies/ · level/ · fx/
scripts/   autoload/ (balance, game_manager, combat_events, time_juice)
           player/ · enemies/ · systems/ · ui/ · fx/
resources/materials/   # palet material .tres terpusat
```

## 6. Combat spec + tabel tuning awal

**Player:** HP 100; kecepatan 6.5 m/s, akselerasi/deselerasi singkat; menghadap arah gerak. Lock-on: menghadap target, gerak jadi strafe.

### Kombo ringan 3-hit (klik kiri)

| Serangan | Durasi | Hitbox aktif | Damage | Cancel dodge/parry mulai | Chain serangan berikutnya mulai |
|---|---|---|---|---|---|
| A1 | 0.36 s | 0.12–0.22 s | 10 | 0.18 s | 0.22 s (= akhir hitbox) |
| A2 | 0.38 s | 0.12–0.24 s | 12 | 0.18 s | 0.24 s |
| A3 finisher | 0.55 s | 0.20–0.34 s | 18 + knockback | 0.30 s | — (kombo selesai) |

- **Input buffer global 0.15 s**: input terlalu awal disimpan, dieksekusi begitu window terbuka (serangan lanjutan, dodge, parry, skill). Diimplementasikan sejak awal M2.
- Dodge bisa meng-cancel serangan kapan pun setelah cancel point — identitas DMC.
- Kombo reset jika idle > 0.5 s setelah serangan selesai.

### Dodge roll

| Parameter | Nilai |
|---|---|
| Durasi | 0.45 s |
| Dorongan | 12 m/s ke arah input (mundur jika netral) |
| i-frames | 0.04–0.32 s |
| **Perfect dodge** | kontak serangan saat i-frames **dan** waktu dodge ≤ 0.16 s |
| Reward perfect | slow-mo 0.3× / 0.35 s + serangan berikutnya ≤ 1.5 s +50% damage + meter +10 |

Implementasi: saat i-frames hurtbox tetap mendeteksi overlap — damage diabaikan, event tetap dikirim ke `combat_events`.

### Parry (klik kanan)

| Parameter | Nilai |
|---|---|
| Durasi state | 0.35 s |
| Window aktif | 0.02–0.20 s |
| **Perfect parry** | kontak di 0.02–0.10 s → musuh **stagger 1.4 s**, meter +30, hitstop 0.12 s, flash + partikel |
| Parry normal | kontak di 0.10–0.20 s → damage 0, meter +10, hitstop kecil |
| Serangan merah | menembus parry → damage penuh (mengajarkan "merah = dodge") |

### Skill (Q)

Butuh meter penuh (100). Tebasan berat area radius 3.5 m, damage 45, knockdown musuh biasa, durasi state 0.8 s (hitbox aktif 0.25–0.45 s). Meter **hanya** terisi dari parry dan perfect dodge.

### Game feel (wajib sejak M2)

| Efek | Nilai |
|---|---|
| Hitstop | ringan 0.05 s / finisher 0.09 s / perfect parry 0.12 s — `Engine.time_scale ≈ 0.05` via `time_juice` (PROCESS_MODE_ALWAYS, timer real-time) |
| Slow-mo perfect dodge | 0.3× selama 0.35 s, lewat manager sama (efek aktif = min scale; expired dibuang) |
| Camera shake | trauma 0–1: memukul 0.2 / terpukul 0.35 / skill 0.5; decay cepat; offset noise |
| Weapon trail | ribbon ImmediateMesh ±12 frame posisi bilah, emissive, memudar |
| Hitspark | GPUParticles3D one-shot emissive di titik kontak, auto-free |
| Flash hit | material overlay putih singkat pada karakter yang terkena |

### Style meter (D→SSS)

Skor 0–1500. +40 per hit (+20 jika jenis serangan beda dari hit sebelumnya), +80 perfect dodge / parry, +120 skill. Decay 25/detik setelah 2 s tanpa aksi ofensif. Terkena hit: skor −25%.

| Rank | D | C | B | A | S | SS | SSS |
|---|---|---|---|---|---|---|---|
| Ambang | 0 | 150 | 350 | 600 | 850 | 1100 | 1400 |

Huruf besar berwarna (warna naik per rank) kanan atas.

### Damage diterima player

Hitstun 0.3 s + knockback kecil. Tidak berlaku saat `SKILL` (super armor; damage tetap masuk).

## 7. Musuh

### Kultis CRT — melee, mayoritas parryable

Jubah kultus gelap + kepala monitor CRT; **layar wajah = telegraph diegetik** (flash putih/merah).

| Parameter | Nilai |
|---|---|
| HP / kecepatan | 45 / 4.5 m/s |
| AI | idle → deteksi (radius 12 m) → kejar → serang saat ≤ 2 m → recovery 0.8 s (jendela hukuman) |
| Tebasan tunggal | windup 0.6 s, **putih**, damage 12 |
| Kombo 2-hit (sesekali) | kedua hit **putih** |
| Perfect parry | → stagger 1.4 s |
| Mati | burst partikel + layar wajah padam |

### Penyiar — ranged, memaksa gerak

Entitas melayang berbadan radio tua + antena.

| Parameter | Nilai |
|---|---|
| HP | 30 |
| Posisi | jaga jarak 8–12 m, menjauh jika didekati |
| Proyektil sinyal | windup 0.8 s, **merah** (unparryable), 10 m/s, damage 10 |

**Batas performa: maksimal 6 musuh aktif bersamaan.**

## 8. Level, Ganna, death loop

`area.tscn` = 3 zona tersambung (graybox → dressing M4/M6):

1. **Gerbang Kuil** — halaman reruntuhan; **Ganna A** (titik mulai); 2 Kultis; ruang lapang untuk belajar.
2. **Koridor Terkutuk** — lorong pilar, kabel akar, tumpukan CRT statis; 3 Kultis + 2 Penyiar; **Ganna B** di ujung sebelum arena.
3. **Arena Boss** — ruang siaran ritual melingkar; gerbang menutup saat masuk.

**Ganna:** E → layar statis jadi sigil ungu + efek aktivasi → checkpoint tersimpan di `game_manager`.

**Mati** → layar kalah → respawn di Ganna terakhir: HP penuh, **meter skill dipertahankan**, musuh biasa respawn semua, boss reset ke fase 1. Titik kematian player diberi komentar kode `# P1: essence drop here` (hook, tidak diimplementasikan).

## 9. Boss 2 fase (HP bar atas layar)

### Fase 1 — "Berhala Pemancar" (uji parry) — HP 320

Menara CRT bertumpuk berlengan kabel; gerak lambat berputar + reposisi sesekali.

| Serangan | Windup | Warna | Damage | Respons benar |
|---|---|---|---|---|
| Slam berat | 0.9 s | **putih** | 20 | parry (ritme utama) |
| Sapuan lengan kabel | 0.7 s | **merah** | 25 | dodge |
| Gelombang statis lantai (cincin radial) | — | **merah** | 15 | i-frames dodge roll |

Perfect parry → stagger 1.6 s; tiap stagger sebagian layar tubuh retak (feedback progres).

### Transisi (HP fase 1 habis)

Boss invulnerable ±2.5 s: slow-mo, layar CRT meledak jadi partikel, cangkang runtuh, sosok asli keluar. Nama baru di HP bar. Player tidak bisa memberi damage.

### Fase 2 — "Sang Suara" (duel cermin; uji dodge + parry) — HP 360, 6 m/s

Perempuan retro — suara pertama Siaran. Siluet ramping jelas female dari primitif (bahu sempit, pinggang, coat/dress retro, helai rambut emissive). Senjata: bilah antena **neon merah** — cermin bilah ungu player.

| Serangan | Windup | Warna | Damage | Catatan |
|---|---|---|---|---|
| String 3-hit | 0.5 s | **putih** | 12/12/16 | duel parry |
| Dash thrust | 0.6 s | **merah** | 22 | momen emas perfect dodge |
| Gelombang sinyal (proyektil) | — | **merah** | 12 | tekanan jarak jauh |
| Backstep + counter cepat | — | **putih** | — | anti-spam |

Perfect parry → stagger 1.6 s (jendela damage utama). **Menang** → slow-mo + fade → layar menang.

## 10. UI / Layar

- **HUD:** HP bar kiri bawah; **meter skill bergaya kaset** di sebelahnya (dua reel + pita terisi — "merekam" energi tiap parry); style rank kanan atas; HP bar boss atas-tengah (hanya saat boss aktif); prompt kontekstual ("E — Aktifkan Ganna").
- **Menu utama:** judul PATHAGANNA, MULAI, KELUAR; latar Ganna — TV berkedip statis.
- **Layar kalah:** **"SINYAL HILANG"** + statis/flicker; auto-respawn 2.5 s (atau tombol).
- **Layar menang:** **"SIARAN BERAKHIR"** + waktu main + rank style tertinggi + kembali ke menu.
- **Pause (Esc):** lanjut / keluar ke menu; `get_tree().paused = true`, UI process exception.
- Font bawaan; kesan retro dari warna, glow, kapital berspasi lebar.

## 11. Art direction — stylized gelap-neon (BUKAN filter PS1)

- Resolusi penuh, MSAA 2×, V-Sync on. Tanpa downscale/pixelate.
- `WorldEnvironment`: bg `#0d0a14`; fog ±30 m; **glow/bloom aktif**; ambient rendah.
- Satu `DirectionalLight3D` redup dingin (satu-satunya shadow caster, shadow map 2048) + material emissive sebagai "cahaya" aksen.
- **Palet terpusat** `resources/materials/`: batu gelap `#3a3546`, logam tua, kabel hitam, jubah gelap; emissive: **ungu `#b44cff`** (player/Ganna/sigil), **merah `#ff2e4d`** (musuh/bahaya), putih-kehijauan (layar CRT).
- Props: pilar batu, kabel akar, tumpukan CRT statis (emissive berkedip lembut), antena berkarat, lilin.
- Performa (target 60 fps laptop biasa): material shared, partikel one-shot auto-free, low poly, 1 shadow caster, ≤6 musuh.

## 12. Roadmap (konteks modularitas — TIDAK dikerjakan di V1)

- **P1:** essence currency + drop di titik mati (bisa dipungut); skill kedua; upgrade di Ganna; musuh elite; upgrade visual (GLB + animasi impor menggantikan lapisan visual — murah karena aturan arsitektur no. 2).
- **P2:** area kedua; senjata alternatif; NPC/lore; gamepad; audio penuh. (SFX prosedural beep/noise boleh masuk V1 hanya jika sangat murah dan tidak menunda milestone.)

## 13. Definisi Selesai V1

1. Gerak + kamera third-person + lock-on berfungsi.
2. Kombo 3-hit responsif.
3. Dodge biasa dan perfect dodge (slow-mo).
4. Parry biasa dan perfect parry (stagger + isi meter).
5. Skill saat meter penuh.
6. Kedua tipe musuh terkalahkan.
7. Mati → respawn di Ganna; Ganna kedua bisa diaktifkan.
8. Boss 2 fase sampai menang → layar menang.
9. ±60 fps laptop biasa, tanpa `ERROR`/`SCRIPT ERROR` di output Godot sepanjang sesi penuh.

Poin yang butuh penilaian manusia diverifikasi oleh user di M6, bukan dicentang sendiri.

---

## 14. Changelog (keputusan yang diambil sendiri)

- **2026-07-09 — Project root.** Dipakai repo git yang sudah dibuat & di-clone user: `Pathaganna/` (remote `github.com/Watarufa/Pathaganna`), bukan membuat folder `pathaganna/` baru.
- **2026-07-09 — Godot 4.7 stable.** Zip `Godot_v4.7-stable_win64.exe.zip` milik user (Downloads) diekstrak ke `%LOCALAPPDATA%\Programs\Godot\`; dipakai exe console. Memenuhi syarat ≥ 4.4.
- **2026-07-09 — Chain point kombo.** Spec hanya mendefinisikan cancel point dodge/parry. Keputusan: serangan lanjutan (buffered) dieksekusi mulai **akhir window hitbox** serangan berjalan (A1 0.22 s, A2 0.24 s) — chaining tidak pernah membatalkan hit yang sedang aktif, tapi tetap jauh lebih cepat daripada menunggu durasi penuh.
- **2026-07-09 — Bentuk hitbox serangan player.** Box arc di depan player (bukan mengikuti bilah presisi) — lebih generoous dan konsisten, sesuai pillar combat feel; visual bilah tetap mengikuti pose.
- **2026-07-09 — Perilaku Tab.** Tanpa target → lock ke kandidat terbaik; dengan target → cycle ke kandidat lain; jika tidak ada kandidat lain → unlock. Auto-unlock saat target mati / > 15 m.
- **2026-07-09 — Style gain parry.** "+80 perfect dodge/parry" dibaca: parry (normal maupun perfect) +80, perfect dodge +80. Diferensiasi normal vs perfect parry sudah lewat meter (+10/+30) dan stagger.
- **2026-07-09 — Window hitbox skill.** Durasi 0.8 s tanpa window di spec → hitbox area aktif 0.25–0.45 s (windup berbobot, recovery jelas).
- **2026-07-09 — Dodge → attack.** Serangan boleh keluar dari dodge setelah i-frames berakhir (0.32 s) agar flow ofensif terjaga.
- **2026-07-09 — Parry sukses → cancel.** Setelah kontak parry sukses, state parry bisa langsung di-cancel ke serangan (memanfaatkan stagger perfect parry).
- **2026-07-09 — Smoke test tambahan.** Selain 2 perintah wajib, `--quit-after` juga dijalankan dengan user arg `-- --smoke` yang membuat main.gd auto-masuk gameplay — supaya script gameplay ikut tereksekusi headless.
