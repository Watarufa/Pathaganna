## Kit props kuil: pilar, kabel menjalar seperti akar, tumpukan CRT menyala
## statis, antena berkarat, lilin. Semua dari primitif + material palet bersama.
##
## Layar CRT props memakai beberapa material duplikat yang dipakai bergantian
## (bukan satu per props): kedipnya jadi tidak seragam, tapi jumlah material
## tetap kecil — props ini disebar puluhan kali di level.
class_name Props
extends RefCounted

const FLICKER_VARIANTS := 3

static var _crt_mats: Array[StandardMaterial3D] = []

## Material CRT berkedip. Panggil `animate_flicker()` tiap frame dari level.
static func crt_materials() -> Array[StandardMaterial3D]:
	if _crt_mats.is_empty():
		for i in FLICKER_VARIANTS:
			_crt_mats.append(Palette.CRT_SCREEN.duplicate())
	return _crt_mats

## Denyut lembut layar-layar statis. Fase berbeda per varian supaya ruangan
## terasa hidup tanpa satu pun berkedip serempak.
static func animate_flicker(t: float) -> void:
	var mats := crt_materials()
	for i in mats.size():
		var phase := t * (1.7 + 0.35 * float(i)) + float(i) * 2.1
		var n := 0.5 + 0.5 * sin(phase) * sin(phase * 2.7)
		mats[i].emission_energy_multiplier = 0.7 + n * 1.1

# ------------------------------------------------------------- primitif dasar
static func mesh_box(parent: Node, size: Vector3, pos: Vector3, mat: Material,
		rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func mesh_cylinder(parent: Node, radius: float, height: float, pos: Vector3,
		mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## Kotak padat bertabrakan (dinding, pilar, lantai).
static func solid_box(parent: Node, size: Vector3, pos: Vector3, mat: Material,
		rot_deg := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1  # world
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = rot_deg
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	parent.add_child(body)
	return body

# ------------------------------------------------------------- props kuil
## Pilar batu retak dengan kabel yang menjalar naik.
static func pillar(parent: Node, pos: Vector3, height := 4.2) -> void:
	var body := solid_box(parent, Vector3(1.1, height, 1.1), pos + Vector3(0, height * 0.5, 0),
		Palette.STONE)
	# kepala & alas pilar
	mesh_box(body, Vector3(1.45, 0.28, 1.45), Vector3(0, height * 0.5 - 0.14, 0), Palette.STONE)
	mesh_box(body, Vector3(1.45, 0.3, 1.45), Vector3(0, -height * 0.5 + 0.15, 0), Palette.STONE)
	# kabel menjalar seperti akar
	for i in 3:
		var a := TAU * float(i) / 3.0
		var off := Vector3(cos(a), 0, sin(a)) * 0.58
		mesh_box(body, Vector3(0.07, height * 0.8, 0.07),
			off + Vector3(0, -height * 0.06, 0), Palette.CABLE,
			Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))

## Kabel menjalar di lantai — menghubungkan props, memperkuat tema "akar sinyal".
static func cable_run(parent: Node, from: Vector3, to: Vector3, sag := 0.0) -> void:
	var seg := 4
	for i in seg:
		var a := from.lerp(to, float(i) / float(seg))
		var b := from.lerp(to, float(i + 1) / float(seg))
		var mid := (a + b) * 0.5
		mid.y += sin(float(i) / float(seg) * PI) * sag
		var d := b - a
		var mi := mesh_box(parent, Vector3(0.08, 0.08, d.length()), mid, Palette.CABLE)
		if d.length() > 0.01:
			mi.look_at(mi.global_position + d.normalized(), Vector3.UP)

## Tumpukan TV CRT menyala statis — motif utama kultus.
static func crt_stack(parent: Node, pos: Vector3, count := 3, yaw := 0.0) -> void:
	var mats := crt_materials()
	var y := 0.0
	for i in count:
		var w := randf_range(0.55, 0.8)
		var h := randf_range(0.45, 0.6)
		var jitter := Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))
		var casing := solid_box(parent, Vector3(w, h, w * 0.9),
			pos + jitter + Vector3(0, y + h * 0.5, 0), Palette.METAL,
			Vector3(0, yaw + randf_range(-14, 14), 0))
		# layar menyala statis (varian material bergantian supaya kedipnya tidak serempak)
		mesh_box(casing, Vector3(w * 0.72, h * 0.66, 0.02), Vector3(0, 0, -w * 0.46),
			mats[i % mats.size()])
		y += h

## Antena berkarat miring.
static func antenna(parent: Node, pos: Vector3, height := 3.0) -> void:
	var lean := Vector3(randf_range(-10, 10), randf_range(0, 180), randf_range(-10, 10))
	var mast := mesh_cylinder(parent, 0.045, height, pos + Vector3(0, height * 0.5, 0),
		Palette.METAL, lean)
	for i in 3:
		var y := height * (0.25 + 0.22 * float(i)) - height * 0.5
		var span := 0.75 - 0.16 * float(i)
		mesh_box(mast, Vector3(span, 0.03, 0.03), Vector3(0, y, 0), Palette.METAL)

## Lilin menyala — satu-satunya cahaya "hangat" di kuil.
static func candle(parent: Node, pos: Vector3, height := 0.26) -> void:
	mesh_cylinder(parent, 0.045, height, pos + Vector3(0, height * 0.5, 0), Palette.STONE)
	var flame := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh.rings = 3
	flame.mesh = mesh
	flame.position = pos + Vector3(0, height + 0.05, 0)
	flame.material_override = Palette.CANDLE
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flame)

## Reruntuhan: balok batu tumbang.
static func rubble(parent: Node, pos: Vector3) -> void:
	for i in 3:
		var s := Vector3(randf_range(0.5, 1.2), randf_range(0.3, 0.6), randf_range(0.5, 1.0))
		solid_box(parent, s, pos + Vector3(randf_range(-0.9, 0.9), s.y * 0.5, randf_range(-0.9, 0.9)),
			Palette.STONE, Vector3(0, randf_range(0, 180), 0))
