## Weapon trail: ribbon ImmediateMesh dari posisi ujung & pangkal bilah
## selama JUICE.trail_frames frame terakhir; emissive ungu, memudar di ekor.
class_name SlashTrail
extends MeshInstance3D

const TRAIL_COLOR := Color(0.706, 0.298, 1.0)  # neon ungu player

var tip: Node3D = null
var blade_base: Node3D = null
var active := false

var _im := ImmediateMesh.new()
var _samples: Array = []  # [tip_pos, base_pos], terbaru di indeks 0

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = m

func _process(_delta: float) -> void:
	if active and tip != null and blade_base != null:
		_samples.push_front([tip.global_position, blade_base.global_position])
		while _samples.size() > int(Balance.JUICE.trail_frames):
			_samples.pop_back()
	elif not _samples.is_empty():
		_samples.pop_back()
		if not _samples.is_empty():
			_samples.pop_back()
	_rebuild()

func _rebuild() -> void:
	_im.clear_surfaces()
	if _samples.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _samples.size()
	for i in n:
		var fade := 1.0 - float(i) / float(n)
		var c := Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, fade * fade * 0.85)
		_im.surface_set_color(c)
		_im.surface_add_vertex(_samples[i][1])
		_im.surface_set_color(c)
		_im.surface_add_vertex(_samples[i][0])
	_im.surface_end()
