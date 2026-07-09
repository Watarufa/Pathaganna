## Payload sebuah serangan, dibawa Hitbox → Hurtbox.
## Dibuat dari dictionary balance.gd lewat AttackData.make().
class_name AttackData
extends Resource

var damage := 0.0
var parryable := true          # true = telegraph putih, false = merah (wajib dodge)
var knockback := 0.0           # m/s impuls menjauh dari sumber
var hitstop := 0.05            # s real-time saat hit ini kena
var style_type := ""           # identitas untuk bonus variasi style ("A1", "skill", ...)
var source: Node = null        # penyerang (arah knockback + atribusi event)

static func make(d: Dictionary, src: Node = null, type_name: String = "") -> AttackData:
	var a := AttackData.new()
	a.damage = d.get("damage", 0.0)
	a.parryable = d.get("parryable", true)
	a.knockback = d.get("knockback", 0.0)
	a.hitstop = d.get("hitstop", 0.05)
	a.style_type = type_name
	a.source = src
	return a
