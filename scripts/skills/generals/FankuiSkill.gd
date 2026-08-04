class_name FankuiSkill
extends Skill

func _init() -> void:
	super(&"fankui", "反馈", "每次受到伤害后，你可以获得伤害来源的一张手牌或装备牌。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"after_damage"
func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool:
	return (
		context is DamageContext
		and context.target == owner
		and context.source != null
		and context.source.total_cards_in_hand_and_equipment() > 0
	)
func should_ai_activate(context: RefCounted, game: Node, owner: Node) -> bool: return can_trigger(context, game, owner)
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "fankui"}
