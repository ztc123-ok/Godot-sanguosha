class_name BarbarianInvasionCard
extends Card
## 南蛮入侵


func _init() -> void:
	super(
		CardType.BARBARIAN_INVASION,
		"南蛮入侵",
		"出牌阶段，对所有其他角色使用：每名目标需打出【杀】，否则受到使用者造成的 1 点伤害。",
		Color("9a4636"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.ALL
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

