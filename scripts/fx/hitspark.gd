## Percikan hit one-shot: GPUParticles3D quad emissive, auto-free.
## Material di-cache per warna (shared antar spark — performa).
class_name HitSpark
extends GPUParticles3D

static var _mat_cache := {}

static func spawn(parent: Node, pos: Vector3, color: Color, count := 14, speed := 7.0, size := 0.06) -> void:
	var p := HitSpark.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = 0.35
	p.emitting = false

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -9.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 5.0
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _material_for(color)
	p.draw_pass_1 = quad

	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	# jaring pengaman: di headless sinyal finished bisa tidak pernah datang.
	# Timer memakai waktu real (abaikan time_scale) agar hitstop tidak menahan partikel.
	var t := p.get_tree().create_timer(2.0, true, false, true)
	t.timeout.connect(p._expire)

func _expire() -> void:
	queue_free()

static func _material_for(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat_cache[key] = m
	return m
