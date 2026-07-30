class_name DuelCard
extends Card
## 决斗


func _init() -> void:
	super(
		CardType.DUEL,
		"决斗",
		"出牌阶段，对其他角色使用：其先打出【杀】，双方轮流打出【杀】，首先不出的角色受到另一方造成的 1 点伤害。",
		Color("9e3941"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.OTHER
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

