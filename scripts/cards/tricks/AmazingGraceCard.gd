class_name AmazingGraceCard
extends Card
## 五谷丰登


func _init() -> void:
	super(
		CardType.AMAZING_GRACE,
		"五谷丰登",
		"出牌阶段，对所有角色使用：亮出等同于存活角色数的牌，各角色依次选择并获得一张。",
		Color("d09b45"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.ALL
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

