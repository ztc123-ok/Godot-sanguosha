class_name ArrowBarrageCard
extends Card
## 万箭齐发


func _init() -> void:
	super(
		CardType.ARROW_BARRAGE,
		"万箭齐发",
		"出牌阶段，对所有其他角色使用：每名目标需打出【闪】，否则受到使用者造成的 1 点伤害。",
		Color("a74758"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.ALL
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

