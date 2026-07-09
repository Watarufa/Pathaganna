# PATHAGANNA

Game 3D stylish action / soulslike singkat (10–15 menit). Kultus kuno memuja **"Siaran"** —
sinyal dari sesuatu di seberang. Lawan para pemujanya, aktifkan Ganna, dan hentikan siaran itu.

Dibangun murni dengan Godot + GDScript: tanpa asset eksternal — karakter, level, dan VFX
dirakit dari primitif, kode, dan partikel. Estetika stylized gelap ber-aksen neon.

## Syarat

- **Godot 4.4 atau lebih baru** (dikembangkan di 4.7 stable).

## Cara menjalankan

- **Termudah:** buka Godot → **Import** → pilih `project.godot` → tekan **F5**.
- **CLI:** `godot --path .` (atau path lengkap ke executable Godot).

## Kontrol

| Aksi | Input |
|---|---|
| Gerak | WASD |
| Kamera | Mouse |
| Serang (kombo 3-hit) | Klik kiri |
| Parry | Klik kanan |
| Dodge roll | Shift atau Space |
| Skill | Q |
| Lock-on / ganti target | Tab |
| Interaksi (Ganna) | E |
| Pause | Esc |
| Debug overlay | F3 |

**Putih = bisa diparry. Merah = wajib dodge.** Meter skill hanya terisi dari parry dan
perfect dodge — bermainlah agresif dan presisi.

## Dokumen

- `GAME_DESIGN.md` — desain lengkap + tabel tuning (sumber kebenaran).
- `TODO.md` — progres milestone.
