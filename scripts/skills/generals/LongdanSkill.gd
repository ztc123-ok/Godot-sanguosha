class_name LongdanSkill
extends Skill


func _init() -> void:
	super(
		&"longdan",
		"龙胆",
		"你可以将【杀】当【闪】、将【闪】当【杀】使用或打出。",
		ActivationMode.VIEW_AS
	)


func can_view_as(
	card: Card,
	effective_type: Card.CardType,
	_game: Node,
	_owner: Node
) -> bool:
	if card == null:
		return false
	return (
		(effective_type == Card.CardType.SLASH and card.card_type == Card.CardType.DODGE)
		or (effective_type == Card.CardType.DODGE and card.card_type == Card.CardType.SLASH)
	)
