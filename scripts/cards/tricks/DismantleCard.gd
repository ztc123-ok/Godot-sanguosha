class_name DismantleCard
extends Card
## 过河拆桥


func _init() -> void:
	super(
		CardType.DISMANTLE,
		"过河拆桥",
		"出牌阶段，对一名有牌的其他角色使用：弃置其区域内一张牌。",
		Color("8f5b43"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.OTHER
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

