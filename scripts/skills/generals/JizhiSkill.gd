class_name JizhiSkill
extends Skill
## 集智：每当你使用一张非延时锦囊牌时，你可以摸一张牌。

func _init() -> void:
	super(&"jizhi", "集智", "每当你使用一张非延时锦囊牌时（即使之后被【无懈可击】抵消），你可以摸一张牌。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"after_trick_use"

func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool:
	var use := context as SkillUseContext
	if use == null or use.user != owner or owner.hp <= 0:
		return false
	var probe: Card = CardFactory.create_card(use.effective_card_type)
	return probe != null and probe.category == Card.CardCategory.TRICK

func should_ai_activate(_context: RefCounted, _game: Node, _owner: Node) -> bool: return true
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "jizhi_draw"}
