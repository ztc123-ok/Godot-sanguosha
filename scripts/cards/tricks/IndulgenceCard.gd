class_name IndulgenceCard
extends Card
## 乐不思蜀


func _init() -> void:
	super(
		CardType.INDULGENCE,
		"乐不思蜀",
		"出牌阶段，置于其他角色判定区。其判定阶段判定：若结果不为红桃，跳过出牌阶段。",
		Color("bb6686"),
		CardCategory.DELAYED_TRICK,
		Suit.NONE,
		0,
		true,
		TargetMode.OTHER
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

