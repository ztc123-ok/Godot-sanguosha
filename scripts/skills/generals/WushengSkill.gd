class_name WushengSkill
extends Skill


func _init() -> void:
	super(
		&"wusheng",
		"武圣",
		"你可以将一张红色手牌或红色装备牌当【杀】使用或打出。",
		ActivationMode.VIEW_AS
	)


func can_view_as(
	card: Card,
	effective_type: Card.CardType,
	_game: Node,
	_owner: Node
) -> bool:
	return card != null and card.is_red() and effective_type == Card.CardType.SLASH
