class_name FankuiSkill
extends Skill

func _init() -> void:
	super(&"fankui", "反馈", "每次受到伤害后，你可以获得伤害来源的一张手牌、装备牌或判定区牌。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"after_damage"
func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool:
	return context is DamageContext and context.target == owner and context.source != null and context.source.has_any_card_in_play_area()
func should_ai_activate(context: RefCounted, game: Node, owner: Node) -> bool: return can_trigger(context, game, owner)
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "fankui"}
