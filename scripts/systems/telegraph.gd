## Kurva telegraph serangan musuh — dipakai SEMUA musuh (dummy latihan, Kultis,
## Penyiar, kedua fase boss) supaya keterbacaan konsisten di seluruh game.
##
## Telegraph bukan cuma warna. Warna memberi tahu APA yang harus dilakukan
## (putih = parry, merah = dodge); GERAKAN memberi tahu KAPAN. Karena itu pose
## windup dihitung sebagai fungsi langsung dari state_time — bukan pose statis
## yang di-blend sekali lalu diam — sehingga progres visual = progres waktu.
##
## Bentuknya: angkat progresif (cepat lalu menahan) → anticipation singkat
## (tarikan balik) → pukul. Itu bahasa animasi klasik untuk "bersiap ... SEKARANG".
class_name Telegraph
extends RefCounted

## Seberapa jauh pose "siap" sudah terangkat (0..1).
##
## Smoothstep, bukan ease-out: mulai pelan (terasa berat), mengalir di tengah,
## lalu melambat mendekati pose siap sehingga terbaca sebagai MENAHAN di puncak.
## Kurva ease-out yang front-loaded menyelesaikan sebagian besar gerakan di
## sepertiga pertama lalu praktis diam — itu terlihat seperti sentakan, bukan
## ancaman yang bisa dilacak mata.
static func raise_amount(state_time: float, windup: float) -> float:
	var t := clampf(state_time / maxf(windup, 0.001), 0.0, 1.0)
	var k := clampf(t / float(Balance.TELEGRAPH.coil_at), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

## Anticipation di ujung windup (0..1): tarikan balik singkat sebelum pukulan.
static func coil_amount(state_time: float, windup: float) -> float:
	var t := clampf(state_time / maxf(windup, 0.001), 0.0, 1.0)
	var c: float = Balance.TELEGRAPH.coil_at
	if t <= c:
		return 0.0
	var k := clampf((t - c) / maxf(1.0 - c, 0.001), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

## Progres telegraph 0..1 untuk hitung mundur di layar musuh.
##
## LINEAR terhadap waktu — sengaja, tidak di-ease: persentase yang dilihat
## pemain harus benar-benar sama dengan sisa waktu. 1.0 = pukulan dimulai.
static func fill_amount(state_time: float, windup: float) -> float:
	return clampf(state_time / maxf(windup, 0.001), 0.0, 1.0)

## Denyut glow di ujung fill: naik-turun tanpa pernah padam.
##
## Menandakan urgensi tanpa mengaburkan gerakan tubuh — kedip on/off justru
## menyembunyikan pose tepat di momen yang paling perlu dibaca pemain.
## Denyut dihitung dari JUMLAH SIKLUS sepanjang fase akhir, bukan Hz, supaya
## polanya identik untuk windup pendek maupun panjang.
static func pulse_energy(fill: float, base: float) -> float:
	var start: float = Balance.TELEGRAPH.pulse_start
	if fill < start:
		return base
	var k := (fill - start) / maxf(1.0 - start, 0.001)
	var wave := 0.5 + 0.5 * sin(k * TAU * float(Balance.TELEGRAPH.pulse_cycles))
	return base * (1.0 + wave * float(Balance.TELEGRAPH.pulse_amount))

## Interpolasi dua pose (dictionary nama pivot → euler derajat).
## Kedua pose harus punya kunci yang sama.
static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in a:
		out[key] = (a[key] as Vector3).lerp(b[key], k)
	return out

## Pose windup lengkap: netral → siap → coil, dari satu profil serangan.
## Profil wajib punya kunci `ready` dan `coil` dengan pivot yang sama; `neutral`
## opsional (default semua nol) dan harus diisi dengan pose diam si musuh —
## kalau tidak, frame pertama windup melompat dan justru merusak keterbacaan.
static func windup_pose(profile: Dictionary, state_time: float, windup: float) -> Dictionary:
	var neutral: Dictionary = profile.get("neutral", {})
	if neutral.is_empty():
		for key in profile.ready:
			neutral[key] = Vector3.ZERO
	var base := blend(neutral, profile.ready, raise_amount(state_time, windup))
	return blend(base, profile.coil, coil_amount(state_time, windup))
