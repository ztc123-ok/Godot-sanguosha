class_name JijiuSkill
extends Skill
## 急救：你的回合外，你可以将一张红色手牌或红色装备牌当【桃】使用。

func _init() -> void:
	super(
		&"jijiu",
		"急救",
		"你的回合外，你可以将一张红色手牌或红色装备牌当【桃】使用。",
		ActivationMode.VIEW_AS
	)

func can_view_as(card: Card, effective_type: Card.CardType, _game: Node, _owner: Node) -> bool:
	return effective_type == Card.CardType.PEACH and card != null and card.is_red()
