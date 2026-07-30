class_name DodgeCard
extends Card
## 闪：只能在成为【杀】的目标时响应。


func _init() -> void:
	super(
		CardType.DODGE,
		"闪",
		"成为【杀】的目标时使用，令本次【杀】无效。",
		Color("3e86c5")
	)


func can_use_as_response(game: Node, user: Node) -> bool:
	return game.is_waiting_for_dodge_from(user)

