class_name PeachGardenCard
extends Card
## 桃园结义


func _init() -> void:
	super(
		CardType.PEACH_GARDEN,
		"桃园结义",
		"出牌阶段，对所有角色使用：每名受伤角色依次回复 1 点体力。",
		Color("d66f84"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.ALL
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

