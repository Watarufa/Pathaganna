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

## Seberapa jauh pose "siap" sudah terangkat (0..1). Naik cepat lalu melambat,
## jadi perubahan besar terjadi di awal dan mata punya waktu menyesuaikan.
static func raise_amount(state_time: float, windup: float) -> float:
	var t := clampf(state_time / maxf(windup, 0.001), 0.0, 1.0)
	var k := clampf(t / float(Balance.TELEGRAPH.coil_at), 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)

## Anticipation di ujung windup (0..1): tarikan balik singkat sebelum pukulan.
static func coil_amount(state_time: float, windup: float) -> float:
	var t := clampf(state_time / maxf(windup, 0.001), 0.0, 1.0)
	var c: float = Balance.TELEGRAPH.coil_at
	if t <= c:
		return 0.0
	var k := clampf((t - c) / maxf(1.0 - c, 0.001), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

## Kedip layar yang mengencang mendekati pukulan — sinyal timing kedua,
## terbaca bahkan di sudut kamera yang menyembunyikan lengan.
##
## Frekuensi naik linear, jadi fase harus INTEGRAL frekuensi, bukan hz * t:
## yang terakhir membuat fase melompat mundur setiap kali hz berubah, dan
## kedipnya terlihat acak alih-alih mengencang.
static func blink_on(state_time: float, windup: float) -> bool:
	var t := clampf(state_time, 0.0, maxf(windup, 0.001))
	var f0: float = Balance.TELEGRAPH.blink_hz_start
	var f1: float = Balance.TELEGRAPH.blink_hz_end
	var slope := (f1 - f0) / maxf(windup, 0.001)
	var phase := f0 * t + 0.5 * slope * t * t
	return fmod(phase, 1.0) < 0.5

## Material layar/telegraph untuk frame ini: berkedip lalu menyala solid saat coil.
static func screen_material(state_time: float, windup: float, parryable: bool, idle_mat: Material) -> Material:
	var lit: Material = Palette.TELEGRAPH_WHITE if parryable else Palette.TELEGRAPH_RED
	if coil_amount(state_time, windup) >= Balance.TELEGRAPH.solid_at:
		return lit
	return lit if blink_on(state_time, windup) else idle_mat

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
