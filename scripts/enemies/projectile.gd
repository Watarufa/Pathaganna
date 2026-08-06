## Proyektil sinyal Penyiar — selalu MERAH (tidak bisa diparry), jadi jawabannya
## selalu dodge atau reposisi. Mati saat mengenai player, menabrak dunia, atau
## umurnya habis.
class_name SignalProjectile
extends Area3D

var dir := Vector3.ZERO
var data: Dictionary = {}
var shooter: Node = null

var _life := 0.0
var _hit := false

static func spawn(parent: Node, from: Vector3, direction: Vector3,
		proj: Dictionary, shooter_node: Node) -> SignalProjectile:
	var p := SignalProjectile.new()
	p.dir = direction.normalized()
	p.data = proj
	p.shooter = shooter_node

	p.add_to_group("projectiles")
	p.collision_layer = 64        # enemy_attack
	p.collision_mask = 1 | 8      # world + player_hurt
	p.monitoring = true

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = float(proj.radius)
	shape.shape = sphere
	p.add_child(shape)

	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = float(proj.radius)
	mesh.height = float(proj.radius) * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mi.mesh = mesh
	mi.material_override = Palette.NEON_RED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)

	parent.add_child(p)
	p.global_position = from
	return p

func _physics_process(delta: float) -> void:
	if _hit:
		return
	global_position += dir * float(data.speed) * delta
	_life += delta
	if _life >= float(data.life):
		queue_free()
		return

	for area in get_overlapping_areas():
		if area is Hurtbox:
			_hit = true
			area.receive(AttackData.make(data, shooter, String(data.get("kind", "proj"))), self)
			HitSpark.spawn(get_parent(), global_position, Color(1.0, 0.18, 0.302), 12, 5.0)
			queue_free()
			return
	if not get_overlapping_bodies().is_empty():
		HitSpark.spawn(get_parent(), global_position, Color(1.0, 0.18, 0.302), 8, 4.0)
		queue_free()
