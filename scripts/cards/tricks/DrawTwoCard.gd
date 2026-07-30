class_name DrawTwoCard
extends Card
## 无中生有


func _init() -> void:
	super(
		CardType.DRAW_TWO,
		"无中生有",
		"出牌阶段，对自己使用：摸两张牌。",
		Color("c58b38"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.SELF
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

