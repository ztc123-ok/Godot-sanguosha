class_name QixiSkill
extends Skill


func _init() -> void:
	super(
		&"qixi",
		"奇袭",
		"出牌阶段，你可以将一张黑色手牌或黑色装备牌当【过河拆桥】使用。",
		ActivationMode.VIEW_AS
	)


func can_view_as(
	card: Card,
	effective_type: Card.CardType,
	_game: Node,
	_owner: Node
) -> bool:
	return card != null and not card.is_red() and effective_type == Card.CardType.DISMANTLE
