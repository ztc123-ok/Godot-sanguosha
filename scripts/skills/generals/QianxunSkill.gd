class_name QianxunSkill
extends Skill
## 谦逊：锁定技，你不能成为【顺手牵羊】和【乐不思蜀】的目标。

func _init() -> void:
	super(
		&"qianxun",
		"谦逊",
		"锁定技，你不能成为【顺手牵羊】或【乐不思蜀】的目标（含国色形成的虚拟【乐不思蜀】）。",
		ActivationMode.MODIFIER,
		[SkillTag.LOCKED]
	)

func can_be_targeted_by(effective_type: Card.CardType, _source: Node, _game: Node, _owner: Node) -> bool:
	return effective_type not in [Card.CardType.STEAL, Card.CardType.INDULGENCE]
