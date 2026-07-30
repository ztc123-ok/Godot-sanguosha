class_name PeachCard
extends Card
## 桃：出牌阶段回复体力，或在自己濒死时自救。


func _init() -> void:
	super(
		CardType.PEACH,
		"桃",
		"出牌阶段回复 1 点体力；自己濒死时也可使用。",
		Color("d56e91")
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.is_play_phase_for(user) and user.hp < user.max_hp


func can_use_while_dying(game: Node, user: Node) -> bool:
	return game.is_waiting_for_rescue_from(user)

