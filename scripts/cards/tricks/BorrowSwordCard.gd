class_name BorrowSwordCard
extends Card
## 借刀杀人


func _init() -> void:
	super(
		CardType.BORROW_SWORD,
		"借刀杀人",
		"对装备武器的其他角色使用：其需对你指定的角色使用【杀】，否则将武器交给你。双人局中被杀目标为使用者。",
		Color("764c8a"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.OTHER
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_play_trick(self, user)

