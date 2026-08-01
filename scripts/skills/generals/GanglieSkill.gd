class_name GanglieSkill
extends Skill

func _init() -> void:
	super(&"ganglie", "刚烈", "每次受到伤害后，你可以判定：若不为红桃，伤害来源弃置两张手牌或受到你造成的1点伤害。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"after_damage"
func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool:
	return context is DamageContext and context.target == owner and context.source != null and context.source.hp > 0
func should_ai_activate(context: RefCounted, game: Node, owner: Node) -> bool: return can_trigger(context, game, owner)
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "ganglie"}
