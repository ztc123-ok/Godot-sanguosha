class_name KejiSkill
extends Skill

func _init() -> void:
	super(&"keji", "克己", "若你未在本回合出牌阶段使用或打出过【杀】，结束出牌阶段时可以跳过弃牌阶段。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"after_play_phase"
func can_trigger(_context: RefCounted, _game: Node, owner: Node) -> bool: return not owner.used_effective_card(Card.CardType.SLASH)
func should_ai_activate(context: RefCounted, game: Node, owner: Node) -> bool:
	return can_trigger(context, game, owner) and owner.hand.size() > game.hand_limit_for(owner)
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "keji"}
