class_name NullificationCard
extends Card
## 无懈可击


func _init() -> void:
	super(
		CardType.NULLIFICATION,
		"无懈可击",
		"一张锦囊牌对一名角色生效前使用：抵消该效果；也可抵消另一张【无懈可击】。",
		Color("706d9e"),
		CardCategory.TRICK,
		Suit.NONE,
		0,
		false,
		TargetMode.NONE
	)


func can_use_as_response(game: Node, user: Node) -> bool:
	return game.is_waiting_for_nullification_from(user)

