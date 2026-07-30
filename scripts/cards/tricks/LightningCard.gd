class_name LightningCard
extends Card
## 闪电


func _init() -> void:
	super(
		CardType.LIGHTNING,
		"闪电",
		"出牌阶段，置于自己的判定区。判定为黑桃 2~9 时受到 3 点雷电伤害，否则将【闪电】移至下一名角色判定区。",
		Color("655d9f"),
		CardCategory.DELAYED_TRICK,
		Suit.NONE,
		0,
		true,
		TargetMode.SELF
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

