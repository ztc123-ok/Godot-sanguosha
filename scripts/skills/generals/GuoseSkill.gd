class_name GuoseSkill
extends Skill
## 国色：出牌阶段，你可以将一张方块手牌或方块装备牌当【乐不思蜀】使用。

func _init() -> void:
	super(
		&"guose",
		"国色",
		"出牌阶段，你可以将一张方块手牌或方块装备牌当【乐不思蜀】使用。",
		ActivationMode.VIEW_AS
	)

func can_view_as(card: Card, effective_type: Card.CardType, _game: Node, _owner: Node) -> bool:
	return effective_type == Card.CardType.INDULGENCE and card != null and card.suit == Card.Suit.DIAMOND
