class_name IronChainCard
extends Card
## 铁索连环


func _init() -> void:
	super(
		CardType.IRON_CHAIN,
		"铁索连环",
		"出牌阶段：选择一至两名角色，分别横置或重置其连环状态；也可以重铸此牌并摸一张牌。",
		Color("497f87"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.ONE_OR_TWO
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

