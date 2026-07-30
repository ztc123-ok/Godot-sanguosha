class_name SupplyShortageCard
extends Card
## 兵粮寸断


func _init() -> void:
	super(
		CardType.SUPPLY_SHORTAGE,
		"兵粮寸断",
		"出牌阶段，对距离为 1 的其他角色使用并置于其判定区。判定若不为梅花，跳过摸牌阶段。",
		Color("65794b"),
		CardCategory.DELAYED_TRICK,
		Suit.NONE,
		0,
		true,
		TargetMode.OTHER
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

