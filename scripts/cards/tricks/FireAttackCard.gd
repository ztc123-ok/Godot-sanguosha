class_name FireAttackCard
extends Card
## 火攻


func _init() -> void:
	super(
		CardType.FIRE_ATTACK,
		"火攻",
		"出牌阶段，对一名有手牌的角色使用：其展示一张手牌，你可弃置一张同花色手牌并对其造成 1 点火焰伤害。",
		Color("d15d35"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.OTHER
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

