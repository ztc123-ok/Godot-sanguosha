class_name StealCard
extends Card
## 顺手牵羊


func _init() -> void:
	super(
		CardType.STEAL,
		"顺手牵羊",
		"出牌阶段，对距离为 1 且有牌的其他角色使用：获得其区域内一张牌。",
		Color("a47b3e"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.OTHER
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

