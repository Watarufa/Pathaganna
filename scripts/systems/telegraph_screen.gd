## Layar telegraph: hitung mundur diegetik yang mengisi dari bawah selama windup,
## penuh 100% tepat saat pukulan dimulai.
##
## Dipakai dummy latihan, Kultis (layar wajah CRT), Penyiar (dial radio), dan
## kedua fase boss — bentuk fisiknya beda, perilakunya sama persis.
##
## Material fill di-duplicate per musuh supaya glow-nya bisa didenyutkan sendiri
## tanpa ikut mengubah musuh lain yang berbagi material palet.
class_name TelegraphScreen
extends RefCounted

var _screen: MeshInstance3D
var _fill: MeshInstance3D
var _mat: StandardMaterial3D
var _base_energy := 1.0
var _center_y := 0.0
var _half := 0.1

## Rakit layar + lapisan fill pada satu pivot rig. `size` = lebar × tinggi layar;
## `offset` = posisi pusat layar relatif pivot. Wajah dianggap menghadap -Z.
static func build(rig: PoseRig, pivot: String, size: Vector2, offset: Vector3) -> TelegraphScreen:
	var t := TelegraphScreen.new()
	t._center_y = offset.y
	t._half = size.y * 0.5
	t._screen = rig.attach_box(pivot, Vector3(size.x, size.y, 0.02), offset, Palette.CRT_SCREEN)
	t._fill = rig.attach_box(pivot, Vector3(size.x * 0.93, size.y, 0.01),
		offset + Vector3(0, 0, -0.012), null)
	t._mat = Palette.TELEGRAPH_WHITE.duplicate()
	t._fill.material_override = t._mat
	t._fill.visible = false
	return t

## Siapkan warna untuk serangan berikutnya. Warna diambil dari material palet,
## jadi sumber kebenarannya tetap di resources/materials/.
func arm(parryable: bool) -> void:
	var src: StandardMaterial3D = Palette.TELEGRAPH_WHITE if parryable else Palette.TELEGRAPH_RED
	_mat.albedo_color = src.albedo_color
	_mat.emission = src.emission
	_base_energy = src.emission_energy_multiplier

## Isi layar dari bawah (0..1). 1.0 = pukulan dimulai.
func set_fill(amount: float) -> void:
	if amount <= 0.001:
		_fill.visible = false
		_screen.material_override = Palette.CRT_SCREEN
		return
	# layar dasar diredupkan supaya warna hitung mundur benar-benar menonjol
	_screen.material_override = Palette.CRT_OFF
	_fill.visible = true
	_fill.scale.y = amount
	_fill.position.y = (_center_y - _half) + _half * amount
	_mat.emission_energy_multiplier = Telegraph.pulse_energy(amount, _base_energy)

## Layar padam total (mati / reboot) — tanpa menyalakan kembali layar dasar.
func power_off() -> void:
	_fill.visible = false
	_screen.material_override = Palette.CRT_OFF

func is_filling() -> bool:
	return _fill.visible
