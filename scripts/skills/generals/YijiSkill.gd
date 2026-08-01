class_name YijiSkill
extends Skill

func _init() -> void:
	super(&"yiji", "遗计", "每受到1点伤害后，你可以观看牌堆顶两张牌，并将它们逐张交给任意角色。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"after_damage"
func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool:
	return context is DamageContext and context.target == owner and context.amount > 0
func trigger_repeat_count(context: RefCounted, _game: Node, _owner: Node) -> int: return maxi((context as DamageContext).amount, 0)
func should_ai_activate(context: RefCounted, game: Node, owner: Node) -> bool: return can_trigger(context, game, owner)
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "yiji"}
