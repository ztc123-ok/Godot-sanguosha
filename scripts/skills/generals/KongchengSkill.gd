class_name KongchengSkill
extends Skill

func _init() -> void:
	super(&"kongcheng", "空城", "锁定技，没有手牌时，你不能成为【杀】或【决斗】的目标。", ActivationMode.MODIFIER, [SkillTag.LOCKED])

func can_be_targeted_by(effective_type: Card.CardType, _source: Node, _game: Node, owner: Node) -> bool:
	return not (owner.hand.is_empty() and effective_type in [Card.CardType.SLASH, Card.CardType.DUEL])
