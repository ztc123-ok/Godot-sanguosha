class_name QicaiSkill
extends Skill
## 奇才：锁定技，你使用锦囊牌无距离限制。

func _init() -> void:
	super(
		&"qicai",
		"奇才",
		"锁定技，你使用锦囊牌无距离限制（顺手牵羊、借刀杀人等不再检查距离，其余目标限制照常）。",
		ActivationMode.MODIFIER,
		[SkillTag.LOCKED]
	)

func ignores_trick_distance(effective_type: Card.CardType, _game: Node, _owner: Node) -> bool:
	return effective_type in [Card.CardType.STEAL, Card.CardType.BORROW_SWORD]
